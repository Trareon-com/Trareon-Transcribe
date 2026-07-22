import sys
from pathlib import Path

from engine import stt
from setup.whisper_models import MODEL_FILES


def test_find_model_unknown_name_falls_back_to_medium(monkeypatch, tmp_path: Path):
    monkeypatch.setattr(stt, "models_dir", lambda: tmp_path)
    medium_path = tmp_path / MODEL_FILES["medium"]
    medium_path.write_bytes(b"stub")

    result = stt.find_model("../../../../etc/passwd")

    assert result == medium_path


def test_find_model_known_name_resolves_directly(monkeypatch, tmp_path: Path):
    monkeypatch.setattr(stt, "models_dir", lambda: tmp_path)
    small_path = tmp_path / MODEL_FILES["small"]
    small_path.write_bytes(b"stub")

    assert stt.find_model("small") == small_path


def test_find_model_missing_file_returns_none(monkeypatch, tmp_path: Path):
    monkeypatch.setattr(stt, "models_dir", lambda: tmp_path)
    assert stt.find_model("medium") is None


# --- find_whisper_binary ---


def test_find_whisper_binary_in_models_dir(monkeypatch, tmp_path: Path):
    """Binary file under models_dir is discovered first."""
    monkeypatch.setattr(stt, "models_dir", lambda: tmp_path)
    binary = tmp_path / "whisper-whisper-cli"
    binary.write_bytes(b"ELF stub")

    result = stt.find_whisper_binary()
    assert result == binary


def test_find_whisper_binary_fallback_name(monkeypatch, tmp_path: Path):
    """Deprecated name whisper-cli is also found."""
    monkeypatch.setattr(stt, "models_dir", lambda: tmp_path)
    binary = tmp_path / "whisper-cli"
    binary.write_bytes(b"ELF stub")

    result = stt.find_whisper_binary()
    assert result == binary


def test_find_whisper_binary_bundled_paths(monkeypatch, tmp_path: Path):
    """When sys.frozen is True, bundled paths next to the executable are checked."""
    monkeypatch.setattr(stt, "models_dir", lambda: tmp_path)
    monkeypatch.setattr(sys, "frozen", True, raising=False)

    exe_dir = tmp_path / "MacOS"
    exe_dir.mkdir(parents=True)
    monkeypatch.setattr(sys, "executable", str(exe_dir / "Trareon Transcribe"))

    binary = exe_dir / "whisper-whisper-cli"
    binary.write_bytes(b"bundled ELF")

    result = stt.find_whisper_binary()
    assert result == binary


def test_find_whisper_binary_bundled_macos_app(monkeypatch, tmp_path: Path):
    """macOS .app bundle: checks Contents/MacOS/ and Contents/Resources/models/."""
    monkeypatch.setattr(stt, "models_dir", lambda: tmp_path)
    monkeypatch.setattr(sys, "frozen", True, raising=False)

    macos_dir = tmp_path / "Trareon Transcribe.app" / "Contents" / "MacOS"
    macos_dir.mkdir(parents=True)
    monkeypatch.setattr(sys, "executable", str(macos_dir / "Trareon Transcribe"))

    resources = tmp_path / "Trareon Transcribe.app" / "Contents" / "Resources" / "models"
    resources.mkdir(parents=True)
    binary = resources / "whisper-whisper-cli"
    binary.write_bytes(b"bundled macOS ELF")

    result = stt.find_whisper_binary()
    assert result == binary


def test_find_whisper_binary_not_found(monkeypatch, tmp_path: Path):
    """No binary anywhere returns None."""
    monkeypatch.setattr(stt, "models_dir", lambda: tmp_path)
    monkeypatch.setattr("shutil.which", lambda name, **kw: None)
    assert stt.find_whisper_binary() is None
