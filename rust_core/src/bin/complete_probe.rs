//! `complete_probe` — runs the post-stop completion pass over a saved
//! session folder and reports what it recovered.
//!
//! This is the command-line face of ITEM 0: point it at a session
//! directory the app wrote and it will, per captured track, report what
//! the live transcript covered, transcribe the stretches it missed, and
//! print the merged result with its coverage figures.
//!
//! ```text
//! complete_probe --session "~/Documents/TrareonTranscribe/<sesi>" \
//!     --model models/ggml-tiny.bin --language id
//! ```
//!
//! `--dry-run` reports coverage without running any inference, which is
//! how you tell whether a session needs the pass at all.

use std::path::{Path, PathBuf};

use clap::Parser;
use rust_core::completion::{complete_transcript, source_for_audio, CompletionRequest};
use rust_core::coverage;
use rust_core::export::Segment;
use rust_core::glossary::GlossaryConfig;
use rust_core::stt::WhisperEngine;

#[derive(Parser, Debug)]
#[command(
    name = "complete_probe",
    about = "Transcribe the parts of a saved session the live pass never reached"
)]
struct Args {
    /// Session directory: the folder holding mic.wav / speaker.wav and the
    /// transcript JSON.
    #[arg(long)]
    session: String,

    /// Path to a GGML whisper model.
    #[arg(long, default_value = "models/ggml-tiny.bin")]
    model: String,

    #[arg(long)]
    language: Option<String>,

    /// Report coverage only; run no inference.
    #[arg(long, default_value_t = false)]
    dry_run: bool,

    /// Write the merged transcript back as `<name>.completed.json` instead
    /// of only printing it.
    #[arg(long, default_value_t = false)]
    write: bool,
}

fn main() {
    tracing_subscriber::fmt().with_env_filter("warn").init();
    std::process::exit(run(Args::parse()));
}

fn run(args: Args) -> i32 {
    let dir = PathBuf::from(&args.session);
    if !dir.is_dir() {
        eprintln!("not a directory: {}", dir.display());
        return 1;
    }
    let Some((transcript_path, existing)) = load_transcript(&dir) else {
        eprintln!("no transcript JSON in {}", dir.display());
        return 1;
    };
    println!(
        "transcript: {} ({} segmen)",
        transcript_path.display(),
        existing.len()
    );

    let tracks: Vec<PathBuf> = ["mic.wav", "speaker.wav"]
        .iter()
        .map(|name| dir.join(name))
        .filter(|path| path.exists())
        .collect();
    if tracks.is_empty() {
        eprintln!("no mic.wav / speaker.wav in {}", dir.display());
        return 1;
    }

    let engine = if args.dry_run {
        None
    } else {
        match WhisperEngine::load(Path::new(&args.model)) {
            Ok(engine) => Some(engine),
            Err(e) => {
                eprintln!("failed to load model '{}': {e}", args.model);
                return 1;
            }
        }
    };

    let mut merged = existing;
    for track in &tracks {
        let source = source_for_audio(track);
        let own: Vec<Segment> = merged
            .iter()
            .filter(|s| s.source == source)
            .cloned()
            .collect();
        let audio_secs = match rust_core::api::audio_duration_secs(track.display().to_string()) {
            Ok(secs) => secs,
            Err(e) => {
                eprintln!("  {source}: cannot read {}: {e}", track.display());
                continue;
            }
        };
        let before = coverage::report(&own, audio_secs, coverage::MIN_GAP_SECS);
        println!(
            "\n[{source}] {} — {:.0}s audio, {:.0}s tertranskrip ({:.1}%), {} celah / {:.0}s hilang",
            track.display(),
            audio_secs,
            before.covered_secs,
            before.fraction * 100.0,
            before.gaps.len(),
            before.missing_secs
        );
        let Some(engine) = engine.as_ref() else {
            continue;
        };

        let request = CompletionRequest {
            audio_path: track.clone(),
            source: source.to_string(),
            language: args.language.clone(),
            glossary: GlossaryConfig::default(),
            vad_enabled: true,
        };
        let started = std::time::Instant::now();
        let mut last_percent = 0u32;
        let outcome = match complete_transcript(engine, &request, own.clone(), |fraction, eta| {
            let percent = (fraction * 100.0) as u32;
            if percent >= last_percent + 10 {
                last_percent = percent;
                println!("  Menyelesaikan transkrip… {percent}% (sisa ~{eta:.0}s)");
            }
        }) {
            Ok(outcome) => outcome,
            Err(e) => {
                eprintln!("  {source}: completion failed: {e}");
                continue;
            }
        };
        println!(
            "  selesai dalam {:.0}s — +{} segmen, {} baris non-ucapan ditolak, \
             ucapan {:.0}s dari {:.0}s tertranskrip ({:.1}%), {} celah tersisa",
            started.elapsed().as_secs_f64(),
            outcome.added,
            outcome.rejected,
            outcome.speech_covered_secs,
            outcome.speech_secs,
            outcome.speech_fraction() * 100.0,
            outcome.coverage.gaps.len()
        );
        for segment in &outcome.segments {
            println!(
                "    [{:>7.2}s +{:>5.2}s] {:<12} {}",
                segment.timestamp, segment.duration, segment.speaker, segment.text
            );
        }
        // Replace this source's slice of the merged transcript.
        merged.retain(|s| s.source != source);
        merged.extend(outcome.segments);
        merged.sort_by(|a, b| a.timestamp.total_cmp(&b.timestamp));
    }

    if args.write && !args.dry_run {
        let out = transcript_path.with_extension("completed.json");
        match serde_json::to_vec_pretty(&merged) {
            Ok(bytes) => match std::fs::write(&out, bytes) {
                Ok(()) => println!("\nditulis: {}", out.display()),
                Err(e) => eprintln!("write failed: {e}"),
            },
            Err(e) => eprintln!("serialise failed: {e}"),
        }
    }
    0
}

/// The session's transcript JSON: the one `.json` that parses as a segment
/// array. `trareon-session.json` is the sidecar and is skipped.
fn load_transcript(dir: &Path) -> Option<(PathBuf, Vec<Segment>)> {
    let entries = std::fs::read_dir(dir).ok()?;
    for entry in entries.flatten() {
        let path = entry.path();
        if path.extension().and_then(|e| e.to_str()) != Some("json") {
            continue;
        }
        if path.file_name().and_then(|n| n.to_str()) == Some("trareon-session.json") {
            continue;
        }
        let Ok(text) = std::fs::read_to_string(&path) else {
            continue;
        };
        if let Ok(segments) = serde_json::from_str::<Vec<Segment>>(&text) {
            return Some((path, segments));
        }
    }
    None
}
