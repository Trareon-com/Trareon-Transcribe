"""whisper.cpp CLI wrapper — offline STT on worker threads."""

from __future__ import annotations

import logging
import os
import re
import shutil
import subprocess
import sys
import tempfile
import wave
from dataclasses import dataclass
from pathlib import Path

from config.paths import models_dir
from setup.whisper_models import MODEL_FILES

log = logging.getLogger("trareon.stt")


@dataclass
class SttResult:
    text: str
    language: str
    confidence: float
    is_final: bool = True


def find_whisper_binary() -> Path | None:
    base = models_dir()
    candidates = [
        base / "whisper-cli",
        base / "whisper-cli.exe",
        base / "main",
        base / "main.exe",
        base / "bin" / "whisper-cli",
        base / "bin" / "whisper-cli.exe",
    ]
    # Bundled next to frozen executable (CI packs whisper-cli into onedir / .app)
    if getattr(sys, "frozen", False):
        exe_dir = Path(sys.executable).resolve().parent
        candidates.extend(
            [
                exe_dir / "whisper-cli",
                exe_dir / "whisper-cli.exe",
                exe_dir / "models" / "whisper-cli",
                exe_dir / "models" / "whisper-cli.exe",
            ]
        )
        # macOS .app: Contents/MacOS/
        if exe_dir.name == "MacOS":
            resources = exe_dir.parent / "Resources" / "models"
            candidates.extend([resources / "whisper-cli", exe_dir / "whisper-cli"])

    for c in candidates:
        if c.is_file():
            return c

    for name in ("whisper-cli", "whisper-cli.exe"):
        hit = shutil.which(name)
        if hit:
            return Path(hit)
    return None


def find_model(name: str = "medium") -> Path | None:
    fname = MODEL_FILES.get(name, f"ggml-{name}.bin")
    p = models_dir() / fname
    return p if p.exists() else None


def _write_wav(path: Path, pcm16: bytes, sr: int = 16000) -> None:
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(pcm16)


def _parse_lang(output: str) -> str:
    m = re.search(r"language\s*[:=]\s*['\"]?(\w+)", output, re.I)
    if m:
        return m.group(1).lower()
    text = output.lower()
    id_hits = sum(1 for w in ("yang", "dan", "untuk", "dengan", "ini", "ada") if w in text)
    en_hits = sum(1 for w in ("the", "and", "for", "with", "this", "that") if w in text)
    if id_hits > en_hits:
        return "id"
    if en_hits > id_hits:
        return "en"
    return "auto"


def _subprocess_kwargs() -> dict:
    kwargs: dict = {}
    if sys.platform == "win32":
        # Avoid black console flash when spawning whisper-cli.exe
        kwargs["creationflags"] = getattr(subprocess, "CREATE_NO_WINDOW", 0x08000000)
    return kwargs


class WhisperCppStt:
    def __init__(self, model_name: str = "medium") -> None:
        self.model_name = model_name
        self.binary = find_whisper_binary()
        self.model = find_model(model_name)

    def available(self) -> bool:
        return self.binary is not None and self.model is not None

    def transcribe(self, pcm16: bytes, sample_rate: int = 16000) -> SttResult:
        if not pcm16:
            return SttResult("", "auto", 0.0)
        if not self.available():
            return SttResult(
                text="[STT: model/binary belum terpasang — jalankan Setup]",
                language="id",
                confidence=0.0,
                is_final=True,
            )
        with tempfile.TemporaryDirectory(prefix="trareon-stt-") as td:
            wav = Path(td) / "chunk.wav"
            _write_wav(wav, pcm16, sample_rate)
            out_txt = Path(td) / "out.txt"
            cmd = [
                str(self.binary),
                "-m",
                str(self.model),
                "-f",
                str(wav),
                "-l",
                "auto",
                "-otxt",
                "-of",
                str(Path(td) / "out"),
                "-np",
            ]
            try:
                proc = subprocess.run(
                    cmd,
                    capture_output=True,
                    text=True,
                    timeout=120,
                    check=False,
                    env={**os.environ},
                    **_subprocess_kwargs(),
                )
            except subprocess.TimeoutExpired:
                log.error("whisper.cpp timed out")
                return SttResult("", "auto", 0.0)
            text = ""
            if out_txt.exists():
                text = out_txt.read_text(encoding="utf-8", errors="replace").strip()
            elif (Path(td) / "out.txt").exists():
                text = (Path(td) / "out.txt").read_text(encoding="utf-8", errors="replace").strip()
            combined = (proc.stdout or "") + "\n" + text
            lang = _parse_lang(combined)
            if not text:
                lines = [
                    ln.strip()
                    for ln in (proc.stdout or "").splitlines()
                    if ln.strip() and not ln.startswith("[")
                ]
                text = " ".join(lines)
            return SttResult(text=text, language=lang, confidence=0.8 if text else 0.0)
