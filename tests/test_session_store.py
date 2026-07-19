from pathlib import Path

import pytest

from config.paths import ensure_under_root
from engine.session_store import create_session, finalize_session, update_title


def test_create_and_finalize(tmp_path: Path):
    s = create_session(tmp_path, "Daily Sync", "rapat_online")
    assert (s.root / "meta.json").exists()
    assert (s.root / ".inprogress").exists()
    update_title(s, "Daily Sync Renamed")
    s = finalize_session(s)
    assert not (s.root / ".inprogress").exists()
    assert "daily-sync-renamed" in s.root.name


def test_path_traversal_blocked(tmp_path: Path):
    root = tmp_path / "Sessions"
    root.mkdir()
    evil = tmp_path / "outside"
    evil.mkdir()
    with pytest.raises(ValueError):
        ensure_under_root(evil, root)
