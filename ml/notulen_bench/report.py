"""Aggregate the JSONL into the table that goes into NOTULEN-BENCHMARK.md.

Reports per model: the composite, each metric that feeds it, ROUGE as
context, latency, and the resident footprint. Also reports how many cases
each average is over — a model that failed half the set and scored well on
the rest has not won, and an average that hides the denominator would let
it.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from . import models
from .run import RESULTS_FILE


def load_records(path: Path) -> list[dict]:
    if not path.is_file():
        raise SystemExit(f"{path} belum ada — jalankan notulen_bench.run dulu")
    out: list[dict] = []
    with path.open(encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            try:
                out.append(json.loads(line))
            except json.JSONDecodeError:
                continue
    return out


def _mean(values: list[float]) -> float:
    return sum(values) / len(values) if values else 0.0


def summarise(records: list[dict]) -> list[dict]:
    """One row per model, newest record per (model, case) winning."""
    latest: dict[tuple[str, str], dict] = {}
    for record in records:
        latest[(record.get("model", ""), record.get("case_id", ""))] = record

    by_model: dict[str, list[dict]] = {}
    for (model, _), record in latest.items():
        by_model.setdefault(model, []).append(record)

    rows = []
    for model, items in by_model.items():
        ok = [r for r in items if r.get("ok")]
        row = {
            "model": model,
            "cases": len(items),
            "ok": len(ok),
            "composite": _mean([_composite(r) for r in ok]),
            "structure": _mean([r["structure"] for r in ok]),
            "faithfulness": _mean([r["faithfulness"] for r in ok]),
            "citation_accuracy": _mean([r.get("citation_accuracy", 0.0) for r in ok]),
            "invented_decisions": sum(r.get("invented_decisions", 0) for r in ok),
            "formality": _mean([r["formality"] for r in ok]),
            "action_f1": _mean([r["action_f1"] for r in ok]),
            "owner_accuracy": _mean([r["owner_accuracy"] for r in ok]),
            "rouge1": _mean([r["rouge1"] for r in ok]),
            "rouge2": _mean([r["rouge2"] for r in ok]),
            "rougel": _mean([r["rougel"] for r in ok]),
            "seconds": _mean([r["seconds"] for r in ok]),
            "tps": _mean([r["tokens_per_second"] for r in ok if r["tokens_per_second"]]),
            "repairs": _mean([float(len(r.get("repairs", []))) for r in ok]),
            "size_bytes": max([r.get("size_bytes", 0) for r in items] or [0]),
            "size_vram_bytes": max([r.get("size_vram_bytes", 0) for r in items] or [0]),
            "host": next((r.get("host", "") for r in items if r.get("host")), ""),
        }
        rows.append(row)
    rows.sort(key=lambda r: (-r["composite"], r["seconds"]))
    return rows


def _composite(record: dict) -> float:
    """Recompute from the stored metrics rather than trusting the field.

    The weights are part of the report, not of the data: changing them
    must not require re-running hours of inference.
    """
    return (
        0.35 * record.get("faithfulness", 0.0)
        + 0.25 * record.get("structure", 0.0)
        + 0.20 * record.get("action_f1", 0.0)
        + 0.20 * record.get("formality", 0.0)
    )


def _gib(value: int) -> str:
    return f"{value / 1024**3:.1f}" if value else "—"


def main_table(rows: list[dict]) -> str:
    head = (
        "| Model | Komposit | Struktur | Faithful | Sitasi | Formal "
        "| Tindak lanjut F1 | PJ benar | Keputusan dikarang | ROUGE-1 | ROUGE-L "
        "| Detik/rapat | tok/s | Kasus ok |\n"
        "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|\n"
    )
    lines = []
    for row in rows:
        candidate = models.by_tag(row["model"])
        label = candidate.label if candidate else row["model"]
        lines.append(
            f"| {label} | **{row['composite']:.3f}** | {row['structure']:.3f} "
            f"| {row['faithfulness']:.3f} | {row['citation_accuracy']:.3f} "
            f"| {row['formality']:.3f} "
            f"| {row['action_f1']:.3f} | {row['owner_accuracy']:.3f} "
            f"| {row['invented_decisions']} "
            f"| {row['rouge1']:.3f} | {row['rougel']:.3f} "
            f"| {row['seconds']:.0f} | {row['tps']:.1f} "
            f"| {row['ok']}/{row['cases']} |"
        )
    return head + "\n".join(lines) + "\n"


def footprint_table(rows: list[dict]) -> str:
    head = (
        "| Model | Parameter | Kuantisasi | Konteks | Lisensi | Boleh dibundel? "
        "| Residen (GiB) | di VRAM (GiB) |\n"
        "|---|---|---|---|---|---|---|---|\n"
    )
    lines = []
    for row in rows:
        candidate = models.by_tag(row["model"])
        if candidate is None:
            lines.append(
                f"| {row['model']} | — | — | — | — | — "
                f"| {_gib(row['size_bytes'])} | {_gib(row['size_vram_bytes'])} |"
            )
            continue
        lines.append(
            f"| {candidate.label} | {candidate.params} | {candidate.quant} "
            f"| {candidate.context:,} tok | {candidate.licence} "
            f"| {'ya' if candidate.commercial_ok else 'perlu kajian hukum'} "
            f"| {_gib(row['size_bytes'])} | {_gib(row['size_vram_bytes'])} |"
        )
    return head + "\n".join(lines) + "\n"


def failure_notes(records: list[dict]) -> str:
    """Every failed case, so no average hides a model that cannot parse."""
    failures = [r for r in records if not r.get("ok")]
    if not failures:
        return "Tidak ada kasus yang gagal diparsing.\n"
    lines = ["| Model | Kasus | Kegagalan |", "|---|---|---|"]
    for record in failures:
        error = str(record.get("error", "")).replace("|", "/")[:140]
        lines.append(f"| {record.get('model')} | {record.get('case_id')} | {error} |")
    return "\n".join(lines) + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Ringkas hasil bake-off notulen.")
    parser.add_argument("--results", type=Path, default=RESULTS_FILE)
    parser.add_argument("--out", type=Path, default=None, help="Tulis tabel ke berkas.")
    args = parser.parse_args(argv)

    records = load_records(args.results)
    rows = summarise(records)
    text = (
        "## Hasil utama\n\n"
        + main_table(rows)
        + "\n## Ukuran, lisensi, dan jejak memori\n\n"
        + footprint_table(rows)
        + "\n## Kasus yang gagal\n\n"
        + failure_notes(records)
    )
    hosts = sorted({r.get("host", "") for r in records if r.get("host")})
    if hosts:
        text += f"\nDiukur pada: {', '.join(hosts)}\n"
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(text, encoding="utf-8")
    print(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
