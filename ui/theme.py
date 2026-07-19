"""Light (default) / dark theme helpers for CustomTkinter."""

from __future__ import annotations

import customtkinter as ctk

COLORS = {
    "light": {
        "bg": "#F4F6F8",
        "panel": "#FFFFFF",
        "text": "#1A1D21",
        "muted": "#5C6570",
        "accent": "#0B6E4F",
        "danger": "#C0392B",
        "partial": "#7A8490",
        "border": "#D5DBE1",
    },
    "dark": {
        "bg": "#1B1F24",
        "panel": "#262B32",
        "text": "#E8ECF0",
        "muted": "#9AA3AD",
        "accent": "#3DDC97",
        "danger": "#E74C3C",
        "partial": "#8B949E",
        "border": "#3A424C",
    },
}


def apply_theme(mode: str) -> dict[str, str]:
    mode = "dark" if mode == "dark" else "light"
    ctk.set_appearance_mode(mode)
    ctk.set_default_color_theme("green")
    return COLORS[mode]
