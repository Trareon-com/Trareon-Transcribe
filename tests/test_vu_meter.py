"""BarVuMeter level → lit-bar count."""

from __future__ import annotations

from ui.vu_meter import BarVuMeter


def _lit(level: float) -> int:
    level = max(0.0, min(1.0, float(level)))
    return int(round(level * BarVuMeter._N))  # noqa: SLF001


def test_lit_bars_quiet_full_mid() -> None:
    assert _lit(-0.5) == 0
    assert _lit(0.0) == 0
    assert _lit(1.0) == 10
    assert _lit(2.0) == 10
    assert _lit(0.5) == 5
