//! App settings persistence — JSON file under the OS config dir (never a
//! hardcoded path; resolved via `dirs`).

use std::fs;
use std::path::PathBuf;

use serde::{Deserialize, Serialize};

use crate::audio::SessionMode;
use crate::error::TranscribeError;
use crate::summary::{SummaryConfig, SummaryProvider, SummaryTemplate};

/// Appearance preference. `System` follows the OS setting; it is a UI
/// concept, but it has to be persisted here or it silently degrades to
/// "Terang" on every restart — which is what it used to do, because the Dart
/// bridge had nowhere to map it to.
///
/// `Default` is `Light` so that a settings file written by an older build
/// (where the field could be absent) still loads.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
pub enum Theme {
    #[default]
    Light,
    Dark,
    System,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppSettings {
    #[serde(default)]
    pub theme: Theme,
    pub default_model: String,
    pub default_mode: SessionMode,
    pub library_path: String,
    pub always_on_top: bool,
    pub auto_save_interval_secs: u32,
    pub vad_enabled: bool,
    pub echo_dedupe_enabled: bool,
    pub language: Option<String>,
    /// Enable GPU acceleration for whisper inference (Vulkan/CUDA/Metal,
    /// whichever backend the binary was compiled with). Defaults to false
    /// so behavior is unchanged for existing installs/settings files —
    /// this is opt-in, not auto-detected, because GPU inference can be
    /// slower than CPU on low-VRAM devices once model weights don't fit.
    #[serde(default)]
    pub gpu_enabled: bool,
    /// GPU device index to use when `gpu_enabled` is true (0 = default).
    #[serde(default)]
    pub gpu_device: i32,
    /// Stop recording automatically after this many minutes without new
    /// transcript segments. `None` = never. Previously Dart-only, which meant
    /// it silently reset to "off" on every launch.
    #[serde(default)]
    pub auto_stop_minutes: Option<u32>,
    /// Hybrid Progressive Transcription: quick (base) pass then refine (q5).
    #[serde(default = "default_true")]
    pub progressive_enabled: bool,
    /// AI summary endpoint configuration. Opt-in; see `crate::summary`.
    #[serde(default)]
    pub summary: SummarySettings,
}

fn default_true() -> bool {
    true
}

/// Persisted configuration for the opt-in AI summary feature.
///
/// `api_key` is stored in the same plaintext settings JSON as everything
/// else (OS config dir, user-private permissions). There is no OS keychain
/// dependency in this project, so this is a deliberate trade-off: it is
/// documented in `SECURITY.md`, the field is empty by default, and the
/// default provider (local Ollama) needs no key at all.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SummarySettings {
    /// Master switch. While false, no summary UI is offered and no request
    /// can be made — the app stays fully offline.
    pub enabled: bool,
    pub provider: SummaryProvider,
    pub base_url: String,
    pub api_key: String,
    pub model: String,
    pub template: SummaryTemplate,
    pub custom_prompt: String,
}

impl Default for SummarySettings {
    fn default() -> Self {
        Self {
            enabled: false,
            provider: SummaryProvider::Ollama,
            base_url: crate::summary::DEFAULT_OLLAMA_BASE_URL.to_string(),
            api_key: String::new(),
            model: String::new(),
            template: SummaryTemplate::NotulenRapat,
            custom_prompt: String::new(),
        }
    }
}

impl SummarySettings {
    /// Builds the runtime config used by `summary::generate_summary`.
    #[flutter_rust_bridge::frb(ignore)]
    pub fn to_config(&self, language: Option<&str>) -> SummaryConfig {
        SummaryConfig {
            provider: self.provider,
            base_url: self.base_url.clone(),
            api_key: self.api_key.clone(),
            model: self.model.clone(),
            template: self.template,
            custom_prompt: self.custom_prompt.clone(),
            language: language.unwrap_or("id").to_string(),
            timeout_secs: crate::summary::DEFAULT_TIMEOUT_SECS,
        }
    }
}

impl Default for AppSettings {
    fn default() -> Self {
        Self {
            theme: Theme::Light,
            default_model: "base".to_string(),
            default_mode: SessionMode::Online,
            library_path: default_library_path(),
            always_on_top: false,
            auto_save_interval_secs: 10,
            vad_enabled: true,
            echo_dedupe_enabled: true,
            language: Some("id".to_string()),
            gpu_enabled: false,
            gpu_device: 0,
            auto_stop_minutes: None,
            progressive_enabled: true,
            summary: SummarySettings::default(),
        }
    }
}

pub fn default_library_path() -> String {
    dirs::document_dir()
        .map(|d| d.join("TrareonTranscribe").to_string_lossy().to_string())
        .unwrap_or_else(|| "./TrareonTranscribe".to_string())
}

fn settings_path() -> Result<PathBuf, TranscribeError> {
    let dir = dirs::config_dir()
        .ok_or_else(|| TranscribeError::InvalidInput("no config directory available".into()))?
        .join("TrareonTranscribe");
    Ok(dir.join("settings.json"))
}

pub fn load_settings() -> AppSettings {
    load_settings_from(&settings_path().ok())
}

fn load_settings_from(path: &Option<PathBuf>) -> AppSettings {
    let Some(path) = path else {
        return AppSettings::default();
    };
    match fs::read_to_string(path) {
        Ok(content) => match serde_json::from_str::<AppSettings>(&content) {
            Ok(settings) => settings,
            Err(e) => {
                tracing::warn!(path = %path.display(), %e, "settings file corrupted; falling back to defaults");
                AppSettings::default()
            }
        },
        Err(_) => AppSettings::default(),
    }
}

pub fn save_settings(settings: &AppSettings) -> Result<(), TranscribeError> {
    let path = settings_path()?;
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).map_err(TranscribeError::from)?;
    }
    let json = serde_json::to_string_pretty(settings)
        .map_err(|e| TranscribeError::InvalidInput(e.to_string()))?;
    fs::write(&path, json).map_err(TranscribeError::from)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn default_settings_are_sane() {
        let s = AppSettings::default();
        assert_eq!(s.default_model, "base");
        assert!(s.vad_enabled);
        assert!(!s.library_path.is_empty());
    }

    #[test]
    fn load_missing_file_returns_default() {
        let path = Some(std::env::temp_dir().join("transcribe_settings_does_not_exist.json"));
        let s = load_settings_from(&path);
        assert_eq!(s.default_model, "base");
    }

    #[test]
    fn save_then_load_roundtrip() {
        let dir =
            std::env::temp_dir().join(format!("transcribe_settings_test_{}", uuid::Uuid::new_v4()));
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join("settings.json");

        let s = AppSettings {
            theme: Theme::Dark,
            default_model: "medium".to_string(),
            ..AppSettings::default()
        };

        let json = serde_json::to_string_pretty(&s).unwrap();
        std::fs::write(&path, json).unwrap();

        let loaded = load_settings_from(&Some(path));
        assert_eq!(loaded.default_model, "medium");
        assert!(matches!(loaded.theme, Theme::Dark));

        let _ = std::fs::remove_dir_all(&dir);
    }

    /// "Sistem" used to exist only in Dart: the bridge had no Rust variant to
    /// map it to, so it was written out as `Light` and came back as "Terang"
    /// after every restart.
    #[test]
    fn system_theme_survives_a_roundtrip() {
        let dir = std::env::temp_dir().join(format!(
            "transcribe_settings_theme_{}",
            uuid::Uuid::new_v4()
        ));
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join("settings.json");

        let saved = AppSettings {
            theme: Theme::System,
            ..AppSettings::default()
        };
        std::fs::write(&path, serde_json::to_string_pretty(&saved).unwrap()).unwrap();

        assert_eq!(load_settings_from(&Some(path)).theme, Theme::System);
        let _ = std::fs::remove_dir_all(&dir);
    }

    /// A settings file written before `theme` was serialised must still load
    /// every other field rather than resetting the whole file to defaults.
    #[test]
    fn a_settings_file_without_a_theme_keeps_its_other_fields() {
        let dir = std::env::temp_dir().join(format!(
            "transcribe_settings_legacy_{}",
            uuid::Uuid::new_v4()
        ));
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join("settings.json");

        let mut value =
            serde_json::to_value(AppSettings::default()).expect("settings serialise to JSON");
        value
            .as_object_mut()
            .expect("settings serialise to a JSON object")
            .remove("theme");
        std::fs::write(&path, serde_json::to_string_pretty(&value).unwrap()).unwrap();

        let loaded = load_settings_from(&Some(path.clone()));
        assert_eq!(loaded.theme, Theme::Light, "missing theme falls back");
        assert_eq!(loaded.default_model, "base", "the rest is not discarded");
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn summary_is_off_and_local_by_default() {
        let s = AppSettings::default();
        assert!(!s.summary.enabled, "networked feature must be opt-in");
        assert!(s.summary.api_key.is_empty());
        assert!(s.summary.base_url.contains("localhost"));
    }

    #[test]
    fn auto_stop_and_progressive_survive_a_roundtrip() {
        // Both used to live only in Dart memory and reset on every launch.
        let dir = std::env::temp_dir().join(format!(
            "transcribe_settings_persist_{}",
            uuid::Uuid::new_v4()
        ));
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join("settings.json");

        let saved = AppSettings {
            auto_stop_minutes: Some(10),
            progressive_enabled: false,
            summary: SummarySettings {
                enabled: true,
                model: "qwen2.5:7b".to_string(),
                template: SummaryTemplate::ActionItems,
                ..SummarySettings::default()
            },
            ..AppSettings::default()
        };
        std::fs::write(&path, serde_json::to_string_pretty(&saved).unwrap()).unwrap();

        let loaded = load_settings_from(&Some(path));
        assert_eq!(loaded.auto_stop_minutes, Some(10));
        assert!(!loaded.progressive_enabled);
        assert!(loaded.summary.enabled);
        assert_eq!(loaded.summary.model, "qwen2.5:7b");
        assert_eq!(loaded.summary.template, SummaryTemplate::ActionItems);

        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn settings_files_from_older_builds_still_load() {
        // A pre-upgrade settings.json has none of the new keys. Falling back
        // to *all* defaults here would silently reset the user's model,
        // theme and library path.
        let dir = std::env::temp_dir().join(format!(
            "transcribe_settings_legacy_{}",
            uuid::Uuid::new_v4()
        ));
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join("settings.json");
        std::fs::write(
            &path,
            r#"{"theme":"Dark","default_model":"large-v3-turbo-q5","default_mode":"Webinar",
                "library_path":"/tmp/lib","always_on_top":false,"auto_save_interval_secs":10,
                "vad_enabled":false,"echo_dedupe_enabled":true,"language":"id"}"#,
        )
        .unwrap();

        let loaded = load_settings_from(&Some(path));
        assert_eq!(loaded.default_model, "large-v3-turbo-q5");
        assert_eq!(loaded.library_path, "/tmp/lib");
        assert!(!loaded.vad_enabled);
        assert_eq!(loaded.auto_stop_minutes, None);
        assert!(loaded.progressive_enabled, "new flag defaults to on");
        assert!(!loaded.summary.enabled);

        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn to_config_carries_the_ui_language_through() {
        let settings = SummarySettings {
            model: "m".into(),
            ..SummarySettings::default()
        };
        assert_eq!(settings.to_config(Some("en")).language, "en");
        assert_eq!(settings.to_config(None).language, "id");
    }

    #[test]
    fn corrupt_settings_file_falls_back_to_default() {
        let dir = std::env::temp_dir().join(format!(
            "transcribe_settings_corrupt_{}",
            uuid::Uuid::new_v4()
        ));
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join("settings.json");
        std::fs::write(&path, "not valid json{{{").unwrap();

        let loaded = load_settings_from(&Some(path));
        assert_eq!(loaded.default_model, "base");

        let _ = std::fs::remove_dir_all(&dir);
    }
}

// ── Quill-inspired config: CLI flag > config.json > default ──

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct AppConfig {
    pub recordings_dir: Option<String>,
    pub on_stop: Option<String>,
    pub transcription_enabled: Option<bool>,
    pub doctor_check_on_start: Option<bool>,
}

impl AppConfig {
    #[flutter_rust_bridge::frb(ignore)]
    pub fn config_path() -> Result<PathBuf, TranscribeError> {
        let dir = dirs::config_dir()
            .ok_or_else(|| TranscribeError::InvalidInput("no config directory".into()))?;
        Ok(dir.join("TrareonTranscribe").join("config.json"))
    }

    #[flutter_rust_bridge::frb(ignore)]
    pub fn load() -> Option<Self> {
        let path = Self::config_path().ok()?;
        let content = fs::read_to_string(&path).ok()?;
        serde_json::from_str(&content).ok()
    }

    #[flutter_rust_bridge::frb(ignore)]
    pub fn resolve_recordings_dir(cli_override: Option<&str>) -> PathBuf {
        if let Some(dir) = cli_override {
            return PathBuf::from(dir);
        }
        if let Some(cfg) = Self::load() {
            if let Some(dir) = cfg.recordings_dir {
                return PathBuf::from(dir);
            }
        }
        PathBuf::from(default_library_path())
    }

    #[flutter_rust_bridge::frb(ignore)]
    pub fn on_stop_hook() -> Option<String> {
        Self::load()?.on_stop
    }

    #[flutter_rust_bridge::frb(ignore)]
    pub fn transcription_enabled() -> bool {
        Self::load()
            .and_then(|c| c.transcription_enabled)
            .unwrap_or(true)
    }

    #[flutter_rust_bridge::frb(ignore)]
    pub fn doctor_check_on_start() -> bool {
        Self::load()
            .and_then(|c| c.doctor_check_on_start)
            .unwrap_or(true)
    }
}

#[cfg(test)]
mod config_tests {
    use super::*;

    #[test]
    fn resolve_recordings_dir_cli_overrides_all() {
        let resolved = AppConfig::resolve_recordings_dir(Some("/from/cli"));
        assert_eq!(resolved.to_string_lossy(), "/from/cli");
    }

    #[test]
    fn resolve_recordings_dir_returns_default_when_no_cli_and_no_config() {
        let resolved = AppConfig::resolve_recordings_dir(None);
        assert!(!resolved.to_string_lossy().is_empty());
    }
}
