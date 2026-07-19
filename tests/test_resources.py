"""Resource HUD string always includes CPU/RAM/GPU tokens."""

from __future__ import annotations

from util.resources import sample_resources


def test_sample_resources_shape() -> None:
    s = sample_resources()
    assert "CPU" in s
    assert "RAM" in s
    assert "GPU" in s
