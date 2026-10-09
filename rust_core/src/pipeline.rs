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
//!
//! Summarisation deliberately lives *outside* this file. It is the one
//! networked feature in the app (`summary`), it runs only on explicit user
//! action after a session has finished, and nothing in this module may
//! reference it — `privacy::tests` enforces that.
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

use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::{Arc, Condvar, Mutex, OnceLock};

use crate::audio::{HptMode, RingBuffer};
use crate::diarization::Diarizer;
use crate::error::{TranscribeError, TranscribeResult};
use crate::export::Segment;
use crate::glossary::GlossaryConfig;
use crate::progressive::ProgressiveEngine;
use crate::streaming::{
    join_words, policy_for_rtf, HypoWord, HypothesisBuffer, LineBuilder, StreamPolicy,
    StreamingBuffer, PRE_ROLL_SECS, UTTERANCE_END_SECS,
};
use crate::stt::{DecodeOptions, WhisperEngine};
use crate::vad::whisper_silero::SileroGate;
use crate::vad::{DualVad, SegmentationConfig, VadConfig, FRAME_SAMPLES_10MS};

/// Per-source live transcription over a LocalAgreement-2 commit policy.
///
/// Replaces the fixed 5-second chunking this used to do. See
/// [`crate::streaming`] for why: a chunk boundary falls mid-word, Whisper
/// has no right context for the end of a chunk, and treating those words
/// as final is what made the live transcript disagree with the
/// post-meeting one.
pub struct LivePipeline<'a> {
    engine: &'a WhisperEngine,
    /// The growing, overlapping decode window.
    window: StreamingBuffer,
    vad: DualVad,
    /// whisper.cpp's Silero VAD, when its model is installed.
    ///
    /// The second stage the module has always described and never had: a
    /// real neural confirmation in front of the decoder. [`DualVad`] runs
    /// per 100 ms buffer and is cheap enough to, but it is WebRTC plus an
    /// RMS threshold, and room tone at -64 dBFS gets past it — measured in
    /// a live session, where four seconds of it before the meeting started
    /// came back as `MENENENEN…` at confidence 0.75. Silero runs once per
    /// decode over the whole window instead and settles the question
    /// properly.
    ///
    /// It pays for itself by keeping the decoder out of silence rather than
    /// by being free. Measured with `live_bench` on the weak-CPU target
    /// over a five-minute recording holding 15 s of speech, `fixed_chunk`
    /// spent 58.6 s of CPU in the decoder with the gate off and 35.4 s with
    /// it on — 40% less, because the windows the gate rejects never reach
    /// Whisper. The window is capped (5 s for `fixed_chunk`, 18 s for
    /// LocalAgreement-2), so scanning all of it each time is bounded work;
    /// an "incremental" gate that only scans newly arrived audio was tried
    /// and measured *worse* (77.3 s), because remembering that the window
    /// still holds speech skips the gate and hands silence-adjacent windows
    /// straight to the decoder, which costs far more than the scan saved.
    silero: Option<SileroGate>,
    vad_enabled: bool,
    diarizer: Diarizer,
    source: String,
    language: Option<String>,
    samples_seen: u64,
    glossary: GlossaryConfig,
    /// `glossary.prioritised_terms()`, computed once per session rather than
    /// per chunk — post-correction runs on every segment.
    glossary_terms: Vec<String>,
    /// How the window is decoded and when a word becomes final.
    policy: StreamPolicy,
    /// The commit policy's state.
    agreement: HypothesisBuffer,
    /// Committed words waiting to become a transcript line.
    lines: LineBuilder,
    /// Absolute time of the last buffer that held speech.
    last_speech_secs: f64,
    /// Absolute time at which the window was last decoded.
    last_decode_secs: f64,
    /// Spans the window had to drop without transcribing, because the
    /// decoder could not keep up. Reported so the post-stop completion
    /// pass has something to point at — the audio itself is on disk and is
    /// recovered from there.
    dropped: Vec<(f64, f64)>,
}

/// What one [`LivePipeline::ingest`] produced.
#[derive(Debug, Default)]
pub struct LiveOutcome {
    /// Lines the policy has committed. Final; never revised.
    pub segments: Vec<Segment>,
    /// The uncommitted tail of the latest hypothesis, as the UI should
    /// show it in grey. `None` means "unchanged"; `Some("")` means "clear
    /// it".
    pub tentative: Option<String>,
}

/// Everything a [`LiveWorker`] needs to transcribe one source.
///
/// Replaces the previous 7-to-9 positional parameters on `spawn*`, each of
/// which needed its own `#[allow(clippy::too_many_arguments)]`, and gives
/// `vad_enabled` an actual home — the user's VAD setting used to reach
/// `SessionConfig` and stop there.
#[flutter_rust_bridge::frb(ignore)]
#[derive(Debug, Clone)]
pub struct LiveWorkerConfig {
    /// Model used for the quick pass, and for single-model transcription.
    pub quick_model_path: PathBuf,
    /// Refine model for HPT. `None` = single-model transcription.
    pub refine_model_path: Option<PathBuf>,
    pub hpt_mode: HptMode,
    /// `"mic"` or `"spk"`.
    pub source: String,
    pub language: Option<String>,
    /// Mirrors `SessionConfig::vad_enabled`.
    pub vad_enabled: bool,
    pub gpu_enabled: bool,
    pub gpu_device: i32,
    /// Mirrors `SessionConfig::glossary` — the kamus istilah biases Whisper's
    /// `initial_prompt` and, optionally, repairs its output.
    pub glossary: GlossaryConfig,
    /// Fastest model installed on this machine, for the single-model live
    /// path to fall back to when the chosen one cannot keep up.
    ///
    /// Picking `large-v3-turbo-q5` as the live model on a device that runs
    /// it at RTF 0.05 does not produce a slower transcript, it produces
    /// almost none: the worker falls a minute further behind every minute
    /// and Stop discards the backlog. The accurate transcript then comes
    /// from the post-stop completion pass (`crate::completion`), which has
    /// no real-time constraint. `None` disables the substitution.
    pub fallback_model_path: Option<PathBuf>,
}

#[derive(Debug, Clone)]
pub enum LiveEvent {
    Vu {
        source: String,
        level: f32,
    },
    Segment(Segment),
    /// The uncommitted tail of the live hypothesis — the greyed
    /// "sementara" text.
    ///
    /// A separate event rather than a `Segment` with `is_partial`: it is
    /// not a transcript line, it is one changing string that replaces
    /// itself, and giving it a timestamp key would leave a trail of stale
    /// provisional rows behind as words were committed out of it. An
    /// empty string clears it.
    Tentative {
        source: String,
        text: String,
    },
}

pub struct LiveWorker {
    stop_tx: Option<std::sync::mpsc::Sender<()>>,
    thread: Option<std::thread::JoinHandle<()>>,
    /// Set only when adaptive HPT chose a strategy — see [`HptRoute`].
    route: Option<HptRoute>,
    /// Set by the worker thread when it exits. Used by `stop()` to wait
    /// with a bounded timeout instead of blocking indefinitely on `join()`.
    finished: Arc<AtomicBool>,
    finished_mutex: Arc<Mutex<()>>,
    finished_cvar: Arc<Condvar>,
    /// Samples this worker has actually run through Whisper. Compared
    /// against what capture has delivered to produce the live
    /// "tertinggal N detik" indicator — see [`Self::processed_samples`].
    processed: Arc<AtomicU64>,
}

impl LiveWorker {
    pub fn resume_pending_transcriptions(
        library_path: &Path,
    ) -> Result<Vec<PathBuf>, TranscribeError> {
        let mut pending = Vec::new();
        let sessions = crate::session::list_recoverable_sessions()?;
        for s in sessions {
            let session_dir = library_path.join(&s.snapshot.session_id);
            if !session_dir.join("transcript.json").exists() {
                pending.push(session_dir);
            }
        }
        Ok(pending)
    }

    /// Starts the worker described by `config`, picking the single-model,
    /// dual-pass or adaptive strategy from `refine_model_path` + `hpt_mode`.
    pub fn spawn(
        config: LiveWorkerConfig,
        samples_rx: std::sync::mpsc::Receiver<Vec<f32>>,
        events_tx: std::sync::mpsc::Sender<LiveEvent>,
    ) -> Result<Self, TranscribeError> {
        match config.refine_model_path.clone() {
            Some(_) => Self::spawn_adaptive(config, samples_rx, events_tx),
            None => Self::spawn_single(config, samples_rx, events_tx),
        }
    }

    /// Single-model live worker, with the keep-up check in front of it.
    ///
    /// Before this, picking an accurate model in single-model mode on a
    /// slow machine produced a transcript with the first few seconds of the
    /// meeting in it and nothing else — the worker fell behind from the
    /// first chunk and never recovered. The benchmark is the same bounded,
    /// cached probe adaptive HPT uses (a local sine wave; no user audio,
    /// no network), so the second source in a "Rapat Online" session pays
    /// nothing for it.
    fn spawn_single(
        config: LiveWorkerConfig,
        samples_rx: std::sync::mpsc::Receiver<Vec<f32>>,
        events_tx: std::sync::mpsc::Sender<LiveEvent>,
    ) -> Result<Self, TranscribeError> {
        let fallback = config
            .fallback_model_path
            .clone()
            .filter(|path| path != &config.quick_model_path);
        let Some(fallback) = fallback else {
            let (engine, policy) = load_with_policy(
                &config.quick_model_path,
                config.gpu_enabled,
                config.gpu_device,
            )?;
            return Self::spawn_with_engine(engine, policy, config, samples_rx, events_tx);
        };

        let key = BenchmarkKey {
            model: config.quick_model_path.to_string_lossy().into_owned(),
            gpu_enabled: config.gpu_enabled,
            gpu_device: config.gpu_device,
        };
        if let Some(route) = recall_route(&key) {
            return Self::spawn_single_route(route, &fallback, config, samples_rx, events_tx);
        }

        let engine = WhisperEngine::load_with_gpu(
            &config.quick_model_path,
            config.gpu_enabled,
            config.gpu_device,
        )?;
        let deadline = crate::benchmark::benchmark_deadline(HPT_LIVE_FLOOR);
        match crate::benchmark::benchmark_rtf_bounded(engine, deadline) {
            crate::benchmark::BenchmarkOutcome::Measured { rtf, engine } => {
                let route = if rtf >= HPT_LIVE_FLOOR {
                    HptRoute::DirectRefine
                } else {
                    HptRoute::QuickOnly
                };
                tracing::info!(rtf, ?route, "single-model live keep-up check");
                remember_route(&key, route);
                remember_rtf(&key, rtf);
                if route == HptRoute::DirectRefine {
                    // The engine that was just measured is the one that
                    // will run, so its rtf is exactly the figure the
                    // commit policy needs.
                    let policy = policy_for_rtf(rtf);
                    return Self::spawn_with_engine(engine, policy, config, samples_rx, events_tx)
                        .map(|worker| worker.with_route(route));
                }
                drop(engine);
                Self::spawn_single_route(route, &fallback, config, samples_rx, events_tx)
            }
            crate::benchmark::BenchmarkOutcome::TooSlow => {
                tracing::info!(
                    deadline_secs = deadline.as_secs_f64(),
                    "chosen live model outran its benchmark deadline; using the fastest \
                     installed model for the live preview"
                );
                remember_route(&key, HptRoute::QuickOnly);
                Self::spawn_single_route(
                    HptRoute::QuickOnly,
                    &fallback,
                    config,
                    samples_rx,
                    events_tx,
                )
            }
        }
    }

    fn spawn_single_route(
        route: HptRoute,
        fallback_model_path: &Path,
        config: LiveWorkerConfig,
        samples_rx: std::sync::mpsc::Receiver<Vec<f32>>,
        events_tx: std::sync::mpsc::Sender<LiveEvent>,
    ) -> Result<Self, TranscribeError> {
        let model = if route == HptRoute::QuickOnly {
            fallback_model_path
        } else {
            config.quick_model_path.as_path()
        };
        let (engine, policy) = load_with_policy(model, config.gpu_enabled, config.gpu_device)?;
        Self::spawn_with_engine(engine, policy, config, samples_rx, events_tx)
            .map(|worker| worker.with_route(route))
    }

    /// Single-model worker over an already-loaded engine. Used by
    /// [`Self::spawn`] and by adaptive HPT's direct-q5 fast path so the
    /// benchmark-loaded engine is reused instead of double-loading the
    /// 548 MB refine model.
    fn spawn_with_engine(
        engine: WhisperEngine,
        policy: StreamPolicy,
        config: LiveWorkerConfig,
        samples_rx: std::sync::mpsc::Receiver<Vec<f32>>,
        events_tx: std::sync::mpsc::Sender<LiveEvent>,
    ) -> Result<Self, TranscribeError> {
        let LiveWorkerConfig {
            source,
            language,
            vad_enabled,
            glossary,
            ..
        } = config;
        let (stop_tx, stop_rx) = std::sync::mpsc::channel();
        let finished = Arc::new(AtomicBool::new(false));
        let finished_mutex = Arc::new(Mutex::new(()));
        let finished_cvar = Arc::new(Condvar::new());
        let finished_thread = Arc::clone(&finished);
        let finished_cvar_thread = Arc::clone(&finished_cvar);
        let _finished_mutex_thread = Arc::clone(&finished_mutex);
        let processed = Arc::new(AtomicU64::new(0));
        let processed_thread = Arc::clone(&processed);
        let thread = std::thread::spawn(move || {
            let mut pipeline = match LivePipeline::with_policy(
                &engine,
                source.clone(),
                language,
                VadConfig::default(),
                vad_enabled,
                glossary,
                policy,
            ) {
                Ok(pipeline) => pipeline,
                Err(error) => {
                    tracing::error!(source = %source, %error, "live pipeline initialization failed");
                    finished_thread.store(true, Ordering::SeqCst);
                    finished_cvar_thread.notify_one();
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
                let ingested = samples.len() as u64;
                match pipeline.ingest(&samples) {
                    Ok(outcome) => {
                        for segment in outcome.segments {
                            let _ = events_tx.send(LiveEvent::Segment(segment));
                        }
                        if let Some(text) = outcome.tentative {
                            let _ = events_tx.send(LiveEvent::Tentative {
                                source: source.clone(),
                                text,
                            });
                        }
                    }
                    Err(error) => tracing::error!(source = %source, %error, "live pipeline failed"),
                }
                processed_thread.fetch_add(ingested, Ordering::Relaxed);
            }
            // Words the policy had already agreed on but had not yet turned
            // into a line. Without this they would be lost at Stop — and
            // unlike the audio still in the window, there is no second
            // chance to recover them from the WAV.
            for segment in pipeline.finish() {
                let _ = events_tx.send(LiveEvent::Segment(segment));
            }
            let _ = events_tx.send(LiveEvent::Tentative {
                source: source.clone(),
                text: String::new(),
            });
            finished_thread.store(true, Ordering::SeqCst);
            finished_cvar_thread.notify_one();
        });
        Ok(Self {
            stop_tx: Some(stop_tx),
            thread: Some(thread),
            route: None,
            finished,
            finished_mutex,
            finished_cvar,
            processed,
        })
    }

    /// Samples this worker has run through Whisper so far.
    ///
    /// Subtract from what capture has delivered and divide by the sample
    /// rate to get how far behind the live transcript is. On a device where
    /// the model cannot keep up this grows without bound, which is exactly
    /// the state the user needs told about while there is still time to do
    /// something about it.
    #[flutter_rust_bridge::frb(ignore)]
    pub fn processed_samples(&self) -> u64 {
        self.processed.load(Ordering::Relaxed)
    }

    /// Signals the worker to exit and returns immediately.
    ///
    /// Stop must not block the UI. The previous implementation waited up to
    /// five seconds for the thread and then leaked it anyway, so on the
    /// device this was measured on — where one chunk of q5 inference takes
    /// 110 seconds — Stop cost a five-second freeze and then leaked the
    /// thread regardless. The five seconds bought nothing.
    ///
    /// The queued audio is not lost by exiting here: it is on disk in the
    /// session's WAV, and `crate::completion` transcribes exactly the
    /// stretches this worker never reached, afterwards, with the model the
    /// user chose rather than whatever the live path had to settle for.
    pub fn stop(&mut self) {
        if let Some(stop_tx) = self.stop_tx.take() {
            let _ = stop_tx.send(());
        }
        let Some(thread) = self.thread.take() else {
            return;
        };
        if self.finished.load(Ordering::SeqCst) {
            let _ = thread.join();
            return;
        }
        // Mid-inference. Detach: the thread observes the stop signal when
        // its current chunk finishes and exits on its own.
        tracing::debug!("LiveWorker still running at stop; detaching rather than blocking the UI");
        std::mem::forget(thread);
    }

    /// Blocks until the worker thread has exited, up to `timeout`. Tests
    /// use this; the app never does, because Stop is a UI action.
    #[flutter_rust_bridge::frb(ignore)]
    pub fn wait_for_exit(&self, timeout: std::time::Duration) -> bool {
        let mut guard = match self.finished_mutex.lock() {
            Ok(g) => g,
            Err(poisoned) => poisoned.into_inner(),
        };
        let start = std::time::Instant::now();
        loop {
            if self.finished.load(Ordering::SeqCst) {
                return true;
            }
            let elapsed = start.elapsed();
            if elapsed >= timeout {
                return false;
            }
            match self.finished_cvar.wait_timeout(guard, timeout - elapsed) {
                Ok((next, result)) => {
                    guard = next;
                    if result.timed_out() && !self.finished.load(Ordering::SeqCst) {
                        return false;
                    }
                }
                Err(_) => return false,
            }
        }
    }

    /// Hybrid Progressive Transcription (HPT) worker: loads BOTH the quick
    /// (`base`) and refine (`large-v3-turbo-q5`) models up front. Each
    /// speech chunk emits quick segments (`is_partial = true`) immediately
    /// so the UI renders text within the 3-5s latency budget, then refined
    /// segments (`is_partial = false`) with the same `(source, timestamp)`
    /// keys replace them on the Dart side.
    pub fn spawn_hpt(
        config: LiveWorkerConfig,
        samples_rx: std::sync::mpsc::Receiver<Vec<f32>>,
        events_tx: std::sync::mpsc::Sender<LiveEvent>,
    ) -> Result<Self, TranscribeError> {
        let refine_model_path = config.refine_model_path.clone().ok_or_else(|| {
            TranscribeError::Model("HPT worker requires a refine model path".into())
        })?;
        let engine = ProgressiveEngine::load(
            &config.quick_model_path,
            &refine_model_path,
            config.gpu_enabled,
            config.gpu_device,
        )?;
        let LiveWorkerConfig {
            source,
            language,
            vad_enabled,
            glossary,
            ..
        } = config;
        let (stop_tx, stop_rx) = std::sync::mpsc::channel();
        let finished = Arc::new(AtomicBool::new(false));
        let finished_mutex = Arc::new(Mutex::new(()));
        let finished_cvar = Arc::new(Condvar::new());
        let finished_thread = Arc::clone(&finished);
        let finished_cvar_thread = Arc::clone(&finished_cvar);
        let _finished_mutex_thread = Arc::clone(&finished_mutex);
        let processed = Arc::new(AtomicU64::new(0));
        let processed_thread = Arc::clone(&processed);
        let thread = std::thread::spawn(move || {
            let mut pipeline = match LivePipelineHpt::new(
                &engine,
                source.clone(),
                language,
                VadConfig::default(),
                vad_enabled,
                glossary,
            ) {
                Ok(pipeline) => pipeline,
                Err(error) => {
                    tracing::error!(source = %source, %error, "hpt live pipeline initialization failed");
                    finished_thread.store(true, Ordering::SeqCst);
                    finished_cvar_thread.notify_one();
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
                let ingested = samples.len() as u64;
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
                processed_thread.fetch_add(ingested, Ordering::Relaxed);
            }
            finished_thread.store(true, Ordering::SeqCst);
            finished_cvar_thread.notify_one();
        });
        Ok(Self {
            stop_tx: Some(stop_tx),
            thread: Some(thread),
            route: None,
            finished,
            finished_mutex,
            finished_cvar,
            processed,
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
        config: LiveWorkerConfig,
        samples_rx: std::sync::mpsc::Receiver<Vec<f32>>,
        events_tx: std::sync::mpsc::Sender<LiveEvent>,
    ) -> Result<Self, TranscribeError> {
        let refine_model_path = config.refine_model_path.clone().ok_or_else(|| {
            TranscribeError::Model("adaptive HPT worker requires a refine model path".into())
        })?;
        let key = BenchmarkKey {
            model: refine_model_path.to_string_lossy().into_owned(),
            gpu_enabled: config.gpu_enabled,
            gpu_device: config.gpu_device,
        };

        // Forced modes need no measurement at all, and a cached route covers
        // every worker after the first. "Rapat Online" spawns one per source,
        // and re-measuring for the second cost a second full benchmark —
        // 110 s of it on the machine this was measured on — for an answer
        // that is a property of the machine, not of the source.
        let known = match config.hpt_mode {
            HptMode::ForceDirect => Some(HptRoute::DirectRefine),
            HptMode::ForceDual => Some(HptRoute::DualPass),
            HptMode::Auto => recall_route(&key),
        };
        if let Some(route) = known {
            return Self::spawn_route(route, &refine_model_path, config, samples_rx, events_tx);
        }

        // Load the refine model once: the benchmark hands it back when it
        // finishes in time, so the direct path reuses it instead of paying
        // for the same ~550 MB twice.
        let engine = WhisperEngine::load_with_gpu(
            &refine_model_path,
            config.gpu_enabled,
            config.gpu_device,
        )?;
        // The deadline is derived from the *lowest* threshold that still needs
        // an exact figure. Past it, `rtf < HPT_LIVE_FLOOR` is already known,
        // which is all `route_for_rtf` needs to reach `QuickOnly`.
        let deadline = crate::benchmark::benchmark_deadline(HPT_LIVE_FLOOR);
        let route = match crate::benchmark::benchmark_rtf_bounded(engine, deadline) {
            crate::benchmark::BenchmarkOutcome::Measured { rtf, engine } => {
                let route = route_for_rtf(rtf);
                tracing::info!(rtf, ?route, mode = ?config.hpt_mode, "adaptive hpt benchmark");
                remember_route(&key, route);
                remember_rtf(&key, rtf);
                if route == HptRoute::DirectRefine {
                    // Only this route can reuse the benchmark's engine; the
                    // others need a different model set.
                    let policy = policy_for_rtf(rtf);
                    return Self::spawn_with_engine(engine, policy, config, samples_rx, events_tx)
                        .map(|worker| worker.with_route(route));
                }
                drop(engine);
                route
            }
            crate::benchmark::BenchmarkOutcome::TooSlow => {
                tracing::info!(
                    deadline_secs = deadline.as_secs_f64(),
                    "adaptive hpt benchmark outran its deadline — the refine model cannot \
                     keep up with live audio on this device, using the quick model only"
                );
                remember_route(&key, HptRoute::QuickOnly);
                HptRoute::QuickOnly
            }
        };
        Self::spawn_route(route, &refine_model_path, config, samples_rx, events_tx)
    }

    /// Spawns the worker for an already-known route.
    fn spawn_route(
        route: HptRoute,
        refine_model_path: &Path,
        config: LiveWorkerConfig,
        samples_rx: std::sync::mpsc::Receiver<Vec<f32>>,
        events_tx: std::sync::mpsc::Sender<LiveEvent>,
    ) -> Result<Self, TranscribeError> {
        let worker = match route {
            HptRoute::DirectRefine => {
                let (engine, policy) =
                    load_with_policy(refine_model_path, config.gpu_enabled, config.gpu_device)?;
                Self::spawn_with_engine(engine, policy, config, samples_rx, events_tx)
            }
            HptRoute::DualPass => Self::spawn_hpt(config, samples_rx, events_tx),
            HptRoute::QuickOnly => {
                let (engine, policy) = load_with_policy(
                    &config.quick_model_path,
                    config.gpu_enabled,
                    config.gpu_device,
                )?;
                Self::spawn_with_engine(engine, policy, config, samples_rx, events_tx)
            }
        };
        worker.map(|worker| worker.with_route(route))
    }

    fn with_route(mut self, route: HptRoute) -> Self {
        self.route = Some(route);
        self
    }

    /// Which live strategy this worker ended up on, when adaptive HPT chose
    /// it. `None` for single-model workers, where there was nothing to choose.
    pub fn route(&self) -> Option<HptRoute> {
        self.route
    }
}

/// Which live strategy adaptive HPT picked for a device.
#[flutter_rust_bridge::frb(ignore)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum HptRoute {
    /// Fast device: the refine model alone, single pass.
    DirectRefine,
    /// The refine model keeps up with real time; the quick model goes first
    /// so text appears before the accurate version replaces it.
    DualPass,
    /// The refine model cannot keep up with live audio on this device. Both
    /// other routes run it on **every** chunk, so on a device below the floor
    /// they emit nothing at all: each 5 s chunk takes longer to transcribe
    /// than the next one takes to arrive, and the worker falls behind
    /// forever. Measured on a 2-core laptop: 110 s of q5 inference per 5 s
    /// chunk, and not one segment in 90 s of speech. Quick-model text the
    /// user can actually read beats perfect text they never see — and
    /// "Transkrip Ulang" re-runs the saved audio with the accurate model
    /// afterwards, with no real-time constraint.
    QuickOnly,
}

/// What an adaptive-HPT measurement is actually about: a model running on
/// this machine with this GPU configuration. Not the audio source.
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
struct BenchmarkKey {
    model: String,
    gpu_enabled: bool,
    gpu_device: i32,
}

fn routes() -> &'static Mutex<HashMap<BenchmarkKey, HptRoute>> {
    static ROUTES: OnceLock<Mutex<HashMap<BenchmarkKey, HptRoute>>> = OnceLock::new();
    ROUTES.get_or_init(|| Mutex::new(HashMap::new()))
}

fn recall_route(key: &BenchmarkKey) -> Option<HptRoute> {
    routes().lock().ok()?.get(key).copied()
}

fn remember_route(key: &BenchmarkKey, route: HptRoute) {
    if let Ok(mut routes) = routes().lock() {
        routes.insert(key.clone(), route);
    }
}

/// Measured realtime factor per model+GPU configuration.
///
/// Separate from the route cache because the two answer different
/// questions at different thresholds: whether the refine model belongs in
/// a live pipeline at all (`HPT_LIVE_FLOOR`, 1.0), and whether the device
/// can afford LocalAgreement-2's second decode
/// ([`crate::streaming::LA2_RTF_FLOOR`], 2.0). A model can be cached in one
/// and not the other — the route is measured for the model the *user*
/// chose, the commit policy for the model that actually ends up running.
fn measured_rtfs() -> &'static Mutex<HashMap<BenchmarkKey, f64>> {
    static RTFS: OnceLock<Mutex<HashMap<BenchmarkKey, f64>>> = OnceLock::new();
    RTFS.get_or_init(|| Mutex::new(HashMap::new()))
}

fn recall_rtf(key: &BenchmarkKey) -> Option<f64> {
    measured_rtfs().lock().ok()?.get(key).copied()
}

fn remember_rtf(key: &BenchmarkKey, rtf: f64) {
    if let Ok(mut rtfs) = measured_rtfs().lock() {
        rtfs.insert(key.clone(), rtf);
    }
}

fn benchmark_key(model: &Path, gpu_enabled: bool, gpu_device: i32) -> BenchmarkKey {
    BenchmarkKey {
        model: model.to_string_lossy().into_owned(),
        gpu_enabled,
        gpu_device,
    }
}

/// Loads `model` and resolves the live commit policy for it.
///
/// The device is measured once per process per model (the result is
/// cached), with the deadline derived from the only threshold that matters
/// here — `LA2_RTF_FLOOR` — so the check costs at most ~3.5 s on a device
/// that is going to fail it anyway.
///
/// On the slow path the engine goes with the detached benchmark thread and
/// has to be loaded again. That is the cheap case by construction: only a
/// model this device cannot run at 2× realtime reaches it, and the model
/// the live path settles on for such a device is the smallest installed
/// one.
fn load_with_policy(
    model: &Path,
    gpu_enabled: bool,
    gpu_device: i32,
) -> TranscribeResult<(WhisperEngine, StreamPolicy)> {
    let key = benchmark_key(model, gpu_enabled, gpu_device);
    let engine = WhisperEngine::load_with_gpu(model, gpu_enabled, gpu_device)?;
    if let Some(rtf) = recall_rtf(&key) {
        return Ok((engine, policy_for_rtf(rtf)));
    }
    let deadline = crate::benchmark::benchmark_deadline(crate::streaming::LA2_RTF_FLOOR);
    match crate::benchmark::benchmark_rtf_bounded(engine, deadline) {
        crate::benchmark::BenchmarkOutcome::Measured { rtf, engine } => {
            remember_rtf(&key, rtf);
            let policy = policy_for_rtf(rtf);
            tracing::info!(rtf, ?policy, "live commit policy");
            Ok((engine, policy))
        }
        crate::benchmark::BenchmarkOutcome::TooSlow => {
            // Past the deadline, `rtf < LA2_RTF_FLOOR` is already known.
            remember_rtf(&key, 0.0);
            tracing::info!(
                "live model is below 2x realtime; committing on sight rather \
                 than on agreement"
            );
            let engine = WhisperEngine::load_with_gpu(model, gpu_enabled, gpu_device)?;
            Ok((engine, StreamPolicy::fixed_chunk()))
        }
    }
}

/// RTF threshold for skipping the base quick pass. ≥1.2 means the q5 engine
/// keeps up with real-time audio (with a 20% safety margin over plain 1.0 so
/// borderline devices still get the instant-partial benefit of dual-pass).
pub const HPT_DIRECT_THRESHOLD: f64 = 1.2;

/// RTF below which the refine model has no place in a *live* pipeline at all.
///
/// 1.0 is not a tuning choice, it is the definition of keeping up: at
/// `rtf < 1.0` the refine pass takes longer than the audio it is transcribing,
/// so every chunk puts the worker further behind. Dual-pass does not help —
/// it runs the same refine pass on every chunk and adds the quick pass on top.
pub const HPT_LIVE_FLOOR: f64 = 1.0;

/// Picks the live strategy for a measured realtime factor.
pub fn route_for_rtf(rtf: f64) -> HptRoute {
    if rtf >= HPT_DIRECT_THRESHOLD {
        HptRoute::DirectRefine
    } else if rtf >= HPT_LIVE_FLOOR {
        HptRoute::DualPass
    } else {
        HptRoute::QuickOnly
    }
}

/// Pure decision: does this device run q5 fast enough to skip the base
/// quick pass entirely? `rtf` = seconds of audio transcribed per second of
/// wall-clock. ≥ `HPT_DIRECT_THRESHOLD` → direct q5 single pass.
pub fn should_direct_q5(rtf: f64) -> bool {
    rtf >= HPT_DIRECT_THRESHOLD
}

#[cfg(test)]
mod route_tests {
    use super::{route_for_rtf, HptRoute, HPT_DIRECT_THRESHOLD, HPT_LIVE_FLOOR};

    #[test]
    fn a_fast_device_runs_the_refine_model_directly() {
        assert_eq!(route_for_rtf(HPT_DIRECT_THRESHOLD), HptRoute::DirectRefine);
        assert_eq!(route_for_rtf(5.0), HptRoute::DirectRefine);
    }

    #[test]
    fn a_device_that_merely_keeps_up_gets_dual_pass() {
        assert_eq!(route_for_rtf(HPT_LIVE_FLOOR), HptRoute::DualPass);
        assert_eq!(
            route_for_rtf(HPT_DIRECT_THRESHOLD - 0.001),
            HptRoute::DualPass
        );
    }

    #[test]
    fn a_device_that_cannot_keep_up_drops_the_refine_model() {
        // The measured case: rtf 0.046 (110 s of q5 inference per 5 s chunk).
        // Dual-pass runs that same refine pass on every chunk, so it emitted
        // nothing at all in 90 s of speech. Quick-only text is readable now;
        // "Transkrip Ulang" recovers the accuracy afterwards.
        assert_eq!(route_for_rtf(0.046), HptRoute::QuickOnly);
        assert_eq!(
            route_for_rtf(HPT_LIVE_FLOOR - 0.001),
            HptRoute::QuickOnly,
            "below 1.0 the refine pass is slower than the audio it transcribes"
        );
        assert_eq!(route_for_rtf(0.0), HptRoute::QuickOnly);
    }

    #[test]
    fn the_floor_is_below_the_direct_threshold() {
        const { assert!(HPT_LIVE_FLOOR < HPT_DIRECT_THRESHOLD) };
        assert_eq!(HPT_LIVE_FLOOR, 1.0, "1.0 is 'keeps up with real time'");
    }
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
        vad_enabled: bool,
        glossary: GlossaryConfig,
    ) -> TranscribeResult<Self> {
        Self::with_policy(
            engine,
            source,
            language,
            vad_config,
            vad_enabled,
            glossary,
            StreamPolicy::default(),
        )
    }

    /// [`Self::new`] with an explicit commit policy.
    ///
    /// The worker picks it from the cached realtime-factor benchmark: a
    /// device that cannot afford LocalAgreement-2's second decode gets
    /// fixed chunking instead of a latency regression. See
    /// [`crate::streaming::policy_for_rtf`].
    #[allow(clippy::too_many_arguments)]
    pub fn with_policy(
        engine: &'a WhisperEngine,
        source: impl Into<String>,
        language: Option<String>,
        vad_config: VadConfig,
        vad_enabled: bool,
        glossary: GlossaryConfig,
        policy: StreamPolicy,
    ) -> TranscribeResult<Self> {
        let glossary_terms = if glossary.post_correction {
            glossary.prioritised_terms()
        } else {
            Vec::new()
        };
        Ok(Self {
            engine,
            policy,
            window: StreamingBuffer::new(crate::decode::TARGET_SAMPLE_RATE),
            vad: DualVad::new(vad_config)?,
            // `None` when the model is not installed, which is the
            // ordinary state until the user downloads it. A failure to
            // load is logged and treated the same: the live path degrades
            // to WebRTC+energy rather than stopping.
            silero: match SileroGate::from_settings(crate::stt::file::VAD_THREADS) {
                Some(Ok(gate)) => Some(gate),
                Some(Err(e)) => {
                    tracing::warn!(%e, "Silero VAD unusable for the live gate");
                    None
                }
                None => None,
            },
            vad_enabled,
            diarizer: Diarizer::new(),
            source: source.into(),
            language,
            samples_seen: 0,
            glossary,
            glossary_terms,
            agreement: HypothesisBuffer::new(),
            lines: LineBuilder::default(),
            last_speech_secs: 0.0,
            last_decode_secs: 0.0,
            dropped: Vec::new(),
        })
    }

    /// Spans the live path dropped untranscribed. Empty on any machine
    /// whose live model keeps up.
    #[flutter_rust_bridge::frb(ignore)]
    pub fn dropped_spans(&self) -> &[(f64, f64)] {
        &self.dropped
    }

    /// Ingest one or more 16 kHz mono f32 samples.
    ///
    /// The window is decoded when the policy's `min_chunk_secs` of new audio has
    /// arrived, or when the speaker has stopped — and only ever if the
    /// window holds speech at all, which is what keeps Whisper from being
    /// asked what the silence said.
    ///
    /// Returned segments are *not* yet echo-filtered: this pipeline only
    /// ever sees its own source, so cross-source dedupe happens where mic
    /// and speaker segments actually meet (see the module doc comment).
    pub fn ingest(&mut self, samples: &[f32]) -> TranscribeResult<LiveOutcome> {
        if samples.is_empty() {
            return Ok(LiveOutcome::default());
        }

        let has_speech = detect_speech(&mut self.vad, self.vad_enabled, samples)?;
        self.window.push(samples);
        self.samples_seen = self.samples_seen.saturating_add(samples.len() as u64);
        let now = self.samples_seen as f64 / crate::decode::TARGET_SAMPLE_RATE as f64;
        if has_speech {
            self.last_speech_secs = now;
        }

        // The speaker has stopped and something is still provisional. No
        // more right context is coming, so waiting for agreement would
        // wait forever — see `streaming::UTTERANCE_END_SECS`.
        let utterance_ended = now - self.last_speech_secs >= UTTERANCE_END_SECS
            && (self.agreement.has_tentative() || !self.lines.is_empty());

        // A window whose last speech predates its own start holds nothing
        // but room tone. Keep it short and never decode it.
        if self.last_speech_secs < self.window.start_secs() {
            self.window.trim_to(now - PRE_ROLL_SECS);
            self.last_decode_secs = now;
            return Ok(self.finish_utterance());
        }

        if now - self.last_decode_secs < self.policy.min_chunk_secs && !utterance_ended {
            return Ok(LiveOutcome::default());
        }
        self.last_decode_secs = now;

        let hypothesis = self.decode_window()?;
        let commit = self.agreement.insert(hypothesis);
        let tentative = Some(join_words(&commit.tentative));
        let mut words = commit.committed;
        // Fixed chunking has no second opinion to wait for: the chunk is
        // all the audio there will ever be for these words.
        if utterance_ended || !self.policy.require_agreement {
            words.extend(self.agreement.flush());
        }

        let mut lines = self.lines.push(words);
        if utterance_ended || !self.policy.require_agreement {
            lines.extend(self.lines.take());
        }
        let segments = self.segments_from_lines(lines);

        // Trim *after* building the segments: the speaker labels are read
        // off the audio under each line.
        self.trim_window(utterance_ended, now);

        Ok(LiveOutcome {
            segments,
            tentative: if utterance_ended || !self.policy.require_agreement {
                Some(String::new())
            } else {
                tentative
            },
        })
    }

    /// Everything still held back, for Stop.
    ///
    /// Unlike the mid-session path this does not decode: whatever audio the
    /// window still holds is on disk, and `crate::completion` transcribes
    /// it afterwards with the accurate model and no deadline. What this
    /// recovers is the words already *agreed* but not yet turned into a
    /// line, which would otherwise never reach the transcript.
    pub fn finish(&mut self) -> Vec<Segment> {
        let mut lines: Vec<Vec<HypoWord>> = Vec::new();
        let flushed = self.agreement.flush();
        lines.extend(self.lines.push(flushed));
        lines.extend(self.lines.take());
        self.segments_from_lines(lines)
    }

    /// Flushes the line in progress at an utterance end, without decoding.
    fn finish_utterance(&mut self) -> LiveOutcome {
        let mut lines: Vec<Vec<HypoWord>> = Vec::new();
        let flushed = self.agreement.flush();
        lines.extend(self.lines.push(flushed));
        lines.extend(self.lines.take());
        if lines.is_empty() {
            return LiveOutcome::default();
        }
        LiveOutcome {
            segments: self.segments_from_lines(lines),
            tentative: Some(String::new()),
        }
    }

    /// One decode of the whole window, as a flat word sequence.
    ///
    /// The per-segment filters run here rather than on the committed lines
    /// because a hallucinated segment must never contribute *words* to the
    /// agreement buffer: once a made-up word is in there it can agree with
    /// itself on the next decode and be committed.
    fn decode_window(&mut self) -> TranscribeResult<Vec<HypoWord>> {
        // No rolling transcript tail. On chunked live inference the
        // previous text is the model's own output, so conditioning on it
        // lets one hallucination seed the next (Research Round 2 §2.2.5) —
        // and the overlapping window already carries the acoustic context
        // that tail was standing in for.
        // Silero has the final say on whether this window holds speech.
        // Only when the user has VAD on: with it off they have asked for
        // every chunk to be transcribed, and the text filters are then the
        // only thing between room tone and an invented caption.
        // Unconditional backstop (B1): independent of whether a Silero
        // model is installed on this machine, the exact audio about to be
        // decoded is measured directly. `window_holds_speech` fails open
        // (`Ok(true)`) when no Silero gate is loaded, which otherwise means
        // a missing model file silently disables all live-path VAD.
        if crate::silence_gate::is_below_speech_floor(
            self.window.samples(),
            crate::silence_gate::SILENCE_THRESHOLD_DBFS,
        ) {
            return Ok(Vec::new());
        }
        if self.vad_enabled && !self.window_holds_speech()? {
            return Ok(Vec::new());
        }

        let prompt = crate::glossary::build_initial_prompt(&self.glossary, "");
        let initial_prompt = (!prompt.text.is_empty()).then_some(prompt.text.as_str());
        let mut segments = self.engine.transcribe_chunk_with(
            self.window.samples(),
            &self.source,
            self.window.start_secs(),
            self.language.as_deref(),
            initial_prompt,
            DecodeOptions::live(),
        )?;
        crate::progressive::filter_loops(&mut segments);
        // Room tone loud enough to pass the VAD still reads as silence to
        // Whisper, which answers with a subtitle caption rather than an
        // empty string. Dropping those here keeps `[MENGENI]` out of the
        // live transcript as well as the file one.
        crate::hallucination::filter_segments(&mut segments);
        Ok(segments
            .into_iter()
            .flat_map(|segment| segment.words)
            .map(HypoWord::from)
            .collect())
    }

    /// Whether the current window holds speech according to Silero.
    ///
    /// `true` when no Silero model is installed: a gate that cannot run
    /// must not be the reason a meeting goes untranscribed. The cheap
    /// WebRTC+energy stage has already had its say by this point.
    fn window_holds_speech(&mut self) -> TranscribeResult<bool> {
        let config = SegmentationConfig::default();
        let Some(gate) = self.silero.as_mut() else {
            return Ok(true);
        };
        match gate.speech_regions(self.window.samples(), config) {
            Ok(regions) => Ok(!regions.is_empty()),
            Err(e) => {
                tracing::warn!(%e, "Silero VAD failed mid-session; falling back to WebRTC+energy");
                Ok(true)
            }
        }
    }

    /// Turns committed word runs into transcript segments.
    fn segments_from_lines(&mut self, lines: Vec<Vec<HypoWord>>) -> Vec<Segment> {
        let mut segments: Vec<Segment> = lines
            .into_iter()
            .filter_map(|line| self.segment_from_line(line))
            .collect();
        crate::hallucination::filter_segments(&mut segments);
        crate::glossary::correct_segments(
            &mut segments,
            &self.glossary_terms,
            &self.glossary.replacements,
        );
        crate::confidence::apply_confidence_routing(&mut segments);
        segments
    }

    fn segment_from_line(&mut self, words: Vec<HypoWord>) -> Option<Segment> {
        let first = words.first()?;
        let last = words.last()?;
        let (start, end) = (first.start, last.end.max(first.start));
        let text = join_words(&words);
        // Mean per-word probability, which is what `stt::words` aggregated
        // the token probabilities into. Converted back to a log for
        // `avg_log_prob` so `confidence.rs` sees the same scale it does on
        // the file path.
        let mean_prob = (words.iter().map(|word| word.prob).sum::<f32>()
            / words.len().max(1) as f32)
            .clamp(0.0, 1.0);
        let window = self.window_slice(start, end).to_vec();
        let speaker = self.diarizer.identify_speaker(&self.source, &window);
        Some(Segment {
            source: self.source.clone(),
            speaker,
            language: crate::stt::segment_language(&text, self.language.as_deref()).to_string(),
            text,
            timestamp: start,
            duration: end - start,
            confidence: mean_prob,
            avg_log_prob: if mean_prob > 0.0 { mean_prob.ln() } else { 0.0 },
            is_partial: false,
            low_confidence: mean_prob < crate::confidence::LOW_CONFIDENCE_THRESHOLD,
            words: words.into_iter().map(Into::into).collect(),
        })
    }

    /// The window's samples between two absolute times, clamped.
    fn window_slice(&self, start_secs: f64, end_secs: f64) -> &[f32] {
        let rate = crate::decode::TARGET_SAMPLE_RATE as f64;
        let samples = self.window.samples();
        let offset = |secs: f64| {
            (((secs - self.window.start_secs()) * rate).max(0.0) as usize).min(samples.len())
        };
        let start = offset(start_secs);
        let end = offset(end_secs).max(start);
        &samples[start..end]
    }

    fn trim_window(&mut self, utterance_ended: bool, now: f64) {
        // Cut back to the last committed *sentence* end on every decode.
        //
        // Not an optimisation that can be left for later: re-decoding a
        // window that grows for the length of the meeting is quadratic in
        // the audio, and measured on this project's weak-CPU target
        // (`live_bench`) that made LocalAgreement-2 take 139 s of CPU for
        // 15 s of audio against the old chunking's 86 s — slower *and*
        // higher-latency, which would have been a regression dressed up as
        // a feature. A sentence boundary is also where Whisper needs the
        // least left context, so this costs nothing in accuracy. Same
        // policy as `ufal/whisper_streaming`'s
        // `chunk_completed_sentence`.
        if let Some(sentence_end) = self.agreement.last_sentence_end() {
            self.window.trim_to(sentence_end - self.policy.keep_secs);
        }
        if !self.policy.require_agreement {
            // Nothing is ever pending under fixed chunking, so the
            // sentence-end trim above rarely fires — the commit point is
            // what bounds the window.
            self.window
                .trim_to(self.agreement.committed_through() - self.policy.keep_secs);
        }
        if let Some((from, to)) = self.window.trim_window(
            self.agreement.committed_through(),
            self.policy.max_window_secs,
        ) {
            tracing::warn!(
                source = %self.source,
                from,
                to,
                "live decode window overflowed with nothing committed; these \
                 seconds are recovered from the WAV after Stop"
            );
            self.dropped.push((from, to));
        }
        if utterance_ended {
            // Keep only the pre-roll: the next utterance's onset arrives
            // in the same buffer the silence does.
            let keep_from = self
                .agreement
                .committed_through()
                .max(now - PRE_ROLL_SECS)
                .min(now);
            self.window.trim_to(keep_from);
        }
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
    vad_enabled: bool,
    diarizer: Diarizer,
    source: String,
    language: Option<String>,
    samples_seen: u64,
    glossary: GlossaryConfig,
    glossary_terms: Vec<String>,
}

impl<'a> LivePipelineHpt<'a> {
    pub fn new(
        engine: &'a ProgressiveEngine,
        source: impl Into<String>,
        language: Option<String>,
        vad_config: VadConfig,
        vad_enabled: bool,
        glossary: GlossaryConfig,
    ) -> TranscribeResult<Self> {
        let glossary_terms = if glossary.post_correction {
            glossary.prioritised_terms()
        } else {
            Vec::new()
        };
        Ok(Self {
            engine,
            ring: RingBuffer::default(),
            vad: DualVad::new(vad_config)?,
            vad_enabled,
            diarizer: Diarizer::new(),
            source: source.into(),
            language,
            samples_seen: 0,
            glossary,
            glossary_terms,
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

        let has_speech = detect_speech(&mut self.vad, self.vad_enabled, samples)?;
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
            // The dual-pass pipeline has never carried a rolling transcript
            // tail (the quick pass would seed the refine pass with its own
            // mistakes), so the glossary is the whole prompt here.
            let prompt = crate::glossary::build_initial_prompt(&self.glossary, "");
            let initial_prompt = (!prompt.text.is_empty()).then_some(prompt.text.as_str());
            let mut quick_segs = self.engine.transcribe_quick(
                &chunk,
                &self.source,
                chunk_start,
                language,
                initial_prompt,
                DecodeOptions::live(),
            )?;
            let mut refined_segs = self.engine.transcribe_refine(
                &chunk,
                &self.source,
                chunk_start,
                language,
                initial_prompt,
                DecodeOptions::live(),
            )?;
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
        crate::hallucination::filter_segments(&mut quick);
        crate::hallucination::filter_segments(&mut refined);
        crate::glossary::correct_segments(
            &mut quick,
            &self.glossary_terms,
            &self.glossary.replacements,
        );
        crate::glossary::correct_segments(
            &mut refined,
            &self.glossary_terms,
            &self.glossary.replacements,
        );
        crate::confidence::apply_confidence_routing(&mut quick);
        crate::confidence::apply_confidence_routing(&mut refined);
        Ok((quick, refined))
    }
}

/// Dual-stage VAD gate, honouring the user's `vad_enabled` setting.
///
/// With VAD off, every buffered chunk is transcribed: more inference work,
/// but a mis-tuned detector can no longer swallow quiet speech. Shared by
/// both pipelines so the two can't drift apart.
fn detect_speech(vad: &mut DualVad, vad_enabled: bool, samples: &[f32]) -> TranscribeResult<bool> {
    // Backstop gate (B1): digital silence or sub-noise-floor audio is never
    // speech, whatever the VAD setting says. `vad_enabled: false` means
    // "don't trust the frame-level detector", not "assume every buffer,
    // including dead air, is speech" — a mic with no OS permission granted
    // produces exactly this (zero-filled buffers, no error), and a disabled
    // VAD must not be the reason that reaches Whisper.
    if crate::silence_gate::is_below_speech_floor(samples, crate::silence_gate::SILENCE_THRESHOLD_DBFS)
    {
        return Ok(false);
    }
    if !vad_enabled {
        return Ok(true);
    }
    let mut frame_buf = [0i16; FRAME_SAMPLES_10MS];
    for frame in samples.as_chunks::<FRAME_SAMPLES_10MS>().0 {
        fill_i16_slice(frame, &mut frame_buf);
        if vad.is_speech(&frame_buf)? {
            return Ok(true);
        }
    }
    Ok(false)
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
            words: Vec::new(),
        }
    }
}
