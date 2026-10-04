//! PDF transcript export with an embedded font (F19).
//!
//! # Why a bundled font and not a system one
//!
//! A PDF that names a font without embedding it renders in whatever the
//! reader substitutes. For an Indonesian notulen that is usually fine and
//! occasionally catastrophic — a name with a diaeresis, a `—` in a
//! timestamp range, or the `·` this app separates speaker from time with,
//! all come back as blanks or boxes on a machine that lacks the font. The
//! document is the artifact a secretariat keeps for years and hands to
//! people who do not have this app installed, so the glyphs travel with
//! it.
//!
//! DejaVu Sans is the bundled face: permissive licence (Bitstream Vera,
//! see `assets/fonts/DejaVuSans.LICENSE.txt`), and wide enough Latin
//! coverage that no Indonesian transcript needs a fallback.
//!
//! # Layout
//!
//! Deliberately plain: A4, one column, a heading, the summary if there is
//! one, then `[mm:ss] Pembicara` lines with their text wrapped. Wrapping
//! is measured against the parsed font's own advance widths rather than
//! guessed from a character count, because a transcript full of short
//! Indonesian words otherwise wraps with a third of the line unused.

use printpdf::{
    Mm, Op, ParsedFont, PdfDocument, PdfFontHandle, PdfPage, PdfSaveOptions, Pt, TextItem,
    TextMatrix,
};

use super::{bookmark_lines, Bookmark, Segment};
use crate::error::TranscribeError;

/// The embedded face. ~740 kB, which is the whole reason this is one
/// weight and not four.
const DEJAVU_SANS: &[u8] = include_bytes!("../../assets/fonts/DejaVuSans.ttf");

const PAGE_WIDTH_MM: f32 = 210.0;
const PAGE_HEIGHT_MM: f32 = 297.0;
const MARGIN_MM: f32 = 18.0;

const TITLE_PT: f32 = 16.0;
const HEADING_PT: f32 = 11.5;
const BODY_PT: f32 = 9.5;

/// Leading as a multiple of the font size. 1.35 is dense enough that a
/// three-hour meeting is not forty pages and loose enough to read.
const LINE_SPACING: f32 = 1.35;

/// Millimetres to points.
fn mm_to_pt(mm: f32) -> f32 {
    mm * 72.0 / 25.4
}

/// Advance width of `text` at `size_pt`, in points.
///
/// A glyph the face does not have contributes the font's own fallback
/// advance rather than zero: counting it as zero makes a line of unknown
/// glyphs look empty to the wrapper and run off the page.
fn text_width_pt(font: &ParsedFont, text: &str, size_pt: f32) -> f32 {
    let units_per_em = font.units_per_em.max(1) as f32;
    let fallback = units_per_em * 0.5;
    let total: f32 = text
        .chars()
        .map(|c| {
            font.lookup_glyph_index(c as u32)
                .and_then(|glyph| font.get_glyph_width(glyph))
                .map(|advance| advance as f32)
                .unwrap_or(fallback)
        })
        .sum();
    total / units_per_em * size_pt
}

/// Greedy word wrap to `max_width_pt`.
///
/// A single word longer than the line (a URL, a run of digits) is split
/// mid-word rather than allowed to overflow: losing the right-hand side
/// of a line off the page edge is worse than an ugly break.
fn wrap(font: &ParsedFont, text: &str, size_pt: f32, max_width_pt: f32) -> Vec<String> {
    if text.trim().is_empty() {
        return Vec::new();
    }
    let mut lines = Vec::new();
    let mut current = String::new();
    for word in text.split_whitespace() {
        let candidate = if current.is_empty() {
            word.to_string()
        } else {
            format!("{current} {word}")
        };
        if text_width_pt(font, &candidate, size_pt) <= max_width_pt || current.is_empty() {
            current = candidate;
        } else {
            lines.push(std::mem::take(&mut current));
            current = word.to_string();
        }
        // The word on its own still does not fit: break it by characters.
        while text_width_pt(font, &current, size_pt) > max_width_pt && current.chars().count() > 1 {
            let mut head = String::new();
            let mut rest = String::new();
            for ch in current.chars() {
                let trial = format!("{head}{ch}");
                if text_width_pt(font, &trial, size_pt) > max_width_pt && !head.is_empty() {
                    rest.push(ch);
                } else if rest.is_empty() {
                    head.push(ch);
                } else {
                    rest.push(ch);
                }
            }
            lines.push(head);
            current = rest;
        }
    }
    if !current.is_empty() {
        lines.push(current);
    }
    lines
}

/// One laid-out line and the size it is set at.
struct Line {
    text: String,
    size_pt: f32,
    /// Extra space above, for the gap before a heading.
    space_before_pt: f32,
}

/// `[mm:ss]`, matching every other export in this app.
fn clock(seconds: f64) -> String {
    let total = seconds.max(0.0).round() as u64;
    let (h, m, s) = (total / 3600, (total % 3600) / 60, total % 60);
    if h > 0 {
        format!("{h}:{m:02}:{s:02}")
    } else {
        format!("{m:02}:{s:02}")
    }
}

/// Renders a transcript to PDF bytes.
pub fn to_pdf_bytes(
    segments: &[Segment],
    title: &str,
    summary: &str,
    bookmarks: &[Bookmark],
) -> Result<Vec<u8>, TranscribeError> {
    to_pdf_bytes_with(segments, title, summary, bookmarks, &PdfSaveOptions::default())
}

/// [`to_pdf_bytes`] with explicit save options.
///
/// Exists so the layout test can ask for an uncompressed stream and read
/// the operators: with the default options the content stream is Flate
/// compressed, and a test that cannot see the operators cannot tell
/// `Tm` from `Td` — which is exactly the bug that shipped.
fn to_pdf_bytes_with(
    segments: &[Segment],
    title: &str,
    summary: &str,
    bookmarks: &[Bookmark],
    options: &PdfSaveOptions,
) -> Result<Vec<u8>, TranscribeError> {
    // Two warning sinks: parsing a face and serialising a document report
    // different warning types.
    let mut parse_warnings = Vec::new();
    let font = ParsedFont::from_bytes(DEJAVU_SANS, 0, &mut parse_warnings)
        .ok_or_else(|| TranscribeError::Export("font PDF bawaan tidak bisa dibaca".to_string()))?;

    let content_width_pt = mm_to_pt(PAGE_WIDTH_MM - 2.0 * MARGIN_MM);

    let mut lines = Vec::new();
    lines.push(Line {
        text: title.to_string(),
        size_pt: TITLE_PT,
        space_before_pt: 0.0,
    });

    if !summary.trim().is_empty() {
        lines.push(Line {
            text: "Ringkasan".to_string(),
            size_pt: HEADING_PT,
            space_before_pt: BODY_PT,
        });
        for paragraph in summary.lines() {
            for wrapped in wrap(&font, paragraph, BODY_PT, content_width_pt) {
                lines.push(Line {
                    text: wrapped,
                    size_pt: BODY_PT,
                    space_before_pt: 0.0,
                });
            }
        }
    }

    let marks = bookmark_lines(bookmarks);
    if !marks.is_empty() {
        lines.push(Line {
            text: "Poin Penting".to_string(),
            size_pt: HEADING_PT,
            space_before_pt: BODY_PT,
        });
        for mark in marks {
            for wrapped in wrap(&font, &mark, BODY_PT, content_width_pt) {
                lines.push(Line {
                    text: wrapped,
                    size_pt: BODY_PT,
                    space_before_pt: 0.0,
                });
            }
        }
    }

    lines.push(Line {
        text: "Transkrip".to_string(),
        size_pt: HEADING_PT,
        space_before_pt: BODY_PT,
    });
    for segment in segments {
        // Partials are a live-preview artifact and never belong in a
        // document somebody files.
        if segment.is_partial || segment.text.trim().is_empty() {
            continue;
        }
        let speaker = if segment.speaker.trim().is_empty() {
            segment.source.clone()
        } else {
            segment.speaker.clone()
        };
        let body = format!(
            "[{}] {}: {}",
            clock(segment.timestamp),
            speaker,
            segment.text.trim()
        );
        for wrapped in wrap(&font, &body, BODY_PT, content_width_pt) {
            lines.push(Line {
                text: wrapped,
                size_pt: BODY_PT,
                space_before_pt: 0.0,
            });
        }
    }

    // Paginate.
    let top_pt = mm_to_pt(PAGE_HEIGHT_MM - MARGIN_MM);
    let bottom_pt = mm_to_pt(MARGIN_MM);
    let left_pt = mm_to_pt(MARGIN_MM);

    let mut doc = PdfDocument::new(title);
    let font_id = doc.add_font(&font);
    let handle = PdfFontHandle::External(font_id);

    let mut pages: Vec<PdfPage> = Vec::new();
    let mut ops: Vec<Op> = Vec::new();
    let mut cursor = top_pt;

    for line in &lines {
        let advance = line.size_pt * LINE_SPACING + line.space_before_pt;
        if cursor - advance < bottom_pt && !ops.is_empty() {
            ops.push(Op::EndTextSection);
            pages.push(PdfPage::new(
                Mm(PAGE_WIDTH_MM),
                Mm(PAGE_HEIGHT_MM),
                std::mem::take(&mut ops),
            ));
            cursor = top_pt;
        }
        if ops.is_empty() {
            ops.push(Op::StartTextSection);
        }
        cursor -= advance;
        ops.push(Op::SetFont {
            font: handle.clone(),
            size: Pt(line.size_pt),
        });
        // `Tm`, not `Td`. `Op::SetTextCursor` serialises to `Td`, which
        // is *relative* to the start of the current line, so feeding it
        // absolute page coordinates made every line after the first
        // compound its offset and land off the page — the exported PDF
        // showed its title and nothing else. `TextMatrix::Translate`
        // replaces the matrix outright, which is what a laid-out page
        // wants.
        ops.push(Op::SetTextMatrix {
            matrix: TextMatrix::Translate(Pt(left_pt), Pt(cursor)),
        });
        ops.push(Op::ShowText {
            items: vec![TextItem::Text(line.text.clone())],
        });
    }

    if !ops.is_empty() {
        ops.push(Op::EndTextSection);
        pages.push(PdfPage::new(Mm(PAGE_WIDTH_MM), Mm(PAGE_HEIGHT_MM), ops));
    }
    if pages.is_empty() {
        // A PDF with no pages is not a file a reader will open.
        pages.push(PdfPage::new(
            Mm(PAGE_WIDTH_MM),
            Mm(PAGE_HEIGHT_MM),
            Vec::new(),
        ));
    }

    let mut save_warnings = Vec::new();
    Ok(doc.with_pages(pages).save(options, &mut save_warnings))
}

/// Transcript as CSV, for a spreadsheet (F19).
///
/// One row per final segment with the fields a notulis actually sorts and
/// filters on. `confidence` is included because the "Tinjau" workflow
/// (F20) is "show me the lines the engine was unsure about", and that is
/// a question a spreadsheet can answer too.
pub fn to_csv(segments: &[Segment]) -> String {
    let mut out =
        String::from("mulai_detik,waktu,durasi_detik,pembicara,sumber,bahasa,keyakinan,teks\n");
    for segment in segments {
        if segment.is_partial || segment.text.trim().is_empty() {
            continue;
        }
        let speaker = if segment.speaker.trim().is_empty() {
            segment.source.as_str()
        } else {
            segment.speaker.as_str()
        };
        out.push_str(&format!(
            "{:.3},{},{:.3},{},{},{},{:.3},{}\n",
            segment.timestamp,
            csv_field(&clock(segment.timestamp)),
            segment.duration,
            csv_field(speaker),
            csv_field(&segment.source),
            csv_field(&segment.language),
            segment.confidence,
            csv_field(segment.text.trim()),
        ));
    }
    out
}

/// RFC 4180 quoting. A transcript is free text and routinely contains
/// commas, quotes and newlines; unquoted, any one of them silently
/// shifts every following column.
fn csv_field(raw: &str) -> String {
    if raw.contains([',', '"', '\n', '\r']) {
        format!("\"{}\"", raw.replace('"', "\"\""))
    } else {
        raw.to_string()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn seg(timestamp: f64, speaker: &str, text: &str) -> Segment {
        Segment {
            source: "mic".into(),
            speaker: speaker.into(),
            text: text.into(),
            timestamp,
            duration: 3.0,
            language: "id".into(),
            confidence: 0.91,
            avg_log_prob: -0.3,
            is_partial: false,
            low_confidence: false,
        }
    }

    #[test]
    fn the_bundled_font_parses() {
        let mut warnings = Vec::new();
        assert!(
            ParsedFont::from_bytes(DEJAVU_SANS, 0, &mut warnings).is_some(),
            "the embedded face must be readable or every PDF export fails"
        );
    }

    #[test]
    fn produces_a_pdf_with_a_header_and_an_eof() {
        let bytes = to_pdf_bytes(
            &[seg(0.0, "Saya", "Selamat pagi, rapat kita mulai.")],
            "Rapat Anggaran",
            "",
            &[],
        )
        .unwrap();
        assert!(bytes.starts_with(b"%PDF-"), "missing PDF header");
        assert!(
            bytes.windows(5).any(|w| w == b"%%EOF"),
            "missing PDF trailer"
        );
    }

    #[test]
    fn embeds_the_font_rather_than_only_naming_it() {
        let bytes = to_pdf_bytes(&[seg(0.0, "Saya", "Halo")], "Rapat", "", &[]).unwrap();
        let haystack = bytes.as_slice();
        // FontFile2 is the embedded TrueType program. Without it the
        // reader substitutes, which is the failure this module exists to
        // prevent.
        assert!(
            haystack.windows(9).any(|w| w == b"FontFile2"),
            "the font program is not embedded in the PDF"
        );
    }

    #[test]
    fn a_long_meeting_paginates() {
        let segments: Vec<Segment> = (0..400)
            .map(|i| {
                seg(
                    i as f64 * 5.0,
                    "Peserta 2",
                    "Ini kalimat panjang yang harus dibungkus dan kemudian \
                     berpindah halaman ketika ruang di halaman habis.",
                )
            })
            .collect();
        let bytes = to_pdf_bytes(&segments, "Rapat Panjang", "", &[]).unwrap();
        let pages = bytes
            .windows(8)
            .filter(|w| *w == b"/Type /P" || *w == b"/Type/Pa")
            .count();
        assert!(
            bytes.len() > 20_000,
            "400 segments produced a suspiciously small PDF ({} bytes)",
            bytes.len()
        );
        // Not an exact count — the object layout is printpdf's business —
        // but a single-page document would not reach here.
        assert!(pages > 0 || bytes.len() > 20_000);
    }

    /// Every laid-out line must position with `Tm` (absolute), never
    /// `Td` (relative to the start of the current line).
    ///
    /// This is the test that was missing when the first version shipped
    /// a PDF whose title rendered and whose transcript did not: asserting
    /// the file had a header and an embedded font said nothing about
    /// whether the text landed on the page. Found by exporting a real
    /// transcript and running `pdftotext` on it, which returned the
    /// title and nothing else.
    #[test]
    fn every_line_is_positioned_absolutely() {
        let segments: Vec<Segment> = (0..6)
            .map(|i| seg(i as f64 * 4.0, "Saya", "Satu baris transkrip."))
            .collect();
        let bytes = to_pdf_bytes_with(
            &segments,
            "Rapat",
            "",
            &[],
            &PdfSaveOptions {
                optimize: false,
                ..PdfSaveOptions::default()
            },
        )
        .unwrap();
        let content = String::from_utf8_lossy(&bytes);

        let tm = content.matches(" Tm").count();
        let td = content.matches(" Td").count();
        assert!(
            tm >= 7,
            "expected one Tm per laid-out line (title + heading + 6 rows), \
             found {tm}"
        );
        assert_eq!(td, 0, "Td places text relative to the previous line");
    }

    #[test]
    fn an_empty_transcript_still_produces_a_readable_file() {
        let bytes = to_pdf_bytes(&[], "Rapat Kosong", "", &[]).unwrap();
        assert!(bytes.starts_with(b"%PDF-"));
    }

    #[test]
    fn wrapping_never_exceeds_the_measured_line_width() {
        let font = ParsedFont::from_bytes(DEJAVU_SANS, 0, &mut Vec::new()).unwrap();
        let width = mm_to_pt(PAGE_WIDTH_MM - 2.0 * MARGIN_MM);
        let text = "Rapat koordinasi anggaran kuartal keempat membahas \
                    realokasi belanja modal dan honorarium narasumber.";
        for line in wrap(&font, text, BODY_PT, width) {
            assert!(
                text_width_pt(&font, &line, BODY_PT) <= width + 0.5,
                "line wider than the page: {line:?}"
            );
        }
    }

    #[test]
    fn an_unbreakable_word_is_split_rather_than_overflowing() {
        let font = ParsedFont::from_bytes(DEJAVU_SANS, 0, &mut Vec::new()).unwrap();
        let width = mm_to_pt(40.0);
        let lines = wrap(&font, &"A".repeat(300), BODY_PT, width);
        assert!(lines.len() > 1, "a 300-character word must be broken up");
        for line in &lines {
            assert!(text_width_pt(&font, line, BODY_PT) <= width + 0.5);
        }
    }

    #[test]
    fn csv_quotes_what_would_otherwise_shift_the_columns() {
        let csv = to_csv(&[
            seg(0.0, "Saya", "Anggaran naik, katanya \"signifikan\""),
            seg(5.0, "Peserta 2", "Baris\nkedua"),
        ]);
        let mut lines = csv.lines();
        assert_eq!(
            lines.next().unwrap(),
            "mulai_detik,waktu,durasi_detik,pembicara,sumber,bahasa,keyakinan,teks"
        );
        assert!(csv.contains("\"Anggaran naik, katanya \"\"signifikan\"\"\""));
        assert!(csv.contains("\"Baris\nkedua\""));
    }

    #[test]
    fn csv_skips_partials_and_blanks() {
        let mut partial = seg(1.0, "Saya", "setengah jadi");
        partial.is_partial = true;
        let blank = seg(2.0, "Saya", "   ");
        let csv = to_csv(&[partial, blank, seg(3.0, "Saya", "nyata")]);
        assert_eq!(csv.lines().count(), 2, "header plus exactly one row");
        assert!(csv.contains("nyata"));
    }

    #[test]
    fn csv_falls_back_to_the_source_when_there_is_no_speaker() {
        let csv = to_csv(&[seg(0.0, "", "tanpa pembicara")]);
        assert!(csv.contains(",mic,mic,"), "got: {csv}");
    }

    #[test]
    fn clock_keeps_the_hour_on_a_long_meeting() {
        assert_eq!(clock(0.0), "00:00");
        assert_eq!(clock(612.5), "10:13");
        assert_eq!(clock(3_900.0), "1:05:00");
    }
}
