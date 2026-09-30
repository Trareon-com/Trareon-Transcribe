//! PulseAudio / PipeWire capture — the Linux path for **both** the
//! microphone and system audio.
//!
//! # Why the mic does not go through cpal on Linux
//!
//! cpal's Linux backend is ALSA. On a machine running PipeWire or PulseAudio
//! (i.e. essentially every desktop Linux today) that is the wrong layer:
//!
//! * `Host::input_devices()` enumerates every ALSA *pcm* the system defines,
//!   which includes plugins that are not capture devices at all — on the Kali
//!   box this was reproduced on, the first entry is `lavrate`, an
//!   ffmpeg-backed rate converter. Enumerating them also makes libjack and
//!   the OSS/dmix/dsnoop plugins print their own connection failures to
//!   stderr.
//! * `Host::default_input_device()` opens the pcm literally named `default`,
//!   which is never one of the enumerated names — so **every** device is
//!   reported with `is_default = false`, and a caller that picks "the default,
//!   else the first" silently lands on `lavrate`.
//! * Opening a raw `hw:`/plugin pcm fights PipeWire for the card. The stream
//!   builds and `play()` succeeds, then `snd_pcm_poll_descriptors_revents()`
//!   returns `POLLERR` on every single poll — a tight loop through cpal's
//!   error callback with no forward progress and no end.
//!
//! Going through the sound server instead resolves all three: the server owns
//! the card, the source list is exactly the real capture endpoints, and the
//! names round-trip to the same `pactl`/`parec` vocabulary the system-audio
//! path already uses. cpal remains the fallback for a machine with no sound
//! server at all (see `super::capture`).
//!
//! The resolution rules and output parsing here are pure functions and are
//! unit-tested on every platform; only [`capture_source`] needs a real server.

use std::io::Read;
use std::process::{Child, Command, Stdio};
use std::sync::{mpsc, Arc, Mutex};
use std::time::Duration;

use crate::audio::capture::AudioCapture;
use crate::error::TranscribeError;

/// How long *one* capture command gets to deliver its first PCM bytes.
/// Both `ffmpeg -f pulse` and `parec` start delivering within a few hundred
/// milliseconds on a healthy server (connecting resumes a suspended source),
/// so this is generous. Timing out and reporting why beats the old behaviour
/// of reporting success and then recording silence forever.
const FIRST_DATA_TIMEOUT: Duration = Duration::from_millis(2_500);

/// Overall budget for [`capture_source`], covering every command it tries.
/// Bounded so a wedged helper process can never leave the UI's "Memulai…"
/// spinner running indefinitely.
const START_TIMEOUT: Duration = Duration::from_secs(8);

/// How often the read loop wakes to check for a stop request. Also the
/// granularity of the first-data deadline.
const POLL_TICK: Duration = Duration::from_millis(100);

/// Tail of the child's stderr kept for error messages. Enough for a
/// `Connection failure`/`No such entity` line without unbounded growth.
const STDERR_TAIL_BYTES: usize = 1024;

/// One capture endpoint as the sound server reports it.
#[derive(Debug, Clone, PartialEq, Eq)]
#[flutter_rust_bridge::frb(ignore)]
pub struct PulseSource {
    /// The server's name, e.g. `alsa_input.pci-0000_00_1f.3.analog-stereo`.
    /// This is the identifier `parec -d` and `ffmpeg -f pulse -i` accept, so
    /// it is what device listings expose and what device hints carry.
    pub name: String,
    pub channels: u16,
    pub sample_rate: u32,
}

impl PulseSource {
    /// A monitor source carries what is being *played*, not what is being
    /// recorded — the system-audio path, never the microphone.
    #[flutter_rust_bridge::frb(ignore)]
    pub fn is_monitor(&self) -> bool {
        self.name.ends_with(".monitor")
    }
}

/// True when a PulseAudio/PipeWire server is reachable. Used to decide
/// between this backend and the cpal fallback.
#[flutter_rust_bridge::frb(ignore)]
pub fn server_available() -> bool {
    pactl(&["info"]).is_some()
}

/// Runs `pactl` and returns trimmed stdout, or `None` if the binary is
/// missing, the server is unreachable, or the output is empty.
#[flutter_rust_bridge::frb(ignore)]
pub fn pactl(args: &[&str]) -> Option<String> {
    let out = Command::new("pactl")
        .args(args)
        .stderr(Stdio::null())
        .output()
        .ok()?;
    if !out.status.success() {
        return None;
    }
    let text = String::from_utf8_lossy(&out.stdout).trim().to_string();
    (!text.is_empty()).then_some(text)
}

/// Parses `pactl list short sources` into source names (column 2).
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

/// Parses `pactl list short sources` into names **plus** the sample spec, so
/// a device listing can report real channel counts and rates instead of the
/// placeholder values cpal's ALSA plugin pcms produce.
///
/// Column 4 looks like `s32le 2ch 48000Hz`. A line whose spec is missing or
/// unparseable still yields a source — the name is the part that matters —
/// with conservative 1ch/16 kHz defaults.
#[flutter_rust_bridge::frb(ignore)]
pub fn parse_pactl_sources_detailed(stdout: &str) -> Vec<PulseSource> {
    stdout
        .lines()
        .filter_map(|line| {
            let mut columns = line.split('\t');
            let _index = columns.next()?;
            let name = columns.next()?.trim();
            if name.is_empty() {
                return None;
            }
            let _driver = columns.next();
            let spec = columns.next().unwrap_or("");
            let (channels, sample_rate) = parse_sample_spec(spec);
            Some(PulseSource {
                name: name.to_string(),
                channels,
                sample_rate,
            })
        })
        .collect()
}

/// `"s32le 2ch 48000Hz"` → `(2, 48000)`.
fn parse_sample_spec(spec: &str) -> (u16, u32) {
    let mut channels = 1;
    let mut sample_rate = 16_000;
    for field in spec.split_whitespace() {
        if let Some(value) = field.strip_suffix("ch") {
            if let Ok(parsed) = value.parse::<u16>() {
                channels = parsed;
            }
        } else if let Some(value) = field.strip_suffix("Hz") {
            if let Ok(parsed) = value.parse::<u32>() {
                sample_rate = parsed;
            }
        }
    }
    (channels, sample_rate)
}

/// Picks the source to record the **microphone** from.
///
/// The mirror image of [`super::loopback::resolve_monitor_source`], and it
/// matters for the same reason in reverse: a `.monitor` source must never be
/// returned as the microphone. On the machine this was debugged on
/// `pactl get-default-source` *is* a monitor (PipeWire leaves the default
/// pointing at the sink monitor when the mic is suspended), so honouring the
/// server's default uncritically would have recorded system audio and
/// labelled it `Saya`.
///
/// Resolution order:
/// 1. `hint` naming a non-monitor source that exists
/// 2. `default_source` when it exists and is not a monitor
/// 3. the first non-monitor source
/// 4. `None` — there is no microphone, so the caller must say so rather than
///    quietly record the speakers
#[flutter_rust_bridge::frb(ignore)]
pub fn resolve_input_source(
    hint: Option<&str>,
    default_source: Option<&str>,
    sources: &[PulseSource],
) -> Option<String> {
    let usable = |name: &str| {
        sources
            .iter()
            .find(|s| s.name == name && !s.is_monitor())
            .map(|s| s.name.clone())
    };

    // An unrecognised hint falls through on purpose: settings written by an
    // older build carry cpal ALSA names (`lavrate`, `default:CARD=PCH`) that
    // no longer mean anything, and those must recover to the real mic rather
    // than fail.
    if let Some(name) = hint
        .map(str::trim)
        .filter(|h| {
            !h.is_empty() && !h.eq_ignore_ascii_case("default") && !h.eq_ignore_ascii_case("auto")
        })
        .and_then(usable)
    {
        return Some(name);
    }

    if let Some(name) = default_source
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .and_then(usable)
    {
        return Some(name);
    }

    sources
        .iter()
        .find(|s| !s.is_monitor())
        .map(|s| s.name.clone())
}

/// Lists capture sources as the server reports them.
#[flutter_rust_bridge::frb(ignore)]
pub fn list_sources() -> Vec<PulseSource> {
    parse_pactl_sources_detailed(&pactl(&["list", "short", "sources"]).unwrap_or_default())
}

/// Lists playback sinks as the server reports them. Sinks are returned in the
/// same shape as sources because a sink is only ever used here to derive its
/// `<sink>.monitor` companion.
#[flutter_rust_bridge::frb(ignore)]
pub fn list_sinks() -> Vec<PulseSource> {
    parse_pactl_sources_detailed(&pactl(&["list", "short", "sinks"]).unwrap_or_default())
}

#[flutter_rust_bridge::frb(ignore)]
pub fn default_source() -> Option<String> {
    pactl(&["get-default-source"])
}

#[flutter_rust_bridge::frb(ignore)]
pub fn default_sink() -> Option<String> {
    pactl(&["get-default-sink"])
}

/// Resolves the microphone source for `hint` against the live server.
#[flutter_rust_bridge::frb(ignore)]
pub fn resolve_microphone(hint: Option<&str>) -> Result<String, TranscribeError> {
    resolve_input_source(hint, default_source().as_deref(), &list_sources()).ok_or_else(|| {
        TranscribeError::AudioDevice(
            "Tidak menemukan perangkat mikrofon pada PipeWire/PulseAudio. \
             Pastikan mikrofon terpasang dan tidak dibisukan (`pactl list short sources`), \
             lalu coba lagi."
                .into(),
        )
    })
}

/// Streams 16 kHz mono f32 PCM from a named Pulse/PipeWire source.
///
/// Returns only once PCM bytes have actually been received, so a caller that
/// gets `Ok` knows audio is flowing. `ffmpeg` is tried first and `parec` is
/// the fallback — including when ffmpeg is present but exits immediately,
/// which the previous system-audio implementation treated as success.
#[flutter_rust_bridge::frb(ignore)]
pub fn capture_source(
    source: &str,
    samples_tx: mpsc::Sender<Vec<f32>>,
) -> Result<AudioCapture, TranscribeError> {
    let (stop_tx, stop_rx) = mpsc::channel::<()>();
    let (ready_tx, ready_rx) = mpsc::channel::<Result<(), TranscribeError>>();
    let owned_source = source.to_string();

    let thread = std::thread::spawn(move || {
        let result = pump_until_stopped(&owned_source, &samples_tx, &stop_rx, &ready_tx);
        // If the pump failed before signalling readiness, this unblocks the
        // caller with the real reason; after readiness it is ignored.
        let _ = ready_tx.send(result);
    });

    // Dropping `stop_tx` on every error path is what tears the helper process
    // down: the read loop treats a disconnected stop channel as a stop
    // request, so a timeout here cannot leak an ffmpeg/parec child.
    match ready_rx.recv_timeout(START_TIMEOUT) {
        Ok(Ok(())) => Ok(AudioCapture::new(stop_tx, thread)),
        Ok(Err(e)) => Err(e),
        Err(mpsc::RecvTimeoutError::Timeout) => Err(TranscribeError::AudioDevice(format!(
            "Tidak ada data audio dari '{source}' dalam {} detik. \
             Periksa PipeWire/PulseAudio (`pactl info`) dan perangkat audio Anda.",
            START_TIMEOUT.as_secs()
        ))),
        Err(mpsc::RecvTimeoutError::Disconnected) => Err(TranscribeError::AudioDevice(format!(
            "Perekaman dari '{source}' gagal dimulai."
        ))),
    }
}

/// Tries each capture command in turn, then reads until stopped or EOF.
fn pump_until_stopped(
    source: &str,
    samples_tx: &mpsc::Sender<Vec<f32>>,
    stop_rx: &mpsc::Receiver<()>,
    ready_tx: &mpsc::Sender<Result<(), TranscribeError>>,
) -> Result<(), TranscribeError> {
    type Spawner = fn(&str) -> Result<(&'static str, Child), String>;
    let mut failures = Vec::new();
    for spawn in [spawn_ffmpeg as Spawner, spawn_parec as Spawner] {
        let (program, child) = match spawn(source) {
            Ok(child) => child,
            Err(e) => {
                failures.push(e);
                continue;
            }
        };
        match pump(child, samples_tx, stop_rx, ready_tx) {
            Ok(()) => return Ok(()),
            // No bytes ever arrived, so nothing downstream has seen this
            // source and the next command can be tried cleanly.
            Err(e) => failures.push(format!("{program}: {e}")),
        }
    }
    Err(TranscribeError::AudioDevice(format!(
        "Gagal merekam dari '{source}'. Pastikan ffmpeg atau parec terpasang. \
         Detail: {}",
        failures.join(" | ")
    )))
}

fn spawn_ffmpeg(source: &str) -> Result<(&'static str, Child), String> {
    // -nostdin: without it ffmpeg reads the parent's stdin, which in a GUI
    // build launched from a terminal swallows the user's keystrokes.
    // -flush_packets 1: deliver PCM as it is produced instead of buffering,
    // so readiness is detected promptly and live latency stays low.
    Command::new("ffmpeg")
        .args([
            "-hide_banner",
            "-nostdin",
            "-loglevel",
            "error",
            "-f",
            "pulse",
            "-i",
            source,
            "-ac",
            "1",
            "-ar",
            "16000",
            "-f",
            "f32le",
            "-flush_packets",
            "1",
            "-",
        ])
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .map(|child| ("ffmpeg", child))
        .map_err(|e| format!("ffmpeg tidak dapat dijalankan: {e}"))
}

fn spawn_parec(source: &str) -> Result<(&'static str, Child), String> {
    Command::new("parec")
        .args([
            "-d",
            source,
            "--rate=16000",
            "--channels=1",
            "--format=float32le",
        ])
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .map(|child| ("parec", child))
        .map_err(|e| format!("parec tidak dapat dijalankan: {e}"))
}

/// Reads f32 PCM from `child`'s stdout until stopped or EOF.
///
/// `Err` is returned **only** when the child produced no audio at all, which
/// is what makes trying the next command safe: nothing downstream has seen a
/// partial stream from this one.
///
/// The actual `read()` runs on its own thread and hands buffers over a
/// channel. Reading inline instead would block indefinitely on a helper that
/// connects but never produces audio — no stop request and no deadline could
/// be observed, and the child would outlive the session.
fn pump(
    mut child: Child,
    samples_tx: &mpsc::Sender<Vec<f32>>,
    stop_rx: &mpsc::Receiver<()>,
    ready_tx: &mpsc::Sender<Result<(), TranscribeError>>,
) -> Result<(), String> {
    let stderr_tail = drain_stderr(&mut child);
    let Some(stdout) = child.stdout.take() else {
        let _ = child.kill();
        let _ = child.wait();
        return Err("tidak ada stdout".into());
    };

    let (byte_tx, byte_rx) = mpsc::channel::<Vec<u8>>();
    std::thread::spawn(move || {
        let mut reader = std::io::BufReader::new(stdout);
        let mut buf = [0u8; 8192];
        loop {
            match reader.read(&mut buf) {
                Ok(0) => break,
                Ok(n) => {
                    if byte_tx.send(buf[..n].to_vec()).is_err() {
                        break;
                    }
                }
                Err(e) if e.kind() == std::io::ErrorKind::Interrupted => {}
                Err(_) => break,
            }
        }
        // Dropping `byte_tx` here is the EOF signal for the loop below.
    });

    // An odd tail is possible when a read lands mid-sample; carry it over
    // rather than discarding it, which would shift the stream by 1-3 bytes
    // and turn every subsequent sample into noise.
    let mut carry: Vec<u8> = Vec::with_capacity(4);
    let mut delivered = false;
    let started = std::time::Instant::now();
    let mut eof = false;

    while !stop_requested(stop_rx) {
        match byte_rx.recv_timeout(POLL_TICK) {
            Ok(bytes) => {
                carry.extend_from_slice(&bytes);
                let usable = carry.len() - carry.len() % 4;
                let samples: Vec<f32> = carry[..usable]
                    .chunks_exact(4)
                    .map(|c| f32::from_le_bytes([c[0], c[1], c[2], c[3]]))
                    .collect();
                carry.drain(..usable);
                if samples.is_empty() {
                    continue;
                }
                if !delivered {
                    delivered = true;
                    let _ = ready_tx.send(Ok(()));
                }
                if samples_tx.send(samples).is_err() {
                    break; // Receiver gone: the session is shutting down.
                }
            }
            Err(mpsc::RecvTimeoutError::Timeout) => {
                if !delivered && started.elapsed() >= FIRST_DATA_TIMEOUT {
                    break;
                }
            }
            Err(mpsc::RecvTimeoutError::Disconnected) => {
                eof = true;
                break;
            }
        }
    }

    let _ = child.kill();
    let status = child.wait().ok();
    if delivered {
        return Ok(());
    }
    let detail = stderr_tail
        .lock()
        .ok()
        .map(|tail| tail.trim().to_string())
        .filter(|tail| !tail.is_empty())
        .unwrap_or_else(|| match (eof, status) {
            (true, Some(status)) => format!("keluar tanpa data (status {status})"),
            (true, None) => "keluar tanpa data".into(),
            _ => format!("tidak ada data dalam {} ms", FIRST_DATA_TIMEOUT.as_millis()),
        });
    Err(detail)
}

/// A stop request, *or* a dropped stop channel — the latter means the caller
/// gave up (e.g. its start timeout fired) and the helper must not outlive it.
fn stop_requested(stop_rx: &mpsc::Receiver<()>) -> bool {
    !matches!(stop_rx.try_recv(), Err(mpsc::TryRecvError::Empty))
}

/// Reads the child's stderr on its own thread into a bounded tail buffer.
///
/// Both piping stderr and *not* reading it is a deadlock waiting to happen —
/// a chatty ffmpeg fills the 64 KB pipe and blocks — and the previous
/// implementation's `Stdio::null()` threw away the one thing that explains a
/// failed capture.
fn drain_stderr(child: &mut Child) -> Arc<Mutex<String>> {
    let tail = Arc::new(Mutex::new(String::new()));
    let Some(mut stderr) = child.stderr.take() else {
        return tail;
    };
    let sink = Arc::clone(&tail);
    std::thread::spawn(move || {
        let mut buf = [0u8; 512];
        while let Ok(n) = stderr.read(&mut buf) {
            if n == 0 {
                break;
            }
            let Ok(mut text) = sink.lock() else { break };
            text.push_str(&String::from_utf8_lossy(&buf[..n]));
            if text.len() > STDERR_TAIL_BYTES {
                let cut = text.len() - STDERR_TAIL_BYTES;
                // Never split a UTF-8 code point.
                let cut = (cut..text.len())
                    .find(|i| text.is_char_boundary(*i))
                    .unwrap_or(text.len());
                text.drain(..cut);
            }
        }
    });
    tail
}

#[cfg(test)]
mod tests {
    use super::*;

    fn src(name: &str) -> PulseSource {
        PulseSource {
            name: name.to_string(),
            channels: 2,
            sample_rate: 48_000,
        }
    }

    /// The exact listing from the machine the POLLERR bug was reproduced on.
    const REAL_LISTING: &str = "52\talsa_output.pci-0000_00_1f.3.analog-stereo.monitor\tPipeWire\ts32le 2ch 48000Hz\tIDLE\n\
                                53\talsa_input.pci-0000_00_1f.3.analog-stereo\tPipeWire\ts32le 2ch 48000Hz\tSUSPENDED\n";

    #[test]
    fn parses_names_and_sample_spec() {
        let sources = parse_pactl_sources_detailed(REAL_LISTING);
        assert_eq!(
            sources,
            vec![
                PulseSource {
                    name: "alsa_output.pci-0000_00_1f.3.analog-stereo.monitor".into(),
                    channels: 2,
                    sample_rate: 48_000,
                },
                PulseSource {
                    name: "alsa_input.pci-0000_00_1f.3.analog-stereo".into(),
                    channels: 2,
                    sample_rate: 48_000,
                },
            ]
        );
        assert!(sources[0].is_monitor());
        assert!(!sources[1].is_monitor());
    }

    #[test]
    fn parses_empty_and_malformed_listings() {
        assert!(parse_pactl_sources_detailed("").is_empty());
        assert!(parse_pactl_sources_detailed("no tabs here\n").is_empty());
        // Missing sample spec: still a usable source, with safe defaults.
        let sources = parse_pactl_sources_detailed("7\tsome.source\n");
        assert_eq!(sources.len(), 1);
        assert_eq!(sources[0].channels, 1);
        assert_eq!(sources[0].sample_rate, 16_000);
    }

    #[test]
    fn short_and_detailed_parsers_agree_on_names() {
        let names = parse_pactl_sources(REAL_LISTING);
        let detailed: Vec<String> = parse_pactl_sources_detailed(REAL_LISTING)
            .into_iter()
            .map(|s| s.name)
            .collect();
        assert_eq!(names, detailed);
    }

    #[test]
    fn never_returns_a_monitor_as_the_microphone() {
        // The reproduction machine's real state: PipeWire reports the *sink
        // monitor* as the default source. Honouring that would record system
        // audio and label it as the user's own voice.
        let sources = parse_pactl_sources_detailed(REAL_LISTING);
        let default = Some("alsa_output.pci-0000_00_1f.3.analog-stereo.monitor");
        for hint in [None, Some("default"), Some("auto"), Some(""), default] {
            let picked = resolve_input_source(hint, default, &sources).unwrap();
            assert_eq!(
                picked, "alsa_input.pci-0000_00_1f.3.analog-stereo",
                "hint {hint:?} resolved to {picked}"
            );
        }
    }

    #[test]
    fn honours_the_default_source_when_it_is_a_real_input() {
        let sources = vec![src("alsa_input.internal"), src("alsa_input.usb-headset")];
        assert_eq!(
            resolve_input_source(None, Some("alsa_input.usb-headset"), &sources).as_deref(),
            Some("alsa_input.usb-headset")
        );
    }

    #[test]
    fn an_explicit_hint_wins_over_the_default() {
        let sources = vec![src("alsa_input.internal"), src("alsa_input.usb-headset")];
        assert_eq!(
            resolve_input_source(
                Some("alsa_input.usb-headset"),
                Some("alsa_input.internal"),
                &sources
            )
            .as_deref(),
            Some("alsa_input.usb-headset")
        );
    }

    #[test]
    fn stale_cpal_alsa_hints_recover_to_a_real_microphone() {
        // Settings written by the previous build store cpal's ALSA pcm names.
        // `lavrate` is an ffmpeg rate-converter plugin, not a capture device;
        // picking it is what produced the POLLERR flood. None of these exist
        // as Pulse sources, so all must fall through to the real mic.
        let sources = parse_pactl_sources_detailed(REAL_LISTING);
        for stale in [
            "lavrate",
            "samplerate",
            "default:CARD=PCH",
            "dsnoop:CARD=PCH,DEV=0",
        ] {
            assert_eq!(
                resolve_input_source(Some(stale), None, &sources).as_deref(),
                Some("alsa_input.pci-0000_00_1f.3.analog-stereo"),
                "stale hint {stale} did not recover"
            );
        }
    }

    #[test]
    fn no_input_source_yields_none_rather_than_a_monitor() {
        let only_monitor = vec![src("alsa_output.analog-stereo.monitor")];
        assert_eq!(resolve_input_source(None, None, &only_monitor), None);
        assert_eq!(
            resolve_input_source(
                Some("alsa_output.analog-stereo.monitor"),
                Some("alsa_output.analog-stereo.monitor"),
                &only_monitor
            ),
            None
        );
        assert_eq!(resolve_input_source(None, None, &[]), None);
    }

    #[test]
    fn sample_spec_parsing_is_tolerant() {
        assert_eq!(parse_sample_spec("s32le 2ch 48000Hz"), (2, 48_000));
        assert_eq!(parse_sample_spec("float32le 1ch 16000Hz"), (1, 16_000));
        assert_eq!(parse_sample_spec(""), (1, 16_000));
        assert_eq!(parse_sample_spec("garbage"), (1, 16_000));
        assert_eq!(parse_sample_spec("s16le 6ch"), (6, 16_000));
    }

    /// End-to-end against the real sound server, when there is one: the
    /// microphone this backend would open must be a non-monitor source that
    /// the server actually lists. Skips (rather than fails) on CI containers
    /// and headless builders — the rules above are covered unconditionally.
    #[test]
    fn resolves_a_real_microphone_when_a_sound_server_is_running() {
        if !server_available() {
            eprintln!("skipped: no PulseAudio/PipeWire server");
            return;
        }
        let sources = list_sources();
        if !sources.iter().any(|s| !s.is_monitor()) {
            eprintln!("skipped: no capture source on this machine");
            return;
        }
        let resolved = resolve_microphone(None).expect("a microphone exists");
        assert!(
            !resolved.ends_with(".monitor"),
            "mic capture would have opened {resolved}, which is a monitor source"
        );
        assert!(
            sources.iter().any(|s| s.name == resolved),
            "{resolved} is not among the sources the server reports"
        );
    }
}
