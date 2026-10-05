"""Opt-in checks against the real sources.

    uv run pytest -m network

Excluded by default (see `addopts` in `pyproject.toml`) because CI must
stay hermetic and a test that silently stops testing because `mkri.id`
changed is worse than no test.

These exist for one purpose: to tell the maintainer **when the access
situation changes**. Both government sources refused automated access on
2026-10-05, and the pilot is blocked on that. If MK drops its Cloudflare
interstitial, or DPR starts serving its risalah index server-side, or an
official data route is opened, these tests are how that gets noticed —
rather than someone re-deriving it by hand in six months.

They therefore **assert on the shape of the answer, not on the block**.
A test that failed the day MK became reachable would be exactly backwards.
"""

from __future__ import annotations

import pytest

from collect.access import Access
from collect.gov_sources import DPR, MK, discover, probe
from collect.hf_sets import FLEURS_ID, describe_access, hf_token
from common.fetch import PoliteSession

pytestmark = pytest.mark.network


@pytest.fixture(scope="module")
def session() -> PoliteSession:
    # Slow on purpose: a research crawl has no reason to hurry, and
    # these run against someone else's government website.
    return PoliteSession(delay=2.0)


@pytest.mark.parametrize("source", [MK, DPR], ids=["mk", "dpr"])
def test_probe_returns_an_actionable_verdict(source, session: PoliteSession) -> None:
    """Whatever the answer, it must be one we can act on.

    Prints the verdict so `pytest -m network -s` doubles as the
    access-status report the sprint report quotes.
    """
    result = probe(source, session)
    print(f"\n[{result.source}] {result.access.value}: {result.detail}")

    assert result.access in set(Access)
    assert result.detail, "sebuah probe tanpa penjelasan tidak bisa ditindaklanjuti"
    if not result.usable:
        assert result.remedy, "probe yang gagal harus menyebut langkah berikutnya"


@pytest.mark.parametrize("source", [MK, DPR], ids=["mk", "dpr"])
def test_discover_returns_items_or_the_reason_there_are_none(
    source, session: PoliteSession
) -> None:
    found, verdict = discover(source, limit=3, session=session)
    print(f"\n[{source.name}] {len(found)} item, akses={verdict.access.value}")

    if verdict.usable:
        # If the site became readable, the items must be usable: a
        # transcript URL is the minimum for the next stage.
        assert found, "indeks terbaca tetapi tidak ada item - pengurai perlu diperbarui"
        assert all(item.transcript_url for item in found)
    else:
        assert found == []
        assert verdict.remedy


def test_dpr_api_stays_out_of_bounds(session: PoliteSession) -> None:
    """The misplaced-Disallow decision, checked against the live file.

    If DPR fixes its robots.txt, this still passes — `INTENT_DISALLOW`
    is independent of the parse. If DPR *deliberately* opens `/api/`,
    this test is where that conversation starts.
    """
    assert session.allowed("https://www.dpr.go.id/api/risalah") is False


def test_fleurs_is_still_public() -> None:
    """The one test set this project can rely on."""
    rows = {row["name"]: row for row in describe_access()}
    assert rows[FLEURS_ID.name]["gated"] is False


def test_gated_sets_report_their_steps() -> None:
    gated = [row for row in describe_access() if row["gated"]]
    assert gated, "diharapkan ada set terkunci (Common Voice, GigaSpeech 2)"
    for row in gated:
        assert row["access_steps"], f"{row['name']} terkunci tanpa langkah akses"
    if hf_token() is None:
        assert all("TERKUNCI" in row["status"] for row in gated)
