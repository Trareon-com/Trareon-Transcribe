#!/usr/bin/env python3
"""Qwen2.5-7B correction + summarization for Traeon Transcribe.

Reads a JSON request from argv[1]:
    {"transcript": "...", "speakers": ["A","B"], "language": "id"}

Writes JSON to stdout:
    {"corrected_text": "...", "summary": "...", "per_speaker_summary": [...]}

Backend selection:
- macOS Apple Silicon: MLX-LM (faster, ~55 tok/s).
- Other platforms: llama.cpp via subprocess (local GGUF, optionally GPU-offloaded).
- Custom: any OpenAI-chat-compatible HTTP endpoint (Ollama, Groq, OpenRouter,
  self-hosted llama-server, ...), opt-in via TRAEON_LLM_ENDPOINT.
- Fallback: pass-through (returns input transcript unchanged).

Offline by default: unless TRAEON_LLM_BACKEND=custom (or TRAEON_LLM_ENDPOINT is
set), this script makes zero network calls — both mlx and llama.cpp backends
run entirely on-device. The custom-endpoint backend is opt-in only and is the
sole path that can leave the machine; it never activates on its own.
"""
from __future__ import annotations

import json
import sys


def pass_through(req: dict) -> dict:
    """No-op: return the transcript verbatim."""
    speakers = req.get("speakers") or []
    return {
        "corrected_text": req.get("transcript", ""),
        "summary": "",
        "per_speaker_summary": [
            {"speaker": s, "summary": ""} for s in speakers
        ],
    }


def run_mlx(prompt: str) -> str:
    """Run Qwen2.5-7B via MLX-LM (macOS Apple Silicon)."""
    try:
        from mlx_lm import load, generate  # type: ignore
    except ImportError:
        return ""
    # Model path is configurable via env; default to a 4-bit quant.
    import os
    model_path = os.environ.get(
        "TRAEON_QWEN_MODEL",
        "mlx-community/Qwen2.5-7B-Instruct-4bit",
    )
    model, tokenizer = load(model_path)
    response = generate(
        model,
        tokenizer,
        prompt=prompt,
        max_tokens=512,
        temp=0.2,
    )
    return response


def run_llama_cpp(prompt: str) -> str:
    """Run Qwen2.5-7B via llama.cpp subprocess.

    Honors TRAEON_LLAMA_NGL to offload layers to GPU (Vulkan/CUDA/Metal —
    whichever backend the llama.cpp binary was built with). Defaults to 0
    (CPU-only) so behavior is unchanged unless the caller opts in.
    """
    import os
    import subprocess
    binary = os.environ.get("TRAEON_LLAMA_CPP", "llama-cli")
    model = os.environ.get(
        "TRAEON_QWEN_MODEL_GGUF",
        os.path.expanduser("~/Models/qwen2.5-7b-instruct-q4_k_m.gguf"),
    )
    ngl = os.environ.get("TRAEON_LLAMA_NGL", "0")
    try:
        result = subprocess.run(
            [
                binary,
                "-m", model,
                "-p", prompt,
                "-n", "512",
                "--temp", "0.2",
                "-ngl", ngl,
                "--single-turn",
                "--simple-io",
                "--no-display-prompt",
                "--no-warmup",
            ],
            capture_output=True,
            text=True,
            timeout=120,
        )
        return result.stdout.strip()
    except Exception:
        return ""


def run_custom_endpoint(prompt: str) -> str:
    """Run correction via any OpenAI-chat-compatible HTTP endpoint.

    Mirrors Meetily's "bring your own provider" flexibility: point
    TRAEON_LLM_ENDPOINT at Ollama, Groq, OpenRouter, or any self-hosted
    OpenAI-compatible server (llama-server included) without recompiling.

    Required env:
        TRAEON_LLM_ENDPOINT   e.g. http://localhost:11434/v1/chat/completions
        TRAEON_LLM_MODEL      model name as the endpoint expects it
    Optional env:
        TRAEON_LLM_API_KEY    sent as "Authorization: Bearer <key>" if set
    """
    import os
    import urllib.request
    import urllib.error

    endpoint = os.environ.get("TRAEON_LLM_ENDPOINT")
    if not endpoint:
        return ""
    model = os.environ.get("TRAEON_LLM_MODEL", "qwen2.5-7b-instruct")
    api_key = os.environ.get("TRAEON_LLM_API_KEY")

    body = json.dumps(
        {
            "model": model,
            "messages": [{"role": "user", "content": prompt}],
            "temperature": 0.2,
            "max_tokens": 512,
        }
    ).encode("utf-8")

    headers = {"Content-Type": "application/json"}
    if api_key:
        headers["Authorization"] = f"Bearer {api_key}"

    req = urllib.request.Request(endpoint, data=body, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            data = json.loads(resp.read().decode("utf-8"))
        return data["choices"][0]["message"]["content"].strip()
    except (urllib.error.URLError, KeyError, IndexError, json.JSONDecodeError):
        return ""


def parse_qwen_output(text: str) -> tuple[str, list[str]]:
    """Parse Qwen's structured response into (corrected, summary_bullets)."""
    if not text:
        return "", []
    corrected = ""
    bullets: list[str] = []
    section = None
    for line in text.splitlines():
        s = line.strip()
        if s.upper().startswith("KOREKSI:"):
            section = "koreksi"
            corrected = s.split(":", 1)[1].strip()
            continue
        if s.upper().startswith("RINGKASAN"):
            section = "ringkasan"
            # Reset: llama-cli echoes the input prompt before the real
            # completion, and our prompt itself contains a RINGKASAN
            # placeholder block as a formatting example. Keep only the
            # LAST RINGKASAN section encountered (the actual answer),
            # discarding any bullets accumulated from the echoed prompt.
            bullets = []
            continue
        if section == "koreksi" and corrected == "" and s:
            corrected = s
        elif section == "ringkasan" and s.startswith("-"):
            bullets.append(s[1:].strip())
    return corrected, bullets


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: qwen_correction.py <request.json>", file=sys.stderr)
        return 2
    try:
        req = json.loads(sys.argv[1])
    except json.JSONDecodeError as e:
        print(f"invalid json: {e}", file=sys.stderr)
        return 2

    # Build the Indonesian prompt (mirrors Rust build_correction_prompt).
    prompt = (
        "Anda adalah asisten transkripsi berbahasa Indonesia.\n"
        "Tugas: Koreksi kesalahan pengucapan dari hasil ASR, lalu buat ringkasan.\n"
        "Aturan:\n"
        "- Pertahankan nama orang, istilah teknis, dan angka.\n"
        "- Jangan menambahkan informasi yang tidak ada di transkrip.\n"
        "- Tulis ringkasan dalam 3 poin singkat.\n\n"
        f"Transkrip:\n{req.get('transcript', '')}\n\n"
        "Format jawaban:\nKOREKSI: <teks terkoreksi>\nRINGKASAN:\n- <poin 1>\n- <poin 2>\n- <poin 3>"
    )

    # Backend selection.
    import platform
    import os
    backend = os.environ.get("TRAEON_LLM_BACKEND")
    if backend is None:
        if os.environ.get("TRAEON_LLM_ENDPOINT"):
            backend = "custom"
        elif platform.system() == "Darwin" and platform.machine().startswith("arm"):
            backend = "mlx"
        else:
            backend = "llama.cpp"

    if backend == "mlx":
        raw = run_mlx(prompt)
    elif backend == "llama.cpp":
        raw = run_llama_cpp(prompt)
    elif backend == "custom":
        raw = run_custom_endpoint(prompt)
    else:
        raw = ""

    if not raw:
        # Pass-through fallback so the pipeline never breaks.
        out = pass_through(req)
        print(json.dumps(out))
        return 0

    corrected, bullets = parse_qwen_output(raw)
    speakers = req.get("speakers") or []
    summary_text = "\n".join(f"- {b}" for b in bullets)
    out = {
        "corrected_text": corrected or req.get("transcript", ""),
        "summary": summary_text,
        "per_speaker_summary": [
            {"speaker": s, "summary": ""} for s in speakers
        ],
    }
    print(json.dumps(out))
    return 0


if __name__ == "__main__":
    sys.exit(main())