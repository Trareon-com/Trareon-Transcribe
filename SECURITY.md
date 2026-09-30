# Security Policy — Trareon Transcribe

## Core Privacy Guarantee

Trareon Transcribe performs 100% offline speech-to-text. During any active
transcription (live capture or file transcription), the application makes
**zero network calls**, and **audio never leaves the device under any
configuration**.

There are exactly two features that can open a socket. Both are started by an
explicit user action, and neither can be reached from the transcription path:

1. **Model download** — an optional Whisper model the user selects (HTTPS,
   verified against a SHA256 pinned in the binary).
2. **AI summary** — sends the *text* of a finished transcript to an endpoint
   the user configures. Never audio, never file paths, never device names.

### AI summary specifics

- **Off by default.** With it off, the app is fully offline.
- **Defaults to loopback** (`http://localhost:11434`, Ollama), so even the
  enabled default configuration does not leave the machine.
- **Per-request, never automatic.** Nothing is sent until the user presses
  "Buat Ringkasan".
- **Audited in-app.** Every request increments the counter in the Privacy
  Report screen and is logged there with its destination endpoint.
- **API key storage.** When an OpenAI-compatible endpoint is used, the key is
  stored in the same plaintext settings JSON as every other setting, under
  the per-user OS config directory. There is no OS-keychain dependency in
  this project; this is a deliberate, documented trade-off. The field is
  empty by default and the default provider needs no key.

These boundaries are enforced by tests, not just documented:
`rust_core/src/privacy.rs` fails the build if any capture/inference/export
module gains an HTTP client or references the summary module, if a third
module starts using `reqwest::Client`, or if the shipped summary default
stops being disabled-and-loopback. `test/privacy_proof_test.dart` mirrors
this on the Dart side and additionally asserts that every summary request
notifies the Privacy Report counter *before* the request is sent.

There is no telemetry, no analytics, and no crash reporting enabled by
default. Any future opt-in diagnostics will be documented here before
release and will never transmit audio.

## Reporting a Vulnerability

If you find a security issue (memory safety bug, path traversal, unsafe
deserialization, dependency vulnerability, etc.), please report it privately
rather than opening a public issue:

- Open a [GitHub Security Advisory](https://github.com/Trareon-com/Transcribe/security/advisories/new)
  on this repository, or
- Email the maintainer directly (see repository profile) with details and,
  if possible, a reproduction.

We aim to acknowledge reports within 72 hours. Fix timelines follow severity:

| Severity | Target fix time |
|---|---|
| Critical (RCE, data exfiltration, network-call regression) | 24–48h |
| High | 7 days |
| Medium | 30 days |
| Low | Next scheduled release |

## Supported Versions

Only the latest released version receives security fixes while the project
is pre-1.0.

## Development Practices

- `cargo audit` and `cargo deny` run on every pull request; a HIGH+ severity
  advisory or license violation blocks merge.
- `cargo clippy -- -D warnings` and `flutter analyze` must be clean before
  merge.
- No `unsafe` Rust without an inline justification comment.
- No `unwrap`/`expect`/`panic!` in library code — all fallible paths return
  `Result<T, Trareon TranscribeError>`.
- Dependencies are kept current via Dependabot (weekly); `Cargo.lock` and
  `pubspec.lock` are committed and never deleted.
- This policy is reviewed at least every 6 months.

Last reviewed: 2026-09-30.
