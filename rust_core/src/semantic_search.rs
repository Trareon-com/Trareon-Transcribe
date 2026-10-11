//! Semantic search layer over [`crate::archive`]'s existing FTS5 index
//! (Sprint 13 D1-D4, revisited).
//!
//! Sprint 13 marked this NOT DONE for the right reasons: a hybrid
//! search needs a local multilingual embedding model (license + size
//! research), vector storage, and RRF ranking — none of which can be
//! half-shipped without either an untested index or a feature that
//! silently claims results it never validated ("no results must not
//! make something up").
//!
//! This module ships the parts of that stack which are pure engineering
//! and fully testable *without* a model: `vec0` storage via `sqlite-vec`
//! and reciprocal rank fusion against [`crate::archive`]'s existing BM25
//! results. [`EmbeddingProvider`] is the seam where a real embedding
//! model plugs in — deliberately a trait with no default/mock
//! implementation in this file, because a fake embedder would be exactly
//! the kind of stub this project's briefs rule out.
//!
//! # Model research (for the PERLU IZIN step before wiring a real one)
//!
//! Candidates surveyed, both permissively licensed and small enough to
//! bundle-download the way Whisper models already are:
//! - `asmud/indonesian-embedding-small` (MIT, quantized ONNX ~113 MB,
//!   384-dim, Indonesian-specific — matches this app's Indonesia-first
//!   positioning most closely).
//! - `sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2`
//!   (Apache-2.0, 384-dim, battle-tested across 50+ languages including
//!   Indonesian, if sessions ever mix languages).
//! Both run via `ort` (already an optional dependency for `silero-onnx`
//! VAD — see Sprint 12), so adopting either adds no new *kind* of
//! dependency, only a new model download, which is why this still needs
//! an explicit go/no-add from the owner before it is wired in for real.
//!
//! # Why RRF and not a weighted score blend
//!
//! BM25 scores and cosine-similarity scores live on unrelated, unbounded
//! scales — a weighted sum between them needs constant re-tuning as
//! either index's score distribution shifts. Reciprocal Rank Fusion
//! sidesteps that by working on *rank position* instead of raw score:
//! `1 / (k + rank)` for each list, summed. It is the same formula the
//! SQLite project's own hybrid-search writeup and most production
//! systems in this space use for exactly this reason.

use std::collections::HashMap;

use rusqlite::Connection;

use crate::error::TranscribeError;

/// Dimensionality for both embedding candidates above (verified in their
/// model cards) — enforced at the `vec0` schema level so a mismatched
/// provider fails loudly at insert time instead of silently truncating.
pub const EMBEDDING_DIM: usize = 384;

/// Reciprocal Rank Fusion constant. 60 is the value used in the
/// original RRF paper and nearly every production hybrid-search
/// implementation since (including the sqlite-vec project's own
/// reference examples) — not tuned per-corpus, which is the point of
/// using RRF instead of a weighted score blend in the first place.
pub const RRF_K: f64 = 60.0;

/// Converts a passage's text into an embedding vector. Implemented by
/// whatever local ONNX model is wired in — deliberately has no
/// implementation in this module. A mock/fake embedder (e.g. a hash-based
/// placeholder) would satisfy the trait but produce search results that
/// *look* like semantic matches while actually being meaningless, which
/// is the specific failure mode the brief's "no stub/mock data" rule
/// exists to rule out.
pub trait EmbeddingProvider {
    /// Returns an [`EMBEDDING_DIM`]-length vector for `text`. Implementors
    /// own batching/truncation for long passages; this module treats the
    /// result as opaque.
    fn embed(&self, text: &str) -> Result<Vec<f32>, TranscribeError>;
}

fn sql_error(error: rusqlite::Error) -> TranscribeError {
    TranscribeError::InvalidInput(format!("indeks semantik: {error}"))
}

/// Registers the `sqlite-vec` extension for every connection opened in
/// this process. Idempotent (safe to call more than once) — `rusqlite`'s
/// `bundled` SQLite build is shared process-wide, so this only needs to
/// run once before the first [`open_vec_table`] call, not once per
/// connection.
pub fn register_extension() {
    // SAFETY: `sqlite3_vec_init` is sqlite-vec's documented C ABI entry
    // point, built for exactly this registration path (see the crate's
    // own `src/lib.rs` test, `test_rusqlite_auto_extension`, which uses
    // this identical `as *const () -> transmute` pattern).
    // `sqlite3_auto_extension` runs it against every connection
    // subsequently opened against this process's bundled SQLite —
    // required because a mismatched system SQLite would not expose
    // `vec0` at all.
    unsafe {
        rusqlite::ffi::sqlite3_auto_extension(Some(std::mem::transmute::<
            *const (),
            unsafe extern "C" fn(
                *mut rusqlite::ffi::sqlite3,
                *mut *mut std::os::raw::c_char,
                *const rusqlite::ffi::sqlite3_api_routines,
            ) -> std::os::raw::c_int,
        >(
            sqlite_vec::sqlite3_vec_init as *const ()
        )));
    }
}

/// Creates the `passage_embeddings` vec0 virtual table if it does not
/// already exist. Call [`register_extension`] first (once per process) —
/// `vec0` is not a real table until the extension is registered, so
/// calling this first produces a clear "no such module: vec0" error
/// rather than a confusing one later.
pub fn ensure_vec_table(db: &Connection) -> Result<(), TranscribeError> {
    db.execute_batch(&format!(
        "CREATE VIRTUAL TABLE IF NOT EXISTS passage_embeddings USING vec0(
             embedding float[{EMBEDDING_DIM}]
         );"
    ))
    .map_err(sql_error)
}

/// Stores (or replaces) the embedding for a passage. `rowid` must match
/// the corresponding row's `rowid` in [`crate::archive`]'s `passages`
/// FTS5 table — the two tables are joined by rowid at search time, the
/// same pattern `sqlite-vec`'s own hybrid-search examples use.
pub fn store_embedding(
    db: &Connection,
    rowid: i64,
    embedding: &[f32],
) -> Result<(), TranscribeError> {
    if embedding.len() != EMBEDDING_DIM {
        return Err(TranscribeError::InvalidInput(format!(
            "embedding dim salah: diharap {EMBEDDING_DIM}, dapat {}",
            embedding.len()
        )));
    }
    let bytes: &[u8] = bytemuck_cast_f32_slice(embedding);
    db.execute(
        "INSERT OR REPLACE INTO passage_embeddings (rowid, embedding) VALUES (?1, ?2)",
        rusqlite::params![rowid, bytes],
    )
    .map_err(sql_error)?;
    Ok(())
}

/// Reinterprets an `f32` slice as raw bytes for `vec0`'s blob input
/// format, without pulling in the `zerocopy`/`bytemuck` crate for one
/// call site — `f32` has no padding and this process is always
/// little-endian x86_64/aarch64, matching `vec0`'s expected layout.
fn bytemuck_cast_f32_slice(floats: &[f32]) -> &[u8] {
    // SAFETY: `f32` and `u8` have no alignment requirement incompatible
    // with this reinterpretation at the byte level; the resulting slice
    // is exactly `floats.len() * 4` bytes, matching `vec0`'s documented
    // `float[N]` blob format.
    unsafe {
        std::slice::from_raw_parts(floats.as_ptr() as *const u8, std::mem::size_of_val(floats))
    }
}

/// Finds the `k` nearest passages to `query_embedding` by cosine/L2
/// distance (as configured by `vec0`'s default metric), returning
/// `(rowid, distance)` pairs ordered nearest-first.
pub fn vector_search(
    db: &Connection,
    query_embedding: &[f32],
    k: usize,
) -> Result<Vec<(i64, f64)>, TranscribeError> {
    if query_embedding.len() != EMBEDDING_DIM {
        return Err(TranscribeError::InvalidInput(format!(
            "embedding dim salah: diharap {EMBEDDING_DIM}, dapat {}",
            query_embedding.len()
        )));
    }
    let bytes: &[u8] = bytemuck_cast_f32_slice(query_embedding);
    let mut statement = db
        .prepare(
            "SELECT rowid, distance FROM passage_embeddings
             WHERE embedding MATCH ?1 AND k = ?2
             ORDER BY distance",
        )
        .map_err(sql_error)?;
    let rows = statement
        .query_map(rusqlite::params![bytes, k as i64], |row| {
            Ok((row.get::<_, i64>(0)?, row.get::<_, f64>(1)?))
        })
        .map_err(sql_error)?;
    let mut results = Vec::new();
    for row in rows {
        results.push(row.map_err(sql_error)?);
    }
    Ok(results)
}

/// Fuses lexical (BM25, from [`crate::archive`]) and semantic (vector
/// distance, from [`vector_search`]) result lists into one ranking via
/// Reciprocal Rank Fusion. Each input list is assumed already sorted
/// best-first (the caller's responsibility — this function only reads
/// position, not the scores themselves, per the module doc's rationale).
///
/// A passage present in only one list still gets a fusion score (RRF
/// degrades gracefully to "whichever list found it" rather than
/// requiring both) — important here because short/unusual queries
/// legitimately match only on keyword or only on meaning, not both.
pub fn reciprocal_rank_fusion(fts_hits: &[i64], vec_hits: &[i64], k: f64) -> Vec<(i64, f64)> {
    let mut scores: HashMap<i64, f64> = HashMap::new();
    for (rank, &rowid) in fts_hits.iter().enumerate() {
        *scores.entry(rowid).or_insert(0.0) += 1.0 / (k + rank as f64 + 1.0);
    }
    for (rank, &rowid) in vec_hits.iter().enumerate() {
        *scores.entry(rowid).or_insert(0.0) += 1.0 / (k + rank as f64 + 1.0);
    }
    let mut fused: Vec<(i64, f64)> = scores.into_iter().collect();
    fused.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap_or(std::cmp::Ordering::Equal));
    fused
}

#[cfg(test)]
mod tests {
    use super::*;

    fn test_db() -> Connection {
        register_extension();
        let db = Connection::open_in_memory().unwrap();
        ensure_vec_table(&db).unwrap();
        db
    }

    fn unit_vector(direction: usize) -> Vec<f32> {
        let mut v = vec![0.0f32; EMBEDDING_DIM];
        v[direction % EMBEDDING_DIM] = 1.0;
        v
    }

    #[test]
    fn vec_extension_registers_and_table_creates_without_error() {
        // The whole point of this test: if `register_extension` ever
        // stops actually registering `vec0` (e.g. a future sqlite-vec
        // upgrade changes the FFI symbol/signature), `ensure_vec_table`
        // fails immediately with "no such module: vec0" instead of this
        // silently degrading into a confusing failure three functions
        // later at search time.
        let _db = test_db();
    }

    #[test]
    fn stored_embedding_is_the_nearest_match_to_itself() {
        let db = test_db();
        store_embedding(&db, 1, &unit_vector(0)).unwrap();
        store_embedding(&db, 2, &unit_vector(1)).unwrap();
        store_embedding(&db, 3, &unit_vector(2)).unwrap();

        let results = vector_search(&db, &unit_vector(0), 3).unwrap();
        assert_eq!(
            results[0].0, 1,
            "the identical vector must rank nearest to itself"
        );
    }

    #[test]
    fn wrong_dimension_embedding_is_rejected_not_silently_truncated() {
        let db = test_db();
        let short = vec![0.0f32; EMBEDDING_DIM - 1];
        let result = store_embedding(&db, 1, &short);
        assert!(result.is_err(), "mismatched dimension must be an error");
    }

    #[test]
    fn rrf_ranks_items_found_by_both_lists_above_items_found_by_one() {
        // Passage 5 ranks #1 in lexical search and #2 in vector search —
        // found by both, near the top of both. Passage 9 ranks #1 in
        // vector search only. RRF should still prefer 5: it is strong
        // across both signals, which is exactly what hybrid search is
        // for (a passage a user would recognize as "clearly the answer"
        // from either angle, not just one).
        let fts_hits = vec![5, 7, 8];
        let vec_hits = vec![9, 5, 6];
        let fused = reciprocal_rank_fusion(&fts_hits, &vec_hits, RRF_K);
        assert_eq!(
            fused[0].0, 5,
            "a passage strong in both lists should outrank one strong in only one"
        );
    }

    #[test]
    fn rrf_still_surfaces_a_passage_found_in_only_one_list() {
        // Semantic-only match (paraphrase, no shared keywords) — found
        // in the vector list at all, absent from lexical entirely.
        let fts_hits = vec![1, 2, 3];
        let vec_hits = vec![42];
        let fused = reciprocal_rank_fusion(&fts_hits, &vec_hits, RRF_K);
        assert!(
            fused.iter().any(|(rowid, _)| *rowid == 42),
            "a semantic-only match must not be dropped just for lacking a lexical hit"
        );
    }

    #[test]
    fn rrf_handles_empty_lists() {
        assert_eq!(reciprocal_rank_fusion(&[], &[], RRF_K), vec![]);
        let fused = reciprocal_rank_fusion(&[1, 2], &[], RRF_K);
        assert_eq!(fused.len(), 2);
    }
}
