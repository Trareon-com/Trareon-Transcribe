import sys

import pytest

from config import keyring_store


def test_set_get_delete_roundtrip(monkeypatch, tmp_path):
    monkeypatch.setattr(keyring_store, "app_support_dir", lambda: tmp_path)
    assert keyring_store.get_hf_token() is None
    keyring_store.set_hf_token("hf_test_token_123")
    assert keyring_store.get_hf_token() == "hf_test_token_123"
    keyring_store.delete_hf_token()
    assert keyring_store.get_hf_token() is None


def test_empty_token_deletes(monkeypatch, tmp_path):
    monkeypatch.setattr(keyring_store, "app_support_dir", lambda: tmp_path)
    keyring_store.set_hf_token("something")
    keyring_store.set_hf_token("")
    assert keyring_store.get_hf_token() is None


@pytest.mark.skipif(sys.platform == "win32", reason="POSIX permission bits only")
def test_token_file_permissions(monkeypatch, tmp_path):
    monkeypatch.setattr(keyring_store, "app_support_dir", lambda: tmp_path)
    keyring_store.set_hf_token("secret")
    mode = (tmp_path / keyring_store._TOKEN_FILE).stat().st_mode & 0o777
    assert mode == 0o600


def test_no_keyring_package_import():
    assert "keyring" not in sys.modules
