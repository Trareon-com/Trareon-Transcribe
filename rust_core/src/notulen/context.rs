//! Local document context for notulen generation (Sprint 8). Reads a
//! user-picked .txt/.md/.pdf file into text for the prompt — never
//! written anywhere, never sent anywhere but the configured LLM endpoint
//! the transcript already goes to.

use std::path::Path;

use crate::error::TranscribeError;

/// Keeps the context block from crowding out the transcript in the prompt
/// budget — same elision strategy as `summary::truncate_transcript`.
pub const MAX_CONTEXT_CHARS: usize = 6_000;

#[flutter_rust_bridge::frb(ignore)]
pub fn extract_document_text(path: &Path) -> Result<String, TranscribeError> {
    let ext = path
        .extension()
        .and_then(|e| e.to_str())
        .unwrap_or_default()
        .to_lowercase();
    let raw = match ext.as_str() {
        "txt" | "md" | "markdown" => std::fs::read_to_string(path)
            .map_err(|e| TranscribeError::Io(format!("Tidak bisa membaca berkas: {e}")))?,
        "pdf" => pdf_extract::extract_text(path)
            .map_err(|e| TranscribeError::Io(format!("Tidak bisa membaca PDF: {e}")))?,
        other => {
            return Err(TranscribeError::Io(format!(
                "Jenis berkas \".{other}\" belum didukung sebagai konteks. \
                 Gunakan .txt, .md, atau .pdf."
            )));
        }
    };
    Ok(truncate_keep_ends(raw.trim(), MAX_CONTEXT_CHARS))
}

fn truncate_keep_ends(text: &str, max_chars: usize) -> String {
    if text.chars().count() <= max_chars {
        return text.to_string();
    }
    let chars: Vec<char> = text.chars().collect();
    let head = max_chars * 6 / 10;
    let tail = max_chars - head;
    let start: String = chars[..head].iter().collect();
    let end: String = chars[chars.len() - tail..].iter().collect();
    format!("{start}\n\n[…dipotong…]\n\n{end}")
}

#[cfg(test)]
mod tests {
    use super::*;

    fn temp_dir() -> std::path::PathBuf {
        let dir = std::env::temp_dir().join(format!("trareon_ctx_{}", uuid::Uuid::new_v4()));
        std::fs::create_dir_all(&dir).unwrap();
        dir
    }

    #[test]
    fn reads_txt_verbatim() {
        let dir = temp_dir();
        let path = dir.join("catatan.txt");
        std::fs::write(&path, "Isi catatan rapat.").unwrap();
        assert_eq!(extract_document_text(&path).unwrap(), "Isi catatan rapat.");
    }

    #[test]
    fn reads_markdown_verbatim() {
        let dir = temp_dir();
        let path = dir.join("agenda.md");
        std::fs::write(&path, "# Agenda\n\n- Satu\n- Dua").unwrap();
        assert_eq!(
            extract_document_text(&path).unwrap(),
            "# Agenda\n\n- Satu\n- Dua"
        );
    }

    #[test]
    fn unsupported_extension_errors_in_indonesian() {
        let dir = temp_dir();
        let path = dir.join("rekaman.wav");
        std::fs::write(&path, b"not really audio").unwrap();
        let err = extract_document_text(&path).unwrap_err();
        assert!(format!("{err}").contains("didukung"));
    }

    #[test]
    fn missing_file_errors_in_indonesian() {
        let err = extract_document_text(Path::new("/tidak/ada/berkas.txt")).unwrap_err();
        assert!(!format!("{err}").is_empty());
    }

    #[test]
    fn long_text_is_truncated_keeping_both_ends() {
        let dir = temp_dir();
        let path = dir.join("panjang.txt");
        let huge = "A".repeat(MAX_CONTEXT_CHARS * 2);
        std::fs::write(&path, &huge).unwrap();
        let out = extract_document_text(&path).unwrap();
        assert!(out.len() <= MAX_CONTEXT_CHARS + 200);
    }

    #[test]
    fn reads_a_real_pdf_round_trip() {
        use crate::export::Segment;

        let segment = Segment {
            source: "mic".into(),
            speaker: "Budi".into(),
            text: "Kalimat unik penanda ekstraksi PDF.".into(),
            timestamp: 0.0,
            duration: 2.0,
            language: "id".into(),
            confidence: 0.9,
            avg_log_prob: -0.3,
            is_partial: false,
            low_confidence: false,
            words: Vec::new(),
        };
        let bytes = crate::export::pdf::to_pdf_bytes(&[segment], "Dokumen Uji", "", &[]).unwrap();
        let dir = temp_dir();
        let path = dir.join("dokumen.pdf");
        std::fs::write(&path, bytes).unwrap();
        let text = extract_document_text(&path).unwrap();
        assert!(
            text.contains("Kalimat unik penanda ekstraksi PDF."),
            "got: {text}"
        );
    }
}
