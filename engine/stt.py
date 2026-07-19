"""whisper.cpp CLI wrapper — offline STT on worker threads."""

from __future__ import annotations

import logging
import re
import subprocess
import tempfile
import wave
from dataclasses import dataclass
from pathlib import Path

from config.paths import models_dir

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
    ]
    for c in candidates:
        if c.exists():
            return c
    return None


def find_model(name: str = "medium") -> Path | None:
    mapping = {
        "tiny": "ggml-tiny.bin",
        "medium": "ggml-medium.bin",
        "large-v3-turbo": "ggml-large-v3-turbo.bin",
    }
    fname = mapping.get(name, f"ggml-{name}.bin")
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
    # heuristic
    text = output.lower()
    id_hits = sum(1 for w in ("yang", "dan", "untuk", "dengan", "ini", "ada") if w in text)
    en_hits = sum(1 for w in ("the", "and", "for", "with", "this", "that") if w in text)
    if id_hits > en_hits:
        return "id"
    if en_hits > id_hits:
        return "en"
    return "auto"


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
            # Offline stub so UI pipeline can be exercised without models
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
                # some builds print to stdout
                lines = [
                    ln.strip()
                    for ln in (proc.stdout or "").splitlines()
                    if ln.strip() and not ln.startswith("[")
                ]
                text = " ".join(lines)
            return SttResult(text=text, language=lang, confidence=0.8 if text else 0.0)
