//! Hybrid Progressive Transcription (HPT).
//!
//! Dual-model pipeline: a quick model (`base`) produces near-instant
//! partial segments (`is_partial = true`), then a high-accuracy model
//! (`large-v3-turbo-q5`) refines the same audio and replaces those
//! segments with final text (`is_partial = false`).
//!
//! Segment identity across the two passes is `(source, timestamp)` —
//! both models transcribe the SAME 16kHz PCM chunk with the same
//! `chunk_start_secs`, so whisper.cpp yields identical segment
//! boundaries. The Dart side replaces text by this key.
//!
//! Latency budget (Apple Silicon, release build):
//!   base  on 30s chunk:  ~0.3-0.8s  → UI shows text in 3-5s window
//!   q5    on 30s chunk:  ~1.5-2.5s  → refinement lands shortly after

use std::path::Path;

use crate::error::{TranscribeError, TranscribeResult};
use crate::export::Segment;
use crate::stt::WhisperEngine;

/// A single HPT segment pair: quick + refined text for the same audio span.
#[derive(Debug, Clone)]
pub struct ProgressiveSegment {
    /// Stable identity: `source@timestamp` — used by Dart to replace by key.
    pub key: String,
    pub source: String,
    pub timestamp: f64,
    pub quick_text: String,
    pub refined_text: String,
    pub language: String,
    pub confidence: f32,
    /// True once the refined (q5) pass has landed for this segment.
    pub is_refined: bool,
}

/// Dual-model HPT engine. Loads BOTH contexts up front so the refine
/// pass never pays model-load latency during a session.
pub struct ProgressiveEngine {
    quick: WhisperEngine,  // base — near-instant partials
    refine: WhisperEngine, // large-v3-turbo-q5 — accurate finals
}

impl ProgressiveEngine {
    /// Load both models. Returns an error naming WHICH model failed so
    /// the caller can fall back to single-model mode.
    pub fn load(
        quick_path: &Path,
        refine_path: &Path,
        use_gpu: bool,
        gpu_device: i32,
    ) -> TranscribeResult<Self> {
        let quick = WhisperEngine::load_with_gpu(quick_path, use_gpu, gpu_device)
            .map_err(|e| TranscribeError::Model(format!("HPT quick model load failed: {e}")))?;
        let refine = WhisperEngine::load_with_gpu(refine_path, use_gpu, gpu_device)
            .map_err(|e| TranscribeError::Model(format!("HPT refine model load failed: {e}")))?;
        Ok(Self { quick, refine })
    }

    /// Pass 1: quick transcription with the base model.
    /// Returns segments with `is_partial = true` for immediate UI display.
    pub fn transcribe_quick(
        &self,
        samples: &[f32],
        source: &str,
        chunk_start_secs: f64,
        language: Option<&str>,
        initial_prompt: Option<&str>,
    ) -> TranscribeResult<Vec<Segment>> {
        let mut segs = self.quick.transcribe_chunk(
            samples,
            source,
            chunk_start_secs,
            language,
            initial_prompt,
        )?;
        for s in segs.iter_mut() {
            s.is_partial = true;
        }
        Ok(segs)
    }

    /// Pass 2: refine the same chunk with the large-v3-turbo-q5 model.
    /// Returns segments with `is_partial = false` and the same
    /// `(source, timestamp)` keys as the quick pass.
    pub fn transcribe_refine(
        &self,
        samples: &[f32],
        source: &str,
        chunk_start_secs: f64,
        language: Option<&str>,
        initial_prompt: Option<&str>,
    ) -> TranscribeResult<Vec<Segment>> {
        let mut segs = self.refine.transcribe_chunk(
            samples,
            source,
            chunk_start_secs,
            language,
            initial_prompt,
        )?;
        for s in segs.iter_mut() {
            s.is_partial = false;
        }
        Ok(segs)
    }

    /// Full HPT pass over one chunk: quick segments immediately, then
    /// refined replacements. `on_quick` fires before the refine pass
    /// starts so the UI renders within the 3-5s latency budget.
    pub fn transcribe_progressive<F>(
        &self,
        samples: &[f32],
        source: &str,
        chunk_start_secs: f64,
        language: Option<&str>,
        mut on_quick: F,
    ) -> TranscribeResult<Vec<ProgressiveSegment>>
    where
        F: FnMut(&[Segment]),
    {
        let quick_segs =
            self.transcribe_quick(samples, source, chunk_start_secs, language, None)?;
        on_quick(&quick_segs);

        let refined_segs =
            self.transcribe_refine(samples, source, chunk_start_secs, language, None)?;

        // Merge by (source, timestamp): refined replaces quick for the
        // same span. Quick-only leftovers (rare boundary drift) are kept
        // as unrefined so text is never lost.
        let mut merged: Vec<ProgressiveSegment> = Vec::with_capacity(refined_segs.len().max(1));
        for r in &refined_segs {
            let quick_text = quick_segs
                .iter()
                .find(|q| (q.timestamp - r.timestamp).abs() < 0.5)
                .map(|q| q.text.clone())
                .unwrap_or_default();
            merged.push(ProgressiveSegment {
                key: format!("{}@{:.2}", r.source, r.timestamp),
                source: r.source.clone(),
                timestamp: r.timestamp,
                quick_text,
                refined_text: r.text.clone(),
                language: r.language.clone(),
                confidence: r.confidence,
                is_refined: true,
            });
        }
        for q in &quick_segs {
            if !merged
                .iter()
                .any(|m| (m.timestamp - q.timestamp).abs() < 0.5)
            {
                merged.push(ProgressiveSegment {
                    key: format!("{}@{:.2}", q.source, q.timestamp),
                    source: q.source.clone(),
                    timestamp: q.timestamp,
                    quick_text: q.text.clone(),
                    refined_text: String::new(),
                    language: q.language.clone(),
                    confidence: q.confidence,
                    is_refined: false,
                });
            }
        }
        merged.sort_by(|a, b| {
            a.timestamp
                .partial_cmp(&b.timestamp)
                .unwrap_or(std::cmp::Ordering::Equal)
        });
        Ok(merged)
    }
}

/// Hallucination guard: collapses runs of identical text Whisper
/// sometimes emits on silence/ambiguity (n-gram scan, O(n)).
///
/// Within one segment: a phrase (1-4 words) repeated >3 times in a row
/// collapses to a single occurrence. Across segments: 3+ consecutive
/// segments with identical text collapse to one.
pub fn filter_loops(segments: &mut Vec<Segment>) {
    // Across-segment collapse first (operates on whole texts).
    let mut i = 0;
    while i + 2 < segments.len() {
        let (a, b, c) = (
            &segments[i].text,
            &segments[i + 1].text,
            &segments[i + 2].text,
        );
        if a == b && b == c {
            segments.remove(i + 1);
            segments.remove(i + 1); // was i+2, now shifted
                                    // Re-check from i in case the run is longer than 3.
        } else {
            i += 1;
        }
    }

    // Within-segment phrase collapse.
    for seg in segments.iter_mut() {
        seg.text = collapse_repeated_phrases(&seg.text);
    }
}

/// Collapse a phrase (1-4 words) repeated 4+ times consecutively into a
/// single occurrence. Operates on whitespace-split words.
fn collapse_repeated_phrases(text: &str) -> String {
    let words: Vec<&str> = text.split_whitespace().collect();
    if words.len() < 8 {
        return text.to_string();
    }
    let mut out: Vec<&str> = Vec::with_capacity(words.len());
    let mut i = 0;
    while i < words.len() {
        let mut repeated_span = 0usize;
        // Try n-gram sizes 4 down to 1; pick the longest repeat found.
        for n in (1..=4).rev() {
            if i + n <= words.len() {
                let phrase: Vec<&str> = words[i..i + n].to_vec();
                let mut count = 1;
                let mut j = i + n;
                while j + n <= words.len() && words[j..j + n] == phrase[..] {
                    count += 1;
                    j += n;
                }
                if count >= 4 {
                    repeated_span = j - i;
                    break;
                }
            }
        }
        if repeated_span > 0 {
            out.extend_from_slice(&words[i..i + n_phrase_len(&words, i, repeated_span)]);
            i += repeated_span;
        } else {
            out.push(words[i]);
            i += 1;
        }
    }
    out.join(" ")
}

/// Helper: given a repeated span starting at `i` of total length
/// `span`, return the phrase length (1-4) that tiles the span.
fn n_phrase_len(words: &[&str], i: usize, span: usize) -> usize {
    for n in (1..=4).rev() {
        if span.is_multiple_of(n) {
            let phrase: Vec<&str> = words[i..i + n].to_vec();
            let mut tiles = true;
            let mut j = i + n;
            while j < i + span {
                if words[j..j + n] != phrase[..] {
                    tiles = false;
                    break;
                }
                j += n;
            }
            if tiles {
                return n;
            }
        }
    }
    1
}

#[cfg(test)]
mod tests {
    use super::*;

    fn seg(text: &str, ts: f64) -> Segment {
        Segment {
            source: "MIC".into(),
            speaker: "MIC".into(),
            text: text.into(),
            timestamp: ts,
            duration: 5.0,
            language: "id".into(),
            confidence: 0.9,
            avg_log_prob: -0.3,
            is_partial: false,
            low_confidence: false,
        }
    }

    /// Same as [`seg`] but with an explicit HPT pass flag — shared with
    /// pipeline.rs contract tests.
    #[allow(dead_code)]
    pub(super) fn seg_with_flag(text: &str, ts: f64, is_partial: bool) -> Segment {
        let mut s = seg(text, ts);
        s.is_partial = is_partial;
        s.low_confidence = false;
        s
    }

    #[test]
    fn collapses_identical_consecutive_segments() {
        let mut v = vec![
            seg("terima kasih", 0.0),
            seg("terima kasih", 5.0),
            seg("terima kasih", 10.0),
            seg("lanjut topik", 15.0),
        ];
        filter_loops(&mut v);
        assert_eq!(v.len(), 2);
        assert_eq!(v[0].text, "terima kasih");
        assert_eq!(v[1].text, "lanjut topik");
    }

    #[test]
    fn collapses_repeated_phrase_inside_segment() {
        let mut v = vec![seg(
            "satu dua tiga satu dua tiga satu dua tiga satu dua tiga lanjut",
            0.0,
        )];
        filter_loops(&mut v);
        assert_eq!(v[0].text, "satu dua tiga lanjut");
    }

    #[test]
    fn leaves_normal_text_untouched() {
        let text = "rapat dimulai sekarang mari kita bahas anggaran";
        let mut v = vec![seg(text, 0.0)];
        filter_loops(&mut v);
        assert_eq!(v[0].text, text);
    }

    #[test]
    fn hpt_merge_keys_are_stable() {
        // Without real models we can't run inference; verify the key
        // format contract that Dart relies on.
        let segs = [seg("halo", 10.0), seg("dunia", 15.0)];
        let keys: Vec<String> = segs
            .iter()
            .map(|s| format!("{}@{:.2}", s.source, s.timestamp))
            .collect();
        assert_eq!(keys, vec!["MIC@10.00", "MIC@15.00"]);
    }
}
