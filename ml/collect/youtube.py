"""Official-channel recordings, via `yt-dlp`.

Both institutions publish their own recordings on their own verified
channels, which is the only route this project uses: re-uploads and
mirrors have no provenance, and the licence note in the manifest would
be a guess.

**Read `ml/DATA_CARD.md` before using this for training data.** The
risalah *text* is free of copyright under UU 28/2014 Pasal 42, but a
broadcast recording carries a broadcasting organisation's related right
("hak terkait lembaga penyiaran"). Audio collected here is therefore
marked `licence_note` as needing permission, and the pilot treats it as
evaluation-only until the owner has an answer from DPR/MK.

`yt-dlp` is invoked as a subprocess rather than imported: it is a tool
the maintainer already updates independently of this package, and its
Python API is explicitly not stable.
"""

from __future__ import annotations

import contextlib
import json
import shutil
import subprocess
import time
from dataclasses import dataclass
from datetime import date, datetime
from pathlib import Path

from collect.gov_index import GovItem, parse_date, parse_komisi, parse_perkara

#: Verified official channels. Checked 2026-10-05.
OFFICIAL_CHANNELS = {
    "dpr": "https://www.youtube.com/@DPRRIOfficial/videos",
    "mk": "https://www.youtube.com/@mahkamahkonstitusi/videos",
}

#: Seconds between `yt-dlp` invocations. YouTube tolerates far more, but
#: a research crawl has no reason to be in a hurry.
DEFAULT_DELAY = 3.0


class YtDlpMissing(RuntimeError):
    pass


class YtDlpFailed(RuntimeError):
    def __init__(self, args: list[str], stderr: str) -> None:
        super().__init__(f"yt-dlp gagal ({' '.join(args[:4])}...): {stderr.strip()[:400]}")
        self.stderr = stderr


@dataclass
class Video:
    id: str
    title: str
    duration: float | None
    upload_date: date | None
    url: str

    def as_gov_item(self, source: str) -> GovItem:
        """Interpret the title as a session reference.

        The *title* date wins over the upload date when present: MK
        titles its videos with the hearing date and uploads days later,
        so the upload date would join the recording to the wrong
        session.
        """
        return GovItem(
            source=source,
            title=self.title,
            session_date=parse_date(self.title) or self.upload_date,
            perkara=parse_perkara(self.title),
            komisi=parse_komisi(self.title),
            media_id=self.id,
            media_url=self.url,
            duration=self.duration,
            extra={
                "upload_date": self.upload_date.isoformat() if self.upload_date else None,
                "date_source": "judul" if parse_date(self.title) else "unggahan",
            },
        )


def _binary() -> str:
    found = shutil.which("yt-dlp")
    if not found:
        raise YtDlpMissing("yt-dlp tidak ditemukan di PATH; pasang dengan `uv tool install yt-dlp`")
    return found


def _run(args: list[str], *, timeout: float = 600.0) -> str:
    completed = subprocess.run(
        [_binary(), *args],
        capture_output=True,
        text=True,
        timeout=timeout,
        check=False,
    )
    if completed.returncode != 0:
        raise YtDlpFailed(args, completed.stderr)
    return completed.stdout


def _parse_upload_date(raw: object) -> date | None:
    if not isinstance(raw, str) or len(raw) != 8 or not raw.isdigit():
        return None
    try:
        return datetime.strptime(raw, "%Y%m%d").date()
    except ValueError:
        return None


def list_channel(
    channel_url: str,
    *,
    limit: int = 25,
    delay: float = DEFAULT_DELAY,
    min_duration: float | None = None,
) -> list[Video]:
    """List a channel's recent videos.

    A flat listing, so one request covers `limit` videos and no upload
    dates come back — titles are what the gov matcher keys on anyway.
    Pass `min_duration` to skip news packages: DPR's channel is mostly
    90-second clips, and a 90-second clip is not a rapat recording.
    """
    raw = _run(
        [
            "--flat-playlist",
            "--playlist-end",
            str(limit),
            "--print",
            "%(id)s\t%(title)s\t%(duration)s",
            channel_url,
        ]
    )
    time.sleep(delay)

    videos: list[Video] = []
    for line in raw.splitlines():
        parts = line.split("\t")
        if len(parts) < 3:
            continue
        video_id, title, duration_text = parts[0], parts[1], parts[2]
        if not video_id or video_id == "NA":
            continue
        duration = None
        try:
            duration = float(duration_text)
        except ValueError:
            duration = None
        if min_duration is not None and (duration is None or duration < min_duration):
            continue
        videos.append(
            Video(
                id=video_id,
                title=title,
                duration=duration,
                upload_date=None,
                url=f"https://www.youtube.com/watch?v={video_id}",
            )
        )
    return videos


def video_metadata(video_id: str, *, delay: float = DEFAULT_DELAY) -> Video:
    """Full metadata for one video, including its upload date.

    One request per video, so only called for candidates whose title
    carries no date — which on the DPR channel is most of them.
    """
    raw = _run(["-J", "--no-playlist", f"https://www.youtube.com/watch?v={video_id}"])
    time.sleep(delay)
    payload = json.loads(raw)
    return Video(
        id=payload.get("id") or video_id,
        title=payload.get("title") or "",
        duration=float(payload["duration"]) if payload.get("duration") else None,
        upload_date=_parse_upload_date(payload.get("upload_date")),
        url=payload.get("webpage_url") or f"https://www.youtube.com/watch?v={video_id}",
    )


def download_audio(
    video_id: str,
    dest: str | Path,
    *,
    sample_rate: int = 16000,
    delay: float = DEFAULT_DELAY,
    timeout: float = 3600.0,
) -> Path:
    """Download one video's audio as 16 kHz mono WAV.

    16 kHz mono because that is what Whisper consumes; keeping the
    original Opus would mean every alignment run re-decodes it. Already
    present and non-empty means already done — the pilot is resumable
    and a re-run must not re-download hours of audio.
    """
    target = Path(dest)
    if target.exists() and target.stat().st_size > 0:
        return target
    target.parent.mkdir(parents=True, exist_ok=True)

    # yt-dlp writes the final name itself, so give it a template in the
    # right directory and move the result into place.
    staging = target.with_suffix(".download")
    _run(
        [
            "--no-playlist",
            "-f",
            "bestaudio/best",
            "--extract-audio",
            "--audio-format",
            "wav",
            "--postprocessor-args",
            f"ExtractAudio:-ac 1 -ar {sample_rate}",
            "-o",
            str(staging.with_suffix(".%(ext)s")),
            f"https://www.youtube.com/watch?v={video_id}",
        ],
        timeout=timeout,
    )
    time.sleep(delay)

    produced = staging.with_suffix(".wav")
    if not produced.exists():
        raise YtDlpFailed(["--extract-audio"], f"tidak ada keluaran WAV untuk {video_id}")
    produced.replace(target)
    return target


def channel_items(
    source: str,
    *,
    limit: int = 25,
    min_duration: float | None = None,
    resolve_dates: bool = False,
    delay: float = DEFAULT_DELAY,
) -> list[GovItem]:
    """List one official channel as `GovItem`s ready for the join.

    `resolve_dates` spends one extra request per video whose title has
    no parseable date. Off by default because on a 25-video listing that
    is 25 requests for information the matcher may not need.
    """
    channel = OFFICIAL_CHANNELS.get(source)
    if channel is None:
        raise KeyError(f"tidak ada kanal resmi terdaftar untuk {source!r}")
    videos = list_channel(channel, limit=limit, min_duration=min_duration, delay=delay)

    items: list[GovItem] = []
    for video in videos:
        if resolve_dates and parse_date(video.title) is None:
            # A single unavailable video must not end the crawl; the item
            # simply keeps the flat listing's metadata and no date.
            with contextlib.suppress(YtDlpFailed, json.JSONDecodeError):
                video = video_metadata(video.id, delay=delay)
        items.append(video.as_gov_item(source))
    return items
