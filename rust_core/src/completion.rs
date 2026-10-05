//! Post-stop transcript completion: "every second recorded ends up in the
//! transcript".
//!
//! # The failure this closes
//!
//! Live transcription is a single worker thread pulling captured PCM off a
//! channel and running Whisper on it. When the model is slower than real
//! time — `large-v3-turbo-q5` measures RTF ≈ 0.05 on a two-core laptop —
//! the channel grows for the whole meeting and the worker never catches
//! up. Stop tells it to exit, and everything still queued is discarded.
//!
//! The audio was never the problem: it is streamed to `mic.wav` /
//! `speaker.wav` by a separate tee thread that does no inference. So the
//! repair is to go back over the saved WAV after the meeting and transcribe
//! the stretches the live pass never reached, with the model the user
//! actually chose and no real-time constraint at all.
//!
//! # Shape of the pass
//!
//! 1. [`crate::coverage`] turns the existing transcript plus the WAV's
//!    length into the list of uncovered ranges.
//! 2. Each range is widened slightly and handed to the VAD, which carves
//!    out the parts that actually hold speech. Silence is never sent to
//!    Whisper — fed silence it answers with the most common caption in its
//!    training data (`[MENGENI]` on Indonesian audio), not with nothing.
//! 3. Each speech region is transcribed in ≤30 s chunks, at absolute
//!    timestamps, with the session's language and kamus istilah.
//! 4. The results are labelled by the same diarizer the live path uses
//!    (`Saya` for mic, `Peserta N` for loopback), filtered for loops and
//!    hallucinations, and merged back by timestamp. The merge is additive:
//!    an existing segment is never replaced, because it may carry the
//!    user's edits.
//!
//! Nothing here touches the network — this is the transcription path.

use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::Mutex;
use std::time::Instant;

use crate::coverage::{self, CoverageReport, TimeRange};
use crate::decode::TARGET_SAMPLE_RATE;
use crate::diarization::{label_segments, Diarizer};
use crate::error::TranscribeResult;
use crate::export::Segment;
use crate::glossary::GlossaryConfig;
use crate::stt::{DecodeOptions, WhisperEngine};
use crate::vad::SegmentationConfig;

/// Inference chunk length. Matches `stt::file` so peak memory during the
/// completion pass is the same as during an import.
const CHUNK_SECS: f64 = 30.0;

/// Everything one source's completion pass needs.
#[derive(Debug, Clone)]
#[flutter_rust_bridge::frb(ignore)]
pub struct CompletionRequest {
    pub audio_path: PathBuf,
    /// `"mic"`, `"spk"` or `"file"` — drives the speaker labels, exactly as
    /// in the live path.
    pub source: String,
    pub language: Option<String>,
    pub glossary: GlossaryConfig,
    /// Mirrors the session's VAD setting. With it off, every uncovered
    /// range is transcribed whole — more inference, and the hallucination
    /// filter is then the only thing standing between silence and
    /// `[MENGENI]`.
    pub vad_enabled: bool,
}

/// What a completion pass did.
#[derive(Debug, Clone, serde::Serialize)]
pub struct CompletionOutcome {
    /// The whole transcript, existing plus recovered, in time order.
    pub segments: Vec<Segment>,
    /// How many segments the pass added.
    pub added: u32,
    /// How many hallucinated/non-speech lines it refused to add.
    pub rejected: u32,
    /// Coverage after the merge, in wall-clock terms, with gaps that hold
    /// no speech already removed — those cannot be closed by transcribing
    /// them and must not leave a session marked unfinished forever.
    pub coverage: CoverageReport,
    /// Seconds of `audio_path` the VAD found speech in.
    pub speech_secs: f64,
    /// How much of that speech the merged transcript now covers. This is
    /// the honest completeness figure for a recording that is mostly
    /// silence, which a three-hour meeting with one speaker usually is.
    pub speech_covered_secs: f64,
    /// Length of the audio file the pass worked from.
    pub audio_secs: f64,
}

impl CompletionOutcome {
    /// `speech_covered_secs / speech_secs`, clamped. `1.0` when the
    /// recording holds no speech at all.
    #[flutter_rust_bridge::frb(ignore)]
    pub fn speech_fraction(&self) -> f64 {
        if self.speech_secs <= 0.0 {
            return 1.0;
        }
        (self.speech_covered_secs / self.speech_secs).clamp(0.0, 1.0)
    }
}

/// Runs the completion pass for one source over an already-loaded engine.
///
/// `on_progress` receives `(fraction, eta_secs)` after each chunk, where
/// the fraction is over the speech that still needs transcribing — not
/// over the recording, which would sit near 100% from the first chunk on a
/// mostly-silent track.
pub fn complete_transcript(
    engine: &WhisperEngine,
    request: &CompletionRequest,
    existing: Vec<Segment>,
    mut on_progress: impl FnMut(f32, f64),
) -> TranscribeResult<CompletionOutcome> {
    let audio = crate::decode::decode_audio_file(&request.audio_path)?;
    let audio_secs = audio.duration_secs;
    // One VAD pass over the whole recording. It answers both questions the
    // rest of this function asks: where the work is, and what "complete"
    // means for a file that is mostly silence.
    let speech = speech_regions(&audio.samples, audio_secs, request.vad_enabled)?;
    let speech_secs = total_secs(&speech);

    let before = coverage::report(&existing, audio_secs, coverage::MIN_GAP_SECS);
    let work = unfinished_speech(&speech, &coverage::covered_ranges(&existing));
    let total_work_secs = total_secs(&work);
    if total_work_secs <= 0.0 {
        // Either the transcript already covers every second that holds
        // speech, or the uncovered stretches hold none. Both are complete.
        on_progress(1.0, 0.0);
        let covered = intersect_secs(&speech, &coverage::covered_ranges(&existing));
        return Ok(CompletionOutcome {
            segments: existing,
            added: 0,
            rejected: 0,
            coverage: CoverageReport {
                gaps: Vec::new(),
                missing_secs: 0.0,
                ..before
            },
            speech_secs,
            speech_covered_secs: covered,
            audio_secs,
        });
    }

    let prompt = crate::glossary::build_initial_prompt(&request.glossary, "");
    let initial_prompt = (!prompt.text.is_empty()).then_some(prompt.text.as_str());
    let started = Instant::now();
    let mut done_secs = 0.0f64;
    let mut fresh: Vec<Segment> = Vec::new();

    for region in &work {
        let mut chunk_start = region.start;
        while chunk_start < region.end {
            let chunk_end = (chunk_start + CHUNK_SECS).min(region.end);
            let samples = slice_secs(&audio.samples, chunk_start, chunk_end);
            if !samples.is_empty() {
                fresh.extend(engine.transcribe_chunk_with(
                    samples,
                    &request.source,
                    chunk_start,
                    request.language.as_deref(),
                    initial_prompt,
                    DecodeOptions::offline(),
                )?);
            }
            done_secs += chunk_end - chunk_start;
            let fraction = (done_secs / total_work_secs).clamp(0.0, 1.0) as f32;
            on_progress(fraction, eta_secs(started, done_secs, total_work_secs));
            chunk_start = chunk_end;
        }
    }

    let before_filter = fresh.len();
    crate::progressive::filter_loops(&mut fresh);
    crate::hallucination::filter_segments(&mut fresh);
    let rejected = (before_filter - fresh.len()) as u32;

    let mut diarizer = Diarizer::new();
    label_segments(&mut diarizer, &audio.samples, &mut fresh);
    if request.glossary.post_correction {
        crate::glossary::correct_segments(&mut fresh, &request.glossary.prioritised_terms());
    }
    crate::confidence::apply_confidence_routing(&mut fresh);

    let added_candidates = fresh.len();
    let merged = coverage::merge_by_timestamp(existing, fresh, coverage::MERGE_TOLERANCE_SECS);
    let covered_after = coverage::covered_ranges(&merged);
    let after = coverage::report(&merged, audio_secs, coverage::MIN_GAP_SECS);
    // A gap the pass could not close because it holds no speech is not a
    // gap in the transcript, it is a quiet stretch of the meeting. Keeping
    // it would leave the session at "Menyelesaikan transkrip…" forever.
    let remaining = unfinished_speech(&speech, &covered_after);
    let after = CoverageReport {
        gaps: after
            .gaps
            .iter()
            .filter(|gap| intersect_secs(&remaining, std::slice::from_ref(gap)) > 0.0)
            .copied()
            .collect(),
        ..after
    };
    let after = CoverageReport {
        missing_secs: after.gaps.iter().map(TimeRange::duration).sum(),
        ..after
    };
    on_progress(1.0, 0.0);

    Ok(CompletionOutcome {
        added: added_candidates as u32,
        rejected,
        speech_secs,
        speech_covered_secs: intersect_secs(&speech, &covered_after),
        segments: merged,
        coverage: after,
        audio_secs,
    })
}

/// Speech spans across the whole recording. With VAD off this is the whole
/// file — the user asked for every chunk to be transcribed, and the
/// hallucination filter is then what stands between silence and
/// `[MENGENI]`.
fn speech_regions(
    samples: &[f32],
    audio_secs: f64,
    vad_enabled: bool,
) -> TranscribeResult<Vec<TimeRange>> {
    if !vad_enabled {
        return Ok(vec![TimeRange::new(0.0, audio_secs)]);
    }
    Ok(crate::vad::detect_speech_regions(
        samples,
        SegmentationConfig::default(),
        crate::stt::file::VAD_THREADS,
    )?
    .into_iter()
    .map(|(start, end)| TimeRange::new(start, end))
    .collect())
}

/// Speech not yet accounted for by `covered`, in chunks big enough to be
/// worth a second pass. Both inputs must be sorted and non-overlapping,
/// which is what [`coverage::covered_ranges`] and [`speech_regions`]
/// guarantee.
fn unfinished_speech(speech: &[TimeRange], covered: &[TimeRange]) -> Vec<TimeRange> {
    let mut out = Vec::new();
    for region in speech {
        let mut cursor = region.start;
        for taken in covered {
            if taken.end <= cursor {
                continue;
            }
            if taken.start >= region.end {
                break;
            }
            if taken.start > cursor {
                push_if_worthwhile(&mut out, cursor, taken.start.min(region.end));
            }
            cursor = cursor.max(taken.end);
            if cursor >= region.end {
                break;
            }
        }
        if cursor < region.end {
            push_if_worthwhile(&mut out, cursor, region.end);
        }
    }
    out
}

/// A sub-second sliver of speech between two transcribed segments is the
/// tail of a word, not a missing sentence. [`coverage::MIN_GAP_SECS`] is
/// the same threshold the pure coverage report uses.
fn push_if_worthwhile(out: &mut Vec<TimeRange>, start: f64, end: f64) {
    if end - start >= coverage::MIN_GAP_SECS {
        out.push(TimeRange::new(start, end));
    }
}

/// Seconds `ranges` spans. `-0.0` is normalised away: the sum of an empty
/// `f64` iterator is negative zero, which prints as "-0s".
fn total_secs(ranges: &[TimeRange]) -> f64 {
    ranges.iter().map(TimeRange::duration).sum::<f64>() + 0.0
}

/// Seconds covered by both `a` and `b`. Both must be sorted and
/// non-overlapping.
fn intersect_secs(a: &[TimeRange], b: &[TimeRange]) -> f64 {
    let mut total = 0.0;
    for left in a {
        for right in b {
            if right.end <= left.start {
                continue;
            }
            if right.start >= left.end {
                break;
            }
            total += right.end.min(left.end) - right.start.max(left.start);
        }
    }
    total + 0.0
}

fn slice_secs(samples: &[f32], start_secs: f64, end_secs: f64) -> &[f32] {
    let rate = TARGET_SAMPLE_RATE as f64;
    let start = ((start_secs * rate).max(0.0) as usize).min(samples.len());
    let end = ((end_secs * rate).max(0.0) as usize).clamp(start, samples.len());
    &samples[start..end]
}

fn eta_secs(started: Instant, done_secs: f64, total_secs: f64) -> f64 {
    if done_secs <= 0.0 {
        return 0.0;
    }
    let elapsed = started.elapsed().as_secs_f64();
    (elapsed / done_secs * (total_secs - done_secs)).max(0.0)
}

// --- Progress, polled from Dart --------------------------------------------

/// One source's completion pass, as the UI sees it.
#[derive(Debug, Clone, serde::Serialize)]
pub struct CompletionProgress {
    /// Opaque key the caller chose — the session directory, in practice.
    pub job_key: String,
    pub source: String,
    /// `0.0..=1.0` over the speech that needed transcribing.
    pub fraction: f32,
    pub eta_secs: f64,
    pub done: bool,
}

fn progress_slots() -> &'static Mutex<HashMap<String, CompletionProgress>> {
    static SLOTS: std::sync::OnceLock<Mutex<HashMap<String, CompletionProgress>>> =
        std::sync::OnceLock::new();
    SLOTS.get_or_init(|| Mutex::new(HashMap::new()))
}

#[flutter_rust_bridge::frb(ignore)]
pub fn publish_progress(progress: CompletionProgress) {
    if let Ok(mut slots) = progress_slots().lock() {
        slots.insert(slot_key(&progress.job_key, &progress.source), progress);
    }
}

#[flutter_rust_bridge::frb(ignore)]
pub fn read_progress() -> Vec<CompletionProgress> {
    progress_slots()
        .lock()
        .map(|slots| slots.values().cloned().collect())
        .unwrap_or_default()
}

#[flutter_rust_bridge::frb(ignore)]
pub fn clear_progress(job_key: &str, source: &str) {
    if let Ok(mut slots) = progress_slots().lock() {
        slots.remove(&slot_key(job_key, source));
    }
}

fn slot_key(job_key: &str, source: &str) -> String {
    format!("{job_key}\u{1}{source}")
}

/// Infers the source tag from a captured track's filename, so Dart does
/// not have to repeat the `mic.wav`/`speaker.wav` convention.
#[flutter_rust_bridge::frb(ignore)]
pub fn source_for_audio(path: &Path) -> &'static str {
    match path.file_name().and_then(|n| n.to_str()) {
        Some("mic.wav") => "mic",
        Some("speaker.wav") => "spk",
        _ => "file",
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn seg(text: &str, timestamp: f64, duration: f64) -> Segment {
        Segment {
            source: "spk".into(),
            speaker: "Peserta 1".into(),
            text: text.into(),
            timestamp,
            duration,
            language: "id".into(),
            confidence: 0.9,
            avg_log_prob: -0.3,
            is_partial: false,
            low_confidence: false,
            words: Vec::new(),
        }
    }

    #[test]
    fn slice_secs_clamps_to_the_buffer() {
        let samples = vec![0.0f32; 16_000 * 2];
        assert_eq!(slice_secs(&samples, 0.0, 1.0).len(), 16_000);
        assert_eq!(slice_secs(&samples, 1.5, 99.0).len(), 8_000);
        assert!(slice_secs(&samples, 10.0, 20.0).is_empty());
        assert!(slice_secs(&samples, -5.0, 0.0).is_empty());
        // An inverted range yields nothing rather than panicking.
        assert!(slice_secs(&samples, 1.0, 0.5).is_empty());
    }

    #[test]
    fn eta_scales_with_what_is_left() {
        let started = Instant::now() - std::time::Duration::from_secs(10);
        // 10 s of wall clock bought 50 s of audio; 150 s remain → ~30 s.
        let eta = eta_secs(started, 50.0, 200.0);
        assert!((25.0..40.0).contains(&eta), "eta was {eta}");
        assert_eq!(eta_secs(started, 0.0, 200.0), 0.0);
        assert_eq!(eta_secs(started, 200.0, 200.0), 0.0);
    }

    #[test]
    fn source_is_read_from_the_track_filename() {
        assert_eq!(source_for_audio(Path::new("/x/mic.wav")), "mic");
        assert_eq!(source_for_audio(Path::new("/x/speaker.wav")), "spk");
        assert_eq!(source_for_audio(Path::new("/x/rapat.m4a")), "file");
    }

    #[test]
    fn progress_slots_are_per_source_and_clearable() {
        let key = "test-session-slots";
        clear_progress(key, "mic");
        clear_progress(key, "spk");
        publish_progress(CompletionProgress {
            job_key: key.into(),
            source: "mic".into(),
            fraction: 0.34,
            eta_secs: 60.0,
            done: false,
        });
        publish_progress(CompletionProgress {
            job_key: key.into(),
            source: "spk".into(),
            fraction: 1.0,
            eta_secs: 0.0,
            done: true,
        });
        let mine: Vec<_> = read_progress()
            .into_iter()
            .filter(|p| p.job_key == key)
            .collect();
        assert_eq!(mine.len(), 2);
        clear_progress(key, "mic");
        clear_progress(key, "spk");
        assert!(read_progress().iter().all(|p| p.job_key != key));
    }

    #[test]
    fn there_is_no_speech_to_recover_from_silence() {
        // 60 s of digital silence: there is nothing to transcribe, and
        // saying so is what stops the pass from manufacturing `[MENGENI]`
        // for six minutes of quiet.
        let samples = vec![0.0f32; 16_000 * 60];
        let speech = speech_regions(&samples, 60.0, true).unwrap();
        assert!(speech.is_empty(), "speech found in silence: {speech:?}");
        assert_eq!(total_secs(&speech), 0.0);
        assert!(unfinished_speech(&speech, &[]).is_empty());
    }

    #[test]
    fn without_vad_the_whole_file_is_speech() {
        let samples = vec![0.0f32; 16_000 * 60];
        let speech = speech_regions(&samples, 60.0, false).unwrap();
        assert_eq!(speech, vec![TimeRange::new(0.0, 60.0)]);
    }

    #[test]
    fn unfinished_speech_is_what_the_transcript_misses() {
        let speech = vec![TimeRange::new(0.0, 30.0), TimeRange::new(150.0, 180.0)];
        // The measured failure: live covered 1..8 s only.
        let covered = vec![TimeRange::new(1.0, 8.0)];
        assert_eq!(
            unfinished_speech(&speech, &covered),
            vec![TimeRange::new(8.0, 30.0), TimeRange::new(150.0, 180.0)]
        );
    }

    #[test]
    fn fully_transcribed_speech_leaves_no_work() {
        let speech = vec![TimeRange::new(10.0, 40.0)];
        let covered = vec![TimeRange::new(0.0, 60.0)];
        assert!(unfinished_speech(&speech, &covered).is_empty());
    }

    #[test]
    fn a_sliver_between_two_segments_is_not_work() {
        // Whisper leaves sub-second holes between segments; chasing them
        // would re-transcribe the file forever.
        let speech = vec![TimeRange::new(0.0, 30.0)];
        let covered = vec![TimeRange::new(0.0, 14.0), TimeRange::new(15.0, 30.0)];
        assert!(unfinished_speech(&speech, &covered).is_empty());
    }

    #[test]
    fn intersect_secs_measures_the_overlap() {
        let speech = vec![TimeRange::new(0.0, 30.0), TimeRange::new(150.0, 180.0)];
        assert_eq!(intersect_secs(&speech, &[TimeRange::new(1.0, 8.0)]), 7.0);
        assert_eq!(intersect_secs(&speech, &[TimeRange::new(40.0, 100.0)]), 0.0);
        assert_eq!(
            intersect_secs(&speech, &[TimeRange::new(0.0, 1000.0)]),
            60.0
        );
        // Negative zero never reaches the UI as "-0s".
        assert!(intersect_secs(&[], &[]).is_sign_positive());
        assert!(total_secs(&[]).is_sign_positive());
    }

    /// End-to-end over a real WAV with a real model. Opt-in because it
    /// needs `models/ggml-tiny.bin` and a minute of CPU:
    ///
    /// ```text
    /// TRAREON_COMPLETION_IT=1 \
    /// TRAREON_COMPLETION_WAV=/path/to/rapat.wav \
    ///   cargo test --lib completion::tests::completion_pass
    /// ```
    ///
    /// **Both** variables are required. The doc here used to name only
    /// the first, and `integration_fixtures` returned `None` without a
    /// word when the second was missing — so following the instructions
    /// produced a green test that had transcribed nothing. It now says so
    /// out loud.
    #[test]
    fn completion_pass_covers_the_speech_in_a_real_recording() {
        let Some((engine, audio_path)) = integration_fixtures() else {
            return;
        };
        let request = CompletionRequest {
            audio_path,
            source: "spk".into(),
            language: Some("id".into()),
            glossary: GlossaryConfig::default(),
            vad_enabled: true,
        };
        // Start from nothing: the worst case, where the live pass produced
        // no transcript at all.
        let outcome = complete_transcript(&engine, &request, Vec::new(), |_, _| {}).unwrap();
        assert!(
            outcome.added > 0,
            "completion pass produced no segments at all"
        );
        // Every segment must be real speech, not a silence caption.
        for segment in &outcome.segments {
            assert!(
                !crate::hallucination::is_non_speech(&segment.text),
                "hallucinated line survived: {:?}",
                segment.text
            );
        }
        // Coverage is measured against the speech in the file, not its
        // length — the fixture is mostly silence by construction.
        assert!(
            outcome.speech_fraction() >= 0.95,
            "covered {:.1}s of {:.1}s of speech ({:.1}%, <95%)",
            outcome.speech_covered_secs,
            outcome.speech_secs,
            outcome.speech_fraction() * 100.0
        );
        assert!(
            outcome.coverage.gaps.is_empty(),
            "speech-bearing gaps remain: {:?}",
            outcome.coverage.gaps
        );
    }

    #[test]
    fn completion_pass_fills_only_the_gap_and_keeps_existing_text() {
        let Some((engine, audio_path)) = integration_fixtures() else {
            return;
        };
        let request = CompletionRequest {
            audio_path,
            source: "spk".into(),
            language: Some("id".into()),
            glossary: GlossaryConfig::default(),
            vad_enabled: true,
        };
        // Pretend the live pass got the first 10 seconds and then fell
        // behind — the measured failure, in miniature.
        let existing = vec![seg("TRANSKRIP LANGSUNG YANG SUDAH ADA", 0.0, 10.0)];
        let outcome = complete_transcript(&engine, &request, existing, |_, _| {}).unwrap();
        assert!(
            outcome
                .segments
                .iter()
                .any(|s| s.text == "TRANSKRIP LANGSUNG YANG SUDAH ADA"),
            "the completion pass destroyed existing text"
        );
        assert!(
            outcome.segments.iter().all(|s| s.timestamp >= 0.0),
            "negative timestamps"
        );
    }

    /// `(engine, wav path)` for the integration tests, or `None` when the
    /// opt-in env var or the fixtures are missing.
    fn integration_fixtures() -> Option<(WhisperEngine, PathBuf)> {
        if std::env::var("TRAREON_COMPLETION_IT").is_err() {
            return None;
        }
        let root = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .parent()?
            .to_path_buf();
        let model = root.join("models/ggml-tiny.bin");
        if !model.exists() {
            eprintln!("skipping: {} missing", model.display());
            return None;
        }
        // Opted in but given nothing to transcribe: shout. A silent
        // `None` here is how a test the brief *requires* passes in 0.5
        // seconds having done no work at all.
        let audio = match std::env::var("TRAREON_COMPLETION_WAV") {
            Ok(path) => PathBuf::from(path),
            Err(_) => panic!(
                "TRAREON_COMPLETION_IT=1 is set but TRAREON_COMPLETION_WAV is \
                 not — this test needs a real recording to transcribe. Point \
                 it at a WAV with speech and silence, e.g. a saved session's \
                 speaker.wav."
            ),
        };
        if !audio.exists() {
            eprintln!("skipping: {} missing", audio.display());
            return None;
        }
        let engine = WhisperEngine::load(&model).ok()?;
        Some((engine, audio))
    }
}
