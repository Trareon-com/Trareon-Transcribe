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
        # Matches main-window redesign mockup (forest green on cool grey).
        "bg": "#F4F6F8",
        "panel": "#FFFFFF",
        "text": "#14181F",
        "muted": "#5B6570",
        "label": "#374151",
        "accent": "#0E5C40",
        "accent_soft": "#E6F5EE",
        "accent_hover": "#0A4A33",
        "on_accent": "#FFFFFF",
        "danger": "#B91C1C",
        "danger_hover": "#991B1B",
        "partial": "#6B7280",
        "border": "#D5DAE1",
        "spk": "#1F2937",
        "mic": "#0E5C40",
        "row": "#EEF1F4",
        "row_active": "#D8F0E4",
        "hud_fg": "#0E5C40",
        "vu_off": "#C5CDD6",
        "warn_bg": "#FEF2F2",
        "warn_border": "#FECACA",
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
        "vu_off": "#4A5560",
        "warn_bg": "#3A1F1F",
        "warn_border": "#6B3030",
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
        anchor="w",
        justify="left",
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


_WRAP_TYPES = frozenset({"CTkLabel", "CTkCheckBox", "CTkRadioButton"})


def wrap_width_for(widget_w: int, master_w: int, fallback: int, *, min_wrap: int = 160) -> int:
    """Pick wraplength from laid-out width, else parent, else window fallback."""
    if widget_w >= 40:
        return max(min_wrap, widget_w - 8)
    if master_w >= 60:
        return max(min_wrap, master_w - 24)
    return max(min_wrap, fallback)


def _walk_widgets(widget: Any):
    yield widget
    try:
        children = widget.winfo_children()
    except Exception:
        return
    for child in children:
        yield from _walk_widgets(child)


def sync_responsive(win: Any, *, pad: int = 48, min_wrap: int = 160) -> None:
    """Recompute wraplength on every text widget so copy follows the window edge."""
    try:
        fallback = max(min_wrap, int(win.winfo_width()) - pad)
    except Exception:
        return
    for w in _walk_widgets(win):
        if type(w).__name__ not in _WRAP_TYPES:
            continue
        try:
            aw = int(w.winfo_width())
        except Exception:
            aw = 0
        try:
            mw = int(w.master.winfo_width()) if w.master is not None else 0
        except Exception:
            mw = 0
        wrap = wrap_width_for(aw, mw, fallback, min_wrap=min_wrap)
        try:
            w.configure(wraplength=wrap)
        except Exception:
            pass


def bind_responsive(win: Any, *, pad: int = 48) -> None:
    """Keep labels/checkboxes/radios wrapping on every window resize.

    Idempotent — safe to call again after theme rebuild (won't stack handlers).
    """
    state = getattr(win, "_trareon_responsive", None)
    if state is None:
        state = {"after": None, "pad": pad}
        win._trareon_responsive = state

        def _run() -> None:
            state["after"] = None
            sync_responsive(win, pad=int(state["pad"]))

        def _schedule(event: Any = None) -> None:
            if event is not None and getattr(event, "widget", None) is not win:
                return
            aid = state["after"]
            if aid is not None:
                try:
                    win.after_cancel(aid)
                except Exception:
                    pass
            try:
                state["after"] = win.after(40, _run)
            except Exception:
                _run()

        win.bind("<Configure>", _schedule, add="+")
    else:
        state["pad"] = pad

    try:
        win.after(60, lambda: sync_responsive(win, pad=int(state["pad"])))
    except Exception:
        sync_responsive(win, pad=pad)
