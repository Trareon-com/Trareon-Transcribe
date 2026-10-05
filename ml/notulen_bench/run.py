"""Run the bake-off. Resumable, budgeted, one JSONL record per attempt.

Why resumable rather than one long run: six models over two dozen
meetings is hours of inference, and anything that long gets interrupted —
a dropped SSH session, a machine that sleeps, a model that has to be
re-pulled. Each (model, case) pair is written to the JSONL as soon as it
finishes, and a second invocation skips what is already there. ``--budget``
stops cleanly on a time limit so the run can be driven in slices.

::

    python -m notulen_bench.run --host http://127.0.0.1:11434 --budget 900
    python -m notulen_bench.run --models qwen3:4b --cases 01-rakor-pagu
    python -m notulen_bench.report
"""

from __future__ import annotations

import argparse
import json
import os
import platform
import sys
import time
from dataclasses import asdict
from pathlib import Path

from . import dataset, metrics, models, ollama, schema

PACKAGE_DIR = Path(__file__).resolve().parent
PROMPT_DIR = PACKAGE_DIR / "prompts"
RESULTS_DIR = PACKAGE_DIR / "results"
RESULTS_FILE = RESULTS_DIR / "results.jsonl"
RAW_DIR = RESULTS_DIR / "raw"

#: Substituted into the mirrored user prompt. Must match
#: ``prompt.rs``'s `TRANSCRIPT_SLOT`.
TRANSCRIPT_SLOT = "<<TRANSKRIP>>"


def load_prompt(templat: str, kind: str) -> str:
    path = PROMPT_DIR / f"{templat}.{kind}.txt"
    if not path.is_file():
        raise SystemExit(
            f"{path} tidak ada. Hasilkan dari rust_core:\n"
            "  TRAREON_DUMP_PROMPTS=1 cargo test --lib notulen::prompt"
        )
    return path.read_text(encoding="utf-8").rstrip("\n")


def done_pairs(path: Path) -> set[tuple[str, str]]:
    """``(model, case_id)`` pairs already recorded."""
    if not path.is_file():
        return set()
    pairs: set[tuple[str, str]] = set()
    with path.open(encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            try:
                record = json.loads(line)
            except json.JSONDecodeError:
                # A run killed mid-write leaves one torn line. Dropping it
                # re-runs one pair, which is cheaper than refusing to
                # resume at all.
                continue
            pairs.add((record.get("model", ""), record.get("case_id", "")))
    return pairs


def append_record(path: Path, record: dict) -> None:
    """Append one JSONL record and flush it to disk.

    Flushed per record on purpose: the point of the JSONL is that an
    interrupted run keeps everything it had already paid for.
    """
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(record, ensure_ascii=False) + "\n")
        handle.flush()
        os.fsync(handle.fileno())


def host_description() -> str:
    """What the latency numbers were measured on."""
    bits = [platform.system(), platform.machine(), f"python {platform.python_version()}"]
    return " / ".join(b for b in bits if b)


#: Context sizes to pick from, smallest first.
_CTX_STEPS = (4096, 8192, 12288, 16384, 24576, 32768)

#: Indonesian characters per token, measured over this set's prompts
#: against Ollama's reported `prompt_eval_count`.
_CHARS_PER_TOKEN = 3.0


def context_for(case: dataset.Case, requested: int) -> int:
    """Smallest context window that fits this meeting's prompt and answer.

    Sizing this per case is not a micro-optimisation. Ollama allocates
    the KV cache for the whole `num_ctx` up front, so asking for 16K on a
    6 GB card pushes transformer layers back onto the CPU: measured on
    `01-rakor-pagu` with qwen3:4b, 16K took 229 s and 8K took 37 s for
    the same prompt and a near-identical score. A fixed large context
    would have made every model in the table look six times slower than
    it is.
    """
    if requested:
        return requested
    needed = int((len(case.numbered_transcript) + 3000) / _CHARS_PER_TOKEN) + 2000
    return next((size for size in _CTX_STEPS if needed <= size), _CTX_STEPS[-1])


def run_one(
    case: dataset.Case,
    tag: str,
    host: str,
    timeout: float,
    num_ctx: int,
) -> tuple[metrics.CaseScore, ollama.ChatResult, str]:
    """One model, one meeting. Returns the score, the round trip, the raw text."""
    system = load_prompt(case.templat, "system")
    user = load_prompt(case.templat, "user").replace(TRANSCRIPT_SLOT, case.numbered_transcript)

    result = ollama.chat(
        tag, system, user, host=host, timeout=timeout, num_ctx=context_for(case, num_ctx)
    )
    if not result.ok:
        return (
            metrics.CaseScore(case_id=case.id, model=tag, ok=False, error=result.error),
            result,
            "",
        )

    parsed = schema.parse(result.content)
    if not parsed.ok:
        return (
            metrics.CaseScore(case_id=case.id, model=tag, ok=False, error=parsed.error),
            result,
            result.content,
        )

    score = metrics.score_case(case, tag, parsed.notulen, parsed.perbaikan)
    score.seconds = result.seconds
    score.tokens_per_second = result.tokens_per_second
    return score, result, result.content


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Bake-off LLM notulen (Ollama).")
    parser.add_argument("--host", default=ollama.DEFAULT_HOST)
    parser.add_argument(
        "--models",
        nargs="*",
        default=[c.tag for c in models.CANDIDATES],
        help="Ollama tags; default is the whole candidate set.",
    )
    parser.add_argument("--cases", nargs="*", default=None, help="Case ids; default is all.")
    parser.add_argument(
        "--budget",
        type=float,
        default=0.0,
        help="Stop cleanly after this many seconds (0 = no limit).",
    )
    parser.add_argument("--timeout", type=float, default=1800.0, help="Per-request timeout.")
    parser.add_argument(
        "--num-ctx",
        type=int,
        default=0,
        help="Context window; 0 sizes it per case (see context_for).",
    )
    parser.add_argument("--out", type=Path, default=RESULTS_FILE)
    parser.add_argument(
        "--redo", action="store_true", help="Ignore existing records and re-run everything."
    )
    parser.add_argument(
        "--list", action="store_true", help="Print the pending work and exit."
    )
    args = parser.parse_args(argv)

    cases = dataset.load_cases()
    if args.cases:
        wanted = set(args.cases)
        cases = [c for c in cases if c.id in wanted]
        unknown = wanted - {c.id for c in cases}
        if unknown:
            raise SystemExit(f"kasus tidak ditemukan: {sorted(unknown)}")
    if not cases:
        raise SystemExit("tidak ada kasus di data/")

    already = set() if args.redo else done_pairs(args.out)
    # Model-major order: each model is loaded once, evaluated on every
    # meeting, then evicted. Case-major order would reload six models per
    # meeting and measure the loader.
    pending = [
        (tag, case)
        for tag in args.models
        for case in cases
        if (tag, case.id) not in already
    ]

    if args.list:
        print(
            f"{len(pending)} pasangan tertunda dari "
            f"{len(args.models)} model × {len(cases)} kasus"
        )
        for tag, case in pending:
            print(f"  {tag}  {case.id}")
        return 0

    installed = set(ollama.installed_models(args.host))
    if not installed:
        raise SystemExit(f"Ollama di {args.host} tidak menjawab /api/tags")
    missing = [t for t in args.models if t not in installed]
    if missing:
        print(f"[peringatan] belum diunduh, akan dilewati: {missing}", file=sys.stderr)
        pending = [(t, c) for t, c in pending if t not in missing]

    started = time.monotonic()
    current_model = None
    completed = 0
    for tag, case in pending:
        if args.budget and time.monotonic() - started > args.budget:
            print(
                f"[anggaran] berhenti setelah {completed} pasangan; "
                f"{len(pending) - completed} tersisa",
                file=sys.stderr,
            )
            break
        if tag != current_model:
            if current_model is not None:
                ollama.unload(current_model, args.host)
            current_model = tag

        score, result, raw = run_one(case, tag, args.host, args.timeout, args.num_ctx)
        footprint = ollama.loaded_footprint(args.host).get(tag, {})
        record = asdict(score)
        record.update(
            {
                "templat": case.templat,
                "menit": case.menit,
                "ciri": case.ciri,
                "num_ctx": context_for(case, args.num_ctx),
                "prompt_tokens": result.prompt_tokens,
                "eval_tokens": result.eval_tokens,
                "thinking_disabled": result.thinking_disabled,
                "size_bytes": footprint.get("size_bytes", 0),
                "size_vram_bytes": footprint.get("size_vram_bytes", 0),
                "host": host_description(),
                "recorded_at": time.strftime("%Y-%m-%dT%H:%M:%S"),
            }
        )
        append_record(args.out, record)

        RAW_DIR.mkdir(parents=True, exist_ok=True)
        slug = tag.replace("/", "_").replace(":", "_")
        (RAW_DIR / f"{slug}__{case.id}.txt").write_text(raw, encoding="utf-8")

        completed += 1
        status = "ok" if score.ok else f"GAGAL: {score.error[:80]}"
        print(
            f"{tag:60s} {case.id:24s} {score.seconds:7.1f}s "
            f"komposit={score.composite:.3f} {status}",
            flush=True,
        )

    if current_model is not None:
        ollama.unload(current_model, args.host)
    print(f"selesai: {completed} pasangan")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
