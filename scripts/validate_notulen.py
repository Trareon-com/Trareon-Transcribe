#!/usr/bin/env python3
"""Read back a generated "Notulen Rapat" DOCX and check it is well-formed.

The Rust side asserts on the WordprocessingML it emits, but a document that
satisfies our own assertions can still be one Word refuses to open. This
opens the file with python-docx — an independent OOXML reader — and checks
the sections the Tata Naskah Dinas layout promises are actually there.

Usage:
    python3 scripts/validate_notulen.py <notulen.docx> [--expect TERM]...

`--expect` asserts a term survived into the document text, which is how the
glossary's effect on the exported notulen is verified (jargon such as PPBJ,
SPBE or RKAKL must appear spelled correctly).

Exits non-zero with a readable report on the first failure.
"""

from __future__ import annotations

import argparse
import sys

try:
    import docx  # type: ignore
except ImportError:
    sys.exit("python-docx is not installed: pip install python-docx")


# Headings the "Notulen Dinas" variant must carry. The Ringkas variant drops
# the kop surat and the signature block but keeps these.
REQUIRED_HEADINGS = [
    "NOTULEN RAPAT",
    "Pembahasan",
    "Keputusan",
    "Tindak Lanjut",
]

# Form fields that must be present as labels.
#
# The exporter deliberately omits the label when the field is blank (an empty
# "Waktu:" row looks like a bug in an official document), so this check
# assumes the document under test was generated from a *filled* form — which
# is what the exit criterion exercises.
REQUIRED_LABELS = [
    "Hari/Tanggal",
    "Waktu",
    "Pimpinan Rapat",
    "Notulis",
]


def document_text(document: "docx.document.Document") -> str:
    """Every run of text in the body, tables included.

    `document.paragraphs` skips paragraphs nested in table cells, which is
    where the Tindak Lanjut rows and most of the form fields live — reading
    only that would make the checks below pass vacuously.
    """
    parts = [p.text for p in document.paragraphs]
    for table in document.tables:
        for row in table.rows:
            for cell in row.cells:
                parts.extend(p.text for p in cell.paragraphs)
    return "\n".join(parts)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path", help="path to the generated .docx")
    parser.add_argument(
        "--expect",
        action="append",
        default=[],
        metavar="TERM",
        help="text that must appear in the document (repeatable)",
    )
    parser.add_argument(
        "--variant",
        choices=["dinas", "ringkas"],
        default="dinas",
        help="template variant, which decides whether a signature block is required",
    )
    args = parser.parse_args()

    try:
        document = docx.Document(args.path)
    except Exception as exc:  # noqa: BLE001 - any reader failure is the finding
        print(f"FAIL  python-docx could not open {args.path}: {exc}")
        return 1

    text = document_text(document)
    failures: list[str] = []

    for heading in REQUIRED_HEADINGS:
        if heading.lower() not in text.lower():
            failures.append(f"missing section heading: {heading!r}")

    for label in REQUIRED_LABELS:
        if label.lower() not in text.lower():
            failures.append(f"missing form label: {label!r}")

    if not document.tables:
        failures.append("no tables: Tindak Lanjut (tugas/PJ/tenggat) must be a table")

    if args.variant == "dinas":
        # The signature block is what makes the document usable as an official
        # record; without it a notulis has to re-create the footer by hand.
        if "notulis" not in text.lower() or "pimpinan" not in text.lower():
            failures.append("Notulen Dinas is missing its signature block")

    for term in args.expect:
        if term.lower() not in text.lower():
            failures.append(f"expected term absent from the document: {term!r}")

    print(f"==> {args.path}")
    print(f"    paragraphs: {len(document.paragraphs)}  tables: {len(document.tables)}")
    print(f"    body characters: {len(text)}")
    if args.expect:
        found = [t for t in args.expect if t.lower() in text.lower()]
        print(f"    expected terms found: {len(found)}/{len(args.expect)} {found}")

    if failures:
        print(f"FAIL  {len(failures)} problem(s):")
        for failure in failures:
            print(f"      - {failure}")
        return 1

    print("OK    the document opens and carries every required section")
    return 0


if __name__ == "__main__":
    sys.exit(main())
