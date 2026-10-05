"""The risalah-to-recording join.

Fixtures use titles observed on the real channels (`@mahkamahkonstitusi`,
`@DPRRIOfficial`) on 2026-10-05, so the parsers are tested against the
shapes they actually meet rather than the shapes they would prefer.
"""

from __future__ import annotations

from datetime import date

import pytest

from collect.gov_index import (
    GovItem,
    agenda_similarity,
    match_sessions,
    parse_date,
    parse_komisi,
    parse_perkara,
)

# -- perkara numbers ----------------------------------------------------


@pytest.mark.parametrize(
    ("text", "expected"),
    [
        ("Perkara Nomor 90/PUU-XXI/2023", "90/PUU-XXI/2023"),
        # Whitespace around separators varies between risalah header and
        # video title; the key must survive it.
        ("90 / PUU - XXI / 2023", "90/PUU-XXI/2023"),
        # Leading zeros are not part of the identity.
        ("006/SKLN-IV/2006", "6/SKLN-IV/2006"),
        # Registers carrying a dot.
        ("1/PHPU.PRES-XXII/2024", "1/PHPU.PRES-XXII/2024"),
        ("Sidang PUU tanpa nomor", None),
        ("", None),
    ],
)
def test_parse_perkara(text: str, expected: str | None) -> None:
    assert parse_perkara(text) == expected


def test_perkara_numbers_normalise_to_the_same_key() -> None:
    assert parse_perkara("nomor 90/puu-xxi/2023") == parse_perkara("90 / PUU-XXI / 2023")


# -- dates --------------------------------------------------------------


@pytest.mark.parametrize(
    ("text", "expected"),
    [
        # Real MK video titles, Indonesian and English.
        ("(Berita Video) 2 Oktober 2026 : Sidang PHPU Presiden", date(2026, 10, 2)),
        ("(Video News) October 1, 2026: Presidential Election Dispute", date(2026, 10, 1)),
        ("(Video News) September 30, 2026: 2024 Presidential Election", date(2026, 9, 30)),
        ("Risalah Sidang 17 Agustus 2024", date(2024, 8, 17)),
        # Spelling variants that appear in older documents.
        ("1 Nopember 2019", date(2019, 11, 1)),
        ("3 Pebruari 2020", date(2020, 2, 3)),
        ("2026-10-02", date(2026, 10, 2)),
        # Indonesian convention is day-first.
        ("02/10/2026", date(2026, 10, 2)),
        ("Sidang tanpa tanggal", None),
        # An impossible date is None, not a wrapped one.
        ("31 Februari 2024", None),
    ],
)
def test_parse_date(text: str, expected: date | None) -> None:
    assert parse_date(text) == expected


def test_iso_date_wins_over_a_stray_number_run() -> None:
    assert parse_date("rapat 2026-10-02 ruang 12") == date(2026, 10, 2)


def test_a_year_in_the_title_alone_is_not_a_date() -> None:
    # "2024 Presidential Election" must not become a date on its own.
    assert parse_date("2024 Presidential Election Dispute Hearing") is None


# -- komisi -------------------------------------------------------------


@pytest.mark.parametrize(
    ("text", "expected"),
    [
        ("Rapat Komisi I DPR RI", "komisi-1"),
        ("komisi xi", "komisi-11"),
        ("Komisi VIII", "komisi-8"),
        ("Rapat Badan Legislasi", "baleg"),
        ("BALEG DPR", "baleg"),
        ("Badan Anggaran", "banggar"),
        ("Rapat Paripurna", "paripurna"),
        ("Rapat Pansus RUU", "pansus"),
        ("DPR dorong KKP permudah akses", None),
    ],
)
def test_parse_komisi(text: str, expected: str | None) -> None:
    assert parse_komisi(text) == expected


def test_komisi_aliases_collapse() -> None:
    assert parse_komisi("Badan Legislasi") == parse_komisi("Baleg")


# -- agenda similarity --------------------------------------------------


def test_agenda_similarity_is_high_for_the_same_rapat() -> None:
    left = "Rapat Dengar Pendapat Komisi VIII dengan Menteri Agama tentang haji"
    right = "RDP Komisi VIII dengan Menteri Agama soal penyelenggaraan haji"
    assert agenda_similarity(left, right) > 0.35


def test_agenda_similarity_is_low_for_different_rapat() -> None:
    left = "Rapat Komisi VIII dengan Menteri Agama tentang haji"
    right = "Rapat Komisi I dengan Panglima TNI tentang alutsista"
    assert agenda_similarity(left, right) < 0.35


def test_agenda_similarity_handles_empty_input() -> None:
    assert agenda_similarity("", "apa pun") == 0.0


# -- the join -----------------------------------------------------------


def _risalah(**kwargs: object) -> GovItem:
    base = {"source": "mk", "title": "", "transcript_url": "https://example/r.pdf"}
    return GovItem(**{**base, **kwargs})  # type: ignore[arg-type]


def _recording(**kwargs: object) -> GovItem:
    base = {"source": "mk", "title": "", "media_id": "vid1"}
    return GovItem(**{**base, **kwargs})  # type: ignore[arg-type]


def test_perkara_number_is_a_strong_key() -> None:
    report = match_sessions(
        [_risalah(perkara="90/PUU-XXI/2023", session_date=date(2023, 8, 1), title="Sidang")],
        [_recording(perkara="90/PUU-XXI/2023", session_date=date(2023, 8, 9), title="Lain")],
    )
    assert len(report.matches) == 1
    assert report.matches[0].basis == "perkara"
    assert report.matches[0].confidence == 1.0


def test_perkara_match_survives_a_late_upload() -> None:
    """MK publishes a hearing's video days after the session.

    A date window must not veto a perkara-number match.
    """
    report = match_sessions(
        [_risalah(perkara="1/PUU-XXII/2024", session_date=date(2024, 1, 10), title="x")],
        [_recording(perkara="1/PUU-XXII/2024", session_date=date(2024, 2, 20), title="y")],
    )
    assert len(report.matches) == 1


def test_different_perkara_numbers_never_match() -> None:
    report = match_sessions(
        [_risalah(perkara="90/PUU-XXI/2023", session_date=date(2023, 8, 1), title="Sidang haji")],
        [_recording(perkara="91/PUU-XXI/2023", session_date=date(2023, 8, 1), title="Sidang haji")],
    )
    assert report.matches == []
    assert len(report.unmatched_risalah) == 1
    assert any("nomor perkara berbeda" in reason for _, _, reason in report.rejected)


def test_dpr_joins_on_komisi_date_and_agenda() -> None:
    report = match_sessions(
        [
            _risalah(
                source="dpr",
                komisi="komisi-8",
                session_date=date(2026, 3, 4),
                title="Rapat Dengar Pendapat Komisi VIII dengan Menteri Agama tentang haji",
            )
        ],
        [
            _recording(
                source="dpr",
                komisi="komisi-8",
                session_date=date(2026, 3, 4),
                title="RDP Komisi VIII dengan Menteri Agama soal penyelenggaraan haji",
            )
        ],
    )
    assert len(report.matches) == 1
    assert report.matches[0].basis == "komisi+tanggal+agenda"


def test_same_komisi_same_day_different_agenda_is_refused() -> None:
    """One komisi can hold two rapat in a day.

    Date plus komisi is not enough, and guessing here would mislabel a
    whole hearing — which the alignment step would silently discard
    rather than flag.
    """
    report = match_sessions(
        [
            _risalah(
                source="dpr",
                komisi="komisi-1",
                session_date=date(2026, 3, 4),
                title="Rapat kerja dengan Panglima TNI mengenai pengadaan alutsista",
            )
        ],
        [
            _recording(
                source="dpr",
                komisi="komisi-1",
                session_date=date(2026, 3, 4),
                title="RDPU dengan akademisi mengenai revisi undang-undang penyiaran",
            )
        ],
    )
    assert report.matches == []
    assert any("agenda terlalu berbeda" in reason for _, _, reason in report.rejected)


def test_different_komisi_on_the_same_day_is_refused() -> None:
    report = match_sessions(
        [_risalah(source="dpr", komisi="komisi-1", session_date=date(2026, 3, 4), title="rapat")],
        [_recording(source="dpr", komisi="komisi-8", session_date=date(2026, 3, 4), title="rapat")],
    )
    assert report.matches == []
    assert any("komisi berbeda" in reason for _, _, reason in report.rejected)


def test_one_day_of_slack_is_allowed_for_a_session_past_midnight() -> None:
    report = match_sessions(
        [
            _risalah(
                source="dpr",
                komisi="paripurna",
                session_date=date(2026, 3, 4),
                title="Rapat Paripurna pengesahan RUU APBN",
            )
        ],
        [
            _recording(
                source="dpr",
                komisi="paripurna",
                session_date=date(2026, 3, 5),
                title="Rapat Paripurna pengesahan RUU APBN",
            )
        ],
    )
    assert len(report.matches) == 1


def test_two_days_apart_is_not_allowed() -> None:
    report = match_sessions(
        [_risalah(source="dpr", komisi="paripurna", session_date=date(2026, 3, 4), title="RUU")],
        [_recording(source="dpr", komisi="paripurna", session_date=date(2026, 3, 7), title="RUU")],
    )
    assert report.matches == []


def test_an_item_without_a_date_is_unmatched_not_guessed() -> None:
    report = match_sessions(
        [_risalah(source="dpr", komisi="komisi-1", title="rapat")],
        [_recording(source="dpr", komisi="komisi-1", session_date=date(2026, 3, 4), title="rapat")],
    )
    assert report.matches == []
    assert len(report.unmatched_risalah) == 1


def test_a_recording_is_claimed_by_at_most_one_risalah() -> None:
    """Two risalah must not both be labelled with the same audio."""
    report = match_sessions(
        [
            _risalah(perkara="90/PUU-XXI/2023", session_date=date(2023, 8, 1), title="a"),
            _risalah(perkara="90/PUU-XXI/2023", session_date=date(2023, 8, 1), title="b"),
        ],
        [_recording(perkara="90/PUU-XXI/2023", session_date=date(2023, 8, 1), title="c")],
    )
    assert len(report.matches) == 1
    assert len(report.unmatched_risalah) == 1


def test_sources_are_never_crossed() -> None:
    report = match_sessions(
        [_risalah(source="mk", session_date=date(2026, 3, 4), title="rapat")],
        [_recording(source="dpr", session_date=date(2026, 3, 4), title="rapat")],
    )
    assert report.matches == []


def test_report_summary_counts_every_bucket() -> None:
    report = match_sessions(
        [_risalah(perkara="90/PUU-XXI/2023", session_date=date(2023, 8, 1), title="a")],
        [
            _recording(perkara="90/PUU-XXI/2023", session_date=date(2023, 8, 1), title="a"),
            _recording(perkara="91/PUU-XXI/2023", session_date=date(2023, 8, 1), title="b"),
        ],
    )
    summary = report.summary()
    assert "1 cocok" in summary
    assert "1 rekaman tanpa risalah" in summary


def test_unmatched_items_are_reported_rather_than_dropped() -> None:
    """The pilot's headline number depends on this.

    "10 hearings obtained" is only meaningful next to how many were
    discovered and refused.
    """
    report = match_sessions(
        [_risalah(session_date=date(2026, 1, 1), title="a")],
        [_recording(session_date=date(2026, 6, 1), title="b")],
    )
    assert len(report.unmatched_risalah) == 1
    assert len(report.unmatched_recordings) == 1


def test_item_key_is_stable_and_filesystem_safe() -> None:
    item = _risalah(perkara="90/PUU-XXI/2023", session_date=date(2023, 8, 1), title="Sidang")
    assert item.key == "mk:2023-08-01:90-puu-xxi-2023"
    assert "/" not in item.key.split(":", 1)[1]
