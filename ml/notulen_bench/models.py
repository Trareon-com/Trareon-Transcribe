"""The candidates, and what their licences allow.

Licence matters as much as score here: Trareon ships to government
procurement, where "which licence covers the model you bundled" is a
question on the form. A model that wins the bake-off under a licence the
product cannot accept has not won anything, so the constraint is recorded
next to the candidate rather than discovered afterwards.

Every entry was verified to exist as a pullable Ollama tag in October
2026; ``notes`` records what could *not* be verified.
"""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class Candidate:
    """One model in the bake-off."""

    #: Ollama tag, pullable as written.
    tag: str
    #: Short name for the report table.
    label: str
    params: str
    quant: str
    #: Context window the tag advertises, in tokens.
    context: int
    licence: str
    #: Whether the licence permits bundling/recommending in a commercial
    #: product without a separate negotiation, as far as can be verified.
    commercial_ok: bool
    #: Indonesian-specific post-training, as claimed by the publisher.
    indonesian_tuned: bool
    notes: str = ""


#: The bake-off set. Four was the brief's floor; six are here because the
#: two questions the literature left open — "does Indonesian-specific
#: post-training beat a stronger general model" and "does 12B buy anything
#: over 8B on a laptop" — each need a pair to answer.
CANDIDATES: tuple[Candidate, ...] = (
    Candidate(
        tag="qwen3:4b",
        label="Qwen3 4B",
        params="4.0B",
        quant="Q4_K_M",
        context=40960,
        licence="Apache-2.0",
        commercial_ok=True,
        indonesian_tuned=False,
        notes="Light option candidate: the only class that is usable on a "
        "4-core CPU laptop without a GPU.",
    ),
    Candidate(
        tag="qwen3:8b",
        label="Qwen3 8B",
        params="8.2B",
        quant="Q4_K_M",
        context=40960,
        licence="Apache-2.0",
        commercial_ok=True,
        indonesian_tuned=False,
        notes="One of the two models the prior research rounds disagreed about.",
    ),
    Candidate(
        tag="gemma3:4b",
        label="Gemma 3 4B",
        params="4.3B",
        quant="Q4_K_M",
        context=131072,
        licence="Gemma Terms of Use",
        commercial_ok=False,
        indonesian_tuned=False,
        notes="Gemma Terms allow commercial use but carry a use-restriction "
        "policy and a redistribution obligation; treated as needing legal "
        "review before bundling, not before recommending.",
    ),
    Candidate(
        tag="gemma3:12b",
        label="Gemma 3 12B",
        params="12.2B",
        quant="Q4_K_M",
        context=131072,
        licence="Gemma Terms of Use",
        commercial_ok=False,
        indonesian_tuned=False,
        notes="Heavy option candidate. Does not fit 6 GB of VRAM at Q4; "
        "partially offloaded to system RAM in this run.",
    ),
    Candidate(
        tag="Supa-AI/gemma2-9b-cpt-sahabatai-v1-instruct:q4_k_s",
        label="Sahabat-AI 9B (Gemma2 CPT)",
        params="9.2B",
        quant="Q4_K_S",
        context=8192,
        licence="Gemma Community License",
        commercial_ok=False,
        indonesian_tuned=True,
        notes="Co-initiated by GoTo and Indosat with AI Singapore; highest "
        "SEA-HELM Indonesian score in its class. 8K context is the "
        "constraint: a one-hour meeting does not fit in one request, so it "
        "depends on map-reduce. Community GGUF republished by Supa-AI, not "
        "by the model's authors.",
    ),
    Candidate(
        tag="aisingapore/Apertus-SEA-LION-v4-8B-IT:q4_k_m",
        label="Apertus-SEA-LION v4 8B",
        params="8.1B",
        quant="Q4_K_M",
        context=65536,
        licence="Apache-2.0",
        commercial_ok=True,
        indonesian_tuned=True,
        notes="AI Singapore's 2026 SEA release, post-trained on ~6.4M "
        "instruction pairs across SEA languages including Indonesian. "
        "Published as GGUF by the authors' own Ollama namespace. The one "
        "candidate that is both Indonesian-tuned and cleanly licensed.",
    ),
)

#: Models considered and left out, with the reason. Recorded because "why
#: isn't X in the table" is the first question a reader has.
EXCLUDED: tuple[tuple[str, str], ...] = (
    (
        "Sahabat-AI v2 70B (Llama 3.1 70B)",
        "70B at Q4 is ~40 GB; outside any laptop this product targets.",
    ),
    (
        "Gemma-SEA-LION-v4 27B-IT",
        "27B at Q4 is ~17 GB; outside the 16 GB-RAM target machine.",
    ),
    (
        "SEA-LION v4 (Qwen 32B)",
        "32B at Q4 is ~20 GB; same reason.",
    ),
    (
        "Cendol-7B, Komodo-7B",
        "No current Ollama tag and no 2026 publisher activity found; the "
        "earlier research round already marked both unverified.",
    ),
    (
        "Gemma-SEA-LION-v3-9B-IT",
        "Superseded by the v4 line, which is the same family with a longer "
        "context and a clearer licence.",
    ),
)


def by_tag(tag: str) -> Candidate | None:
    return next((c for c in CANDIDATES if c.tag == tag), None)
