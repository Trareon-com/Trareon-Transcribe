//! Audio capture: device enumeration, ring buffering, and session types.
//! Live dual-stream (mic+speaker) thread wiring is hardware-dependent and
//! is exercised via manual smoke tests (see project test plan) rather than
//! CI unit tests; the pieces here (device list, ring buffer, config/mode
//! types) are pure logic and fully unit-tested.

pub mod capture;
pub mod device;
pub mod loopback;
pub mod ring_buffer;

use serde::{Deserialize, Serialize};

pub use capture::AudioCapture;
pub use device::{get_loopback_device, list_input_devices, AudioDeviceInfo};
pub use ring_buffer::RingBuffer;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum SessionMode {
    Webinar, // mic=off, speaker=on
    Online,  // mic=on, speaker=on, echo-dedupe=on
    Offline, // mic=on, speaker=off
}

impl SessionMode {
    pub fn default_toggles(&self) -> (bool, bool) {
        match self {
            SessionMode::Webinar => (false, true),
            SessionMode::Online => (true, true),
            SessionMode::Offline => (true, false),
        }
    }

    pub fn echo_dedupe_enabled(&self) -> bool {
        matches!(self, SessionMode::Online)
    }
}

/// User-chosen strategy for Hybrid Progressive Transcription (HPT).
///
/// * `Auto`      — benchmark q5; direct single-pass on fast devices,
///   dual-pass base→q5 on slow ones (default).
/// * `ForceDual` — always base quick → q5 refine (best for low-CPU devices
///   where the user wants instant partial text).
/// * `ForceDirect` — skip the base pass, run q5 alone from the start
///   (best for fast devices; lower total latency).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Default)]
pub enum HptMode {
    #[default]
    Auto = 0,
    ForceDual = 1,
    ForceDirect = 2,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SessionConfig {
    pub mic_enabled: bool,
    pub speaker_enabled: bool,
    pub mode: SessionMode,
    pub mic_device_id: Option<String>,
    pub speaker_device_id: Option<String>,
    pub model_path: String,
    /// Optional second model for Hybrid Progressive Transcription (HPT).
    /// When `Some`, each source runs quick (base) → refine (q5) so text
    /// renders in 3-5s and is then replaced in place by the accurate pass.
    /// `None` = classic single-model live transcription.
    #[serde(default)]
    pub refine_model_path: Option<String>,
    /// Overrides adaptive HPT routing. `Auto` benchmarks live; the other
    /// variants force a specific path regardless of device capability.
    #[serde(default)]
    pub hpt_mode: HptMode,
    pub vad_enabled: bool,
    pub sample_rate: u32,
    pub chunk_duration_secs: u32,
    /// Enable GPU acceleration for whisper inference (Vulkan/CUDA/Metal).
    /// Mirrors `AppSettings::gpu_enabled`; the caller is responsible for
    /// copying the user's setting in when building this config.
    #[serde(default)]
    pub gpu_enabled: bool,
    /// GPU device index to use when `gpu_enabled` is true (0 = default).
    #[serde(default)]
    pub gpu_device: i32,
}

impl SessionConfig {
    pub fn for_mode(mode: SessionMode, model_path: String) -> Self {
        let (mic_enabled, speaker_enabled) = mode.default_toggles();
        Self {
            mic_enabled,
            speaker_enabled,
            mode,
            mic_device_id: None,
            speaker_device_id: None,
            model_path,
            refine_model_path: None,
            hpt_mode: HptMode::Auto,
            vad_enabled: true,
            sample_rate: 16_000,
            chunk_duration_secs: 30,
            gpu_enabled: false,
            gpu_device: 0,
        }
    }

    /// True when HPT is configured (refine model present and distinct from
    /// the quick model).
    pub fn hpt_enabled(&self) -> bool {
        self.refine_model_path
            .as_deref()
            .is_some_and(|p| !p.is_empty() && p != self.model_path)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn webinar_mode_defaults() {
        assert_eq!(SessionMode::Webinar.default_toggles(), (false, true));
        assert!(!SessionMode::Webinar.echo_dedupe_enabled());
    }

    #[test]
    fn online_mode_enables_dedupe() {
        assert_eq!(SessionMode::Online.default_toggles(), (true, true));
        assert!(SessionMode::Online.echo_dedupe_enabled());
    }

    #[test]
    fn offline_mode_mic_only() {
        assert_eq!(SessionMode::Offline.default_toggles(), (true, false));
        assert!(!SessionMode::Offline.echo_dedupe_enabled());
    }

    #[test]
    fn session_config_from_mode() {
        let cfg = SessionConfig::for_mode(SessionMode::Online, "models/tiny.gguf".into());
        assert!(cfg.mic_enabled && cfg.speaker_enabled);
        assert_eq!(cfg.sample_rate, 16_000);
    }
}
