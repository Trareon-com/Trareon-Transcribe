//! Minimal DOCX (WordprocessingML) writer.
//!
//! Replaces the `docx-rs` crate, whose newest release pins `zip ^8.6` and so
//! kept five RustSec zip advisories in our lockfile. The exports only ever
//! used a small slice of it (paragraphs, bold/sized runs, centring, left
//! indent, page break, fixed-width tables with or without borders, and one
//! inline PNG), so this module keeps that slice with the same builder API.
//! Call sites only change their `use` line.
//!
//! The package written is the smallest one Word, LibreOffice and Google Docs
//! accept: `[Content_Types].xml`, `_rels/.rels`, `word/document.xml`,
//! `word/styles.xml`, `word/_rels/document.xml.rels` and `word/media/*.png`.

use std::fmt::Write as _;
use std::io::{Seek, Write};

/// EMU (English Metric Units) per pixel at 96 dpi.
const EMU_PER_PX: u64 = 9525;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AlignmentType {
    Center,
}

impl AlignmentType {
    fn as_str(self) -> &'static str {
        match self {
            AlignmentType::Center => "center",
        }
    }
}

/// Only twentieths of a point are used by the exports.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum WidthType {
    Dxa,
}

/// An inline PNG picture, sized in pixels at 96 dpi.
#[derive(Debug, Clone)]
pub struct Pic {
    bytes: Vec<u8>,
    width_px: u32,
    height_px: u32,
}

impl Pic {
    pub fn new_with_dimensions(bytes: Vec<u8>, width_px: u32, height_px: u32) -> Self {
        Self {
            bytes,
            width_px,
            height_px,
        }
    }
}

#[derive(Debug, Clone, Default)]
pub struct Run {
    text: String,
    bold: bool,
    /// Half-points, as in `<w:sz>`.
    size: Option<usize>,
    image: Option<Pic>,
}

impl Run {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn add_text(mut self, text: impl Into<String>) -> Self {
        self.text.push_str(&text.into());
        self
    }

    pub fn bold(mut self) -> Self {
        self.bold = true;
        self
    }

    pub fn size(mut self, half_points: usize) -> Self {
        self.size = Some(half_points);
        self
    }

    pub fn add_image(mut self, pic: Pic) -> Self {
        self.image = Some(pic);
        self
    }
}

#[derive(Debug, Clone, Default)]
pub struct Paragraph {
    runs: Vec<Run>,
    align: Option<AlignmentType>,
    indent_left: Option<i32>,
    page_break_before: bool,
}

impl Paragraph {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn add_run(mut self, run: Run) -> Self {
        self.runs.push(run);
        self
    }

    pub fn align(mut self, align: AlignmentType) -> Self {
        self.align = Some(align);
        self
    }

    /// Same shape as `docx-rs`: `(left, special, end, start_chars)`. Only the
    /// left indent (in twentieths of a point) is supported.
    pub fn indent(
        mut self,
        left: Option<i32>,
        _special: Option<()>,
        _end: Option<i32>,
        _start_chars: Option<i32>,
    ) -> Self {
        self.indent_left = left;
        self
    }

    pub fn page_break_before(mut self, on: bool) -> Self {
        self.page_break_before = on;
        self
    }
}

#[derive(Debug, Clone, Default)]
pub struct TableCell {
    paragraphs: Vec<Paragraph>,
    width: Option<usize>,
}

impl TableCell {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn add_paragraph(mut self, paragraph: Paragraph) -> Self {
        self.paragraphs.push(paragraph);
        self
    }

    pub fn width(mut self, width: usize, _kind: WidthType) -> Self {
        self.width = Some(width);
        self
    }
}

#[derive(Debug, Clone)]
pub struct TableRow {
    cells: Vec<TableCell>,
}

impl TableRow {
    pub fn new(cells: Vec<TableCell>) -> Self {
        Self { cells }
    }
}

#[derive(Debug, Clone)]
pub struct Table {
    rows: Vec<TableRow>,
    borders: bool,
    width: Option<usize>,
    grid: Vec<usize>,
}

impl Table {
    /// A table with single-line borders on every edge.
    pub fn new(rows: Vec<TableRow>) -> Self {
        Self {
            rows,
            borders: true,
            width: None,
            grid: Vec::new(),
        }
    }

    pub fn without_borders(rows: Vec<TableRow>) -> Self {
        Self {
            borders: false,
            ..Self::new(rows)
        }
    }

    pub fn width(mut self, width: usize, _kind: WidthType) -> Self {
        self.width = Some(width);
        self
    }

    pub fn set_grid(mut self, grid: Vec<usize>) -> Self {
        self.grid = grid;
        self
    }
}

#[derive(Debug, Clone)]
enum Block {
    Paragraph(Paragraph),
    Table(Table),
}

#[derive(Debug, Clone, Default)]
pub struct Docx {
    blocks: Vec<Block>,
}

impl Docx {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn add_paragraph(mut self, paragraph: Paragraph) -> Self {
        self.blocks.push(Block::Paragraph(paragraph));
        self
    }

    pub fn add_table(mut self, table: Table) -> Self {
        self.blocks.push(Block::Table(table));
        self
    }

    /// Renders every part. `document` is exposed for the golden tests.
    pub fn build(self) -> XmlDocx {
        let mut writer = BodyWriter::default();
        for block in &self.blocks {
            match block {
                Block::Paragraph(p) => writer.paragraph(p),
                Block::Table(t) => writer.table(t),
            }
        }
        let document = format!(
            concat!(
                r#"<?xml version="1.0" encoding="UTF-8" standalone="yes"?>"#,
                r#"<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main""#,
                r#" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships""#,
                r#" xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing""#,
                r#" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main""#,
                r#" xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">"#,
                "<w:body>{body}",
                // A4, 2.54 cm margins: 9026 twips of text width, enough for
                // the exports' 9000-twip tables.
                r#"<w:sectPr><w:pgSz w:w="11906" w:h="16838"/>"#,
                r#"<w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="708" w:footer="708" w:gutter="0"/>"#,
                "</w:sectPr></w:body></w:document>"
            ),
            body = writer.out
        );
        XmlDocx {
            document: document.into_bytes(),
            images: writer.images,
        }
    }
}

/// The rendered package, ready to [`pack`](XmlDocx::pack).
pub struct XmlDocx {
    pub document: Vec<u8>,
    images: Vec<Vec<u8>>,
}

impl XmlDocx {
    pub fn pack<W: Write + Seek>(self, writer: W) -> zip::result::ZipResult<()> {
        let mut zip = zip::ZipWriter::new(writer);
        let options = zip::write::SimpleFileOptions::default()
            .compression_method(zip::CompressionMethod::Deflated);

        let mut put = |name: &str, bytes: &[u8]| -> zip::result::ZipResult<()> {
            zip.start_file(name, options)?;
            zip.write_all(bytes)?;
            Ok(())
        };

        put(
            "[Content_Types].xml",
            content_types(!self.images.is_empty()).as_bytes(),
        )?;
        put("_rels/.rels", ROOT_RELS.as_bytes())?;
        put("word/document.xml", &self.document)?;
        put("word/styles.xml", STYLES.as_bytes())?;
        put(
            "word/_rels/document.xml.rels",
            document_rels(self.images.len()).as_bytes(),
        )?;
        for (index, bytes) in self.images.iter().enumerate() {
            put(&format!("word/media/image{}.png", index + 1), bytes)?;
        }
        zip.finish()?;
        Ok(())
    }
}

#[derive(Default)]
struct BodyWriter {
    out: String,
    images: Vec<Vec<u8>>,
}

impl BodyWriter {
    fn paragraph(&mut self, p: &Paragraph) {
        self.out.push_str("<w:p>");
        if p.align.is_some() || p.indent_left.is_some() || p.page_break_before {
            self.out.push_str("<w:pPr>");
            if p.page_break_before {
                self.out.push_str("<w:pageBreakBefore/>");
            }
            if let Some(left) = p.indent_left {
                let _ = write!(self.out, r#"<w:ind w:left="{left}"/>"#);
            }
            if let Some(align) = p.align {
                let _ = write!(self.out, r#"<w:jc w:val="{}"/>"#, align.as_str());
            }
            self.out.push_str("</w:pPr>");
        }
        for run in &p.runs {
            self.run(run);
        }
        self.out.push_str("</w:p>");
    }

    fn run(&mut self, run: &Run) {
        self.out.push_str("<w:r>");
        if run.bold || run.size.is_some() {
            self.out.push_str("<w:rPr>");
            if run.bold {
                self.out.push_str("<w:b/><w:bCs/>");
            }
            if let Some(size) = run.size {
                let _ = write!(
                    self.out,
                    r#"<w:sz w:val="{size}"/><w:szCs w:val="{size}"/>"#
                );
            }
            self.out.push_str("</w:rPr>");
        }
        if let Some(pic) = &run.image {
            self.images.push(pic.bytes.clone());
            self.drawing(pic, self.images.len());
        }
        if !run.text.is_empty() {
            let _ = write!(
                self.out,
                r#"<w:t xml:space="preserve">{}</w:t>"#,
                escape(&run.text)
            );
        }
        self.out.push_str("</w:r>");
    }

    fn drawing(&mut self, pic: &Pic, number: usize) {
        let cx = pic.width_px as u64 * EMU_PER_PX;
        let cy = pic.height_px as u64 * EMU_PER_PX;
        let _ = write!(
            self.out,
            concat!(
                "<w:drawing>",
                r#"<wp:inline distT="0" distB="0" distL="0" distR="0">"#,
                r#"<wp:extent cx="{cx}" cy="{cy}"/>"#,
                r#"<wp:docPr id="{n}" name="Gambar {n}"/>"#,
                r#"<a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">"#,
                r#"<pic:pic><pic:nvPicPr><pic:cNvPr id="{n}" name="image{n}.png"/><pic:cNvPicPr/></pic:nvPicPr>"#,
                r#"<pic:blipFill><a:blip r:embed="rIdImage{n}"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>"#,
                r#"<pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="{cx}" cy="{cy}"/></a:xfrm>"#,
                r#"<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr></pic:pic>"#,
                "</a:graphicData></a:graphic></wp:inline></w:drawing>"
            ),
            cx = cx,
            cy = cy,
            n = number
        );
    }

    fn table(&mut self, t: &Table) {
        self.out.push_str("<w:tbl><w:tblPr>");
        match t.width {
            Some(w) => {
                let _ = write!(self.out, r#"<w:tblW w:w="{w}" w:type="dxa"/>"#);
            }
            None => self.out.push_str(r#"<w:tblW w:w="0" w:type="auto"/>"#),
        }
        let style = if t.borders { "single" } else { "nil" };
        self.out.push_str("<w:tblBorders>");
        for edge in ["top", "left", "bottom", "right", "insideH", "insideV"] {
            if t.borders {
                let _ = write!(
                    self.out,
                    r#"<w:{edge} w:val="{style}" w:sz="4" w:space="0" w:color="000000"/>"#
                );
            } else {
                let _ = write!(self.out, r#"<w:{edge} w:val="{style}"/>"#);
            }
        }
        self.out
            .push_str(r#"</w:tblBorders><w:tblLayout w:type="fixed"/></w:tblPr>"#);
        if !t.grid.is_empty() {
            self.out.push_str("<w:tblGrid>");
            for w in &t.grid {
                let _ = write!(self.out, r#"<w:gridCol w:w="{w}"/>"#);
            }
            self.out.push_str("</w:tblGrid>");
        }
        for row in &t.rows {
            self.out.push_str("<w:tr>");
            for cell in &row.cells {
                self.out.push_str("<w:tc><w:tcPr>");
                match cell.width {
                    Some(w) => {
                        let _ = write!(self.out, r#"<w:tcW w:w="{w}" w:type="dxa"/>"#);
                    }
                    None => self.out.push_str(r#"<w:tcW w:w="0" w:type="auto"/>"#),
                }
                self.out.push_str("</w:tcPr>");
                if cell.paragraphs.is_empty() {
                    // A cell must end in a paragraph or Word calls the file corrupt.
                    self.out.push_str("<w:p/>");
                }
                for p in &cell.paragraphs {
                    self.paragraph(p);
                }
                self.out.push_str("</w:tc>");
            }
            self.out.push_str("</w:tr>");
        }
        self.out.push_str("</w:tbl>");
    }
}

/// Escapes text for an XML text node, dropping characters XML 1.0 forbids
/// (e.g. stray control codes from a transcript), which would otherwise make
/// Word reject the whole file.
fn escape(text: &str) -> String {
    let mut out = String::with_capacity(text.len());
    for c in text.chars() {
        match c {
            '&' => out.push_str("&amp;"),
            '<' => out.push_str("&lt;"),
            '>' => out.push_str("&gt;"),
            '"' => out.push_str("&quot;"),
            '\'' => out.push_str("&apos;"),
            '\t' | '\n' | '\r' => out.push(c),
            c if (c as u32) < 0x20 || c == '\u{FFFE}' || c == '\u{FFFF}' => {}
            c => out.push(c),
        }
    }
    out
}

fn content_types(with_png: bool) -> String {
    format!(
        concat!(
            r#"<?xml version="1.0" encoding="UTF-8" standalone="yes"?>"#,
            r#"<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">"#,
            r#"<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>"#,
            r#"<Default Extension="xml" ContentType="application/xml"/>"#,
            "{png}",
            r#"<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>"#,
            r#"<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>"#,
            "</Types>"
        ),
        png = if with_png {
            r#"<Default Extension="png" ContentType="image/png"/>"#
        } else {
            ""
        }
    )
}

const ROOT_RELS: &str = concat!(
    r#"<?xml version="1.0" encoding="UTF-8" standalone="yes"?>"#,
    r#"<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">"#,
    r#"<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>"#,
    "</Relationships>"
);

fn document_rels(images: usize) -> String {
    let mut out = String::from(concat!(
        r#"<?xml version="1.0" encoding="UTF-8" standalone="yes"?>"#,
        r#"<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">"#,
        r#"<Relationship Id="rIdStyles" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>"#,
    ));
    for n in 1..=images {
        let _ = write!(
            out,
            r#"<Relationship Id="rIdImage{n}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/image{n}.png"/>"#
        );
    }
    out.push_str("</Relationships>");
    out
}

/// Document defaults: Calibri 11 pt, Indonesian proofing language.
const STYLES: &str = concat!(
    r#"<?xml version="1.0" encoding="UTF-8" standalone="yes"?>"#,
    r#"<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">"#,
    "<w:docDefaults><w:rPrDefault><w:rPr>",
    r#"<w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:eastAsia="Calibri" w:cs="Calibri"/>"#,
    r#"<w:sz w:val="22"/><w:szCs w:val="22"/><w:lang w:val="id-ID"/>"#,
    "</w:rPr></w:rPrDefault>",
    r#"<w:pPrDefault><w:pPr><w:spacing w:after="120" w:line="259" w:lineRule="auto"/></w:pPr></w:pPrDefault>"#,
    "</w:docDefaults>",
    r#"<w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/><w:qFormat/></w:style>"#,
    "</w:styles>"
);

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Read;

    fn png_1x1() -> Vec<u8> {
        // Smallest valid PNG: 1x1 transparent pixel.
        vec![
            137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1,
            8, 6, 0, 0, 0, 31, 21, 196, 137, 0, 0, 0, 13, 73, 68, 65, 84, 120, 156, 99, 0, 1, 0, 0,
            5, 0, 1, 13, 10, 45, 180, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130,
        ]
    }

    fn sample() -> Docx {
        Docx::new()
            .add_paragraph(
                Paragraph::new()
                    .align(AlignmentType::Center)
                    .add_run(Run::new().add_image(Pic::new_with_dimensions(png_1x1(), 10, 5))),
            )
            .add_paragraph(Paragraph::new().add_run(Run::new().add_text("Judul").bold().size(32)))
            .add_table(
                Table::new(vec![TableRow::new(vec![
                    TableCell::new()
                        .add_paragraph(Paragraph::new().add_run(Run::new().add_text("a & b")))
                        .width(4500, WidthType::Dxa),
                    TableCell::new().width(4500, WidthType::Dxa),
                ])])
                .width(9000, WidthType::Dxa)
                .set_grid(vec![4500, 4500]),
            )
            .add_paragraph(
                Paragraph::new()
                    .page_break_before(true)
                    .indent(Some(360), None, None, None)
                    .add_run(Run::new().add_text("<Lampiran>\u{0007}")),
            )
    }

    #[test]
    fn document_xml_carries_text_formatting_and_escaping() {
        let xml = String::from_utf8(sample().build().document).unwrap();
        assert!(xml.contains(r#"<w:jc w:val="center"/>"#));
        assert!(xml.contains("<w:b/>"));
        assert!(xml.contains(r#"<w:sz w:val="32"/>"#));
        assert!(xml.contains(">a &amp; b<"));
        assert!(xml.contains("&lt;Lampiran&gt;"));
        assert!(!xml.contains('\u{0007}'), "control characters are dropped");
        assert!(xml.contains("<w:pageBreakBefore/>"));
        assert!(xml.contains(r#"<w:ind w:left="360"/>"#));
        assert!(xml.contains(&format!("cx=\"{}\"", 10 * 9525)));
        assert!(xml.contains(r#"r:embed="rIdImage1""#));
        // An empty cell still gets a paragraph.
        assert!(xml.contains(r#"<w:tcW w:w="4500" w:type="dxa"/></w:tcPr><w:p/></w:tc>"#));
    }

    #[test]
    fn packed_docx_has_every_part_word_needs() {
        let mut cursor = std::io::Cursor::new(Vec::new());
        sample().build().pack(&mut cursor).unwrap();
        let mut archive = zip::ZipArchive::new(std::io::Cursor::new(cursor.into_inner())).unwrap();
        for name in [
            "[Content_Types].xml",
            "_rels/.rels",
            "word/document.xml",
            "word/styles.xml",
            "word/_rels/document.xml.rels",
            "word/media/image1.png",
        ] {
            assert!(archive.by_name(name).is_ok(), "missing {name}");
        }
        let mut types = String::new();
        archive
            .by_name("[Content_Types].xml")
            .unwrap()
            .read_to_string(&mut types)
            .unwrap();
        assert!(types.contains(r#"Extension="png""#));
        let mut rels = String::new();
        archive
            .by_name("word/_rels/document.xml.rels")
            .unwrap()
            .read_to_string(&mut rels)
            .unwrap();
        assert!(rels.contains(r#"Id="rIdImage1""#));
        assert!(rels.contains(r#"Target="media/image1.png""#));
    }

    #[test]
    fn document_without_images_declares_no_png_type() {
        let mut cursor = std::io::Cursor::new(Vec::new());
        Docx::new()
            .add_paragraph(Paragraph::new().add_run(Run::new().add_text("x")))
            .build()
            .pack(&mut cursor)
            .unwrap();
        let mut archive = zip::ZipArchive::new(std::io::Cursor::new(cursor.into_inner())).unwrap();
        assert!(archive.by_name("word/media/image1.png").is_err());
        let mut types = String::new();
        archive
            .by_name("[Content_Types].xml")
            .unwrap()
            .read_to_string(&mut types)
            .unwrap();
        assert!(!types.contains("png"));
    }
}
