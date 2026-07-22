"""Download whisper.cpp binary + ggml models with SHA256 verify."""

from __future__ import annotations

import hashlib
import logging
import platform
import shutil
import subprocess
import tempfile
import zipfile
from collections.abc import Callable
from pathlib import Path
from urllib.request import urlopen

from config.paths import models_dir
from setup.disk import MODEL_BYTES, WHISPER_BIN_BYTES, ensure_space
from setup.whisper_models import MODEL_FILES, model_url, suggest_model

log = logging.getLogger("trareon.model_dl")

# Official ggml models (ggerganov HuggingFace)
MODEL_URLS = {name: model_url(name) for name in MODEL_FILES}

# Optional expected SHA256 — empty means verify download completed + size sanity only.
MODEL_SHA256: dict[str, str] = {}

# Whisper.cpp release that still ships Windows CLI zip (macOS has no CLI zip).
WHISPER_CPP_TAG = "v1.9.1"
WHISPER_WIN_ZIP = (
    f"https://github.com/ggml-org/whisper.cpp/releases/download/"
    f"{WHISPER_CPP_TAG}/whisper-bin-x64.zip"
)

ProgressCb = Callable[[str, float], None]


def _sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def download_file(url: str, dest: Path, progress: ProgressCb | None = None, expected_sha: str = "") -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    tmp = dest.with_suffix(dest.suffix + ".part")
    with urlopen(url, timeout=120) as resp:  # noqa: S310 — URL from our constants
        total = int(resp.headers.get("Content-Length") or 0)
        read = 0
        with tmp.open("wb") as out:
            while True:
                chunk = resp.read(1024 * 256)
                if not chunk:
                    break
                out.write(chunk)
                read += len(chunk)
                if progress and total:
                    progress(dest.name, read / total)
    if expected_sha:
        digest = _sha256_file(tmp)
        if digest.lower() != expected_sha.lower():
            tmp.unlink(missing_ok=True)
            raise ValueError(f"SHA256 mismatch for {dest.name}: got {digest}")
    tmp.replace(dest)


def download_model(name: str, progress: ProgressCb | None = None) -> Path:
    url = MODEL_URLS[name]
    size = MODEL_BYTES.get(name, 1024**3)
    ok, msg = ensure_space(size + WHISPER_BIN_BYTES, models_dir())
    if not ok:
        raise OSError(msg)
    dest = models_dir() / Path(url).name
    if dest.exists() and dest.stat().st_size > 1_000_000:
        if progress:
            progress(dest.name, 1.0)
        return dest
    download_file(url, dest, progress=progress, expected_sha=MODEL_SHA256.get(name, ""))
    return dest


def _copy_binary_to_models(src: Path) -> Path:
    dest = models_dir() / src.name
    shutil.copy2(src, dest)
    dest.chmod(dest.stat().st_mode | 0o111)
    return dest


def _try_brew_whisper(progress: ProgressCb | None = None) -> Path | None:
    brew = shutil.which("brew")
    if not brew:
        log.warning("Homebrew not found — cannot auto-install whisper-cpp")
        return None
    if progress:
        progress("whisper-cpp (brew)", 0.1)
    try:
        subprocess.run(
            [brew, "install", "whisper-cpp"],
            capture_output=True,
            text=True,
            timeout=900,
            check=False,
        )
    except Exception as e:
        log.warning("brew install whisper-cpp failed: %s", e)
        return None
    if progress:
        progress("whisper-cpp (brew)", 1.0)
    for name in ("whisper-whisper-cli", "whisper-cli", "whisper-cpp"):
        hit = shutil.which(name)
        if hit:
            return _copy_binary_to_models(Path(hit))
    # Common Cellar locations
    for pattern in (
        "/opt/homebrew/bin/whisper-whisper-cli",
        "/opt/homebrew/bin/whisper-cli",
        "/usr/local/bin/whisper-whisper-cli",
        "/usr/local/bin/whisper-cli",
    ):
        p = Path(pattern)
        if p.is_file():
            return _copy_binary_to_models(p)
    return None


def _extract_whisper_from_zip(archive: Path) -> Path | None:
    with tempfile.TemporaryDirectory() as td:
        extract_dir = Path(td) / "ex"
        extract_dir.mkdir()
        with zipfile.ZipFile(archive) as zf:
            zf.extractall(extract_dir)
        # whisper-whisper-cli is the current binary name; whisper-cli is now
        # a deprecated shim, so prefer the new name when both are present.
        for name in ("whisper-whisper-cli.exe", "whisper-whisper-cli", "whisper-cli.exe", "whisper-cli", "main.exe", "main"):
            hits = list(extract_dir.rglob(name))
            if hits:
                return _copy_binary_to_models(hits[0])
    return None


def ensure_whisper_binary(progress: ProgressCb | None = None) -> Path | None:
    from engine.stt import find_whisper_binary

    existing = find_whisper_binary()
    if existing:
        return existing

    sysname = platform.system().lower()
    ok, msg = ensure_space(WHISPER_BIN_BYTES, models_dir())
    if not ok:
        raise OSError(msg)

    if sysname == "windows":
        with tempfile.TemporaryDirectory() as td:
            archive = Path(td) / "w.zip"
            try:
                if progress:
                    progress("whisper-cli.exe", 0.0)
                download_file(WHISPER_WIN_ZIP, archive, progress=progress)
            except Exception as e:
                log.warning("binary download failed: %s — place whisper-cli.exe manually", e)
                return None
            return _extract_whisper_from_zip(archive)

    if sysname == "darwin":
        # No official macOS CLI zip in recent releases — use Homebrew.
        got = _try_brew_whisper(progress=progress)
        if got:
            return got
        log.warning(
            "No whisper-cli on PATH. Install: brew install whisper-cpp — then re-run Setup. "
            "Or place whisper-cli in %s",
            models_dir(),
        )
        return None

    log.warning("No prebuilt whisper binary for this platform; place whisper-cli in %s", models_dir())
    return None


def find_partial_models() -> list[str]:
    """Return list of model names with partial downloads."""
    from config.paths import models_dir

    partials: list[str] = []
    for f in models_dir().glob("*.ggml.part"):
        partials.append(f.stem)
    return partials


# re-export for callers
__all__ = [
    "MODEL_URLS",
    "WHISPER_WIN_ZIP",
    "download_file",
    "download_model",
    "ensure_whisper_binary",
    "find_partial_models",
    "suggest_model",
]
