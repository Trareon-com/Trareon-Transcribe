"""Getting a hypothesis out of a model.

Two runners, and the first one is the one that matters:

* `GgmlRunner` drives `rust_core`'s `wer_bench` binary — the same
  `WhisperEngine` the shipped app uses, with the same decoding options.
  Its numbers are what a user gets, including the RTF, which is the
  figure the live-model fallback keys off. Prefer it.
* `TransformersRunner` loads a Hugging Face model directly. Needed for
  anything not converted to GGML (`cahya/whisper-medium-id`) and for
  evaluating a LoRA checkpoint before it is merged and exported, but its
  RTF describes PyTorch on this machine, not the app.

Both return the same `ClipResult`, so `eval/harness.py` scores them
identically. A model that fails on a clip returns an empty hypothesis
with `failed=True` rather than being skipped: a model that cannot decode
a file has not scored 0% on it.
"""

from __future__ import annotations

import json
import subprocess
import time
import wave
from dataclasses import dataclass
from pathlib import Path
from typing import Protocol


@dataclass
class ClipResult:
    clip: str
    hypothesis: str
    audio_secs: float
    elapsed_secs: float
    failed: bool = False


class Runner(Protocol):
    """What the harness needs from a model."""

    @property
    def label(self) -> str: ...

    @property
    def kind(self) -> str: ...

    def run(self, manifest: Path, *, limit: int | None = None) -> list[ClipResult]: ...


class RunnerFailed(RuntimeError):
    pass


def parse_manifest_tsv(path: str | Path) -> list[tuple[str, str]]:
    """Read `path<TAB>reference` lines.

    A line without a tab is an error, not a skipped clip: a manifest
    that quietly measures fewer clips than it lists produces a number
    nobody can reproduce. (Same rule as `wer_bench`'s parser, so the two
    always agree on what the corpus is.)
    """
    entries: list[tuple[str, str]] = []
    for number, line in enumerate(Path(path).read_text(encoding="utf-8").splitlines(), start=1):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if "\t" not in line:
            raise ValueError(f"{path}: baris {number} tidak punya tab pemisah")
        audio, reference = line.split("\t", 1)
        entries.append((audio.strip(), reference.strip()))
    return entries


def wav_duration(path: str | Path) -> float:
    """Duration of a WAV file, or 0.0 when it cannot be read.

    Used only for the transformers runner; the GGML runner reports the
    duration the engine itself decoded, which is the honest number for
    a non-WAV input.
    """
    try:
        with wave.open(str(path), "rb") as handle:
            rate = handle.getframerate()
            return handle.getnframes() / rate if rate else 0.0
    except (OSError, wave.Error):
        return 0.0


# -- the app's own engine ----------------------------------------------


@dataclass
class GgmlRunner:
    """Drives `wer_bench`, which drives the app's `WhisperEngine`."""

    model_path: Path
    binary: Path
    language: str = "id"
    gpu: bool = False
    timeout: float = 14400.0
    name: str | None = None

    @property
    def label(self) -> str:
        return self.name or self.model_path.stem

    @property
    def kind(self) -> str:
        return "ggml/rust-cli"

    def run(self, manifest: Path, *, limit: int | None = None) -> list[ClipResult]:
        args = [
            str(self.binary),
            "--manifest",
            str(manifest),
            "--model",
            str(self.model_path),
            "--language",
            self.language,
            "--json",
        ]
        if self.gpu:
            args.append("--gpu")
        if limit is not None:
            args += ["--limit", str(limit)]

        completed = subprocess.run(
            args, capture_output=True, text=True, timeout=self.timeout, check=False
        )
        if completed.returncode != 0:
            raise RunnerFailed(
                f"wer_bench gagal untuk {self.label}: {completed.stderr.strip()[-600:]}"
            )

        payload = _extract_json_array(completed.stdout)
        if not payload:
            raise RunnerFailed(f"wer_bench tidak mengeluarkan JSON untuk {self.label}")

        results: list[ClipResult] = []
        for model_score in payload:
            for clip in model_score.get("clips", []):
                hypothesis = clip.get("hypothesis") or ""
                audio_secs = float(clip.get("audio_secs") or 0.0)
                results.append(
                    ClipResult(
                        clip=clip.get("clip", ""),
                        hypothesis=hypothesis,
                        audio_secs=audio_secs,
                        elapsed_secs=float(clip.get("elapsed_secs") or 0.0),
                        # wer_bench records a decode failure as a clip
                        # with no audio and no text.
                        failed=not hypothesis and audio_secs == 0.0,
                    )
                )
        return results


def _extract_json_array(stdout: str) -> list[dict]:
    """Pull the JSON array out of `wer_bench`'s output.

    It prints the Markdown table first and the JSON after, so the array
    starts at the first line that is exactly `[`.
    """
    lines = stdout.splitlines()
    for index, line in enumerate(lines):
        if line.rstrip() == "[":
            try:
                return json.loads("\n".join(lines[index:]))
            except json.JSONDecodeError:
                continue
    return []


# -- Hugging Face models -----------------------------------------------


@dataclass
class TransformersRunner:
    """Loads a Whisper-family model with `transformers`.

    Lazy: the model is loaded on the first `run` so that constructing a
    benchmark plan costs nothing. `adapter` points at a PEFT LoRA
    directory, which is how a fine-tune is evaluated before the merge
    and GGML export.
    """

    model_id: str
    language: str = "id"
    device: str = "cpu"
    adapter: str | None = None
    #: 25 s matches the training config's clip ceiling.
    chunk_length_s: float = 25.0
    name: str | None = None

    _pipe: object = None

    @property
    def label(self) -> str:
        if self.name:
            return self.name
        return f"{self.model_id}+lora" if self.adapter else self.model_id

    @property
    def kind(self) -> str:
        return f"transformers/{self.device}"

    def _ensure_loaded(self) -> object:
        if self._pipe is not None:
            return self._pipe
        try:
            import torch
            from transformers import (
                AutomaticSpeechRecognitionPipeline,
                WhisperForConditionalGeneration,
                WhisperProcessor,
            )
        except ImportError as error:  # pragma: no cover - dependency guard
            raise ImportError(
                "`transformers`/`torch` belum terpasang; `uv sync --extra train` di ml/"
            ) from error

        processor = WhisperProcessor.from_pretrained(self.model_id)
        model = WhisperForConditionalGeneration.from_pretrained(
            self.model_id,
            dtype=torch.float32 if self.device == "cpu" else torch.float16,
        )
        if self.adapter:
            from peft import PeftModel

            model = PeftModel.from_pretrained(model, self.adapter)
            model = model.merge_and_unload()
        model.to(self.device)
        model.eval()

        self._pipe = AutomaticSpeechRecognitionPipeline(
            model=model,
            tokenizer=processor.tokenizer,
            feature_extractor=processor.feature_extractor,
            chunk_length_s=self.chunk_length_s,
            device=self.device,
        )
        return self._pipe

    def run(self, manifest: Path, *, limit: int | None = None) -> list[ClipResult]:
        pipe = self._ensure_loaded()
        base = Path(manifest).parent
        entries = parse_manifest_tsv(manifest)
        if limit is not None:
            entries = entries[:limit]

        results: list[ClipResult] = []
        for audio, _reference in entries:
            path = base / audio if not Path(audio).is_absolute() else Path(audio)
            if not path.exists():
                continue
            duration = wav_duration(path)
            started = time.perf_counter()
            try:
                output = pipe(  # type: ignore[operator]
                    str(path),
                    generate_kwargs={"language": self.language, "task": "transcribe"},
                )
                hypothesis = (output or {}).get("text", "").strip()
                failed = False
            except Exception:
                hypothesis, failed = "", True
            elapsed = time.perf_counter() - started
            results.append(
                ClipResult(
                    clip=audio,
                    hypothesis=hypothesis,
                    audio_secs=0.0 if failed else duration,
                    elapsed_secs=elapsed,
                    failed=failed,
                )
            )
        return results
