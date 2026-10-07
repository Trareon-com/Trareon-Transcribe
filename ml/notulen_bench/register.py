"""EYD V / Tata Naskah Dinas register check — the Python mirror.

``rust_core/src/notulen/register.rs`` is the shipped implementation. The
lexicon below is the same data, and ``fixtures/register_cases.json`` is
asserted by a test on each side so the benchmark's formality score is the
one the app will show.

Rules come from the Pedoman Tata Naskah Dinas (Pedoman Menteri Kominfo
No. 03/2019 butir P, which mandates bahasa Indonesia baku per KBBI) and
the ``naskah-dinas-komdigi`` ejaan table.
"""

from __future__ import annotations

from dataclasses import dataclass

#: ``(colloquial, baku)`` — replaced automatically, because each formal
#: equivalent is a single word and the substitution cannot change meaning.
BAKU: tuple[tuple[str, str], ...] = (
    ("gak", "tidak"),
    ("nggak", "tidak"),
    ("enggak", "tidak"),
    ("udah", "sudah"),
    ("udh", "sudah"),
    ("blm", "belum"),
    ("kalo", "kalau"),
    ("gimana", "bagaimana"),
    ("kenapa", "mengapa"),
    ("bikin", "membuat"),
    ("ngasih", "memberikan"),
    ("dikasih", "diberikan"),
    ("kerjain", "kerjakan"),
    ("nanya", "bertanya"),
    ("ngomong", "menyampaikan"),
    ("bareng", "bersama"),
    ("dapet", "mendapat"),
    ("pengen", "ingin"),
    ("makasih", "terima kasih"),
    ("oke", "baik"),
    ("ok", "baik"),
    ("analisa", "analisis"),
    ("aktifitas", "aktivitas"),
    ("efektifitas", "efektivitas"),
    ("kreatifitas", "kreativitas"),
    ("praktek", "praktik"),
    ("resiko", "risiko"),
    ("obyek", "objek"),
    ("subyek", "subjek"),
    ("standarisasi", "standardisasi"),
    ("managemen", "manajemen"),
    ("menejemen", "manajemen"),
    ("jadual", "jadwal"),
    ("nomer", "nomor"),
    ("ijin", "izin"),
    ("sekedar", "sekadar"),
    ("silahkan", "silakan"),
    ("mempengaruhi", "memengaruhi"),
    ("seksama", "saksama"),
    ("komplit", "lengkap"),
    ("kordinasi", "koordinasi"),
    ("rapot", "rapor"),
    ("prosentase", "persentase"),
    ("dimana", "di mana"),
    ("kemana", "ke mana"),
    ("kesini", "ke sini"),
    ("disana", "di sana"),
    ("kebijaksanaan anggaran", "kebijakan anggaran"),
)

#: Reported but never auto-replaced: the repair is a rewrite, and silently
#: rephrasing a decision is how a notulen stops being a record.
FLAG_ONLY: tuple[tuple[str, str], ...] = (
    ("banget", 'ganti dengan "sangat" dan susun ulang kalimatnya'),
    ("kayak", 'ganti dengan "seperti" dan susun ulang kalimatnya'),
    ("aja", "hilangkan; tulis kalimat lengkap"),
    ("sih", "hilangkan; partikel percakapan"),
    ("deh", "hilangkan; partikel percakapan"),
    ("dong", "hilangkan; partikel percakapan"),
    ("nih", "hilangkan; partikel percakapan"),
    ("tuh", "hilangkan; partikel percakapan"),
    ("kok", "hilangkan; partikel percakapan"),
    ("lho", "hilangkan; partikel percakapan"),
    ("ya kan", "hilangkan; penegas percakapan"),
    ("gitu", 'ganti dengan "demikian"'),
    ("gini", 'ganti dengan "seperti ini"'),
    (
        "dan lain-lain",
        'Pedoman melarang "dan lain-lain" di naskah resmi — sebutkan rinciannya',
    ),
    ("dll", 'Pedoman melarang "dll." di naskah resmi — sebutkan rinciannya'),
    ("dsb", 'Pedoman melarang "dsb." di naskah resmi — sebutkan rinciannya'),
)

_SPOKEN = frozenset(
    "gak nggak udah udh blm kalo bikin dapet pengen oke ok bareng nanya".split()
)
_GAYA_DINAS = frozenset(["dan lain-lain", "dll", "dsb"])


@dataclass
class Finding:
    rule: str
    ditemukan: str
    saran: str
    baris: int
    otomatis: bool


def _is_word_boundary(text: str, at: int, length: int) -> bool:
    before = text[at - 1] if at > 0 else ""
    after = text[at + length] if at + length < len(text) else ""
    return not (before.isalnum() or before == "-") and not (after.isalnum() or after == "-")


def find_words(line: str, needle: str) -> list[int]:
    """Case-insensitive whole-word search, returning offsets."""
    lower_line = line.lower()
    lower_needle = needle.lower()
    hits: list[int] = []
    at = 0
    while at + len(lower_needle) <= len(lower_line):
        if lower_line.startswith(lower_needle, at) and _is_word_boundary(
            line, at, len(lower_needle)
        ):
            hits.append(at)
            at += len(lower_needle)
        else:
            at += 1
    return hits


def check(text: str) -> list[Finding]:
    """Every register problem in ``text``, line by line."""
    findings: list[Finding] = []
    for index, line in enumerate(text.splitlines()):
        baris = index + 1
        for bad, good in BAKU:
            for _ in find_words(line, bad):
                rule = (
                    "KataTidakBaku"
                    if len(bad) <= 7 and " " not in bad and bad in _SPOKEN
                    else "EjaanBaku"
                )
                findings.append(Finding(rule, bad, good, baris, True))
        for bad, advice in FLAG_ONLY:
            for _ in find_words(line, bad):
                rule = "GayaDinas" if bad in _GAYA_DINAS else "KataTidakBaku"
                findings.append(Finding(rule, bad, advice, baris, False))
        findings.extend(_number_findings(line, baris))
    return findings


def _number_findings(line: str, baris: int) -> list[Finding]:
    findings: list[Finding] = []
    for index in range(len(line) - 4):
        window = line[index : index + 5]
        if (
            window[0].isdigit()
            and window[1].isdigit()
            and window[2] == ":"
            and window[3].isdigit()
            and window[4].isdigit()
        ):
            findings.append(
                Finding(
                    "FormatAngka",
                    window,
                    f"pukul {window.replace(':', '.')} WIB",
                    baris,
                    True,
                )
            )
    for at in find_words(line, "rp"):
        amount = " ".join(line[at:].split()[:2]).rstrip(".,;")
        lower = amount.lower()
        if lower.startswith("rp.") or lower.startswith("rp "):
            saran = "tulis tanpa titik dan tanpa spasi, mis. Rp8.500.000,00"
        elif ",-" in amount:
            saran = 'akhiri dengan ",00", bukan ",-"'
        else:
            continue
        findings.append(Finding("FormatAngka", amount, saran, baris, False))
    findings.extend(_date_findings(line, baris))
    return findings


def _date_findings(line: str, baris: int) -> list[Finding]:
    findings: list[Finding] = []
    digits = 0
    dashes = 0
    start = 0
    for index, ch in enumerate(line):
        if ch.isdigit():
            if digits == 0 and dashes == 0:
                start = index
            digits += 1
        elif ch in "-/" and digits > 0:
            dashes += 1
            digits = 0
        else:
            if dashes == 2 and digits >= 2:
                findings.append(
                    Finding(
                        "FormatAngka",
                        line[start:index],
                        "tulis tanggal lengkap, mis. 5 Oktober 2026",
                        baris,
                        False,
                    )
                )
            digits = 0
            dashes = 0
    if dashes == 2 and digits >= 2:
        findings.append(
            Finding(
                "FormatAngka",
                line[start:],
                "tulis tanggal lengkap, mis. 5 Oktober 2026",
                baris,
                False,
            )
        )
    return findings


def normalise(text: str) -> str:
    """Apply every unambiguous replacement, preserving capitalisation."""
    out = text
    for bad, good in BAKU:
        out = _replace_words(out, bad, good)
    return _replace_clock(out)


def _replace_words(text: str, needle: str, replacement: str) -> str:
    out: list[str] = []
    rest = text
    while True:
        hits = find_words(rest, needle)
        if not hits:
            out.append(rest)
            return "".join(out)
        at = hits[0]
        out.append(rest[:at])
        original = rest[at : at + len(needle)]
        out.append(_match_case(original, replacement))
        rest = rest[at + len(needle) :]


def _match_case(original: str, replacement: str) -> str:
    if not original[:1].isupper():
        return replacement
    return replacement[:1].upper() + replacement[1:]


def _replace_clock(text: str) -> str:
    out: list[str] = []
    index = 0
    while index < len(text):
        window = text[index : index + 5]
        if (
            len(window) == 5
            and window[0].isdigit()
            and window[1].isdigit()
            and window[2] == ":"
            and window[3].isdigit()
            and window[4].isdigit()
        ):
            out.append(window.replace(":", ".", 1))
            index += 5
            continue
        out.append(text[index])
        index += 1
    return "".join(out)


def formality_score(text: str) -> float:
    """``0.0..=1.0``: register findings per 100 words, inverted.

    Empty text scores **0.0**, not 1.0. A notulen with no words has no
    register to be formal in, and the old ``max(len(words), 1)`` floor
    handed a perfect 0.20 of the composite to a model that produced
    nothing. Measured: Sahabat-AI 9B answered the notulen prompt with an
    unrelated boilerplate object (`{"name": "John Doe", ...}`), rendered
    to zero words, and banked full marks for formality on the way to a
    mid-table composite. A metric that rewards the absence of a document
    is worse than no metric.
    """
    words = len(text.split())
    if words == 0:
        return 0.0
    per_hundred = len(check(text)) * 100.0 / words
    return max(0.0, min(1.0, 1.0 - per_hundred / 5.0))
