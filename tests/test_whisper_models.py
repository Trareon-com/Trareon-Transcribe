"""Whisper catalog + suggest_model ladder."""

from __future__ import annotations

from setup.model_dl import MODEL_URLS, suggest_model
from setup.whisper_models import MODEL_FILES, WHISPER_MODELS, model_url


def test_six_models_catalog() -> None:
    assert WHISPER_MODELS == (
        "tiny",
        "base",
        "small",
        "medium",
        "large-v3-turbo",
        "large",
    )
    assert set(MODEL_URLS) == set(WHISPER_MODELS)
    assert MODEL_FILES["large"] == "ggml-large-v3.bin"
    assert model_url("base").endswith("ggml-base.bin")


def test_suggest_model_ladder() -> None:
    assert suggest_model(2.0, False) == "tiny"
    assert suggest_model(3.0, False) == "base"
    assert suggest_model(6.0, False) == "small"
    assert suggest_model(12.0, False) == "medium"
    assert suggest_model(16.0, False) == "large-v3-turbo"
    assert suggest_model(16.0, True) == "large-v3-turbo"
    assert suggest_model(24.0, True) == "large"
