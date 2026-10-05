"""The six metrics the bake-off scores on.

Each one exists because a model can be good at the others and still
unusable:

* A model can fill every section and invent the decisions in them
  (`faithfulness`).
* It can be perfectly faithful and write "oke, nanti kita bikin"
  (`formality`).
* It can summarise beautifully and drop every penanggung jawab
  (`action_items`).
* It can do all of it at 0.4 tokens/s on the hardware the user owns
  (`latency`, measured by the runner).

ROUGE is included because it is the number the literature reports, and
excluded from the composite for the reason the literature keeps
rediscovering: it rewards copying the reference's wording. It is reported
as context, not as a ranking.
"""

from __future__ import annotations

from collections import Counter
from dataclasses import dataclass, field

from . import register, stem
from .dataset import Case
from .schema import TEMPLATE_SECTIONS

#: Minimum content-word overlap for a claim to count as supported.
#: Mirrors ``factcheck::MIN_DUKUNGAN``.
MIN_DUKUNGAN = 0.35

#: Minimum overlap with the cited segments before a citation is called
#: misaimed. Mirrors ``factcheck::MIN_RUJUKAN``.
MIN_RUJUKAN = 0.2

#: Token-overlap threshold at which a produced follow-up is considered to
#: be "the same task" as a gold one. 0.5 — half the task's content words —
#: matches on paraphrase while refusing to match two different tasks that
#: share one noun.
TASK_MATCH = 0.5


@dataclass
class CaseScore:
    """Every metric for one (model, case) pair."""

    case_id: str
    model: str
    ok: bool = False
    error: str = ""
    repairs: list[str] = field(default_factory=list)
    structure: float = 0.0
    missing_sections: list[str] = field(default_factory=list)
    #: Decisions produced for a meeting whose gold has none. The single
    #: most damaging failure mode: an invented decision in a signed naskah.
    invented_decisions: int = 0
    faithfulness: float = 0.0
    unsupported: list[str] = field(default_factory=list)
    #: Statements whose `segmen` citations exist and match, over all
    #: statements. Reported apart from faithfulness: a true statement
    #: with a broken link is a different defect from an invented one.
    citation_accuracy: float = 0.0
    citation_notes: list[str] = field(default_factory=list)
    formality: float = 0.0
    register_findings: int = 0
    action_f1: float = 0.0
    action_precision: float = 0.0
    action_recall: float = 0.0
    owner_accuracy: float = 0.0
    rouge1: float = 0.0
    rouge2: float = 0.0
    rougel: float = 0.0
    seconds: float = 0.0
    tokens_per_second: float = 0.0
    output_chars: int = 0

    @property
    def composite(self) -> float:
        """The single number the default model was chosen on.

        Weights, and why: faithfulness 0.35 because an invented decision
        in a signed naskah is the one failure with legal consequences;
        structure 0.25 because a missing required section makes the
        document unusable as a naskah dinas; action items 0.20 because
        the tindak-lanjut table is what the pimpinan reads; formality
        0.20 because a notulen in spoken register has to be rewritten by
        hand, which removes the point of generating it. ROUGE is excluded
        — see the module docstring.
        """
        if not self.ok:
            return 0.0
        return (
            0.35 * self.faithfulness
            + 0.25 * self.structure
            + 0.20 * self.action_f1
            + 0.20 * self.formality
        )


def score_case(case: Case, model: str, notulen: dict, repairs: list[str]) -> CaseScore:
    """All content metrics for one produced notulen."""
    score = CaseScore(case_id=case.id, model=model, ok=True, repairs=list(repairs))
    # A section the meeting itself did not produce cannot be required of
    # the model. Case 07 is a sosialisasi that took no decisions: scoring
    # it down for an empty Keputusan would reward exactly the invention
    # the fact check exists to catch.
    gold_sections = (("keputusan", case.keputusan), ("tindak_lanjut", case.tindak_lanjut))
    skip = {key for key, gold in gold_sections if not gold}
    score.structure, score.missing_sections = structure_score(notulen, case.templat, skip)
    score.invented_decisions = len(notulen.get("keputusan", [])) if not case.keputusan else 0
    (
        score.faithfulness,
        score.unsupported,
        score.citation_accuracy,
        score.citation_notes,
    ) = faithfulness_score(notulen, case)
    text = rendered_text(notulen)
    score.output_chars = len(text)
    score.formality = register.formality_score(text)
    score.register_findings = len(register.check(text))
    (
        score.action_f1,
        score.action_precision,
        score.action_recall,
        score.owner_accuracy,
    ) = action_item_scores(notulen, case)
    score.rouge1 = rouge_n(text, case.referensi, 1)
    score.rouge2 = rouge_n(text, case.referensi, 2)
    score.rougel = rouge_l(text, case.referensi)
    return score


def rendered_text(notulen: dict) -> str:
    """The notulen as the document will read it.

    Register and ROUGE must see what reaches the page, not the JSON
    punctuation: scoring the raw response would count every `"segmen":`
    as text and reward a model for emitting more of it.
    """
    lines: list[str] = []
    if notulen.get("ringkasan"):
        lines.append(notulen["ringkasan"])
    for key in ("peserta", "agenda", "pihak"):
        lines.extend(notulen.get(key, []))
    for item in notulen.get("jalannya_rapat", []):
        speaker = item.get("pembicara", "")
        lines.append(f"{speaker}: {item['pokok']}" if speaker else item["pokok"])
    for item in notulen.get("pembahasan", []):
        if item.get("topik"):
            lines.append(item["topik"])
        if item.get("uraian"):
            lines.append(item["uraian"])
    lines.extend(item["isi"] for item in notulen.get("keputusan", []))
    for item in notulen.get("tindak_lanjut", []):
        parts = [item["tugas"], item.get("penanggung_jawab", ""), item.get("tenggat", "")]
        lines.append(" | ".join(p for p in parts if p))
    return "\n".join(lines)


# --------------------------------------------------------------------------
# 1. structure compliance
# --------------------------------------------------------------------------


def structure_score(
    notulen: dict, templat: str, skip: set[str] | None = None
) -> tuple[float, list[str]]:
    """Fraction of the template's required sections that are filled.

    ``skip`` names sections the meeting itself did not produce, which are
    dropped from the denominator rather than counted as failures.
    """
    sections = TEMPLATE_SECTIONS.get(templat)
    if sections is None:
        raise ValueError(f"templat tidak dikenal: {templat}")
    skip = skip or set()
    required = [(key, heading) for key, heading, req in sections if req and key not in skip]
    if not required:
        return 1.0, []
    missing = [heading for key, heading in required if not notulen.get(key)]
    return (len(required) - len(missing)) / len(required), missing


# --------------------------------------------------------------------------
# 2. factual faithfulness
# --------------------------------------------------------------------------


def faithfulness_score(notulen: dict, case: Case) -> tuple[float, list[str], float, list[str]]:
    """``(faithfulness, unsupported, citation_accuracy, citation_notes)``.

    Two scores, because they mean different things to a reader. A
    statement the transcript does not support is a fabrication about to
    be signed; a statement that is true but cites the wrong segment is a
    broken link. Averaging them into one number would let a model with
    sloppy citations look as dangerous as one that invents decisions.

    Both are scored over keputusan and tindak_lanjut only — the sections
    that carry commitments. ``citation_accuracy`` counts a statement only
    when it cited segments that exist *and* overlap it, over all
    statements: a model that cites nothing scores 0.0, because a notulen
    with no provenance cannot be checked by the shipped fact check
    either.
    """
    # Speaker labels are part of the transcript, not metadata around it.
    # Leaving them out made every penanggung jawab named only by their
    # speaker label — which is most of them — look invented.
    transcript = " ".join(f"{s.speaker} {s.text}" for s in case.segments)
    lower = transcript.lower()
    all_words = stem.content_words(transcript)
    by_id = {s.id: s for s in case.segments}

    statements: list[tuple[str, list[int]]] = [
        (item["isi"], item.get("segmen", [])) for item in notulen.get("keputusan", [])
    ]
    for item in notulen.get("tindak_lanjut", []):
        text = item["tugas"]
        if item.get("penanggung_jawab"):
            text += f" — penanggung jawab {item['penanggung_jawab']}"
        if item.get("tenggat"):
            text += f", tenggat {item['tenggat']}"
        statements.append((text, item.get("segmen", [])))

    if not statements:
        # Nothing claimed is not a faithfulness failure; the structure
        # metric is what penalises an empty required section.
        return 1.0, [], 1.0, []

    # A meeting that decided nothing is the sharpest anti-hallucination
    # test there is, and a decision invented for it can still pass the
    # lexical check by restating a discussion point. So it is failed
    # outright rather than scored.
    decided_nothing = not case.keputusan

    unsupported: list[str] = []
    citation_notes: list[str] = []
    clean = 0
    cited_well = 0
    for text, ids in statements:
        problems: list[str] = []
        if decided_nothing and any(
            text == item["isi"] for item in notulen.get("keputusan", [])
        ):
            problems.append("rapat ini tidak mengambil keputusan")
        if stem.overlap(text, all_words) < MIN_DUKUNGAN:
            problems.append("dukungan transkrip lemah")
        for number in stem.numbers(text):
            if not stem.number_supported(number, lower):
                problems.append(f'angka "{number}" tidak ada')
        for name in stem.proper_names(text):
            if name.lower() not in lower:
                problems.append(f'nama "{name}" tidak ada')
        if problems:
            unsupported.append(f"{text} → {'; '.join(problems)}")
        else:
            clean += 1

        # Citation quality, scored and reported apart from the above.
        if not ids:
            citation_notes.append(f"{text} → tanpa rujukan segmen")
            continue
        valid = [i for i in ids if i in by_id]
        if len(valid) < len(ids):
            citation_notes.append(f"{text} → rujukan segmen tidak ada")
            continue
        cited = [w for i in valid for w in stem.content_words(by_id[i].text)]
        if stem.overlap(text, cited) < MIN_RUJUKAN:
            citation_notes.append(f"{text} → rujukan segmen tidak cocok")
            continue
        cited_well += 1

    citation_accuracy = cited_well / len(statements)
    return clean / len(statements), unsupported, citation_accuracy, citation_notes


# --------------------------------------------------------------------------
# 3. action-item extraction F1
# --------------------------------------------------------------------------


def action_item_scores(notulen: dict, case: Case) -> tuple[float, float, float, float]:
    """``(f1, precision, recall, owner_accuracy)`` against the gold tasks.

    Matching is greedy on content-word overlap rather than string
    equality: a model that writes "Menyusun draf RKA-KL" for the gold
    "Susun draf RKA-KL" has extracted the task.

    ``owner_accuracy`` is scored over *matched* tasks only, and counts a
    gold owner as hit when the produced owner contains it or vice versa —
    "Kepala Bagian Perencanaan" and "Kabag Perencanaan" are the same
    person, and a model that names the jabatan where the gold names the
    person has still answered the question.
    """
    gold = case.tindak_lanjut
    produced = notulen.get("tindak_lanjut", [])
    if not gold and not produced:
        return 1.0, 1.0, 1.0, 1.0
    if not gold or not produced:
        return 0.0, 0.0, 0.0, 0.0

    remaining = list(range(len(gold)))
    matches: list[tuple[int, int]] = []
    for p_index, item in enumerate(produced):
        best, best_score = None, 0.0
        for g_index in remaining:
            value = _task_similarity(item["tugas"], gold[g_index][0])
            if value > best_score:
                best, best_score = g_index, value
        if best is not None and best_score >= TASK_MATCH:
            matches.append((p_index, best))
            remaining.remove(best)

    precision = len(matches) / len(produced)
    recall = len(matches) / len(gold)
    f1 = 0.0 if precision + recall == 0 else 2 * precision * recall / (precision + recall)

    owners_checked = 0
    owners_right = 0
    for p_index, g_index in matches:
        gold_owner = gold[g_index][1].strip()
        if not gold_owner:
            continue
        owners_checked += 1
        if _owner_matches(produced[p_index].get("penanggung_jawab", ""), gold_owner):
            owners_right += 1
    owner_accuracy = 1.0 if owners_checked == 0 else owners_right / owners_checked
    return f1, precision, recall, owner_accuracy


def _task_similarity(left: str, right: str) -> float:
    a = set(stem.content_words(left))
    b = set(stem.content_words(right))
    if not a or not b:
        return 0.0
    return len(a & b) / len(a | b)


def _owner_matches(produced: str, gold: str) -> bool:
    produced_words = set(stem.content_words(produced))
    gold_words = set(stem.content_words(gold))
    if not produced_words or not gold_words:
        return False
    return bool(produced_words & gold_words)


# --------------------------------------------------------------------------
# 4. ROUGE
# --------------------------------------------------------------------------


def _tokens(text: str) -> list[str]:
    out: list[str] = []
    current: list[str] = []
    for ch in text.lower():
        if ch.isalnum():
            current.append(ch)
        elif current:
            out.append("".join(current))
            current.clear()
    if current:
        out.append("".join(current))
    return out


def rouge_n(candidate: str, reference: str, n: int) -> float:
    """ROUGE-N F1 over word n-grams."""
    cand = _ngrams(_tokens(candidate), n)
    ref = _ngrams(_tokens(reference), n)
    if not cand or not ref:
        return 0.0
    overlap = sum((cand & ref).values())
    precision = overlap / sum(cand.values())
    recall = overlap / sum(ref.values())
    if precision + recall == 0:
        return 0.0
    return 2 * precision * recall / (precision + recall)


def _ngrams(tokens: list[str], n: int) -> Counter[tuple[str, ...]]:
    if n <= 0 or len(tokens) < n:
        return Counter()
    return Counter(tuple(tokens[i : i + n]) for i in range(len(tokens) - n + 1))


def rouge_l(candidate: str, reference: str) -> float:
    """ROUGE-L F1 over the longest common subsequence."""
    cand = _tokens(candidate)
    ref = _tokens(reference)
    if not cand or not ref:
        return 0.0
    length = _lcs_length(cand, ref)
    if length == 0:
        return 0.0
    precision = length / len(cand)
    recall = length / len(ref)
    return 2 * precision * recall / (precision + recall)


def _lcs_length(a: list[str], b: list[str]) -> int:
    """LCS length in O(len(a) * len(b)) time and O(len(b)) space."""
    previous = [0] * (len(b) + 1)
    for token in a:
        current = [0]
        for index, other in enumerate(b):
            if token == other:
                current.append(previous[index] + 1)
            else:
                current.append(max(current[index], previous[index + 1]))
        previous = current
    return previous[-1]
