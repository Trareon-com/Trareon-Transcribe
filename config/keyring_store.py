"""HF token in OS keyring — never plaintext in config."""

from __future__ import annotations

SERVICE = "TrareonTranscribe"
USERNAME = "huggingface_token"


def get_hf_token() -> str | None:
    try:
        import keyring
    except ImportError:
        return None
    try:
        return keyring.get_password(SERVICE, USERNAME)
    except Exception:
        return None


def set_hf_token(token: str) -> None:
    import keyring

    if not token:
        delete_hf_token()
        return
    keyring.set_password(SERVICE, USERNAME, token)


def delete_hf_token() -> None:
    try:
        import keyring

        keyring.delete_password(SERVICE, USERNAME)
    except Exception:
        pass
