"""CLI for populating the benchmark's test sets.

    uv run python -m eval.fetch_sets --status
    uv run python -m eval.fetch_sets --set fleurs-id --clips 60
    uv run python -m eval.fetch_sets --public        # everything ungated

`--status` is the useful one: it prints which sets are ready, which are
waiting on credentials, and exactly what a human has to do about each —
without touching the network.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from collect.hf_sets import TEST_SETS, GatedDataset, describe_access, fetch

DATA_ROOT = Path(__file__).resolve().parents[1] / "data"


def show_status() -> None:
    print("Set uji Hugging Face\n")
    for row in describe_access():
        ready = (DATA_ROOT / row["name"] / "manifest.tsv").exists()
        print(f"  {row['name']:14} {'[terunduh]' if ready else '[belum   ]'} {row['status']}")
        print(f"      repo    : {row['repo']} [{row['config']}/{row['split']}]")
        print(f"      ucapan  : {row['domain']}")
        print(f"      lisensi : {row['licence_note']}")
        if row["training_caveat"]:
            print(f"      ⚠ latih : {row['training_caveat']}")
        if row["access_steps"] and not ready:
            for line in row["access_steps"].splitlines():
                print(f"      langkah : {line}")
        print()

    print("Set yang dibangun sendiri (ml/eval/build_sets.py):")
    for name in ("codeswitch-synth-id-en", "silence"):
        ready = (DATA_ROOT / name / "manifest.tsv").exists()
        print(f"  {name:24} {'[terbangun]' if ready else '[belum    ]'}")
    print("\nSet yang menunggu akses resmi (ml/collect/gov_sources.py):")
    for name in ("mk-holdout", "dpr-holdout"):
        ready = (DATA_ROOT / name / "manifest.tsv").exists()
        print(f"  {name:24} {'[siap]' if ready else '[TERBLOKIR - lihat laporan sprint]'}")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="eval.fetch_sets")
    parser.add_argument("--status", action="store_true", help="tampilkan status, tanpa jaringan")
    parser.add_argument("--set", action="append", default=[], help="nama set (boleh berulang)")
    parser.add_argument("--public", action="store_true", help="semua set yang tidak terkunci")
    parser.add_argument("--clips", type=int, default=40)
    parser.add_argument("--data-root", default=str(DATA_ROOT))
    args = parser.parse_args(argv)

    if args.status or (not args.set and not args.public):
        show_status()
        return 0

    names = list(args.set)
    if args.public:
        names += [name for name, item in TEST_SETS.items() if not item.gated]
    unknown = [name for name in names if name not in TEST_SETS]
    if unknown:
        print(f"set tidak dikenal: {unknown}; pilihan: {sorted(TEST_SETS)}", file=sys.stderr)
        return 2

    failures = 0
    for name in dict.fromkeys(names):
        test_set = TEST_SETS[name]
        print(f"\n== {name}")
        try:
            manifest = fetch(test_set, Path(args.data_root) / name, clips=args.clips)
            print(f"   -> {manifest}")
        except GatedDataset as error:
            failures += 1
            print(f"   TERKUNCI:\n{error}", file=sys.stderr)
        except Exception as error:
            failures += 1
            print(f"   GAGAL: {type(error).__name__}: {error}", file=sys.stderr)
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
