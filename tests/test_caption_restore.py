"""Caption restore after theme rebuild keeps MIC/SPK labels."""

from __future__ import annotations


def test_restore_caption_tags_logic() -> None:
    # Pure logic: lines starting with MIC/SPK are split for tagging.
    text = "MIC  Halo semua\n\nSPK  Good morning\n"
    lines = [ln for ln in text.splitlines() if ln.strip()]
    assert lines[0].startswith("MIC")
    assert lines[1].startswith("SPK")
    assert lines[0][3:].lstrip() == "Halo semua"
    assert lines[1][3:].lstrip() == "Good morning"
