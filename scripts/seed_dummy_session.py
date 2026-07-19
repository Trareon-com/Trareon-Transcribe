#!/usr/bin/env python3
"""Seed dummy Library sessions and optionally open the player UI."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))


def main() -> int:
    p = argparse.ArgumentParser(description="Seed dummy Trareon Transcribe sessions")
    p.add_argument("--force", action="store_true", help="Recreate demo sessions")
    p.add_argument("--ui", action="store_true", help="Open Library + player for the main demo")
    p.add_argument("--print-only", action="store_true", help="Seed/verify and print paths only")
    args = p.parse_args()

    from engine.demo_seed import seed_demo_sessions, verify_demo

    sessions = seed_demo_sessions(force=args.force)
    print(f"Seeded {len(sessions)} demo session(s):\n")
    for s in sessions:
        checks = verify_demo(s)
        print(f"  • {s.meta.title}")
        print(f"    {s.root}")
        print(f"    OK: {', '.join(checks)}")
        print()

    if args.print_only or not args.ui:
        if not args.ui:
            print("Next: ./scripts/run_mac_app.sh   then click Library → Putar")
            print("Or:   python scripts/seed_dummy_session.py --ui")
            print("Or:   python main.py --demo")
        return 0

    from config.branding import ensure_tk_registered
    from config.settings import Settings

    ensure_tk_registered()
    import customtkinter as ctk

    from ui.library import LibraryWindow
    from ui.theme import apply_theme
    from ui.transcript_player import TranscriptPlayerWindow

    settings = Settings.load()
    apply_theme(settings.theme)
    root = ctk.CTk()
    root.title("Trareon Transcribe — Demo")
    root.geometry("420x120")
    ctk.CTkLabel(root, text="Demo Library terbuka. Tutup window player untuk keluar.").pack(
        padx=16, pady=24
    )
    lib = LibraryWindow(root, settings.library_path())
    TranscriptPlayerWindow(lib, sessions[0].root)
    root.mainloop()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
