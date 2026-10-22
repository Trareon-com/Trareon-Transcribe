//! One-off probe: load a Qwen3-ASR GGUF via `CrispAsrEngine` (the
//! subprocess-backed `SttEngine` impl) and transcribe a real FLEURS-id
//! sample end-to-end, through Trareon's own types (`Segment`), not just
//! through CrispASR's CLI directly.
//!
//! Usage: `crispasr_probe <cli_path> <model.gguf> <backend_flag> <audio.wav> [variant_label]`
//! e.g.:  `crispasr_probe .../crispasr .../qwen3-asr-1.7b-q4_k.gguf qwen3-1.7b sample.wav qwen3-asr-1.7b`

use std::path::Path;

use rust_core::stt::{CrispAsrEngine, SttEngine};

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() < 5 {
        eprintln!(
            "usage: crispasr_probe <cli_path> <model.gguf> <backend_flag> <audio.wav> [variant_label]"
        );
        std::process::exit(2);
    }
    let cli_path = Path::new(&args[1]);
    let model_path = Path::new(&args[2]);
    let backend_flag = &args[3];
    let wav_path = &args[4];
    let variant = args.get(5).map(String::as_str).unwrap_or("qwen3-asr");

    let mut reader = hound::WavReader::open(wav_path).expect("open wav");
    let spec = reader.spec();
    eprintln!(
        "wav: {} Hz, {} ch, {:?}",
        spec.sample_rate, spec.channels, spec.sample_format
    );
    assert_eq!(
        spec.sample_rate, 16000,
        "probe expects pre-resampled 16kHz input"
    );
    assert_eq!(spec.channels, 1, "probe expects mono input");

    let samples: Vec<f32> = match spec.sample_format {
        hound::SampleFormat::Float => reader.samples::<f32>().map(|s| s.unwrap()).collect(),
        hound::SampleFormat::Int => reader
            .samples::<i16>()
            .map(|s| s.unwrap() as f32 / 32768.0)
            .collect(),
    };

    eprintln!(
        "loading CrispASR engine: cli={} model={} backend={backend_flag} ({variant})",
        cli_path.display(),
        model_path.display()
    );
    let t0 = std::time::Instant::now();
    let engine = CrispAsrEngine::load(cli_path, model_path, backend_flag, variant)
        .expect("load CrispAsrEngine");
    eprintln!("load took {:.2}s", t0.elapsed().as_secs_f64());

    let t1 = std::time::Instant::now();
    let segments = engine
        .transcribe(
            &samples,
            "probe",
            0.0,
            Some("id"),
            None,
            rust_core::stt::DecodeOptions::default(),
        )
        .expect("transcribe");
    let elapsed = t1.elapsed().as_secs_f64();

    println!("engine_id = {}", engine.engine_id());
    println!("is_experimental = {}", engine.is_experimental());
    println!(
        "audio_secs = {:.2}, infer_secs = {:.2}, rtf = {:.3}",
        samples.len() as f64 / 16000.0,
        elapsed,
        elapsed / (samples.len() as f64 / 16000.0)
    );
    for seg in &segments {
        println!(
            "[{:.2}-{:.2}] {}",
            seg.timestamp,
            seg.timestamp + seg.duration,
            seg.text
        );
    }
}
