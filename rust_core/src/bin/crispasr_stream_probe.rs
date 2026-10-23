//! Standalone manual probe for `CrispAsrStreamEngine` (2026-10-13).
//!
//! Feeds a whole WAV file to the streaming engine in one `push_pcm`
//! call (simulating what a live capture thread would do incrementally)
//! and prints every event the reader thread parses, to prove the real
//! end-to-end path — spawn, write stdin, background-thread JSON
//! parsing, `finish()` — works against the real CLI, not just the
//! wire-format unit test.
//!
//! Usage: crispasr_stream_probe <cli_path> <model.gguf> <backend_flag> <audio.wav> [lang]

use std::path::Path;

use rust_core::stt::CrispAsrStreamEngine;

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() < 5 {
        eprintln!(
            "usage: {} <cli_path> <model.gguf> <backend_flag> <audio.wav> [lang]",
            args[0]
        );
        std::process::exit(2);
    }
    let cli_path = Path::new(&args[1]);
    let model_path = Path::new(&args[2]);
    let backend_flag = &args[3];
    let wav_path = &args[4];
    let lang = args.get(5).map(|s| s.as_str()).unwrap_or("id");

    let mut reader = hound::WavReader::open(wav_path).expect("open wav");
    let spec = reader.spec();
    println!(
        "wav: {} Hz, {} ch, {:?}",
        spec.sample_rate, spec.channels, spec.sample_format
    );
    let samples: Vec<f32> = match spec.sample_format {
        hound::SampleFormat::Float => reader.samples::<f32>().map(|s| s.unwrap()).collect(),
        hound::SampleFormat::Int => reader
            .samples::<i32>()
            .map(|s| s.unwrap() as f32 / i16::MAX as f32)
            .collect(),
    };

    let mut engine = CrispAsrStreamEngine::spawn(cli_path, model_path, backend_flag, Some(lang))
        .expect("spawn stream engine");
    println!("spawned, pushing {} samples in 2 chunks...", samples.len());

    // Simulate two capture-thread callbacks rather than one giant push,
    // closer to how a live mic stream actually arrives.
    let mid = samples.len() / 2;
    engine.push_pcm(&samples[..mid]).expect("push_pcm chunk 1");
    std::thread::sleep(std::time::Duration::from_millis(200));
    for event in engine.poll_events() {
        println!("mid-poll: {event:?}");
    }
    engine.push_pcm(&samples[mid..]).expect("push_pcm chunk 2");

    println!("closing stdin, waiting for final flush...");
    let final_events = engine.finish().expect("finish");
    for event in final_events {
        println!("final-drain: {event:?}");
    }
}
