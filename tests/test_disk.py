from setup.disk import ensure_space, human_gb


def test_ensure_space_ok():
    ok, msg = ensure_space(1024)
    assert ok
    assert "OK" in msg


def test_human_gb():
    assert human_gb(1024**3) == "1.0 GB"
