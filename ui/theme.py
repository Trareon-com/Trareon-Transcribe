"""Light (default) / dark theme helpers for CustomTkinter.

Palette tuned for WCAG AA: body text ≥4.5:1 on panel/bg, UI borders ≥3:1.
"""

from __future__ import annotations

from collections.abc import Callable
from typing import Any

import customtkinter as ctk

# Contrast notes (approx vs panel):
# light text #14181F on #FFFFFF ≈ 16:1; muted #4B5563 ≈ 7:1; border #B8C0CC ≈ 2.9–3:1
# dark text #F2F4F7 on #262B32 ≈ 12:1; muted #B0B8C2 ≈ 5.5:1; on_accent dark on mint ≈ 7:1
COLORS = {
    "light": {
        "bg": "#EEF1F5",
        "panel": "#FFFFFF",
        "text": "#14181F",
        "muted": "#4B5563",
        "label": "#374151",
        "accent": "#145C3F",
        "accent_soft": "#D7F0E4",
        "accent_hover": "#0F4A33",
        "on_accent": "#FFFFFF",
        "danger": "#B91C1C",
        "danger_hover": "#991B1B",
        "partial": "#5B6470",
        "border": "#B8C0CC",
        "spk": "#14181F",
        "mic": "#145C3F",
        "row": "#F3F5F8",
        "row_active": "#D7F0E4",
        "hud_fg": "#0F4A33",
    },
    "dark": {
        "bg": "#12151A",
        "panel": "#1E242C",
        "text": "#F2F4F7",
        "muted": "#B0B8C2",
        "label": "#C5CDD6",
        "accent": "#3DDC97",
        "accent_soft": "#163528",
        "accent_hover": "#55E5A8",
        "on_accent": "#0B1A14",
        "danger": "#F07167",
        "danger_hover": "#F48B82",
        "partial": "#A8B0BA",
        "border": "#5A6572",
        "spk": "#F2F4F7",
        "mic": "#3DDC97",
        "row": "#181D24",
        "row_active": "#163528",
        "hud_fg": "#8AF0C0",
    },
}


def apply_theme(mode: str) -> dict[str, str]:
    mode = "dark" if mode == "dark" else "light"
    ctk.set_appearance_mode(mode)
    ctk.set_default_color_theme("green")
    return COLORS[mode]


def colors_for(mode: str | None = None) -> dict[str, str]:
    if mode is None:
        mode = ctk.get_appearance_mode()
    key = "dark" if str(mode).lower() == "dark" else "light"
    return COLORS[key]


def paint_window(win: ctk.CTk | ctk.CTkToplevel, colors: dict[str, str] | None = None) -> dict[str, str]:
    c = colors or colors_for()
    win.configure(fg_color=c["bg"])
    return c


def ghost_button(
    parent: Any,
    text: str,
    command: Callable[[], None] | None,
    colors: dict[str, str],
    *,
    width: int = 88,
    height: int = 30,
) -> ctk.CTkButton:
    return ctk.CTkButton(
        parent,
        text=text,
        width=width,
        height=height,
        corner_radius=8,
        fg_color=colors["panel"],
        hover_color=colors["row"],
        text_color=colors["text"],
        border_width=1,
        border_color=colors["border"],
        command=command,
    )


def primary_button(
    parent: Any,
    text: str,
    command: Callable[[], None] | None,
    colors: dict[str, str],
    *,
    width: int = 100,
    height: int = 32,
) -> ctk.CTkButton:
    return ctk.CTkButton(
        parent,
        text=text,
        width=width,
        height=height,
        corner_radius=8,
        fg_color=colors["accent"],
        hover_color=colors["accent_hover"],
        text_color=colors["on_accent"],
        command=command,
    )


def danger_button(
    parent: Any,
    text: str,
    command: Callable[[], None] | None,
    colors: dict[str, str],
    *,
    width: int = 80,
    height: int = 30,
) -> ctk.CTkButton:
    return ctk.CTkButton(
        parent,
        text=text,
        width=width,
        height=height,
        corner_radius=8,
        fg_color=colors["danger"],
        hover_color=colors["danger_hover"],
        text_color="#FFFFFF",
        command=command,
    )


def panel_frame(parent: Any, colors: dict[str, str], **kwargs: Any) -> ctk.CTkFrame:
    opts = {
        "fg_color": colors["panel"],
        "corner_radius": 12,
        "border_width": 1,
        "border_color": colors["border"],
    }
    opts.update(kwargs)
    return ctk.CTkFrame(parent, **opts)


def heading(parent: Any, text: str, colors: dict[str, str], *, size: int = 18) -> ctk.CTkLabel:
    return ctk.CTkLabel(
        parent,
        text=text,
        font=ctk.CTkFont(size=size, weight="bold"),
        text_color=colors["text"],
    )


def muted(parent: Any, text: str = "", colors: dict[str, str] | None = None, **kwargs: Any) -> ctk.CTkLabel:
    c = colors or colors_for()
    opts = {"text": text, "text_color": c["muted"], "font": ctk.CTkFont(size=12)}
    opts.update(kwargs)
    return ctk.CTkLabel(parent, **opts)


def field_label(parent: Any, text: str, colors: dict[str, str], **kwargs: Any) -> ctk.CTkLabel:
    """Section / form labels — stronger than muted helper text."""
    opts = {
        "text": text,
        "text_color": colors["label"],
        "font": ctk.CTkFont(size=12, weight="bold"),
    }
    opts.update(kwargs)
    return ctk.CTkLabel(parent, **opts)


def styled_entry(parent: Any, colors: dict[str, str], **kwargs: Any) -> ctk.CTkEntry:
    opts = {
        "height": 32,
        "border_color": colors["border"],
        "fg_color": colors["bg"],
        "text_color": colors["text"],
        "placeholder_text_color": colors["muted"],
        "corner_radius": 8,
    }
    opts.update(kwargs)
    return ctk.CTkEntry(parent, **opts)
