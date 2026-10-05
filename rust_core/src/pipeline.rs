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
use crate::stt::WhisperEngine;
use crate::vad::{DualVad, VadConfig, FRAME_SAMPLES_10MS};

pub struct LivePipeline<'a> {
    engine: &'a WhisperEngine,
    ring: RingBuffer,
    vad: DualVad,
    vad_enabled: bool,
    diarizer: Diarizer,
    source: String,
    language: Option<String>,
    samples_seen: u64,
    last_transcript_tail: String,
    glossary: GlossaryConfig,
    /// `glossary.prioritised_terms()`, computed once per session rather than
    /// per chunk — post-correction runs on every segment.
    glossary_terms: Vec<String>,
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
    Vu { source: String, level: f32 },
    Segment(Segment),
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
            let engine = WhisperEngine::load_with_gpu(
                &config.quick_model_path,
                config.gpu_enabled,
                config.gpu_device,
            )?;
            return Self::spawn_with_engine(engine, config, samples_rx, events_tx);
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
                if route == HptRoute::DirectRefine {
                    return Self::spawn_with_engine(engine, config, samples_rx, events_tx)
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
        let engine = WhisperEngine::load_with_gpu(model, config.gpu_enabled, config.gpu_device)?;
        Self::spawn_with_engine(engine, config, samples_rx, events_tx)
            .map(|worker| worker.with_route(route))
    }

    /// Single-model worker over an already-loaded engine. Used by
    /// [`Self::spawn`] and by adaptive HPT's direct-q5 fast path so the
    /// benchmark-loaded engine is reused instead of double-loading the
    /// 548 MB refine model.
    fn spawn_with_engine(
        engine: WhisperEngine,
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
            let mut pipeline = match LivePipeline::new(
                &engine,
                source.clone(),
                language,
                VadConfig::default(),
                vad_enabled,
                glossary,
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
                    Ok(segments) => {
                        for segment in segments {
                            let _ = events_tx.send(LiveEvent::Segment(segment));
                        }
                    }
                    Err(error) => tracing::error!(source = %source, %error, "live pipeline failed"),
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
                if route == HptRoute::DirectRefine {
                    // Only this route can reuse the benchmark's engine; the
                    // others need a different model set.
                    return Self::spawn_with_engine(engine, config, samples_rx, events_tx)
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
                let engine = WhisperEngine::load_with_gpu(
                    refine_model_path,
                    config.gpu_enabled,
                    config.gpu_device,
                )?;
                Self::spawn_with_engine(engine, config, samples_rx, events_tx)
            }
            HptRoute::DualPass => Self::spawn_hpt(config, samples_rx, events_tx),
            HptRoute::QuickOnly => {
                let engine = WhisperEngine::load_with_gpu(
                    &config.quick_model_path,
                    config.gpu_enabled,
                    config.gpu_device,
                )?;
                Self::spawn_with_engine(engine, config, samples_rx, events_tx)
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
            last_transcript_tail: String::new(),
            glossary,
            glossary_terms,
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

        let has_speech = detect_speech(&mut self.vad, self.vad_enabled, samples)?;
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
            let prompt =
                crate::glossary::build_initial_prompt(&self.glossary, &self.last_transcript_tail);
            let segments = self.engine.transcribe_chunk(
                &chunk,
                &self.source,
                chunk_start,
                self.language.as_deref(),
                Some(&prompt.text),
            )?;
            for mut segment in segments {
                segment.speaker = self.diarizer.identify_speaker(&self.source, &chunk);
                fresh.push(segment);
            }
        }
        crate::progressive::filter_loops(&mut fresh);
        // Room tone loud enough to pass the VAD still reads as silence to
        // Whisper, which answers with a subtitle caption rather than an
        // empty string. Dropping those here keeps `[MENGENI]` out of the
        // live transcript as well as the file one.
        crate::hallucination::filter_segments(&mut fresh);
        crate::glossary::correct_segments(&mut fresh, &self.glossary_terms);
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
            )?;
            let mut refined_segs = self.engine.transcribe_refine(
                &chunk,
                &self.source,
                chunk_start,
                language,
                initial_prompt,
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
        crate::glossary::correct_segments(&mut quick, &self.glossary_terms);
        crate::glossary::correct_segments(&mut refined, &self.glossary_terms);
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
