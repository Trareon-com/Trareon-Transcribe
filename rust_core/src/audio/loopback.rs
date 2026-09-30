//! Platform-specific speaker loopback capture.
//!
//! | Platform | Technique |
//! |----------|-----------|
//! | macOS    | BlackHole 2ch via cpal (primary) + ffmpeg avfoundation (fallback) |
//! | Windows  | WASAPI loopback (`AUDCLNT_STREAMFLAGS_LOOPBACK`) |
//! | Linux    | PulseAudio/PipeWire `<sink>.monitor` via ffmpeg (primary) + parec (fallback) |
//!
//! On Linux the monitor source is resolved explicitly (see
//! [`resolve_monitor_source`]) rather than recording `default` — the default
//! *source* is the microphone, so recording it as "system audio" produced a
//! transcript of the user's own mic on both channels.

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

// ---------------------------------------------------------------------------
// macOS — ScreenCaptureKit (primary, zero-setup), BlackHole/ffmpeg (fallback)
// ---------------------------------------------------------------------------
#[cfg(target_os = "macos")]
pub(crate) mod macos {
    use crate::audio::capture::AudioCapture;
    use crate::error::TranscribeError;
    use std::io::Read;
    use std::process::{Command, Stdio};
    use std::sync::mpsc;

    #[flutter_rust_bridge::frb(ignore)]
    pub fn capture_loopback(
        device_hint: Option<String>,
        samples_tx: mpsc::Sender<Vec<f32>>,
    ) -> Result<AudioCapture, TranscribeError> {
        // ScreenCaptureKit: zero-setup system audio on macOS 13+
        // Skip if user explicitly requested a specific device (e.g. BlackHole)
        let wants_sck = device_hint
            .as_deref()
            .map(|h| h.is_empty() || h.eq_ignore_ascii_case("default"))
            .unwrap_or(true);

        if wants_sck {
            match try_sck_capture(&samples_tx) {
                Ok(capture) => {
                    tracing::info!("using ScreenCaptureKit for system audio");
                    return Ok(capture);
                }
                Err(e) => {
                    tracing::warn!("ScreenCaptureKit unavailable: {e}, falling back");
                }
            }
        }

        // Fallback: BlackHole 2ch via cpal (or requested device)
        let device_name = device_hint
            .filter(|s| !s.is_empty())
            .or_else(|| Some("BlackHole 2ch".to_string()));

        let cpal_result = AudioCapture::start(device_name.clone(), samples_tx.clone());
        if cpal_result.is_ok() {
            return cpal_result;
        }

        // Final fallback: ffmpeg avfoundation
        ffmpeg_fallback(samples_tx)
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
        stream
            .add_output_handler(
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
            )
            .map_or(Ok(()), |e| {
                Err(TranscribeError::AudioDevice(format!(
                    "ScreenCaptureKit: add handler failed: {e}"
                )))
            })?;

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

    /// ffmpeg avfoundation fallback for macOS versions < 13 or when
    /// ScreenCaptureKit permission is unavailable.
    fn ffmpeg_fallback(
        samples_tx: mpsc::Sender<Vec<f32>>,
    ) -> Result<AudioCapture, TranscribeError> {
        let (stop_tx, stop_rx) = mpsc::channel::<()>();
        let (ready_tx, ready_rx) = mpsc::channel::<Result<(), TranscribeError>>();

        let thread = std::thread::spawn(move || {
            let result = (|| -> Result<(), TranscribeError> {
                let mut child = Command::new("ffmpeg")
                    .args([
                        "-hide_banner",
                        "-loglevel",
                        "error",
                        "-f",
                        "avfoundation",
                        "-i",
                        ":default",
                        "-ac",
                        "1",
                        "-ar",
                        "16000",
                        "-f",
                        "f32le",
                        "-",
                    ])
                    .stdout(Stdio::piped())
                    .stderr(Stdio::null())
                    .spawn()
                    .map_err(|e| {
                        TranscribeError::AudioDevice(format!(
                            "ffmpeg not found. Install: brew install ffmpeg ({e})"
                        ))
                    })?;

                let stdout = child
                    .stdout
                    .take()
                    .ok_or_else(|| TranscribeError::AudioDevice("no stdout from ffmpeg".into()))?;

                let _ = ready_tx.send(Ok(()));
                let mut reader = std::io::BufReader::new(stdout);
                let mut buf = [0u8; 8192];

                loop {
                    if stop_rx.try_recv().is_ok() {
                        let _ = child.kill();
                        break;
                    }
                    match reader.read(&mut buf) {
                        Ok(0) => break,
                        Ok(n) if n >= 4 => {
                            let f32s: Vec<f32> = buf[..n]
                                .chunks(4)
                                .filter_map(|c| {
                                    if c.len() == 4 {
                                        Some(f32::from_le_bytes([c[0], c[1], c[2], c[3]]))
                                    } else {
                                        None
                                    }
                                })
                                .collect();
                            if !f32s.is_empty() {
                                let _ = samples_tx.send(f32s);
                            }
                        }
                        _ => {}
                    }
                }
                let _ = child.wait();
                Ok(())
            })();
            let _ = ready_tx.send(result);
        });

        match ready_rx.recv() {
            Ok(Ok(())) => Ok(AudioCapture::new(stop_tx, thread)),
            Ok(Err(e)) => Err(e),
            Err(_) => Err(TranscribeError::AudioDevice("ffmpeg thread failed".into())),
        }
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
#[flutter_rust_bridge::frb(ignore)]
pub fn parse_pactl_sources(stdout: &str) -> Vec<String> {
    stdout
        .lines()
        .filter_map(|line| line.split('\t').nth(1))
        .map(str::trim)
        .filter(|name| !name.is_empty())
        .map(str::to_string)
        .collect()
}

// ---------------------------------------------------------------------------
// Linux — ffmpeg PulseAudio monitor, fallback to parec
// ---------------------------------------------------------------------------
#[cfg(target_os = "linux")]
pub(crate) mod linux {
    use super::{parse_pactl_sources, resolve_monitor_source};
    use crate::audio::capture::AudioCapture;
    use crate::error::TranscribeError;
    use std::io::Read;
    use std::process::{Command, Stdio};
    use std::sync::mpsc;

    #[flutter_rust_bridge::frb(ignore)]
    pub fn capture_loopback(
        device_hint: Option<String>,
        samples_tx: mpsc::Sender<Vec<f32>>,
    ) -> Result<AudioCapture, TranscribeError> {
        let monitor = monitor_source(device_hint.as_deref())?;
        tracing::info!(source = %monitor, "linux loopback: recording system audio monitor");

        let (stop_tx, stop_rx) = mpsc::channel::<()>();
        let (ready_tx, ready_rx) = mpsc::channel::<Result<(), TranscribeError>>();

        let thread = std::thread::spawn(move || {
            let result = run_linux_loopback(&monitor, &samples_tx, &stop_rx, &ready_tx);
            let _ = ready_tx.send(result);
        });

        match ready_rx.recv_timeout(std::time::Duration::from_secs(8)) {
            Ok(Ok(())) => Ok(AudioCapture::new(stop_tx, thread)),
            Ok(Err(e)) => Err(e),
            Err(mpsc::RecvTimeoutError::Timeout) => Err(TranscribeError::AudioDevice(
                "Linux loopback (ffmpeg/parec) did not respond within 8 seconds.".into(),
            )),
            Err(mpsc::RecvTimeoutError::Disconnected) => Err(TranscribeError::AudioDevice(
                "Linux loopback thread failed".into(),
            )),
        }
    }

    /// Asks PulseAudio/PipeWire (via `pactl`) which monitor source carries
    /// system audio. Errors instead of guessing: falling back to `default`
    /// here is what used to make Trareon record the microphone and label it
    /// as system audio.
    fn monitor_source(hint: Option<&str>) -> Result<String, TranscribeError> {
        let sources =
            parse_pactl_sources(&pactl(&["list", "short", "sources"]).unwrap_or_default());
        let default_sink = pactl(&["get-default-sink"]);

        resolve_monitor_source(hint, default_sink.as_deref(), &sources).ok_or_else(|| {
            TranscribeError::AudioDevice(
                "Tidak menemukan monitor source PulseAudio/PipeWire untuk audio sistem. \
                 Pastikan PipeWire atau PulseAudio berjalan (`pactl info`), \
                 lalu coba lagi."
                    .into(),
            )
        })
    }

    fn pactl(args: &[&str]) -> Option<String> {
        let out = Command::new("pactl").args(args).output().ok()?;
        if !out.status.success() {
            return None;
        }
        let text = String::from_utf8_lossy(&out.stdout).trim().to_string();
        (!text.is_empty()).then_some(text)
    }

    fn run_linux_loopback(
        monitor: &str,
        samples_tx: &mpsc::Sender<Vec<f32>>,
        stop_rx: &mpsc::Receiver<()>,
        ready_tx: &mpsc::Sender<Result<(), TranscribeError>>,
    ) -> Result<(), TranscribeError> {
        // ffmpeg -f pulse -i <sink>.monitor -ac 1 -ar 16000 -f f32le -
        // fallback: parec -d <sink>.monitor --rate=16000 ...
        let mut child = Command::new("ffmpeg")
            .args([
                "-hide_banner",
                "-loglevel",
                "error",
                "-f",
                "pulse",
                "-i",
                monitor,
                "-ac",
                "1",
                "-ar",
                "16000",
                "-f",
                "f32le",
                "-",
            ])
            .stdout(Stdio::piped())
            .stderr(Stdio::null())
            .spawn();

        if child.is_err() {
            child = Command::new("parec")
                .args([
                    "-d",
                    monitor,
                    "--rate=16000",
                    "--channels=1",
                    "--format=float32le",
                ])
                .stdout(Stdio::piped())
                .stderr(Stdio::null())
                .spawn();
        }

        let mut child = child
            .map_err(|e| TranscribeError::AudioDevice(format!("need ffmpeg or parec: {e}")))?;
        let stdout = child
            .stdout
            .take()
            .ok_or_else(|| TranscribeError::AudioDevice("no stdout".into()))?;

        let _ = ready_tx.send(Ok(()));
        let mut reader = std::io::BufReader::new(stdout);
        let mut buf = [0u8; 8192];

        loop {
            if stop_rx.try_recv().is_ok() {
                let _ = child.kill();
                break;
            }
            match reader.read(&mut buf) {
                Ok(0) => break,
                Ok(n) if n >= 4 => {
                    let f32s: Vec<f32> = buf[..n]
                        .chunks(4)
                        .filter_map(|c| {
                            if c.len() == 4 {
                                Some(f32::from_le_bytes([c[0], c[1], c[2], c[3]]))
                            } else {
                                None
                            }
                        })
                        .collect();
                    if !f32s.is_empty() {
                        let _ = samples_tx.send(f32s);
                    }
                }
                _ => {}
            }
        }
        let _ = child.wait();
        Ok(())
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
            let Some(listing) = pactl(&["list", "short", "sources"]) else {
                eprintln!("skipped: pactl unavailable");
                return;
            };
            let sources = parse_pactl_sources(&listing);
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
