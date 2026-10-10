//! Audio device enumeration.
//!
//! cpal on every platform, **except** Linux with a running sound server,
//! where the list comes from PulseAudio/PipeWire instead (see
//! [`crate::audio::pulse`]). Enumerating ALSA there listed plugin pcms that
//! aren't capture devices at all — `lavrate`, `samplerate`, `speexrate`,
//! `upmix`, … — with `is_default` false on every single entry, because cpal's
//! default is the pcm named `default`, which the enumeration never yields.
//! A caller picking "the default, else the first" therefore selected
//! `lavrate`, a rate converter, as the user's microphone. That is the direct
//! cause of the POLLERR flood this module's Linux branch exists to prevent.

use cpal::traits::{DeviceTrait, HostTrait};
use serde::Serialize;

use crate::error::TranscribeError;

#[derive(Debug, Clone, Serialize)]
pub struct AudioDeviceInfo {
    pub name: String,
    pub device_id: String,
    pub is_default: bool,
    pub channels: u16,
    pub sample_rates: Vec<u32>,
}

pub fn list_input_devices() -> Result<Vec<AudioDeviceInfo>, TranscribeError> {
    #[cfg(target_os = "linux")]
    if let Some(devices) = linux::list_inputs() {
        return Ok(devices);
    }
    list_input_devices_via_cpal()
}

pub fn list_output_devices() -> Result<Vec<AudioDeviceInfo>, TranscribeError> {
    #[cfg(target_os = "linux")]
    if let Some(devices) = linux::list_outputs() {
        return Ok(devices);
    }
    list_output_devices_via_cpal()
}

/// PulseAudio/PipeWire device listing. Returns `None` when there is no
/// reachable server, so the caller falls back to cpal.
#[cfg(target_os = "linux")]
mod linux {
    use super::AudioDeviceInfo;
    use crate::audio::pulse;

    pub(super) fn list_inputs() -> Option<Vec<AudioDeviceInfo>> {
        if !pulse::server_available() {
            return None;
        }
        // Monitor sources are excluded: they are the *system audio* path and
        // appear in the output listing via their sink. Offering them as
        // microphones is how "mic" ends up recording the speakers.
        let sources: Vec<_> = pulse::list_sources()
            .into_iter()
            .filter(|source| !source.is_monitor())
            .collect();
        // The default is whatever the mic capture path would actually open,
        // so what the UI marks as default and what gets recorded cannot
        // disagree. `pactl get-default-source` alone is not enough — on a
        // suspended mic PipeWire reports the sink monitor as the default.
        let default = pulse::resolve_input_source(
            None,
            pulse::default_source().as_deref(),
            &pulse::list_sources(),
        );
        Some(to_device_infos(sources, default.as_deref(), "input"))
    }

    pub(super) fn list_outputs() -> Option<Vec<AudioDeviceInfo>> {
        if !pulse::server_available() {
            return None;
        }
        let sinks = pulse::list_sinks();
        let default = pulse::default_sink();
        Some(to_device_infos(sinks, default.as_deref(), "output"))
    }

    fn to_device_infos(
        sources: Vec<pulse::PulseSource>,
        default: Option<&str>,
        id_prefix: &str,
    ) -> Vec<AudioDeviceInfo> {
        sources
            .into_iter()
            .enumerate()
            .map(|(index, source)| AudioDeviceInfo {
                is_default: Some(source.name.as_str()) == default,
                device_id: format!("{id_prefix}:{index}"),
                channels: source.channels,
                sample_rates: vec![source.sample_rate],
                name: source.name,
            })
            .collect()
    }
}

fn list_input_devices_via_cpal() -> Result<Vec<AudioDeviceInfo>, TranscribeError> {
    crate::audio::alsa_quiet::silence_once();
    let host = cpal::default_host();
    let default_name = host.default_input_device().and_then(|d| d.name().ok());

    let devices = host
        .input_devices()
        .map_err(|e| TranscribeError::AudioDevice(e.to_string()))?;

    let mut out = Vec::new();
    for device in devices {
        let name = device
            .name()
            .map_err(|e| TranscribeError::AudioDevice(e.to_string()))?;
        let is_default = default_name.as_deref() == Some(name.as_str());

        let (channels, sample_rates) = match device.supported_input_configs() {
            Ok(configs) => {
                let configs: Vec<_> = configs.collect();
                let channels = configs.first().map(|c| c.channels()).unwrap_or(1);
                let rates = configs
                    .iter()
                    .map(|c| c.min_sample_rate().0)
                    .collect::<Vec<_>>();
                (channels, rates)
            }
            Err(_) => (1, vec![]),
        };

        out.push(AudioDeviceInfo {
            name,
            device_id: format!("input:{}", out.len()),
            is_default,
            channels,
            sample_rates,
        });
    }
    Ok(out)
}

fn list_output_devices_via_cpal() -> Result<Vec<AudioDeviceInfo>, TranscribeError> {
    crate::audio::alsa_quiet::silence_once();
    let host = cpal::default_host();
    let default_name = host.default_output_device().and_then(|d| d.name().ok());

    let devices = host
        .output_devices()
        .map_err(|e| TranscribeError::AudioDevice(e.to_string()))?;

    let mut out = Vec::new();
    for device in devices {
        let name = device
            .name()
            .map_err(|e| TranscribeError::AudioDevice(e.to_string()))?;
        let is_default = default_name.as_deref() == Some(name.as_str());

        let (channels, sample_rates) = match device.supported_output_configs() {
            Ok(configs) => {
                let configs: Vec<_> = configs.collect();
                let channels = configs.first().map(|c| c.channels()).unwrap_or(1);
                let rates = configs
                    .iter()
                    .map(|c| c.min_sample_rate().0)
                    .collect::<Vec<_>>();
                (channels, rates)
            }
            Err(_) => (1, vec![]),
        };

        out.push(AudioDeviceInfo {
            name,
            device_id: format!("output:{}", out.len()),
            is_default,
            channels,
            sample_rates,
        });
    }
    Ok(out)
}

/// Best-effort lookup for a macOS/Windows loopback device by name convention
/// (BlackHole on macOS, WASAPI loopback exposed as an output device on
/// Windows). Returns an error the caller should surface as "install
/// BlackHole" / wizard guidance rather than a crash.
pub fn get_loopback_device(name_hint: &str) -> Result<AudioDeviceInfo, TranscribeError> {
    let mut devices = list_input_devices()?;
    devices.extend(list_output_devices()?);
    devices
        .into_iter()
        .find(|d| d.name.to_lowercase().contains(&name_hint.to_lowercase()))
        .ok_or_else(|| {
            TranscribeError::AudioDevice(format!("no loopback device matching '{name_hint}' found"))
        })
}

/// Sample rate below which a mic's best-offered rate is considered too low
/// for reliable transcription (narrowband telephony quality — HFP Bluetooth
/// headset profiles typically cap out at 8 kHz).
const LOW_QUALITY_SAMPLE_RATE_HZ: u32 = 16_000;

/// Non-blocking advisory for a selected microphone's expected transcription
/// quality (Sprint 13 B7). Returns `None` when the device looks fine.
///
/// Two independent signals, either one enough to warn: the device's best
/// sample rate is below [`LOW_QUALITY_SAMPLE_RATE_HZ`] (narrowband audio —
/// Whisper was trained on 16 kHz+ wideband speech), or its name carries a
/// Bluetooth indication (`bluez` on Linux's PulseAudio/PipeWire naming, or a
/// bare MAC-address-shaped name, which is how some Bluetooth stacks label
/// unpaired-profile devices). This is advisory only — callers decide how to
/// present it (a dismissible banner, never a block on starting the session).
pub fn mic_quality_advisory(name: &str, sample_rates: &[u32]) -> Option<String> {
    let best_rate = sample_rates.iter().copied().max().unwrap_or(0);
    let low_rate = best_rate > 0 && best_rate < LOW_QUALITY_SAMPLE_RATE_HZ;
    let bluetooth = is_bluetooth_device_name(name);
    if !low_rate && !bluetooth {
        return None;
    }
    Some(
        "Mic Bluetooth/kualitas rendah terdeteksi — transkrip mungkin kurang akurat \
         saat rapat berlangsung, disarankan headset wired untuk rapat penting."
            .to_string(),
    )
}

/// Whether `name` looks like a Bluetooth audio device by naming
/// convention: PulseAudio/PipeWire's `bluez_*` card/source names on Linux,
/// or a bare MAC-address-shaped name (`aa:bb:cc:dd:ee:ff`) some stacks fall
/// back to before a friendly name is resolved.
fn is_bluetooth_device_name(name: &str) -> bool {
    let lower = name.to_lowercase();
    if lower.contains("bluez") || lower.contains("bluetooth") {
        return true;
    }
    is_mac_address_shaped(&lower)
}

fn is_mac_address_shaped(name: &str) -> bool {
    let parts: Vec<&str> = name.split(':').collect();
    parts.len() == 6
        && parts
            .iter()
            .all(|p| p.len() == 2 && p.chars().all(|c| c.is_ascii_hexdigit()))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn list_input_devices_does_not_error() {
        // CI runners may have zero audio devices; this must not panic or
        // error out just because the list is empty.
        let result = list_input_devices();
        assert!(result.is_ok());
    }

    #[test]
    fn list_output_devices_does_not_error() {
        let result = list_output_devices();
        assert!(result.is_ok());
    }

    #[test]
    fn missing_loopback_device_returns_error_not_panic() {
        let result = get_loopback_device("definitely-not-a-real-device-xyz123");
        assert!(result.is_err());
    }

    /// The listing the mic picker reads must never offer an ALSA plugin pcm
    /// or a monitor source, and — when there is anything to pick at all —
    /// must mark exactly one entry as the default. "Default, else the first"
    /// landing on `lavrate` is the bug this asserts against.
    #[cfg(target_os = "linux")]
    #[test]
    fn linux_input_listing_offers_only_real_microphones() {
        let Some(devices) = linux::list_inputs() else {
            eprintln!("skipped: no PulseAudio/PipeWire server");
            return;
        };
        for device in &devices {
            assert!(
                !device.name.ends_with(".monitor"),
                "{} is a monitor source, not a microphone",
                device.name
            );
            for plugin in ["lavrate", "samplerate", "speexrate", "upmix", "vdownmix"] {
                assert_ne!(
                    device.name, plugin,
                    "ALSA plugin pcm {plugin} leaked into the microphone list"
                );
            }
            assert!(device.channels >= 1);
            assert!(device.sample_rates.iter().all(|rate| *rate >= 8_000));
        }
        if devices.is_empty() {
            eprintln!("skipped: machine has no capture source");
            return;
        }
        assert_eq!(
            devices.iter().filter(|d| d.is_default).count(),
            1,
            "exactly one default expected, so 'default else first' cannot mispick"
        );
    }

    #[test]
    fn narrowband_sample_rate_triggers_the_advisory() {
        assert!(mic_quality_advisory("USB Microphone", &[8_000]).is_some());
    }

    #[test]
    fn wideband_sample_rate_is_fine() {
        assert!(mic_quality_advisory("USB Microphone", &[16_000]).is_none());
    }

    #[test]
    fn modern_multi_rate_device_is_fine() {
        assert!(mic_quality_advisory("Built-in Microphone", &[44_100, 48_000]).is_none());
    }

    #[test]
    fn bluez_name_triggers_the_advisory_even_at_a_good_rate() {
        assert!(mic_quality_advisory("bluez_input.AA_BB_CC_DD_EE_FF", &[48_000]).is_some());
    }

    #[test]
    fn mac_address_shaped_name_triggers_the_advisory() {
        assert!(mic_quality_advisory("aa:bb:cc:dd:ee:ff", &[48_000]).is_some());
    }

    #[test]
    fn empty_sample_rates_relies_on_the_name_only() {
        assert!(mic_quality_advisory("bluez_input.headset", &[]).is_some());
        assert!(mic_quality_advisory("Built-in Microphone", &[]).is_none());
    }
}
