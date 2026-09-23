use std::path::PathBuf;

use clap::Parser;
use rust_core::export::{export_segments, ExportFormat};
use rust_core::stt::file::{transcribe_files_batch, BatchFileStatus};
use rust_core::stt::WhisperEngine;

#[derive(Parser, Debug)]
#[command(
    name = "transcribe",
    about = "Batch-transcribe audio files from the command line"
)]
pub struct Args {
    /// Glob pattern for input files, e.g. "*.mp3" or "recordings/**/*.wav"
    #[arg(long)]
    pub batch: String,

    /// Output directory for exported transcripts
    #[arg(long, default_value = "./transkrip")]
    pub output: String,

    /// Path to a GGML/GGUF whisper model
    #[arg(long)]
    pub model: String,

    /// Comma-separated export formats: md,txt,json,srt,vtt,html,docx
    #[arg(long, default_value = "md,txt,json")]
    pub format: String,

    /// Force a language (ISO-639-1) instead of auto-detect
    #[arg(long)]
    pub language: Option<String>,

    /// Enable GPU acceleration (Vulkan/CUDA/Metal, whichever backend the
    /// binary was compiled with). Falls back to CPU if no GPU backend was
    /// compiled in or no compatible device is found at runtime.
    #[arg(long, default_value_t = false)]
    pub gpu: bool,

    /// GPU device index to use when --gpu is set (0 = default/first device)
    #[arg(long, default_value_t = 0)]
    pub gpu_device: i32,
}

pub fn parse_formats(raw: &str) -> Vec<ExportFormat> {
    raw.split(',')
        .filter_map(|s| match s.trim().to_lowercase().as_str() {
            "md" | "markdown" => Some(ExportFormat::Markdown),
            "txt" => Some(ExportFormat::Txt),
            "json" => Some(ExportFormat::Json),
            "srt" => Some(ExportFormat::Srt),
            "vtt" => Some(ExportFormat::Vtt),
            "html" => Some(ExportFormat::Html),
            "docx" => Some(ExportFormat::Docx),
            _ => None,
        })
        .collect()
}

pub fn run(args: Args) -> i32 {
    let files: Vec<PathBuf> = match glob::glob(&args.batch) {
        Ok(paths) => paths.filter_map(Result::ok).collect(),
        Err(e) => {
            eprintln!("invalid glob pattern '{}': {e}", args.batch);
            return 1;
        }
    };

    if files.is_empty() {
        eprintln!("no files matched pattern '{}'", args.batch);
        return 1;
    }

    let engine = match WhisperEngine::load_with_gpu(
        std::path::Path::new(&args.model),
        args.gpu,
        args.gpu_device,
    ) {
        Ok(e) => e,
        Err(e) => {
            eprintln!("failed to load model '{}': {e}", args.model);
            return 1;
        }
    };

    let formats = parse_formats(&args.format);
    if formats.is_empty() {
        eprintln!("no valid export formats in '{}'", args.format);
        return 1;
    }

    let output_dir = PathBuf::from(&args.output);
    let total = files.len();
    let mut failures = 0usize;

    transcribe_files_batch(
        &engine,
        &files,
        args.language.as_deref(),
        |progress| match progress.status {
            BatchFileStatus::Done => {
                println!(
                    "[{}/{}] {} — done",
                    progress.file_index + 1,
                    progress.total_files,
                    progress.filename
                );
                if let Some(result) = progress.result {
                    let title = progress
                        .filename
                        .rsplit_once('.')
                        .map(|(name, _)| name)
                        .unwrap_or(&progress.filename);
                    if let Err(e) = export_segments(&result.segments, &formats, &output_dir, title)
                    {
                        eprintln!("  export failed: {e}");
                    }
                }
            }
            BatchFileStatus::Error => {
                failures += 1;
                eprintln!(
                    "[{}/{}] {} — error: {}",
                    progress.file_index + 1,
                    progress.total_files,
                    progress.filename,
                    progress.error.unwrap_or_default()
                );
            }
            _ => {}
        },
    );

    println!(
        "Done: {}/{total} files transcribed, {failures} failed",
        total - failures
    );
    if failures > 0 {
        1
    } else {
        0
    }
}
