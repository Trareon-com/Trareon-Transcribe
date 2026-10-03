//! Platform-specific speaker loopback capture.
//!
//! | Platform | Technique |
//! |----------|-----------|
//! | macOS    | ScreenCaptureKit (zero-setup) or the user's chosen loopback device via cpal |
//! | Windows  | WASAPI loopback (`AUDCLNT_STREAMFLAGS_LOOPBACK`) |
//! | Linux    | PulseAudio/PipeWire `<sink>.monitor` via [`crate::audio::pulse`] (ffmpeg, then parec) |
//!
//! No platform here ever falls back to the default *input* device. On Linux
//! the monitor source is resolved explicitly (see [`resolve_monitor_source`])
//! rather than recording `default`, and on macOS a failed capture returns an
//! actionable error instead of `ffmpeg -f avfoundation -i :default` — because
//! the default source is the microphone, and recording it as "system audio"
//! produced a transcript of the user's own mic on both channels.

use crate::audio::capture::AudioCapture;
use crate::error::TranscribeError;
use std::sync::mpsc;

#[flutter_rust_bridge::frb(ignore)]
pub fn start_loopback(
    device_hint: Option<String>,
    samples_tx: mpsc::Sender<Vec<f32>>,
) -> Result<AudioCapture, TranscribeError> {
    #[cfg(target_os = "macos")]
    {
        macos::capture_loopback(device_hint, samples_tx)
    }
    #[cfg(target_os = "windows")]
    {
        windows::capture_loopback(device_hint, samples_tx)
    }
    #[cfg(target_os = "linux")]
    {
        linux::capture_loopback(device_hint, samples_tx)
    }
    #[cfg(not(any(target_os = "macos", target_os = "windows", target_os = "linux")))]
    {
        let _ = (device_hint, samples_tx);
        Err(TranscribeError::AudioDevice(
            "loopback not supported".into(),
        ))
    }
}

/// Turns `SCStream::add_output_handler`'s return value into a `Result`.
///
/// The registration returns `Option<usize>`: `Some(handler_id)` on success,
/// `None` on failure. The call site used to write that as
/// `.map_or(Ok(()), |e| Err(..))`, which is the mapping *inverted* — every
/// successful registration became an `Err` (so ScreenCaptureKit "failed" on
/// every healthy machine and macOS fell through to the mic-recording
/// fallback), and a genuine `None` became `Ok` (starting a handler-less
/// stream that captured silence).
///
/// Deliberately lives outside the `#[cfg(target_os = "macos")]` module and is
/// generic over the handler id: the inversion is a logic bug, not a platform
/// one, so [`sck_handler_registration_is_ok_only_on_some`] compiles and runs
/// on Linux and Windows CI too. Nothing about this can regress unnoticed
/// again just because the gate has no Mac.
// Only the macOS module calls it; off a Mac it exists purely so the tests can.
#[cfg_attr(not(target_os = "macos"), allow(dead_code))]
pub(crate) fn sck_handler_registration<T>(handler_id: Option<T>) -> Result<(), TranscribeError> {
    handler_id.map(|_| ()).ok_or_else(|| {
        TranscribeError::AudioDevice(
            "ScreenCaptureKit: failed to register audio output handler".into(),
        )
    })
}

/// Whether macOS should try ScreenCaptureKit's zero-setup system-audio
/// capture instead of opening a named device.
///
/// True exactly when the user has not picked a concrete output device — an
/// absent, empty or `"default"` hint. Pure and cfg-independent so the policy
/// is tested everywhere, not only on a Mac.
#[cfg_attr(not(target_os = "macos"), allow(dead_code))]
pub(crate) fn wants_zero_setup_capture(device_hint: Option<&str>) -> bool {
    device_hint
        .map(|hint| hint.trim().is_empty() || hint.eq_ignore_ascii_case("default"))
        .unwrap_or(true)
}

// ---------------------------------------------------------------------------
// macOS — ScreenCaptureKit (primary, zero-setup), chosen device via cpal
// ---------------------------------------------------------------------------
#[cfg(target_os = "macos")]
pub(crate) mod macos {
    use super::{sck_handler_registration, wants_zero_setup_capture};
    use crate::audio::capture::AudioCapture;
    use crate::error::TranscribeError;
    use std::sync::mpsc;

    #[flutter_rust_bridge::frb(ignore)]
    pub fn capture_loopback(
        device_hint: Option<String>,
        samples_tx: mpsc::Sender<Vec<f32>>,
    ) -> Result<AudioCapture, TranscribeError> {
        // ScreenCaptureKit: zero-setup system audio on macOS 13+.
        // Skipped only when the user explicitly picked a device (e.g. BlackHole).
        if wants_zero_setup_capture(device_hint.as_deref()) {
            return match try_sck_capture(&samples_tx) {
                Ok(capture) => {
                    tracing::info!("using ScreenCaptureKit for system audio");
                    Ok(capture)
                }
                // No fallthrough. The only fallbacks available here are
                // BlackHole-by-name (usually not installed, since the user
                // picked nothing) and `ffmpeg -f avfoundation -i :default`,
                // which is the MICROPHONE — avfoundation has no system-audio
                // device. Recording the mic and labelling it "Audio sistem",
                // possibly with the mic toggle off, is the worst outcome for a
                // privacy-first app, so surface the actionable error (almost
                // always: grant Screen & System Audio Recording permission).
                // Same rule as Linux, where `pulse::monitor_source` errors
                // rather than recording `default`.
                Err(e) => {
                    tracing::warn!(%e, "ScreenCaptureKit unavailable; not falling back to mic");
                    Err(e)
                }
            };
        }

        // Explicitly requested device (BlackHole 2ch and friends) via cpal.
        let device_name = device_hint.filter(|s| !s.trim().is_empty());
        AudioCapture::start("spk", device_name.clone(), samples_tx).map_err(|e| {
            // Again no `ffmpeg -i :default` fallback: it would quietly swap
            // the device the user chose for their microphone.
            let requested = device_name.unwrap_or_else(|| "BlackHole 2ch".to_string());
            TranscribeError::AudioDevice(format!(
                "Tidak bisa membuka \"{requested}\" untuk audio sistem ({e}). Pilih perangkat \
                 loopback lain di Pengaturan, atau kosongkan pilihan perangkat agar Trareon \
                 memakai ScreenCaptureKit (butuh izin Screen & System Audio Recording)."
            ))
        })
    }

    /// ScreenCaptureKit-based system audio capture — no driver install needed.
    /// Requires macOS 13.0+ and one-time "Screen & System Audio Recording" permission.
    fn try_sck_capture(
        samples_tx: &mpsc::Sender<Vec<f32>>,
    ) -> Result<AudioCapture, TranscribeError> {
        use screencapturekit::cm::CMSampleBuffer;
        use screencapturekit::prelude::*;

        let content = SCShareableContent::get().map_err(|e| {
            TranscribeError::AudioDevice(format!(
                "ScreenCaptureKit: cannot list content — grant Screen & System Audio Recording permission in System Settings ({e})"
            ))
        })?;
        let displays = content.displays();
        let display = displays.first().ok_or_else(|| {
            TranscribeError::AudioDevice("ScreenCaptureKit: no display found".into())
        })?;

        let filter = SCContentFilter::create()
            .with_display(display)
            .with_excluding_windows(&[])
            .build();

        // Minimal video config (2×2) — we only need audio.
        // The purple recording indicator only appears for video captures,
        // not audio-only SCStream (per Apple documentation).
        let config = SCStreamConfiguration::new()
            .with_width(2)
            .with_height(2)
            .with_captures_audio(true)
            .with_sample_rate(16_000)
            .with_channel_count(1)
            .with_excludes_current_process_audio(true);

        let mut stream = SCStream::new(&filter, &config);
        let tx = samples_tx.clone();

        // Closure-based audio handler — fires on ScreenCaptureKit's internal queue
        let handler = stream.add_output_handler(
            move |sample: CMSampleBuffer, of_type: SCStreamOutputType| {
                if of_type != SCStreamOutputType::Audio {
                    return;
                }
                if let Some(list) = sample.audio_buffer_list() {
                    for buf in list.iter() {
                        let ptr = buf.data().as_ptr() as *const f32;
                        let len = buf.data_byte_size() / 4;
                        if !ptr.is_null() && len > 0 {
                            let samples = unsafe { std::slice::from_raw_parts(ptr, len) };
                            let _ = tx.send(samples.to_vec());
                        }
                    }
                }
            },
            SCStreamOutputType::Audio,
        );
        // `Some(handler_id)` means the handler is registered; see
        // `sck_handler_registration` for the inversion this replaces.
        sck_handler_registration(handler)?;

        stream.start_capture().map_err(|e| {
            TranscribeError::AudioDevice(format!("ScreenCaptureKit: start failed: {e}"))
        })?;

        let (stop_tx, stop_rx) = mpsc::channel::<()>();
        let thread = std::thread::spawn(move || {
            let _ = stop_rx.recv();
            let _ = stream.stop_capture();
        });

        Ok(AudioCapture::new(stop_tx, thread))
    }
}

// ---------------------------------------------------------------------------
// Windows — WASAPI loopback
// ---------------------------------------------------------------------------
#[cfg(target_os = "windows")]
pub(crate) mod windows {
    use crate::audio::capture::AudioCapture;
    use crate::decode::resample_to_target;
    use crate::error::TranscribeError;
    use std::sync::mpsc;
    // The `windows` crate (not `windows-sys`) is used here specifically because
    // it generates ergonomic method-call bindings for COM interfaces
    // (`client.Start()`, etc). `windows-sys` only gives raw `*mut c_void`
    // pointers with no vtable dispatch and no per-interface IID constants, so
    // none of the interface method calls below would compile against it.
    use windows::Win32::Media::Audio::{
        eConsole, eRender, IAudioCaptureClient, IAudioClient, IMMDeviceEnumerator,
        MMDeviceEnumerator, AUDCLNT_SHAREMODE_SHARED, AUDCLNT_STREAMFLAGS_LOOPBACK,
    };
    use windows::Win32::System::Com::{
        CoCreateInstance, CoInitializeEx, CoTaskMemFree, CLSCTX_ALL, COINIT_APARTMENTTHREADED,
    };

    #[flutter_rust_bridge::frb(ignore)]
    pub fn capture_loopback(
        _device_hint: Option<String>,
        samples_tx: mpsc::Sender<Vec<f32>>,
    ) -> Result<AudioCapture, TranscribeError> {
        let (stop_tx, stop_rx) = mpsc::channel::<()>();
        let (ready_tx, ready_rx) = mpsc::channel::<Result<(), TranscribeError>>();

        let thread = std::thread::spawn(move || {
            let result = unsafe { run_wasapi_loopback(&samples_tx, &stop_rx, &ready_tx) };
            let _ = ready_tx.send(result);
        });

        match ready_rx.recv_timeout(std::time::Duration::from_secs(8)) {
            Ok(Ok(())) => Ok(AudioCapture::new(stop_tx, thread)),
            Ok(Err(e)) => Err(e),
            Err(mpsc::RecvTimeoutError::Timeout) => Err(TranscribeError::AudioDevice(
                "WASAPI loopback did not respond within 8 seconds (IAudioClient::Initialize \
                 hang, a known issue with some audio drivers). Try restarting the Windows \
                 Audio service or updating your audio driver."
                    .into(),
            )),
            Err(mpsc::RecvTimeoutError::Disconnected) => {
                Err(TranscribeError::AudioDevice("WASAPI thread failed".into()))
            }
        }
    }

    unsafe fn run_wasapi_loopback(
        samples_tx: &mpsc::Sender<Vec<f32>>,
        stop_rx: &mpsc::Receiver<()>,
        ready_tx: &mpsc::Sender<Result<(), TranscribeError>>,
    ) -> Result<(), TranscribeError> {
        let _ = CoInitializeEx(None, COINIT_APARTMENTTHREADED);

        let enumerator: IMMDeviceEnumerator =
            CoCreateInstance(&MMDeviceEnumerator, None, CLSCTX_ALL)
                .map_err(|e| TranscribeError::AudioDevice(format!("CoCreateInstance: {e}")))?;

        let device = enumerator
            .GetDefaultAudioEndpoint(eRender, eConsole)
            .map_err(|e| TranscribeError::AudioDevice(format!("GetDefaultAudioEndpoint: {e}")))?;

        let client: IAudioClient = device
            .Activate(CLSCTX_ALL, None)
            .map_err(|e| TranscribeError::AudioDevice(format!("Activate: {e}")))?;

        let fmt = client
            .GetMixFormat()
            .map_err(|e| TranscribeError::AudioDevice(format!("GetMixFormat: {e}")))?;
        let sr = (*fmt).nSamplesPerSec;
        let ch = (*fmt).nChannels as usize;

        client
            .Initialize(
                AUDCLNT_SHAREMODE_SHARED,
                AUDCLNT_STREAMFLAGS_LOOPBACK,
                0,
                0,
                fmt,
                None,
            )
            .map_err(|e| TranscribeError::AudioDevice(format!("Initialize: {e}")))?;
        CoTaskMemFree(Some(fmt.cast()));

        let cc: IAudioCaptureClient = client
            .GetService()
            .map_err(|e| TranscribeError::AudioDevice(format!("GetService: {e}")))?;

        client
            .Start()
            .map_err(|e| TranscribeError::AudioDevice(format!("Start: {e}")))?;
        let _ = ready_tx.send(Ok(()));

        let batch = (sr / 10) as u32;
        let mut accum: Vec<f32> = Vec::with_capacity(batch as usize * 2);

        loop {
            if stop_rx.try_recv().is_ok() {
                break;
            }
            let sz = cc.GetNextPacketSize().unwrap_or(0);
            if sz == 0 {
                std::thread::sleep(std::time::Duration::from_millis(5));
                continue;
            }
            let mut ptr: *mut u8 = std::ptr::null_mut();
            let mut frames: u32 = 0;
            let mut flags: u32 = 0;
            if cc
                .GetBuffer(&mut ptr, &mut frames, &mut flags, None, None)
                .is_err()
                || ptr.is_null()
                || frames == 0
            {
                let _ = cc.ReleaseBuffer(frames);
                continue;
            }

            let float_data = std::slice::from_raw_parts(ptr as *const f32, frames as usize * ch);
            let mono: Vec<f32> = float_data
                .chunks(ch)
                .map(|f| f.iter().sum::<f32>() / ch as f32)
                .collect();
            accum.extend(mono);
            let _ = cc.ReleaseBuffer(frames);

            if accum.len() >= batch as usize {
                if let Ok(r) = resample_to_target(&accum, sr) {
                    let _ = samples_tx.send(r);
                }
                accum.clear();
            }
        }
        let _ = client.Stop();
        Ok(())
    }
}

// ---------------------------------------------------------------------------
// Linux — PulseAudio/PipeWire *monitor* source resolution
// ---------------------------------------------------------------------------
//
// Kept out of the `#[cfg(target_os = "linux")]` module on purpose: the
// resolution rules are pure string logic and are worth unit-testing on every
// CI runner, not only the Linux one.

/// Picks the PulseAudio/PipeWire source to record **system audio** from.
///
/// This is the fix for the long-standing Linux bug where loopback recorded
/// the microphone: `-i default` (ffmpeg) and a bare `parec` both open the
/// default *source*, which is the mic. System audio lives on the default
/// *sink*'s monitor, conventionally named `<sink>.monitor`.
///
/// Resolution order:
/// 1. `hint` that already names a `.monitor` source present in `sources`
/// 2. `hint` naming a sink whose `<hint>.monitor` is present in `sources`
/// 3. `<default_sink>.monitor` when present in `sources`
/// 4. the first `.monitor` source in `sources`
/// 5. `None` — no monitor source exists, so the caller must not silently
///    fall through to the microphone
#[flutter_rust_bridge::frb(ignore)]
pub fn resolve_monitor_source(
    hint: Option<&str>,
    default_sink: Option<&str>,
    sources: &[String],
) -> Option<String> {
    let has = |name: &str| sources.iter().any(|s| s == name);

    if let Some(hint) = hint.map(str::trim).filter(|h| {
        !h.is_empty() && !h.eq_ignore_ascii_case("default") && !h.eq_ignore_ascii_case("auto")
    }) {
        if hint.ends_with(".monitor") && has(hint) {
            return Some(hint.to_string());
        }
        let as_monitor = format!("{hint}.monitor");
        if has(&as_monitor) {
            return Some(as_monitor);
        }
    }

    if let Some(sink) = default_sink.map(str::trim).filter(|s| !s.is_empty()) {
        let as_monitor = format!("{sink}.monitor");
        if has(&as_monitor) {
            return Some(as_monitor);
        }
    }

    sources.iter().find(|s| s.ends_with(".monitor")).cloned()
}

/// Parses `pactl list short sources` output into source names (column 2).
///
/// Re-exported from [`crate::audio::pulse`], which owns the `pactl` and
/// helper-process plumbing now shared by the microphone and system-audio
/// paths. Kept visible here because the monitor-resolution rules below are
/// its only caller outside that module.
pub use crate::audio::pulse::parse_pactl_sources;

// ---------------------------------------------------------------------------
// Linux — PulseAudio/PipeWire monitor source via the shared pulse backend
// ---------------------------------------------------------------------------
#[cfg(target_os = "linux")]
pub(crate) mod linux {
    use super::resolve_monitor_source;
    use crate::audio::capture::AudioCapture;
    use crate::audio::pulse;
    use crate::error::TranscribeError;
    use std::sync::mpsc;

    #[flutter_rust_bridge::frb(ignore)]
    pub fn capture_loopback(
        device_hint: Option<String>,
        samples_tx: mpsc::Sender<Vec<f32>>,
    ) -> Result<AudioCapture, TranscribeError> {
        let monitor = monitor_source(device_hint.as_deref())?;
        tracing::info!(source = %monitor, "linux loopback: recording system audio monitor");
        pulse::capture_source(&monitor, samples_tx)
    }

    /// Asks PulseAudio/PipeWire (via `pactl`) which monitor source carries
    /// system audio. Errors instead of guessing: falling back to `default`
    /// here is what used to make Trareon record the microphone and label it
    /// as system audio.
    fn monitor_source(hint: Option<&str>) -> Result<String, TranscribeError> {
        let sources: Vec<String> = pulse::list_sources()
            .into_iter()
            .map(|source| source.name)
            .collect();
        let default_sink = pulse::default_sink();

        resolve_monitor_source(hint, default_sink.as_deref(), &sources).ok_or_else(|| {
            TranscribeError::AudioDevice(
                "Tidak menemukan monitor source PulseAudio/PipeWire untuk audio sistem. \
                 Pastikan PipeWire atau PulseAudio berjalan (`pactl info`), \
                 lalu coba lagi."
                    .into(),
            )
        })
    }

    #[cfg(test)]
    mod tests {
        use super::*;

        /// End-to-end against the real sound server: what `capture_loopback`
        /// would actually record must be a monitor source, never the mic.
        ///
        /// Skips when there is no usable PulseAudio/PipeWire (CI containers,
        /// headless builders) rather than failing — the pure resolution rules
        /// are covered unconditionally by `monitor_resolution_tests`.
        #[test]
        fn resolves_a_real_monitor_source_when_a_sound_server_is_running() {
            if !pulse::server_available() {
                eprintln!("skipped: no PulseAudio/PipeWire server");
                return;
            }
            let sources: Vec<String> = pulse::list_sources()
                .into_iter()
                .map(|source| source.name)
                .collect();
            if !sources.iter().any(|s| s.ends_with(".monitor")) {
                eprintln!("skipped: no monitor source on this machine");
                return;
            }

            let resolved = monitor_source(None).expect("a monitor source exists");
            assert!(
                resolved.ends_with(".monitor"),
                "loopback would have recorded {resolved}, which is not a monitor source"
            );
            assert!(
                sources.contains(&resolved),
                "{resolved} is not among the sources the server reports"
            );
        }

        /// The mic and system-audio resolvers must never agree on a source —
        /// that is exactly the A-1 bug (mic recorded on both channels, then
        /// half the transcript silently dropped by echo-dedupe) in a new
        /// guise, now that both go through the same backend.
        #[test]
        fn microphone_and_monitor_resolve_to_different_sources() {
            if !pulse::server_available() {
                eprintln!("skipped: no PulseAudio/PipeWire server");
                return;
            }
            let (Ok(monitor), Ok(mic)) = (monitor_source(None), pulse::resolve_microphone(None))
            else {
                eprintln!("skipped: machine has no mic or no monitor source");
                return;
            };
            assert_ne!(mic, monitor);
        }
    }
}

/// macOS capture policy, tested on every platform.
///
/// The ScreenCaptureKit path itself cannot be compiled off a Mac, so the two
/// decisions that actually broke system-audio capture live in pure helpers
/// that CI (Linux) does exercise.
#[cfg(test)]
mod macos_policy_tests {
    use super::{sck_handler_registration, wants_zero_setup_capture};

    /// The regression that made ScreenCaptureKit unusable: `Some(handler_id)`
    /// is success. Before this, a healthy registration was reported as an
    /// error and macOS fell through to recording the microphone.
    #[test]
    fn sck_handler_registration_is_ok_only_on_some() {
        assert!(sck_handler_registration(Some(7usize)).is_ok());
        // A handler id of 0 is still a handler id, not a failure.
        assert!(sck_handler_registration(Some(0usize)).is_ok());

        let err = sck_handler_registration(None::<usize>).expect_err("None must be an error");
        assert!(
            err.to_string().contains("output handler"),
            "error should name what failed to register, got: {err}"
        );
    }

    #[test]
    fn zero_setup_capture_is_used_when_no_device_was_chosen() {
        assert!(wants_zero_setup_capture(None));
        assert!(wants_zero_setup_capture(Some("")));
        // Settings round-trips can leave whitespace behind; it is still
        // "the user picked nothing", not a device named " ".
        assert!(wants_zero_setup_capture(Some("   ")));
        assert!(wants_zero_setup_capture(Some("default")));
        assert!(wants_zero_setup_capture(Some("Default")));
    }

    #[test]
    fn a_chosen_device_skips_zero_setup_capture() {
        assert!(!wants_zero_setup_capture(Some("BlackHole 2ch")));
        assert!(!wants_zero_setup_capture(Some("Loopback Audio")));
        // Not a prefix/substring match: a device merely containing "default"
        // is a real device the user picked.
        assert!(!wants_zero_setup_capture(Some("MacBook Pro Speakers")));
        assert!(!wants_zero_setup_capture(Some("default-ish Mixer")));
    }
}

#[cfg(test)]
mod monitor_resolution_tests {
    use super::{parse_pactl_sources, resolve_monitor_source};

    fn sources() -> Vec<String> {
        vec![
            "alsa_input.pci-0000_00_1f.3.analog-stereo".to_string(),
            "alsa_output.pci-0000_00_1f.3.analog-stereo.monitor".to_string(),
            "alsa_output.usb-Generic_USB_Audio.analog-stereo.monitor".to_string(),
        ]
    }

    #[test]
    fn prefers_default_sink_monitor_over_first_monitor() {
        let picked = resolve_monitor_source(
            None,
            Some("alsa_output.usb-Generic_USB_Audio.analog-stereo"),
            &sources(),
        );
        assert_eq!(
            picked.as_deref(),
            Some("alsa_output.usb-Generic_USB_Audio.analog-stereo.monitor")
        );
    }

    #[test]
    fn never_picks_a_plain_input_source() {
        // The whole point of this resolver: an input (microphone) source must
        // never be returned as the system-audio source.
        for hint in [None, Some("default"), Some("auto"), Some("")] {
            let picked = resolve_monitor_source(hint, None, &sources()).unwrap();
            assert!(
                picked.ends_with(".monitor"),
                "hint {hint:?} resolved to non-monitor source {picked}"
            );
        }
    }

    #[test]
    fn hint_naming_a_sink_is_expanded_to_its_monitor() {
        let picked = resolve_monitor_source(
            Some("alsa_output.pci-0000_00_1f.3.analog-stereo"),
            Some("alsa_output.usb-Generic_USB_Audio.analog-stereo"),
            &sources(),
        );
        assert_eq!(
            picked.as_deref(),
            Some("alsa_output.pci-0000_00_1f.3.analog-stereo.monitor")
        );
    }

    #[test]
    fn hint_already_naming_a_monitor_is_used_verbatim() {
        let picked = resolve_monitor_source(
            Some("alsa_output.usb-Generic_USB_Audio.analog-stereo.monitor"),
            None,
            &sources(),
        );
        assert_eq!(
            picked.as_deref(),
            Some("alsa_output.usb-Generic_USB_Audio.analog-stereo.monitor")
        );
    }

    #[test]
    fn unknown_hint_falls_back_instead_of_failing() {
        let picked = resolve_monitor_source(
            Some("bluez_output.AA_BB_CC"),
            Some("alsa_output.pci-0000_00_1f.3.analog-stereo"),
            &sources(),
        );
        assert_eq!(
            picked.as_deref(),
            Some("alsa_output.pci-0000_00_1f.3.analog-stereo.monitor")
        );
    }

    #[test]
    fn no_monitor_source_yields_none_rather_than_the_microphone() {
        let only_mic = vec!["alsa_input.pci-0000_00_1f.3.analog-stereo".to_string()];
        assert_eq!(
            resolve_monitor_source(None, Some("some-sink"), &only_mic),
            None
        );
        assert_eq!(resolve_monitor_source(None, None, &[]), None);
    }

    #[test]
    fn parses_pactl_short_source_listing() {
        let stdout = "0\talsa_output.pci-0000_00_1f.3.analog-stereo.monitor\tPipeWire\ts16le 2ch 48000Hz\tSUSPENDED\n\
                      1\talsa_input.pci-0000_00_1f.3.analog-stereo\tPipeWire\ts16le 2ch 48000Hz\tSUSPENDED\n";
        assert_eq!(
            parse_pactl_sources(stdout),
            vec![
                "alsa_output.pci-0000_00_1f.3.analog-stereo.monitor".to_string(),
                "alsa_input.pci-0000_00_1f.3.analog-stereo".to_string(),
            ]
        );
    }

    #[test]
    fn parses_empty_and_malformed_pactl_output() {
        assert!(parse_pactl_sources("").is_empty());
        assert!(parse_pactl_sources("no tabs here\n").is_empty());
    }
}
