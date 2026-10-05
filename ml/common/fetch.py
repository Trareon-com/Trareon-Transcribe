"""A polite HTTP client for the collectors.

"Polite" is four concrete things, not a disposition:

1. **Identified.** The User-Agent names the project and how to reach a
   human. A crawler an administrator cannot identify is a crawler an
   administrator can only block.
2. **robots.txt-aware, and it obeys.** Checked once per host, cached,
   and a disallowed path raises `RobotsDisallowed` rather than being
   fetched. `Crawl-delay` is honoured when the host sets one.
3. **Rate-limited** per host, with exponential backoff on 429/5xx and
   respect for `Retry-After`.
4. **Resumable at item granularity.** Downloads land in a
   content-addressed cache and an already-complete file is not
   re-fetched, so an interrupted crawl restarts without re-downloading
   what it already has. Byte-range resume *within* one file is not
   implemented: a torn download leaves no file at all (the write is
   atomic), so the worst case is re-fetching one item, and the risalah
   PDFs this crawls are single-digit megabytes.

It deliberately does **not** try to get past a bot challenge. If a host
answers with a Cloudflare interstitial we record that and stop — see
`ChallengeDetected`. Working around an anti-bot control is not
politeness, and the sources this sprint cares about (MK, DPR) are meant
to be obtained through an official data request when the public site
refuses automated access.
"""

from __future__ import annotations

import hashlib
import time
import urllib.robotparser
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import urljoin, urlsplit

import requests

from common.atomic import write_bytes

#: Names the project, the purpose, and where to complain.
USER_AGENT = (
    "TrareonTranscribeResearchBot/0.1 "
    "(+https://github.com/trareon/transcribe; "
    "riset ASR Bahasa Indonesia; kontak: issue di repo)"
)

#: Minimum seconds between requests to one host when robots.txt is silent.
DEFAULT_DELAY = 2.0

#: Markers of an anti-bot interstitial rather than real content.
_CHALLENGE_MARKERS = (
    "just a moment...",
    "cf-browser-verification",
    "cf_chl_opt",
    "checking your browser",
    "attention required! | cloudflare",
)


class FetchError(RuntimeError):
    """Base class so a collector can catch everything this module raises."""


class RobotsDisallowed(FetchError):
    """robots.txt forbids this path for our user-agent."""


class ChallengeDetected(FetchError):
    """The host served a bot challenge. We stop rather than solve it."""


class HttpError(FetchError):
    def __init__(self, status: int, url: str) -> None:
        super().__init__(f"HTTP {status} untuk {url}")
        self.status = status
        self.url = url


@dataclass
class FetchStats:
    requests_made: int = 0
    bytes_downloaded: int = 0
    cache_hits: int = 0
    robots_blocks: int = 0
    challenges: int = 0


class PoliteSession:
    """Rate-limited, robots-aware, resumable fetcher.

    One instance per collector run. `cache_dir` makes downloads
    resumable across runs; pass `None` to disable caching (used by the
    tests, which must not write outside tmp_path).
    """

    def __init__(
        self,
        cache_dir: str | Path | None = None,
        *,
        delay: float = DEFAULT_DELAY,
        timeout: float = 60.0,
        max_retries: int = 4,
        obey_robots: bool = True,
        user_agent: str = USER_AGENT,
    ) -> None:
        self.cache_dir = Path(cache_dir) if cache_dir else None
        if self.cache_dir:
            self.cache_dir.mkdir(parents=True, exist_ok=True)
        self.delay = delay
        self.timeout = timeout
        self.max_retries = max_retries
        self.obey_robots = obey_robots
        self.user_agent = user_agent
        self.stats = FetchStats()
        self._session = requests.Session()
        self._session.headers["User-Agent"] = user_agent
        self._last_request: dict[str, float] = {}
        self._robots: dict[str, urllib.robotparser.RobotFileParser | None] = {}
        self._host_delay: dict[str, float] = {}

    # -- politeness ----------------------------------------------------

    def _robots_for(self, url: str) -> urllib.robotparser.RobotFileParser | None:
        """Fetch and cache robots.txt for `url`'s host.

        A host that does not serve one is treated as "no rules", which
        is what the standard says. A host that *errors* is also treated
        as no rules — but we still rate-limit, so the blast radius of
        being wrong is one request every `delay` seconds.
        """
        host = urlsplit(url).netloc
        if host in self._robots:
            return self._robots[host]
        robots_url = urljoin(f"{urlsplit(url).scheme}://{host}", "/robots.txt")
        parser: urllib.robotparser.RobotFileParser | None = urllib.robotparser.RobotFileParser()
        parser.set_url(robots_url)
        try:
            response = self._session.get(robots_url, timeout=self.timeout)
            if response.status_code >= 400:
                parser = None
            else:
                parser.parse(response.text.splitlines())
        except requests.RequestException:
            parser = None
        self._robots[host] = parser
        if parser is not None:
            crawl_delay = parser.crawl_delay(self.user_agent)
            if crawl_delay:
                self._host_delay[host] = float(crawl_delay)
        return parser

    def allowed(self, url: str) -> bool:
        """True when robots.txt permits fetching `url`."""
        if not self.obey_robots:
            return True
        parser = self._robots_for(url)
        if parser is None:
            return True
        return parser.can_fetch(self.user_agent, url)

    def _wait_turn(self, url: str) -> None:
        host = urlsplit(url).netloc
        gap = max(self.delay, self._host_delay.get(host, 0.0))
        last = self._last_request.get(host)
        if last is not None:
            remaining = gap - (time.monotonic() - last)
            if remaining > 0:
                time.sleep(remaining)
        self._last_request[host] = time.monotonic()

    # -- requests ------------------------------------------------------

    def get(self, url: str, **kwargs: object) -> requests.Response:
        """GET `url` politely, retrying 429/5xx with backoff.

        Raises `RobotsDisallowed`, `ChallengeDetected` or `HttpError`.
        """
        if not self.allowed(url):
            self.stats.robots_blocks += 1
            raise RobotsDisallowed(f"robots.txt melarang {url}")

        backoff = self.delay
        last_status = 0
        for attempt in range(self.max_retries + 1):
            self._wait_turn(url)
            self.stats.requests_made += 1
            response = self._session.get(url, timeout=self.timeout, **kwargs)  # type: ignore[arg-type]
            last_status = response.status_code

            if response.status_code in (429, 500, 502, 503, 504):
                if attempt == self.max_retries:
                    break
                retry_after = response.headers.get("Retry-After")
                pause = backoff
                if retry_after and retry_after.isdigit():
                    pause = max(pause, float(retry_after))
                time.sleep(pause)
                backoff *= 2
                continue

            if response.status_code >= 400:
                if _looks_like_challenge(response):
                    self.stats.challenges += 1
                    raise ChallengeDetected(
                        f"{urlsplit(url).netloc} menyajikan tantangan anti-bot "
                        f"(HTTP {response.status_code}); akses otomatis ditolak. "
                        "Jalur resmi (permintaan data / PPID) diperlukan."
                    )
                raise HttpError(response.status_code, url)

            if _looks_like_challenge(response):
                self.stats.challenges += 1
                raise ChallengeDetected(
                    f"{urlsplit(url).netloc} menyajikan tantangan anti-bot pada HTTP 200"
                )

            self.stats.bytes_downloaded += len(response.content)
            return response

        raise HttpError(last_status, url)

    def download(self, url: str, dest: str | Path, *, expect_type: str | None = None) -> Path:
        """Download `url` to `dest`, resuming and caching.

        `expect_type` is a Content-Type prefix (`"application/pdf"`). A
        mismatch raises: a 200 that returns an HTML error page where a
        PDF was expected is the single most common way a crawl fills a
        corpus with garbage.
        """
        target = Path(dest)
        if target.exists() and target.stat().st_size > 0:
            self.stats.cache_hits += 1
            return target

        cached = self._cache_path(url)
        if cached and cached.exists() and cached.stat().st_size > 0:
            self.stats.cache_hits += 1
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(cached.read_bytes())
            return target

        response = self.get(url, stream=False)
        if expect_type:
            content_type = response.headers.get("Content-Type", "")
            if not content_type.startswith(expect_type):
                raise FetchError(
                    f"{url} mengembalikan Content-Type {content_type!r}, diharapkan {expect_type!r}"
                )

        write_bytes(target, response.content)
        if cached:
            write_bytes(cached, response.content)
        return target

    def _cache_path(self, url: str) -> Path | None:
        if not self.cache_dir:
            return None
        digest = hashlib.sha256(url.encode("utf-8")).hexdigest()
        return self.cache_dir / digest[:2] / digest


def _looks_like_challenge(response: requests.Response) -> bool:
    """True when the body is an anti-bot interstitial, not content.

    Checked on the first 4 KiB only: a legitimate 50 MB PDF must not be
    decoded as text to answer this question.
    """
    content_type = response.headers.get("Content-Type", "")
    if "html" not in content_type.lower():
        return False
    if "cf-mitigated" in response.headers:
        return True
    head = response.content[:4096].decode("utf-8", errors="replace").lower()
    return any(marker in head for marker in _CHALLENGE_MARKERS)
