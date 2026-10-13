//! Real-microphone variant of `live_crispasr_probe`: instead of feeding a
//! pre-recorded WAV in simulated 100ms chunks, this opens the system's
//! actual default input device via `AudioCapture::start` (the exact same
//! function `session.rs` uses for a real recording session) and forwards
//! live PCM into `LiveWorker::spawn`'s CrispASR dispatch path for a fixed
//! duration.
//!
//! This is the one thing `live_crispasr_probe` (WAV-fed) could not prove:
//! that the full chain -- OS mic permission, cpal/PulseAudio capture,
//! `samples_tx` channel, `LiveWorker::spawn`'s filename-match dispatch,
//! `CrispAsrStreamEngine`'s subprocess, and `LiveEvent` translation back
//! out -- works end-to-end against a live hardware source, not just a
//! `Vec<f32>` already sitting in memory.
//!
//! Usage: live_crispasr_mic_probe <model.gguf> [seconds] [lang]
//! (CRISPASR_CLI_PATH env var or sibling crispasr/crispasr.exe, same as
//! live_crispasr_probe)

use std::path::PathBuf;
use std::sync::mpsc;
use std::time::Duration;

use rust_core::audio::{AudioCapture, HptMode};
use rust_core::glossary::GlossaryConfig;
use rust_core::pipeline::{LiveEvent, LiveWorker, LiveWorkerConfig};

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.is_empty() || args.len() < 2 {
        eprintln!("usage: {} <model.gguf> [seconds=8] [lang=id]", args.first().map(String::as_str).unwrap_or("live_crispasr_mic_probe"));
        std::process::exit(2);
    }
    let model_path = PathBuf::from(&args[1]);
    let record_secs: u64 = args.get(2).and_then(|s| s.parse().ok()).unwrap_or(8);
    let lang = args.get(3).cloned().unwrap_or_else(|| "id".to_string());

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
    println!("LiveWorker spawned (CrispASR dispatch).");

    println!("Opening real microphone via AudioCapture::start (same path session.rs uses)...");
    let mut capture =
        AudioCapture::start("mic", None, samples_tx).expect("open default microphone");
    println!(
        "Mic open -- recording for {record_secs}s. Please speak a short sentence now..."
    );

    let start = std::time::Instant::now();
    while start.elapsed() < Duration::from_secs(record_secs) {
        // Drain tentative events as they arrive so the probe shows live
        // progress instead of a silent wait, mirroring what the Flutter
        // UI's live caption view does with the same channel.
        while let Ok(event) = events_rx.try_recv() {
            print_event(&event);
        }
        if let Some(failure) = capture.take_failure() {
            eprintln!("mic capture failed mid-recording: {failure}");
            break;
        }
        std::thread::sleep(Duration::from_millis(100));
    }

    println!("stopping mic capture...");
    capture.stop();

    // Drain whatever arrived while recording.
    std::thread::sleep(Duration::from_millis(300));
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
        LiveEvent::Vu { level, .. } => {
            // Diagnostic-only: confirms real audio samples are actually
            // arriving from the hardware mic (not just a clean-but-silent
            // run) -- the file-fed live_crispasr_probe never needed this
            // since its WAV source obviously has signal; a mic probe can
            // run clean end-to-end (worker starts, stops, no error) while
            // capturing pure silence (TCC denial, wrong input device, a
            // muted hardware mic) and this is the only way to tell those
            // two cases apart from the probe's own output.
            if *level > 0.001 {
                println!("vu: level={level:.4} (audio detected)");
            }
        }
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
