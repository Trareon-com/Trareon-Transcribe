//! Measures how long `start_session` blocks for, broken down by phase.
//!
//! The GUI's record button shows "⚡ Memulai..." for exactly as long as this
//! call takes, so this is the number behind "the button is stuck". Capture
//! start is bounded by the audio backends; the rest is Whisper model loading
//! and the adaptive-HPT benchmark, which is what actually dominates.
//!
//! ```text
//! cargo run --release --bin session_start_probe -- <quick-model> [refine-model] [observe-secs]
//! ```

use std::time::Instant;

use rust_core::audio::{SessionConfig, SessionMode};

fn main() {
    tracing_subscriber::fmt()
        .with_max_level(tracing::Level::INFO)
        .with_writer(std::io::stderr)
        .init();

    let mut args = std::env::args().skip(1);
    let Some(quick_model) = args.next() else {
        eprintln!("usage: session_start_probe <quick-model> [refine-model] [observe-secs]");
        std::process::exit(2);
    };
    let refine_model = args.next();
    let observe_secs: u64 = args.next().and_then(|a| a.parse().ok()).unwrap_or(30);

    let mut config = SessionConfig::for_mode(SessionMode::Online, quick_model.clone());
    config.refine_model_path = refine_model.clone();
    println!("mode:   Rapat Online (mic + system audio)");
    println!("quick:  {quick_model}");
    println!("refine: {refine_model:?}");

    let started = Instant::now();
    let result = rust_core::session::start_session(config);
    let elapsed = started.elapsed();

    match result {
        Ok(id) => {
            println!(
                "\nstart_session returned OK in {:.1}s",
                elapsed.as_secs_f64()
            );
            println!("session: {id}");
            // Then watch it transcribe, so a "fast start" that captures
            // nothing cannot pass as success.
            for tick in 1..=(observe_secs / 10).max(1) {
                std::thread::sleep(std::time::Duration::from_secs(10));
                match rust_core::session::poll_events(&id) {
                    Ok(events) => {
                        let transcripts: Vec<_> = events
                            .iter()
                            .filter_map(|event| match event {
                                rust_core::session::SessionEvent::Transcript(segment) => {
                                    Some(format!("[{}] {}", segment.speaker, segment.text.trim()))
                                }
                                _ => None,
                            })
                            .collect();
                        let notices: Vec<_> = events
                            .iter()
                            .filter_map(|event| match event {
                                rust_core::session::SessionEvent::Notice { message, .. } => {
                                    Some(message.clone())
                                }
                                _ => None,
                            })
                            .collect();
                        let peak = |want: &str| {
                            events
                                .iter()
                                .filter_map(|event| match event {
                                    rust_core::session::SessionEvent::Vu { source, level }
                                        if source == want =>
                                    {
                                        Some(*level)
                                    }
                                    _ => None,
                                })
                                .fold(0.0f32, f32::max)
                        };
                        println!(
                            "t={}s  vu(mic)={:.4} vu(spk)={:.4}  {} transcript(s)",
                            tick * 10,
                            peak("mic"),
                            peak("spk"),
                            transcripts.len()
                        );
                        for line in transcripts {
                            println!("      {line}");
                        }
                        for notice in notices {
                            println!("      NOTICE: {notice}");
                        }
                    }
                    Err(e) => println!("t={}s  poll failed — {e}", tick * 10),
                }
            }
            let _ = rust_core::session::stop_session(&id);
        }
        Err(e) => {
            println!(
                "\nstart_session returned Err in {:.1}s: {e}",
                elapsed.as_secs_f64()
            );
        }
    }
}
