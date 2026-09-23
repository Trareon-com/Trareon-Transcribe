//! Rust Engine poll probe — verifies that poll_events() returns data
//! when a session is started with capture disabled (no real audio device).
//!
//! Usage: cargo run --bin poll_probe
//!
//! Expected output:
//!   - Session started: <id>
//!   - Poll iteration 1: 0 events (no capture = no audio data, OK)
//!   - Poll iteration 2..N: 0 events (expected — capture is disabled)
//!   - Session stopped: OK
//!
//! With capture ENABLED on a real machine, events > 0 indicates
//! the full pipeline (capture → VAD → STT → poll) works end-to-end.

fn main() {
    tracing_subscriber::fmt().with_env_filter("info").init();

    let config = rust_core::audio::SessionConfig {
        mic_enabled: false,
        speaker_enabled: false,
        mode: rust_core::audio::SessionMode::Offline,
        mic_device_id: None,
        speaker_device_id: None,
        model_path: "tiny".to_string(),
        refine_model_path: None,
        hpt_mode: rust_core::audio::HptMode::Auto,
        vad_enabled: false,
        sample_rate: 16_000,
        chunk_duration_secs: 30,
        gpu_enabled: false,
        gpu_device: 0,
    };

    let session_id = rust_core::api::start_session(config).expect("start_session");
    println!("Session started: {session_id}");

    for i in 1..=5 {
        std::thread::sleep(std::time::Duration::from_millis(200));
        match rust_core::api::poll_session_events(session_id.clone()) {
            Ok(events) => println!("Poll {i}: {} events", events.len()),
            Err(e) => println!("Poll {i}: ERROR — {e}"),
        }
    }

    rust_core::api::stop_session(session_id.clone()).expect("stop_session");
    println!("Session stopped: OK");
}
