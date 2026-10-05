"""The Indonesian Meeting ASR benchmark.

Scoring is deliberately separated from decoding: a runner produces
hypotheses, this module scores them with `eval/normalize.py`. The
consequence worth having is that re-scoring under a changed
normalisation policy costs nothing — no model is re-run — and that every
model on every set is scored by exactly the same code.

Reporting rules, inherited from `docs/WER-BENCH.md` and enforced here
rather than left to whoever writes the table:

1. Read-speech and meeting-audio sets are reported in **separate
   blocks**, never pooled. Averaging them produces a figure that
   describes neither.
2. Every row carries the normalisation policy and its version.
3. Every block states the machine, because RTF is meaningless without
   it, and the clip count, because a 12-clip smoke run is not a model's
   WER.
"""

from __future__ import annotations

import json
import platform
import subprocess
from dataclasses import dataclass, field
from datetime import UTC, datetime
from pathlib import Path

from common.atomic import write_json, write_text
from eval.normalize import ID_MEETING, POLICY_VERSION, NormalizerConfig
from eval.runners import Runner, RunnerFailed, parse_manifest_tsv
from eval.wer import ClipScore, Errors, SetScore, char_errors, word_errors


@dataclass(frozen=True)
class TestSet:
    """One scored corpus."""

    name: str
    manifest: Path
    #: What the speech is. Printed next to every figure.
    domain: str
    #: "baca" (read) or "rapat" (meeting). Decides the report block.
    speech_kind: str
    licence_note: str = ""
    notes: str = ""
    #: Default clip cap for this set. Needed because the models differ in
    #: speed by a factor of forty on this CPU — measured 2026-10-05:
    #: tiny 3.4x real time, small 0.37x, large-v3-turbo-q5 0.09x — so a
    #: cap that makes tiny instant makes turbo-q5 an afternoon. Chosen
    #: per set from how long its clips are, and applied to *every* model
    #: so that a column comparison is always over identical clips.
    default_limit: int | None = None

    @property
    def is_meeting(self) -> bool:
        return self.speech_kind == "rapat"


@dataclass
class BenchmarkResult:
    scores: list[SetScore] = field(default_factory=list)
    #: Runner/set pairs that could not be measured, with the reason.
    errors: list[dict] = field(default_factory=list)
    machine: str = ""
    commit: str = ""
    created_at: str = ""
    policy: str = ""
    #: Every distinct commit the merged runs came from. More than one
    #: means the RTF column mixes builds, which is worth saying out loud
    #: rather than hiding behind whichever file was read last.
    commits: list[str] = field(default_factory=list)

    def for_set(self, name: str) -> list[SetScore]:
        return [score for score in self.scores if score.test_set == name]

    def as_dict(self) -> dict:
        return {
            "benchmark": "Indonesian Meeting ASR v0",
            "created_at": self.created_at,
            "machine": self.machine,
            "commit": self.commit,
            "normalisation_policy": self.policy,
            "commits": self.commits or ([self.commit] if self.commit else []),
            "scores": [score.as_dict() for score in self.scores],
            "errors": self.errors,
        }


def machine_description() -> str:
    """The machine, in enough detail for an RTF to mean something."""
    processor = platform.processor() or platform.machine()
    model = ""
    try:
        for line in Path("/proc/cpuinfo").read_text(encoding="utf-8").splitlines():
            if line.startswith("model name"):
                model = line.split(":", 1)[1].strip()
                break
    except OSError:
        pass
    cores = ""
    try:
        import os

        cores = f", {os.cpu_count()} thread"
    except Exception:
        pass
    return f"{platform.system()} {platform.machine()}, {model or processor}{cores}"


def git_commit(repo: Path | None = None) -> str:
    root = repo or Path(__file__).resolve().parents[2]
    try:
        completed = subprocess.run(
            ["git", "-C", str(root), "rev-parse", "--short", "HEAD"],
            capture_output=True,
            text=True,
            timeout=15,
            check=False,
        )
    except (OSError, subprocess.SubprocessError):
        return ""
    return completed.stdout.strip() if completed.returncode == 0 else ""


def score_set(
    runner: Runner,
    test_set: TestSet,
    *,
    config: NormalizerConfig = ID_MEETING,
    limit: int | None = None,
) -> SetScore:
    """Run `runner` over `test_set` and score the hypotheses."""
    references = dict(parse_manifest_tsv(test_set.manifest))
    results = runner.run(test_set.manifest, limit=limit)

    clips: list[ClipScore] = []
    for result in results:
        reference = references.get(result.clip)
        if reference is None:
            # A hypothesis for a clip the manifest does not list cannot
            # be scored; counting it would invent a reference.
            continue
        clips.append(
            ClipScore(
                clip=result.clip,
                reference=reference,
                hypothesis=result.hypothesis,
                words=word_errors(reference, result.hypothesis, config),
                chars=char_errors(reference, result.hypothesis, config),
                audio_secs=result.audio_secs,
                elapsed_secs=result.elapsed_secs,
                failed=result.failed,
            )
        )
    return SetScore(
        model=runner.label,
        test_set=test_set.name,
        policy=f"{config.name}/{POLICY_VERSION}",
        clips=clips,
    )


def run_benchmark(
    runners: list[Runner],
    test_sets: list[TestSet],
    *,
    config: NormalizerConfig = ID_MEETING,
    limit: int | None = None,
    verbose: bool = True,
) -> BenchmarkResult:
    """Score every runner on every set, recording failures rather than
    aborting: one unavailable model must not void the whole table."""
    result = BenchmarkResult(
        machine=machine_description(),
        commit=git_commit(),
        created_at=datetime.now(UTC).isoformat(timespec="seconds"),
        policy=f"{config.name}/{POLICY_VERSION}",
    )
    for test_set in test_sets:
        if not Path(test_set.manifest).exists():
            result.errors.append(
                {
                    "test_set": test_set.name,
                    "model": "*",
                    "error": f"manifes tidak ada: {test_set.manifest}",
                }
            )
            continue
        # An explicit --limit overrides; otherwise the set's own cap. The
        # same number for every model, so a column is always comparable.
        set_limit = limit if limit is not None else test_set.default_limit
        for runner in runners:
            if verbose:
                print(
                    f"  {runner.label} on {test_set.name}"
                    f"{f' (maks {set_limit} klip)' if set_limit else ''} ...",
                    flush=True,
                )
            try:
                score = score_set(runner, test_set, config=config, limit=set_limit)
            except (RunnerFailed, OSError, ValueError, ImportError) as error:
                result.errors.append(
                    {
                        "test_set": test_set.name,
                        "model": runner.label,
                        "error": f"{type(error).__name__}: {error}",
                    }
                )
                if verbose:
                    print(f"    GAGAL: {error}", flush=True)
                continue
            if not score.clips:
                result.errors.append(
                    {
                        "test_set": test_set.name,
                        "model": runner.label,
                        "error": "tidak ada klip yang terukur",
                    }
                )
                continue
            result.scores.append(score)
            if verbose:
                print(
                    f"    WER {score.words.rate * 100:.1f}%  "
                    f"CER {score.chars.rate * 100:.1f}%  "
                    f"RTF {score.rtf:.2f}x  ({len(score.clips)} klip)",
                    flush=True,
                )
    return result


# -- reporting ---------------------------------------------------------


def render_markdown(result: BenchmarkResult, test_sets: list[TestSet]) -> str:
    """The published table.

    Read speech and meeting audio get separate blocks; see the module
    docstring for why that is not a formatting preference.
    """
    by_name = {test_set.name: test_set for test_set in test_sets}
    lines: list[str] = [
        "# Benchmark: Indonesian Meeting ASR v0",
        "",
        f"- Dibuat: {result.created_at}",
        f"- Mesin: {result.machine}",
        (
            f"- Commit: `{result.commit or 'tidak diketahui'}`"
            if len(result.commits) <= 1
            else "- Commit: "
            + ", ".join(f"`{commit}`" for commit in result.commits)
            + " ⚠️ beberapa build - kolom RTF mencampur keduanya"
        ),
        f"- Normalisasi: `{result.policy}` (lihat `ml/eval/normalize.py`)",
        "",
        "RTF = detik audio per detik jam dinding. Di bawah 1,0 berarti model "
        "tidak bisa mengikuti rapat langsung di mesin ini.",
        "",
        "**RTF juga bergantung pada apa lagi yang berjalan saat pengukuran.** "
        "Angka di bawah diambil di mesin yang sedang dipakai mengerjakan hal "
        "lain, jadi perlakukan RTF sebagai urutan besaran (apakah model ini "
        "bisa real-time di kelas mesin ini?) dan bukan sebagai tolok ukur "
        "yang presisi. WER dan CER tidak terpengaruh beban.",
        "",
    ]

    for kind, heading, caveat in (
        (
            "baca",
            "Ucapan baca (read speech)",
            "FLEURS dan Common Voice adalah ucapan **dibaca**, satu penutur, "
            "mikrofon dekat. Model yang bagus di sini BELUM terbukti bisa "
            "menangani rapat empat orang lewat mikrofon laptop.",
        ),
        (
            "rapat",
            "Ucapan rapat / spontan",
            "Inilah beban kerja sebenarnya aplikasi ini. Angka di sini dan di "
            "blok atas **tidak boleh dirata-ratakan**.",
        ),
    ):
        names = [name for name, item in by_name.items() if item.speech_kind == kind]
        measured = [name for name in names if result.for_set(name)]
        if not measured:
            continue
        lines += [f"## {heading}", "", caveat, ""]
        for name in measured:
            test_set = by_name[name]
            scores = sorted(result.for_set(name), key=lambda score: score.words.rate)
            clips = scores[0].clip_count
            lines += [
                f"### {name}",
                "",
                f"- Jenis: {test_set.domain}",
                f"- Klip terukur: {clips}"
                + ("  ⚠️ uji asap, bukan WER definitif" if clips < 25 else ""),
                f"- Lisensi: {test_set.licence_note or 'tidak dicatat'}",
            ]
            if test_set.notes:
                lines.append(f"- Catatan: {test_set.notes}")
            lines += [
                "",
                "| Model | WER | CER | RTF | Subst | Hapus | Sisip | Gagal |",
                "|---|---:|---:|---:|---:|---:|---:|---:|",
            ]
            for score in scores:
                words = score.words
                lines.append(
                    f"| {score.model} "
                    f"| {words.rate * 100:.1f}% "
                    f"| {score.chars.rate * 100:.1f}% "
                    f"| {score.rtf:.2f}× "
                    f"| {words.substitutions} "
                    f"| {words.deletions} "
                    f"| {words.insertions} "
                    f"| {score.failures} |"
                )
            lines.append("")

    if result.errors:
        lines += ["## Tidak terukur", "", "| Set | Model | Sebab |", "|---|---|---|"]
        for error in result.errors:
            reason = str(error["error"]).replace("|", "/").splitlines()[0][:160]
            lines.append(f"| {error['test_set']} | {error['model']} | {reason} |")
        lines.append("")

    lines += [
        "## Cara membaca tabel ini",
        "",
        "1. WER Bahasa Indonesia kejam karena afiksasi: "
        "`mempertanggungjawabkan` yang salah satu suku kata tetap satu kata "
        "salah utuh. CER menunjukkan seberapa dekat kesalahannya.",
        "2. Angka dari korpus < 25 klip adalah uji asap. Jangan dikutip sebagai WER model.",
        "3. RTF hanya berarti bersama nama mesin di atas.",
        "4. Kolom Subst/Hapus/Sisip membedakan model yang salah dengar dari "
        "model yang menghilangkan atau mengarang kata - dua kegagalan yang "
        "sangat berbeda bagi pengguna.",
        "",
    ]
    return "\n".join(lines)


def write_report(
    result: BenchmarkResult,
    test_sets: list[TestSet],
    *,
    markdown_path: str | Path,
    json_path: str | Path,
) -> None:
    write_text(markdown_path, render_markdown(result, test_sets))
    write_json(json_path, result.as_dict())


def load_report(path: str | Path) -> dict:
    return json.loads(Path(path).read_text(encoding="utf-8"))


def _errors(payload: dict) -> Errors:
    return Errors(
        substitutions=payload["substitutions"],
        deletions=payload["deletions"],
        insertions=payload["insertions"],
        reference_length=payload["reference_length"],
    )


def merge_reports(paths: list[str | Path]) -> BenchmarkResult:
    """Combine several benchmark JSONs into one report.

    Scoring is already separate from decoding here, and this is the other
    half of that: a set measured in a later run can be folded into the
    published table without re-running the models that were measured in
    an earlier one. On this machine `large-v3-turbo-q5` runs at 0.09x
    real time, so re-running a full matrix to add one test set would cost
    an afternoon for nothing.

    Scores are rebuilt from the per-clip detail where a file has it, so
    the merged table is computed by the same code as a single-run one;
    where it does not, the report's own totals are carried across. A
    later file wins for a given (model, test set) pair, which makes a
    re-measurement replace rather than duplicate.

    Do not pass the same path as both an input and the output: the
    inputs are read before the output is written, but a mistake there
    destroys the data being merged.
    """
    merged = BenchmarkResult()
    by_key: dict[tuple[str, str], SetScore] = {}
    errors: dict[tuple[str, str], dict] = {}

    for path in paths:
        payload = load_report(path)
        # The newest file's provenance describes the merged report; all
        # runs must come from the same machine and commit for the RTF
        # column to mean anything, which `--merge` cannot enforce but
        # the header makes visible.
        merged.machine = payload.get("machine", merged.machine)
        merged.commit = payload.get("commit", merged.commit)
        merged.created_at = payload.get("created_at", merged.created_at)
        merged.policy = payload.get("normalisation_policy", merged.policy)
        for commit in payload.get("commits") or [payload.get("commit", "")]:
            if commit and commit not in merged.commits:
                merged.commits.append(commit)

        for score in payload.get("scores", []):
            key = (score["model"], score["test_set"])
            detail = score.get("clip_detail") or []
            clips = [
                ClipScore(
                    clip=clip.get("clip", ""),
                    reference="",
                    hypothesis="",
                    words=_errors(clip["words"]),
                    chars=_errors(clip["chars"]),
                    audio_secs=clip.get("audio_secs", 0.0),
                    elapsed_secs=clip.get("elapsed_secs", 0.0),
                    failed=clip.get("failed", False),
                )
                for clip in detail
            ]
            by_key[key] = SetScore(
                model=score["model"],
                test_set=score["test_set"],
                policy=score.get("policy", ""),
                clips=clips,
                # Carried straight from the report when the per-clip
                # detail is absent, which is the case for any file
                # written before `clip_detail` existed.
                loaded_words=None if detail else _errors(score["word_errors"]),
                loaded_chars=None if detail else _errors(score["char_errors"]),
                loaded_clips=None if detail else score.get("clips"),
                loaded_failures=None if detail else score.get("failed_clips"),
                loaded_audio_secs=None if detail else score.get("audio_secs"),
                loaded_elapsed_secs=None if detail else score.get("elapsed_secs"),
            )
            # A set that now has a score is no longer an error.
            errors.pop(key, None)

        for error in payload.get("errors", []):
            key = (error.get("model", "*"), error.get("test_set", ""))
            if key not in by_key:
                errors[key] = error

    merged.scores = list(by_key.values())
    merged.errors = list(errors.values())
    return merged
