"""Tolerant parse of a model's notulen JSON — the Python mirror.

``rust_core/src/notulen/schema.rs`` is the shipped implementation; this is
the benchmark's copy, kept in step by the shared fixtures under
``fixtures/``. A benchmark that is *stricter* than the app would score a
model down for output the app repairs fine, and a benchmark that is more
lenient would recommend a model whose output the app rejects.
"""

from __future__ import annotations

import json
from dataclasses import dataclass, field

#: Section keys and which templates require them. Mirrors
#: ``NotulenTemplate::sections`` in Rust.
TEMPLATE_SECTIONS: dict[str, list[tuple[str, str, bool]]] = {
    "notulen_dinas": [
        ("ringkasan", "Ringkasan", False),
        ("peserta", "Peserta", True),
        ("agenda", "Acara", False),
        ("jalannya_rapat", "Jalannya Rapat", False),
        ("pembahasan", "Pembahasan", True),
        ("keputusan", "Keputusan", True),
        ("tindak_lanjut", "Tindak Lanjut", True),
    ],
    "risalah_rapat": [
        ("peserta", "Peserta", True),
        ("agenda", "Acara", False),
        ("jalannya_rapat", "Jalannya Rapat", True),
        ("keputusan", "Keputusan", True),
        ("tindak_lanjut", "Tindak Lanjut", True),
    ],
    "berita_acara": [
        ("pihak", "Para Pihak", True),
        ("pembahasan", "Pelaksanaan", True),
        ("keputusan", "Kesepakatan", True),
        ("tindak_lanjut", "Tindak Lanjut", True),
    ],
    "notulen_ringkas": [
        ("ringkasan", "Ringkasan", False),
        ("pembahasan", "Pembahasan", True),
        ("keputusan", "Keputusan", True),
        ("tindak_lanjut", "Tindak Lanjut", True),
    ],
}

#: What a model writes to mean "nothing here". Left in place they become a
#: keputusan reading "Tidak ada" and a PJ called "-".
PLACEHOLDERS = frozenset(
    [
        "-",
        "–",
        "—",
        "n/a",
        "na",
        "null",
        "none",
        "tidak ada",
        "tidak ada.",
        "tidak disebutkan",
        "tidak disebutkan.",
        "belum ada",
        "...",
        "…",
    ]
)

_ALIASES = {
    "acara": "agenda",
    "para_pihak": "pihak",
    "jalannya": "jalannya_rapat",
    "kesimpulan": "keputusan",
    "kesepakatan": "keputusan",
    "action_items": "tindak_lanjut",
    "rencana_aksi": "tindak_lanjut",
}
_ITEM_ALIASES = {
    "judul": "topik",
    "pokok_bahasan": "topik",
    "ringkasan": "uraian",
    "detail": "uraian",
    "nama": "pembicara",
    "speaker": "pembicara",
    "penutur": "pembicara",
    "pernyataan": "pokok",
    "teks": "isi",
    "keputusan": "isi",
    "kegiatan": "tugas",
    "action": "tugas",
    "pj": "penanggung_jawab",
    "pic": "penanggung_jawab",
    "owner": "penanggung_jawab",
    "penanggungjawab": "penanggung_jawab",
    "batas_waktu": "tenggat",
    "due": "tenggat",
    "deadline": "tenggat",
}


@dataclass
class Parsed:
    """A parsed notulen plus everything the parser had to forgive."""

    notulen: dict = field(default_factory=dict)
    perbaikan: list[str] = field(default_factory=list)
    error: str = ""

    @property
    def ok(self) -> bool:
        return not self.error


def strip_thinking(raw: str) -> tuple[str, bool]:
    """Remove a reasoning model's ``<think>...</think>`` preamble."""
    lower = raw.lower()
    start = lower.find("<think>")
    if start < 0:
        return raw, False
    end = lower.find("</think>", start)
    if end < 0:
        # An unterminated block means the JSON never arrived; keep the
        # text so the caller can see why.
        return raw[:start], True
    return raw[:start] + raw[end + len("</think>") :], True


def extract_object(text: str) -> str | None:
    """The outermost ``{...}``, ignoring braces inside strings."""
    start = text.find("{")
    if start < 0:
        return None
    depth = 0
    in_string = False
    escaped = False
    for index in range(start, len(text)):
        ch = text[index]
        if in_string:
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == '"':
                in_string = False
            continue
        if ch == '"':
            in_string = True
        elif ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return text[start : index + 1]
    return None


def strip_trailing_commas(text: str) -> tuple[str, bool]:
    """Drop a ``,`` that immediately precedes ``}`` or ``]``, outside strings."""
    out: list[str] = []
    in_string = False
    escaped = False
    changed = False
    for index, ch in enumerate(text):
        if in_string:
            out.append(ch)
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == '"':
                in_string = False
            continue
        if ch == '"':
            in_string = True
            out.append(ch)
            continue
        if ch == ",":
            nxt = next((c for c in text[index + 1 :] if not c.isspace()), "")
            if nxt in "}]":
                changed = True
                continue
        out.append(ch)
    return "".join(out), changed


def _ids_from(value: object) -> list[int]:
    if value is None:
        return []
    if isinstance(value, bool):
        return []
    if isinstance(value, int):
        return [value]
    if isinstance(value, str):
        out: list[int] = []
        digits = ""
        for ch in value + " ":
            if ch.isdigit():
                digits += ch
            elif digits:
                out.append(int(digits))
                digits = ""
        return out
    if isinstance(value, list):
        return [i for item in value for i in _ids_from(item)]
    return []


def _split_people(text: str) -> list[str]:
    """Split one line holding several names.

    A comma only separates when the line has no newline or semicolon:
    "Dr. Siti Aminah, M.Si." is one person.
    """
    separators = "\n;" if ("\n" in text or ";" in text) else ","
    parts = [text]
    for sep in separators:
        parts = [piece for part in parts for piece in part.split(sep)]
    return [p.strip().lstrip("-*•").strip() for p in parts if p.strip()]


def _strings(value: object) -> list[str]:
    if value is None:
        return []
    if isinstance(value, str):
        return _split_people(value)
    if isinstance(value, list):
        return [s for item in value for s in _strings(item)]
    if isinstance(value, dict):
        for key in ("nama", "name", "jabatan"):
            if key in value:
                return _strings(value[key])
        return []
    return [str(value)]


def _split_inline_citation(text: str) -> tuple[str, list[int]]:
    """Split ``"Pagu disetujui. [#7,8]"`` into its text and its ids."""
    open_at = text.rstrip().rfind("[#")
    if open_at < 0:
        return text.strip(), []
    close = text.find("]", open_at)
    if close < 0:
        return text.strip(), []
    ids = _ids_from(text[open_at:close])
    if not ids:
        return text.strip(), []
    return (text[:open_at] + text[close + 1 :]).strip(), ids


def _looks_like_speaker(head: str) -> bool:
    connectors = {"dan", "atau", "serta", "a.n.", "u.b.", "de", "bin", "binti"}
    words = head.split()
    if not words or len(words) > 6 or len(head) > 64:
        return False
    return all(w.lower() in connectors or w[0].isupper() or w[0].isdigit() for w in words)


def _normalise_item(item: dict) -> dict:
    out: dict = {}
    for key, value in item.items():
        out[_ITEM_ALIASES.get(key.lower(), key.lower())] = value
    out["segmen"] = _ids_from(out.get("segmen"))
    return out


def _items(value: object, text_key: str, speaker_split: bool = False) -> list[dict]:
    """Map whatever container arrived onto a list of dicts."""
    if value is None:
        return []
    if isinstance(value, dict):
        return [_normalise_item(value)]
    if isinstance(value, str):
        lines = [ln.strip().lstrip("-*•").strip() for ln in value.splitlines()]
        value = [ln for ln in lines if ln]
    if not isinstance(value, list):
        return []
    out: list[dict] = []
    for item in value:
        if isinstance(item, dict):
            out.append(_normalise_item(item))
        elif isinstance(item, str):
            body, ids = _split_inline_citation(item)
            entry: dict = {"segmen": ids}
            if speaker_split and ":" in body:
                head, rest = body.split(":", 1)
                if _looks_like_speaker(head):
                    entry["pembicara"] = head.strip()
                    entry[text_key] = rest.strip()
                else:
                    entry[text_key] = body
            else:
                entry[text_key] = body
            out.append(entry)
    return out


def _is_placeholder(text: str) -> bool:
    return text.strip().lower() in PLACEHOLDERS


def _clean_text(value: object) -> str:
    text = str(value or "").strip()
    return "" if _is_placeholder(text) else text


def parse(raw: str) -> Parsed:
    """Turn whatever the model said into a normalised notulen dict."""
    perbaikan: list[str] = []
    without_thinking, had_thinking = strip_thinking(raw)
    if had_thinking:
        perbaikan.append("blok penalaran <think> dibuang")

    obj = extract_object(without_thinking)
    if obj is None:
        return Parsed(error="jawaban model tidak memuat objek JSON notulen")
    if len(obj) + 8 < len(without_thinking.strip()):
        perbaikan.append("teks di luar objek JSON dibuang")

    cleaned, had_trailing = strip_trailing_commas(obj)
    if had_trailing:
        perbaikan.append("koma berlebih sebelum penutup dibuang")

    try:
        loaded = json.loads(cleaned)
    except json.JSONDecodeError as e:
        return Parsed(error=f"objek JSON notulen tidak bisa dibaca: {e}")
    if not isinstance(loaded, dict):
        return Parsed(error="objek JSON notulen bukan objek")

    renamed = {_ALIASES.get(k.lower(), k.lower()): v for k, v in loaded.items()}
    notulen = {
        "ringkasan": _clean_text(renamed.get("ringkasan")),
        "peserta": [p for p in _strings(renamed.get("peserta")) if not _is_placeholder(p)],
        "agenda": [a for a in _strings(renamed.get("agenda")) if not _is_placeholder(a)],
        "pihak": [p for p in _strings(renamed.get("pihak")) if not _is_placeholder(p)],
        "jalannya_rapat": [],
        "pembahasan": [],
        "keputusan": [],
        "tindak_lanjut": [],
    }

    for item in _items(renamed.get("jalannya_rapat"), "pokok", speaker_split=True):
        pokok = _clean_text(item.get("pokok"))
        if pokok:
            notulen["jalannya_rapat"].append(
                {
                    "pembicara": _clean_text(item.get("pembicara")),
                    "pokok": pokok,
                    "segmen": item.get("segmen", []),
                }
            )
    for item in _items(renamed.get("pembahasan"), "uraian"):
        topik = _clean_text(item.get("topik"))
        uraian = _clean_text(item.get("uraian"))
        if topik or uraian:
            notulen["pembahasan"].append(
                {"topik": topik, "uraian": uraian, "segmen": item.get("segmen", [])}
            )
    for item in _items(renamed.get("keputusan"), "isi"):
        isi = _clean_text(item.get("isi"))
        if isi:
            notulen["keputusan"].append({"isi": isi, "segmen": item.get("segmen", [])})
    for item in _items(renamed.get("tindak_lanjut"), "tugas"):
        tugas = _clean_text(item.get("tugas"))
        if tugas:
            notulen["tindak_lanjut"].append(
                {
                    "tugas": tugas,
                    "penanggung_jawab": _clean_text(item.get("penanggung_jawab")),
                    "tenggat": _clean_text(item.get("tenggat")),
                    "segmen": item.get("segmen", []),
                }
            )
    return Parsed(notulen=notulen, perbaikan=perbaikan)
