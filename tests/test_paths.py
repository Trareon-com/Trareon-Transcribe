"""Platform path defaults."""

from __future__ import annotations

import sys
from pathlib import Path
from unittest.mock import patch

from config.paths import APP_DISPLAY, APP_NAME, default_library_root


def test_default_library_root_windows_uses_localappdata(tmp_path: Path, monkeypatch) -> None:  # noqa: ANN001
    monkeypatch.setenv("LOCALAPPDATA", str(tmp_path / "Local"))
    with patch.object(sys, "platform", "win32"):
        root = default_library_root()
    assert root == tmp_path / "Local" / APP_NAME / "Sessions"
    assert root.is_dir()


def test_default_library_root_non_windows_uses_documents(tmp_path: Path, monkeypatch) -> None:  # noqa: ANN001
    monkeypatch.setattr("config.paths._home", lambda: tmp_path)
    with patch.object(sys, "platform", "darwin"):
        root = default_library_root()
    assert root == tmp_path / "Documents" / APP_DISPLAY / "Sessions"
    assert root.is_dir()
