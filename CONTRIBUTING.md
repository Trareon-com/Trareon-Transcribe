# Contributing to Trareon Transcribe

First off, thank you for considering contributing! We welcome contributions of all kinds — bug fixes, features, documentation improvements, and testing.

## Table of Contents

- [Development Setup](#development-setup)
- [Build Instructions](#build-instructions)
- [Running Tests](#running-tests)
- [Code Style](#code-style)
- [Pull Request Process](#pull-request-process)
- [Commit Message Conventions](#commit-message-conventions)
- [Project Layout](#project-layout)
- [CI Gates](#ci-gates)
- [Security-Sensitive Changes](#security-sensitive-changes)
- [Getting Help](#getting-help)

---

## Development Setup

### Prerequisites

- **Flutter SDK** 3.32+ (stable channel) — [Install Flutter](https://flutter.dev/docs/get-started/install)
- **Rust toolchain** 1.80+ — [Install Rust](https://rustup.rs/)
- **CMake** on `PATH` — whisper.cpp is compiled from source via `whisper-rs`
- **macOS**: Xcode 15+ (with Command Line Tools) and CocoaPods
- **Windows**: Visual Studio 2022 Build Tools (with "Desktop development with C++" workload)

### Getting Started

```bash
# 1. Fork and clone the repository
git clone https://github.com/YOUR_USERNAME/Transcribe.git
cd Transcribe

# 2. Add upstream remote
git remote add upstream https://github.com/Trareon-com/Transcribe.git

# 3. Install Flutter dependencies
flutter pub get

# 4. Verify Rust toolchain
cd rust_core
cargo check
cd ..
```

> **Tip**: If you encounter issues with `whisper-rs` compilation, ensure `cmake` is available (`cmake --version`). On macOS, `brew install cmake`; on Windows, install it via Visual Studio Installer or `choco install cmake`.

---

## Build Instructions

### Building the Rust Engine

```bash
cd rust_core

# Debug build (faster compilation, good for development)
cargo build

# Release build (optimized, needed for packaging)
cargo build --release --lib
```

The Rust engine is compiled as a staticlib/cdylib/lib. For Flutter development, the debug build is sufficient.

### Building the Flutter App

Build the Rust engine first, then:

```bash
# macOS
flutter build macos --debug     # or --release for distribution

# Windows
flutter build windows --debug   # or --release for distribution

# Linux
flutter build linux --debug     # or --release for distribution
```

### Running the App (Development Mode)

```bash
# macOS
flutter run -d macos

# Windows
flutter run -d windows

# Linux
flutter run -d linux
```

### Building a Distributable Package

See [`DISTRIBUTION.md`](DISTRIBUTION.md) for the full packaging workflow:

```bash
# macOS
bash scripts/package_macos.sh "1.0.0"

# Windows (PowerShell)
.\scripts\package_windows.ps1 -Version "1.0.0"
```

### Generating FRB Bindings

If you change any `#[flutter_rust_bridge::frb(ignore)]`-free signatures in `rust_core/src/`, regenerate the Dart bindings:

```bash
flutter_rust_bridge_codegen generate \
  --rust-input crate::api,crate::error \
  --rust-root rust_core \
  --dart-output lib/src/rust \
  --dart-entrypoint-class-name RustLib

flutter pub run build_runner build --delete-conflicting-outputs
```

> **Do not** run `flutter_rust_bridge_codegen integrate` — it overwrites `lib/main.dart` with a demo stub. Always use the scoped `generate` command above.

### Generating Audio Test Fixtures

```bash
cd rust_core
cargo run --bin gen_fixtures -- ../test/fixtures
```

This creates synthetic WAV files for decode/VAD tests without requiring a real microphone.

---

## Running Tests

### Rust Tests

```bash
cd rust_core

# Run all Rust unit + integration tests
cargo test --all-features

# Run tests for a specific module
cargo test vad
cargo test session
cargo test export

# Run with output (useful for debugging)
cargo test -- --nocapture
```

### Flutter Tests

```bash
# From the repo root
flutter test

# Run a specific test file
flutter test test/widgets/vu_meter_test.dart
```

### CI Gates (must pass before merging)

```bash
# Rust quality gate
cd rust_core
cargo fmt --check
cargo clippy --all-targets -- -D warnings
cargo test --all-features
cargo audit
cargo deny check

# Flutter quality gate
cd ..
flutter analyze
flutter test
```

### Performance Benchmarks

```bash
bash scripts/benchmark.sh
```

---

## Code Style

### Rust

- **No `unwrap`/`expect`/`panic!` in library code** — every fallible path returns `Result<T, Trareon TranscribeError>`. See `rust_core/src/error.rs` for the error type.
- **No `unsafe` without an inline justification comment** explaining why it's necessary and why a safe alternative isn't viable.
- **No `println!` in library code** — use the `tracing` crate for structured logging.
- Format with `cargo fmt` before committing.
- Run `cargo clippy --all-targets -- -D warnings` — warnings are treated as errors.
- Prefer explicit `Result<T, Trareon TranscribeError>` over type aliases in FRB-exposed signatures (the `Trareon TranscribeResult<T>` alias can't be resolved by FRB codegen across modules).
- Follow the [Rust API Guidelines](https://rust-lang.github.io/api-guidelines/).

### Dart / Flutter

- Use **Riverpod** for state management (`StateNotifierProvider`). No global mutable state outside providers.
- **Widgets stay presentational** where reasonable — business logic lives in notifiers and services.
- Format with `dart format` (or your IDE's Flutter formatter).
- Run `flutter analyze` — it must be clean before merging.
- **Accessibility**: Include `Semantics` labels on all interactive widgets. Minimum 24×24pt tap targets. Follow WCAG 2.2 AA contrast ratios.

### General

- Prefer editing existing files over creating new ones.
- Don't add abstractions or configuration beyond what the current task needs.
- Keep it simple — favor clarity over cleverness.

---

## Pull Request Process

1. **Create a feature branch** from `main`:
   ```bash
   git checkout -b feat/my-feature main
   ```

2. **Make your changes** following the [Code Style](#code-style) guidelines.

3. **Run all CI gates locally** (see above) — every check must pass.

4. **Write or update tests** for any new or changed functionality. Pure logic (VAD decisions, export formatting, session state machine, auto-split thresholds, sanitization, etc.) **must** have unit tests. Hardware-dependent code (live audio capture) is exercised via manual smoke tests.

5. **Commit your changes** following the [Commit Message Conventions](#commit-message-conventions).

6. **Push your branch** and open a pull request against `main`:
   ```bash
   git push origin feat/my-feature
   ```

7. **Fill out the PR template** describing:
   - What changed and why
   - Testing performed (both automated and manual)
   - Any caveats or follow-up work

8. **Address reviewer feedback** — expect at least one review before merging.

9. **Merge** is performed by a maintainer once all CI checks pass and at least one approval is received. We use **squash-merge** to keep the history clean (unless there's a reason to preserve individual commits).

### PR Checklist

Before opening your PR, verify:

- [ ] `cargo fmt --check` passes
- [ ] `cargo clippy --all-targets -- -D warnings` passes
- [ ] `cargo test --all-features` passes
- [ ] `cargo audit` passes
- [ ] `cargo deny check` passes
- [ ] `flutter analyze` passes
- [ ] `flutter test` passes
- [ ] New code includes tests (where applicable)
- [ ] No `unwrap`/`expect`/`panic!` in library code
- [ ] No `unsafe` without justification comment
- [ ] Commit messages follow conventions (see below)
- [ ] CHANGELOG.md updated (if applicable)
- [ ] Documentation updated (README, ARCHITECTURE, etc.) if APIs or workflows changed

---

## Commit Message Conventions

We follow a structured commit message format inspired by [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <short summary>

[optional body — what changed and why]
[optional footer — breaking changes, issue references, co-authors]
```

### Types

| Type | When to use |
|------|------------|
| `feat` | A new feature or user-facing capability |
| `fix` | A bug fix |
| `docs` | Documentation-only changes |
| `style` | Code formatting, missing semicolons, etc. (no logic change) |
| `refactor` | Code restructuring that doesn't change behavior |
| `perf` | Performance improvement |
| `test` | Adding or updating tests |
| `build` | Build system, CI, or dependency changes |
| `chore` | Repository maintenance, tooling, config changes |

### Scopes

| Scope | When to use |
|-------|------------|
| `rust` | Rust engine (`rust_core/`) |
| `ui` | Flutter UI (`lib/`) |
| `bridge` | FRB bindings / bridge service |
| `ci` | CI/CD workflows |
| `docs` | Documentation files |
| `release` | Release-related changes |
| *(none)* | Cross-cutting changes |

### Examples

```
feat(rust): add resumable model download with SHA256 verification

Append partial downloads instead of restarting. Covered by a
deterministic unit test for resumed vs. fresh download paths.
```

```
fix(ui): correct VU meter jitter on silence frames

The VU meter was updating on every zero-signal frame, causing
visible flutter. Gate at -60 dB threshold.
```

```
docs: add FAQ section to README
```

```
build(ci): add macOS packaging smoke test to CI
```

```
chore: update cargo-audit to 0.21
```

### Body Guidelines

- Use the imperative mood ("add" not "added" or "adds")
- Explain **what** changed and **why** — not just what
- Reference related issues: `Closes #123`, `Related to #456`
- For breaking changes, include `BREAKING CHANGE:` in the footer

---

## Project Layout

```
lib/                      Flutter UI
  screens/                 Full-page screens (main, wizard, library, settings, player, privacy report)
  widgets/                 Reusable UI pieces (VU meter, transcript view, shortcuts panel, ...)
  state/                   Riverpod state notifiers + Dart mirrors of the Rust API types
  services/                RustBridge interface, RustEngineBridge (real), RustBridgeMock, native library loader
  src/rust/                flutter_rust_bridge-generated Dart bindings — do not hand-edit
  theme/                   Color tokens, ThemeData

rust_core/                 Rust engine (compiled as staticlib/cdylib/lib)
  src/
    api.rs                 Public surface exposed to Dart (FRB entry point)
    frb_generated.rs        flutter_rust_bridge-generated glue — do not hand-edit
    audio/                  Device enumeration, ring buffer, SessionConfig/SessionMode
    vad/                    Dual-stage VAD (WebRTC gate + confirmation detector)
    stt/                    whisper-rs engine wrapper + file/batch transcription
    dedupe/                 Echo-dedupe (MIC vs SPK similarity)
    export/                 Markdown/TXT/JSON/SRT/VTT/HTML/DOCX/WAV writers
    decode/                 Symphonia decode + rubato resample (no ffmpeg)
    model.rs                Model catalog, SHA256 verification, resumable download
    session.rs              In-memory session registry, auto-split logic
    settings.rs              Settings persistence (OS config dir)
    singleton.rs             Single-instance PID lock
    memory.rs                Memory-pressure detection
    error.rs                 Central error type (Trareon TranscribeError)
    bin/gen_fixtures.rs      Synthetic WAV fixtures for hardware-free tests
    bin/transcribe.rs         Main CLI for batch transcription
    bin/transcribe_cli.rs     Compatibility alias for the CLI

test/                       Flutter widget/unit tests
scripts/                    Build, package, and benchmark scripts
.github/workflows/          CI and release workflows
```

---

## CI Gates

The CI pipeline (`.github/workflows/ci.yml`) runs on every PR and push to `main`:

| Job | What it checks |
|-----|---------------|
| `rust` | `cargo fmt --check`, `cargo clippy -- -D warnings`, `cargo test --all-features`, `cargo audit --deny warnings`, `cargo deny check` |
| `flutter` | `flutter analyze`, `flutter test` |
| `rust-build` | Cross-platform Rust build (Linux, macOS, Windows) |
| `flutter-build` | Cross-platform Flutter build (Linux, macOS, Windows) |
| `macos-packaging-smoke-test` | macOS DMG build + ad-hoc sign (push only) |
| `benchmark` | Performance benchmarks for STT latency, export time, VAD processing |

Tagged pushes (`v*`) also trigger `.github/workflows/release.yml` for binary distribution.

---

## Security-Sensitive Changes

If your change touches any of the following areas, please review [`SECURITY.md`](SECURITY.md) carefully:

- **Networking**: No new code path may make a network call during transcription (models download is the only legitimate network activity).
- **File I/O**: Path traversal risks in export paths, model file paths, and session storage files.
- **Dependencies**: Any new dependency must clear `cargo deny check` (license + advisory) before merge.
- **Unsafe code**: Every `unsafe` block must include an inline justification comment.

Report security vulnerabilities privately via [GitHub Security Advisory](https://github.com/Trareon-com/Transcribe/security/advisories/new) — do not open a public issue.

---

## Testing Philosophy

- **Pure logic must be unit-tested** — VAD decisions, export formatting, session state machine, auto-split thresholds, sanitization, etc. These run in CI and require no real hardware or network.
- **Hardware-dependent code** (live audio capture threads, device enumeration results) is exercised via **manual smoke tests**, not CI assertions, since CI runners may have zero audio devices.
- Use `gen_fixtures.rs` to generate synthetic WAV files for decode/VAD tests instead of requiring a real microphone.
- **Widget tests** should prefer `RustBridgeMock` over the real `RustEngineBridge` for deterministic behavior.

## Getting Help

- Open a [Discussion](https://github.com/Trareon-com/Transcribe/discussions) for questions or ideas
- Check [`ARCHITECTURE.md`](ARCHITECTURE.md) for the codebase layout and data flow
- Check [`SECURITY.md`](SECURITY.md) for the security and privacy posture
- Check [`CHANGELOG.md`](CHANGELOG.md) for recent changes and known gaps

---

*Thank you for helping make Trareon Transcribe better! 🎤*
