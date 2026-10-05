"""Notulen bake-off: which local LLM should write Indonesian meeting minutes.

Two research reports disagreed about the default model — one recommended
Sahabat-AI (Gemma2 9B CPT, the highest SEA-HELM Indonesian score in its
class), the other Qwen3-8B (Apache-2.0, long context). Neither
recommendation is measurable from the literature, because **no public
benchmark measures transcript → formal Indonesian minutes at all**: the
Indonesian summarisation sets (IndoSum, Liputan6) are news articles, and
SEA-HELM measures general instruction following.

So this package measures it. Six metrics over a hand-authored set of
Indonesian meeting transcripts with reference notulen in Tata Naskah
Dinas style:

================  ===========================================================
structure         required sections of the template actually filled
faithfulness      decisions, owners, numbers and names the transcript supports
formality         EYD V / Tata Naskah Dinas register findings per 100 words
action items      F1 of tugas/PJ extraction against the gold set
rouge             ROUGE-1/2/L against the reference notulen
latency           wall clock and tokens/s, with the hardware it ran on
================  ===========================================================

Deliberately dependency-free: ``urllib`` and the standard library only.
The bake-off runs on whichever machine has the GPU, and requiring a
virtualenv there is friction that ends with the benchmark not being run.

``prompts/`` is a copy of the prompts ``rust_core/src/notulen/prompt.rs``
ships, kept in sync by a Rust test. Measuring a prompt the app does not
use would measure nothing.
"""
