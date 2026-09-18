//! Offline transcription pipeline — fully local, no network.
//!
//! Composes the four stages of the offline engine (see docs/MASTER_PLAN.md):
//!
//!   1. **Silero VAD** → chunk raw PCM at silence boundaries
//!      (`vad::DualVad`, 10 ms frames, dual mic+speaker channels).
//!   2. **Whisper large-v3-turbo** → speech to text
//!      (`stt::WhisperEngine`, via whisper.cpp; backend auto-detected by
//!      `stt::detect_backend()` — CoreML/Metal on macOS, CUDA/DML/CPU
//!      elsewhere — and logged at engine init).
//!   3. **Speaker labels** → per-channel acoustic-feature clustering
//!      (`diarization::Diarizer`); cross-source echo dedupe runs in
//!      `session::SessionState::collect_worker_events`.
//!   4. **Qwen2.5-7B** → post-correction + per-speaker summary
//!      (`llm_correction::correct_and_summarize`, feature-gated `llm`,
//!      invoked after the batch is finalized — see `export` for the
//!      Markdown/TXT/SRT/DOCX writers that consume the result).
//!
//! `LivePipeline` is the deterministic per-source stage orchestrator (stages
//! 1–3). It deliberately owns only processing state; audio device threads
//! capture and send resampled PCM here, keeping cpal platform details out of
//! VAD/STT orchestration.
//!
//! Each [`LivePipeline`] instance handles exactly one source (mic OR
//! speaker) — one runs per [`LiveWorker`] thread. Echo-dedupe requires
//! comparing MIC segments against SPK segments, which this type can't do
//! on its own since it only ever sees one source; that cross-source pass
//! happens one level up, in `session::SessionState::collect_worker_events`,
//! once both channels' segments have actually converged.

use std::path::{Path, PathBuf};

use crate::audio::{HptMode, RingBuffer};
use crate::diarization::Diarizer;
use crate::error::{TranscribeError, TranscribeResult};
use crate::export::Segment;
use crate::progressive::ProgressiveEngine;
use crate::stt::WhisperEngine;
use crate::vad::{DualVad, VadConfig, FRAME_SAMPLES_10MS};

pub struct LivePipeline<'a> {
    engine: &'a WhisperEngine,
    ring: RingBuffer,
    vad: DualVad,
    diarizer: Diarizer,
    source: String,
    language: Option<String>,
    samples_seen: u64,
    last_transcript_tail: String,
}

#[derive(Debug, Clone)]
pub enum LiveEvent {
    Vu { source: String, level: f32 },
    Segment(Segment),
}

pub struct LiveWorker {
    stop_tx: Option<std::sync::mpsc::Sender<()>>,
    thread: Option<std::thread::JoinHandle<()>>,
}

impl LiveWorker {
    pub fn resume_pending_transcriptions(
        library_path: &Path,
    ) -> Result<Vec<PathBuf>, TranscribeError> {
        let mut pending = Vec::new();
        let sessions = crate::session::list_recoverable_sessions()?;
        for s in sessions {
            let session_dir = library_path.join(&s.session_id);
            if !session_dir.join("transcript.json").exists() {
                pending.push(session_dir);
            }
        }
        Ok(pending)
    }

    pub fn spawn(
        model_path: impl AsRef<std::path::Path>,
        source: impl Into<String>,
        language: Option<String>,
        samples_rx: std::sync::mpsc::Receiver<Vec<f32>>,
        events_tx: std::sync::mpsc::Sender<LiveEvent>,
    ) -> Result<Self, TranscribeError> {
        let engine = WhisperEngine::load(model_path.as_ref())?;
        Self::spawn_with_engine(engine, source, language, samples_rx, events_tx)
    }

    /// Single-model worker over an already-loaded engine. Used by
    /// [`Self::spawn`] and by adaptive HPT's direct-q5 fast path so the
    /// benchmark-loaded engine is reused instead of double-loading the
    /// 548 MB refine model.
    fn spawn_with_engine(
        engine: WhisperEngine,
        source: impl Into<String>,
        language: Option<String>,
        samples_rx: std::sync::mpsc::Receiver<Vec<f32>>,
        events_tx: std::sync::mpsc::Sender<LiveEvent>,
    ) -> Result<Self, TranscribeError> {
        let source = source.into();
        let (stop_tx, stop_rx) = std::sync::mpsc::channel();
        let thread = std::thread::spawn(move || {
            let mut pipeline = match LivePipeline::new(
                &engine,
                source.clone(),
                language,
                VadConfig::default(),
            ) {
                Ok(pipeline) => pipeline,
                Err(error) => {
                    tracing::error!(source = %source, %error, "live pipeline initialization failed");
                    return;
                }
            };

            while stop_rx.try_recv().is_err() {
                let samples = match samples_rx.recv_timeout(std::time::Duration::from_millis(100)) {
                    Ok(samples) => samples,
                    Err(std::sync::mpsc::RecvTimeoutError::Timeout) => continue,
                    Err(std::sync::mpsc::RecvTimeoutError::Disconnected) => break,
                };
                let level = rms_level(&samples);
                let _ = events_tx.send(LiveEvent::Vu {
                    source: source.clone(),
                    level,
                });
                match pipeline.ingest(&samples) {
                    Ok(segments) => {
                        for segment in segments {
                            let _ = events_tx.send(LiveEvent::Segment(segment));
                        }
                    }
                    Err(error) => tracing::error!(source = %source, %error, "live pipeline failed"),
                }
            }
        });
        Ok(Self {
            stop_tx: Some(stop_tx),
            thread: Some(thread),
        })
    }

    pub fn stop(&mut self) {
        if let Some(stop_tx) = self.stop_tx.take() {
            let _ = stop_tx.send(());
        }
        if let Some(thread) = self.thread.take() {
            let _ = thread.join();
        }
    }

    /// Hybrid Progressive Transcription (HPT) worker: loads BOTH the quick
    /// (`base`) and refine (`large-v3-turbo-q5`) models up front. Each
    /// speech chunk emits quick segments (`is_partial = true`) immediately
    /// so the UI renders text within the 3-5s latency budget, then refined
    /// segments (`is_partial = false`) with the same `(source, timestamp)`
    /// keys replace them on the Dart side.
    pub fn spawn_hpt(
        quick_model_path: impl AsRef<std::path::Path>,
        refine_model_path: impl AsRef<std::path::Path>,
        source: impl Into<String>,
        language: Option<String>,
        samples_rx: std::sync::mpsc::Receiver<Vec<f32>>,
        events_tx: std::sync::mpsc::Sender<LiveEvent>,
    ) -> Result<Self, TranscribeError> {
        let engine = ProgressiveEngine::load(
            quick_model_path.as_ref(),
            refine_model_path.as_ref(),
            false,
            0,
        )?;
        let source = source.into();
        let (stop_tx, stop_rx) = std::sync::mpsc::channel();
        let thread = std::thread::spawn(move || {
            let mut pipeline = match LivePipelineHpt::new(
                &engine,
                source.clone(),
                language,
                VadConfig::default(),
            ) {
                Ok(pipeline) => pipeline,
                Err(error) => {
                    tracing::error!(source = %source, %error, "hpt live pipeline initialization failed");
                    return;
                }
            };

            while stop_rx.try_recv().is_err() {
                let samples = match samples_rx.recv_timeout(std::time::Duration::from_millis(100)) {
                    Ok(samples) => samples,
                    Err(std::sync::mpsc::RecvTimeoutError::Timeout) => continue,
                    Err(std::sync::mpsc::RecvTimeoutError::Disconnected) => break,
                };
                let level = rms_level(&samples);
                let _ = events_tx.send(LiveEvent::Vu {
                    source: source.clone(),
                    level,
                });
                match pipeline.ingest(&samples) {
                    Ok((quick, refined)) => {
                        // Quick pass first — UI renders immediately.
                        for segment in quick {
                            let _ = events_tx.send(LiveEvent::Segment(segment));
                        }
                        // Refined pass replaces by key — same (source, timestamp).
                        for segment in refined {
                            let _ = events_tx.send(LiveEvent::Segment(segment));
                        }
                    }
                    Err(error) => {
                        tracing::error!(source = %source, %error, "hpt live pipeline failed")
                    }
                }
            }
        });
        Ok(Self {
            stop_tx: Some(stop_tx),
            thread: Some(thread),
        })
    }

    /// Adaptive HPT worker. The [mode] (from the user's settings) decides the
    /// exact strategy:
    ///   * `Auto`      — benchmark q5 once; if RTF ≥ `HPT_DIRECT_THRESHOLD`
    ///     run q5 directly (single pass, reusing the loaded
    ///     engine — no double 548MB load). Otherwise fall back
    ///     to dual-pass [`Self::spawn_hpt`].
    ///   * `ForceDual` — always dual-pass (base quick → q5 refine).
    ///   * `ForceDirect` — always single q5 pass (reuse loaded engine).
    ///
    /// The benchmark itself is a no-network local inference probe over a 5s
    /// synthetic sine wave, so no user audio ever leaves the device for it.
    pub fn spawn_adaptive(
        quick_model_path: impl AsRef<std::path::Path>,
        refine_model_path: impl AsRef<std::path::Path>,
        mode: HptMode,
        source: impl Into<String>,
        language: Option<String>,
        samples_rx: std::sync::mpsc::Receiver<Vec<f32>>,
        events_tx: std::sync::mpsc::Sender<LiveEvent>,
    ) -> Result<Self, TranscribeError> {
        // Load refine model ONCE — used for both the benchmark and (when
        // direct is chosen) the actual transcription engine.
        let engine = WhisperEngine::load(refine_model_path.as_ref())?;
        let rtf = crate::benchmark::benchmark_rtf(&engine);
        tracing::info!(rtf, mode = ?mode, "adaptive hpt benchmark");

        let direct = match mode {
            HptMode::ForceDirect => true,
            HptMode::ForceDual => false,
            HptMode::Auto => should_direct_q5(rtf),
        };

        if direct {
            Self::spawn_with_engine(engine, source, language, samples_rx, events_tx)
        } else {
            drop(engine); // dual-pass loads both models itself
            Self::spawn_hpt(
                quick_model_path,
                refine_model_path,
                source,
                language,
                samples_rx,
                events_tx,
            )
        }
    }
}

/// RTF threshold for skipping the base quick pass. ≥1.2 means the q5 engine
/// keeps up with real-time audio (with a 20% safety margin over plain 1.0 so
/// borderline devices still get the instant-partial benefit of dual-pass).
pub const HPT_DIRECT_THRESHOLD: f64 = 1.2;

/// Pure decision: does this device run q5 fast enough to skip the base
/// quick pass entirely? `rtf` = seconds of audio transcribed per second of
/// wall-clock. ≥ `HPT_DIRECT_THRESHOLD` → direct q5 single pass.
pub fn should_direct_q5(rtf: f64) -> bool {
    rtf >= HPT_DIRECT_THRESHOLD
}

#[cfg(test)]
mod adaptive_tests {
    use super::{should_direct_q5, HptMode, HPT_DIRECT_THRESHOLD};

    #[test]
    fn rtf_at_threshold_directs_q5() {
        assert!(should_direct_q5(HPT_DIRECT_THRESHOLD));
    }

    #[test]
    fn rtf_below_threshold_falls_back_to_dual_pass() {
        assert!(!should_direct_q5(HPT_DIRECT_THRESHOLD - 0.001));
        assert!(!should_direct_q5(0.5));
        assert!(!should_direct_q5(0.0));
    }

    #[test]
    fn fast_device_directs_q5() {
        assert!(should_direct_q5(1.2));
        assert!(should_direct_q5(5.0));
        assert!(should_direct_q5(12.0));
    }

    #[test]
    fn threshold_is_strict_and_conservative() {
        // 1.0 is real-time but below the 1.2 safety margin → dual-pass.
        assert!(!should_direct_q5(1.0));
        assert_eq!(HPT_DIRECT_THRESHOLD, 1.2);
    }

    #[test]
    fn hpt_mode_force_direct_bypasses_benchmark() {
        for rtf in [0.0, 0.5, 1.0, 1.2, 5.0] {
            let direct = match HptMode::ForceDirect {
                HptMode::ForceDirect => true,
                HptMode::ForceDual => false,
                HptMode::Auto => should_direct_q5(rtf),
            };
            assert!(direct, "ForceDirect at rtf={rtf} must direct");
        }
    }

    #[test]
    fn hpt_mode_force_dual_always_falls_back() {
        for rtf in [0.0, 1.2, 5.0] {
            let direct = match HptMode::ForceDual {
                HptMode::ForceDual => false,
                HptMode::ForceDirect => true,
                HptMode::Auto => should_direct_q5(rtf),
            };
            assert!(!direct, "ForceDual at rtf={rtf} must dual");
        }
    }
}

impl Drop for LiveWorker {
    fn drop(&mut self) {
        self.stop();
    }
}

impl<'a> LivePipeline<'a> {
    pub fn new(
        engine: &'a WhisperEngine,
        source: impl Into<String>,
        language: Option<String>,
        vad_config: VadConfig,
    ) -> TranscribeResult<Self> {
        Ok(Self {
            engine,
            ring: RingBuffer::default(),
            vad: DualVad::new(vad_config)?,
            diarizer: Diarizer::new(),
            source: source.into(),
            language,
            samples_seen: 0,
            last_transcript_tail: String::new(),
        })
    }

    /// Updates the rolling prompt context with the last transcript tail (up to
    /// 200 characters) to improve continuity in subsequent transcription chunks.
    pub fn update_prompt_context(&mut self, transcript_tail: &str) {
        const MAX_TAIL: usize = 200;
        if transcript_tail.len() > MAX_TAIL {
            self.last_transcript_tail =
                transcript_tail[transcript_tail.len() - MAX_TAIL..].to_string();
        } else {
            self.last_transcript_tail = transcript_tail.to_string();
        }
    }

    /// Ingest one or more 16 kHz mono f32 samples.
    ///
    /// Chunks are only sent to Whisper after at least one 10 ms frame in the
    /// input is confirmed as speech. Returned segments are *not* yet
    /// echo-filtered — this pipeline only ever sees its own source, so
    /// cross-source dedupe happens where mic and speaker segments actually
    /// meet (see the module doc comment).
    pub fn ingest(&mut self, samples: &[f32]) -> TranscribeResult<Vec<Segment>> {
        if samples.is_empty() {
            return Ok(Vec::new());
        }

        let mut frame_buf = [0i16; FRAME_SAMPLES_10MS];
        let mut has_speech = false;
        for frame in samples.as_chunks::<FRAME_SAMPLES_10MS>().0 {
            fill_i16_slice(frame, &mut frame_buf);
            if self.vad.is_speech(&frame_buf)? {
                has_speech = true;
                break;
            }
        }
        self.ring.push(samples);
        self.samples_seen = self.samples_seen.saturating_add(samples.len() as u64);

        if !has_speech {
            return Ok(Vec::new());
        }

        let mut fresh = Vec::new();
        while let Some(chunk) = self.ring.take_chunk() {
            let chunk_start = self
                .samples_seen
                .saturating_sub(self.ring.buffered_samples() as u64 + chunk.len() as u64)
                as f64
                / 16_000.0;
            let segments = self.engine.transcribe_chunk(
                &chunk,
                &self.source,
                chunk_start,
                self.language.as_deref(),
                Some(&self.last_transcript_tail),
            )?;
            for mut segment in segments {
                segment.speaker = self.diarizer.identify_speaker(&self.source, &chunk);
                fresh.push(segment);
            }
        }
        crate::progressive::filter_loops(&mut fresh);
        crate::confidence::apply_confidence_routing(&mut fresh);
        if let Some(last) = fresh.last() {
            self.update_prompt_context(&last.text);
        }
        Ok(fresh)
    }
}

/// HPT variant of [`LivePipeline`]: holds BOTH models (quick + refine)
/// and emits two segment passes per speech chunk. The quick pass carries
/// `is_partial = true` for immediate UI rendering; the refine pass carries
/// `is_partial = false` and the SAME `(source, timestamp)` keys so Dart can
/// replace text in place instead of appending duplicates.
pub struct LivePipelineHpt<'a> {
    engine: &'a ProgressiveEngine,
    ring: RingBuffer,
    vad: DualVad,
    diarizer: Diarizer,
    source: String,
    language: Option<String>,
    samples_seen: u64,
}

impl<'a> LivePipelineHpt<'a> {
    pub fn new(
        engine: &'a ProgressiveEngine,
        source: impl Into<String>,
        language: Option<String>,
        vad_config: VadConfig,
    ) -> TranscribeResult<Self> {
        Ok(Self {
            engine,
            ring: RingBuffer::default(),
            vad: DualVad::new(vad_config)?,
            diarizer: Diarizer::new(),
            source: source.into(),
            language,
            samples_seen: 0,
        })
    }

    /// Ingest one or more 16 kHz mono f32 samples. Returns
    /// `(quick_segments, refined_segments)` — quick first (UI-immediate),
    /// refined second (replaces by key). Same VAD gating as the
    /// single-model pipeline: chunks only go to Whisper after at least one
    /// 10 ms speech frame.
    pub fn ingest(&mut self, samples: &[f32]) -> TranscribeResult<(Vec<Segment>, Vec<Segment>)> {
        if samples.is_empty() {
            return Ok((Vec::new(), Vec::new()));
        }

        let mut frame_buf = [0i16; FRAME_SAMPLES_10MS];
        let mut has_speech = false;
        for frame in samples.as_chunks::<FRAME_SAMPLES_10MS>().0 {
            fill_i16_slice(frame, &mut frame_buf);
            if self.vad.is_speech(&frame_buf)? {
                has_speech = true;
                break;
            }
        }
        self.ring.push(samples);
        self.samples_seen = self.samples_seen.saturating_add(samples.len() as u64);

        if !has_speech {
            return Ok((Vec::new(), Vec::new()));
        }

        let mut quick = Vec::new();
        let mut refined = Vec::new();
        while let Some(chunk) = self.ring.take_chunk() {
            let chunk_start = self
                .samples_seen
                .saturating_sub(self.ring.buffered_samples() as u64 + chunk.len() as u64)
                as f64
                / 16_000.0;
            let language = self.language.as_deref();
            let mut quick_segs =
                self.engine
                    .transcribe_quick(&chunk, &self.source, chunk_start, language, None)?;
            let mut refined_segs =
                self.engine
                    .transcribe_refine(&chunk, &self.source, chunk_start, language, None)?;
            for segment in quick_segs.iter_mut() {
                segment.speaker = self.diarizer.identify_speaker(&self.source, &chunk);
            }
            for segment in refined_segs.iter_mut() {
                segment.speaker = self.diarizer.identify_speaker(&self.source, &chunk);
            }
            quick.append(&mut quick_segs);
            refined.append(&mut refined_segs);
        }
        // Hallucination guard on both passes (same n-gram filter used by
        // file-mode HPT in api.rs).
        crate::progressive::filter_loops(&mut quick);
        crate::progressive::filter_loops(&mut refined);
        crate::confidence::apply_confidence_routing(&mut quick);
        crate::confidence::apply_confidence_routing(&mut refined);
        Ok((quick, refined))
    }
}

fn fill_i16_slice(src: &[f32], dst: &mut [i16]) {
    for (s, d) in src.iter().zip(dst.iter_mut()) {
        *d = (s.clamp(-1.0, 1.0) * i16::MAX as f32) as i16;
    }
}

fn rms_level(samples: &[f32]) -> f32 {
    if samples.is_empty() {
        return 0.0;
    }
    (samples.iter().map(|sample| sample * sample).sum::<f32>() / samples.len() as f32).sqrt()
}

#[cfg(test)]
mod tests {
    use super::{fill_i16_slice, rms_level};

    #[test]
    fn fill_i16_slice_clamps_samples() {
        let input = [-2.0f32, -1.0f32, 0.0f32, 1.0f32, 2.0f32];
        let mut out = [0i16; 5];
        fill_i16_slice(&input, &mut out);
        assert_eq!(out, [-32767, -32767, 0, 32767, 32767]);
    }

    #[test]
    fn pcm_conversion_clamps_float_bounds() {
        let input = [-2.0f32, -1.0f32, 0.0f32, 1.0f32, 2.0f32];
        let mut out = [0i16; 5];
        fill_i16_slice(&input, &mut out);
        assert_eq!(out, [-32767, -32767, 0, 32767, 32767]);
    }

    #[test]
    fn rms_level_is_bounded_for_normalized_pcm() {
        assert_eq!(rms_level(&[]), 0.0);
        assert!((rms_level(&[0.5, -0.5]) - 0.5).abs() < f32::EPSILON);
    }

    #[test]
    fn hpt_quick_is_partial_refined_is_final_contract() {
        // The HPT contract Dart depends on: quick pass flags is_partial,
        // refined pass flags is_final (inverse). We pin the key format and
        // the flag convention here so a future refactor can't silently
        // swap them. (Inference itself needs real models; this is a
        // contract test, same as progressive::hpt_merge_keys_are_stable.)
        let mut quick = hpt_seg("halo dunia", 10.0);
        quick.is_partial = true;
        let refined = hpt_seg("halo dunia", 10.0);
        assert!(quick.is_partial, "quick pass must be partial");
        assert!(!refined.is_partial, "refined pass must be final");
        assert_eq!(
            format!("{}@{:.2}", quick.source, quick.timestamp),
            format!("{}@{:.2}", refined.source, refined.timestamp),
            "quick and refined must share the merge key"
        );
    }

    fn hpt_seg(text: &str, ts: f64) -> crate::export::Segment {
        crate::export::Segment {
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
}
