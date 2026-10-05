//! Multi-Speaker Acoustic Diarization Module.
//!
//! Provides two backends:
//! 1. **Pure Rust clustering** (default) — uses ZCR, pitch proxy, and RMS energy
//!    to distinguish speakers. Works offline, no external dependencies.
//! 2. **pyannote.audio** (optional) — Python-based neural diarization via
//!    `scripts/pyannote_audio.py`. More accurate for overlapping speakers.

#[cfg(feature = "pyannote")]
use serde::{Deserialize, Serialize};
#[cfg(feature = "pyannote")]
use std::process::Command;

#[derive(Debug, Clone)]
pub struct SpeakerCluster {
    pub id: String,
    pub channel: String,
    pub centroid_pitch: f32,
    pub centroid_energy: f32,
    pub centroid_zcr: f32,
    pub sample_count: u32,
}

pub struct Diarizer {
    mic_clusters: Vec<SpeakerCluster>,
    spk_clusters: Vec<SpeakerCluster>,
    /// Upper bound on clusters per channel, when the user told us how
    /// many people are in the recording (F10).
    ///
    /// The acoustic features here are crude — pitch proxy, energy, ZCR —
    /// so one person recorded across a long meeting reliably splits into
    /// three or four "speakers". A notulis importing a file usually
    /// knows the real number, and that one piece of information is worth
    /// more than any amount of threshold tuning: once the budget is
    /// spent, a new voice joins its nearest existing cluster instead of
    /// inventing "Pembicara 7".
    max_speakers: Option<usize>,
}

impl Default for Diarizer {
    fn default() -> Self {
        Self::new()
    }
}

impl Diarizer {
    pub fn new() -> Self {
        Self {
            mic_clusters: Vec::new(),
            spk_clusters: Vec::new(),
            max_speakers: None,
        }
    }

    /// A diarizer that will never report more than `max` speakers per
    /// channel. `0` means "no hint" rather than "no speakers", because a
    /// zero arriving from a UI spinner must not silence the transcript.
    #[flutter_rust_bridge::frb(ignore)]
    pub fn with_max_speakers(max: usize) -> Self {
        Self {
            max_speakers: (max > 0).then_some(max),
            ..Self::new()
        }
    }

    /// Identifies or clusters the human speaker for a given audio PCM slice and channel.
    pub fn identify_speaker(&mut self, channel: &str, pcm_samples: &[f32]) -> String {
        let channel_tag = channel_tag(channel);

        if pcm_samples.is_empty() {
            return speaker_label(channel_tag, 1);
        }

        let (pitch, energy, zcr) = extract_acoustic_features(pcm_samples);

        let clusters = match channel_tag {
            ChannelTag::Mic => &mut self.mic_clusters,
            ChannelTag::Speaker | ChannelTag::File => &mut self.spk_clusters,
        };

        let threshold = 0.22;
        let mut best_match: Option<(usize, f32)> = None;

        for (idx, cluster) in clusters.iter().enumerate() {
            let p_diff = cluster.centroid_pitch - pitch;
            let e_diff = cluster.centroid_energy - energy;
            let z_diff = cluster.centroid_zcr - zcr;
            let dist = (p_diff * p_diff + e_diff * e_diff + z_diff * z_diff).sqrt();

            if dist < threshold && best_match.is_none_or(|(_, min_dist)| dist < min_dist) {
                best_match = Some((idx, dist));
            }
        }

        // Budget spent: fold this window into whichever cluster is
        // closest, even past the threshold. Without this the hint would
        // only ever be advisory.
        if best_match.is_none()
            && self
                .max_speakers
                .is_some_and(|max| clusters.len() >= max.max(1))
        {
            best_match = clusters
                .iter()
                .enumerate()
                .map(|(idx, cluster)| {
                    let p_diff = cluster.centroid_pitch - pitch;
                    let e_diff = cluster.centroid_energy - energy;
                    let z_diff = cluster.centroid_zcr - zcr;
                    (
                        idx,
                        (p_diff * p_diff + e_diff * e_diff + z_diff * z_diff).sqrt(),
                    )
                })
                .min_by(|a, b| a.1.total_cmp(&b.1));
        }

        if let Some((idx, _)) = best_match {
            let cluster = &mut clusters[idx];
            cluster.sample_count += 1;
            let n = cluster.sample_count as f32;
            cluster.centroid_pitch = (cluster.centroid_pitch * (n - 1.0) + pitch) / n;
            cluster.centroid_energy = (cluster.centroid_energy * (n - 1.0) + energy) / n;
            cluster.centroid_zcr = (cluster.centroid_zcr * (n - 1.0) + zcr) / n;
            speaker_label(channel_tag, idx + 1)
        } else {
            let new_id = speaker_label(channel_tag, clusters.len() + 1);
            clusters.push(SpeakerCluster {
                id: new_id.clone(),
                channel: channel_tag.as_str().to_string(),
                centroid_pitch: pitch,
                centroid_energy: energy,
                centroid_zcr: zcr,
                sample_count: 1,
            });
            new_id
        }
    }
}

/// Which capture channel a PCM slice came from. Decides the label wording:
/// the microphone is the person using the app, the loopback is everyone else.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ChannelTag {
    Mic,
    Speaker,
    /// An imported file — no mic/system distinction available.
    File,
}

impl ChannelTag {
    pub fn as_str(self) -> &'static str {
        match self {
            ChannelTag::Mic => "MIC",
            ChannelTag::Speaker => "SPK",
            ChannelTag::File => "FILE",
        }
    }
}

/// Maps a pipeline source string (`"mic"`, `"spk"`, `"file"`) to a tag.
pub fn channel_tag(channel: &str) -> ChannelTag {
    let lower = channel.to_lowercase();
    if lower.contains("spk") || lower.contains("speaker") {
        ChannelTag::Speaker
    } else if lower.contains("file") {
        ChannelTag::File
    } else {
        ChannelTag::Mic
    }
}

/// Indonesian speaker label for cluster `n` (1-based) on `tag`.
///
/// Meetily-parity requirement: a reader must be able to tell "me" from "the
/// other participants" at a glance, so the mic's primary cluster is `Saya`
/// and loopback clusters are `Peserta N`. Extra mic clusters (a second
/// person sharing the same microphone) stay explicit rather than being
/// silently folded into `Saya`.
pub fn speaker_label(tag: ChannelTag, n: usize) -> String {
    match (tag, n) {
        (ChannelTag::Mic, 1) => "Saya".to_string(),
        (ChannelTag::Mic, n) => format!("Pembicara {n} (Mikrofon)"),
        (ChannelTag::Speaker, n) => format!("Peserta {n}"),
        (ChannelTag::File, n) => format!("Pembicara {n}"),
    }
}

/// Extract fundamental pitch frequency proxy, RMS volume, and Zero Crossing Rate (ZCR).
fn extract_acoustic_features(pcm: &[f32]) -> (f32, f32, f32) {
    if pcm.is_empty() {
        return (0.0, 0.0, 0.0);
    }

    let energy: f32 = (pcm.iter().map(|s| s * s).sum::<f32>() / pcm.len() as f32).sqrt();

    let zcr = pcm
        .windows(2)
        .filter(|w| (w[0] >= 0.0 && w[1] < 0.0) || (w[0] < 0.0 && w[1] >= 0.0))
        .count() as f32
        / pcm.len() as f32;

    let mut max_corr = 0.0f32;
    let max_lag = (pcm.len() / 2).min(160);
    if max_lag > 10 {
        for lag in 10..max_lag {
            let mut sum = 0.0f32;
            for window in pcm.windows(lag + 1) {
                sum += window[0] * window[lag];
            }
            if sum > max_corr {
                max_corr = sum;
            }
        }
    }
    let pitch_proxy = if !pcm.is_empty() {
        max_corr / pcm.len() as f32
    } else {
        0.0
    };

    (pitch_proxy, energy, zcr)
}

// ─── pyannote.audio integration ───────────────────────────────────────────────

#[cfg(feature = "pyannote")]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DiarizationResult {
    pub segments: Vec<SpeakerSegment>,
}

#[cfg(feature = "pyannote")]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SpeakerSegment {
    pub start: f64,
    pub end: f64,
    pub speaker: String,
    pub confidence: f32,
}

/// Run pyannote.audio v3.3 speaker diarization via Python subprocess.
///
/// Requires `pyannote.audio`, `pyannote.database`, and a trained model to be installed.
///
/// `audio_path` — path to 16kHz mono WAV audio file.
/// `output_path` — path to write RTTM output (optional, pass "" to skip file write).
///
/// Returns parsed `DiarizationResult` with speaker segments.
#[cfg(feature = "pyannote")]
pub fn run_pyannote(audio_path: &str, output_path: &str) -> Result<DiarizationResult, String> {
    let script = format!(
        r#"
import sys
import json
sys.path.insert(0, 'scripts')
try:
    from pyannote_audio import transcribe_with_diarization
    result = transcribe_with_diarization('{}', '{}')
    print(json.dumps(result))
except ImportError:
    print(json.dumps({{'error': 'pyannote.audio not installed', 'segments': []}}))
except Exception as e:
    print(json.dumps({{'error': str(e), 'segments': []}}))
"#,
        audio_path.replace("'", "'\"'\"'"),
        output_path.replace("'", "'\"'\"'")
    );

    let output = Command::new("python3")
        .args(["-c", &script])
        .output()
        .map_err(|e| format!("failed to spawn python3: {e}"))?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(format!("pyannote script failed: {stderr}"));
    }

    let stdout = String::from_utf8_lossy(&output.stdout);

    serde_json::from_str::<serde_json::Value>(&stdout)
        .map_err(|e| format!("failed to parse pyannote JSON: {e}"))
        .map(|v| {
            let segments: Vec<SpeakerSegment> = v
                .get("segments")
                .and_then(|s| s.as_array())
                .map(|arr| {
                    arr.iter()
                        .filter_map(|seg| {
                            Some(SpeakerSegment {
                                start: seg.get("start")?.as_f64()?,
                                end: seg.get("end")?.as_f64()?,
                                speaker: seg.get("speaker")?.as_str()?.to_string(),
                                confidence: seg
                                    .get("confidence")?
                                    .as_f64()
                                    .map(|v| v as f32)
                                    .unwrap_or(1.0),
                            })
                        })
                        .collect()
                })
                .unwrap_or_default();
            DiarizationResult { segments }
        })
        .map_err(|e| e.to_string())
}

/// Assigns a speaker label to every segment of a single-channel recording
/// (an imported file), by clustering the PCM window each segment covers.
///
/// `samples` must be 16 kHz mono — the rate every decode path targets. A
/// segment whose window falls outside the buffer (rounding at the tail) is
/// clustered on whatever samples remain, and on nothing at all it falls back
/// to the first cluster rather than being left unlabelled.
pub fn label_segments(
    diarizer: &mut Diarizer,
    samples: &[f32],
    segments: &mut [crate::export::Segment],
) {
    const SAMPLE_RATE: f64 = 16_000.0;
    for segment in segments.iter_mut() {
        let start = (segment.timestamp * SAMPLE_RATE).max(0.0) as usize;
        let end = ((segment.timestamp + segment.duration) * SAMPLE_RATE).max(0.0) as usize;
        let window = samples
            .get(start.min(samples.len())..end.min(samples.len()))
            .unwrap_or(&[]);
        segment.speaker = diarizer.identify_speaker(&segment.source, window);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn seg(timestamp: f64, duration: f64, source: &str) -> crate::export::Segment {
        crate::export::Segment {
            source: source.to_string(),
            speaker: String::new(),
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

    #[test]
    fn clusters_distinct_pitch_profiles_into_separate_speakers() {
        let mut diarizer = Diarizer::new();
        let low_pitch_pcm = vec![0.5, -0.5, 0.5, -0.5, 0.5, -0.5, 0.5, -0.5];
        let high_pitch_pcm = vec![0.5, 0.5, 0.5, 0.5, -0.5, -0.5, -0.5, -0.5];

        let spk1 = diarizer.identify_speaker("MIC", &low_pitch_pcm);
        let spk2 = diarizer.identify_speaker("MIC", &high_pitch_pcm);

        assert_eq!(spk1, "Saya");
        assert_eq!(spk2, "Pembicara 2 (Mikrofon)");
    }

    #[test]
    fn groups_similar_acoustics_to_same_speaker() {
        let mut diarizer = Diarizer::new();
        let pcm_a1 = vec![0.4, -0.4, 0.4, -0.4, 0.4, -0.4, 0.4, -0.4];
        let pcm_a2 = vec![0.42, -0.38, 0.41, -0.39, 0.4, -0.4, 0.42, -0.38];

        let spk1 = diarizer.identify_speaker("SPK", &pcm_a1);
        let spk2 = diarizer.identify_speaker("SPK", &pcm_a2);

        assert_eq!(spk1, "Peserta 1");
        assert_eq!(spk2, "Peserta 1");
    }

    #[test]
    fn lowercase_channel_names_are_tagged_correctly() {
        let mut diarizer = Diarizer::new();
        let mic_pcm = vec![0.5, -0.5, 0.5, -0.5, 0.5, -0.5, 0.5, -0.5];
        let spk_pcm = vec![0.4, -0.4, 0.4, -0.4, 0.4, -0.4, 0.4, -0.4];

        assert_eq!(diarizer.identify_speaker("mic", &mic_pcm), "Saya");
        assert_eq!(diarizer.identify_speaker("spk", &spk_pcm), "Peserta 1");
    }

    #[test]
    fn mic_and_speaker_cluster_pools_are_independent() {
        // Identical audio on both channels must not collapse into one label:
        // the whole point of "Saya" vs "Peserta" is the channel distinction.
        let mut diarizer = Diarizer::new();
        let pcm = vec![0.4, -0.4, 0.4, -0.4, 0.4, -0.4, 0.4, -0.4];
        assert_eq!(diarizer.identify_speaker("mic", &pcm), "Saya");
        assert_eq!(diarizer.identify_speaker("spk", &pcm), "Peserta 1");
    }

    #[test]
    fn imported_files_get_neutral_pembicara_labels() {
        let mut diarizer = Diarizer::new();
        let pcm = vec![0.4, -0.4, 0.4, -0.4, 0.4, -0.4, 0.4, -0.4];
        assert_eq!(diarizer.identify_speaker("file", &pcm), "Pembicara 1");
    }

    #[test]
    fn empty_pcm_still_yields_a_label() {
        let mut diarizer = Diarizer::new();
        assert_eq!(diarizer.identify_speaker("mic", &[]), "Saya");
        assert_eq!(diarizer.identify_speaker("spk", &[]), "Peserta 1");
    }

    #[test]
    fn label_segments_assigns_a_speaker_to_every_segment() {
        let mut diarizer = Diarizer::new();
        // 3 s of 16 kHz audio: first second one timbre, then a different one.
        let mut samples = vec![0.0f32; 48_000];
        for (i, s) in samples.iter_mut().enumerate() {
            *s = if i < 16_000 {
                if i % 2 == 0 {
                    0.5
                } else {
                    -0.5
                }
            } else if i % 8 < 4 {
                0.5
            } else {
                -0.5
            };
        }
        let mut segments = vec![seg(0.0, 1.0, "file"), seg(1.0, 2.0, "file")];
        label_segments(&mut diarizer, &samples, &mut segments);

        assert!(segments.iter().all(|s| s.speaker.starts_with("Pembicara")));
        assert_ne!(
            segments[0].speaker, segments[1].speaker,
            "clearly different timbres should not share a cluster"
        );
    }

    #[test]
    fn label_segments_tolerates_windows_past_the_end_of_the_buffer() {
        let mut diarizer = Diarizer::new();
        let samples = vec![0.3f32; 16_000]; // 1 s
        let mut segments = vec![seg(0.9, 5.0, "file"), seg(60.0, 1.0, "file")];
        label_segments(&mut diarizer, &samples, &mut segments);
        assert!(segments.iter().all(|s| !s.speaker.is_empty()));
    }

    #[cfg(feature = "pyannote")]
    #[test]
    fn pyannote_result_deserializes() {
        let json =
            r#"{"segments":[{"start":0.0,"end":5.0,"speaker":"SPEAKER_00","confidence":0.95}]}"#;
        let v: DiarizationResult = serde_json::from_str(json).unwrap();
        assert_eq!(v.segments.len(), 1);
        assert_eq!(v.segments[0].speaker, "SPEAKER_00");
    }
}
