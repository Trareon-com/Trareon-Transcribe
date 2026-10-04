//! WER/CER benchmark across models (F18).
//!
//! ```text
//! wer_bench --manifest bench/id_id.tsv \
//!           --model ~/Library/Caches/TrareonTranscribe/models/ggml-base.bin \
//!           --model models/ggml-tiny.bin \
//!           --out bench/results.md
//! ```
//!
//! The manifest is TSV: `path-to-audio<TAB>reference text`, paths relative
//! to the manifest's own directory so a corpus can be moved as a unit.
//! `scripts/fetch_wer_corpus.sh` builds one from FLEURS id_id; no audio is
//! committed to this repository.
//!
//! Prints a Markdown table and, with `--json`, the per-clip detail — the
//! table is for a README and the detail is for working out *which* clips a
//! model loses.

use std::path::{Path, PathBuf};
use std::time::Instant;

use clap::Parser;
use rust_core::glossary::GlossaryConfig;
use rust_core::stt::file::transcribe_file;
use rust_core::stt::WhisperEngine;
use rust_core::wer::{
    char_errors, parse_manifest, render_table, word_errors, ClipScore, ModelScore,
};

#[derive(Parser, Debug)]
#[command(
    name = "wer_bench",
    about = "Hitung WER/CER beberapa model Whisper atas satu manifes klip"
)]
struct Args {
    /// TSV manifest: `audio<TAB>teks acuan`.
    #[arg(long)]
    manifest: String,

    /// A model to measure. Repeat for a comparison.
    #[arg(long = "model", required = true)]
    models: Vec<String>,

    /// Force a language instead of auto-detect. Defaults to Indonesian,
    /// because auto-detect on a two-second clip is a coin toss and that
    /// noise lands in the WER.
    #[arg(long, default_value = "id")]
    language: String,

    /// Write the Markdown table here as well as to stdout.
    #[arg(long)]
    out: Option<String>,

    /// Also print per-clip JSON.
    #[arg(long, default_value_t = false)]
    json: bool,

    /// Enable GPU acceleration if this binary was built with a backend.
    #[arg(long, default_value_t = false)]
    gpu: bool,

    /// Stop after this many clips. For a smoke run on a slow machine.
    #[arg(long)]
    limit: Option<usize>,
}

fn main() -> std::process::ExitCode {
    let args = Args::parse();

    let manifest_path = PathBuf::from(&args.manifest);
    let content = match std::fs::read_to_string(&manifest_path) {
        Ok(content) => content,
        Err(e) => {
            eprintln!("tidak bisa membaca manifes {}: {e}", args.manifest);
            return std::process::ExitCode::FAILURE;
        }
    };
    let mut entries = match parse_manifest(&content) {
        Ok(entries) => entries,
        Err(e) => {
            eprintln!("manifes tidak sah: {e}");
            return std::process::ExitCode::FAILURE;
        }
    };
    if let Some(limit) = args.limit {
        entries.truncate(limit);
    }
    let base = manifest_path
        .parent()
        .map(Path::to_path_buf)
        .unwrap_or_else(|| PathBuf::from("."));

    let mut scores = Vec::new();
    for model_path in &args.models {
        let label = Path::new(model_path)
            .file_stem()
            .map(|s| s.to_string_lossy().to_string())
            .unwrap_or_else(|| model_path.clone());
        eprintln!("== {label} ==");

        let engine = match WhisperEngine::load_with_gpu(Path::new(model_path), args.gpu, 0) {
            Ok(engine) => engine,
            Err(e) => {
                eprintln!("  model tidak bisa dimuat: {e}");
                continue;
            }
        };

        let mut clips = Vec::new();
        for (index, entry) in entries.iter().enumerate() {
            let audio = if Path::new(&entry.audio).is_absolute() {
                PathBuf::from(&entry.audio)
            } else {
                base.join(&entry.audio)
            };
            if !audio.exists() {
                eprintln!(
                    "  [{}/{}] {} — tidak ada",
                    index + 1,
                    entries.len(),
                    entry.audio
                );
                continue;
            }

            let started = Instant::now();
            let result = transcribe_file(
                &engine,
                &audio,
                Some(&args.language),
                &GlossaryConfig::default(),
            );
            let elapsed = started.elapsed().as_secs_f64();

            match result {
                Ok(result) => {
                    let hypothesis = result
                        .segments
                        .iter()
                        .filter(|s| !s.is_partial)
                        .map(|s| s.text.trim())
                        .filter(|text| !text.is_empty())
                        .collect::<Vec<_>>()
                        .join(" ");
                    let words = word_errors(&entry.reference, &hypothesis);
                    let chars = char_errors(&entry.reference, &hypothesis);
                    eprintln!(
                        "  [{}/{}] {} — WER {:.1}% CER {:.1}% ({:.2}× RT)",
                        index + 1,
                        entries.len(),
                        entry.audio,
                        words.rate() * 100.0,
                        chars.rate() * 100.0,
                        if elapsed > 0.0 {
                            result.duration_secs / elapsed
                        } else {
                            0.0
                        },
                    );
                    clips.push(ClipScore {
                        clip: entry.audio.clone(),
                        words,
                        chars,
                        audio_secs: result.duration_secs,
                        elapsed_secs: elapsed,
                        hypothesis,
                    });
                }
                Err(e) => {
                    // Counted as a total loss rather than skipped: a model
                    // that cannot decode a clip has not scored 0% on it.
                    eprintln!(
                        "  [{}/{}] {} — gagal: {e}",
                        index + 1,
                        entries.len(),
                        entry.audio
                    );
                    clips.push(ClipScore {
                        clip: entry.audio.clone(),
                        words: word_errors(&entry.reference, ""),
                        chars: char_errors(&entry.reference, ""),
                        audio_secs: 0.0,
                        elapsed_secs: elapsed,
                        hypothesis: String::new(),
                    });
                }
            }
        }

        if clips.is_empty() {
            eprintln!("  tidak ada klip yang terukur");
            continue;
        }
        scores.push(ModelScore {
            model: label,
            clips,
        });
    }

    if scores.is_empty() {
        eprintln!("tidak ada model yang bisa diukur");
        return std::process::ExitCode::FAILURE;
    }

    let table = render_table(&scores);
    println!("{table}");
    if let Some(out) = &args.out {
        if let Err(e) = std::fs::write(out, &table) {
            eprintln!("tidak bisa menulis {out}: {e}");
        } else {
            eprintln!("tabel ditulis ke {out}");
        }
    }
    if args.json {
        match serde_json::to_string_pretty(&scores) {
            Ok(json) => println!("{json}"),
            Err(e) => eprintln!("tidak bisa membuat JSON: {e}"),
        }
    }

    std::process::ExitCode::SUCCESS
}
