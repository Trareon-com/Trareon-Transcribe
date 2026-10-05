"""Minimal Ollama client — ``urllib`` only.

The bake-off has to run on whichever machine has the GPU. Requiring a
virtualenv there is friction that ends with the benchmark not being run,
so this talks to ``/api/chat``, ``/api/tags`` and ``/api/ps`` directly.
"""

from __future__ import annotations

import json
import time
import urllib.error
import urllib.request
from dataclasses import dataclass, field

DEFAULT_HOST = "http://127.0.0.1:11434"


@dataclass
class ChatResult:
    """One model round trip, with the numbers the report needs."""

    content: str = ""
    error: str = ""
    seconds: float = 0.0
    prompt_tokens: int = 0
    eval_tokens: int = 0
    eval_seconds: float = 0.0
    thinking_disabled: bool = False
    raw: dict = field(default_factory=dict)

    @property
    def ok(self) -> bool:
        return not self.error

    @property
    def tokens_per_second(self) -> float:
        if self.eval_seconds <= 0:
            return 0.0
        return self.eval_tokens / self.eval_seconds


def _post(host: str, path: str, payload: dict, timeout: float) -> tuple[int, str]:
    request = urllib.request.Request(
        f"{host.rstrip('/')}{path}",
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return response.status, response.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode("utf-8", "replace")


def _get(host: str, path: str, timeout: float) -> tuple[int, str]:
    request = urllib.request.Request(f"{host.rstrip('/')}{path}", method="GET")
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return response.status, response.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode("utf-8", "replace")


def chat(
    model: str,
    system: str,
    user: str,
    *,
    host: str = DEFAULT_HOST,
    timeout: float = 1800.0,
    temperature: float = 0.2,
    num_ctx: int = 16384,
    json_format: bool = True,
    no_think: bool = True,
) -> ChatResult:
    """One non-streaming chat completion.

    ``no_think`` matters more than it looks: a reasoning model left in
    thinking mode spends most of its budget on reasoning tokens the
    notulen never shows, which on a 6 GB GPU is the difference between
    40 seconds and 6 minutes per meeting. Ollama rejects ``think`` for
    models that have no thinking mode, so a rejection is retried without
    it rather than failing the case.
    """
    payload: dict = {
        "model": model,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        "stream": False,
        "options": {"temperature": temperature, "num_ctx": num_ctx},
    }
    if json_format:
        payload["format"] = "json"
    if no_think:
        payload["think"] = False

    started = time.monotonic()
    status, body = _post(host, "/api/chat", payload, timeout)
    if status >= 400 and no_think and "think" in body.lower():
        payload.pop("think")
        started = time.monotonic()
        status, body = _post(host, "/api/chat", payload, timeout)
        no_think = False
    elapsed = time.monotonic() - started

    if status >= 400:
        return ChatResult(error=f"HTTP {status}: {body[:300]}", seconds=elapsed)
    try:
        parsed = json.loads(body)
    except json.JSONDecodeError as e:
        return ChatResult(error=f"jawaban bukan JSON: {e} — {body[:200]}", seconds=elapsed)
    if "error" in parsed:
        return ChatResult(error=f"ollama: {parsed['error']}", seconds=elapsed)

    content = (parsed.get("message") or {}).get("content", "")
    return ChatResult(
        content=content,
        seconds=elapsed,
        prompt_tokens=int(parsed.get("prompt_eval_count") or 0),
        eval_tokens=int(parsed.get("eval_count") or 0),
        eval_seconds=float(parsed.get("eval_duration") or 0) / 1e9,
        thinking_disabled=no_think,
        raw={k: v for k, v in parsed.items() if k != "message"},
    )


def installed_models(host: str = DEFAULT_HOST, timeout: float = 30.0) -> list[str]:
    """Model names ``/api/tags`` reports."""
    status, body = _get(host, "/api/tags", timeout)
    if status >= 400:
        return []
    try:
        parsed = json.loads(body)
    except json.JSONDecodeError:
        return []
    return [m.get("name", "") for m in parsed.get("models", []) if m.get("name")]


def loaded_footprint(host: str = DEFAULT_HOST, timeout: float = 30.0) -> dict[str, dict]:
    """Resident size per loaded model, from ``/api/ps``.

    ``size`` is the total resident footprint and ``size_vram`` the part on
    the GPU; the difference is what the user's RAM has to hold. That split
    is exactly what the app's hardware-aware recommendation needs, so the
    report states it per model rather than quoting the download size.
    """
    status, body = _get(host, "/api/ps", timeout)
    if status >= 400:
        return {}
    try:
        parsed = json.loads(body)
    except json.JSONDecodeError:
        return {}
    out: dict[str, dict] = {}
    for model in parsed.get("models", []):
        name = model.get("name") or model.get("model")
        if not name:
            continue
        out[name] = {
            "size_bytes": int(model.get("size") or 0),
            "size_vram_bytes": int(model.get("size_vram") or 0),
        }
    return out


def unload(model: str, host: str = DEFAULT_HOST, timeout: float = 60.0) -> None:
    """Evict ``model`` from memory.

    Six models do not fit in 6 GB of VRAM at once. Without this, model
    five runs with four others resident, spills to system RAM, and gets
    recorded as slow when what was slow was the benchmark.
    """
    _post(host, "/api/chat", {"model": model, "messages": [], "keep_alive": 0}, timeout)
