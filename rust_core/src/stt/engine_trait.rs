//! `SttEngine` — the common interface every speech-to-text backend
//! implements (Sprint: ASR engine selector, 2026-10-13).
//!
//! Before this trait existed, every call site talked to `WhisperEngine`
//! directly. Adding CrispASR/Qwen3-ASR as a second backend meant either
//! duplicating every call site or giving both engines one shape to be
//! called through. This is that shape.
//!
//! A model is picked **once**, at the start of a recording/import session,
//! and never swapped mid-session for quality-chasing reasons: whisper and
//! Qwen3-ASR have different transcription "handwriting" (punctuation,
//! proper-noun spelling), and switching mid-rapat would make one notulen
//! look stitched together from two voices. The one exception is a
//! same-session fallback on a hard engine failure (crash/error), which is
//! a safety net, not a quality optimization, and is handled by the caller
//! choosing a different `SttEngine` for the rest of the session — this
//! trait itself has no fallback logic, intentionally.

use crate::export::Segment;

use super::{DecodeOptions, TranscribeResult};

/// Stable identifier for which engine produced a transcript, persisted in
/// provenance metadata so a transcript can always say how it was made.
pub trait SttEngine: Send {
    /// Transcribe one chunk of 16kHz mono f32 PCM. `chunk_start_secs` is
    /// added to every returned timestamp so segments from a live session's
    /// Nth chunk land at the right point in the overall recording.
    fn transcribe(
        &self,
        samples: &[f32],
        source: &str,
        chunk_start_secs: f64,
        language: Option<&str>,
        initial_prompt: Option<&str>,
        options: DecodeOptions,
    ) -> TranscribeResult<Vec<Segment>>;

    /// Short stable id, e.g. `"whisper"` or `"crispasr-qwen3"`. Written into
    /// transcript provenance, never shown to the user verbatim (the UI maps
    /// it to a tier label).
    fn engine_id(&self) -> &'static str;

    /// Whether this engine is still considered experimental. Surfaced in
    /// the UI as a badge; does not change behaviour here.
    fn is_experimental(&self) -> bool {
        false
    }
}
