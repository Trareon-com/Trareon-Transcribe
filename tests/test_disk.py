from pathlib import Path

from setup.disk import ensure_space, human_gb, library_storage_summary


def test_ensure_space_ok():
    ok, msg = ensure_space(1024)
    assert ok
    assert "OK" in msg


def test_human_gb():
    assert human_gb(1024**3) == "1.0 GB"


def test_library_storage_summary(tmp_path: Path):
    (tmp_path / "a.bin").write_bytes(b"x" * 2048)
    s = library_storage_summary(tmp_path)
    assert "terpakai" in s
    assert "bebas" in s
