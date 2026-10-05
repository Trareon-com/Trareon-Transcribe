//! Live-path measurement: commit latency and live coverage, old policy vs
//! LocalAgreement-2.
//!
//! ```text
//! live_bench --audio /path/rapat_id.mp3 \
//!            --model ~/Library/Caches/TrareonTranscribe/models/ggml-base.bin \
//!            --policy both
//! ```
//!
//! # What it measures
//!
//! The file is fed to the live pipeline in 100 ms buffers, exactly as the
//! capture thread does, and the wall clock is read every time a segment
//! comes out. Two numbers come from that:
//!
//! * **Commit latency** — for each committed word, how long after the
//!   audio containing it had arrived the user could read it. This is what
//!   "latency from speech to committed text" means: it is measured against
//!   the word's own end time, not against the start of the decode, so a
//!   decoder that falls behind is penalised.
//! * **Live coverage** — committed audio seconds as a fraction of the
//!   seconds the VAD says hold speech. "% of speech committed live".
//!
//! # Why it paces in real time
//!
//! Buffers are delivered no earlier than the wall-clock moment they would
//! have arrived in a real session (`started + audio_offset`), and latency
//! is measured against that same clock. Feeding as fast as the pipeline
//! accepts and calling the *audio* offset the arrival time — the first
//! version of this harness — reports zero latency for any policy whose
//! segments end exactly where its chunk ends, which is every fixed-chunk
//! policy. It made the old 5-second chunking look instantaneous on a
//! machine where it was in fact 70 seconds behind by the end of the clip.
//!
//! Nothing here touches the network and nothing opens an audio device.

use std::path::{Path, PathBuf};
use std::time::Instant;

use clap::Parser;
use rust_core::decode::{decode_audio_file, TARGET_SAMPLE_RATE};
use rust_core::glossary::GlossaryConfig;
use rust_core::pipeline::LivePipeline;
use rust_core::streaming::StreamPolicy;
use rust_core::stt::{DecodeOptions, WhisperEngine};
use rust_core::vad::{detect_speech_regions, SegmentationConfig};

/// Buffer the capture thread delivers at a time.
const BUFFER_SECS: f64 = 0.1;

/// The chunk length the pre-Sprint-4b live path used.
const LEGACY_CHUNK_SECS: f64 = 5.0;
/// Its overlap.
const LEGACY_OVERLAP_SECS: f64 = 1.0;

#[derive(Parser, Debug)]
#[command(
    name = "live_bench",
    about = "Ukur latensi commit dan cakupan live: kebijakan lama vs LocalAgreement-2"
)]
struct Args {
    /// Audio file to replay through the live path.
    #[arg(long)]
    audio: String,

    /// Model for the live preview.
    #[arg(long)]
    model: String,

    /// `la2`, `fixed`, `legacy`, or `all`.
    ///
    /// `la2` and `fixed` are the two [`StreamPolicy`] configurations the
    /// app ships; `legacy` is the pre-Sprint-4b code path, reimplemented
    /// here so the comparison is against what the app actually used to do.
    #[arg(long, default_value = "all")]
    policy: String,

    /// Force a language. Auto-detect on a short window is a coin toss and
    /// the noise lands in the measurement.
    #[arg(long, default_value = "id")]
    language: String,

    /// Silero VAD model for the live gate, as the app configures it.
    ///
    /// Without this the gate is simply absent and every window reaches the
    /// decoder — which is a configuration the app only runs before the
    /// model has been downloaded. Pass it to measure what a finished
    /// install actually does.
    #[arg(long)]
    vad_model: Option<PathBuf>,
}

/// One policy's result.
#[derive(Debug, Default)]
struct Measurement {
    segments: usize,
    words: usize,
    /// Audio seconds the committed segments account for.
    covered_secs: f64,
    /// Per-segment latency samples, in seconds.
    latencies: Vec<f64>,
    /// Wall-clock seconds the whole replay took.
    ///
    /// A *floor*, not a cost: the feeder paces in real time, so a policy
    /// that keeps up finishes at the length of the clip however little
    /// work it did. Read [`Self::decode_secs`] for the cost.
    wall_secs: f64,
    /// Every committed line, timestamped.
    ///
    /// Printed so the silence claim can be checked rather than believed: on
    /// a mostly-silent recording the counts alone cannot tell five real
    /// lines from five invented ones.
    lines: Vec<String>,
    /// Seconds actually spent inside the decoder.
    ///
    /// This is the number that separates the policies. LocalAgreement-2
    /// decodes every second of audio at least twice by construction, and
    /// on a device without the headroom for that it is the whole story.
    decode_secs: f64,
}

impl Measurement {
    fn median_latency(&self) -> f64 {
        percentile(&self.latencies, 0.5)
    }

    fn p90_latency(&self) -> f64 {
        percentile(&self.latencies, 0.9)
    }

    fn coverage(&self, speech_secs: f64) -> f64 {
        if speech_secs <= 0.0 {
            return 0.0;
        }
        (self.covered_secs / speech_secs).clamp(0.0, 1.0)
    }

    /// Seconds of audio the decoder got through per second of CPU. Above
    /// 1.0 the policy keeps up with a live meeting; below it, it does not.
    fn rtf(&self, audio_secs: f64) -> f64 {
        if self.decode_secs <= 0.0 {
            return f64::INFINITY;
        }
        audio_secs / self.decode_secs
    }
}

fn percentile(values: &[f64], fraction: f64) -> f64 {
    if values.is_empty() {
        return f64::NAN;
    }
    let mut sorted = values.to_vec();
    sorted.sort_by(f64::total_cmp);
    let index = ((sorted.len() - 1) as f64 * fraction).round() as usize;
    sorted[index]
}

fn main() {
    let args = Args::parse();
    // Same global the app sets from `AppSettings` on load and save. Set
    // before any pipeline is built: `LivePipeline` reads it once, in its
    // constructor.
    if let Some(path) = args.vad_model.as_deref() {
        if !path.exists() {
            eprintln!("model VAD tidak ada: {}", path.display());
            std::process::exit(1);
        }
        rust_core::vad::whisper_silero::set_model_path(Some(path.to_path_buf()));
    }
    let audio_path = PathBuf::from(&args.audio);
    let audio = match decode_audio_file(&audio_path) {
        Ok(audio) => audio,
        Err(e) => {
            eprintln!("tidak bisa membaca {}: {e}", audio_path.display());
            std::process::exit(1);
        }
    };
    let engine = match WhisperEngine::load(Path::new(&args.model)) {
        Ok(engine) => engine,
        Err(e) => {
            eprintln!("tidak bisa memuat model {}: {e}", args.model);
            std::process::exit(1);
        }
    };

    let speech =
        detect_speech_regions(&audio.samples, SegmentationConfig::default(), 4).unwrap_or_default();
    let speech_secs: f64 = speech.iter().map(|(start, end)| end - start).sum();

    println!("# Live-path benchmark\n");
    println!("- Audio: `{}`", audio_path.display());
    println!("- Panjang: {:.1} s", audio.duration_secs);
    println!(
        "- Bicara menurut VAD: {speech_secs:.1} s ({:.0}%)",
        100.0 * speech_secs / audio.duration_secs.max(f64::EPSILON)
    );
    println!("- Model: `{}`", args.model);
    println!(
        "- Gerbang Silero: {}\n",
        match args.vad_model.as_deref() {
            Some(path) => format!("`{}`", path.display()),
            None => "tidak dipakai (--vad-model tidak diberikan)".to_string(),
        }
    );

    let all = args.policy == "all";
    let legacy = (all || args.policy == "legacy").then(|| {
        eprintln!("menjalankan jalur lama sebelum Sprint 4b (potongan 5 s)…");
        measure_legacy(&engine, &audio.samples, &args.language)
    });
    let fixed = (all || args.policy == "fixed").then(|| {
        eprintln!("menjalankan StreamPolicy::fixed_chunk…");
        measure_policy(
            &engine,
            &audio.samples,
            &args.language,
            StreamPolicy::fixed_chunk(),
        )
    });
    let la2 = (all || args.policy == "la2").then(|| {
        eprintln!("menjalankan LocalAgreement-2…");
        measure_policy(
            &engine,
            &audio.samples,
            &args.language,
            StreamPolicy::local_agreement(),
        )
    });

    println!(
        "| Kebijakan | Baris | Kata | Cakupan live | Latensi median | Latensi p90 | \
         Detik dekode | RTF |"
    );
    println!("|---|---|---|---|---|---|---|---|");
    for (name, measurement) in [
        ("Lama sebelum 4b (5 s)", &legacy),
        ("fixed_chunk", &fixed),
        ("LocalAgreement-2", &la2),
    ] {
        let Some(m) = measurement else { continue };
        println!(
            "| {name} | {} | {} | {:.0}% | {:.2} s | {:.2} s | {:.1} s | {:.2} |",
            m.segments,
            m.words,
            100.0 * m.coverage(speech_secs),
            m.median_latency(),
            m.p90_latency(),
            m.decode_secs,
            m.rtf(audio.duration_secs),
        );
    }

    for (name, measurement) in [
        ("Lama sebelum 4b (5 s)", &legacy),
        ("fixed_chunk", &fixed),
        ("LocalAgreement-2", &la2),
    ] {
        let Some(m) = measurement else { continue };
        println!("\n## Baris yang di-commit — {name}\n");
        if m.lines.is_empty() {
            println!("(tidak ada)");
            continue;
        }
        println!("```");
        for line in &m.lines {
            println!("{line}");
        }
        println!("```");
    }
}

/// One [`StreamPolicy`] through the real [`LivePipeline`].
fn measure_policy(
    engine: &WhisperEngine,
    samples: &[f32],
    language: &str,
    policy: StreamPolicy,
) -> Measurement {
    let mut pipeline = LivePipeline::with_policy(
        engine,
        "mic",
        Some(language.to_string()),
        rust_core::vad::VadConfig::default(),
        true,
        GlossaryConfig::default(),
        policy,
    )
    .expect("build live pipeline");

    let mut measurement = Measurement::default();
    let started = Instant::now();
    let buffer = (TARGET_SAMPLE_RATE as f64 * BUFFER_SECS) as usize;
    let mut delivered_secs = 0.0f64;
    for chunk in samples.chunks(buffer) {
        delivered_secs += chunk.len() as f64 / TARGET_SAMPLE_RATE as f64;
        wait_until(started, delivered_secs);
        let decode_started = Instant::now();
        let outcome = pipeline.ingest(chunk);
        measurement.decode_secs += decode_started.elapsed().as_secs_f64();
        let outcome = match outcome {
            Ok(outcome) => outcome,
            Err(e) => {
                eprintln!("ingest gagal: {e}");
                continue;
            }
        };
        record(&mut measurement, &outcome.segments, started);
    }
    let finished = pipeline.finish();
    record(&mut measurement, &finished, started);
    measurement.wall_secs = started.elapsed().as_secs_f64();
    measurement
}

/// Blocks until `audio_secs` of the recording would have arrived.
///
/// A no-op once the decoder has fallen behind, which is the state this
/// machine spends most of a session in.
fn wait_until(started: Instant, audio_secs: f64) {
    let target = std::time::Duration::from_secs_f64(audio_secs);
    let elapsed = started.elapsed();
    if let Some(remaining) = target.checked_sub(elapsed) {
        std::thread::sleep(remaining);
    }
}

/// The policy this sprint replaced: fixed 5-second chunks with 1 second of
/// overlap, every word of every chunk treated as final.
///
/// Reimplemented here rather than kept alive in the pipeline — the
/// comparison has to be against what the app actually used to do, and
/// leaving a second code path in `pipeline.rs` to support a benchmark
/// would be the wrong trade.
fn measure_legacy(engine: &WhisperEngine, samples: &[f32], language: &str) -> Measurement {
    let mut measurement = Measurement::default();
    let started = Instant::now();
    let chunk_len = (TARGET_SAMPLE_RATE as f64 * LEGACY_CHUNK_SECS) as usize;
    let stride = (TARGET_SAMPLE_RATE as f64 * (LEGACY_CHUNK_SECS - LEGACY_OVERLAP_SECS)) as usize;

    let mut offset = 0usize;
    while offset + chunk_len <= samples.len() {
        let chunk = &samples[offset..offset + chunk_len];
        let chunk_start = offset as f64 / TARGET_SAMPLE_RATE as f64;
        // The chunk is only complete once its last sample has arrived.
        wait_until(started, chunk_start + LEGACY_CHUNK_SECS);
        let decode_started = Instant::now();
        let mut segments = engine
            .transcribe_chunk_with(
                chunk,
                "mic",
                chunk_start,
                Some(language),
                None,
                DecodeOptions::live(),
            )
            .unwrap_or_default();
        measurement.decode_secs += decode_started.elapsed().as_secs_f64();
        rust_core::hallucination::filter_segments(&mut segments);
        record(&mut measurement, &segments, started);
        offset += stride;
    }
    measurement.wall_secs = started.elapsed().as_secs_f64();
    measurement
}

/// Folds a batch of emitted segments into the measurement.
///
/// Latency is `wall_elapsed - segment_end`: how much later than the moment
/// the words were spoken the user could read them. Because the feeder
/// paces in real time, `wall_elapsed` is also when the audio arrived — so
/// on a machine that keeps up this is the policy's own delay, and on one
/// that does not it is that plus how far behind the decoder has fallen.
fn record(
    measurement: &mut Measurement,
    segments: &[rust_core::export::Segment],
    started: Instant,
) {
    let elapsed = started.elapsed().as_secs_f64();
    for segment in segments {
        if segment.text.trim().is_empty() {
            continue;
        }
        measurement.segments += 1;
        measurement.words += segment.text.split_whitespace().count();
        measurement.covered_secs += segment.duration.max(0.0);
        let segment_end = segment.timestamp + segment.duration;
        measurement.latencies.push((elapsed - segment_end).max(0.0));
        measurement.lines.push(format!(
            "[{:>7.2}–{:>7.2}] {}",
            segment.timestamp,
            segment_end,
            segment.text.trim()
        ));
    }
}
