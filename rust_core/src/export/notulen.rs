//! Notulen Rapat resmi (F2) — official Indonesian meeting minutes.
//!
//! # Why this exists
//!
//! A generic transcript export is not a deliverable in an Indonesian office.
//! Government, BUMN and most corporate secretariats circulate a *notulen* /
//! *risalah rapat* with a fixed structure mandated by Tata Naskah Dinas
//! (ANRI Peraturan No. 5/2025; see the Kemendagri PPID notulen form referenced
//! in `docs/COMPETITOR-RESEARCH.md` §6): identity block (hari/tanggal, waktu,
//! tempat, pimpinan, notulis, peserta), agenda, pembahasan, keputusan, tindak
//! lanjut, and a signature block. No global competitor produces this, and the
//! Indonesian SaaS players charge for it.
//!
//! # Shape of the module
//!
//! Everything except the final `docx_rs` call is a pure function so the whole
//! document can be tested without touching a filesystem:
//!
//! * [`draft_from_summary`] parses the Markdown the `NotulenRapat` summary
//!   template produces into structured `keputusan` / `tindak_lanjut` /
//!   `peserta`, so the form arrives prefilled instead of empty.
//! * [`parse_blocks`] turns the Markdown body into an explicit block list
//!   (heading / bullet / paragraph / table).
//! * [`document_xml`] renders the finished `word/document.xml`, which is what
//!   the golden-file tests assert on.
//! * [`to_docx_bytes`] packs that into the `.docx` ZIP container.
//!
//! Exactly zero of it touches the network.

use docx_rs::{AlignmentType, Docx, Paragraph, Pic, Run, Table, TableCell, TableRow, WidthType};
use serde::{Deserialize, Serialize};

use crate::error::TranscribeError;
use crate::export::{fmt_timestamp, Bookmark, Segment};

/// Which of the two shipped layouts to render.
///
/// Tata Naskah Dinas varies per ministry and pemda, so the strategy from the
/// blueprint is two variants rather than one "correct" template: the full
/// dinas form for archiving, and a one-page ringkas form for circulation.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
pub enum NotulenVariant {
    /// Full Tata Naskah Dinas layout: kop surat, nomor, identity table,
    /// agenda, pembahasan, keputusan, tindak lanjut table, signature block.
    #[default]
    Dinas,
    /// One page, no kop surat and no signature block — for circulating the
    /// outcome quickly.
    Ringkas,
}

/// One row of the "Tindak Lanjut" table.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct TindakLanjut {
    pub tugas: String,
    pub penanggung_jawab: String,
    pub tenggat: String,
}

/// Everything the notulen needs that the audio cannot supply, plus the body
/// sections derived from the summary.
///
/// Persisted with the session (see `session_store.dart`) so re-exporting a
/// meeting six months later reproduces the same document.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct NotulenForm {
    pub variant: NotulenVariant,
    /// Kop surat first line, e.g. "KEMENTERIAN KEUANGAN REPUBLIK INDONESIA".
    pub instansi: String,
    /// Kop surat second line, e.g. "DIREKTORAT JENDERAL ANGGARAN".
    pub unit_kerja: String,
    /// Nomor notulen, e.g. "ND-12/AG.3/2026".
    pub nomor: String,
    pub judul: String,
    /// Day name, e.g. "Senin".
    pub hari: String,
    /// Written date, e.g. "1 Oktober 2026".
    pub tanggal: String,
    /// e.g. "09.00 – 11.30 WIB".
    pub waktu: String,
    /// Place or platform, e.g. "Ruang Rapat Lt. 5 / Zoom".
    pub tempat: String,
    pub pimpinan: String,
    pub notulis: String,
    pub peserta: Vec<String>,
    pub agenda: Vec<String>,
    /// Discussion body, Markdown (normally the AI summary's "Pembahasan").
    pub pembahasan: String,
    pub keputusan: Vec<String>,
    pub tindak_lanjut: Vec<TindakLanjut>,
    /// Bookmarks the notulis dropped during the meeting, rendered as
    /// "Poin Penting". Already formatted as `"[mm:ss] catatan"`.
    pub poin_penting: Vec<String>,
    /// Absolute path to a PNG letterhead. Empty = render the kop surat as
    /// text from `instansi` / `unit_kerja`.
    pub kop_surat_path: String,
    /// Append the full transcript as "Lampiran: Transkrip".
    pub lampirkan_transkrip: bool,
}

/// The `##` section headings the `NotulenRapat` summary template emits.
const SECTION_RINGKASAN: &str = "ringkasan";
const SECTION_PESERTA: &str = "peserta";
const SECTION_PEMBAHASAN: &str = "pembahasan";
const SECTION_KEPUTUSAN: &str = "keputusan";
const SECTION_TINDAK_LANJUT: &str = "tindak lanjut";

/// Prefill for the notulen form, parsed out of an AI summary.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct NotulenDraft {
    pub pembahasan: String,
    pub keputusan: Vec<String>,
    pub tindak_lanjut: Vec<TindakLanjut>,
    pub peserta: Vec<String>,
}

/// Strips Markdown list/emphasis noise from one line of model output.
fn clean_item(line: &str) -> String {
    let mut text = line.trim();
    // Bullet or numbered list marker.
    if let Some(rest) = text
        .strip_prefix("- ")
        .or_else(|| text.strip_prefix("* "))
        .or_else(|| text.strip_prefix("+ "))
    {
        text = rest.trim();
    } else if let Some((head, rest)) = text.split_once(". ") {
        if !head.is_empty() && head.chars().all(|c| c.is_ascii_digit()) {
            text = rest.trim();
        }
    }
    text.trim_start_matches('#')
        .trim()
        .replace("**", "")
        .replace('`', "")
        .trim()
        .to_string()
}

/// True for a Markdown table separator row like `|---|:---:|`.
fn is_table_rule(line: &str) -> bool {
    let trimmed = line.trim();
    trimmed.starts_with('|')
        && trimmed
            .chars()
            .all(|c| matches!(c, '|' | '-' | ':' | ' ' | '+' | '='))
        && trimmed.contains('-')
}

/// Splits one Markdown table row into trimmed cells.
fn table_cells(line: &str) -> Vec<String> {
    line.trim()
        .trim_matches('|')
        .split('|')
        .map(clean_item)
        .collect()
}

/// Parses a summary produced by the `NotulenRapat` template into the notulen's
/// structured sections.
///
/// Anything it cannot recognise falls through into `pembahasan` rather than
/// being dropped — an unparseable summary must still reach the document, since
/// the alternative is a notulen with an empty body and no explanation.
#[flutter_rust_bridge::frb(ignore)]
pub fn draft_from_summary(summary: &str) -> NotulenDraft {
    let mut draft = NotulenDraft::default();
    let mut section = String::new();
    let mut pembahasan_lines: Vec<String> = Vec::new();
    let mut fallback_lines: Vec<String> = Vec::new();
    let mut ringkasan_lines: Vec<String> = Vec::new();
    // Column order of the tindak-lanjut table, resolved from its header.
    let mut columns: Option<(usize, usize, usize)> = None;

    for raw in summary.lines() {
        let line = raw.trim_end();
        if let Some(heading) = line.trim().strip_prefix('#') {
            let name = heading.trim_start_matches('#').trim().to_lowercase();
            section = if name.contains(SECTION_TINDAK_LANJUT) || name.contains("action item") {
                columns = None;
                SECTION_TINDAK_LANJUT.to_string()
            } else if name.contains(SECTION_KEPUTUSAN) || name.contains("decision") {
                SECTION_KEPUTUSAN.to_string()
            } else if name.contains(SECTION_PEMBAHASAN) {
                SECTION_PEMBAHASAN.to_string()
            } else if name.contains(SECTION_PESERTA) {
                SECTION_PESERTA.to_string()
            } else if name.contains(SECTION_RINGKASAN) {
                SECTION_RINGKASAN.to_string()
            } else {
                // An unknown heading belongs to the discussion body, heading
                // and all.
                pembahasan_lines.push(line.to_string());
                String::new()
            };
            continue;
        }

        let item = clean_item(line);
        match section.as_str() {
            SECTION_PESERTA => {
                if !item.is_empty() && !item.eq_ignore_ascii_case("tidak disebutkan") {
                    // A model sometimes answers with one comma-separated line.
                    for name in item.split(',') {
                        let name = name.trim();
                        if !name.is_empty() {
                            draft.peserta.push(name.to_string());
                        }
                    }
                }
            }
            SECTION_KEPUTUSAN => {
                if !item.is_empty() {
                    draft.keputusan.push(item);
                }
            }
            SECTION_TINDAK_LANJUT => {
                if is_table_rule(line) {
                    continue;
                }
                if !line.trim().starts_with('|') {
                    // Free-text follow-up: keep it as a task with no owner
                    // rather than discarding it.
                    if !item.is_empty() {
                        draft.tindak_lanjut.push(TindakLanjut {
                            tugas: item,
                            ..TindakLanjut::default()
                        });
                    }
                    continue;
                }
                let cells = table_cells(line);
                if columns.is_none() {
                    columns = Some(resolve_columns(&cells));
                    if is_header_row(&cells) {
                        continue;
                    }
                }
                let (tugas, pj, tenggat) = columns.unwrap_or((0, 1, 2));
                let pick = |index: usize| cells.get(index).cloned().unwrap_or_default();
                let row = TindakLanjut {
                    tugas: pick(tugas),
                    penanggung_jawab: pick(pj),
                    tenggat: pick(tenggat),
                };
                if !row.tugas.is_empty() {
                    draft.tindak_lanjut.push(row);
                }
            }
            SECTION_PEMBAHASAN => pembahasan_lines.push(line.to_string()),
            SECTION_RINGKASAN => ringkasan_lines.push(line.to_string()),
            _ => fallback_lines.push(line.to_string()),
        }
    }

    // Prefer the explicit Pembahasan section; fall back to Ringkasan, then to
    // whatever prose arrived before any heading.
    let body = if pembahasan_lines.iter().any(|l| !l.trim().is_empty()) {
        pembahasan_lines
    } else if ringkasan_lines.iter().any(|l| !l.trim().is_empty()) {
        ringkasan_lines
    } else {
        fallback_lines
    };
    draft.pembahasan = body.join("\n").trim().to_string();
    draft
}

fn is_header_row(cells: &[String]) -> bool {
    cells.iter().any(|c| {
        let lower = c.to_lowercase();
        lower.contains("tugas")
            || lower.contains("penanggung")
            || lower.contains("tenggat")
            || lower.contains("action")
    })
}

/// Maps a tindak-lanjut table header onto `(tugas, pj, tenggat)` column
/// indices. Models reorder these columns, so reading them positionally
/// silently swaps owners and deadlines.
fn resolve_columns(cells: &[String]) -> (usize, usize, usize) {
    let mut tugas = 0usize;
    let mut pj = 1usize;
    let mut tenggat = 2usize;
    let mut matched = false;
    for (index, cell) in cells.iter().enumerate() {
        let lower = cell.to_lowercase();
        if lower.contains("tugas") || lower.contains("action") || lower.contains("kegiatan") {
            tugas = index;
            matched = true;
        } else if lower.contains("penanggung") || lower.contains("pj") || lower.contains("owner") {
            pj = index;
            matched = true;
        } else if lower.contains("tenggat")
            || lower.contains("batas")
            || lower.contains("due")
            || lower.contains("deadline")
        {
            tenggat = index;
            matched = true;
        }
    }
    if matched {
        (tugas, pj, tenggat)
    } else {
        (0, 1, 2)
    }
}

// ---------------------------------------------------------------------------
// Markdown body → document blocks
// ---------------------------------------------------------------------------

/// One renderable unit of the discussion body.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Block {
    Heading(String),
    Bullet(String),
    Paragraph(String),
    /// First row is the header.
    Table(Vec<Vec<String>>),
}

/// Converts the Markdown a summary model emits into explicit blocks.
///
/// Keeping this separate from `docx_rs` is what makes the body renderer
/// testable: the alternative is asserting on packed ZIP bytes.
#[flutter_rust_bridge::frb(ignore)]
pub fn parse_blocks(markdown: &str) -> Vec<Block> {
    let mut blocks: Vec<Block> = Vec::new();
    let mut table: Vec<Vec<String>> = Vec::new();
    let mut paragraph: Vec<String> = Vec::new();

    let flush_paragraph = |paragraph: &mut Vec<String>, blocks: &mut Vec<Block>| {
        if !paragraph.is_empty() {
            blocks.push(Block::Paragraph(paragraph.join(" ")));
            paragraph.clear();
        }
    };
    let flush_table = |table: &mut Vec<Vec<String>>, blocks: &mut Vec<Block>| {
        if !table.is_empty() {
            blocks.push(Block::Table(std::mem::take(table)));
        }
    };

    for raw in markdown.lines() {
        let line = raw.trim();
        if line.starts_with('|') {
            flush_paragraph(&mut paragraph, &mut blocks);
            if !is_table_rule(line) {
                table.push(table_cells(line));
            }
            continue;
        }
        flush_table(&mut table, &mut blocks);

        if line.is_empty() {
            flush_paragraph(&mut paragraph, &mut blocks);
        } else if line.starts_with('#') {
            flush_paragraph(&mut paragraph, &mut blocks);
            blocks.push(Block::Heading(clean_item(line)));
        } else if line.starts_with("- ") || line.starts_with("* ") || line.starts_with("+ ") {
            flush_paragraph(&mut paragraph, &mut blocks);
            blocks.push(Block::Bullet(clean_item(line)));
        } else if line
            .split_once(". ")
            .is_some_and(|(head, _)| !head.is_empty() && head.chars().all(|c| c.is_ascii_digit()))
        {
            flush_paragraph(&mut paragraph, &mut blocks);
            blocks.push(Block::Bullet(clean_item(line)));
        } else {
            paragraph.push(clean_item(line));
        }
    }
    flush_table(&mut table, &mut blocks);
    flush_paragraph(&mut paragraph, &mut blocks);
    blocks
}

// ---------------------------------------------------------------------------
// DOCX rendering
// ---------------------------------------------------------------------------

/// Body font size, in docx half-points (11 pt).
const BODY_SIZE: usize = 22;
const HEADING_SIZE: usize = 24;
const TITLE_SIZE: usize = 28;
/// Table width in DXA twentieths of a point (≈16 cm of usable A4 width).
const TABLE_WIDTH: usize = 9000;

fn body(text: &str) -> Paragraph {
    Paragraph::new().add_run(Run::new().add_text(text).size(BODY_SIZE))
}

fn bold_body(text: &str) -> Paragraph {
    Paragraph::new().add_run(Run::new().add_text(text).size(BODY_SIZE).bold())
}

fn heading(text: &str) -> Paragraph {
    Paragraph::new().add_run(Run::new().add_text(text).size(HEADING_SIZE).bold())
}

fn centered_bold(text: &str, size: usize) -> Paragraph {
    Paragraph::new()
        .align(AlignmentType::Center)
        .add_run(Run::new().add_text(text).size(size).bold())
}

fn cell(paragraph: Paragraph, width: usize) -> TableCell {
    TableCell::new()
        .add_paragraph(paragraph)
        .width(width, WidthType::Dxa)
}

/// PNG intrinsic size, read from the IHDR chunk.
///
/// `docx_rs::Pic::new` would do this via the `image` crate, which this build
/// deliberately does not compile in (`default-features = false`), so the
/// 8-byte header is parsed here instead. Only PNG is accepted: the DOCX media
/// part is written as `image*.png`, so handing it a JPEG would produce a file
/// Word refuses to render.
fn png_dimensions(bytes: &[u8]) -> Result<(u32, u32), TranscribeError> {
    const PNG_MAGIC: [u8; 8] = [137, 80, 78, 71, 13, 10, 26, 10];
    if bytes.len() < 24 || bytes[..8] != PNG_MAGIC {
        return Err(TranscribeError::Export(
            "kop surat harus berupa berkas PNG".into(),
        ));
    }
    let read_u32 =
        |at: usize| u32::from_be_bytes([bytes[at], bytes[at + 1], bytes[at + 2], bytes[at + 3]]);
    let (width, height) = (read_u32(16), read_u32(20));
    if width == 0 || height == 0 {
        return Err(TranscribeError::Export(
            "ukuran gambar kop surat tidak terbaca".into(),
        ));
    }
    Ok((width, height))
}

/// Scales a letterhead down so it cannot push the whole notulen onto page two.
fn kop_surat_paragraph(path: &str) -> Result<Paragraph, TranscribeError> {
    let bytes = std::fs::read(path).map_err(|e| {
        TranscribeError::Export(format!("tidak bisa membaca kop surat '{path}': {e}"))
    })?;
    let (width, height) = png_dimensions(&bytes)?;
    // 16 cm at 96 dpi.
    const MAX_WIDTH_PX: u32 = 600;
    let (width, height) = if width > MAX_WIDTH_PX {
        let scaled = (height as u64 * MAX_WIDTH_PX as u64 / width as u64).max(1) as u32;
        (MAX_WIDTH_PX, scaled)
    } else {
        (width, height)
    };
    Ok(Paragraph::new()
        .align(AlignmentType::Center)
        .add_run(Run::new().add_image(Pic::new_with_dimensions(bytes, width, height))))
}

/// `(label, value)` rows of the identity block, skipping fields the user left
/// blank so the document never shows an empty "Tempat :".
fn identity_rows(form: &NotulenForm) -> Vec<(String, String)> {
    let mut rows: Vec<(String, String)> = Vec::new();
    let hari_tanggal = match (form.hari.trim(), form.tanggal.trim()) {
        ("", "") => String::new(),
        ("", tanggal) => tanggal.to_string(),
        (hari, "") => hari.to_string(),
        (hari, tanggal) => format!("{hari}, {tanggal}"),
    };
    let mut push = |label: &str, value: &str| {
        if !value.trim().is_empty() {
            rows.push((label.to_string(), value.trim().to_string()));
        }
    };
    push("Hari/Tanggal", &hari_tanggal);
    push("Waktu", &form.waktu);
    push("Tempat/Media", &form.tempat);
    push("Pimpinan Rapat", &form.pimpinan);
    push("Notulis", &form.notulis);
    rows
}

fn identity_table(form: &NotulenForm) -> Table {
    let rows: Vec<TableRow> = identity_rows(form)
        .into_iter()
        .map(|(label, value)| {
            TableRow::new(vec![
                cell(bold_body(&label), 2600),
                cell(body(":"), 300),
                cell(body(&value), TABLE_WIDTH - 2900),
            ])
        })
        .collect();
    Table::without_borders(rows)
        .width(TABLE_WIDTH, WidthType::Dxa)
        .set_grid(vec![2600, 300, TABLE_WIDTH - 2900])
}

fn tindak_lanjut_table(rows: &[TindakLanjut]) -> Table {
    let widths = [4400usize, 2600, TABLE_WIDTH - 7000];
    let header = TableRow::new(vec![
        cell(bold_body("Tugas"), widths[0]),
        cell(bold_body("Penanggung Jawab"), widths[1]),
        cell(bold_body("Tenggat"), widths[2]),
    ]);
    let dash = |value: &str| {
        if value.trim().is_empty() {
            "-".to_string()
        } else {
            value.trim().to_string()
        }
    };
    let mut table_rows = vec![header];
    for row in rows {
        table_rows.push(TableRow::new(vec![
            cell(body(&dash(&row.tugas)), widths[0]),
            cell(body(&dash(&row.penanggung_jawab)), widths[1]),
            cell(body(&dash(&row.tenggat)), widths[2]),
        ]));
    }
    Table::new(table_rows)
        .width(TABLE_WIDTH, WidthType::Dxa)
        .set_grid(widths.to_vec())
}

/// Two-column signature block: Notulis on the left, Pimpinan Rapat on the
/// right, each over four blank lines and the name.
fn signature_table(form: &NotulenForm) -> Table {
    let half = TABLE_WIDTH / 2;
    let column = |role: &str, name: &str| {
        let mut c = TableCell::new()
            .add_paragraph(
                Paragraph::new()
                    .align(AlignmentType::Center)
                    .add_run(Run::new().add_text(role).size(BODY_SIZE)),
            )
            .width(half, WidthType::Dxa);
        for _ in 0..3 {
            c = c.add_paragraph(Paragraph::new());
        }
        let printed = if name.trim().is_empty() {
            "( ................................... )".to_string()
        } else {
            name.trim().to_string()
        };
        c.add_paragraph(
            Paragraph::new()
                .align(AlignmentType::Center)
                .add_run(Run::new().add_text(printed).size(BODY_SIZE).bold()),
        )
    };
    Table::without_borders(vec![TableRow::new(vec![
        column("Notulis", &form.notulis),
        column("Pimpinan Rapat", &form.pimpinan),
    ])])
    .width(TABLE_WIDTH, WidthType::Dxa)
    .set_grid(vec![half, half])
}

fn add_blocks(mut docx: Docx, markdown: &str) -> Docx {
    for block in parse_blocks(markdown) {
        docx = match block {
            Block::Heading(text) => docx.add_paragraph(bold_body(&text)),
            Block::Bullet(text) => docx.add_paragraph(
                Paragraph::new()
                    .indent(Some(360), None, None, None)
                    .add_run(Run::new().add_text(format!("• {text}")).size(BODY_SIZE)),
            ),
            Block::Paragraph(text) => docx.add_paragraph(body(&text)),
            Block::Table(rows) => {
                let columns = rows.iter().map(Vec::len).max().unwrap_or(1).max(1);
                let width = TABLE_WIDTH / columns;
                let table_rows: Vec<TableRow> = rows
                    .iter()
                    .enumerate()
                    .map(|(index, row)| {
                        TableRow::new(
                            (0..columns)
                                .map(|column| {
                                    let text = row.get(column).cloned().unwrap_or_default();
                                    let paragraph = if index == 0 {
                                        bold_body(&text)
                                    } else {
                                        body(&text)
                                    };
                                    cell(paragraph, width)
                                })
                                .collect(),
                        )
                    })
                    .collect();
                docx.add_table(
                    Table::new(table_rows)
                        .width(TABLE_WIDTH, WidthType::Dxa)
                        .set_grid(vec![width; columns]),
                )
            }
        };
    }
    docx
}

/// Numbered list, or the honest "Tidak ada" when the section is empty.
fn add_numbered(mut docx: Docx, items: &[String]) -> Docx {
    if items.iter().all(|item| item.trim().is_empty()) {
        return docx.add_paragraph(body("Tidak ada."));
    }
    for (index, item) in items.iter().filter(|i| !i.trim().is_empty()).enumerate() {
        docx = docx.add_paragraph(
            Paragraph::new()
                .indent(Some(360), None, None, None)
                .add_run(
                    Run::new()
                        .add_text(format!("{}. {}", index + 1, item.trim()))
                        .size(BODY_SIZE),
                ),
        );
    }
    docx
}

/// Builds the whole document. Separated from [`to_docx_bytes`] so
/// [`document_xml`] can hand the raw XML to the golden tests.
fn build(form: &NotulenForm, segments: &[Segment]) -> Result<Docx, TranscribeError> {
    let dinas = form.variant == NotulenVariant::Dinas;
    let mut docx = Docx::new();

    // ── Kop surat ────────────────────────────────────────────────────────
    if dinas {
        if !form.kop_surat_path.trim().is_empty() {
            docx = docx.add_paragraph(kop_surat_paragraph(form.kop_surat_path.trim())?);
        } else {
            if !form.instansi.trim().is_empty() {
                docx = docx.add_paragraph(centered_bold(form.instansi.trim(), HEADING_SIZE));
            }
            if !form.unit_kerja.trim().is_empty() {
                docx = docx.add_paragraph(centered_bold(form.unit_kerja.trim(), BODY_SIZE));
            }
        }
        if !form.instansi.trim().is_empty()
            || !form.unit_kerja.trim().is_empty()
            || !form.kop_surat_path.trim().is_empty()
        {
            docx = docx.add_paragraph(Paragraph::new());
        }
    }

    // ── Judul ────────────────────────────────────────────────────────────
    docx = docx.add_paragraph(centered_bold(
        if dinas {
            "NOTULEN RAPAT"
        } else {
            "NOTULEN RAPAT (RINGKAS)"
        },
        TITLE_SIZE,
    ));
    if dinas && !form.nomor.trim().is_empty() {
        docx = docx.add_paragraph(centered_bold(
            &format!("Nomor: {}", form.nomor.trim()),
            BODY_SIZE,
        ));
    }
    docx = docx.add_paragraph(Paragraph::new());

    if !form.judul.trim().is_empty() {
        docx = docx.add_paragraph(bold_body(&format!("Judul Rapat: {}", form.judul.trim())));
    }

    // ── Identitas rapat ──────────────────────────────────────────────────
    let rows = identity_rows(form);
    if !rows.is_empty() {
        docx = docx.add_table(identity_table(form));
        docx = docx.add_paragraph(Paragraph::new());
    }

    // ── Peserta ──────────────────────────────────────────────────────────
    let peserta: Vec<String> = form
        .peserta
        .iter()
        .map(|p| p.trim().to_string())
        .filter(|p| !p.is_empty())
        .collect();
    if !peserta.is_empty() {
        docx = docx.add_paragraph(heading("Peserta"));
        if dinas {
            docx = add_numbered(docx, &peserta);
        } else {
            docx = docx.add_paragraph(body(&peserta.join(", ")));
        }
        docx = docx.add_paragraph(Paragraph::new());
    }

    // ── Agenda ───────────────────────────────────────────────────────────
    let agenda: Vec<String> = form
        .agenda
        .iter()
        .map(|a| a.trim().to_string())
        .filter(|a| !a.is_empty())
        .collect();
    if !agenda.is_empty() {
        docx = docx.add_paragraph(heading("Agenda"));
        docx = add_numbered(docx, &agenda);
        docx = docx.add_paragraph(Paragraph::new());
    }

    // ── Pembahasan ───────────────────────────────────────────────────────
    docx = docx.add_paragraph(heading("Pembahasan"));
    if form.pembahasan.trim().is_empty() {
        docx = docx.add_paragraph(body("Tidak ada."));
    } else {
        docx = add_blocks(docx, form.pembahasan.trim());
    }
    docx = docx.add_paragraph(Paragraph::new());

    // ── Poin penting (bookmarks) ─────────────────────────────────────────
    let poin: Vec<String> = form
        .poin_penting
        .iter()
        .map(|p| p.trim().to_string())
        .filter(|p| !p.is_empty())
        .collect();
    if !poin.is_empty() {
        docx = docx.add_paragraph(heading("Poin Penting"));
        docx = add_numbered(docx, &poin);
        docx = docx.add_paragraph(Paragraph::new());
    }

    // ── Keputusan ────────────────────────────────────────────────────────
    docx = docx.add_paragraph(heading("Keputusan"));
    docx = add_numbered(docx, &form.keputusan);
    docx = docx.add_paragraph(Paragraph::new());

    // ── Tindak lanjut ────────────────────────────────────────────────────
    docx = docx.add_paragraph(heading("Tindak Lanjut"));
    if form.tindak_lanjut.is_empty() {
        docx = docx.add_paragraph(body("Tidak ada."));
    } else {
        docx = docx.add_table(tindak_lanjut_table(&form.tindak_lanjut));
    }
    docx = docx.add_paragraph(Paragraph::new());

    // ── Penutup + tanda tangan ───────────────────────────────────────────
    if dinas {
        docx = docx.add_paragraph(body(
            "Rapat ditutup setelah seluruh agenda dibahas. Notulen ini dibuat \
             sebagai dokumentasi resmi pelaksanaan rapat.",
        ));
        docx = docx.add_paragraph(Paragraph::new());
        docx = docx.add_table(signature_table(form));
    }

    // ── Lampiran transkrip ───────────────────────────────────────────────
    if form.lampirkan_transkrip && !segments.is_empty() {
        docx = docx.add_paragraph(
            Paragraph::new().page_break_before(true).add_run(
                Run::new()
                    .add_text("Lampiran: Transkrip")
                    .size(HEADING_SIZE)
                    .bold(),
            ),
        );
        for segment in segments.iter().filter(|s| !s.is_partial) {
            let text = segment.text.trim();
            if text.is_empty() {
                continue;
            }
            docx = docx.add_paragraph(body(&format!(
                "[{}] {}: {}",
                fmt_timestamp(segment.timestamp),
                segment.speaker.trim(),
                text
            )));
        }
    }

    Ok(docx)
}

/// The generated `word/document.xml`, as UTF-8.
///
/// This is the artefact the golden tests assert on: packing to a ZIP first
/// would mean the tests either need a ZIP reader or assert on compressed
/// bytes, neither of which says anything about the document's structure.
#[flutter_rust_bridge::frb(ignore)]
pub fn document_xml(form: &NotulenForm, segments: &[Segment]) -> Result<String, TranscribeError> {
    let xml = build(form, segments)?.build().document;
    String::from_utf8(xml)
        .map_err(|e| TranscribeError::Export(format!("document.xml bukan UTF-8: {e}")))
}

/// The finished `.docx` container.
#[flutter_rust_bridge::frb(ignore)]
pub fn to_docx_bytes(form: &NotulenForm, segments: &[Segment]) -> Result<Vec<u8>, TranscribeError> {
    let mut cursor = std::io::Cursor::new(Vec::new());
    build(form, segments)?
        .build()
        .pack(&mut cursor)
        .map_err(|e| TranscribeError::Export(format!("gagal menyusun notulen DOCX: {e}")))?;
    Ok(cursor.into_inner())
}

/// Formats the session's bookmarks the way [`NotulenForm::poin_penting`]
/// expects them.
#[flutter_rust_bridge::frb(ignore)]
pub fn poin_penting_from_bookmarks(bookmarks: &[Bookmark]) -> Vec<String> {
    bookmarks
        .iter()
        .map(|bookmark| {
            let note = bookmark.note.trim();
            if note.is_empty() {
                format!("[{}] Poin penting", fmt_timestamp(bookmark.timestamp))
            } else {
                format!("[{}] {note}", fmt_timestamp(bookmark.timestamp))
            }
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn form() -> NotulenForm {
        NotulenForm {
            variant: NotulenVariant::Dinas,
            instansi: "KEMENTERIAN KEUANGAN REPUBLIK INDONESIA".into(),
            unit_kerja: "DIREKTORAT JENDERAL ANGGARAN".into(),
            nomor: "ND-12/AG.3/2026".into(),
            judul: "Rapat Koordinasi Penyusunan RKAKL 2027".into(),
            hari: "Senin".into(),
            tanggal: "1 Oktober 2026".into(),
            waktu: "09.00 – 11.30 WIB".into(),
            tempat: "Ruang Rapat Lt. 5 / Zoom".into(),
            pimpinan: "Dr. Siti Aminah".into(),
            notulis: "Budi Santoso".into(),
            peserta: vec!["Dr. Siti Aminah".into(), "Budi Santoso".into()],
            agenda: vec!["Evaluasi pagu indikatif".into(), "Jadwal Musrenbang".into()],
            pembahasan: "## Pagu\n- Pagu naik 4%\n\nDetail dibahas bersama PPBJ.".into(),
            keputusan: vec!["Pagu disetujui".into(), "Rapat lanjutan 15 Oktober".into()],
            tindak_lanjut: vec![TindakLanjut {
                tugas: "Susun draf RKAKL".into(),
                penanggung_jawab: "Budi Santoso".into(),
                tenggat: "10 Oktober 2026".into(),
            }],
            poin_penting: vec!["[05:12] keputusan penting".into()],
            kop_surat_path: String::new(),
            lampirkan_transkrip: false,
        }
    }

    fn segment(text: &str, ts: f64) -> Segment {
        Segment {
            source: "mic".into(),
            speaker: "Pimpinan".into(),
            text: text.into(),
            timestamp: ts,
            duration: 2.0,
            language: "id".into(),
            confidence: 0.9,
            avg_log_prob: -0.3,
            is_partial: false,
            low_confidence: false,
            words: Vec::new(),
        }
    }

    // --- summary parsing -------------------------------------------------

    const SUMMARY: &str = "## Ringkasan\nRapat membahas pagu indikatif.\n\n\
## Peserta\n- Dr. Siti Aminah\n- Budi Santoso\n\n\
## Pembahasan\n- Pagu naik 4%\n- Musrenbang dijadwalkan ulang\n\n\
## Keputusan\n1. Pagu disetujui\n2. Rapat lanjutan 15 Oktober\n\n\
## Tindak Lanjut\n| Tugas | Penanggung Jawab | Tenggat |\n|---|---|---|\n\
| Susun draf RKAKL | Budi Santoso | 10 Oktober 2026 |\n\
| Kirim undangan | Rina | - |\n";

    #[test]
    fn draft_extracts_every_section_from_the_notulen_template() {
        let draft = draft_from_summary(SUMMARY);
        assert_eq!(draft.peserta, vec!["Dr. Siti Aminah", "Budi Santoso"]);
        assert_eq!(
            draft.keputusan,
            vec!["Pagu disetujui", "Rapat lanjutan 15 Oktober"]
        );
        assert!(draft.pembahasan.contains("Pagu naik 4%"));
        assert!(
            !draft.pembahasan.contains("Pagu disetujui"),
            "keputusan must not leak into pembahasan"
        );
        assert_eq!(
            draft.tindak_lanjut,
            vec![
                TindakLanjut {
                    tugas: "Susun draf RKAKL".into(),
                    penanggung_jawab: "Budi Santoso".into(),
                    tenggat: "10 Oktober 2026".into(),
                },
                TindakLanjut {
                    tugas: "Kirim undangan".into(),
                    penanggung_jawab: "Rina".into(),
                    tenggat: "-".into(),
                },
            ]
        );
    }

    #[test]
    fn draft_reads_reordered_table_columns_by_header() {
        // A model that emits Penanggung Jawab first must not have owners and
        // tasks silently swapped.
        let summary = "## Tindak Lanjut\n| Penanggung Jawab | Tugas | Tenggat |\n|---|---|---|\n\
                       | Rina | Kirim undangan | Jumat |\n";
        assert_eq!(
            draft_from_summary(summary).tindak_lanjut,
            vec![TindakLanjut {
                tugas: "Kirim undangan".into(),
                penanggung_jawab: "Rina".into(),
                tenggat: "Jumat".into(),
            }]
        );
    }

    #[test]
    fn draft_keeps_free_text_follow_ups_as_tasks_without_an_owner() {
        let summary = "## Tindak Lanjut\n- Hubungi vendor\n";
        let draft = draft_from_summary(summary);
        assert_eq!(draft.tindak_lanjut.len(), 1);
        assert_eq!(draft.tindak_lanjut[0].tugas, "Hubungi vendor");
        assert!(draft.tindak_lanjut[0].penanggung_jawab.is_empty());
    }

    #[test]
    fn draft_never_drops_an_unparseable_summary() {
        let draft = draft_from_summary("Rapat singkat, tidak ada keputusan formal.");
        assert!(draft.pembahasan.contains("Rapat singkat"));
        assert!(draft.keputusan.is_empty());
    }

    #[test]
    fn draft_falls_back_to_ringkasan_when_there_is_no_pembahasan() {
        let draft = draft_from_summary("## Ringkasan\nHanya sinkronisasi jadwal.\n");
        assert_eq!(draft.pembahasan, "Hanya sinkronisasi jadwal.");
    }

    #[test]
    fn draft_ignores_a_not_mentioned_participant_list() {
        let draft = draft_from_summary("## Peserta\nTidak disebutkan\n");
        assert!(draft.peserta.is_empty());
    }

    // --- markdown blocks -------------------------------------------------

    #[test]
    fn blocks_classify_headings_bullets_paragraphs_and_tables() {
        let blocks = parse_blocks(
            "## Topik\n- satu\n2. dua\n\nProsa biasa\nyang menyambung.\n\
             \n| A | B |\n|---|---|\n| 1 | 2 |\n",
        );
        assert_eq!(
            blocks,
            vec![
                Block::Heading("Topik".into()),
                Block::Bullet("satu".into()),
                Block::Bullet("dua".into()),
                Block::Paragraph("Prosa biasa yang menyambung.".into()),
                Block::Table(vec![
                    vec!["A".into(), "B".into()],
                    vec!["1".into(), "2".into()],
                ]),
            ]
        );
    }

    #[test]
    fn blocks_drop_the_markdown_table_rule_row() {
        let blocks = parse_blocks("| A |\n|:--|\n| 1 |");
        assert_eq!(
            blocks,
            vec![Block::Table(vec![vec!["A".into()], vec!["1".into()]])]
        );
    }

    // --- golden document XML --------------------------------------------

    #[test]
    fn dinas_document_carries_every_tata_naskah_dinas_section() {
        let xml = document_xml(&form(), &[]).unwrap();
        for expected in [
            "KEMENTERIAN KEUANGAN REPUBLIK INDONESIA",
            "DIREKTORAT JENDERAL ANGGARAN",
            "NOTULEN RAPAT",
            "Nomor: ND-12/AG.3/2026",
            "Judul Rapat: Rapat Koordinasi Penyusunan RKAKL 2027",
            "Hari/Tanggal",
            "Senin, 1 Oktober 2026",
            "Waktu",
            "09.00 – 11.30 WIB",
            "Tempat/Media",
            "Pimpinan Rapat",
            "Notulis",
            "Peserta",
            "Agenda",
            "Pembahasan",
            "Poin Penting",
            "[05:12] keputusan penting",
            "Keputusan",
            "1. Pagu disetujui",
            "Tindak Lanjut",
            "Penanggung Jawab",
            "Tenggat",
            "Susun draf RKAKL",
            "10 Oktober 2026",
        ] {
            assert!(
                xml.contains(expected),
                "document.xml is missing {expected:?}"
            );
        }
        // Signature block: both roles, each rendered once.
        assert_eq!(xml.matches("Pimpinan Rapat").count(), 2);
    }

    #[test]
    fn section_order_follows_the_official_form() {
        let xml = document_xml(&form(), &[]).unwrap();
        let at = |needle: &str| {
            xml.find(needle)
                .unwrap_or_else(|| panic!("missing {needle}"))
        };
        assert!(at("NOTULEN RAPAT") < at("Hari/Tanggal"));
        assert!(at("Hari/Tanggal") < at(">Agenda<"));
        assert!(at(">Agenda<") < at(">Pembahasan<"));
        assert!(at(">Pembahasan<") < at(">Keputusan<"));
        assert!(at(">Keputusan<") < at(">Tindak Lanjut<"));
        // "Notulis" appears twice — as an identity-block label before the
        // body, and again as the left signature column after it.
        assert!(at(">Notulis<") < at(">Pembahasan<"));
        assert!(at(">Tindak Lanjut<") < xml.rfind(">Notulis<").unwrap());
    }

    #[test]
    fn ringkas_variant_drops_the_kop_and_signature_block() {
        let mut ringkas = form();
        ringkas.variant = NotulenVariant::Ringkas;
        let xml = document_xml(&ringkas, &[]).unwrap();
        assert!(xml.contains("NOTULEN RAPAT (RINGKAS)"));
        assert!(!xml.contains("KEMENTERIAN KEUANGAN"), "no kop surat");
        assert!(!xml.contains("Nomor:"), "no nomor naskah");
        // "Pimpinan Rapat" survives only as the identity row, not as a
        // signature column.
        assert_eq!(xml.matches("Pimpinan Rapat").count(), 1);
        // Peserta are inline, not a numbered list.
        assert!(xml.contains("Dr. Siti Aminah, Budi Santoso"));
    }

    #[test]
    fn blank_form_fields_do_not_produce_empty_labelled_rows() {
        let sparse = NotulenForm {
            judul: "Rapat singkat".into(),
            ..NotulenForm::default()
        };
        let xml = document_xml(&sparse, &[]).unwrap();
        assert!(!xml.contains("Tempat/Media"));
        assert!(!xml.contains("Hari/Tanggal"));
        // The mandatory sections are still present, stated honestly.
        assert!(xml.contains(">Keputusan<"));
        assert!(xml.contains("Tidak ada."));
    }

    #[test]
    fn transcript_attachment_is_opt_in() {
        let mut with_transcript = form();
        with_transcript.lampirkan_transkrip = true;
        let segments = [segment("selamat pagi semua", 5.0)];
        let xml = document_xml(&with_transcript, &segments).unwrap();
        assert!(xml.contains("Lampiran: Transkrip"));
        assert!(xml.contains("[00:05] Pimpinan: selamat pagi semua"));

        let without = document_xml(&form(), &segments).unwrap();
        assert!(!without.contains("Lampiran: Transkrip"));
        assert!(!without.contains("selamat pagi semua"));
    }

    #[test]
    fn partial_segments_are_never_attached() {
        let mut with_transcript = form();
        with_transcript.lampirkan_transkrip = true;
        let mut partial = segment("teks cepat", 1.0);
        partial.is_partial = true;
        let xml = document_xml(&with_transcript, &[partial]).unwrap();
        assert!(!xml.contains("teks cepat"));
    }

    #[test]
    fn xml_special_characters_in_user_input_are_escaped() {
        let mut risky = form();
        risky.judul = "Rapat <PPBJ> & \"Anggaran\"".into();
        let xml = document_xml(&risky, &[]).unwrap();
        assert!(!xml.contains("<PPBJ>"));
        assert!(xml.contains("&lt;PPBJ&gt;"));
        assert!(xml.contains("&amp;"));
    }

    #[test]
    fn docx_bytes_are_a_zip_container() {
        let bytes = to_docx_bytes(&form(), &[]).unwrap();
        assert!(bytes.len() > 4);
        assert_eq!(&bytes[0..2], b"PK");
    }

    /// Writes a real notulen DOCX to `$TRAREON_NOTULEN_DUMP` when that env var
    /// is set, so `scripts/validate_notulen.py` can read it back with an
    /// independent OOXML parser. A no-op in the normal test run.
    #[test]
    fn dump_notulen_docx_for_external_validation() {
        let Ok(path) = std::env::var("TRAREON_NOTULEN_DUMP") else {
            return;
        };
        let bytes = to_docx_bytes(&form(), &[]).unwrap();
        std::fs::write(&path, &bytes).unwrap();
    }

    // --- kop surat -------------------------------------------------------

    #[test]
    fn png_dimensions_are_read_from_the_ihdr_chunk() {
        let mut png = vec![137, 80, 78, 71, 13, 10, 26, 10];
        png.extend_from_slice(&13u32.to_be_bytes());
        png.extend_from_slice(b"IHDR");
        png.extend_from_slice(&1200u32.to_be_bytes());
        png.extend_from_slice(&300u32.to_be_bytes());
        png.extend_from_slice(&[8, 6, 0, 0, 0]);
        assert_eq!(png_dimensions(&png).unwrap(), (1200, 300));
    }

    #[test]
    fn a_non_png_kop_surat_is_rejected_with_an_indonesian_message() {
        let err = png_dimensions(&[
            0xff, 0xd8, 0xff, 0xe0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        ])
        .unwrap_err()
        .to_string();
        assert!(err.contains("PNG"), "got: {err}");
    }

    #[test]
    fn a_missing_kop_surat_file_is_an_error_not_a_panic() {
        let mut with_kop = form();
        with_kop.kop_surat_path = "/nonexistent/kop.png".into();
        assert!(document_xml(&with_kop, &[]).is_err());
    }

    #[test]
    fn kop_surat_image_is_embedded_and_scaled_down() {
        let dir = std::env::temp_dir().join(format!("trareon_kop_{}", uuid::Uuid::new_v4()));
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join("kop.png");
        // A 1-pixel PNG is enough: only the IHDR is parsed.
        let mut png = vec![137, 80, 78, 71, 13, 10, 26, 10];
        png.extend_from_slice(&13u32.to_be_bytes());
        png.extend_from_slice(b"IHDR");
        png.extend_from_slice(&1200u32.to_be_bytes());
        png.extend_from_slice(&300u32.to_be_bytes());
        png.extend_from_slice(&[8, 6, 0, 0, 0]);
        std::fs::write(&path, &png).unwrap();

        let mut with_kop = form();
        with_kop.kop_surat_path = path.to_string_lossy().to_string();
        let xml = document_xml(&with_kop, &[]).unwrap();
        assert!(xml.contains("<w:drawing>"), "kop surat must be a drawing");
        // 1200 px wide is scaled to the 600 px cap; docx stores EMU (×9525).
        assert!(
            xml.contains(&format!("cx=\"{}\"", 600 * 9525)),
            "letterhead must be scaled to the page width"
        );
        // The text kop must not be duplicated underneath the image.
        assert!(!xml.contains("KEMENTERIAN KEUANGAN REPUBLIK INDONESIA"));

        let _ = std::fs::remove_dir_all(&dir);
    }

    // --- bookmarks -------------------------------------------------------

    #[test]
    fn bookmarks_become_timestamped_poin_penting() {
        let bookmarks = vec![
            Bookmark {
                timestamp: 312.0,
                note: " keputusan penting ".into(),
            },
            Bookmark {
                timestamp: 65.0,
                note: String::new(),
            },
        ];
        assert_eq!(
            poin_penting_from_bookmarks(&bookmarks),
            vec!["[05:12] keputusan penting", "[01:05] Poin penting"]
        );
    }
}
