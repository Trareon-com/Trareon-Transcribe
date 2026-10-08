"""The notulen bake-off: parity with the shipped Rust, and the metrics.

The parity half reads the *same* ``fixtures/parity.json`` that
``rust_core/src/notulen/parity.rs`` reads. Neither side can be made to
pass by editing its own expectations, which is the only way to keep a
benchmark honest about a product it does not run.
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from notulen_bench import (
    dataset,
    metrics,
    models,
    ollama,
    register,
    run,
    schema,
    stem,
)

FIXTURE = Path(__file__).resolve().parent.parent / "notulen_bench" / "fixtures" / "parity.json"


@pytest.fixture(scope="module")
def parity() -> dict:
    return json.loads(FIXTURE.read_text(encoding="utf-8"))


# --------------------------------------------------------------------------
# parity with rust_core
# --------------------------------------------------------------------------


def test_stemming_matches_rust(parity: dict) -> None:
    for word, expected in parity["stem"]:
        assert stem.stem(word) == expected, word


def test_number_spelling_matches_rust(parity: dict) -> None:
    for value, expected in parity["spell_integer"]:
        assert stem.spell_integer(value) == expected, value


def test_spoken_forms_match_rust(parity: dict) -> None:
    for written, expected in parity["spoken_forms"]:
        assert stem.spoken_forms(written) == expected, written


def test_number_extraction_matches_rust(parity: dict) -> None:
    for text, expected in parity["numbers"]:
        assert stem.numbers(text) == expected, text


def test_proper_names_match_rust(parity: dict) -> None:
    for text, expected in parity["proper_names"]:
        assert stem.proper_names(text) == expected, text


def test_register_matches_rust(parity: dict) -> None:
    for text, expected, normalised in parity["register"]:
        # Sorted: both sides walk their lexicon in the same order, so
        # findings arrive in lexicon order rather than text order.
        found = sorted(f.ditemukan for f in register.check(text))
        assert found == sorted(expected), text
        assert register.normalise(text) == normalised, text


def test_tolerant_json_parse_matches_rust(parity: dict) -> None:
    for case in parity["schema"]:
        parsed = schema.parse(case["raw"])
        assert parsed.ok, f"{case['name']}: {parsed.error}"
        keputusan = [[k["isi"], k["segmen"]] for k in parsed.notulen["keputusan"]]
        assert keputusan == case["keputusan"], case["name"]
        follow_ups = [
            [t["tugas"], t["penanggung_jawab"], t["tenggat"]]
            for t in parsed.notulen["tindak_lanjut"]
        ]
        assert follow_ups == case["tindak_lanjut"], case["name"]


# --------------------------------------------------------------------------
# the dataset
# --------------------------------------------------------------------------


def test_every_case_parses_and_declares_its_template() -> None:
    cases = dataset.load_cases()
    assert len(cases) >= 20, "the brief asks for 20-30 meetings"
    for case in cases:
        assert case.templat in schema.TEMPLATE_SECTIONS, f"{case.id}: {case.templat}"
        assert case.segments, case.id
        assert case.referensi, case.id
        assert case.peserta, case.id
        # Synthetic is the honest label and has to be stated per case.
        assert case.sumber, case.id


def test_the_set_covers_every_template_and_a_long_meeting() -> None:
    cases = dataset.load_cases()
    templates = {c.templat for c in cases}
    assert templates == set(schema.TEMPLATE_SECTIONS), templates
    assert max(c.menit for c in cases) >= 30, "one case must be a 30-minute meeting"
    assert any("tanpa keputusan" in c.ciri for c in cases), (
        "a meeting that decided nothing is the sharpest anti-hallucination case"
    )
    assert any("code-switching" in c.ciri for c in cases)


def test_segment_numbering_is_dense_and_one_based() -> None:
    for case in dataset.load_cases():
        assert [s.id for s in case.segments] == list(range(1, len(case.segments) + 1))


def test_numbered_transcript_matches_the_rust_rendering() -> None:
    case = dataset.load_cases()[0]
    first = case.numbered_transcript.splitlines()[0]
    segment = case.segments[0]
    assert first == f"[1] 00:00 ({segment.speaker}): {segment.text}"


def test_gold_follow_ups_have_three_columns() -> None:
    for case in dataset.load_cases():
        for row in case.tindak_lanjut:
            assert len(row) == 3, f"{case.id}: {row}"
            assert row[0], f"{case.id}: a follow-up with no task"


def test_a_case_without_decisions_must_say_so() -> None:
    text = """# kasus
id: x
judul: X
templat: notulen_dinas
sumber: sintetis

# transkrip
[00:00] A: halo

# referensi
kosong

# emas
## peserta
- A
## keputusan
## tindak_lanjut
"""
    with pytest.raises(ValueError, match="tanpa keputusan"):
        dataset.parse_case(text)


def test_an_unparseable_transcript_line_is_rejected() -> None:
    text = """# kasus
id: x
judul: X
templat: notulen_dinas
sumber: sintetis
ciri: tanpa keputusan

# transkrip
halo tanpa stempel waktu

# referensi
kosong

# emas
## peserta
- A
## keputusan
## tindak_lanjut
"""
    with pytest.raises(ValueError, match="baris transkrip"):
        dataset.parse_case(text)


# --------------------------------------------------------------------------
# the metrics
# --------------------------------------------------------------------------


def _case(**overrides) -> dataset.Case:
    base = {
        "id": "uji",
        "judul": "Uji",
        "templat": "notulen_dinas",
        "jenis": "uji",
        "sumber": "sintetis",
        "menit": 1,
        "ciri": "",
        "segments": [
            dataset.Segment(1, 0.0, "Pimpinan Rapat", "pagu indikatif naik empat persen"),
            dataset.Segment(2, 10.0, "Pimpinan Rapat", "pagu itu kita setujui hari ini"),
            dataset.Segment(3, 20.0, "Budi", "saya susun draf rencana kerja"),
        ],
        "referensi": "Pagu indikatif disetujui.",
        "peserta": ["Pimpinan Rapat", "Budi"],
        "keputusan": ["Pagu indikatif disetujui."],
        "tindak_lanjut": [("Susun draf rencana kerja", "Budi", "10 Oktober 2026")],
    }
    base.update(overrides)
    return dataset.Case(**base)


def test_structure_scores_the_required_sections_only() -> None:
    score, missing = metrics.structure_score({"pembahasan": [{"uraian": "a"}]}, "notulen_dinas")
    assert missing == ["Peserta", "Keputusan", "Tindak Lanjut"]
    assert score == pytest.approx(0.25)


def test_structure_skips_sections_the_meeting_never_produced() -> None:
    score, missing = metrics.structure_score(
        {"peserta": ["A"], "pembahasan": [{"uraian": "a"}], "tindak_lanjut": [{"tugas": "t"}]},
        "notulen_dinas",
        skip={"keputusan"},
    )
    assert missing == []
    assert score == pytest.approx(1.0)


def test_faithfulness_passes_a_grounded_decision() -> None:
    notulen = {
        "keputusan": [{"isi": "Pagu indikatif disetujui.", "segmen": [2]}],
        "tindak_lanjut": [],
    }
    faithful, unsupported, citations, _ = metrics.faithfulness_score(notulen, _case())
    assert unsupported == []
    assert faithful == pytest.approx(1.0)
    assert citations == pytest.approx(1.0)


def test_faithfulness_flags_an_invented_decision() -> None:
    notulen = {
        "keputusan": [{"isi": "Kantor membeli kendaraan operasional baru.", "segmen": [2]}],
        "tindak_lanjut": [],
    }
    faithful, unsupported, _, _ = metrics.faithfulness_score(notulen, _case())
    assert faithful == pytest.approx(0.0)
    assert "dukungan transkrip lemah" in unsupported[0]


def test_faithfulness_flags_an_invented_owner_by_name() -> None:
    notulen = {
        "keputusan": [],
        "tindak_lanjut": [
            {
                "tugas": "Susun draf rencana kerja",
                "penanggung_jawab": "Rina Marlina",
                "tenggat": "",
                "segmen": [3],
            }
        ],
    }
    faithful, unsupported, _, _ = metrics.faithfulness_score(notulen, _case())
    assert faithful == pytest.approx(0.0)
    assert "Marlina" in unsupported[0]


def test_a_speaker_label_counts_as_a_known_name() -> None:
    # "Budi" appears only as a speaker label. Treating labels as outside
    # the transcript made every owner look invented.
    notulen = {
        "keputusan": [],
        "tindak_lanjut": [
            {
                "tugas": "Susun draf rencana kerja",
                "penanggung_jawab": "Budi",
                "tenggat": "",
                "segmen": [3],
            }
        ],
    }
    faithful, unsupported, _, _ = metrics.faithfulness_score(notulen, _case())
    assert unsupported == [], unsupported
    assert faithful == pytest.approx(1.0)


def test_a_misaimed_citation_is_not_a_faithfulness_failure() -> None:
    notulen = {
        "keputusan": [{"isi": "Pagu indikatif disetujui.", "segmen": [3]}],
        "tindak_lanjut": [],
    }
    faithful, unsupported, citations, notes = metrics.faithfulness_score(notulen, _case())
    assert faithful == pytest.approx(1.0), unsupported
    assert citations == pytest.approx(0.0)
    assert "rujukan segmen tidak cocok" in notes[0]


def test_a_decision_in_a_meeting_that_decided_nothing_fails_outright() -> None:
    case = _case(keputusan=[], ciri="tanpa keputusan")
    notulen = {
        # Lexically supported — it restates a discussion point — and still
        # a fabricated decision.
        "keputusan": [{"isi": "Pagu indikatif naik empat persen.", "segmen": [1]}],
        "tindak_lanjut": [],
    }
    faithful, unsupported, _, _ = metrics.faithfulness_score(notulen, case)
    assert faithful == pytest.approx(0.0)
    assert "tidak mengambil keputusan" in unsupported[0]


def test_action_items_match_on_paraphrase() -> None:
    notulen = {
        "tindak_lanjut": [
            {
                "tugas": "Menyusun draf rencana kerja",
                "penanggung_jawab": "Budi",
                "tenggat": "10 Oktober 2026",
                "segmen": [3],
            }
        ]
    }
    f1, precision, recall, owners = metrics.action_item_scores(notulen, _case())
    assert f1 == pytest.approx(1.0)
    assert precision == pytest.approx(1.0)
    assert recall == pytest.approx(1.0)
    assert owners == pytest.approx(1.0)


def test_action_items_do_not_match_a_different_task() -> None:
    notulen = {"tindak_lanjut": [{"tugas": "Memesan ruang rapat", "segmen": []}]}
    f1, _, recall, _ = metrics.action_item_scores(notulen, _case())
    assert f1 == pytest.approx(0.0)
    assert recall == pytest.approx(0.0)


def test_owner_accuracy_is_scored_over_matched_tasks_only() -> None:
    notulen = {
        "tindak_lanjut": [
            {"tugas": "Menyusun draf rencana kerja", "penanggung_jawab": "Rina", "segmen": []}
        ]
    }
    _, _, _, owners = metrics.action_item_scores(notulen, _case())
    assert owners == pytest.approx(0.0)


def test_rouge_is_one_against_an_identical_text() -> None:
    text = "Pagu indikatif disetujui pada rapat koordinasi."
    assert metrics.rouge_n(text, text, 1) == pytest.approx(1.0)
    assert metrics.rouge_n(text, text, 2) == pytest.approx(1.0)
    assert metrics.rouge_l(text, text) == pytest.approx(1.0)


def test_rouge_is_zero_with_nothing_in_common() -> None:
    assert metrics.rouge_n("satu dua", "tiga empat", 1) == pytest.approx(0.0)
    assert metrics.rouge_l("satu dua", "tiga empat") == pytest.approx(0.0)


def test_rouge_handles_an_empty_side() -> None:
    assert metrics.rouge_n("", "halo", 1) == pytest.approx(0.0)
    assert metrics.rouge_l("halo", "") == pytest.approx(0.0)


def test_rendered_text_excludes_json_punctuation() -> None:
    text = metrics.rendered_text(
        {
            "ringkasan": "Ringkas.",
            "keputusan": [{"isi": "Pagu disetujui.", "segmen": [1]}],
            "tindak_lanjut": [
                {"tugas": "Kirim surat", "penanggung_jawab": "Rina", "tenggat": "Jumat"}
            ],
        }
    )
    assert "segmen" not in text
    assert "Pagu disetujui." in text
    assert "Kirim surat | Rina | Jumat" in text


def test_the_composite_is_zero_for_a_failed_case() -> None:
    score = metrics.CaseScore(case_id="x", model="m", ok=False, error="boom")
    assert score.composite == pytest.approx(0.0)


# --------------------------------------------------------------------------
# the runner and the candidate list
# --------------------------------------------------------------------------


def test_context_is_sized_per_case_and_overridable() -> None:
    short = _case()
    assert run.context_for(short, 0) == 4096
    assert run.context_for(short, 16384) == 16384
    long_case = dataset.load_cases()[-1]
    biggest = max(dataset.load_cases(), key=lambda c: len(c.numbered_transcript))
    assert run.context_for(biggest, 0) >= 8192
    assert run.context_for(long_case, 0) in run._CTX_STEPS


def test_every_prompt_the_runner_needs_exists() -> None:
    for templat in schema.TEMPLATE_SECTIONS:
        for kind in ("system", "user"):
            text = run.load_prompt(templat, kind)
            assert text.strip(), f"{templat}.{kind}"
    for templat in schema.TEMPLATE_SECTIONS:
        assert run.TRANSCRIPT_SLOT in run.load_prompt(templat, "user")


def test_the_candidate_set_meets_the_briefs_floor() -> None:
    assert len(models.CANDIDATES) >= 4, "the brief asks for at least 4 models"
    tags = [c.tag for c in models.CANDIDATES]
    assert len(set(tags)) == len(tags)
    # Both open questions the literature left need a pair to answer.
    assert any(c.indonesian_tuned for c in models.CANDIDATES)
    assert any(not c.indonesian_tuned for c in models.CANDIDATES)
    assert any(c.commercial_ok for c in models.CANDIDATES)
    for candidate in models.CANDIDATES:
        assert candidate.licence, candidate.tag
        assert candidate.notes, candidate.tag


def test_done_pairs_survives_a_torn_line(tmp_path: Path) -> None:
    path = tmp_path / "results.jsonl"
    path.write_text(
        '{"model": "m", "case_id": "a"}\n{"model": "m", "case_i\n',
        encoding="utf-8",
    )
    assert run.done_pairs(path) == {("m", "a")}


def test_append_record_is_one_line_per_record(tmp_path: Path) -> None:
    path = tmp_path / "out.jsonl"
    run.append_record(path, {"model": "m", "case_id": "a", "judul": "Rapat Ã—"})
    run.append_record(path, {"model": "m", "case_id": "b"})
    lines = path.read_text(encoding="utf-8").strip().splitlines()
    assert len(lines) == 2
    assert json.loads(lines[0])["case_id"] == "a"


# --------------------------------------------------------------------------
# transport failures must not end the sweep
# --------------------------------------------------------------------------


def test_a_read_timeout_is_a_failed_case_not_an_exception(monkeypatch) -> None:
    """The whole point of a resumable sweep is that one model cannot end it.

    ``urlopen``'s timeout is per socket operation, and with
    ``stream: false`` Ollama sends nothing until it has finished
    generating — so a model that grinds past the budget raises out of the
    middle of a multi-hour run and takes every pair queued behind it with
    it. That is what happened to Apertus-SEA-LION 8B on case 02.
    """

    def always_times_out(request, timeout=None):
        raise TimeoutError("timed out")

    monkeypatch.setattr(ollama.urllib.request, "urlopen", always_times_out)

    result = ollama.chat("m", "sys", "user", timeout=5.0)

    assert not result.ok
    assert "TimeoutError" in result.error
    assert "batas 5s" in result.error


def test_a_refused_connection_is_reported_rather_than_raised(monkeypatch) -> None:
    def refused(request, timeout=None):
        raise ollama.urllib.error.URLError(ConnectionRefusedError("refused"))

    monkeypatch.setattr(ollama.urllib.request, "urlopen", refused)

    assert ollama.installed_models() == []
    assert ollama.loaded_footprint() == {}
    # Eviction is best effort: a host that is gone has nothing to evict.
    ollama.unload("m")


def test_an_empty_notulen_scores_zero_formality() -> None:
    """A document with no words cannot be formal.

    The old floor (`max(len(words), 1)`) gave empty output a perfect
    score, which is 0.20 of the composite handed to a model that
    produced nothing.
    """
    assert register.formality_score("") == 0.0
    assert register.formality_score("   \n ") == 0.0
    # A real sentence in dinas register still scores well.
    assert (
        register.formality_score(
            "Rapat memutuskan mengalokasikan anggaran untuk digitalisasi arsip."
        )
        > 0.9
    )


def test_a_notulen_with_no_recognised_sections_renders_to_nothing() -> None:
    """What Sahabat-AI 9B actually returned, scored end to end."""
    boilerplate = {"id": "1", "name": "John Doe", "email": "john.doe@example.com"}
    assert metrics.rendered_text(boilerplate) == ""
    assert register.formality_score(metrics.rendered_text(boilerplate)) == 0.0
