//! Silero VAD via ONNX Runtime (ort).
//!
//! Silero requires 512-sample (32ms) frames at 16kHz. Since the rest of the
//! pipeline uses 160-sample (10ms) WebRTC frames, this detector accumulates
//! 5 consecutive 10ms frames internally before running inference.

use std::path::Path;

use ort::{session::Session, value::Tensor};

use crate::error::{TranscribeError, TranscribeResult};

const SILERO_FRAME_SAMPLES: usize = 512;

pub struct SileroVad {
    session: Session,
    state: [f32; 256],
    sample_rate: i64,
    accum_buf: Vec<i16>,
    threshold: f32,
}

impl SileroVad {
    pub fn load(model_path: &Path, threshold: f32) -> TranscribeResult<Self> {
        if !model_path.exists() {
            return Err(TranscribeError::Model(format!(
                "Silero VAD model not found: {}",
                model_path.display()
            )));
        }

        let session = Session::builder(crate::ort_env::get()?)
            .map_err(|e| TranscribeError::Model(format!("Silero session build failed: {e}")))?
            .commit_from_file(model_path)
            .map_err(|e| TranscribeError::Model(format!("Silero model load failed: {e}")))?;

        Ok(Self {
            session,
            state: [0.0; 256],
            sample_rate: 16_000,
            accum_buf: Vec::with_capacity(SILERO_FRAME_SAMPLES),
            threshold,
        })
    }

    pub fn reset(&mut self) {
        self.state = [0.0; 256];
        self.accum_buf.clear();
    }

    /// Returns the speech probability for the accumulated frame, or `None` if
    /// fewer than 5 × 160 = 512 samples have been accumulated.
    pub fn predict(&mut self, frame_10ms: &[i16]) -> TranscribeResult<Option<f32>> {
        self.accum_buf.extend_from_slice(frame_10ms);

        if self.accum_buf.len() < SILERO_FRAME_SAMPLES {
            return Ok(None);
        }

        let frame_i16: Vec<i16> = self.accum_buf.drain(..SILERO_FRAME_SAMPLES).collect();
        self.accum_buf.shrink_to_fit();

        let audio: Vec<f32> = frame_i16
            .iter()
            .map(|&s| s as f32 / i16::MAX as f32)
            .collect();

        let input = Tensor::from_array(([1usize, SILERO_FRAME_SAMPLES], audio.into_boxed_slice()))
            .map_err(|e| TranscribeError::Model(format!("Silero input tensor failed: {e}")))?;
        let state = Tensor::from_array(([2usize, 1, 128], self.state.to_vec().into_boxed_slice()))
            .map_err(|e| TranscribeError::Model(format!("Silero state tensor failed: {e}")))?;
        let sr = Tensor::from_array(([1usize], vec![self.sample_rate].into_boxed_slice()))
            .map_err(|e| {
                TranscribeError::Model(format!("Silero sample-rate tensor failed: {e}"))
            })?;

        let outputs = self
            .session
            .run(ort::inputs![input, state, sr])
            .map_err(|e| TranscribeError::Model(format!("Silero inference failed: {e}")))?;

        let (prob, new_state) = outputs
            .into_iter()
            .find(|(name, _)| *name == "output" || *name == "output0")
            .ok_or_else(|| TranscribeError::Model("Silero output tensor not found".into()))
            .and_then(|(_, v)| {
                let tensor = v
                    .try_extract_tensor::<f32>()
                    .map_err(|e| TranscribeError::Model(format!("Silero extract failed: {e}")))?;
                let slice = tensor.1;
                let n = tensor.0.num_elements();
                if n >= 128 {
                    Ok((slice.first().copied().unwrap_or(0.0), slice[128..].to_vec()))
                } else {
                    Err(TranscribeError::Model(
                        "Silero unexpected output shape".into(),
                    ))
                }
            })?;

        self.state = new_state.try_into().unwrap_or([0.0; 256]);
        Ok(Some(prob))
    }

    /// Returns `true` if the accumulated frame is speech (prob >= threshold).
    pub fn is_speech(&mut self, frame_10ms: &[i16]) -> TranscribeResult<bool> {
        match self.predict(frame_10ms)? {
            Some(prob) => Ok(prob >= self.threshold),
            None => Ok(false),
        }
    }
}
