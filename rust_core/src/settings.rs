//! App settings persistence — JSON file under the OS config dir (never a
//! hardcoded path; resolved via `dirs`).

use std::fs;
use std::path::PathBuf;

use serde::{Deserialize, Serialize};

use crate::audio::SessionMode;
use crate::error::TranscribeError;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum Theme {
    Light,
    Dark,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppSettings {
    pub theme: Theme,
    pub default_model: String,
    pub default_mode: SessionMode,
    pub library_path: String,
    pub always_on_top: bool,
    pub auto_save_interval_secs: u32,
    pub vad_enabled: bool,
    pub echo_dedupe_enabled: bool,
    pub language: Option<String>,
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
        Ok(content) => serde_json::from_str(&content).unwrap_or_default(),
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
