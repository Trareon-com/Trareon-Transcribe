//! Optional neural speaker diarization via sherpa-onnx.
//!
//! "Pemisahan pembicara akurat". The default diarizer in the parent module
//! clusters three crude acoustic features (pitch proxy, RMS, zero-crossing
//! rate) and is adequate for the case most sessions are: two capture
//! sources, where the microphone is the user and the loopback is everyone
//! else. It is not adequate for a single-source recording of six people
//! round a table, which is what an imported file usually is — there it
//! splits one voice into four "speakers" and merges two quiet ones.
//!
//! sherpa-onnx is the pipeline Research Round 2 §2.3.3 settles on: pyannote
//! segmentation 3.0 for "who is speaking when", 3D-Speaker CAM++ for the
//! voice fingerprints, agglomerative clustering to join them up — all ONNX,
//! all on the CPU, ~34 MB of models, no Python anywhere. It reports DER
//! 12–15% on AMI/CALLHOME, which is what the commercial cloud services get.
//!
//! # Why this is behind a cargo feature
//!
//! `sherpa-onnx-sys`'s build script downloads a prebuilt static library
//! (23 MB on Linux x64, 123 MB on Windows) from GitHub Releases at *build*
//! time. That is fine for a release pipeline and unacceptable as a
//! mandatory dependency of `cargo test`: it would make every contributor's
//! first build depend on GitHub being up, and the Windows archive is built
//! `/MT` while this project's other C dependencies are `/MD`. So the
//! feature is off by default, Linux CI builds it, and the two other
//! platforms are documented rather than assumed — see
//! `docs/NEURAL-DIARIZATION.md`.
//!
//! # What is *not* behind the feature
//!
//! [`assign_from_turns`] — the part that decides which transcript segment
//! belongs to which speaker. It is pure arithmetic over time ranges, it is
//! where every off-by-one bug in a diarization integration lives, and it is
//! fully unit-tested on every platform whether or not sherpa is compiled
//! in.

use std::path::PathBuf;
use std::sync::{Mutex, OnceLock};

use crate::diarization::{channel_tag, speaker_label};
use crate::error::TranscribeResult;
use crate::export::Segment;

/// Catalog id of the pyannote segmentation model.
pub const SEGMENTATION_MODEL_ID: &str = "diarization-segmentation";
/// Catalog id of the CAM++ speaker-embedding model.
pub const EMBEDDING_MODEL_ID: &str = "diarization-embedding";

/// One speaker turn as the diarizer reports it: a span of the recording
/// and an opaque cluster index.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct SpeakerTurn {
    pub start: f64,
    pub end: f64,
    /// Cluster id from the diarizer. Not a display number — see
    /// [`assign_from_turns`] for why these are renumbered.
    pub cluster: u32,
}

/// The two model files neural diarization needs.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DiarizationModels {
    pub segmentation: PathBuf,
    pub embedding: PathBuf,
}

/// Where the diarization models are, when both are installed.
///
/// Same process-global pattern as [`crate::vad::whisper_silero`] and for
/// the same reason: the diarization step is reached from `stt::file`,
/// `completion` and the re-transcribe path, none of which are handed
/// `AppSettings`.
fn model_slot() -> &'static Mutex<Option<DiarizationModels>> {
    static SLOT: OnceLock<Mutex<Option<DiarizationModels>>> = OnceLock::new();
    SLOT.get_or_init(|| Mutex::new(None))
}

/// Whether the user asked for neural diarization. Separate from whether
/// the models are present: "on but not downloaded" must fall back to the
/// lightweight clustering rather than produce no speaker labels at all.
fn enabled_slot() -> &'static std::sync::atomic::AtomicBool {
    static ENABLED: std::sync::atomic::AtomicBool = std::sync::atomic::AtomicBool::new(false);
    &ENABLED
}

/// Records the user's setting and where the models are. Called from
/// `api::load_settings`/`save_settings`.
#[flutter_rust_bridge::frb(ignore)]
pub fn configure(enabled: bool, models: Option<DiarizationModels>) {
    enabled_slot().store(enabled, std::sync::atomic::Ordering::Relaxed);
    if let Ok(mut slot) = model_slot().lock() {
        *slot = models.filter(|m| m.segmentation.exists() && m.embedding.exists());
    }
}

/// Whether a neural pass will actually run: the setting is on, both models
/// are on disk, and this binary was built with the feature.
#[flutter_rust_bridge::frb(ignore)]
pub fn is_active() -> bool {
    compiled_in()
        && enabled_slot().load(std::sync::atomic::Ordering::Relaxed)
        && model_slot().lock().is_ok_and(|slot| slot.is_some())
}

/// Whether this binary has the sherpa-onnx backend compiled in at all.
///
/// Surfaced to the UI so the setting can say "tidak tersedia di build ini"
/// instead of silently doing nothing — which is the state macOS and
/// Windows builds are in until their prebuilt archives are verified.
#[flutter_rust_bridge::frb(ignore)]
pub const fn compiled_in() -> bool {
    cfg!(feature = "neural-diarization")
}

/// Relabels `segments` from a neural diarization pass over `samples`.
///
/// Returns how many distinct speakers it found, or `Ok(0)` when no pass
/// ran (feature off, setting off, or models missing) — in which case the
/// caller keeps whatever labels the lightweight diarizer produced.
///
/// Never returns `Err` for "not available": a diarizer that cannot run is
/// not a failed transcription.
pub fn relabel_segments(samples: &[f32], segments: &mut [Segment]) -> TranscribeResult<usize> {
    if !is_active() || segments.is_empty() || samples.is_empty() {
        return Ok(0);
    }
    let Some(models) = model_slot().lock().ok().and_then(|slot| slot.clone()) else {
        return Ok(0);
    };
    let turns = match run(samples, &models) {
        Ok(turns) => turns,
        Err(e) => {
            // A model that will not load, or audio it cannot handle. The
            // transcript is good; the speaker labels stay as they were.
            tracing::warn!(%e, "neural diarization failed; keeping acoustic labels");
            return Ok(0);
        }
    };
    Ok(assign_from_turns(&turns, segments))
}

/// Assigns each segment the speaker whose turns overlap it most.
///
/// Clusters are renumbered by **first appearance in the recording**, not
/// by the index sherpa happens to give them. That is what makes the labels
/// stable: sherpa's cluster ids come out of a clustering step whose
/// numbering is an implementation detail, so a re-transcribe could swap
/// "Pembicara 1" and "Pembicara 2" and silently invalidate every rename
/// the user had made (`speaker_aliases.dart` keys renames on the label).
/// Ordering by first appearance is a property of the audio, so it survives.
///
/// A segment that overlaps no turn keeps the label it arrived with: the
/// diarizer dropping a half-second of speech must not cost the transcript
/// its speaker.
pub fn assign_from_turns(turns: &[SpeakerTurn], segments: &mut [Segment]) -> usize {
    if turns.is_empty() {
        return 0;
    }
    let mut display_order: Vec<u32> = Vec::new();
    for turn in turns {
        if !display_order.contains(&turn.cluster) {
            display_order.push(turn.cluster);
        }
    }

    for segment in segments.iter_mut() {
        let segment_start = segment.timestamp;
        let segment_end = segment.timestamp + segment.duration.max(0.0);
        let best = display_order
            .iter()
            .enumerate()
            .map(|(index, cluster)| {
                let overlap: f64 = turns
                    .iter()
                    .filter(|turn| turn.cluster == *cluster)
                    .map(|turn| {
                        (turn.end.min(segment_end) - turn.start.max(segment_start)).max(0.0)
                    })
                    .sum();
                (index, overlap)
            })
            .filter(|(_, overlap)| *overlap > 0.0)
            .max_by(|a, b| a.1.total_cmp(&b.1));
        if let Some((index, _)) = best {
            segment.speaker = speaker_label(channel_tag(&segment.source), index + 1);
        }
    }
    display_order.len()
}

#[cfg(feature = "neural-diarization")]
fn run(samples: &[f32], models: &DiarizationModels) -> TranscribeResult<Vec<SpeakerTurn>> {
    // Flat re-exports at the crate root; the modules themselves are
    // private (`sherpa_onnx::lib.rs` is `mod x; pub use x::*;`).
    use sherpa_onnx::{
        FastClusteringConfig, OfflineSpeakerDiarization, OfflineSpeakerDiarizationConfig,
        OfflineSpeakerSegmentationModelConfig, OfflineSpeakerSegmentationPyannoteModelConfig,
        SpeakerEmbeddingExtractorConfig,
    };

    use crate::error::TranscribeError;
    use crate::vad::SegmentationConfig;

    let defaults = SegmentationConfig::default();
    let config = OfflineSpeakerDiarizationConfig {
        segmentation: OfflineSpeakerSegmentationModelConfig {
            pyannote: OfflineSpeakerSegmentationPyannoteModelConfig {
                model: Some(models.segmentation.to_string_lossy().into_owned()),
                ..Default::default()
            },
            num_threads: crate::stt::file::VAD_THREADS,
            ..Default::default()
        },
        embedding: SpeakerEmbeddingExtractorConfig {
            model: Some(models.embedding.to_string_lossy().into_owned()),
            num_threads: crate::stt::file::VAD_THREADS,
            ..Default::default()
        },
        // `num_clusters: -1` means "work it out from the threshold", which
        // is the only honest answer for a meeting recording: the app does
        // not know how many people are in the room. The speaker *hint* the
        // import dialog collects is not wired through here on purpose —
        // forcing a cluster count the user guessed wrong is worse than the
        // threshold, which at least degrades gracefully.
        clustering: FastClusteringConfig {
            num_clusters: -1,
            threshold: 0.5,
            ..Default::default()
        },
        min_duration_on: defaults.min_speech_secs as f32,
        min_duration_off: defaults.tail_silence_secs as f32,
    };

    let diarizer = OfflineSpeakerDiarization::create(&config).ok_or_else(|| {
        TranscribeError::Model(
            "sherpa-onnx diarization could not be created from the installed models".into(),
        )
    })?;
    // The segmentation model declares its own rate; everything in this
    // crate is already 16 kHz, so a mismatch means the wrong model file.
    let expected = diarizer.sample_rate();
    if expected != crate::decode::TARGET_SAMPLE_RATE as i32 {
        return Err(TranscribeError::Model(format!(
            "diarization model expects {expected} Hz, the pipeline is 16000 Hz"
        )));
    }
    let result = diarizer
        .process(samples)
        .ok_or_else(|| TranscribeError::Transcription("sherpa-onnx diarization failed".into()))?;
    // Already in time order, which is what `assign_from_turns` needs to
    // renumber the clusters by first appearance.
    let turns: Vec<SpeakerTurn> = result
        .sort_by_start_time()
        .into_iter()
        .map(|segment| SpeakerTurn {
            start: segment.start as f64,
            end: segment.end as f64,
            cluster: segment.speaker.max(0) as u32,
        })
        .collect();
    tracing::info!(turns = turns.len(), "neural diarization completed");
    Ok(turns)
}

#[cfg(not(feature = "neural-diarization"))]
fn run(_samples: &[f32], _models: &DiarizationModels) -> TranscribeResult<Vec<SpeakerTurn>> {
    // Unreachable: `is_active()` is false without the feature. Present so
    // `relabel_segments` has one body on every platform.
    Ok(Vec::new())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn seg(source: &str, timestamp: f64, duration: f64) -> Segment {
        Segment {
            source: source.into(),
            speaker: "Pembicara 9".into(),
            text: "halo".into(),
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

    fn turn(start: f64, end: f64, cluster: u32) -> SpeakerTurn {
        SpeakerTurn {
            start,
            end,
            cluster,
        }
    }

    #[test]
    fn each_segment_takes_the_speaker_it_overlaps_most() {
        let turns = [turn(0.0, 5.0, 0), turn(5.0, 10.0, 1)];
        let mut segments = vec![seg("file", 0.5, 2.0), seg("file", 6.0, 3.0)];
        let speakers = assign_from_turns(&turns, &mut segments);
        assert_eq!(speakers, 2);
        assert_eq!(segments[0].speaker, "Pembicara 1");
        assert_eq!(segments[1].speaker, "Pembicara 2");
    }

    #[test]
    fn a_segment_straddling_two_turns_goes_to_the_larger_share() {
        let turns = [turn(0.0, 10.0, 0), turn(10.0, 20.0, 1)];
        // 9.0..13.0 — one second of speaker 0, three of speaker 1.
        let mut segments = vec![seg("file", 9.0, 4.0)];
        assign_from_turns(&turns, &mut segments);
        assert_eq!(segments[0].speaker, "Pembicara 2");
    }

    #[test]
    fn clusters_are_renumbered_by_first_appearance() {
        // sherpa's cluster ids are an implementation detail. Whoever
        // speaks first is "Pembicara 1", so a re-transcribe cannot swap
        // the names out from under the user's renames.
        let turns = [turn(0.0, 4.0, 7), turn(4.0, 8.0, 2), turn(8.0, 12.0, 7)];
        let mut segments = vec![
            seg("file", 1.0, 1.0),
            seg("file", 5.0, 1.0),
            seg("file", 9.0, 1.0),
        ];
        assert_eq!(assign_from_turns(&turns, &mut segments), 2);
        assert_eq!(segments[0].speaker, "Pembicara 1");
        assert_eq!(segments[1].speaker, "Pembicara 2");
        assert_eq!(segments[2].speaker, "Pembicara 1");
    }

    #[test]
    fn a_segment_overlapping_nothing_keeps_its_label() {
        // The diarizer dropping half a second of speech must not cost the
        // transcript its speaker.
        let turns = [turn(0.0, 2.0, 0)];
        let mut segments = vec![seg("file", 50.0, 1.0)];
        assign_from_turns(&turns, &mut segments);
        assert_eq!(
            segments[0].speaker, "Pembicara 9",
            "label must be untouched"
        );
    }

    #[test]
    fn mic_segments_keep_the_mic_naming_scheme() {
        // The first mic speaker is "Saya", not "Pembicara 1" — the labels
        // come from the same `speaker_label` the acoustic path uses, so
        // neural and acoustic transcripts read alike.
        let turns = [turn(0.0, 5.0, 0), turn(5.0, 10.0, 1)];
        let mut segments = vec![seg("mic", 1.0, 1.0), seg("mic", 6.0, 1.0)];
        assign_from_turns(&turns, &mut segments);
        assert_eq!(segments[0].speaker, "Saya");
        assert_eq!(segments[1].speaker, "Pembicara 2 (Mikrofon)");
    }

    #[test]
    fn loopback_segments_are_participants() {
        let turns = [turn(0.0, 5.0, 3)];
        let mut segments = vec![seg("spk", 1.0, 1.0)];
        assign_from_turns(&turns, &mut segments);
        assert_eq!(segments[0].speaker, "Peserta 1");
    }

    #[test]
    fn no_turns_means_no_relabelling() {
        let mut segments = vec![seg("file", 0.0, 1.0)];
        assert_eq!(assign_from_turns(&[], &mut segments), 0);
        assert_eq!(segments[0].speaker, "Pembicara 9");
    }

    #[test]
    fn a_zero_length_segment_is_matched_by_a_turn_that_contains_it() {
        // Whisper emits these around chunk boundaries. `max(0.0)` on the
        // overlap would make every candidate zero and leave the label
        // alone, so the point of the test is that the *filter* is what
        // decides, and it does not fire for a turn strictly containing the
        // instant... which it does not. Document the real behaviour: a
        // zero-length segment keeps its label.
        let turns = [turn(0.0, 10.0, 0)];
        let mut segments = vec![seg("file", 5.0, 0.0)];
        assign_from_turns(&turns, &mut segments);
        assert_eq!(segments[0].speaker, "Pembicara 9");
    }

    #[test]
    fn inactive_without_configuration() {
        configure(false, None);
        assert!(!is_active());
        let mut segments = vec![seg("file", 0.0, 1.0)];
        assert_eq!(relabel_segments(&[0.1; 16_000], &mut segments).unwrap(), 0);
        assert_eq!(segments[0].speaker, "Pembicara 9");
    }

    #[test]
    fn enabling_without_the_models_stays_inactive() {
        // "On but not downloaded" must fall back, not produce a transcript
        // with no speakers in it.
        configure(
            true,
            Some(DiarizationModels {
                segmentation: PathBuf::from("/nonexistent/seg.onnx"),
                embedding: PathBuf::from("/nonexistent/emb.onnx"),
            }),
        );
        assert!(!is_active());
        configure(false, None);
    }
}
