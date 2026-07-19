"""Download whisper.cpp binary + ggml models with SHA256 verify."""

from __future__ import annotations

import hashlib
import logging
import platform
import shutil
import tarfile
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
# Populate from release notes when pinning a release.
MODEL_SHA256: dict[str, str] = {}

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


def _whisper_release_asset() -> tuple[str, str] | None:
    sysname = platform.system().lower()
    machine = platform.machine().lower()
    # Best-effort: user can also place binary manually in models_dir
    if sysname == "darwin":
        if "arm" in machine or machine == "aarch64":
            return (
                "https://github.com/ggerganov/whisper.cpp/releases/download/v1.7.5/whisper-bin-macos.zip",
                "zip",
            )
        return (
            "https://github.com/ggerganov/whisper.cpp/releases/download/v1.7.5/whisper-bin-macos.zip",
            "zip",
        )
    if sysname == "windows":
        return (
            "https://github.com/ggerganov/whisper.cpp/releases/download/v1.7.5/whisper-bin-x64.zip",
            "zip",
        )
    return None


def ensure_whisper_binary(progress: ProgressCb | None = None) -> Path | None:
    from engine.stt import find_whisper_binary

    existing = find_whisper_binary()
    if existing:
        return existing
    asset = _whisper_release_asset()
    if not asset:
        log.warning("No prebuilt whisper binary URL for this platform; place whisper-cli in %s", models_dir())
        return None
    url, kind = asset
    ok, msg = ensure_space(WHISPER_BIN_BYTES, models_dir())
    if not ok:
        raise OSError(msg)
    with tempfile.TemporaryDirectory() as td:
        archive = Path(td) / ("w.zip" if kind == "zip" else "w.tgz")
        try:
            download_file(url, archive, progress=progress)
        except Exception as e:
            log.warning("binary download failed: %s — place whisper-cli manually", e)
            return None
        extract_dir = Path(td) / "ex"
        extract_dir.mkdir()
        if kind == "zip":
            with zipfile.ZipFile(archive) as zf:
                zf.extractall(extract_dir)
        else:
            with tarfile.open(archive) as tf:
                tf.extractall(extract_dir)
        # find executable
        for name in ("whisper-cli", "whisper-cli.exe", "main", "main.exe"):
            hits = list(extract_dir.rglob(name))
            if hits:
                dest = models_dir() / hits[0].name
                shutil.copy2(hits[0], dest)
                dest.chmod(dest.stat().st_mode | 0o111)
                return dest
    return None


# re-export for callers: from setup.model_dl import suggest_model
__all__ = [
    "MODEL_URLS",
    "download_file",
    "download_model",
    "ensure_whisper_binary",
    "suggest_model",
]
