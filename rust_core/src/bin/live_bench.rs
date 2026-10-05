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
//! # Why it does not sleep
//!
//! Feeding the pipeline in real time would make a 15-second clip take 15
//! seconds and measure the sleep, not the engine. Instead the buffers are
//! delivered as fast as the pipeline accepts them and the arrival time of
//! each buffer is taken to be its audio time — so on a machine that keeps
//! up the figures match a real session, and on one that does not, the
//! latency is the honest "how far behind did it fall".
//!
//! Nothing here touches the network and nothing opens an audio device.

use std::path::{Path, PathBuf};
use std::time::Instant;

use clap::Parser;
use rust_core::decode::{decode_audio_file, TARGET_SAMPLE_RATE};
use rust_core::glossary::GlossaryConfig;
use rust_core::pipeline::LivePipeline;
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

    /// `la2`, `legacy`, or `both`.
    #[arg(long, default_value = "both")]
    policy: String,

    /// Force a language. Auto-detect on a short window is a coin toss and
    /// the noise lands in the measurement.
    #[arg(long, default_value = "id")]
    language: String,
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
    wall_secs: f64,
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
    println!("- Model: `{}`\n", args.model);

    let run_la2 = args.policy != "legacy";
    let run_legacy = args.policy != "la2";

    let legacy = run_legacy.then(|| {
        eprintln!("menjalankan kebijakan lama (potongan 5 s)…");
        measure_legacy(&engine, &audio.samples, &args.language)
    });
    let la2 = run_la2.then(|| {
        eprintln!("menjalankan LocalAgreement-2…");
        measure_la2(&engine, &audio.samples, &args.language)
    });

    println!(
        "| Kebijakan | Baris | Kata | Cakupan live | Latensi median | Latensi p90 | Waktu nyata |"
    );
    println!("|---|---|---|---|---|---|---|");
    for (name, measurement) in [("Lama (5 s)", &legacy), ("LocalAgreement-2", &la2)] {
        let Some(m) = measurement else { continue };
        println!(
            "| {name} | {} | {} | {:.0}% | {:.2} s | {:.2} s | {:.1} s |",
            m.segments,
            m.words,
            100.0 * m.coverage(speech_secs),
            m.median_latency(),
            m.p90_latency(),
            m.wall_secs,
        );
    }
}

/// LocalAgreement-2 through the real [`LivePipeline`].
fn measure_la2(engine: &WhisperEngine, samples: &[f32], language: &str) -> Measurement {
    let mut pipeline = LivePipeline::new(
        engine,
        "mic",
        Some(language.to_string()),
        rust_core::vad::VadConfig::default(),
        true,
        GlossaryConfig::default(),
    )
    .expect("build live pipeline");

    let mut measurement = Measurement::default();
    let started = Instant::now();
    let buffer = (TARGET_SAMPLE_RATE as f64 * BUFFER_SECS) as usize;
    let mut delivered_secs = 0.0f64;
    for chunk in samples.chunks(buffer) {
        delivered_secs += chunk.len() as f64 / TARGET_SAMPLE_RATE as f64;
        let outcome = match pipeline.ingest(chunk) {
            Ok(outcome) => outcome,
            Err(e) => {
                eprintln!("ingest gagal: {e}");
                continue;
            }
        };
        record(&mut measurement, &outcome.segments, delivered_secs);
    }
    let finished = pipeline.finish();
    record(&mut measurement, &finished, delivered_secs);
    measurement.wall_secs = started.elapsed().as_secs_f64();
    measurement
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
        let delivered_secs = chunk_start + LEGACY_CHUNK_SECS;
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
        rust_core::hallucination::filter_segments(&mut segments);
        record(&mut measurement, &segments, delivered_secs);
        offset += stride;
    }
    measurement.wall_secs = started.elapsed().as_secs_f64();
    measurement
}

/// Folds a batch of emitted segments into the measurement.
///
/// `delivered_secs` is how much audio had been handed to the pipeline when
/// these came out. The latency of a segment is therefore
/// `delivered_secs - segment_end`: how much later than the moment the
/// words were spoken the user could read them.
fn record(
    measurement: &mut Measurement,
    segments: &[rust_core::export::Segment],
    delivered_secs: f64,
) {
    for segment in segments {
        if segment.text.trim().is_empty() {
            continue;
        }
        measurement.segments += 1;
        measurement.words += segment.text.split_whitespace().count();
        measurement.covered_secs += segment.duration.max(0.0);
        let segment_end = segment.timestamp + segment.duration;
        measurement
            .latencies
            .push((delivered_secs - segment_end).max(0.0));
    }
}
