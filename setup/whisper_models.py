"""Canonical Whisper ggml catalog for wizard / settings / downloads."""

from __future__ import annotations

# UI key → ggml filename under models_dir()
MODEL_FILES: dict[str, str] = {
    "tiny": "ggml-tiny.bin",
    "base": "ggml-base.bin",
    "small": "ggml-small.bin",
    "medium": "ggml-medium.bin",
    "large-v3-turbo": "ggml-large-v3-turbo.bin",
    "large": "ggml-large-v3.bin",
}

WHISPER_MODELS: tuple[str, ...] = tuple(MODEL_FILES.keys())

# Short labels for radio / docs (size · speed · quality)
MODEL_SIZES: dict[str, int] = {
    "tiny": 75,
    "base": 142,
    "small": 466,
    "medium": 1_500,
    "large": 2_900,
    "large-v3-turbo": 1_500,
}

MODEL_LABELS: dict[str, str] = {
    "tiny": "tiny ~75MB — very fast, low quality",
    "base": "base ~150MB — fast, medium quality",
    "small": "small ~500MB — medium speed, good quality",
    "medium": "medium ~1.5GB — slower, high quality",
    "large-v3-turbo": "large-v3-turbo ~1.6GB — medium speed, very high quality",
    "large": "large ~3GB — slowest, best quality",
}

MODEL_URL_BASE = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/"


def model_url(name: str) -> str:
    return MODEL_URL_BASE + MODEL_FILES[name]


def suggest_model(ram_gb: float, is_apple_silicon: bool) -> str:
    """Pick a Whisper size from RAM; prefer turbo over full large on Apple Silicon."""
    if ram_gb >= 20 and is_apple_silicon:
        return "large"
    if ram_gb >= 14 and is_apple_silicon:
        return "large-v3-turbo"
    if ram_gb >= 16:
        return "large-v3-turbo"
    if ram_gb >= 10:
        return "medium"
    if ram_gb >= 5:
        return "small"
    if ram_gb >= 2.5:
        return "base"
    return "tiny"
