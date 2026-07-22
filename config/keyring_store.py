"""HF token storage — local file only, never the OS keychain.

Storing this in the macOS Keychain (via the `keyring` package) prompted a
"TrareonTranscribe wants to use your confidential information stored in
Keychain" access dialog on every run of an unsigned/ad-hoc dev build (the
binary hash changes each build, so Keychain treats it as a new app each
time). The HF token is only a read-scoped download credential for gated
pyannote model weights, not an account password — obscuring it in a
0600 file under the app's own config dir is an adequate trade-off that
avoids that prompt entirely.
"""

from __future__ import annotations

import base64
import contextlib
import os
import stat

from config.paths import app_support_dir

_TOKEN_FILE = "hf_token.dat"  # noqa: S105 — filename, not a credential
_KEY_FILE = ".hf_token_key"


def _token_path():
    return app_support_dir() / _TOKEN_FILE


def _key_path():
    return app_support_dir() / _KEY_FILE


def _chmod_owner_only(path) -> None:
    with contextlib.suppress(OSError):
        os.chmod(path, stat.S_IRUSR | stat.S_IWUSR)


def _load_key() -> bytes:
    key_path = _key_path()
    if key_path.exists():
        return key_path.read_bytes()
    key = os.urandom(32)
    key_path.write_bytes(key)
    _chmod_owner_only(key_path)
    return key


def _xor(data: bytes, key: bytes) -> bytes:
    return bytes(b ^ key[i % len(key)] for i, b in enumerate(data))


def get_hf_token() -> str | None:
    path = _token_path()
    if not path.exists():
        return None
    try:
        key = _load_key()
        raw = base64.b64decode(path.read_bytes())
        return _xor(raw, key).decode("utf-8")
    except (OSError, ValueError):
        return None


def set_hf_token(token: str) -> None:
    if not token:
        delete_hf_token()
        return
    key = _load_key()
    path = _token_path()
    path.write_bytes(base64.b64encode(_xor(token.encode("utf-8"), key)))
    _chmod_owner_only(path)


def delete_hf_token() -> None:
    with contextlib.suppress(OSError):
        _token_path().unlink()
