"""Building the two test sets this project constructs itself.

**Synthetic ID–EN code-switching.** The verified research says the
code-switching gap is the single largest accuracy problem for this app:
Whisper commits to one language token per 30-second window, and measured
Indonesian CER goes from 4.1% monolingual to 37.6% on synthetic
code-switching and above 80% on natural code-switching. No
openly-licensed ID–EN meeting corpus exists, so the owner-recorded set
in `ml/record_kit/` is the real answer — but it does not exist yet, and
a benchmark that simply omits its most important axis reports nothing
about it.

So this builds the *synthetic* version, by concatenating one Indonesian
and one English FLEURS utterance into a single clip whose reference is
both transcripts. Both halves are CC-BY 4.0 read speech, so the set is
redistributable and exactly reproducible from a seed.

What it does and does not measure, stated plainly because the number is
easy to misuse:

* It **does** measure whether a model survives a language switch inside
  one decoding window — the specific documented failure.
* It does **not** measure natural code-switching, which is intra-
  sentential ("jadi kita perlu align dulu sebelum deploy"), far harder,
  and the reason the recording kit exists. Expect natural code-switching
  to be much worse than this set suggests, not better.
* Concatenated read speech has an unnaturally clean boundary: no
  overlap, no disfluency at the switch, consistent channel per half.

**Silence.** A zero-reference set: the audio is silence, so every word a
model emits is an insertion and a WER of 0% means it did not
hallucinate. Whisper's silence hallucinations ("Terima kasih telah
menonton", bracketed tags) are a documented failure of this app's
domain, and `ml/eval/normalize.py` deliberately does not filter them,
so they land in the score where they belong.
"""

from __future__ import annotations

import random
import struct
import subprocess
import wave
from pathlib import Path

from common.atomic import write_text
from common.manifest import ManifestWriter, Record
from eval.runners import parse_manifest_tsv

#: Silence between the two halves. Long enough to be a clear boundary,
#: short enough that both halves stay inside one 30 s Whisper window —
#: which is the point of the set.
SWITCH_GAP_SECS = 0.4


def _ffmpeg(args: list[str]) -> None:
    completed = subprocess.run(
        ["ffmpeg", "-v", "error", "-y", *args],
        capture_output=True,
        text=True,
        check=False,
    )
    if completed.returncode != 0:
        raise RuntimeError(f"ffmpeg gagal: {completed.stderr.strip()[-400:]}")


def build_codeswitch(
    id_dir: str | Path,
    en_dir: str | Path,
    target_dir: str | Path,
    *,
    clips: int = 40,
    seed: int = 20261005,
    sample_rate: int = 16000,
    id_first: bool | None = None,
) -> Path:
    """Concatenate ID+EN FLEURS clips into a code-switching set.

    `id_first=None` alternates, so a model is tested on both switch
    directions; a set that always starts in Indonesian would let a model
    score well by locking onto the first language and would hide exactly
    the behaviour under test.
    """
    id_root, en_root, target = Path(id_dir), Path(en_dir), Path(target_dir)
    id_entries = parse_manifest_tsv(id_root / "manifest.tsv")
    en_entries = parse_manifest_tsv(en_root / "manifest.tsv")
    if not id_entries or not en_entries:
        raise RuntimeError("butuh manifest FLEURS id dan en; jalankan collect/hf_sets.py dulu")

    rng = random.Random(seed)
    id_pool = list(id_entries)
    en_pool = list(en_entries)
    rng.shuffle(id_pool)
    rng.shuffle(en_pool)

    audio_dir = target / "audio"
    audio_dir.mkdir(parents=True, exist_ok=True)
    writer = ManifestWriter(target / "manifest.jsonl")
    tsv_lines = [
        "# codeswitch-synth-id-en: FLEURS id_id + en_us digabung (CC-BY 4.0).",
        f"# Dibuat ml/eval/build_sets.py seed={seed}, jeda {SWITCH_GAP_SECS}s.",
        "# SINTETIS: mengukur peralihan bahasa dalam satu jendela dekode,",
        "# BUKAN code-switching alami intra-kalimat. Lihat docstring modul.",
    ]

    gap = audio_dir / "_gap.wav"
    _write_silence(gap, SWITCH_GAP_SECS, sample_rate)

    count = min(clips, len(id_pool), len(en_pool))
    written = 0
    for index in range(count):
        id_path, id_text = id_pool[index]
        en_path, en_text = en_pool[index]
        indonesian_first = (index % 2 == 0) if id_first is None else id_first

        first = (id_root / id_path, id_text) if indonesian_first else (en_root / en_path, en_text)
        second = (en_root / en_path, en_text) if indonesian_first else (id_root / id_path, id_text)
        if not first[0].exists() or not second[0].exists():
            continue

        name = f"{written:04d}.wav"
        output = audio_dir / name
        concat_list = audio_dir / f"_concat_{written:04d}.txt"
        concat_list.write_text(
            "\n".join(
                f"file '{path}'"
                for path in (first[0].resolve(), gap.resolve(), second[0].resolve())
            )
            + "\n",
            encoding="utf-8",
        )
        _ffmpeg(
            [
                "-f",
                "concat",
                "-safe",
                "0",
                "-i",
                str(concat_list),
                "-ac",
                "1",
                "-ar",
                str(sample_rate),
                str(output),
            ]
        )
        concat_list.unlink(missing_ok=True)

        reference = f"{first[1]} {second[1]}".strip()
        writer.add(
            Record(
                id=f"codeswitch-synth-id-en:{written:04d}",
                source="codeswitch-synth-id-en",
                url="https://huggingface.co/datasets/google/fleurs",
                audio_path=f"audio/{name}",
                duration=_wav_seconds(output),
                licence_note="CC-BY 4.0 (FLEURS id_id + en_us, digabung)",
                extra={
                    "reference": reference,
                    "order": "id-en" if indonesian_first else "en-id",
                    "id_clip": id_path,
                    "en_clip": en_path,
                    "synthetic": True,
                },
            )
        )
        tsv_lines.append(f"audio/{name}\t{reference.replace(chr(9), ' ')}")
        written += 1

    gap.unlink(missing_ok=True)
    if written == 0:
        raise RuntimeError("tidak ada klip code-switching yang bisa dibuat")
    write_text(target / "manifest.tsv", "\n".join(tsv_lines) + "\n")
    write_text(target / ".gitignore", "*\n")
    return target / "manifest.tsv"


def build_silence(
    target_dir: str | Path,
    *,
    clips: int = 12,
    seconds: float = 30.0,
    sample_rate: int = 16000,
) -> Path:
    """A zero-reference set of silent clips.

    30 seconds per clip because that is exactly one Whisper window, which
    is where the hallucination appears. The reference is the empty
    string, so `eval/wer.py` scores every emitted word as an insertion
    and a clean run is 0%.
    """
    target = Path(target_dir)
    audio_dir = target / "audio"
    audio_dir.mkdir(parents=True, exist_ok=True)
    writer = ManifestWriter(target / "manifest.jsonl")
    tsv_lines = [
        # The directive rust_core's parse_manifest needs before it will
        # accept a blank reference. Without it an empty reference is an
        # error, which is the right default for an ordinary corpus.
        "# allow-empty-reference",
        "# silence: klip hening buatan sendiri.",
        f"# {clips} klip x {seconds}s @ {sample_rate} Hz (satu jendela Whisper).",
        "# Acuan KOSONG: setiap kata yang keluar adalah sisipan.",
        "# WER 0% = model tidak berhalusinasi pada keheningan.",
    ]
    for index in range(clips):
        name = f"{index:04d}.wav"
        path = audio_dir / name
        _write_silence(path, seconds, sample_rate)
        writer.add(
            Record(
                id=f"silence:{index:04d}",
                source="silence",
                url="",
                audio_path=f"audio/{name}",
                duration=seconds,
                licence_note="Dibuat sendiri - tanpa hak pihak ketiga",
                extra={"reference": "", "purpose": "uji halusinasi"},
            )
        )
        # The empty reference is the point; the tab must still be there
        # or the manifest parser rejects the line.
        tsv_lines.append(f"audio/{name}\t")
    write_text(target / "manifest.tsv", "\n".join(tsv_lines) + "\n")
    write_text(target / ".gitignore", "*\n")
    return target / "manifest.tsv"


def _write_silence(path: Path, seconds: float, sample_rate: int) -> None:
    frames = int(seconds * sample_rate)
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(sample_rate)
        handle.writeframes(struct.pack(f"<{frames}h", *([0] * frames)))


def _wav_seconds(path: Path) -> float:
    with wave.open(str(path), "rb") as handle:
        rate = handle.getframerate()
        return handle.getnframes() / rate if rate else 0.0


def main(argv: list[str] | None = None) -> int:
    import argparse

    root = Path(__file__).resolve().parents[1] / "data"
    parser = argparse.ArgumentParser(prog="eval.build_sets")
    parser.add_argument("--data-root", default=str(root))
    parser.add_argument("--codeswitch-clips", type=int, default=40)
    parser.add_argument("--silence-clips", type=int, default=12)
    parser.add_argument("--skip-codeswitch", action="store_true")
    parser.add_argument("--skip-silence", action="store_true")
    args = parser.parse_args(argv)

    data = Path(args.data_root)
    if not args.skip_codeswitch:
        manifest = build_codeswitch(
            data / "fleurs-id",
            data / "fleurs-en",
            data / "codeswitch-synth-id-en",
            clips=args.codeswitch_clips,
        )
        print(f"codeswitch-synth-id-en -> {manifest}")
    if not args.skip_silence:
        manifest = build_silence(data / "silence", clips=args.silence_clips)
        print(f"silence -> {manifest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
