"""Indonesian stemming and content-word extraction.

A deliberate, line-for-line mirror of ``rust_core/src/notulen/factcheck.rs``.
The app's "Periksa fakta" pass runs the Rust version; the bake-off runs
this one. If they disagree, the benchmark picks a model on numbers the
product will not reproduce, so ``fixtures/factcheck_cases.json`` is
asserted by a test on each side.

Affixation is why a naive word match fails here: a speaker says "kita
setujui", the notulen writes "disetujui", and a literal comparison reports
a correct decision as unsupported.
"""

from __future__ import annotations

#: Indonesian function words. Counting them would make every statement
#: look supported, since a transcript contains all of them.
STOPWORDS = frozenset(
    """yang dan dari untuk pada dengan ini itu adalah akan sudah telah tidak ada juga
    oleh atau dalam kita kami saya bahwa agar serta para bagi dapat harus lebih masih
    kepada sebagai tentang setelah sebelum karena sehingga antara secara bisa perlu
    saja maka hal sesuai terkait rapat""".split()
)

_SUFFIXES = ("nya", "lah", "kah", "pun", "kan", "an", "i")

#: Longest first: `mem` must not win over `memper`.
_PREFIXES = (
    "memper",
    "diper",
    "meny",
    "meng",
    "peny",
    "peng",
    "mem",
    "men",
    "pem",
    "pen",
    "ber",
    "bel",
    "ter",
    "tel",
    "per",
    "pel",
    "di",
    "ke",
    "se",
    "me",
    "pe",
)

#: Prefixes whose nasal assimilation swallowed a leading `s`:
#: `menyetujui` is `meN-` + `setujui`, so the `s` is restored.
_RESTORE_S = ("meny", "peny")


def stem(word: str) -> str:
    """Reduce an Indonesian word to a rough root.

    One suffix, then prefixes to a fixed point. Over-stems on purpose: a
    spurious match costs a missed finding, a missed match costs a false
    accusation of invention, and the second is what makes users stop
    reading the report.
    """
    root = word
    for suffix in _SUFFIXES:
        if root.endswith(suffix) and len(root) - len(suffix) >= 4:
            root = root[: -len(suffix)]
            break
    while True:
        before = root
        for prefix in _PREFIXES:
            if not root.startswith(prefix):
                continue
            shorter = root[len(prefix) :]
            if len(shorter) < 3:
                continue
            root = "s" + shorter if prefix in _RESTORE_S else shorter
            break
        if root == before:
            return root


def content_words(text: str) -> list[str]:
    """Stemmed content words of ``text``.

    Stopwords are removed *before* stemming: the stems of function words
    collide with content roots ("dalam" -> "alam").
    """
    out: list[str] = []
    current: list[str] = []
    for ch in text.lower():
        if ch.isalnum():
            current.append(ch)
            continue
        if current:
            word = "".join(current)
            current.clear()
            if len(word) > 2 and word not in STOPWORDS:
                out.append(stem(word))
    if current:
        word = "".join(current)
        if len(word) > 2 and word not in STOPWORDS:
            out.append(stem(word))
    return out


def overlap(claim: str, evidence: list[str]) -> float:
    """Fraction of ``claim``'s content words present in ``evidence``.

    A claim of only function words and digits has nothing checkable and
    scores 1.0; the number check covers it instead.
    """
    words = content_words(claim)
    if not words:
        return 1.0
    present = set(evidence)
    return sum(1 for word in words if word in present) / len(words)


def numbers(text: str) -> list[str]:
    """Every number in ``text``, keeping thousand separators.

    "8.500.000" is one number, not three.
    """
    out: list[str] = []
    current = ""
    for ch in text + " ":
        if ch.isdigit() or (ch in ".," and current):
            current += ch
        else:
            if current:
                trimmed = current.rstrip(".,")
                if trimmed:
                    out.append(trimmed)
            current = ""
    return out


_UNITS = (
    "nol",
    "satu",
    "dua",
    "tiga",
    "empat",
    "lima",
    "enam",
    "tujuh",
    "delapan",
    "sembilan",
)
#: 10^3k scale names, index = k.
_SCALES = ("", "ribu", "juta", "miliar", "triliun", "kuadriliun")


def spell_integer(value: int) -> str | None:
    """Spell a non-negative integer in Indonesian.

    Mirrors ``rust_core/src/notulen/angka.rs``. Going digits -> words,
    not words -> digits: generating is deterministic, while parsing
    "dua ribu dua puluh enam" needs a grammar whose every bug turns a
    real figure into a fabricated-number finding.
    """
    if value < 0:
        return None
    if value < 10:
        return _UNITS[value]
    if value == 10:
        return "sepuluh"
    if value == 11:
        return "sebelas"
    if value < 20:
        return f"{_UNITS[value % 10]} belas"
    if value < 100:
        tens, ones = divmod(value, 10)
        head = f"{_UNITS[tens]} puluh"
        return head if ones == 0 else f"{head} {_UNITS[ones]}"
    if value < 1000:
        hundreds, rest = divmod(value, 100)
        head = "seratus" if hundreds == 1 else f"{_UNITS[hundreds]} ratus"
        if rest == 0:
            return head
        tail = spell_integer(rest)
        return None if tail is None else f"{head} {tail}"

    groups: list[int] = []
    remaining = value
    while remaining > 0:
        remaining, group = divmod(remaining, 1000)
        groups.append(group)
    if len(groups) > len(_SCALES):
        return None
    parts: list[str] = []
    for index in range(len(groups) - 1, -1, -1):
        group = groups[index]
        if group == 0:
            continue
        if index == 1 and group == 1:
            parts.append("seribu")  # 1000, not "satu ribu"
            continue
        spelled = spell_integer(group)
        if spelled is None:
            return None
        parts.append(f"{spelled} {_SCALES[index]}".strip())
    return " ".join(parts)


def spoken_forms(written: str) -> list[str]:
    """Word forms worth searching a transcript for, given a written figure."""
    bare = "".join(ch for ch in written if ch.isdigit())
    if not bare:
        return []
    # A clock reads as its hour, and only as its hour: reading "08.00"
    # as 800 too would let "delapan ratus juta" vouch for a meeting time
    # nobody stated.
    for separator in (":", "."):
        if separator not in written:
            continue
        head, _, tail = written.partition(separator)
        head_digits = "".join(ch for ch in head if ch.isdigit())
        tail_digits = "".join(ch for ch in tail if ch.isdigit())
        if head_digits and len(head_digits) <= 2 and len(tail_digits) == 2:
            words = spell_integer(int(head_digits))
            return [words] if words else []
        break
    words = spell_integer(int(bare))
    return [words] if words else []


def number_supported(number: str, haystack_lower: str) -> bool:
    """Whether ``number``, or its Indonesian word form, is in the transcript."""
    if number in haystack_lower:
        return True
    bare = "".join(ch for ch in number if ch.isdigit())
    if bare and bare != number and bare in haystack_lower:
        return True
    return any(words in haystack_lower for words in spoken_forms(number))


#: Capitalised words that are not personal names: months, days, dinas
#: vocabulary, institutions, and the section headings themselves.
BUKAN_NAMA = frozenset(
    """januari februari maret april mei juni juli agustus september oktober november
    desember senin selasa rabu kamis jumat sabtu minggu rapat notulen notula risalah
    berita acara keputusan kesimpulan pembahasan tindak lanjut peserta agenda pimpinan
    notulis sekretaris ketua kepala direktur direktorat jenderal kementerian
    sekretariat biro bagian subbagian bidang unit kerja tim panitia kelompok lampiran
    nomor tanggal waktu tempat hari pukul wib wita wit indonesia republik pemerintah
    daerah provinsi kabupaten kota jakarta bapak ibu saudara yth dan atau dengan untuk
    pada dari oleh sebagai yang akan telah tidak dalam para seluruh semua""".split()
)


def proper_names(text: str) -> list[str]:
    """Name-shaped tokens: capitalised, not sentence-opening, not vocabulary.

    Deliberately conservative. A false "invented name" finding on every
    notulen trains the user to ignore the whole report.
    """
    names: set[str] = set()
    sentence = ""
    for ch in text:
        if ch in ".!?\n;:":
            _collect_names(sentence, names)
            sentence = ""
        else:
            sentence += ch
    _collect_names(sentence, names)
    return sorted(names)


def _trim_non_alnum(word: str) -> str:
    start, end = 0, len(word)
    while start < end and not word[start].isalnum():
        start += 1
    while end > start and not word[end - 1].isalnum():
        end -= 1
    return word[start:end]


def _collect_names(sentence: str, into: set[str]) -> None:
    for index, word in enumerate(sentence.split()):
        clean = _trim_non_alnum(word)
        if len(clean) < 3 or index == 0:
            continue
        if not clean[0].isupper():
            continue
        letters = [c for c in clean if c.isalpha()]
        if letters and all(c.isupper() for c in letters):
            # ALL CAPS is a heading or an acronym, not a personal name.
            continue
        if clean.lower() in BUKAN_NAMA:
            continue
        into.add(clean)
