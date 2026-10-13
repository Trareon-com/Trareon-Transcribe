//! Standalone manual probe for the FULL `LiveWorker::spawn()` dispatch
//! path with a CrispASR model, feeding audio in many small chunks to
//! simulate a real cpal capture callback cadence (unlike
//! `crispasr_stream_probe`, which drives `CrispAsrStreamEngine`
//! directly in just 2 big chunks and bypasses `LiveWorker` entirely).
//!
//! This is the first test of the actual dispatch condition in
//! `LiveWorker::spawn` (filename match -> spawn_crispasr_stream) and of
//! `LiveEvent` translation, not just the engine underneath it.
//!
//! Usage: live_crispasr_probe <model.gguf> <audio.wav> [lang]
//! (crispasr CLI resolved via CRISPASR_CLI_PATH env var or a binary
//! named crispasr/crispasr.exe sitting next to the model file)

use std::path::PathBuf;
use std::sync::mpsc;
use std::time::Duration;

use rust_core::audio::HptMode;
use rust_core::glossary::GlossaryConfig;
use rust_core::pipeline::{LiveEvent, LiveWorker, LiveWorkerConfig};

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() < 3 {
        eprintln!("usage: {} <model.gguf> <audio.wav> [lang]", args[0]);
        std::process::exit(2);
    }
    let model_path = PathBuf::from(&args[1]);
    let wav_path = &args[2];
    let lang = args.get(3).cloned().unwrap_or_else(|| "id".to_string());

    let mut reader = hound::WavReader::open(wav_path).expect("open wav");
    let spec = reader.spec();
    println!("wav: {} Hz, {} ch, {:?}", spec.sample_rate, spec.channels, spec.sample_format);
    let samples: Vec<f32> = match spec.sample_format {
        hound::SampleFormat::Float => reader.samples::<f32>().map(|s| s.unwrap()).collect(),
        hound::SampleFormat::Int => reader
            .samples::<i32>()
            .map(|s| s.unwrap() as f32 / i16::MAX as f32)
            .collect(),
    };

    let config = LiveWorkerConfig {
        quick_model_path: model_path,
        refine_model_path: None,
        hpt_mode: HptMode::Auto,
        source: "mic".to_string(),
        language: Some(lang),
        vad_enabled: true,
        gpu_enabled: false,
        gpu_device: 0,
        glossary: GlossaryConfig::default(),
        fallback_model_path: None,
    };

    let (samples_tx, samples_rx) = mpsc::channel::<Vec<f32>>();
    let (events_tx, events_rx) = mpsc::channel::<LiveEvent>();

    let mut worker = LiveWorker::spawn(config, samples_rx, events_tx)
        .expect("LiveWorker::spawn (expected to dispatch to spawn_crispasr_stream)");
    println!("LiveWorker spawned -- feeding audio in 100ms chunks (cpal-like cadence)...");

    // 16kHz mono -> 1600 samples per 100ms, mimicking a real capture
    // callback instead of one giant push.
    let chunk_size = 1600;
    for chunk in samples.chunks(chunk_size) {
        samples_tx.send(chunk.to_vec()).expect("send chunk");
        std::thread::sleep(Duration::from_millis(30)); // faster than real-time on purpose
    }

    // Drain whatever arrived while feeding.
    std::thread::sleep(Duration::from_millis(500));
    while let Ok(event) = events_rx.try_recv() {
        print_event(&event);
    }

    println!("stopping worker...");
    worker.stop();
    let exited = worker.wait_for_exit(Duration::from_secs(45));
    println!("worker exited cleanly: {exited}");

    // Drain the final flush.
    while let Ok(event) = events_rx.try_recv() {
        print_event(&event);
    }
}

fn print_event(event: &LiveEvent) {
    match event {
        LiveEvent::Vu { .. } => {} // noisy, skip
        LiveEvent::Segment(seg) => {
            println!(
                "SEGMENT [{:.2}-{:.2}] {}",
                seg.timestamp,
                seg.timestamp + seg.duration,
                seg.text
            );
        }
        LiveEvent::Tentative { text, .. } if !text.is_empty() => {
            println!("tentative: {text}");
        }
        LiveEvent::Tentative { .. } => {}
    }
}
