"""The fetcher's politeness guarantees.

Hermetic: `requests.Session.get` is replaced, so none of this touches
the network. The point of these tests is that the four promises in
`common/fetch.py`'s docstring are enforced by code rather than by
intention.
"""

from __future__ import annotations

import pytest
import requests

from common.fetch import (
    INTENT_DISALLOW,
    USER_AGENT,
    ChallengeDetected,
    HttpError,
    PoliteSession,
    RobotsDisallowed,
)

CHALLENGE_BODY = (
    b'<!DOCTYPE html><html lang="en-US"><head><title>Just a moment...</title>'
    b'<meta name="robots" content="noindex,nofollow"></head><body></body></html>'
)


class FakeResponse:
    def __init__(
        self,
        *,
        status: int = 200,
        body: bytes = b"ok",
        content_type: str = "text/html",
        headers: dict[str, str] | None = None,
    ) -> None:
        self.status_code = status
        self.content = body
        self.headers = {"Content-Type": content_type, **(headers or {})}

    @property
    def text(self) -> str:
        return self.content.decode("utf-8", errors="replace")


class Recorder:
    """Stands in for `requests.Session.get` and records every call."""

    def __init__(self, routes: dict[str, FakeResponse] | None = None) -> None:
        self.routes = routes or {}
        self.calls: list[tuple[str, str]] = []

    def __call__(self, url: str, **kwargs: object) -> FakeResponse:
        headers = kwargs.get("headers") or {}
        agent = headers.get("User-Agent", "") if isinstance(headers, dict) else ""
        self.calls.append((url, str(agent)))
        for prefix, response in self.routes.items():
            if url.startswith(prefix):
                return response
        return FakeResponse()


@pytest.fixture
def session(monkeypatch: pytest.MonkeyPatch) -> PoliteSession:
    polite = PoliteSession(delay=0.0)
    return polite


def _install(polite: PoliteSession, recorder: Recorder) -> None:
    polite._session.get = recorder  # type: ignore[method-assign]


# -- 1. identified ------------------------------------------------------


def test_user_agent_names_the_project_and_a_contact() -> None:
    assert "Trareon" in USER_AGENT
    assert "kontak" in USER_AGENT
    assert "riset" in USER_AGENT


def test_user_agent_carries_no_url() -> None:
    """Measured: the DPR WAF 403s any User-Agent containing one.

    See the constant's comment in common/fetch.py.
    """
    assert "http://" not in USER_AGENT
    assert "https://" not in USER_AGENT


def test_every_request_sends_the_user_agent(session: PoliteSession) -> None:
    recorder = Recorder()
    _install(session, recorder)
    session.get("https://example.test/a")
    assert all(agent == USER_AGENT for _, agent in recorder.calls if agent)
    assert session._session.headers["User-Agent"] == USER_AGENT


# -- 2. robots-aware ---------------------------------------------------


def test_disallowed_path_raises_rather_than_fetching(session: PoliteSession) -> None:
    recorder = Recorder(
        {
            "https://example.test/robots.txt": FakeResponse(
                body=b"User-agent: *\nDisallow: /rahasia/\n", content_type="text/plain"
            )
        }
    )
    _install(session, recorder)
    with pytest.raises(RobotsDisallowed):
        session.get("https://example.test/rahasia/berkas.pdf")
    assert session.stats.robots_blocks == 1
    # robots.txt itself was fetched; the forbidden URL was not.
    assert not any(url.endswith("berkas.pdf") for url, _ in recorder.calls)


def test_allowed_path_is_fetched(session: PoliteSession) -> None:
    recorder = Recorder(
        {
            "https://example.test/robots.txt": FakeResponse(
                body=b"User-agent: *\nDisallow: /rahasia/\n", content_type="text/plain"
            )
        }
    )
    _install(session, recorder)
    assert session.get("https://example.test/publik/a.pdf").status_code == 200


def test_robots_is_fetched_once_per_host(session: PoliteSession) -> None:
    recorder = Recorder(
        {
            "https://example.test/robots.txt": FakeResponse(
                body=b"User-agent: *\nAllow: /\n", content_type="text/plain"
            )
        }
    )
    _install(session, recorder)
    for index in range(4):
        session.get(f"https://example.test/a{index}")
    robots_calls = [url for url, _ in recorder.calls if url.endswith("robots.txt")]
    assert len(robots_calls) == 1


def test_missing_robots_means_no_rules(session: PoliteSession) -> None:
    recorder = Recorder({"https://example.test/robots.txt": FakeResponse(status=404)})
    _install(session, recorder)
    assert session.get("https://example.test/apa-pun").status_code == 200


def test_crawl_delay_is_picked_up(session: PoliteSession) -> None:
    recorder = Recorder(
        {
            "https://example.test/robots.txt": FakeResponse(
                body=b"User-agent: *\nAllow: /\nCrawl-delay: 7\n", content_type="text/plain"
            )
        }
    )
    _install(session, recorder)
    session.get("https://example.test/a")
    assert session._host_delay["example.test"] == 7.0


def test_obey_robots_false_skips_the_check() -> None:
    polite = PoliteSession(delay=0.0, obey_robots=False)
    recorder = Recorder(
        {
            "https://example.test/robots.txt": FakeResponse(
                body=b"User-agent: *\nDisallow: /\n", content_type="text/plain"
            )
        }
    )
    _install(polite, recorder)
    assert polite.get("https://example.test/rahasia").status_code == 200


# -- 2b. a misplaced Disallow is not permission ------------------------


def test_dpr_api_is_out_of_bounds_despite_parsing_as_allowed(
    session: PoliteSession,
) -> None:
    """The real robots.txt permits /api/ by accident.

    Its `Disallow` block sits after the last `User-agent` line, so the
    standard assigns it to YandexBot and `Allow: /` wins for everyone.
    Reading that as consent would be a technicality; `INTENT_DISALLOW`
    keeps the path out of bounds.
    """
    real_robots = (
        b"User-agent: *\nAllow: /\n\n"
        b"User-agent: YandexBot\nAllow: /\n\n"
        b"# Disallow admin and private areas\n"
        b"Disallow: /admin/\nDisallow: /api/\n"
    )
    recorder = Recorder(
        {
            "https://www.dpr.go.id/robots.txt": FakeResponse(
                body=real_robots, content_type="text/plain"
            )
        }
    )
    _install(session, recorder)

    # The parser really does permit it...
    import urllib.robotparser

    parser = urllib.robotparser.RobotFileParser()
    parser.parse(real_robots.decode().splitlines())
    assert parser.can_fetch(USER_AGENT, "https://www.dpr.go.id/api/risalah") is True

    # ...and we still refuse.
    assert session.allowed("https://www.dpr.go.id/api/risalah") is False
    with pytest.raises(RobotsDisallowed):
        session.get("https://www.dpr.go.id/api/risalah")


def test_intent_disallow_does_not_block_the_public_pages(session: PoliteSession) -> None:
    recorder = Recorder(
        {
            "https://www.dpr.go.id/robots.txt": FakeResponse(
                body=b"User-agent: *\nAllow: /\n", content_type="text/plain"
            )
        }
    )
    _install(session, recorder)
    assert session.allowed("https://www.dpr.go.id/dokumen/persidangan-paripurna/risalah-rapat")


def test_intent_disallow_covers_both_host_spellings() -> None:
    assert "/api/" in INTENT_DISALLOW["www.dpr.go.id"]
    assert "/api/" in INTENT_DISALLOW["dpr.go.id"]


# -- 3. rate limited and backs off -------------------------------------


def test_requests_to_one_host_are_spaced(monkeypatch: pytest.MonkeyPatch) -> None:
    polite = PoliteSession(delay=2.5)
    slept: list[float] = []
    monkeypatch.setattr("common.fetch.time.sleep", slept.append)
    recorder = Recorder(
        {
            "https://example.test/robots.txt": FakeResponse(
                body=b"User-agent: *\nAllow: /\n", content_type="text/plain"
            )
        }
    )
    _install(polite, recorder)
    polite.get("https://example.test/a")
    polite.get("https://example.test/b")
    assert any(pause > 0 for pause in slept)


def test_server_error_is_retried_then_raises(monkeypatch: pytest.MonkeyPatch) -> None:
    polite = PoliteSession(delay=0.0, max_retries=2)
    monkeypatch.setattr("common.fetch.time.sleep", lambda _: None)
    recorder = Recorder({"https://example.test/a": FakeResponse(status=503)})
    _install(polite, recorder)
    with pytest.raises(HttpError) as caught:
        polite.get("https://example.test/a")
    assert caught.value.status == 503
    attempts = [url for url, _ in recorder.calls if url.endswith("/a")]
    assert len(attempts) == 3  # initial + 2 retries


def test_retry_after_header_is_honoured(monkeypatch: pytest.MonkeyPatch) -> None:
    polite = PoliteSession(delay=1.0, max_retries=1)
    slept: list[float] = []
    monkeypatch.setattr("common.fetch.time.sleep", slept.append)
    recorder = Recorder(
        {"https://example.test/a": FakeResponse(status=429, headers={"Retry-After": "30"})}
    )
    _install(polite, recorder)
    with pytest.raises(HttpError):
        polite.get("https://example.test/a")
    assert max(slept) >= 30.0


def test_a_404_is_not_retried(monkeypatch: pytest.MonkeyPatch) -> None:
    polite = PoliteSession(delay=0.0, max_retries=3)
    monkeypatch.setattr("common.fetch.time.sleep", lambda _: None)
    recorder = Recorder({"https://example.test/a": FakeResponse(status=404)})
    _install(polite, recorder)
    with pytest.raises(HttpError):
        polite.get("https://example.test/a")
    assert len([url for url, _ in recorder.calls if url.endswith("/a")]) == 1


# -- the anti-bot line we do not cross ---------------------------------


def test_cloudflare_interstitial_raises_rather_than_being_parsed(
    session: PoliteSession,
) -> None:
    recorder = Recorder({"https://example.test/a": FakeResponse(status=403, body=CHALLENGE_BODY)})
    _install(session, recorder)
    with pytest.raises(ChallengeDetected):
        session.get("https://example.test/a")
    assert session.stats.challenges == 1


def test_a_challenge_served_as_http_200_is_still_a_challenge(
    session: PoliteSession,
) -> None:
    """The nastier case: a 200 whose body is an interstitial.

    Without this the crawl would store the challenge page as if it were
    the document index and report zero items with no reason.
    """
    recorder = Recorder({"https://example.test/a": FakeResponse(body=CHALLENGE_BODY)})
    _install(session, recorder)
    with pytest.raises(ChallengeDetected):
        session.get("https://example.test/a")


def test_cf_mitigated_header_marks_a_challenge(session: PoliteSession) -> None:
    recorder = Recorder(
        {"https://example.test/a": FakeResponse(headers={"cf-mitigated": "challenge"})}
    )
    _install(session, recorder)
    with pytest.raises(ChallengeDetected):
        session.get("https://example.test/a")


def test_a_pdf_is_never_scanned_for_challenge_markers(session: PoliteSession) -> None:
    """A 50 MB PDF must not be decoded as text to answer that question."""
    recorder = Recorder(
        {
            "https://example.test/a.pdf": FakeResponse(
                body=b"%PDF-1.7 just a moment... binary", content_type="application/pdf"
            )
        }
    )
    _install(session, recorder)
    assert session.get("https://example.test/a.pdf").status_code == 200


# -- 4. resumable ------------------------------------------------------


def test_download_writes_the_file(session: PoliteSession, tmp_path) -> None:
    recorder = Recorder(
        {
            "https://example.test/a.pdf": FakeResponse(
                body=b"%PDF-1.7 isi", content_type="application/pdf"
            )
        }
    )
    _install(session, recorder)
    target = session.download(
        "https://example.test/a.pdf", tmp_path / "a.pdf", expect_type="application/pdf"
    )
    assert target.read_bytes() == b"%PDF-1.7 isi"


def test_an_existing_file_is_not_refetched(session: PoliteSession, tmp_path) -> None:
    target = tmp_path / "a.pdf"
    target.write_bytes(b"sudah ada")
    recorder = Recorder()
    _install(session, recorder)
    session.download("https://example.test/a.pdf", target)
    assert target.read_bytes() == b"sudah ada"
    assert session.stats.cache_hits == 1
    assert recorder.calls == []


def test_cache_makes_a_second_run_free(tmp_path) -> None:
    cache = tmp_path / "cache"
    recorder = Recorder(
        {
            "https://example.test/a.pdf": FakeResponse(
                body=b"%PDF isi", content_type="application/pdf"
            )
        }
    )
    first = PoliteSession(cache, delay=0.0)
    _install(first, recorder)
    first.download("https://example.test/a.pdf", tmp_path / "one" / "a.pdf")

    second = PoliteSession(cache, delay=0.0)
    _install(second, recorder)
    second.download("https://example.test/a.pdf", tmp_path / "two" / "a.pdf")

    assert (tmp_path / "two" / "a.pdf").read_bytes() == b"%PDF isi"
    assert second.stats.cache_hits == 1
    # Only the first run hit the network for the PDF.
    assert len([url for url, _ in recorder.calls if url.endswith(".pdf")]) == 1


def test_wrong_content_type_raises_rather_than_storing_an_error_page(
    session: PoliteSession, tmp_path
) -> None:
    """The commonest way a crawl fills a corpus with garbage.

    A 200 that returns an HTML error page where a PDF was expected must
    not land in the corpus as a risalah.
    """
    recorder = Recorder(
        {
            "https://example.test/a.pdf": FakeResponse(
                body=b"<html>Halaman tidak ditemukan</html>", content_type="text/html"
            )
        }
    )
    _install(session, recorder)
    with pytest.raises(Exception, match="Content-Type"):
        session.download(
            "https://example.test/a.pdf", tmp_path / "a.pdf", expect_type="application/pdf"
        )
    assert not (tmp_path / "a.pdf").exists()


def test_network_exception_propagates(session: PoliteSession) -> None:
    def boom(url: str, **kwargs: object) -> FakeResponse:
        raise requests.ConnectionError("tidak tersambung")

    session._session.get = boom  # type: ignore[method-assign]
    session._robots["example.test"] = None
    with pytest.raises(requests.ConnectionError):
        session.get("https://example.test/a")
