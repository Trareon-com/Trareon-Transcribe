"""Update check helpers (no network)."""

from update.check import _prefer_asset, is_newer, platform_key


def test_is_newer() -> None:
    assert is_newer("0.1.1", "0.1.0")
    assert is_newer("v0.2.0", "0.1.9")
    assert not is_newer("0.1.0", "0.1.1")
    assert not is_newer("0.1.1", "0.1.1")


def test_prefer_windows_setup() -> None:
    assets = [
        {"name": "Trareon-Transcribe-0.1.1-windows-x64-portable.zip", "browser_download_url": "https://x/p.zip"},
        {"name": "Trareon-Transcribe-0.1.1-windows-x64-Setup.exe", "browser_download_url": "https://x/s.exe"},
    ]
    url, name = _prefer_asset(assets, "windows")
    assert "Setup" in name
    assert url.endswith("s.exe")


def test_platform_key_runs() -> None:
    assert platform_key() in ("windows", "macos-arm64", "macos-x64", "other")
