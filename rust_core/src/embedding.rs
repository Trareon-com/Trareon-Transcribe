//! `IndonesianEmbedder`: the concrete [`crate::semantic_search::EmbeddingProvider`]
//! implementation, backed by a local ONNX sentence-embedding model.
//!
//! Only compiled under the `semantic-embedding` feature (off by default —
//! see `Cargo.toml`). Nothing in this crate downloads the model files: the
//! user fetches them once into the app's model cache dir, and this module
//! just loads whatever is already on disk.
//!
//! Expected model: `asmud/indonesian-embedding-small` (MIT), exported to
//! ONNX int8 (`indonesian_embedding_q8.onnx`, ~113 MB) with its own
//! `tokenizer.json`. Verified inputs/outputs of that export (checked by
//! hand against the actual .onnx graph, not assumed):
//!   inputs:  input_ids [batch, seq], attention_mask [batch, seq]
//!   outputs: last_hidden_state [batch, seq, 384] (token-level, unused here)
//!            <pooled>            [batch, 384]    (already-pooled sentence
//!                                                  embedding — this is what
//!                                                  we read)
//! The pooled output has no stable name in the traced graph (opset-specific
//! generated name), so it is selected by shape (rank 2) rather than by
//! name — the one piece of fragility worth calling out for future readers.

use std::path::Path;
use std::sync::Mutex;

use ort::session::Session;
use ort::value::Value;
use tokenizers::Tokenizer;

use crate::error::{TranscribeError, TranscribeResult};
use crate::semantic_search::EmbeddingProvider;

/// Max tokens fed to the model per chunk. The base model's own config caps
/// at 512; we use a smaller window because meeting-transcript chunks are
/// short utterances, not documents, and a smaller window is cheaper.
const MAX_TOKENS: usize = 256;

pub struct IndonesianEmbedder {
    // `ort::session::Session::run` takes `&mut self`; the trait method is
    // `&self`, so the session is wrapped in a `Mutex` rather than widening
    // the trait to `&mut self` for every other (possibly remote/stateless)
    // implementation.
    session: Mutex<Session>,
    tokenizer: Tokenizer,
}

impl IndonesianEmbedder {
    /// Loads the ONNX session and tokenizer from the given paths. Returns
    /// an error (never panics) if either file is missing or malformed —
    /// callers are expected to check for the files' existence first and
    /// surface a "download the model" prompt in the UI rather than a raw
    /// Rust error.
    pub fn load(
        onnx_path: impl AsRef<Path>,
        tokenizer_path: impl AsRef<Path>,
    ) -> TranscribeResult<Self> {
        let onnx_path = onnx_path.as_ref();
        let tokenizer_path = tokenizer_path.as_ref();

        ort::init().commit();

        let session = Session::builder()
            .map_err(|e| TranscribeError::Model(format!("embedding session build failed: {e}")))?
            .commit_from_file(onnx_path)
            .map_err(|e| {
                TranscribeError::Model(format!(
                    "embedding model load failed ({}): {e}",
                    onnx_path.display()
                ))
            })?;

        let tokenizer = Tokenizer::from_file(tokenizer_path).map_err(|e| {
            TranscribeError::Model(format!(
                "embedding tokenizer load failed ({}): {e}",
                tokenizer_path.display()
            ))
        })?;

        Ok(Self {
            session: Mutex::new(session),
            tokenizer,
        })
    }
}

impl EmbeddingProvider for IndonesianEmbedder {
    fn embed(&self, text: &str) -> TranscribeResult<Vec<f32>> {
        let encoding = self
            .tokenizer
            .encode(text, true)
            .map_err(|e| TranscribeError::Model(format!("tokenize failed: {e}")))?;

        let mut ids: Vec<i64> = encoding.get_ids().iter().map(|&x| x as i64).collect();
        let mut mask: Vec<i64> = encoding
            .get_attention_mask()
            .iter()
            .map(|&x| x as i64)
            .collect();
        ids.truncate(MAX_TOKENS);
        mask.truncate(MAX_TOKENS);

        let seq_len = ids.len();
        let input_ids = Value::from_array(([1, seq_len], ids))
            .map_err(|e| TranscribeError::Model(format!("input_ids tensor build failed: {e}")))?;
        let attention_mask = Value::from_array(([1, seq_len], mask)).map_err(|e| {
            TranscribeError::Model(format!("attention_mask tensor build failed: {e}"))
        })?;

        let mut session = self
            .session
            .lock()
            .map_err(|_| TranscribeError::Model("embedding session mutex poisoned".into()))?;

        let outputs = session
            .run(ort::inputs![
                "input_ids" => input_ids,
                "attention_mask" => attention_mask,
            ])
            .map_err(|e| TranscribeError::Model(format!("embedding inference failed: {e}")))?;

        // Pick the rank-2 [batch, hidden] output — that's the already-pooled
        // sentence embedding, as opposed to the rank-3 [batch, seq, hidden]
        // last_hidden_state. See module doc for why this is by-shape, not
        // by-name.
        let mut pooled: Option<Vec<f32>> = None;
        for (_name, value) in outputs.iter() {
            if let Ok((shape, data)) = value.try_extract_tensor::<f32>() {
                if shape.len() == 2 {
                    pooled = Some(data.to_vec());
                    break;
                }
            }
        }

        pooled.ok_or_else(|| {
            TranscribeError::Model(
                "embedding model produced no rank-2 pooled output — model export may have changed"
                    .into(),
            )
        })
    }
}
