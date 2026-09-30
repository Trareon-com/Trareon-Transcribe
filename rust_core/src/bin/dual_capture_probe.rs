//! Hardware smoke test for live dual capture: records from the microphone
//! *and* the system-audio monitor at the same time and reports how much
//! audio each actually delivered.
//!
//! This is the check that catches what unit tests cannot — that the resolved
//! devices are real, that both streams deliver 16 kHz mono f32 PCM, and that
//! a broken stream fails loudly instead of flooding stderr.
//!
//! ```text
//! cargo run --release --bin dual_capture_probe            # 5 s, default devices
//! cargo run --release --bin dual_capture_probe -- 10      # 10 s
//! TRAREON_CAPTURE_BACKEND=cpal cargo run --release --bin dual_capture_probe
//! ```
//!
//! For the monitor RMS to be non-zero something has to be playing; e.g.
//! `ffmpeg -v error -i some.mp3 -f wav - | paplay &` alongside it.

use std::sync::mpsc;
use std::thread::sleep;
use std::time::{Duration, Instant};

use rust_core::audio::capture::AudioCapture;
use rust_core::audio::loopback::start_loopback;
use rust_core::decode::TARGET_SAMPLE_RATE;

fn main() {
    let seconds: u64 = std::env::args()
        .nth(1)
        .and_then(|arg| arg.parse().ok())
        .unwrap_or(5);
    // Optional explicit mic device, to reproduce a specific failure. Passing
    // an ALSA plugin pcm together with TRAREON_CAPTURE_BACKEND=cpal is how the
    // original POLLERR flood is reproduced on demand:
    //   TRAREON_CAPTURE_BACKEND=cpal … dual_capture_probe 5 lavrate
    let mic_device = std::env::args().nth(2);

    // Route tracing to stderr so a stream-error flood, if the rate limiter
    // ever regresses, shows up here instead of only inside the GUI.
    tracing_subscriber::fmt()
        .with_max_level(tracing::Level::INFO)
        .with_writer(std::io::stderr)
        .init();

    println!(
        "backend override: {:?}",
        std::env::var(rust_core::audio::capture::BACKEND_ENV).ok()
    );
    println!("mic device arg:   {mic_device:?}");
    print_environment();

    let (mic_tx, mic_rx) = mpsc::channel::<Vec<f32>>();
    let mic = match AudioCapture::start("mic", mic_device, mic_tx) {
        Ok(capture) => {
            println!("mic:     capture started");
            Some(capture)
        }
        Err(e) => {
            println!("mic:     FAILED to start — {e}");
            None
        }
    };

    let (spk_tx, spk_rx) = mpsc::channel::<Vec<f32>>();
    let speaker = match start_loopback(None, spk_tx) {
        Ok(capture) => {
            println!("speaker: capture started");
            Some(capture)
        }
        Err(e) => {
            println!("speaker: FAILED to start — {e}");
            None
        }
    };

    println!("\nrecording for {seconds}s ...");
    let started = Instant::now();
    let mut mic_stats = Stats::default();
    let mut speaker_stats = Stats::default();
    while started.elapsed() < Duration::from_secs(seconds) {
        mic_stats.drain(&mic_rx);
        speaker_stats.drain(&spk_rx);
        sleep(Duration::from_millis(50));
    }
    // Anything still queued when the clock ran out.
    mic_stats.drain(&mic_rx);
    speaker_stats.drain(&spk_rx);

    drop(mic);
    drop(speaker);

    println!();
    mic_stats.report("mic", seconds);
    speaker_stats.report("speaker", seconds);

    let mut failures = Vec::new();
    if mic_stats.samples == 0 {
        failures.push("mic delivered no audio");
    }
    if speaker_stats.samples == 0 {
        failures.push("speaker/monitor delivered no audio");
    }
    println!();
    if failures.is_empty() {
        println!("RESULT: OK — both sources delivered audio");
    } else {
        println!("RESULT: FAIL — {}", failures.join("; "));
        std::process::exit(1);
    }
}

fn print_environment() {
    use rust_core::audio::pulse;
    if !pulse::server_available() {
        println!("sound server: none reachable (cpal/ALSA fallback)");
        return;
    }
    println!("sound server: PulseAudio/PipeWire reachable");
    println!("  default source: {:?}", pulse::default_source());
    println!("  default sink:   {:?}", pulse::default_sink());
    println!("  resolved mic:   {:?}", pulse::resolve_microphone(None));
    for source in pulse::list_sources() {
        println!(
            "  source: {:44} {}ch {}Hz{}",
            source.name,
            source.channels,
            source.sample_rate,
            if source.is_monitor() {
                "  [monitor]"
            } else {
                ""
            }
        );
    }
}

#[derive(Default)]
struct Stats {
    chunks: usize,
    samples: usize,
    sum_squares: f64,
    peak: f32,
}

impl Stats {
    fn drain(&mut self, rx: &mpsc::Receiver<Vec<f32>>) {
        for chunk in rx.try_iter() {
            self.chunks += 1;
            self.samples += chunk.len();
            for sample in chunk {
                self.sum_squares += (sample as f64) * (sample as f64);
                self.peak = self.peak.max(sample.abs());
            }
        }
    }

    fn rms(&self) -> f64 {
        if self.samples == 0 {
            return 0.0;
        }
        (self.sum_squares / self.samples as f64).sqrt()
    }

    fn report(&self, label: &str, seconds: u64) {
        let expected = TARGET_SAMPLE_RATE as usize * seconds as usize;
        println!(
            "{label:8} chunks={:<5} samples={:<8} ({:.0}% of {expected} expected @{}Hz)  rms={:.6}  peak={:.6}",
            self.chunks,
            self.samples,
            if expected == 0 {
                0.0
            } else {
                100.0 * self.samples as f64 / expected as f64
            },
            TARGET_SAMPLE_RATE,
            self.rms(),
            self.peak
        );
    }
}
