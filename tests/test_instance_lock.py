import os

from config import instance_lock
from config.paths import instance_lock_file


def test_stale_pid_lock_is_reclaimed(monkeypatch, tmp_path):
    lock = tmp_path / "instance.lock"
    lock.write_text("99999999", encoding="utf-8")  # unlikely live pid
    monkeypatch.setattr(instance_lock, "instance_lock_file", lambda: lock)
    assert instance_lock.acquire_instance_lock() is True
    assert lock.read_text(encoding="utf-8").strip() == str(os.getpid())
    instance_lock.release_instance_lock()
