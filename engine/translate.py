"""Optional offline EN↔ID translation (Argos Translate). Default off."""

from __future__ import annotations

import logging

log = logging.getLogger("trareon.translate")


def translate_text(text: str, direction: str = "en_id") -> str:
    if not text.strip():
        return text
    try:
        import argostranslate.translate
    except ImportError:
        log.info("argostranslate not installed")
        return text
    if direction == "id_en":
        from_code, to_code = "id", "en"
    else:
        from_code, to_code = "en", "id"
    try:
        return argostranslate.translate.translate(text, from_code, to_code)
    except Exception as e:
        log.warning("translate failed: %s", e)
        return text
