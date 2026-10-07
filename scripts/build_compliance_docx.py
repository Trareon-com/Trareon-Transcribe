#!/usr/bin/env python3
"""Render docs/compliance/*.md to DOCX for circulation.

Why a converter rather than pandoc: the compliance pack goes to
procurement committees who want .docx, and a build step that depends on
pandoc being installed is a build step that stops working. python-docx is
the only dependency, and it is the one already present on the build host.

Run with the system interpreter, not a sandbox venv::

    /usr/bin/python3 scripts/build_compliance_docx.py

Markdown is the source of truth. The DOCX files are derived artifacts —
regenerate them, never edit them.

Supported Markdown: ATX headings, paragraphs, ``-``/``*`` and ordered
lists, pipe tables, fenced code blocks, blockquotes, horizontal rules,
and inline ``**bold**``, ``*italic*``, ``` `code` ``` and
``[text](link)``. That is the subset the pack actually uses; anything
else falls through as plain text rather than being silently dropped.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

try:
    from docx import Document
    from docx.enum.table import WD_TABLE_ALIGNMENT
    from docx.enum.text import WD_ALIGN_PARAGRAPH
    from docx.oxml.ns import qn
    from docx.shared import Pt, RGBColor
except ImportError:  # pragma: no cover - environment problem, not logic
    sys.exit(
        "python-docx tidak tersedia. Pasang dengan:\n"
        "  /usr/bin/python3 -m pip install --user python-docx"
    )

REPO_ROOT = Path(__file__).resolve().parent.parent
SOURCE_DIR = REPO_ROOT / "docs" / "compliance"
OUTPUT_DIR = SOURCE_DIR / "docx"

#: Order matters: it is the order a reader should meet the documents in,
#: and it becomes the order of the generated file list in the log.
DOCUMENTS = (
    "Ringkasan-Kepatuhan-untuk-Pengadaan.md",
    "README.md",
    "PEMETAAN-UU-PDP-27-2022.md",
    "PEMETAAN-ISO-27001-27701.md",
    "ALUR-DATA.md",
    "TEMPLAT-DPIA.md",
    "PROSEDUR-RETENSI-DAN-PENGHAPUSAN.md",
)

MONO = "Consolas"

_INLINE = re.compile(
    r"(\*\*.+?\*\*"  # bold
    r"|`[^`]+`"  # code
    r"|\[[^\]]+\]\([^)]+\)"  # link
    r"|\*[^*]+\*)"  # italic
)


def add_inline(paragraph, text: str) -> None:
    """Append ``text`` to ``paragraph``, honouring inline Markdown."""
    for piece in _INLINE.split(text):
        if not piece:
            continue
        if piece.startswith("**") and piece.endswith("**") and len(piece) > 4:
            paragraph.add_run(piece[2:-2]).bold = True
        elif piece.startswith("`") and piece.endswith("`") and len(piece) > 2:
            run = paragraph.add_run(piece[1:-1])
            run.font.name = MONO
            run.font.size = Pt(9)
        elif piece.startswith("[") and "](" in piece:
            label, _, target = piece[1:-1].partition("](")
            run = paragraph.add_run(label)
            run.font.color.rgb = RGBColor(0x1E, 0x40, 0xAF)
            run.underline = True
            # The target is kept as visible text rather than a real
            # hyperlink relationship: most targets are sibling Markdown
            # files whose DOCX counterparts live in docx/, so a clickable
            # link would point at a file the reader does not have.
            if target.startswith("http"):
                paragraph.add_run(f" ({target})").font.size = Pt(8)
        elif piece.startswith("*") and piece.endswith("*") and len(piece) > 2:
            paragraph.add_run(piece[1:-1]).italic = True
        else:
            paragraph.add_run(piece)


def split_row(line: str) -> list[str]:
    return [cell.strip() for cell in line.strip().strip("|").split("|")]


def is_separator(line: str) -> bool:
    cells = split_row(line)
    return bool(cells) and all(re.fullmatch(r":?-{2,}:?", c) for c in cells)


def add_table(document, rows: list[list[str]]) -> None:
    """Render a pipe table. First row is the header."""
    width = max(len(r) for r in rows)
    table = document.add_table(rows=0, cols=width)
    table.style = "Table Grid"
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    for index, row in enumerate(rows):
        cells = table.add_row().cells
        for column in range(width):
            text = row[column] if column < len(row) else ""
            paragraph = cells[column].paragraphs[0]
            # Markdown line breaks inside a cell are written as <br/>.
            for part_index, part in enumerate(re.split(r"<br\s*/?>", text)):
                if part_index:
                    paragraph = cells[column].add_paragraph()
                paragraph.paragraph_format.space_after = Pt(2)
                add_inline(paragraph, part.strip())
                for run in paragraph.runs:
                    run.font.size = Pt(9)
                    if index == 0:
                        run.bold = True


def add_code(document, lines: list[str], language: str) -> None:
    if language == "mermaid":
        note = document.add_paragraph()
        run = note.add_run(
            "Diagram mermaid — lihat versi Markdown untuk tampilan "
            "tergambar. Sumber diagram:"
        )
        run.italic = True
        run.font.size = Pt(9)
    for line in lines:
        paragraph = document.add_paragraph()
        paragraph.paragraph_format.space_after = Pt(0)
        paragraph.paragraph_format.left_indent = Pt(18)
        run = paragraph.add_run(line if line else " ")
        run.font.name = MONO
        run.font.size = Pt(8)
        # python-docx sets only the latin font; east-asian has to be set
        # on the rPr directly or Word falls back for part of the run.
        run._element.rPr.rFonts.set(qn("w:eastAsia"), MONO)


def add_quote(document, lines: list[str]) -> None:
    paragraph = document.add_paragraph()
    paragraph.paragraph_format.left_indent = Pt(24)
    paragraph.paragraph_format.space_before = Pt(6)
    paragraph.paragraph_format.space_after = Pt(6)
    add_inline(paragraph, " ".join(lines))
    for run in paragraph.runs:
        run.font.size = Pt(10)
        if not run.bold:
            run.italic = True


def convert(path: Path, output: Path) -> None:
    document = Document()
    normal = document.styles["Normal"]
    normal.font.name = "Calibri"
    normal.font.size = Pt(10.5)

    lines = path.read_text(encoding="utf-8").splitlines()
    index = 0
    pending_quote: list[str] = []
    seen_title = False

    def flush_quote() -> None:
        if pending_quote:
            add_quote(document, list(pending_quote))
            pending_quote.clear()

    while index < len(lines):
        line = lines[index]

        if line.startswith(">"):
            stripped = line[1:].strip()
            if stripped:
                pending_quote.append(stripped)
            elif pending_quote:
                flush_quote()
            index += 1
            continue
        flush_quote()

        if line.startswith("```"):
            language = line[3:].strip()
            block: list[str] = []
            index += 1
            while index < len(lines) and not lines[index].startswith("```"):
                block.append(lines[index])
                index += 1
            index += 1
            add_code(document, block, language)
            continue

        heading = re.match(r"^(#{1,6})\s+(.*)$", line)
        if heading:
            level = len(heading.group(1))
            text = heading.group(2).strip()
            if level == 1 and not seen_title:
                paragraph = document.add_heading("", level=0)
                add_inline(paragraph, text)
                seen_title = True
            else:
                paragraph = document.add_heading("", level=min(level, 4))
                add_inline(paragraph, text)
            index += 1
            continue

        if re.fullmatch(r"\s*([-*_])\s*(\1\s*){2,}", line):
            rule = document.add_paragraph()
            rule.alignment = WD_ALIGN_PARAGRAPH.CENTER
            run = rule.add_run("· · ·")
            run.font.size = Pt(9)
            index += 1
            continue

        if line.strip().startswith("|"):
            rows: list[list[str]] = []
            while index < len(lines) and lines[index].strip().startswith("|"):
                if not is_separator(lines[index]):
                    rows.append(split_row(lines[index]))
                index += 1
            if rows:
                add_table(document, rows)
                document.add_paragraph().paragraph_format.space_after = Pt(2)
            continue

        bullet = re.match(r"^(\s*)[-*]\s+(.*)$", line)
        if bullet:
            depth = len(bullet.group(1)) // 2
            style = "List Bullet" if depth == 0 else "List Bullet 2"
            paragraph = document.add_paragraph(style=style)
            add_inline(paragraph, bullet.group(2))
            index += 1
            continue

        ordered = re.match(r"^(\s*)\d+[.)]\s+(.*)$", line)
        if ordered:
            depth = len(ordered.group(1)) // 2
            style = "List Number" if depth == 0 else "List Number 2"
            paragraph = document.add_paragraph(style=style)
            add_inline(paragraph, ordered.group(2))
            index += 1
            continue

        if not line.strip():
            index += 1
            continue

        # Soft-wrapped paragraph: join until a blank line or a construct.
        body = [line.strip()]
        index += 1
        while index < len(lines):
            nxt = lines[index]
            if not nxt.strip() or re.match(r"^\s*([-*+]\s|\d+[.)]\s|#|>|\||```)", nxt):
                break
            body.append(nxt.strip())
            index += 1
        paragraph = document.add_paragraph()
        add_inline(paragraph, " ".join(body))

    flush_quote()
    output.parent.mkdir(parents=True, exist_ok=True)
    # Atomic: a half-written DOCX that Word refuses to open is worse than
    # no DOCX, and this runs over a directory of them.
    temporary = output.with_suffix(".docx.tmp")
    document.save(temporary)
    temporary.replace(output)


def main() -> int:
    if not SOURCE_DIR.is_dir():
        sys.exit(f"{SOURCE_DIR} tidak ada")
    missing = [name for name in DOCUMENTS if not (SOURCE_DIR / name).is_file()]
    if missing:
        sys.exit(f"berkas sumber tidak ada: {missing}")

    for name in DOCUMENTS:
        source = SOURCE_DIR / name
        target = OUTPUT_DIR / (source.stem + ".docx")
        convert(source, target)
        print(f"{source.relative_to(REPO_ROOT)} -> {target.relative_to(REPO_ROOT)}")
    print(f"{len(DOCUMENTS)} berkas DOCX dihasilkan di {OUTPUT_DIR.relative_to(REPO_ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
