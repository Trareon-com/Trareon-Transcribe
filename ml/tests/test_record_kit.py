"""Transcript parsing and the consent redaction.

The redaction tests are the important ones: dropping a `[potong]` turn is
a promise made to a participant in `CONSENT.md`, not a quality filter,
and a promise enforced only by a code comment is not enforced.
"""

from __future__ import annotations

from align.cut import cut_risalah
from collect.risalah import Risalah
from record_kit.ingest import REDACT_MARKER, clean_label, parse_transcript
from tests.test_textalign import hyp_from_text

TRANSCRIPT = """\
PENUTUR A: jadi kita perlu align dulu sebelum deploy ya
PENUTUR B: iya tapi staging-nya masih down dari kemarin
PENUTUR A: oke nanti saya follow up ke tim infra
PENUTUR C: eh sebentar [tak jelas] budget-nya belum di-approve
"""


def test_speaker_turns_are_parsed() -> None:
    risalah, redacted = parse_transcript(TRANSCRIPT)
    assert [turn.speaker for turn in risalah.turns] == [
        "PENUTUR A",
        "PENUTUR B",
        "PENUTUR A",
        "PENUTUR C",
    ]
    assert redacted == []


def test_turn_text_is_captured() -> None:
    risalah, _ = parse_transcript(TRANSCRIPT)
    assert "align dulu sebelum deploy" in risalah.turns[0].text
    assert "staging-nya masih down" in risalah.turns[1].text


def test_a_continuation_line_joins_the_open_turn() -> None:
    text = "PENUTUR A: kalimat pertama\nlanjutan tanpa label\nPENUTUR B: balasan\n"
    risalah, _ = parse_transcript(text)
    assert len(risalah.turns) == 2
    assert risalah.turns[0].text == "kalimat pertama lanjutan tanpa label"


def test_text_before_any_speaker_label_is_ignored() -> None:
    text = "catatan fasilitator sebelum sesi\nPENUTUR A: mulai sekarang\n"
    risalah, _ = parse_transcript(text)
    assert len(risalah.turns) == 1
    assert risalah.turns[0].text == "mulai sekarang"


def test_empty_transcript_yields_no_turns() -> None:
    risalah, redacted = parse_transcript("")
    assert risalah.turns == []
    assert redacted == []


# -- the consent obligation --------------------------------------------


def test_a_redaction_request_is_detected() -> None:
    text = (
        "PENUTUR A: ini boleh direkam\n"
        f"PENUTUR B: bagian yang ditarik peserta {REDACT_MARKER}\n"
        "PENUTUR A: lanjut saja\n"
    )
    _, redacted = parse_transcript(text)
    assert redacted == [1]


def test_a_redaction_marker_on_a_continuation_line_is_detected() -> None:
    text = f"PENUTUR A: kalimat pertama\nbagian ditarik {REDACT_MARKER}\nPENUTUR B: lanjut\n"
    _, redacted = parse_transcript(text)
    assert redacted == [0]


def test_the_marker_is_case_insensitive() -> None:
    _, redacted = parse_transcript("PENUTUR A: hapus ini [POTONG]\n")
    assert redacted == [0]


def test_a_redacted_turn_never_reaches_the_cutter() -> None:
    """End to end: the audio of a redacted turn must not be cuttable.

    Mirrors what `ingest` does — drop first, align second — so that no
    clip of a withdrawn turn is written even temporarily.
    """
    clean = "kuota haji tahun ini berjumlah dua ratus ribu jemaah nasional"
    withdrawn = "mohon bagian ini dihapus dari rekaman sesi hari ini"
    text = f"PENUTUR A: {clean}\nPENUTUR B: {withdrawn} {REDACT_MARKER}\n"

    parsed, redacted = parse_transcript(text)
    assert redacted == [1]

    # What ingest keeps.
    kept = [turn for index, turn in enumerate(parsed.turns) if index not in set(redacted)]
    usable = Risalah(turns=kept, source="uji")

    result = cut_risalah(usable, hyp_from_text(f"{clean} {withdrawn}", wps=2.0))
    all_text = " ".join(utterance.text for utterance in result.utterances)
    assert "dihapus dari rekaman" not in all_text
    assert "kuota haji" in all_text


# -- label cleaning ----------------------------------------------------


def test_non_speech_markers_are_stripped_from_the_label() -> None:
    # An ASR never emits brackets; training on them would teach it to.
    assert clean_label("eh sebentar [tak jelas] budget-nya") == "eh sebentar budget-nya"
    assert clean_label("ya [tawa] betul") == "ya betul"
    assert clean_label("[tumpang tindih] silakan") == "silakan"


def test_an_uncertainty_guess_marker_is_stripped_whole() -> None:
    assert clean_label("anggaran [tak jelas: budget?] naik") == "anggaran naik"


def test_a_name_placeholder_is_stripped() -> None:
    assert clean_label("tolong [nama] cek lagi") == "tolong cek lagi"


def test_the_redaction_marker_itself_is_stripped_from_a_label() -> None:
    assert REDACT_MARKER not in clean_label(f"sisa teks {REDACT_MARKER}")


def test_fillers_are_kept_in_the_label() -> None:
    """The normaliser drops them at scoring time, not here.

    Keeping them makes the label an honest record of what was said; the
    WER harness removes them on both sides so the figure is unaffected.
    """
    assert "eh" in clean_label("eh jadi begitu")


def test_cleaning_collapses_the_whitespace_it_leaves_behind() -> None:
    assert clean_label("satu  [tawa]   dua") == "satu dua"
