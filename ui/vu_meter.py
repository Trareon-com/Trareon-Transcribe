"""Compact equalizer VU — fixed width like the design mockup."""

from __future__ import annotations

from typing import Any

import customtkinter as ctk


class BarVuMeter(ctk.CTkFrame):
    """10-bar meter; fixed size so the toolbar stays tight (no empty stretch)."""

    _N = 10
    _H = (8, 12, 16, 20, 18, 14, 20, 16, 12, 10)
    _BAR_W = 4
    _GAP = 3

    def __init__(
        self,
        master: Any,
        *,
        colors: dict[str, str],
        height: int = 24,
        width: int = 72,
    ) -> None:
        # Exact pixel width from bars — never grow with the toolbar.
        width = self._N * (self._BAR_W + self._GAP) + 2
        super().__init__(master, fg_color="transparent", width=width, height=height)
        self.configure(width=width, height=height)
        self.pack_propagate(False)
        self.grid_propagate(False)
        self._on = colors["accent"]
        # Off bars must stay visible (mock: light grey stubs).
        self._off = colors.get("vu_off") or colors.get("border", "#D0D5DD")
        self._level = 0.0
        self._bars: list[ctk.CTkFrame] = []
        x = 1
        for h in self._H:
            bar = ctk.CTkFrame(
                self,
                fg_color=self._off,
                corner_radius=2,
                width=self._BAR_W,
                height=h,
            )
            # CTk: size in constructor only; place with x/y.
            bar.place(x=x, y=height - h - 2)
            self._bars.append(bar)
            x += self._BAR_W + self._GAP

    def set(self, level: float) -> None:
        level = max(0.0, min(1.0, float(level)))
        self._level = level
        lit = int(round(level * self._N))
        for i, bar in enumerate(self._bars):
            try:
                bar.configure(fg_color=self._on if i < lit else self._off)
            except Exception:
                pass

    def recolor(self, colors: dict[str, str]) -> None:
        self._on = colors["accent"]
        self._off = colors.get("vu_off") or colors.get("border", "#D0D5DD")
        self.set(self._level)
