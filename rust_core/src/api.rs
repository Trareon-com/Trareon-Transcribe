//! Public API surface exposed to Flutter via flutter_rust_bridge V2.
//!
//! FRB-compatible: no lifetimes in public signatures, every fallible
//! function returns `Result<T, TranscribeError>`. Streams (`vu_meter_stream`,
//! `transcript_stream`, live audio thread wiring) land once FRB codegen is
//! set up against the actual Flutter app.

use std::collections::HashMap;
use std::path::PathBuf;

use crate::audio::{AudioDeviceInfo, SessionConfig};
use crate::doctor::{format_checks, run_checks, Check};
use crate::error::TranscribeError;
use crate::export::notulen::{NotulenDraft, NotulenForm};
use crate::export::{Bookmark, ExportFormat, ExportedFile, Segment};
use crate::model::ModelInfo;
use crate::session::{
    CaptureHealth, RecoverableSession, RecoveredSession, SessionEvent, SessionRecoverySnapshot,
    SessionStatus,
};
use crate::settings::AppSettings;

pub fn run_preflight_checks() -> Vec<Check> {
    let settings = crate::settings::load_settings();
    run_checks(&settings)
}

pub fn format_preflight_checks(checks: Vec<Check>) -> String {
    format_checks(&checks)
}

/// What this *build* can actually do for GPU inference.
///
/// The Settings switch is a request, not a capability: whisper.cpp only
/// has a GPU backend if one was compiled in, so on a plain Linux build
/// turning "Akselerasi GPU" on changes nothing at all. The settings screen
/// used to claim "Transkripsi menggunakan GPU (Vulkan/CUDA/Metal)" purely
/// because the switch was on, which is a statement about the UI rather
/// than about the machine.
pub struct GpuCapability {
    /// True when a GPU backend is compiled into this binary.
    pub available: bool,
    /// Human-facing backend name: "Vulkan", "CoreML", "Metal", "CPU".
    pub backend: String,
}

pub fn gpu_capability() -> GpuCapability {
    #[cfg(feature = "gpu-vulkan")]
    {
        GpuCapability {
            available: true,
            backend: "Vulkan".to_string(),
        }
    }
    #[cfg(all(not(feature = "gpu-vulkan"), target_os = "macos"))]
    {
        // whisper.cpp builds Metal (and CoreML on Apple Silicon) in by
        // default on Apple platforms.
        GpuCapability {
            available: true,
            backend: crate::stt::detect_backend(),
        }
    }
    #[cfg(all(not(feature = "gpu-vulkan"), not(target_os = "macos")))]
    {
        GpuCapability {
            available: false,
            backend: "CPU".to_string(),
        }
    }
}

/// Installs a `tracing` subscriber writing to stderr. Without this,
/// every `tracing::error!`/`warn!` call in the engine (session/pipeline
/// failures, capture errors, etc.) is silently dropped — there is no
/// default subscriber. Call once, right after `RustLib.init()`, before
/// anything else. Safe to call more than once (subsequent calls are a
/// harmless no-op via `try_init`).
pub fn init_logging() {
    let _ = tracing_subscriber::fmt::try_init();
}

pub fn engine_version() -> String {
    env!("CARGO_PKG_VERSION").to_string()
}

pub fn health_check() -> Result<bool, TranscribeError> {
    Ok(true)
}

// --- Audio devices -----------------------------------------------------

pub fn list_audio_devices() -> Result<Vec<AudioDeviceInfo>, TranscribeError> {
    crate::audio::list_input_devices()
}

/// Playback devices — what the "Pengeras Suara" / loopback picker must show.
///
/// The speaker picker used to call [`list_audio_devices`], so it offered the
/// user a list of microphones to record the system audio from. On Linux this
/// resolves to PulseAudio/PipeWire *sinks* (same source of truth as
/// `audio::pulse`, which the loopback capture then turns into
/// `<sink>.monitor`), so what the picker shows and what gets recorded agree.
pub fn list_output_audio_devices() -> Result<Vec<AudioDeviceInfo>, TranscribeError> {
    crate::audio::list_output_devices()
}

// --- Session control -----------------------------------------------------

pub fn start_session(config: SessionConfig) -> Result<String, TranscribeError> {
    crate::session::start_session(config)
}

pub fn stop_session(session_id: String) -> Result<(), TranscribeError> {
    crate::session::stop_session(&session_id)
}

pub fn toggle_mic(session_id: String, enabled: bool) -> Result<(), TranscribeError> {
    crate::session::toggle_mic(&session_id, enabled)
}

pub fn toggle_speaker(session_id: String, enabled: bool) -> Result<(), TranscribeError> {
    crate::session::toggle_speaker(&session_id, enabled)
}

pub fn get_session_status(session_id: String) -> Result<SessionStatus, TranscribeError> {
    crate::session::get_status(&session_id)
}

pub fn poll_session_events(session_id: String) -> Result<Vec<SessionEvent>, TranscribeError> {
    crate::session::poll_events(&session_id)
}

/// Sessions left behind by a crash, with what is actually recoverable for
/// each (segment count, audio duration per source) rather than just the
/// configuration the old snapshot carried.
pub fn list_recoverable_sessions() -> Result<Vec<RecoverableSession>, TranscribeError> {
    crate::session::list_recoverable_sessions()
}

/// Restores a crashed session: returns its recovered transcript along with
/// the live session id, and resumes capture into the same audio files.
pub fn recover_session(
    snapshot: SessionRecoverySnapshot,
) -> Result<RecoveredSession, TranscribeError> {
    crate::session::recover_session(snapshot)
}

/// Discards one recoverable session and everything it held.
pub fn delete_recoverable_session(session_id: String) -> Result<(), TranscribeError> {
    crate::session::delete_recoverable_session(&session_id)
}

/// Live capture health: how much audio each source has actually delivered,
/// whether it has ever been above the noise floor ("rekaman terkonfirmasi")
/// and how long it has been quiet. Drives both the recording indicator and
/// the integrity summary shown at Stop.
pub fn get_capture_health(session_id: String) -> Result<CaptureHealth, TranscribeError> {
    crate::session::get_capture_health(&session_id)
}

/// Mirrors the user-entered title into the recovery snapshot, so a crashed
/// session appears in the recovery dialog under its name.
pub fn set_session_title(session_id: String, title: String) -> Result<(), TranscribeError> {
    crate::session::set_session_title(&session_id, &title)
}

// --- Disk space -----------------------------------------------------

/// Free space on the volume holding `path`, plus whether that is enough to
/// keep recording. Called before a session starts and periodically while
/// one runs — three hours of "Rapat Online" is ~1.4 GB of WAV, and nothing
/// used to check.
pub fn check_disk_space(path: String) -> crate::disk::DiskSpaceStatus {
    crate::disk::status_for(std::path::Path::new(&path))
}

// --- Model management -----------------------------------------------------

/// Benchmark a model's realtime factor (seconds of audio transcribed per
/// second of wall-clock) using a 5s calibration chunk. Used by adaptive
/// HPT to decide whether a device can run q5 in a single pass.
/// Returns an error if the model cannot be loaded.
/// (No network access — purely local inference benchmark.)
pub fn benchmark_rtf(model_path: String) -> Result<f64, TranscribeError> {
    let engine = crate::stt::WhisperEngine::load(std::path::Path::new(&model_path))
        .map_err(|e| TranscribeError::Model(format!("benchmark model load failed: {e}")))?;
    Ok(crate::benchmark::benchmark_rtf(&engine))
}

pub fn list_available_models(models_dir: String) -> Vec<ModelInfo> {
    crate::model::list_available_models(&PathBuf::from(models_dir))
}

pub fn is_model_downloaded(models_dir: String, model_id: String) -> bool {
    crate::model::is_model_downloaded(&PathBuf::from(models_dir), &model_id)
}

pub async fn download_model(models_dir: String, model_id: String) -> Result<(), TranscribeError> {
    let models_path = PathBuf::from(models_dir);
    let info = crate::model::resolve_model_info(&models_path, &model_id)?;
    let dest_path = crate::model::resolve_model_path(&models_path, &model_id)?;

    if let Some(parent) = dest_path.parent() {
        std::fs::create_dir_all(parent).map_err(TranscribeError::from)?;
    }

    // Progress is a single global slot (see model.rs), shared across every
    // call — without resetting here, a caller downloading models back to
    // back (onboarding) would briefly read the *previous* download's 100%
    // before the first progress callback for this one lands.
    crate::model::reset_download_progress();

    crate::model::download_with_resume(&info.url, &dest_path, |progress| {
        crate::model::set_download_progress(progress.bytes_downloaded, progress.total_bytes);
    })
    .await?;

    if !info.sha256.is_empty() {
        if let Err(e) = crate::model::verify_checksum(&dest_path, &info.sha256) {
            // A file that fails its checksum is corrupt or partial. Leaving
            // it on disk is worse than having nothing: `is_model_downloaded`
            // then reports the model as installed, and the next attempt's
            // `download_with_resume` appends onto the bad bytes from the
            // recorded offset, so the checksum can never come out right
            // again — a poisoned resume the user cannot clear from the UI.
            // Removing it makes the retry a clean download.
            crate::model::discard_corrupt_download(&dest_path);
            return Err(e);
        }
    }

    Ok(())
}

/// Poll the current download progress. Returns `None` if no download is
/// in progress or progress tracking has been reset.
pub fn get_download_progress() -> Option<(u64, u64)> {
    crate::model::read_download_progress().map(|p| (p.bytes_downloaded, p.total_bytes))
}

// --- Export -----------------------------------------------------

pub fn export_session(
    segments: Vec<Segment>,
    formats: Vec<ExportFormat>,
    output_dir: String,
    title: String,
) -> Result<Vec<ExportedFile>, TranscribeError> {
    crate::export::export_segments(&segments, &formats, &PathBuf::from(output_dir), &title)
}

/// As [`export_session`], but leads the Markdown/TXT/HTML/DOCX output with
/// `summary` (Markdown, from [`generate_summary`]) and the meeting's
/// `bookmarks` as "Poin Penting". An empty `summary` with no bookmarks
/// produces byte-identical output to [`export_session`].
pub fn export_session_with_summary(
    segments: Vec<Segment>,
    formats: Vec<ExportFormat>,
    output_dir: String,
    title: String,
    summary: String,
    bookmarks: Vec<Bookmark>,
) -> Result<Vec<ExportedFile>, TranscribeError> {
    crate::export::export_segments_full(
        &segments,
        &formats,
        &PathBuf::from(output_dir),
        &title,
        &summary,
        &bookmarks,
    )
}

// --- Notulen Rapat resmi (F2) ----------------------------------------------

/// Writes the official "Notulen Rapat" DOCX into the session folder.
///
/// `form.variant` selects the layout ("Notulen Dinas" or "Notulen Ringkas").
/// The file is named `Notulen - <title>.docx` so it sits next to the
/// transcript exports without colliding with the plain DOCX transcript.
pub fn export_notulen(
    form: NotulenForm,
    segments: Vec<Segment>,
    output_dir: String,
    title: String,
) -> Result<ExportedFile, TranscribeError> {
    let bytes = crate::export::notulen::to_docx_bytes(&form, &segments)?;
    let output_dir = PathBuf::from(output_dir);
    let session_dir = crate::export::session_dir_for(&output_dir, &title);
    std::fs::create_dir_all(&session_dir).map_err(TranscribeError::from)?;
    let filename = format!(
        "Notulen - {}.docx",
        crate::export::sanitize_filename(&title)
    );
    let path = session_dir.join(&filename);
    crate::export::atomic_write(&path, &bytes)?;
    let size_bytes = std::fs::metadata(&path)
        .map_err(TranscribeError::from)?
        .len();
    Ok(ExportedFile {
        filename,
        path: path.to_string_lossy().to_string(),
        size_bytes,
    })
}

/// Prefills a [`NotulenForm`]'s body sections from an AI summary: peserta,
/// pembahasan, keputusan and the tugas/PJ/tenggat rows. Pure and local — the
/// summary text is already in hand.
pub fn notulen_draft_from_summary(summary: String) -> NotulenDraft {
    crate::export::notulen::draft_from_summary(&summary)
}

/// Renders bookmarks as the `"[mm:ss] catatan"` lines the notulen's
/// "Poin Penting" section and every export use.
pub fn format_bookmarks(bookmarks: Vec<Bookmark>) -> Vec<String> {
    crate::export::notulen::poin_penting_from_bookmarks(&bookmarks)
}

// --- Mesin notulen (Sprint 7) ----------------------------------------------

/// One template, as the export form's picker shows it.
pub struct NotulenTemplateInfo {
    pub template: crate::notulen::NotulenTemplate,
    /// Stable id, used in settings and the benchmark.
    pub id: String,
    pub label: String,
    pub description: String,
    /// What the document calls itself, e.g. "NOTULA RAPAT".
    pub judul_dokumen: String,
    /// Jenis naskah dinas for the archive sidecar.
    pub jenis_naskah: String,
    /// Headings this template requires, in document order.
    pub bagian_wajib: Vec<String>,
    /// Whether it carries a kop surat, a nomor and a signature block.
    pub resmi: bool,
}

/// Every notulen template, in the order the picker shows them.
pub fn notulen_templates() -> Vec<NotulenTemplateInfo> {
    crate::notulen::NotulenTemplate::all()
        .iter()
        .map(|template| NotulenTemplateInfo {
            template: *template,
            id: template.id().to_string(),
            label: template.label().to_string(),
            description: template.description().to_string(),
            judul_dokumen: template.document_title().to_string(),
            jenis_naskah: template.jenis_naskah().to_string(),
            bagian_wajib: template
                .required_sections()
                .iter()
                .map(|section| section.heading.to_string())
                .collect(),
            resmi: template.is_formal(),
        })
        .collect()
}

/// A generated notulen plus every check that was run on it.
pub struct NotulenHasil {
    /// Prefilled form, ready for the export screen to show and edit.
    pub form: NotulenForm,
    /// What the JSON parser had to forgive, in Indonesian. A long list is
    /// a signal that the chosen model is a poor fit.
    pub perbaikan: Vec<String>,
    pub struktur: crate::notulen::schema::StructureReport,
    pub fakta: crate::notulen::factcheck::LaporanFakta,
    pub ragam: Vec<crate::notulen::register::RegisterFinding>,
    /// `true` when the meeting was long enough to need map-reduce.
    pub map_reduce: bool,
    /// The model's answer verbatim. Shown in Diagnostik, never in the
    /// document — a notulen the parser mangled is only debuggable if the
    /// original survived.
    pub mentah: String,
}

/// Generates a notulen from `segments` and checks it.
///
/// The only networked call in the notulen path, and it runs once per
/// explicit press of "Buat Notulen". `base` is the form as the user left
/// it, so regenerating does not wipe the identity block they typed.
///
/// Progress is published for [`read_summary_progress`] to poll, the same
/// way the map-reduce summary does: a thirty-minute meeting is several
/// round trips and the user has to see which.
pub async fn generate_notulen(
    config: crate::summary::SummaryConfig,
    template: crate::notulen::NotulenTemplate,
    segments: Vec<Segment>,
    bookmarks: Vec<Bookmark>,
    base: NotulenForm,
    panjang: crate::notulen::NotulenLength,
    konteks_dokumen: Option<String>,
) -> Result<NotulenHasil, TranscribeError> {
    let marks = crate::export::notulen::poin_penting_from_bookmarks(&bookmarks);
    crate::summary::reset_progress();
    let outcome = crate::summary::generate_notulen(
        config,
        template,
        segments.clone(),
        marks,
        panjang,
        konteks_dokumen,
        crate::summary::publish_progress,
    )
    .await;
    crate::summary::reset_progress();
    let response = outcome?;

    let notulen = &response.parsed.notulen;
    let form = crate::notulen::to_form(notulen, template, &base);
    let ragam = crate::notulen::register::check(&notulen_text(&form));
    Ok(NotulenHasil {
        struktur: crate::notulen::schema::check_structure(notulen, template),
        fakta: crate::notulen::factcheck::periksa(notulen, &segments),
        ragam,
        perbaikan: response.parsed.perbaikan,
        map_reduce: response.map_reduce,
        mentah: response.mentah,
        form,
    })
}

/// Reads a local .txt/.md/.pdf file for use as notulen context. Never
/// uploads or caches the file anywhere else.
pub fn extract_notulen_document_context(path: String) -> Result<String, TranscribeError> {
    crate::notulen::context::extract_document_text(std::path::Path::new(&path))
}

/// The document's prose, for the register checker and the preview.
///
/// Headings and labels are excluded: they are the app's words, not the
/// model's, and flagging "Tindak Lanjut" for register would be noise.
fn notulen_text(form: &NotulenForm) -> String {
    let mut out = String::new();
    let mut line = |text: &str| {
        if !text.trim().is_empty() {
            out.push_str(text.trim());
            out.push('\n');
        }
    };
    line(&form.ringkasan);
    for item in &form.peserta {
        line(item);
    }
    for item in &form.agenda {
        line(item);
    }
    for item in &form.pihak {
        line(item);
    }
    for entry in &form.jalannya_rapat {
        line(&format!("{} {}", entry.pembicara, entry.pokok));
    }
    line(&form.pembahasan);
    for item in &form.keputusan {
        line(item);
    }
    for row in &form.tindak_lanjut {
        line(&format!(
            "{} {} {}",
            row.tugas, row.penanggung_jawab, row.tenggat
        ));
    }
    out
}

/// Re-runs every check on a form the user has edited.
///
/// Citations do not survive editing — once a human rewrites a keputusan
/// the model's `segmen` no longer describes it — so the fact check here
/// runs without them, checking each statement against the whole
/// transcript and its entities. That is weaker than the generated
/// report and is the honest amount of checking available.
pub fn periksa_notulen(
    form: NotulenForm,
    template: crate::notulen::NotulenTemplate,
    segments: Vec<Segment>,
) -> NotulenHasil {
    let notulen = crate::notulen::schema::from_form(&form);
    let ragam = crate::notulen::register::check(&notulen_text(&form));
    NotulenHasil {
        struktur: crate::notulen::schema::check_structure(&notulen, template),
        fakta: crate::notulen::factcheck::periksa(&notulen, &segments),
        ragam,
        perbaikan: Vec::new(),
        map_reduce: false,
        mentah: String::new(),
        form,
    }
}

/// Applies the register fixes that have exactly one correct answer.
///
/// Spelling and the clock format only. A colloquial clause is left alone,
/// because rewriting a sentence is a judgement call and a notulen is a
/// record of what was said.
pub fn rapikan_ragam(text: String) -> String {
    crate::notulen::register::normalise(&text)
}

// --- Ekspor siap SRIKANDI --------------------------------------------------

/// Prefills the archive metadata from the notulen form.
pub fn srikandi_metadata_default(form: NotulenForm) -> crate::srikandi::SrikandiMetadata {
    crate::srikandi::defaults_from_form(&form)
}

/// Checks the archive metadata before export.
pub fn srikandi_validate(
    metadata: crate::srikandi::SrikandiMetadata,
) -> Vec<crate::srikandi::TemuanMetadata> {
    crate::srikandi::validate(&metadata)
}

/// Whether the metadata is complete enough to register.
pub fn srikandi_siap_unggah(metadata: crate::srikandi::SrikandiMetadata) -> bool {
    crate::srikandi::siap_unggah(&metadata)
}

/// Writes the notulen and its archive sidecar into the session folder.
///
/// Four files: the DOCX (the signing copy), a PDF for circulation, and
/// the metadata as JSON and CSV. The upload to SRIKANDI itself is manual
/// — there is no API — and `docs/SRIKANDI-EXPORT.md` is the procedure.
pub fn export_notulen_srikandi(
    form: NotulenForm,
    metadata: crate::srikandi::SrikandiMetadata,
    segments: Vec<Segment>,
    output_dir: String,
    title: String,
) -> Result<Vec<ExportedFile>, TranscribeError> {
    let session_dir = crate::export::session_dir_for(&PathBuf::from(output_dir), &title);
    std::fs::create_dir_all(&session_dir).map_err(TranscribeError::from)?;
    let stem = format!(
        "{} - {}",
        form.template.jenis_naskah(),
        crate::export::sanitize_filename(&title)
    );

    let docx_name = format!("{stem}.docx");
    let mut written: Vec<ExportedFile> = Vec::new();
    for (filename, bytes) in [
        (
            docx_name.clone(),
            crate::export::notulen::to_docx_bytes(&form, &segments)?,
        ),
        (
            format!("{stem}.pdf"),
            crate::export::pdf::notulen_to_pdf_bytes(&form, &segments)?,
        ),
        (
            format!("{stem} - metadata.json"),
            crate::srikandi::to_json(&metadata, &docx_name).into_bytes(),
        ),
        (
            format!("{stem} - metadata.csv"),
            crate::srikandi::to_csv(&metadata, &docx_name).into_bytes(),
        ),
    ] {
        let path = session_dir.join(&filename);
        crate::export::atomic_write(&path, &bytes)?;
        let size_bytes = std::fs::metadata(&path)
            .map_err(TranscribeError::from)?
            .len();
        written.push(ExportedFile {
            filename,
            path: path.to_string_lossy().to_string(),
            size_bytes,
        });
    }
    Ok(written)
}

// --- Penyiapan model notulen (first run) -----------------------------------

/// Checks whether an Ollama runtime answers at `base_url`.
///
/// Never fails: "not installed" is the expected answer on first run.
pub async fn llm_detect(base_url: String) -> crate::summary::OllamaStatus {
    crate::summary::detect_ollama(base_url).await
}

/// RAM and thread count of this machine, for the recommendation.
pub fn llm_hardware() -> crate::llm_setup::HardwareProfile {
    crate::llm_setup::HardwareProfile::probe()
}

/// The model this machine should run, and why.
pub fn llm_recommend(
    hardware: crate::llm_setup::HardwareProfile,
) -> crate::llm_setup::Recommendation {
    crate::llm_setup::recommend(&hardware)
}

/// Every model the setup step offers.
pub fn llm_catalogue() -> Vec<crate::llm_setup::ModelOption> {
    crate::llm_setup::catalogue()
}

/// The tag the app configures when the user accepts the default.
///
/// Exposed so the settings screen's "Model" hint names the model the
/// bake-off actually chose. It used to hardcode a tag that was never in
/// the catalogue, which told a user who typed it verbatim to pull a model
/// the app has no measurements for.
pub fn llm_default_model() -> String {
    crate::llm_setup::DEFAULT_MODEL.to_string()
}

/// How to install Ollama on `os` (`"macos"`, `"windows"`, `"linux"`).
pub fn llm_install_guide(os: String) -> crate::llm_setup::InstallGuide {
    crate::llm_setup::install_guide(&os)
}

/// The operating system this build is running on, for [`llm_install_guide`].
pub fn current_os() -> String {
    std::env::consts::OS.to_string()
}

/// Where a running model download has got to, or `None`.
///
/// A single global slot, like the map-reduce progress: only one pull runs
/// at a time because the button disables itself, and polling is how Dart
/// sees inside one long-lived FRB future.
static PULL_PROGRESS: std::sync::Mutex<Option<crate::llm_setup::PullProgress>> =
    std::sync::Mutex::new(None);

pub fn read_llm_pull_progress() -> Option<crate::llm_setup::PullProgress> {
    PULL_PROGRESS.lock().ok()?.clone()
}

/// Downloads `model` into the Ollama at `base_url`.
///
/// Records one audit entry on success, so the Privacy Report shows that
/// the app fetched something over the network and from where.
pub async fn llm_pull_model(base_url: String, model: String) -> Result<(), TranscribeError> {
    if let Ok(mut slot) = PULL_PROGRESS.lock() {
        *slot = None;
    }
    let result = crate::summary::pull_model(base_url, model, |progress| {
        if let Ok(mut slot) = PULL_PROGRESS.lock() {
            *slot = Some(progress);
        }
    })
    .await;
    if let Ok(mut slot) = PULL_PROGRESS.lock() {
        *slot = None;
    }
    result
}

/// Writes the raw mic/speaker audio captured during `session_id`'s live
/// recording as WAV files into the same session folder `export_session`
/// uses (blueprint §7.1: per-track mic.wav + speaker.wav). Call once, after
/// `stop_session` — the raw audio is only retained until the first call for
/// a given session. Returns an empty list (not an error) when there was no
/// live capture to save, e.g. a batch-file transcription.
pub fn export_session_audio(
    session_id: String,
    output_dir: String,
    title: String,
) -> Result<Vec<ExportedFile>, TranscribeError> {
    use crate::export::CapturedTrack;
    let audio = crate::session::take_session_audio(&session_id);
    let mic = audio
        .mic_file
        .as_deref()
        .map(CapturedTrack::File)
        .or_else(|| audio.mic_samples.as_deref().map(CapturedTrack::Samples));
    let speaker = audio
        .speaker_file
        .as_deref()
        .map(CapturedTrack::File)
        .or_else(|| audio.speaker_samples.as_deref().map(CapturedTrack::Samples));
    let exported =
        crate::export::export_session_audio(mic, speaker, &PathBuf::from(output_dir), &title)?;
    // The staged WAVs were the last thing holding the session's recovery
    // directory open.
    crate::session::release_recovery_dir(&session_id);
    Ok(exported)
}

// --- Hybrid Progressive Transcription (HPT) --------------------------------------

/// Result of an HPT (dual-model) file transcription: the quick pass from
/// `base` (`is_partial = true`) and the refined pass from
/// `large-v3-turbo-q5` (`is_partial = false`). Same segment order, same
/// `(source, timestamp)` keys — Dart replaces text by key.
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct ProgressiveFileResult {
    pub filename: String,
    pub quick_segments: Vec<Segment>,
    pub refined_segments: Vec<Segment>,
    pub language: String,
}

/// HPT file transcription: quick pass (base) then refine pass
/// (large-v3-turbo-q5) over the same decoded audio. UI shows
/// `quick_segments` immediately, then swaps in `refined_segments`
/// by key — target latency to first text: 3-5s.
#[allow(clippy::too_many_arguments)]
pub fn progressive_transcribe_file(
    quick_model_path: String,
    refine_model_path: String,
    path: String,
    language: Option<String>,
    gpu_enabled: bool,
    gpu_device: i32,
    glossary: crate::glossary::GlossaryConfig,
    speaker_hint: u32,
) -> Result<ProgressiveFileResult, TranscribeError> {
    let engine = crate::progressive::ProgressiveEngine::load(
        std::path::Path::new(&quick_model_path),
        std::path::Path::new(&refine_model_path),
        gpu_enabled,
        gpu_device,
    )?;
    let filename = std::path::Path::new(&path)
        .file_name()
        .map(|n| n.to_string_lossy().to_string())
        .unwrap_or_default();
    // The two-pass import used to publish no progress at all, so turning
    // Progressive Mode on made the import spinner stop moving until the
    // whole file was done (audit B.1-2). It reports the same snapshot the
    // single-model batch path does.
    let report = |status: crate::stt::file::BatchFileStatus, fraction: f32| {
        crate::stt::file::publish_batch_progress(0, 1, filename.clone(), status, fraction);
    };
    report(crate::stt::file::BatchFileStatus::Decoding, 0.0);
    let audio = crate::decode::decode_audio_file(std::path::Path::new(&path))?;

    // Kamus istilah: an import has no rolling transcript tail, so the
    // glossary is the whole `initial_prompt` for every chunk of both passes.
    let prompt = crate::glossary::build_initial_prompt(&glossary, "");
    let initial_prompt = (!prompt.text.is_empty()).then_some(prompt.text.as_str());

    // Chunk like file.rs: 30s chunks bound peak memory.
    const CHUNK_SECS: f64 = 30.0;
    let chunk_samples = (crate::decode::TARGET_SAMPLE_RATE as f64 * CHUNK_SECS) as usize;
    let mut quick_segments = Vec::new();
    let mut refined_segments = Vec::new();

    if audio.samples.len() <= chunk_samples {
        report(crate::stt::file::BatchFileStatus::Transcribing, 0.0);
        quick_segments = engine.transcribe_quick(
            &audio.samples,
            "file",
            0.0,
            language.as_deref(),
            initial_prompt,
            crate::stt::DecodeOptions::offline(),
        )?;
        report(crate::stt::file::BatchFileStatus::Transcribing, 0.5);
        refined_segments = engine.transcribe_refine(
            &audio.samples,
            "file",
            0.0,
            language.as_deref(),
            initial_prompt,
            crate::stt::DecodeOptions::offline(),
        )?;
        report(crate::stt::file::BatchFileStatus::Transcribing, 1.0);
    } else {
        let total_chunks = audio.samples.len().div_ceil(chunk_samples);
        // Both passes run over every chunk, so the unit of work is
        // 2 × chunks and the bar has to count them that way.
        let total_passes = (total_chunks * 2) as f32;
        let mut done = 0.0f32;
        for (idx, chunk) in audio.samples.chunks(chunk_samples).enumerate() {
            let start = idx as f64 * CHUNK_SECS;
            quick_segments.extend(engine.transcribe_quick(
                chunk,
                "file",
                start,
                language.as_deref(),
                initial_prompt,
                crate::stt::DecodeOptions::offline(),
            )?);
            done += 1.0;
            report(
                crate::stt::file::BatchFileStatus::Transcribing,
                done / total_passes,
            );
            refined_segments.extend(engine.transcribe_refine(
                chunk,
                "file",
                start,
                language.as_deref(),
                initial_prompt,
                crate::stt::DecodeOptions::offline(),
            )?);
            done += 1.0;
            report(
                crate::stt::file::BatchFileStatus::Transcribing,
                done / total_passes,
            );
        }
    }

    // Hallucination guard: collapse repeated runs in both passes.
    crate::progressive::filter_loops(&mut quick_segments);
    crate::progressive::filter_loops(&mut refined_segments);

    if glossary.post_correction {
        let terms = glossary.prioritised_terms();
        crate::glossary::correct_segments(&mut quick_segments, &terms, &glossary.replacements);
        crate::glossary::correct_segments(&mut refined_segments, &terms, &glossary.replacements);
    }

    // Speaker labels, same as the single-model file path. Both passes are
    // labelled from a single diarizer over the same audio so the quick and
    // refined rows for one utterance agree — a label that flips when the
    // refine pass lands reads as a bug to the user.
    // `speaker_hint` caps the clustering the same way the single-pass
    // import does (F10); 0 means "work it out".
    let mut diarizer = crate::diarization::Diarizer::with_max_speakers(speaker_hint as usize);
    crate::diarization::label_segments(&mut diarizer, &audio.samples, &mut refined_segments);
    let labels: std::collections::HashMap<String, String> = refined_segments
        .iter()
        .map(|s| {
            (
                format!("{}@{:.2}", s.source, s.timestamp),
                s.speaker.clone(),
            )
        })
        .collect();
    for segment in quick_segments.iter_mut() {
        let key = format!("{}@{:.2}", segment.source, segment.timestamp);
        if let Some(label) = labels.get(&key) {
            segment.speaker = label.clone();
        }
    }

    report(crate::stt::file::BatchFileStatus::Done, 1.0);
    Ok(ProgressiveFileResult {
        filename,
        quick_segments,
        refined_segments,
        language: language.unwrap_or_else(|| "auto".to_string()),
    })
}

// --- File transcription (batch) -----------------------------------------------------

/// Transcribes every file in `files` against a single loaded model.
///
/// Loading the model is the expensive part (≈550 MB for large-v3-turbo-q5),
/// so callers should pass the whole queue in one call rather than looping
/// per file. Returns one outcome per input file, in input order, carrying
/// either the transcript or the error — so a single bad file no longer
/// disappears from the results without explanation.
/// `speaker_hint` is how many people are in the recordings, or `0` for
/// "work it out" (F10).
pub fn transcribe_files_batch(
    model_path: String,
    files: Vec<String>,
    language: Option<String>,
    gpu_enabled: bool,
    gpu_device: i32,
    glossary: crate::glossary::GlossaryConfig,
    speaker_hint: u32,
) -> Result<Vec<crate::stt::file::BatchFileOutcome>, TranscribeError> {
    let engine = crate::stt::WhisperEngine::load_with_gpu(
        &PathBuf::from(&model_path),
        gpu_enabled,
        gpu_device,
    )?;
    let file_paths: Vec<PathBuf> = files.iter().map(PathBuf::from).collect();
    let mut outcomes = Vec::with_capacity(file_paths.len());

    crate::stt::file::transcribe_files_batch(
        &engine,
        &file_paths,
        language.as_deref(),
        &glossary,
        speaker_hint,
        |progress| {
            // Decoding is an interim status; only terminal states produce an
            // outcome, otherwise every file would be reported twice.
            if progress.result.is_none() && progress.error.is_none() {
                return;
            }
            outcomes.push(crate::stt::file::BatchFileOutcome {
                filename: progress.filename,
                path: files.get(progress.file_index).cloned().unwrap_or_default(),
                result: progress.result,
                error: progress.error,
            });
        },
    );

    Ok(outcomes)
}

/// Which file [`transcribe_files_batch`] is currently on. Poll this while the
/// batch future is in flight — that call only returns once *every* file is
/// done, so without it a long import shows a spinner that never moves.
pub fn get_batch_progress() -> Option<crate::stt::file::BatchProgressSnapshot> {
    crate::stt::file::read_batch_progress()
}

// --- Transcript completion (ITEM 0) ----------------------------------------
//
// "Every second recorded ends up in the transcript." The live worker can
// fall behind the meeting on a slow device, and Stop cannot wait for it —
// so what it never reached is transcribed afterwards from the saved WAV.
// Entirely local; this is the transcription path.

/// Length of an audio file in seconds, from its header where possible.
///
/// Falls back to a full decode only when the container declares no frame
/// count, so the coverage check on save stays cheap for a 1.4 GB WAV.
pub fn audio_duration_secs(path: String) -> Result<f64, TranscribeError> {
    let path = std::path::PathBuf::from(path);
    if let Some(secs) = crate::decode::probe_duration_secs(&path)? {
        return Ok(secs);
    }
    Ok(crate::decode::decode_audio_file(&path)?.duration_secs)
}

/// What `segments` account for across a recording of `total_secs`, and
/// which stretches they miss. Pure; no decode, no inference.
pub fn transcript_coverage(
    segments: Vec<Segment>,
    total_secs: f64,
) -> crate::coverage::CoverageReport {
    crate::coverage::report(&segments, total_secs, crate::coverage::MIN_GAP_SECS)
}

/// [`transcript_coverage`] against the real length of `audio_path`.
pub fn transcript_coverage_for_audio(
    segments: Vec<Segment>,
    audio_path: String,
) -> Result<crate::coverage::CoverageReport, TranscribeError> {
    let total = audio_duration_secs(audio_path)?;
    Ok(transcript_coverage(segments, total))
}

/// Folds `incoming` into `existing` by timestamp, keeping every existing
/// segment. Exposed so the UI can merge without re-running a pass.
pub fn merge_transcript_segments(existing: Vec<Segment>, incoming: Vec<Segment>) -> Vec<Segment> {
    crate::coverage::merge_by_timestamp(existing, incoming, crate::coverage::MERGE_TOLERANCE_SECS)
}

/// Transcribes the stretches of `audio_path` that `existing` does not
/// cover, and returns the merged transcript.
///
/// `job_key` identifies this pass in [`read_completion_progress`] — the
/// session directory, in practice. Progress is published per source, so a
/// "Rapat Online" session's two tracks report independently.
///
/// Returns `existing` untouched (and `added = 0`) when the transcript
/// already covers the recording, or when the uncovered stretches hold no
/// speech — a meeting with ten silent minutes at the end is complete, and
/// must not sit at "Menyelesaikan transkrip…" forever.
#[allow(clippy::too_many_arguments)]
pub fn complete_session_transcript(
    model_path: String,
    audio_path: String,
    job_key: String,
    existing: Vec<Segment>,
    language: Option<String>,
    gpu_enabled: bool,
    gpu_device: i32,
    glossary: crate::glossary::GlossaryConfig,
    vad_enabled: bool,
) -> Result<crate::completion::CompletionOutcome, TranscribeError> {
    let audio_path = std::path::PathBuf::from(audio_path);
    let source = crate::completion::source_for_audio(&audio_path).to_string();
    let engine = crate::stt::WhisperEngine::load_with_gpu(
        &PathBuf::from(&model_path),
        gpu_enabled,
        gpu_device,
    )?;
    let request = crate::completion::CompletionRequest {
        audio_path,
        source: source.clone(),
        language,
        glossary,
        vad_enabled,
    };
    let progress_key = job_key.clone();
    let progress_source = source.clone();
    let outcome =
        crate::completion::complete_transcript(&engine, &request, existing, |fraction, eta| {
            crate::completion::publish_progress(crate::completion::CompletionProgress {
                job_key: progress_key.clone(),
                source: progress_source.clone(),
                fraction,
                eta_secs: eta,
                done: fraction >= 1.0,
            });
        });
    // The slot is cleared whether the pass succeeded or failed: a stuck
    // "34%" in the sidebar after an error is its own bug report.
    crate::completion::clear_progress(&job_key, &source);
    outcome
}

/// Per-source progress of every completion pass currently running.
pub fn read_completion_progress() -> Vec<crate::completion::CompletionProgress> {
    crate::completion::read_progress()
}

/// Forgets one source's progress slot — used when a job is cancelled.
pub fn clear_completion_progress(job_key: String, source: String) {
    crate::completion::clear_progress(&job_key, &source);
}

/// Whether `text`, as a whole segment, is a caption Whisper invented over
/// silence rather than something a person said. Exposed so the UI can
/// explain a dropped line instead of silently removing it.
pub fn is_non_speech_text(text: String) -> bool {
    crate::hallucination::is_non_speech(&text)
}

// --- AI summary (the only networked feature; opt-in) -----------------------
//
// See `summary.rs` for the full privacy contract. In short: these two
// functions are the ONLY place user content leaves the process, they run
// only when the user presses a button, and the default endpoint is loopback.

/// Generates a Markdown meeting summary for `segments` using `config`.
///
/// Only the rendered transcript text is sent — no audio, no file paths, no
/// device names. Returns a `TranscribeError::Summary` (never a panic, never
/// a partial write) when the endpoint is unreachable or rejects the request,
/// so a failed summary can never look like a lost transcript.
pub async fn generate_summary(
    segments: Vec<Segment>,
    config: crate::summary::SummaryConfig,
    bookmarks: Vec<Bookmark>,
) -> Result<String, TranscribeError> {
    let transcript = crate::summary::transcript_text(&segments);
    let marks = crate::export::notulen::poin_penting_from_bookmarks(&bookmarks);
    crate::summary::generate_summary(config, transcript, marks).await
}

/// Summarises a meeting of any length, splitting it into time windows
/// and reducing when it does not fit one request (F15).
///
/// `progress` is polled from Dart via [`read_summary_progress`]; a
/// three-hour meeting is around eighteen round trips and the user has to
/// see which one is running.
pub async fn generate_summary_long(
    segments: Vec<Segment>,
    config: crate::summary::SummaryConfig,
    bookmarks: Vec<Bookmark>,
) -> Result<String, TranscribeError> {
    let marks = crate::export::notulen::poin_penting_from_bookmarks(&bookmarks);
    crate::summary::reset_progress();
    let result = crate::summary::generate_summary_long(
        config,
        segments,
        marks,
        crate::summary::publish_progress,
    )
    .await;
    crate::summary::reset_progress();
    result
}

/// How far a map-reduce summary has got, or `None` when none is running.
pub fn read_summary_progress() -> Option<crate::mapreduce::MapReduceProgress> {
    crate::summary::read_progress()
}

// --- Action items (F6) ------------------------------------------------------

/// Pulls the tugas / PJ / tenggat / status rows out of a summary,
/// however the model formatted them. Pure and local.
pub fn parse_action_items(summary: String) -> Vec<crate::actions::ActionItem> {
    crate::actions::parse_action_items(&summary)
}

/// Removes the raw JSON block from a summary once it has been parsed, so
/// the rendered summary does not show the machine-readable copy under
/// the checklist.
pub fn strip_action_items_block(summary: String) -> String {
    crate::actions::strip_json_block(&summary)
}

/// RFC 5545 calendar for a checklist: one `VTODO` per task, plus a
/// `VEVENT` for each task whose deadline resolves to a date.
/// `today` is `YYYY-MM-DD`, used to resolve "Jumat" and "besok".
pub fn action_items_to_ics(
    items: Vec<crate::actions::ActionItem>,
    calendar_name: String,
    today: String,
) -> String {
    crate::actions::to_ics(&items, &calendar_name, &today)
}

pub fn action_items_to_csv(items: Vec<crate::actions::ActionItem>) -> String {
    crate::actions::to_csv(&items)
}

/// Indonesian label for a status, for the checklist's dropdown.
pub fn action_status_label(status: crate::actions::ActionStatus) -> String {
    status.label().to_string()
}

// --- Summary provenance (F7) ------------------------------------------------

/// Splits a summary into lines and resolves each `[#n]` marker to a
/// transcript timestamp, dropping ids the transcript does not have.
pub fn parse_summary_provenance(
    summary: String,
    segments: Vec<Segment>,
) -> crate::provenance::SummaryProvenance {
    crate::provenance::parse_summary(&summary, &segments)
}

/// [`parse_summary_provenance`] plus the stricter check: a citation whose
/// segment shares almost no vocabulary with the claim is dropped too.
pub fn parse_summary_provenance_verified(
    summary: String,
    segments: Vec<Segment>,
) -> crate::provenance::SummaryProvenance {
    let parsed = crate::provenance::parse_summary(&summary, &segments);
    crate::provenance::verify_citations(parsed, &segments, crate::provenance::MIN_CITATION_OVERLAP)
}

/// The section headings a built-in template asks the model for — the starting
/// point when the user duplicates it into a template of their own (F8).
pub fn summary_template_headings(template: crate::summary::SummaryTemplate) -> Vec<String> {
    crate::summary::builtin_headings(template)
}

/// Composes the instruction a user-authored template sends, from its free-text
/// instructions plus its declared section headings.
pub fn compose_summary_instruction(instructions: String, headings: Vec<String>) -> String {
    crate::summary::compose_custom_instruction(&instructions, &headings)
}

/// Lists the models the configured summary endpoint offers, so the settings
/// UI can show a dropdown instead of a free-text field. Sends no transcript.
pub async fn list_summary_models(
    provider: crate::summary::SummaryProvider,
    base_url: String,
    api_key: String,
) -> Result<Vec<String>, TranscribeError> {
    crate::summary::list_summary_models(provider, base_url, api_key).await
}

/// Renders `segments` the way [`generate_summary`] would send them. Exposed
/// so the UI can show the user exactly what would be transmitted before they
/// opt in — no network access.
pub fn summary_preview_transcript(segments: Vec<Segment>) -> String {
    crate::summary::transcript_text(&segments)
}

// --- Kamus istilah (glossary) ----------------------------------------------

/// What the glossary actually contributes to one inference call.
///
/// `terms_used` / `terms_total` let Settings say "18 dari 40 istilah dipakai"
/// instead of silently discarding vocabulary: Whisper's prompt is capped at
/// 224 tokens and an over-long prompt degrades output, so the cap has to be
/// visible rather than a surprise. `u32` rather than `usize` so Dart sees an
/// `int` instead of a `BigInt`.
pub struct GlossaryPromptInfo {
    /// The exact `initial_prompt` string that would be sent to Whisper.
    pub prompt: String,
    pub terms_used: u32,
    pub terms_total: u32,
}

/// Previews the `initial_prompt` a glossary would produce. Pure and local.
pub fn glossary_prompt_preview(
    glossary: crate::glossary::GlossaryConfig,
    context_tail: String,
) -> GlossaryPromptInfo {
    let built = crate::glossary::build_initial_prompt(&glossary, &context_tail);
    GlossaryPromptInfo {
        prompt: built.text,
        terms_used: built.terms_used as u32,
        terms_total: built.terms_total as u32,
    }
}

/// Parses an imported glossary file (`.txt` one-per-line, or `.csv`/TSV where
/// the first column is the term). Deduplicates case-insensitively.
pub fn parse_glossary_file(content: String) -> Vec<String> {
    crate::glossary::parse_glossary(&content)
}

/// Renders the glossary for export: `csv = true` produces a one-column CSV
/// with an `istilah` header, otherwise one term per line.
pub fn render_glossary_file(terms: Vec<String>, csv: bool) -> String {
    crate::glossary::render_glossary(&terms, csv)
}

/// Applies the conservative post-correction pass to arbitrary text. Exposed so
/// the UI can preview what the glossary would change before enabling it.
pub fn apply_glossary_corrections(text: String, terms: Vec<String>) -> String {
    crate::glossary::apply_corrections(&text, &terms)
}

// --- Tanya arsip rapat (F12) ------------------------------------------------
//
// A local FTS5 index over every session, plus a question-answering step
// that reuses the summary endpoint. Indexing and retrieval never touch
// the network; only the answer does, and only through `summary::ask`.

/// Indexes one session, replacing whatever was indexed for it before.
/// Returns how many passages went in.
#[allow(clippy::too_many_arguments)]
pub fn archive_index_session(
    library_path: String,
    dir_path: String,
    title: String,
    date: String,
    segments: Vec<Segment>,
    summary: String,
    transcript_size: u64,
    transcript_mtime_ms: i64,
) -> Result<u32, TranscribeError> {
    let mut db = crate::archive::open(std::path::Path::new(&library_path))?;
    crate::archive::index_session(
        &mut db,
        &dir_path,
        &title,
        &date,
        &segments,
        &summary,
        transcript_size,
        transcript_mtime_ms,
    )
}

/// Whether `dir_path`'s transcript has changed since it was indexed.
pub fn archive_is_stale(
    library_path: String,
    dir_path: String,
    transcript_size: u64,
    transcript_mtime_ms: i64,
) -> Result<bool, TranscribeError> {
    let db = crate::archive::open(std::path::Path::new(&library_path))?;
    crate::archive::is_stale(&db, &dir_path, transcript_size, transcript_mtime_ms)
}

/// Drops a session from the index — called when the user deletes it.
pub fn archive_forget_session(
    library_path: String,
    dir_path: String,
) -> Result<(), TranscribeError> {
    let db = crate::archive::open(std::path::Path::new(&library_path))?;
    crate::archive::forget_session(&db, &dir_path)
}

/// Ranked passages for `question`. Purely local; this is what the UI
/// can show before (or instead of) asking a model anything.
pub fn archive_search(
    library_path: String,
    question: String,
    limit: u32,
) -> Result<Vec<crate::archive::ArchiveHit>, TranscribeError> {
    let db = crate::archive::open(std::path::Path::new(&library_path))?;
    crate::archive::search(&db, &question, limit)
}

pub fn archive_stats(
    library_path: String,
) -> Result<crate::archive::ArchiveStats, TranscribeError> {
    let path = std::path::Path::new(&library_path);
    let db = crate::archive::open(path)?;
    crate::archive::stats(&db, path)
}

pub fn archive_clear(library_path: String) -> Result<(), TranscribeError> {
    let db = crate::archive::open(std::path::Path::new(&library_path))?;
    crate::archive::clear(&db)
}

/// Answers `question` from the archive.
///
/// Retrieval is local. The composed answer comes from the configured
/// summary endpoint, and **only the retrieved passages** are sent — not
/// the archive, not the audio, not the file paths. Returns the answer
/// alongside the passages it was allowed to use, so the UI can render
/// each `[K1]` as a link into the meeting it came from.
pub async fn archive_ask(
    library_path: String,
    question: String,
    config: crate::summary::SummaryConfig,
) -> Result<crate::archive::ArchiveAnswer, TranscribeError> {
    let sources = archive_search(
        library_path,
        question.clone(),
        crate::archive::MAX_CONTEXT_PASSAGES as u32,
    )?;
    if sources.is_empty() {
        return Ok(crate::archive::ArchiveAnswer {
            answer: "Tidak ditemukan di arsip rapat.".to_string(),
            sources,
        });
    }
    let prompt = crate::archive::build_question_prompt(&question, &sources);
    let answer = crate::summary::ask(config, prompt).await?;
    Ok(crate::archive::ArchiveAnswer { answer, sources })
}

// --- Mode Kepatuhan UU PDP (F13) -------------------------------------------
//
// Redaction on export, retention limits, a local audit log and the
// consent notice. Entirely local; see `pdp` for the contract.

/// What `config` would mask in `text`, with byte offsets so the UI can
/// highlight it before anything is changed.
pub fn preview_redaction(
    text: String,
    config: crate::pdp::redaction::RedactionConfig,
) -> Vec<crate::pdp::redaction::PiiMatch> {
    crate::pdp::redaction::find_pii(&text, &config)
}

/// `text` with every match replaced by its Indonesian placeholder.
pub fn redact_text(text: String, config: crate::pdp::redaction::RedactionConfig) -> String {
    crate::pdp::redaction::redact(&text, &config)
}

/// Everything `config` would mask across a whole transcript, for the
/// pre-export preview.
pub fn preview_redaction_segments(
    segments: Vec<Segment>,
    config: crate::pdp::redaction::RedactionConfig,
) -> Vec<crate::pdp::redaction::PiiMatch> {
    segments
        .iter()
        .flat_map(|segment| crate::pdp::redaction::find_pii(&segment.text, &config))
        .collect()
}

/// Returns a redacted **copy** of `segments`. The stored transcript is
/// never rewritten — a user who cannot get the original back has lost
/// evidence, not protected it.
pub fn redact_segments(
    segments: Vec<Segment>,
    config: crate::pdp::redaction::RedactionConfig,
) -> Vec<Segment> {
    let mut copy = segments;
    let masked = crate::pdp::redaction::redact_segments(&mut copy, &config);
    if !masked.is_empty() {
        crate::pdp::audit::record(
            crate::pdp::audit::AuditEntry::new(
                crate::pdp::audit::AuditAction::RedactionApplied,
                "transkrip",
            )
            .with_detail(summarise_matches(&masked)),
        );
    }
    copy
}

/// "3 NIK, 1 email" — the detail line an audit entry carries. Counts
/// only; the values themselves never reach the log.
fn summarise_matches(matches: &[crate::pdp::redaction::PiiMatch]) -> String {
    use std::collections::BTreeMap;
    let mut counts: BTreeMap<&str, usize> = BTreeMap::new();
    for found in matches {
        *counts.entry(found.kind.label()).or_insert(0) += 1;
    }
    counts
        .into_iter()
        .map(|(label, count)| format!("{count} {label}"))
        .collect::<Vec<_>>()
        .join(", ")
}

/// Sessions in `library_path`, aged for the retention planner.
pub fn scan_library_ages(library_path: String) -> Vec<crate::pdp::retention::SessionAge> {
    crate::pdp::retention::scan_library(std::path::Path::new(&library_path))
}

/// What `policy` would delete from `library_path` right now. Pure
/// preview: nothing is removed until [`apply_retention`] runs.
pub fn preview_retention(
    library_path: String,
    policy: crate::pdp::retention::RetentionPolicy,
) -> crate::pdp::retention::RetentionPlan {
    let sessions = crate::pdp::retention::scan_library(std::path::Path::new(&library_path));
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_millis() as u64)
        .unwrap_or(0);
    crate::pdp::retention::plan(&sessions, policy, now)
}

/// One Indonesian sentence describing a plan, for the confirm dialog.
pub fn describe_retention_plan(plan: crate::pdp::retention::RetentionPlan) -> String {
    plan.summary()
}

/// Carries out a plan the user has confirmed, writing an audit entry per
/// deletion.
pub fn apply_retention(
    plan: crate::pdp::retention::RetentionPlan,
) -> Result<crate::pdp::retention::RetentionOutcome, TranscribeError> {
    crate::pdp::retention::apply(&plan)
}

/// The audit log, newest first. `limit = 0` returns everything.
pub fn read_audit_log(limit: u32) -> Vec<crate::pdp::audit::AuditEntry> {
    crate::pdp::audit::read(limit)
}

pub fn audit_entry_count() -> u32 {
    crate::pdp::audit::entry_count()
}

/// Indonesian label for an audit action, so the viewer does not have to
/// keep its own copy of the mapping.
pub fn audit_action_label(action: crate::pdp::audit::AuditAction) -> String {
    action.label().to_string()
}

/// `YYYY-MM-DD HH:MM:SS` in local time.
pub fn format_audit_time(at_unix_ms: u64) -> String {
    crate::pdp::audit::format_time(at_unix_ms)
}

/// Appends one entry. Called by the UI for acts only it knows about —
/// an export the user confirmed, a summary actually sent.
pub fn write_audit_entry(
    action: crate::pdp::audit::AuditAction,
    subject: String,
    destination: String,
    detail: String,
) -> Result<(), TranscribeError> {
    crate::pdp::audit::append(
        &crate::pdp::audit::AuditEntry::new(action, subject)
            .to(destination)
            .with_detail(detail),
    )
}

/// Writes the audit log to `destination` as CSV and records that it did.
pub fn export_audit_log(destination: String) -> Result<String, TranscribeError> {
    let path = crate::pdp::audit::export_csv(std::path::Path::new(&destination))?;
    Ok(path.to_string_lossy().to_string())
}

/// The consent notice for a meeting, ready to paste into a meeting chat.
pub fn consent_notice_text(template: String, title: String, date: String) -> String {
    crate::pdp::consent_notice(&template, &title, &date)
}

/// The shipped default notice, for the settings field's placeholder.
pub fn default_consent_notice() -> String {
    crate::pdp::DEFAULT_CONSENT_NOTICE.to_string()
}

/// Records that the notice was delivered for this meeting.
pub fn acknowledge_consent(title: String, note: String) {
    crate::pdp::acknowledge_consent(&title, &note);
}

// --- Settings -----------------------------------------------------

/// Every capability, where it runs, and whether it is on right now (F14).
///
/// Generated from `crate::capabilities`, which `crate::privacy`'s tests
/// check against the source — so this table cannot quietly disagree with
/// what the code does.
pub fn describe_capabilities(settings: AppSettings) -> Vec<crate::capabilities::Capability> {
    crate::capabilities::capabilities(&settings)
}

pub fn load_settings() -> AppSettings {
    let settings = crate::settings::load_settings();
    apply_engine_settings(&settings);
    settings
}

pub fn save_settings(settings: AppSettings) -> Result<(), TranscribeError> {
    apply_engine_settings(&settings);
    crate::settings::save_settings(&settings)
}

/// Pushes the settings the engine reads from process globals rather than
/// from a parameter: noise reduction (F17), the Silero VAD gate and the
/// optional neural diarizer.
///
/// They are globals because the code that reads them — `stt`, `pipeline`,
/// `completion`, `diarization` — sits under three layers that have no
/// other use for `AppSettings` and should not start taking it. Applied on
/// both load and save so a change takes effect on the next chunk rather
/// than the next launch.
fn apply_engine_settings(settings: &AppSettings) {
    crate::denoise::set_enabled(settings.noise_reduction);

    let library = PathBuf::from(expand_home(&settings.library_path));
    crate::vad::whisper_silero::set_model_path(crate::model::find_model_file(
        &library,
        crate::vad::whisper_silero::MODEL_ID,
    ));

    let models =
        crate::model::find_model_file(&library, crate::diarization::neural::SEGMENTATION_MODEL_ID)
            .zip(crate::model::find_model_file(
                &library,
                crate::diarization::neural::EMBEDDING_MODEL_ID,
            ))
            .map(
                |(segmentation, embedding)| crate::diarization::neural::DiarizationModels {
                    segmentation,
                    embedding,
                },
            );
    crate::diarization::neural::configure(settings.neural_diarization, models);
}

/// Resolves a leading `~` the way Dart's `resolveTilde` does.
///
/// `library_path` is stored tilde-form (`~/Documents/TrareonTranscribe`),
/// and `model_search_dirs` joins it verbatim — so without this the library
/// folder is simply never searched and the app concludes the VAD model is
/// missing on a machine where it is plainly there. (`model_search_dirs`
/// also checks the OS cache directory, which is where downloads land, so
/// the bug was invisible until someone pointed the library elsewhere.)
fn expand_home(path: &str) -> String {
    match path.strip_prefix("~/") {
        Some(rest) => match dirs::home_dir() {
            Some(home) => home.join(rest).to_string_lossy().into_owned(),
            None => path.to_string(),
        },
        None => path.to_string(),
    }
}

/// Which voice-activity detector the engine will use for the next pass.
///
/// `"silero"` when whisper.cpp's neural VAD model is installed,
/// `"webrtc+energy"` when it is not. Shown in Diagnostics and in the "Apa
/// Jalan di Mana" table, because it is the single biggest determinant of
/// whether a quiet recording comes back with invented captions in it.
pub fn vad_backend() -> String {
    if crate::vad::whisper_silero::is_available() {
        "silero".to_string()
    } else {
        "webrtc+energy".to_string()
    }
}

/// Whether neural diarization will run: the setting, the models and the
/// build feature all have to line up.
pub fn neural_diarization_status() -> NeuralDiarizationStatus {
    NeuralDiarizationStatus {
        compiled_in: crate::diarization::neural::compiled_in(),
        active: crate::diarization::neural::is_active(),
    }
}

/// Reportable state of the optional diarizer.
#[derive(Debug, Clone, Copy)]
pub struct NeuralDiarizationStatus {
    /// Built with the `neural-diarization` cargo feature.
    pub compiled_in: bool,
    /// Switched on, models installed, feature compiled in.
    pub active: bool,
}

/// The non-transcription model files the app can download: the Silero VAD
/// gate and the two diarization models.
pub fn list_auxiliary_assets(models_dir: String) -> Vec<ModelInfo> {
    crate::model::list_auxiliary_assets(&PathBuf::from(models_dir))
}

// --- Flight recorder -----------------------------------------------------
//
// Privacy-conscious, metadata-only event logger. See `flight_recorder.rs`
// for the full contract. All functions are fire-and-forget: they never
// block, never panic and never crash the host app.

/// Points the recorder at the app-support directory. Call once at startup
/// (right after `RustLib.init()`); creates the directory if missing.
pub fn init_flight_recorder(app_support_dir: String) -> Result<(), TranscribeError> {
    crate::flight_recorder::init(&app_support_dir)?;
    Ok(())
}

pub fn flight_log_lifecycle(session_id: String, from: String, to: String) {
    crate::flight_recorder::log_lifecycle(&session_id, &from, &to);
}

pub fn flight_log_segment_batch(
    session_id: String,
    batch_size: usize,
    total_segments: usize,
    queue_depth: usize,
) {
    crate::flight_recorder::log_segment_batch(&session_id, batch_size, total_segments, queue_depth);
}

pub fn flight_log_error(session_id: String, source: String, message: String) {
    crate::flight_recorder::log_error(&session_id, &source, &message);
}

pub fn flight_log_auto_stop(session_id: String, minutes: u64) {
    crate::flight_recorder::log_auto_stop(&session_id, minutes);
}

pub fn flight_log_system(event: String, details: Option<HashMap<String, String>>) {
    let pairs = details.map(|m| m.into_iter().collect::<Vec<(String, String)>>());
    crate::flight_recorder::log_system(&event, pairs);
}

/// Reads the current flight-recorder contents (raw JSONL) for diagnostics.
pub fn flight_read_log() -> String {
    crate::flight_recorder::read_log()
}

pub fn flight_clear_log() {
    crate::flight_recorder::clear_log();
}

pub fn flight_entry_count() -> usize {
    crate::flight_recorder::entry_count()
}

/// Packs "Ekspor Log Diagnostik": every rotated log generation plus the
/// preflight report, into `destination` as a `.zip`. Returns the path written.
///
/// Contains no transcript text and no audio — see
/// `flight_recorder::write_diagnostics_bundle` for the exhaustive contents.
pub fn flight_export_diagnostics(
    destination: String,
    doctor_report: String,
    environment: String,
) -> Result<String, TranscribeError> {
    let path = crate::flight_recorder::write_diagnostics_bundle(
        std::path::Path::new(&destination),
        &doctor_report,
        &environment,
    )
    .map_err(TranscribeError::from)?;
    Ok(path.to_string_lossy().to_string())
}

/// How many log files (active + rotated generations) the recorder currently
/// holds. Lets the diagnostics screen say what an export would contain.
pub fn flight_log_file_count() -> u32 {
    crate::flight_recorder::log_files().len() as u32
}

pub fn flight_set_enabled(enabled: bool) {
    crate::flight_recorder::set_enabled(enabled);
}

// --- Singleton instance lock -----------------------------------------------------

pub fn acquire_instance_lock() -> Result<(), TranscribeError> {
    crate::singleton::acquire_lock()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::audio::SessionMode;

    #[test]
    fn version_is_not_empty() {
        assert!(!engine_version().is_empty());
    }

    #[test]
    fn health_check_ok() {
        assert!(health_check().unwrap());
    }

    #[test]
    fn session_lifecycle_through_api() {
        let mut config = SessionConfig::for_mode(SessionMode::Offline, "tiny".into());
        config.mic_enabled = false;
        config.speaker_enabled = false;
        let id = start_session(config).unwrap();
        assert!(get_session_status(id.clone()).is_ok());
        toggle_mic(id.clone(), false).unwrap();
        assert!(!get_session_status(id.clone()).unwrap().mic_enabled);
        stop_session(id).unwrap();
    }

    #[test]
    fn list_models_includes_tiny() {
        let dir = std::env::temp_dir().to_string_lossy().to_string();
        let models = list_available_models(dir);
        assert!(models.iter().any(|m| m.id == "tiny"));
    }

    #[tokio::test]
    async fn download_unknown_model_errors() {
        let dir = std::env::temp_dir().to_string_lossy().to_string();
        let res = download_model(dir, "invalid-model-id".into()).await;
        assert!(res.is_err());
    }

    #[test]
    fn settings_roundtrip_through_api() {
        let s = load_settings();
        assert!(!s.default_model.is_empty());
    }
}
