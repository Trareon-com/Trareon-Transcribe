"""Risalah parsing.

The fixtures reproduce the layout of real published documents: an MK
risalah with numbered turns and a cover page, and a DPR risalah with
faction-labelled turns. They are written by hand rather than copied so
that the test suite carries no third-party document text.
"""

from __future__ import annotations

from collect.risalah import (
    find_front_matter_end,
    parse_risalah,
    strip_repeated_headers,
)

MK_RISALAH = """\
MAHKAMAH KONSTITUSI
REPUBLIK INDONESIA
---------------------
RISALAH SIDANG
PERKARA NOMOR 90/PUU-XXI/2023

PERIHAL
PENGUJIAN UNDANG-UNDANG NOMOR 7 TAHUN 2017
TENTANG PEMILIHAN UMUM

ACARA
PEMERIKSAAN PENDAHULUAN

J A K A R T A
SENIN, 7 AGUSTUS 2023

SUSUNAN PERSIDANGAN
1) Anwar Usman (Ketua)
2) Saldi Isra (Anggota)

Pihak yang Hadir:
Kuasa Hukum Pemohon: Budi Santoso

SIDANG DIBUKA PUKUL 10.00 WIB

1. KETUA: ANWAR USMAN

Sidang dalam perkara Nomor 90/PUU-XXI/2023 dengan ini dibuka.
Saya persilakan Pemohon memperkenalkan diri.

(KETUK PALU 3X)

2. KUASA HUKUM PEMOHON: BUDI SANTOSO

Terima kasih Yang Mulia. Saya Budi Santoso, kuasa hukum Pemohon
dalam perkara ini.

3. KETUA: ANWAR USMAN

Baik, silakan sampaikan pokok permohonan Saudara.

SIDANG DITUTUP PUKUL 11.30 WIB
"""

DPR_RISALAH = """\
RISALAH RAPAT DENGAR PENDAPAT
KOMISI VIII DPR RI DENGAN MENTERI AGAMA
Rabu, 4 Maret 2026

RAPAT DIBUKA PUKUL 09.30 WIB

KETUA RAPAT: H. ASHABUL KAHFI

Assalamualaikum warahmatullahi wabarakatuh. Rapat Dengar Pendapat
Komisi VIII dengan Menteri Agama kami buka.

F-PKB (H. MARWAN DASOPANG):

Interupsi Pimpinan. Saya ingin menanyakan soal kuota haji tahun ini
yang belum jelas pembagiannya.

MENTERI AGAMA:

Terima kasih atas pertanyaannya. Kuota haji tahun ini berjumlah
dua ratus dua puluh satu ribu jemaah.

KETUA RAPAT: H. ASHABUL KAHFI

Baik, terima kasih Pak Menteri.

RAPAT DITUTUP PUKUL 12.00 WIB
"""


# -- front matter -------------------------------------------------------


def test_front_matter_ends_at_the_opening_formula() -> None:
    index = find_front_matter_end(MK_RISALAH)
    assert index > 0
    assert "MAHKAMAH KONSTITUSI" in MK_RISALAH[:index]
    assert "SIDANG DIBUKA PUKUL" in MK_RISALAH[index:]


def test_cover_page_is_not_part_of_the_aligner_text() -> None:
    """The cover page was never spoken aloud.

    Leaving it in would have the aligner match a hypothesis against
    "PERIHAL PENGUJIAN UNDANG-UNDANG" and label audio with it.
    """
    risalah = parse_risalah(MK_RISALAH)
    assert "PERIHAL" not in risalah.text
    assert "SUSUNAN PERSIDANGAN" not in risalah.text
    assert "Pihak yang Hadir" not in risalah.text
    assert "PERIHAL" in risalah.front_matter


def test_unknown_layout_keeps_all_text_rather_than_guessing() -> None:
    # Losing a little data beats mislabelling it.
    assert find_front_matter_end("teks tanpa penanda apa pun") == 0


# -- MK: numbered turns -------------------------------------------------


def test_mk_numbered_turns_are_parsed() -> None:
    risalah = parse_risalah(MK_RISALAH, source="mk")
    assert [turn.index for turn in risalah.turns] == [1, 2, 3]
    assert [turn.role for turn in risalah.turns] == [
        "ketua",
        "kuasa hukum pemohon",
        "ketua",
    ]


def test_mk_speaker_name_after_the_colon_is_captured() -> None:
    risalah = parse_risalah(MK_RISALAH, source="mk")
    assert risalah.turns[0].speaker == "ANWAR USMAN"
    assert risalah.turns[1].speaker == "BUDI SANTOSO"
    assert risalah.speakers == ["ANWAR USMAN", "BUDI SANTOSO"]


def test_mk_speech_follows_its_label_not_the_previous_turn() -> None:
    risalah = parse_risalah(MK_RISALAH, source="mk")
    assert risalah.turns[0].text.startswith("Sidang dalam perkara")
    assert "Terima kasih Yang Mulia" in risalah.turns[1].text
    assert "Terima kasih Yang Mulia" not in risalah.turns[0].text


def test_speaker_name_is_not_swallowed_from_the_speech() -> None:
    """The failure this guards against deletes a sentence.

    If the name detector accepted ordinary speech, the first sentence of
    every turn would move into the `speaker` field and vanish from the
    label.
    """
    text = "SIDANG DIBUKA PUKUL 10.00 WIB\n\n1. KETUA: Saudara Pemohon, silakan berdiri.\n"
    risalah = parse_risalah(text)
    assert risalah.turns[0].speaker is None
    assert "silakan berdiri" in risalah.turns[0].text


def test_initials_in_a_name_are_still_a_name() -> None:
    text = "RAPAT DIBUKA PUKUL 09.00 WIB\n\nKETUA RAPAT: H. ASHABUL KAHFI\n\nSelamat pagi.\n"
    risalah = parse_risalah(text)
    assert risalah.turns[0].speaker == "H. ASHABUL KAHFI"
    assert risalah.turns[0].text == "Selamat pagi."


# -- DPR: labelled turns ------------------------------------------------


def test_dpr_labelled_turns_are_parsed() -> None:
    risalah = parse_risalah(DPR_RISALAH, source="dpr")
    assert [turn.role for turn in risalah.turns] == [
        "ketua rapat",
        "f-pkb",
        "menteri agama",
        "ketua rapat",
    ]
    assert all(turn.index is None for turn in risalah.turns)


def test_dpr_faction_label_yields_role_and_name() -> None:
    risalah = parse_risalah(DPR_RISALAH, source="dpr")
    faction_turn = risalah.turns[1]
    assert faction_turn.role == "f-pkb"
    assert faction_turn.speaker == "H. MARWAN DASOPANG"
    assert "kuota haji" in faction_turn.text


def test_dpr_speech_is_attributed_to_the_right_turn() -> None:
    risalah = parse_risalah(DPR_RISALAH, source="dpr")
    assert "Assalamualaikum" in risalah.turns[0].text
    assert "dua ratus dua puluh satu ribu" in risalah.turns[2].text


# -- document furniture -------------------------------------------------


def test_gavel_and_sitting_formulae_are_dropped_from_the_label() -> None:
    """An ASR never produces them.

    Leaving "KETUK PALU 3X" in the label would charge every model for
    four words that were not spoken.
    """
    risalah = parse_risalah(MK_RISALAH, source="mk")
    assert "KETUK PALU" not in risalah.text
    assert "SIDANG DITUTUP" not in risalah.text
    assert "RAPAT DIBUKA" not in parse_risalah(DPR_RISALAH).text


def test_stage_directions_in_brackets_are_dropped() -> None:
    text = (
        "RAPAT DIBUKA PUKUL 09.00 WIB\n\n"
        "KETUA RAPAT: A B\n\nBaik (tertawa) kita lanjutkan (tidak jelas) ya.\n"
    )
    risalah = parse_risalah(text)
    assert "tertawa" not in risalah.text
    assert "tidak jelas" not in risalah.text
    assert "kita lanjutkan" in risalah.text


def test_an_all_caps_sentence_with_a_colon_does_not_start_a_turn() -> None:
    """Risalah set emphasis in capitals.

    A colon inside such a sentence would otherwise split a turn and
    invent a speaker.
    """
    text = (
        "RAPAT DIBUKA PUKUL 09.00 WIB\n\n"
        "KETUA RAPAT: A B\n\n"
        "PERHATIAN KEPADA SELURUH ANGGOTA YANG HADIR PADA HARI INI: mohon tenang.\n"
    )
    risalah = parse_risalah(text)
    assert len(risalah.turns) == 1
    assert "mohon tenang" in risalah.turns[0].text


def test_repeated_page_headers_are_stripped() -> None:
    pages = [
        "PERKARA NOMOR 90/PUU-XXI/2023\nSidang dibuka.\n1",
        "PERKARA NOMOR 90/PUU-XXI/2023\nSilakan Pemohon.\n2",
        "PERKARA NOMOR 90/PUU-XXI/2023\nTerima kasih.\n3",
        "PERKARA NOMOR 90/PUU-XXI/2023\nSidang ditutup.\n4",
    ]
    cleaned = strip_repeated_headers(pages)
    assert all("PERKARA NOMOR" not in page for page in cleaned)
    assert "Sidang dibuka." in cleaned[0]


def test_a_short_document_loses_nothing_to_header_stripping() -> None:
    # On two pages, "appears on more than half" would delete real text.
    pages = ["Sidang dibuka.", "Sidang ditutup."]
    assert strip_repeated_headers(pages) == pages


def test_page_numbers_inside_a_turn_are_dropped() -> None:
    text = (
        "RAPAT DIBUKA PUKUL 09.00 WIB\n\nKETUA RAPAT: A B\n\nKalimat pertama.\n7\nKalimat kedua.\n"
    )
    risalah = parse_risalah(text)
    assert risalah.turns[0].text == "Kalimat pertama. Kalimat kedua."


# -- aggregate accessors ------------------------------------------------


def test_text_is_speech_only_and_word_count_matches() -> None:
    risalah = parse_risalah(DPR_RISALAH, source="dpr")
    assert risalah.words == sum(turn.words for turn in risalah.turns)
    assert risalah.words > 40
    assert "RISALAH RAPAT" not in risalah.text


def test_empty_input_yields_no_turns() -> None:
    risalah = parse_risalah("")
    assert risalah.turns == []
    assert risalah.text == ""
    assert risalah.speakers == []
