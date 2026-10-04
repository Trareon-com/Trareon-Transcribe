//! Export module — Markdown / TXT / JSON / SRT / VTT / HTML / DOCX / WAV.

use std::fs;
use std::path::{Path, PathBuf};
use std::sync::Arc;

use serde::{Deserialize, Serialize};

use crate::error::TranscribeError;

/// Official "Notulen Rapat" document generation (F2). Kept in its own module
/// because it is a *document*, not a transcript dump: it has a form, two
/// layout variants and its own golden tests.
pub mod notulen;

/// A marker the notulis dropped during the meeting (F9).
///
/// One keystroke during a three-hour rapat is the workflow this replaces:
/// before this existed, flagging "this is the decision" meant writing the
/// wall-clock time on paper.
#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct Bookmark {
    /// Offset into the recording, in seconds.
    pub timestamp: f64,
    /// Optional one-line note. Empty is normal — the timestamp is the point.
    #[serde(default)]
    pub note: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Segment {
    pub source: String,
    pub speaker: String,
    pub text: String,
    pub timestamp: f64,
    pub duration: f64,
    pub language: String,
    pub confidence: f32,
    /// Average log probability per token from Whisper (negative, e.g. -0.5).
    /// Used by confidence.rs to flag low-quality segments.
    pub avg_log_prob: f32,
    pub is_partial: bool,
    pub low_confidence: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WordTimestamp {
    pub word: String,
    pub start: f64,
    pub end: f64,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ExportFormat {
    Markdown,
    Txt,
    Json,
    Srt,
    Vtt,
    Html,
    Docx,
}

#[derive(Debug, Clone, Serialize)]
pub struct ExportedFile {
    pub filename: String,
    pub path: String,
    pub size_bytes: u64,
}

/// Sanitize a user/window-title-derived name into a safe path component:
/// no separators, no traversal, no control characters.
pub fn sanitize_filename(raw: &str) -> String {
    let cleaned: String = raw
        .chars()
        .map(|c| match c {
            '/' | '\\' | ':' | '*' | '?' | '"' | '<' | '>' | '|' => '_',
            c if c.is_control() => '_',
            c => c,
        })
        .collect();
    let trimmed = cleaned.trim().trim_matches('.');
    if trimmed.is_empty() {
        "untitled".to_string()
    } else {
        trimmed.chars().take(120).collect()
    }
}

/// Computes the same per-session subfolder that `export_segments` writes
/// into, from `output_dir` + `title` alone — shared with
/// `export_session_audio` so a transcript export and its raw-audio export
/// always land in the same folder (blueprint §7.2 naming convention) even
/// though they're separate FRB calls made at different times.
#[flutter_rust_bridge::frb(ignore)]
pub fn session_dir_for(output_dir: &Path, title: &str) -> PathBuf {
    let safe_title = sanitize_filename(title);
    // Prepend today's date in YYYYMMDD format per blueprint §5.4, unless the
    // session title already starts with a YYYYMMDD prefix (session titles are
    // generated as "{timestamp}-{name}", so prepending again would produce a
    // doubled prefix like "20260807-20260807-test_speech").
    let has_date_prefix = safe_title
        .get(..8)
        .is_some_and(|head| head.chars().all(|c| c.is_ascii_digit()));
    let date_prefix = chrono::Local::now().format("%Y%m%d").to_string();
    if has_date_prefix {
        output_dir.join(&safe_title)
    } else {
        output_dir.join(format!("{date_prefix}-{safe_title}"))
    }
}

/// One source's captured audio, as a stopped session left it.
#[flutter_rust_bridge::frb(ignore)]
pub enum CapturedTrack<'a> {
    /// Already a finished WAV, streamed during the session. Moved into
    /// place rather than re-encoded.
    File(&'a Path),
    /// Samples from the RAM fallback path, still to be written.
    Samples(&'a [f32]),
}

/// Places the mic/speaker audio of a live session as per-track WAV files
/// (blueprint §7.1: `mic.wav` + `speaker.wav`) in the same session folder
/// `export_segments` uses for this `output_dir`/`title`.
///
/// A [`CapturedTrack::File`] is *moved* (with a copy fallback across
/// filesystems), not re-encoded: it is already the exact bytes
/// [`write_wav`] would produce, and re-reading 700 MB to write it back out
/// would double both the I/O and the peak memory this path exists to
/// avoid.
/// Not FRB-exposed directly (takes `&Path`); see `api::export_session_audio`.
#[flutter_rust_bridge::frb(ignore)]
pub fn export_session_audio(
    mic: Option<CapturedTrack<'_>>,
    speaker: Option<CapturedTrack<'_>>,
    output_dir: &Path,
    title: &str,
) -> Result<Vec<ExportedFile>, TranscribeError> {
    let session_dir = session_dir_for(output_dir, title);
    fs::create_dir_all(&session_dir).map_err(TranscribeError::from)?;

    let mut results = Vec::new();
    for (filename, track) in [("mic.wav", mic), ("speaker.wav", speaker)] {
        let Some(track) = track else { continue };
        let path = session_dir.join(filename);
        match track {
            CapturedTrack::Samples(samples) => write_wav(samples, 16_000, &path)?,
            CapturedTrack::File(source) => move_file(source, &path)?,
        }
        let size_bytes = fs::metadata(&path).map_err(TranscribeError::from)?.len();
        results.push(ExportedFile {
            filename: filename.to_string(),
            path: path.to_string_lossy().to_string(),
            size_bytes,
        });
    }
    Ok(results)
}

/// `rename`, falling back to copy+delete when source and destination are
/// on different filesystems (the recovery directory lives under the OS
/// config dir; the library can be anywhere, including a mounted share).
fn move_file(source: &Path, destination: &Path) -> Result<(), TranscribeError> {
    if fs::rename(source, destination).is_ok() {
        return Ok(());
    }
    fs::copy(source, destination).map_err(TranscribeError::from)?;
    if let Err(e) = fs::remove_file(source) {
        // The audio is safely in the library; a leftover in the recovery
        // directory is cleaned up by the next `list_recoverable_sessions`.
        tracing::warn!(path = %source.display(), %e, "could not remove staged audio");
    }
    Ok(())
}

/// Not FRB-exposed directly (takes `&Path`); see `api::export_session`.
#[flutter_rust_bridge::frb(ignore)]
pub fn export_segments(
    segments: &[Segment],
    formats: &[ExportFormat],
    output_dir: &Path,
    title: &str,
) -> Result<Vec<ExportedFile>, TranscribeError> {
    export_segments_with_summary(segments, formats, output_dir, title, "")
}

/// As [`export_segments`], but prepends `summary` (Markdown, as produced by
/// [`crate::summary`]) to the document formats.
///
/// Meetily-parity: an exported meeting is expected to lead with its summary —
/// the transcript is the appendix. Subtitle formats (SRT/VTT) and the
/// machine-readable JSON are untouched, since a prose block would corrupt
/// them.
#[flutter_rust_bridge::frb(ignore)]
pub fn export_segments_with_summary(
    segments: &[Segment],
    formats: &[ExportFormat],
    output_dir: &Path,
    title: &str,
    summary: &str,
) -> Result<Vec<ExportedFile>, TranscribeError> {
    export_segments_full(segments, formats, output_dir, title, summary, &[])
}

/// As [`export_segments_with_summary`], plus the meeting's bookmarks as a
/// "Poin Penting" section ahead of the transcript.
///
/// Bookmarks are the notulis' own annotations, so leaving them out of the
/// export would mean the one thing they explicitly marked is the one thing the
/// document does not mention. Subtitle and JSON formats are untouched, for the
/// same reason the summary skips them.
#[flutter_rust_bridge::frb(ignore)]
pub fn export_segments_full(
    segments: &[Segment],
    formats: &[ExportFormat],
    output_dir: &Path,
    title: &str,
    summary: &str,
    bookmarks: &[Bookmark],
) -> Result<Vec<ExportedFile>, TranscribeError> {
    let summary = Arc::<str>::from(summary.trim());
    let bookmarks: Arc<[Bookmark]> = Arc::from(bookmarks.to_vec());
    let safe_title = sanitize_filename(title);
    let session_dir = session_dir_for(output_dir, title);
    fs::create_dir_all(&session_dir).map_err(TranscribeError::from)?;

    // PARALLEL EXPORT: spawn a thread per format so that e.g. Markdown
    // generation doesn't block DOCX (which involves expensive ZIP packing)
    // or JSON serialisation. Each format writes to its own file — there is
    // no shared mutable state.
    let segments = Arc::from(segments.to_vec());
    let mut handles = Vec::with_capacity(formats.len());

    for format in formats {
        let segments = Arc::clone(&segments);
        let summary = Arc::clone(&summary);
        let bookmarks = Arc::clone(&bookmarks);
        let session_dir = session_dir.clone();
        let safe_title = safe_title.clone();
        let title = title.to_string();
        let format = *format;

        handles.push(std::thread::spawn(move || {
            let (filename, content): (String, Vec<u8>) = match format {
                ExportFormat::Markdown => (
                    format!("{safe_title}.md"),
                    to_markdown(&segments, &title, &summary, &bookmarks).into_bytes(),
                ),
                ExportFormat::Txt => (
                    format!("{safe_title}.txt"),
                    to_txt(&segments, &summary, &bookmarks).into_bytes(),
                ),
                ExportFormat::Json => (
                    format!("{safe_title}.json"),
                    serde_json::to_string_pretty(&*segments)
                        .map_err(|e| TranscribeError::Export(e.to_string()))?
                        .into_bytes(),
                ),
                ExportFormat::Srt => (format!("{safe_title}.srt"), to_srt(&*segments).into_bytes()),
                ExportFormat::Vtt => (format!("{safe_title}.vtt"), to_vtt(&*segments).into_bytes()),
                ExportFormat::Html => (
                    format!("{safe_title}.html"),
                    to_html(&segments, &title, &summary, &bookmarks).into_bytes(),
                ),
                ExportFormat::Docx => (
                    format!("{safe_title}.docx"),
                    to_docx_bytes(&segments, &title, &summary, &bookmarks)?,
                ),
            };

            let path: PathBuf = session_dir.join(&filename);
            atomic_write(&path, &content)?;

            let size_bytes = fs::metadata(&path).map_err(TranscribeError::from)?.len();
            Ok::<ExportedFile, TranscribeError>(ExportedFile {
                filename,
                path: path.to_string_lossy().to_string(),
                size_bytes,
            })
        }));
    }

    // Join all threads and collect results / errors.
    let mut results = Vec::with_capacity(formats.len());
    for handle in handles {
        match handle.join() {
            Ok(Ok(file)) => results.push(file),
            Ok(Err(e)) => return Err(e),
            Err(e) => {
                return Err(TranscribeError::Export(format!(
                    "export thread panicked: {:?}",
                    e
                )));
            }
        }
    }

    // Trigger on_stop hook after all exports complete.
    run_on_stop_hook(&session_dir);

    Ok(results)
}

/// Atomic write: write to temp file then rename. Falls back to
/// copy+remove on cross-device rename (e.g. /tmp on a different
/// filesystem than the target).
#[flutter_rust_bridge::frb(ignore)]
pub fn atomic_write(path: &Path, content: &[u8]) -> Result<(), TranscribeError> {
    // Unique temp name per target file — `with_extension("tmp")` would
    // collide across formats (Rapat Q3.md / .txt / .json → same .tmp),
    // causing parallel export threads to overwrite each other.
    let temp_path = PathBuf::from(format!("{}.tmp", path.display()));
    fs::write(&temp_path, content).map_err(TranscribeError::from)?;
    match fs::rename(&temp_path, path) {
        Ok(()) => Ok(()),
        Err(_) => {
            fs::copy(&temp_path, path).map_err(TranscribeError::from)?;
            let _ = fs::remove_file(&temp_path);
            Ok(())
        }
    }
}

/// Sanitize an on-stop hook command path to prevent shell injection.
/// Allows only alphanumeric, dash, underscore, dot, slash, and space.
fn sanitize_hook_cmd(hook: &str) -> String {
    hook.chars()
        .map(|c| {
            if c.is_alphanumeric() || c == '-' || c == '_' || c == '.' || c == '/' || c == ' ' {
                c
            } else {
                '_'
            }
        })
        .collect()
}

/// Execute the on_stop hook (if configured) after export completes.
fn run_on_stop_hook(session_dir: &Path) {
    if let Some(hook) = crate::settings::AppConfig::on_stop_hook() {
        let sanitized = sanitize_hook_cmd(&hook);
        if let Err(e) = std::process::Command::new("sh")
            .arg("-c")
            .arg(format!("{} \"$1\"", sanitized))
            .arg(session_dir.to_string_lossy().to_string())
            .spawn()
        {
            tracing::error!(%e, "on_stop_hook failed to spawn");
        }
    }
}

/// Write mono f32 PCM (16kHz) as a 16-bit WAV file.
#[flutter_rust_bridge::frb(ignore)]
pub fn write_wav(samples: &[f32], sample_rate: u32, path: &Path) -> Result<(), TranscribeError> {
    let spec = hound::WavSpec {
        channels: 1,
        sample_rate,
        bits_per_sample: 16,
        sample_format: hound::SampleFormat::Int,
    };
    let mut writer =
        hound::WavWriter::create(path, spec).map_err(|e| TranscribeError::Export(e.to_string()))?;
    for &s in samples {
        let clamped = (s.clamp(-1.0, 1.0) * i16::MAX as f32) as i16;
        writer
            .write_sample(clamped)
            .map_err(|e| TranscribeError::Export(e.to_string()))?;
    }
    writer
        .finalize()
        .map_err(|e| TranscribeError::Export(e.to_string()))
}

/// `"[mm:ss] note"` per bookmark, or an empty vector.
fn bookmark_lines(bookmarks: &[Bookmark]) -> Vec<String> {
    notulen::poin_penting_from_bookmarks(bookmarks)
}

fn to_markdown(segments: &[Segment], title: &str, summary: &str, bookmarks: &[Bookmark]) -> String {
    let mut out = format!("# {title}\n\n");
    if !summary.trim().is_empty() {
        out.push_str("## Ringkasan\n\n");
        out.push_str(summary.trim());
        out.push_str("\n\n");
    }
    let marks = bookmark_lines(bookmarks);
    if !marks.is_empty() {
        out.push_str("## Poin Penting\n\n");
        for line in &marks {
            out.push_str(&format!("- {line}\n"));
        }
        out.push('\n');
    }
    if !summary.trim().is_empty() || !marks.is_empty() {
        out.push_str("## Transkrip\n\n");
    }
    for seg in segments {
        out.push_str(&format!(
            "**[{}]** `{}` — {}\n\n",
            fmt_timestamp(seg.timestamp),
            seg.speaker,
            seg.text
        ));
    }
    out
}

fn to_txt(segments: &[Segment], summary: &str, bookmarks: &[Bookmark]) -> String {
    let transcript = segments
        .iter()
        .map(|s| s.text.clone())
        .collect::<Vec<_>>()
        .join("\n");
    let marks = bookmark_lines(bookmarks);
    if summary.trim().is_empty() && marks.is_empty() {
        return transcript;
    }
    let mut out = String::new();
    if !summary.trim().is_empty() {
        out.push_str("RINGKASAN\n=========\n");
        out.push_str(summary.trim());
        out.push_str("\n\n");
    }
    if !marks.is_empty() {
        out.push_str("POIN PENTING\n============\n");
        out.push_str(&marks.join("\n"));
        out.push_str("\n\n");
    }
    out.push_str("TRANSKRIP\n=========\n");
    out.push_str(&transcript);
    out
}

fn to_srt(segments: &[Segment]) -> String {
    let mut out = String::new();
    for (i, seg) in segments.iter().enumerate() {
        out.push_str(&format!(
            "{}\n{} --> {}\n{}: {}\n\n",
            i + 1,
            fmt_srt_time(seg.timestamp),
            fmt_srt_time(seg.timestamp + seg.duration),
            seg.speaker,
            seg.text
        ));
    }
    out
}

fn to_vtt(segments: &[Segment]) -> String {
    let mut out = String::from("WEBVTT\n\n");
    for seg in segments {
        out.push_str(&format!(
            "{} --> {}\n{}: {}\n\n",
            fmt_vtt_time(seg.timestamp),
            fmt_vtt_time(seg.timestamp + seg.duration),
            seg.speaker,
            seg.text
        ));
    }
    out
}

fn to_html(segments: &[Segment], title: &str, summary: &str, bookmarks: &[Bookmark]) -> String {
    let mut body = String::new();
    if !summary.trim().is_empty() {
        body.push_str("<h2>Ringkasan</h2>\n<pre>");
        body.push_str(&html_escape(summary.trim()));
        body.push_str("</pre>\n");
    }
    let marks = bookmark_lines(bookmarks);
    if !marks.is_empty() {
        body.push_str("<h2>Poin Penting</h2>\n<ul>\n");
        for line in &marks {
            body.push_str(&format!("<li>{}</li>\n", html_escape(line)));
        }
        body.push_str("</ul>\n");
    }
    if !summary.trim().is_empty() || !marks.is_empty() {
        body.push_str("<h2>Transkrip</h2>\n");
    }
    for seg in segments {
        body.push_str(&format!(
            "<p><strong>[{}] {}</strong> — {}</p>\n",
            fmt_timestamp(seg.timestamp),
            html_escape(&seg.speaker),
            html_escape(&seg.text)
        ));
    }
    format!(
        "<!DOCTYPE html>\n<html lang=\"id\"><head><meta charset=\"utf-8\"><title>{}</title></head>\n<body>\n<h1>{}</h1>\n{}</body></html>\n",
        html_escape(title),
        html_escape(title),
        body
    )
}

fn html_escape(raw: &str) -> String {
    raw.replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
        .replace('"', "&quot;")
}

fn to_docx_bytes(
    segments: &[Segment],
    title: &str,
    summary: &str,
    bookmarks: &[Bookmark],
) -> Result<Vec<u8>, TranscribeError> {
    use docx_rs::{Docx, Paragraph, Run};

    let mut docx = Docx::new()
        .add_paragraph(Paragraph::new().add_run(Run::new().add_text(title).bold().size(32)));

    if !summary.trim().is_empty() {
        docx = docx.add_paragraph(
            Paragraph::new().add_run(Run::new().add_text("Ringkasan").bold().size(26)),
        );
        for line in summary.trim().lines() {
            docx = docx.add_paragraph(Paragraph::new().add_run(Run::new().add_text(line)));
        }
    }

    let marks = bookmark_lines(bookmarks);
    if !marks.is_empty() {
        docx = docx.add_paragraph(
            Paragraph::new().add_run(Run::new().add_text("Poin Penting").bold().size(26)),
        );
        for line in &marks {
            docx = docx
                .add_paragraph(Paragraph::new().add_run(Run::new().add_text(format!("• {line}"))));
        }
    }

    if !summary.trim().is_empty() || !marks.is_empty() {
        docx = docx.add_paragraph(
            Paragraph::new().add_run(Run::new().add_text("Transkrip").bold().size(26)),
        );
    }

    for seg in segments {
        let line = format!(
            "[{}] {}: {}",
            fmt_timestamp(seg.timestamp),
            seg.speaker,
            seg.text
        );
        docx = docx.add_paragraph(Paragraph::new().add_run(Run::new().add_text(line)));
    }

    let mut cursor = std::io::Cursor::new(Vec::new());
    docx.build()
        .pack(&mut cursor)
        .map_err(|e| TranscribeError::Export(format!("docx build failed: {e}")))?;
    Ok(cursor.into_inner())
}

pub(crate) fn fmt_timestamp(secs: f64) -> String {
    let m = (secs / 60.0) as u64;
    let s = (secs % 60.0) as u64;
    format!("{m:02}:{s:02}")
}

fn fmt_srt_time(secs: f64) -> String {
    let ms = ((secs.fract()) * 1000.0).round() as u64;
    let total = secs as u64;
    format!(
        "{:02}:{:02}:{:02},{:03}",
        total / 3600,
        (total % 3600) / 60,
        total % 60,
        ms
    )
}

fn fmt_vtt_time(secs: f64) -> String {
    let ms = ((secs.fract()) * 1000.0).round() as u64;
    let total = secs as u64;
    format!(
        "{:02}:{:02}:{:02}.{:03}",
        total / 3600,
        (total % 3600) / 60,
        total % 60,
        ms
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample_segments() -> Vec<Segment> {
        vec![Segment {
            source: "mic".into(),
            speaker: "MIC".into(),
            text: "halo dunia".into(),
            timestamp: 1.5,
            duration: 2.0,
            language: "id".into(),
            confidence: 0.9,
            avg_log_prob: -0.3,
            is_partial: false,
            low_confidence: false,
        }]
    }

    #[test]
    fn sanitize_removes_path_separators() {
        let sanitized = sanitize_filename("../../etc/passwd");
        assert!(!sanitized.contains('/'));
        assert!(!sanitized.contains('\\'));
        assert_eq!(sanitize_filename("rapat: q3\\review"), "rapat_ q3_review");
    }

    #[test]
    fn sanitize_empty_falls_back() {
        assert_eq!(sanitize_filename("...."), "untitled");
        assert_eq!(sanitize_filename(""), "untitled");
    }

    #[test]
    fn export_all_formats_writes_files() {
        let dir =
            std::env::temp_dir().join(format!("transcribe_export_test_{}", uuid::Uuid::new_v4()));
        let segments = sample_segments();
        let formats = [
            ExportFormat::Markdown,
            ExportFormat::Txt,
            ExportFormat::Json,
            ExportFormat::Srt,
            ExportFormat::Vtt,
            ExportFormat::Html,
            ExportFormat::Docx,
        ];
        let files = export_segments(&segments, &formats, &dir, "Rapat Q3").unwrap();
        assert_eq!(files.len(), 7);
        for f in &files {
            assert!(Path::new(&f.path).exists());
            assert!(f.size_bytes > 0);
        }
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn export_title_with_date_prefix_does_not_double_prefix() {
        let dir =
            std::env::temp_dir().join(format!("transcribe_export_date_{}", uuid::Uuid::new_v4()));
        let segments = sample_segments();
        let files = export_segments(
            &segments,
            &[ExportFormat::Txt],
            &dir,
            "20260807-test_speech",
        )
        .unwrap();
        // Session titles already carry a YYYYMMDD prefix — the export folder
        // must NOT become "20260807-20260807-test_speech".
        let written = Path::new(&files[0].path)
            .parent()
            .unwrap()
            .file_name()
            .unwrap()
            .to_string_lossy()
            .to_string();
        assert_eq!(written, "20260807-test_speech");
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn html_export_escapes_and_contains_text() {
        let segments = vec![Segment {
            source: "mic".into(),
            speaker: "MIC".into(),
            text: "<script>alert(1)</script> & \"quoted\"".into(),
            timestamp: 0.0,
            duration: 1.0,
            language: "id".into(),
            confidence: 0.9,
            avg_log_prob: -0.3,
            is_partial: false,
            low_confidence: false,
        }];
        let html = to_html(&segments, "Rapat <Q3>", "", &[]);
        assert!(!html.contains("<script>alert"));
        assert!(html.contains("&lt;script&gt;"));
        assert!(html.contains("&amp;"));
        assert!(html.contains("Rapat &lt;Q3&gt;"));
    }

    #[test]
    fn summary_leads_the_document_formats() {
        let segments = sample_segments();
        let summary = "## Keputusan\n- Pakai Rust";

        let md = to_markdown(&segments, "Rapat Q3", summary, &[]);
        assert!(md.contains("## Ringkasan"));
        assert!(md.contains("- Pakai Rust"));
        assert!(
            md.find("## Ringkasan") < md.find("## Transkrip"),
            "summary must come before the transcript"
        );

        let txt = to_txt(&segments, summary, &[]);
        assert!(txt.starts_with("RINGKASAN"));
        assert!(txt.contains("halo dunia"));

        let html = to_html(&segments, "Rapat Q3", summary, &[]);
        assert!(html.contains("<h2>Ringkasan</h2>"));
        assert!(html.contains("<h2>Transkrip</h2>"));
    }

    #[test]
    fn summary_is_html_escaped() {
        let segments = sample_segments();
        let html = to_html(&segments, "Rapat", "<script>alert(1)</script>", &[]);
        assert!(!html.contains("<script>alert"));
        assert!(html.contains("&lt;script&gt;"));
    }

    #[test]
    fn empty_summary_leaves_every_format_byte_identical() {
        // An un-summarised session must export exactly as it did before the
        // summary feature existed — no stray headings, no blank sections.
        let segments = sample_segments();
        for blank in ["", "   ", "\n\t "] {
            assert_eq!(
                to_markdown(&segments, "Rapat", blank, &[]),
                to_markdown(&segments, "Rapat", "", &[])
            );
            assert!(!to_markdown(&segments, "Rapat", blank, &[]).contains("Ringkasan"));
            assert!(!to_txt(&segments, blank, &[]).contains("RINGKASAN"));
            assert!(!to_html(&segments, "Rapat", blank, &[]).contains("Ringkasan"));
        }
    }

    #[test]
    fn subtitle_and_json_formats_never_carry_the_summary() {
        // Prose in an SRT cue or a JSON segment array corrupts the file for
        // every downstream consumer.
        let dir =
            std::env::temp_dir().join(format!("transcribe_summary_fmt_{}", uuid::Uuid::new_v4()));
        let segments = sample_segments();
        let files = export_segments_with_summary(
            &segments,
            &[ExportFormat::Srt, ExportFormat::Vtt, ExportFormat::Json],
            &dir,
            "Rapat",
            "RAHASIA-RINGKASAN",
        )
        .unwrap();
        assert_eq!(files.len(), 3);
        for file in &files {
            let content = fs::read_to_string(&file.path).unwrap();
            assert!(
                !content.contains("RAHASIA-RINGKASAN"),
                "{} leaked the summary",
                file.filename
            );
        }
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn docx_export_produces_valid_zip() {
        let segments = sample_segments();
        let bytes = to_docx_bytes(&segments, "Rapat Q3", "", &[]).unwrap();
        // DOCX is a ZIP container; the local file header signature is a
        // cheap, dependency-free sanity check that we produced real output.
        assert!(bytes.len() > 4);
        assert_eq!(&bytes[0..2], b"PK");
    }

    #[test]
    fn export_path_traversal_title_is_contained() {
        let dir =
            std::env::temp_dir().join(format!("transcribe_export_test_{}", uuid::Uuid::new_v4()));
        let segments = sample_segments();
        let files = export_segments(&segments, &[ExportFormat::Txt], &dir, "../../evil").unwrap();
        for f in &files {
            assert!(Path::new(&f.path).starts_with(&dir));
        }
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn wav_roundtrip_readable() {
        let path =
            std::env::temp_dir().join(format!("transcribe_wav_test_{}.wav", uuid::Uuid::new_v4()));
        let samples = vec![0.0f32, 0.5, -0.5, 1.0, -1.0];
        write_wav(&samples, 16_000, &path).unwrap();
        let reader = hound::WavReader::open(&path).unwrap();
        assert_eq!(reader.spec().sample_rate, 16_000);
        assert_eq!(reader.len(), samples.len() as u32);
        let _ = fs::remove_file(&path);
    }

    #[test]
    fn export_session_audio_writes_per_track_wav_in_same_dir_as_transcript() {
        let dir = std::env::temp_dir().join(format!(
            "transcribe_export_audio_test_{}",
            uuid::Uuid::new_v4()
        ));
        let segments = sample_segments();
        // Transcript export first (as the app does on stop()), audio second
        // — both must resolve to the same session folder.
        let transcript_files =
            export_segments(&segments, &[ExportFormat::Txt], &dir, "Rapat Q3").unwrap();
        let mic = vec![0.1f32, 0.2, -0.2];
        let speaker = vec![0.3f32, -0.3];
        let audio_files = export_session_audio(
            Some(CapturedTrack::Samples(&mic)),
            Some(CapturedTrack::Samples(&speaker)),
            &dir,
            "Rapat Q3",
        )
        .unwrap();

        let transcript_dir = Path::new(&transcript_files[0].path).parent().unwrap();
        assert_eq!(audio_files.len(), 2);
        for f in &audio_files {
            assert_eq!(Path::new(&f.path).parent().unwrap(), transcript_dir);
        }
        assert!(audio_files.iter().any(|f| f.filename == "mic.wav"));
        assert!(audio_files.iter().any(|f| f.filename == "speaker.wav"));

        let reader = hound::WavReader::open(transcript_dir.join("mic.wav")).unwrap();
        assert_eq!(reader.len(), mic.len() as u32);

        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn export_session_audio_skips_missing_tracks() {
        let dir = std::env::temp_dir().join(format!(
            "transcribe_export_audio_skip_test_{}",
            uuid::Uuid::new_v4()
        ));
        let mic = vec![0.1f32, 0.2];
        // No speaker track (e.g. mic-only session) — must not write a
        // speaker.wav placeholder.
        let files =
            export_session_audio(Some(CapturedTrack::Samples(&mic)), None, &dir, "Rapat Q3")
                .unwrap();
        assert_eq!(files.len(), 1);
        assert_eq!(files[0].filename, "mic.wav");
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn srt_time_format() {
        assert_eq!(fmt_srt_time(3661.5), "01:01:01,500");
    }

    #[test]
    fn vtt_time_format() {
        assert_eq!(fmt_vtt_time(65.25), "00:01:05.250");
    }
}
