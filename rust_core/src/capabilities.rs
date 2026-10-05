//! "Apa jalan di mana" — every capability, where it runs, is it on (F14).
//!
//! # Why this is code and not a page of prose
//!
//! The app's central claim is that transcription is local and that the
//! only things that leave the machine are two opt-in features the user
//! configured. A README saying so is worth nothing: it cannot be wrong
//! out loud. This module is the claim as data, and
//! `crate::privacy`'s tests check it against the source — a capability
//! declared local whose module contains a network primitive fails the
//! build, and a capability declared networked whose module is not one of
//! the two allowed HTTP modules fails too.
//!
//! So the table the user reads in Settings and the gate that fails CI are
//! the same list. Adding a feature that sends something somewhere means
//! editing this file, and editing this file is what the review notices.

use serde::Serialize;

use crate::settings::AppSettings;

/// Where a capability's work happens.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
pub enum RunsAt {
    /// Entirely on this machine. Nothing is sent anywhere.
    Local,
    /// The user-configured summary endpoint, and nothing else.
    SummaryEndpoint,
    /// A fixed third party, named in [`Capability::where_label`].
    Internet,
}

/// One row of the table.
#[derive(Debug, Clone, Serialize)]
pub struct Capability {
    /// Stable key, for tests and for the UI's list keys.
    pub id: String,
    /// Indonesian name, as the feature is called in the UI.
    pub name: String,
    /// One sentence on what it does, in Indonesian.
    pub detail: String,
    pub runs_at: RunsAt,
    /// Rendered destination: "Lokal", the configured endpoint, or a host.
    pub where_label: String,
    /// Whether it would do anything right now, given the settings.
    pub enabled: bool,
    /// Why it is off, when it is. Empty when enabled.
    pub disabled_reason: String,
    /// The Rust module that implements it, relative to `rust_core/src`.
    ///
    /// This is the field that makes the table checkable rather than
    /// decorative: `privacy.rs` scans exactly these files.
    pub module: String,
}

/// `Lokal` for everything that never opens a socket.
const LOCAL: &str = "Lokal (di komputer ini)";

/// Every capability, in the order the UI shows them: capture first,
/// because that is what the app is for, then the networked few, then the
/// housekeeping.
pub fn capabilities(settings: &AppSettings) -> Vec<Capability> {
    let endpoint = settings.summary.base_url.trim();
    let endpoint_label = if endpoint.is_empty() {
        "Endpoint ringkasan (belum diatur)".to_string()
    } else {
        format!("Endpoint ringkasan: {endpoint}")
    };
    let summary_usable = settings.summary.enabled
        && !endpoint.is_empty()
        && !settings.summary.model.trim().is_empty();
    let summary_off_reason = if !settings.summary.enabled {
        "Ringkasan AI dimatikan di Pengaturan."
    } else if endpoint.is_empty() || settings.summary.model.trim().is_empty() {
        "Endpoint atau model ringkasan belum diisi."
    } else {
        ""
    };

    let local =
        |id: &str, name: &str, detail: &str, module: &str, enabled: bool, why: &str| Capability {
            id: id.to_string(),
            name: name.to_string(),
            detail: detail.to_string(),
            runs_at: RunsAt::Local,
            where_label: LOCAL.to_string(),
            enabled,
            disabled_reason: why.to_string(),
            module: module.to_string(),
        };

    vec![
        local(
            "capture",
            "Perekaman mikrofon & audio sistem",
            "Mengambil suara dari mikrofon dan dari audio yang keluar dari \
             komputer, lalu menyimpannya sebagai WAV di perpustakaan Anda.",
            "audio/capture.rs",
            true,
            "",
        ),
        local(
            "transcribe",
            "Transkripsi (Whisper)",
            "Mengubah suara menjadi teks dengan model Whisper yang sudah \
             ada di komputer ini. Tidak ada audio yang dikirim ke mana pun.",
            "stt/mod.rs",
            true,
            "",
        ),
        local(
            "vad",
            "Deteksi suara (VAD)",
            "Melewati bagian yang sunyi agar model tidak mengarang kalimat \
             untuk keheningan.",
            "vad/mod.rs",
            settings.vad_enabled,
            if settings.vad_enabled {
                ""
            } else {
                "Dimatikan di Pengaturan."
            },
        ),
        local(
            "vad_silero",
            "Gerbang suara neural (Silero)",
            "Model Silero bawaan whisper.cpp memutuskan bagian mana yang \
             berisi suara manusia. Jauh lebih teliti daripada detektor \
             energi, dan inilah pertahanan utama terhadap kalimat karangan \
             di bagian sunyi.",
            "vad/whisper_silero.rs",
            settings.vad_enabled && crate::vad::whisper_silero::is_available(),
            if !settings.vad_enabled {
                "VAD dimatikan di Pengaturan."
            } else {
                "Model Silero belum diunduh — memakai detektor WebRTC + energi."
            },
        ),
        local(
            "denoise",
            "Pengurangan derau (RNNoise)",
            "Menekan kipas, AC, dan derau ruangan sebelum transkripsi.",
            "denoise.rs",
            settings.noise_reduction,
            if settings.noise_reduction {
                ""
            } else {
                "Dimatikan di Pengaturan → Audio."
            },
        ),
        local(
            "diarization",
            "Pemisahan pembicara",
            "Menebak siapa berbicara dari ciri akustik, lalu memberi label \
             Saya / Peserta N.",
            "diarization/mod.rs",
            true,
            "",
        ),
        local(
            "diarization_neural",
            "Pemisahan pembicara akurat (sherpa-onnx)",
            "Segmentasi pyannote + sidik suara CAM++, semuanya ONNX di CPU \
             komputer ini. Dipakai pada impor berkas, transkrip ulang, dan \
             penyelesaian setelah Stop.",
            "diarization/neural.rs",
            crate::diarization::neural::is_active(),
            if !crate::diarization::neural::compiled_in() {
                "Tidak tersedia di build ini."
            } else if !settings.neural_diarization {
                "Dimatikan di Pengaturan → Audio."
            } else {
                "Model pemisahan pembicara belum diunduh."
            },
        ),
        local(
            "glossary",
            "Kamus istilah",
            "Memberi daftar istilah Anda ke model agar nama dan singkatan \
             tidak salah tulis.",
            "glossary.rs",
            settings.glossary.enabled,
            if settings.glossary.enabled {
                ""
            } else {
                "Dimatikan di Pengaturan → Kamus istilah."
            },
        ),
        local(
            "completion",
            "Penyelesaian transkrip setelah Berhenti",
            "Menyalin ulang bagian rekaman yang belum tertranskripsi saat \
             rapat berjalan, agar tidak ada detik yang hilang.",
            "completion.rs",
            true,
            "",
        ),
        local(
            "export",
            "Ekspor (Markdown, TXT, SRT, VTT, HTML, DOCX, CSV, PDF, JSON)",
            "Menulis berkas hasil ke folder sesi di komputer ini.",
            "export/mod.rs",
            true,
            "",
        ),
        local(
            "archive_index",
            "Indeks & pencarian arsip rapat",
            "Indeks SQLite FTS5 atas seluruh rapat Anda, untuk mencari \
             kalimat di rapat mana pun. Pencarian tidak memakai jaringan.",
            "archive.rs",
            true,
            "",
        ),
        local(
            "pdp",
            "Mode Kepatuhan UU PDP",
            "Penyamaran NIK/telepon/e-mail saat ekspor, batas retensi, dan \
             log audit — semuanya di komputer ini.",
            "pdp/mod.rs",
            settings.pdp.enabled,
            if settings.pdp.enabled {
                ""
            } else {
                "Dimatikan di Pengaturan → Kepatuhan PDP."
            },
        ),
        Capability {
            id: "summary".to_string(),
            name: "Ringkasan AI".to_string(),
            detail: "Mengirim teks transkrip (bukan audio) ke endpoint yang \
                     Anda atur sendiri, dan menerima ringkasan."
                .to_string(),
            runs_at: RunsAt::SummaryEndpoint,
            where_label: endpoint_label.clone(),
            enabled: summary_usable,
            disabled_reason: summary_off_reason.to_string(),
            module: "summary.rs".to_string(),
        },
        Capability {
            id: "archive_ask".to_string(),
            name: "Tanya arsip rapat (jawaban otomatis)".to_string(),
            detail: "Mengirim kutipan yang ditemukan di arsip lokal ke \
                     endpoint ringkasan yang sama, untuk disusun menjadi \
                     jawaban. Pencarian sendiri tetap lokal."
                .to_string(),
            runs_at: RunsAt::SummaryEndpoint,
            where_label: endpoint_label,
            enabled: summary_usable,
            disabled_reason: summary_off_reason.to_string(),
            module: "summary.rs".to_string(),
        },
        Capability {
            id: "model_download".to_string(),
            name: "Unduh model (Whisper, Silero VAD, pemisahan pembicara)".to_string(),
            detail: "Hanya saat Anda menekan tombol unduh. Setiap berkas \
                     diverifikasi dengan SHA256 yang sudah dipatok di dalam \
                     aplikasi, bukan yang dikirim server."
                .to_string(),
            runs_at: RunsAt::Internet,
            where_label: "huggingface.co, github.com".to_string(),
            enabled: true,
            disabled_reason: String::new(),
            module: "model.rs".to_string(),
        },
    ]
}

/// The two modules allowed to open a socket. Mirrors the allow-list in
/// `privacy.rs`'s `only_model_download_and_summary_may_use_http`.
pub const NETWORKED_MODULES: &[&str] = &["model.rs", "summary.rs"];

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ids_are_unique() {
        let settings = AppSettings::default();
        let mut ids: Vec<String> = capabilities(&settings).into_iter().map(|c| c.id).collect();
        let count = ids.len();
        ids.sort();
        ids.dedup();
        assert_eq!(ids.len(), count, "duplicate capability id");
    }

    #[test]
    fn a_fresh_install_sends_nothing_without_being_asked() {
        let settings = AppSettings::default();
        for capability in capabilities(&settings) {
            if capability.runs_at == RunsAt::Local {
                continue;
            }
            // The model download is "enabled" in the sense that the
            // button works; it still only runs on a press. Everything
            // else that leaves the machine must be off out of the box.
            if capability.id == "model_download" {
                continue;
            }
            assert!(
                !capability.enabled,
                "{} would send data on a fresh install",
                capability.id
            );
            assert!(
                !capability.disabled_reason.is_empty(),
                "{} is off and does not say why",
                capability.id
            );
        }
    }

    #[test]
    fn every_row_names_a_module_that_exists() {
        let base = std::path::PathBuf::from(
            std::env::var("CARGO_MANIFEST_DIR").unwrap_or_else(|_| ".".into()),
        )
        .join("src");
        for capability in capabilities(&AppSettings::default()) {
            let path = base.join(&capability.module);
            assert!(
                path.exists(),
                "{} points at {} which does not exist",
                capability.id,
                capability.module
            );
        }
    }

    #[test]
    fn turning_the_summary_on_properly_enables_both_endpoint_features() {
        let mut settings = AppSettings::default();
        settings.summary.enabled = true;
        settings.summary.model = "qwen2.5:0.5b".into();
        let rows = capabilities(&settings);
        for id in ["summary", "archive_ask"] {
            let row = rows.iter().find(|c| c.id == id).unwrap();
            assert!(row.enabled, "{id} should be usable now");
            assert!(row.disabled_reason.is_empty());
            assert!(
                row.where_label.contains(&settings.summary.base_url),
                "{id} must name the endpoint it would reach: {}",
                row.where_label
            );
        }
    }

    #[test]
    fn an_endpoint_without_a_model_is_reported_as_not_ready() {
        let mut settings = AppSettings::default();
        settings.summary.enabled = true;
        settings.summary.model = String::new();
        let rows = capabilities(&settings);
        let summary = rows.iter().find(|c| c.id == "summary").unwrap();
        assert!(!summary.enabled);
        assert!(summary.disabled_reason.contains("model"));
    }

    #[test]
    fn the_local_only_settings_are_reflected_rather_than_assumed() {
        let settings = AppSettings {
            noise_reduction: true,
            vad_enabled: false,
            neural_diarization: false,
            ..AppSettings::default()
        };
        let rows = capabilities(&settings);
        assert!(rows.iter().find(|c| c.id == "denoise").unwrap().enabled);
        assert!(!rows.iter().find(|c| c.id == "vad").unwrap().enabled);
    }
}
