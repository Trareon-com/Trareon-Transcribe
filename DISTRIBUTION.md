# Distribution — Trareon Transcribe

## Pricing & Channel

- **License**: MIT (source) + binary for $5 via Lynk.ID
- **Primary channel**: [Lynk.ID](https://lynk.id) — Indonesian payment gateway
- **Backup channel**: [Gumroad](https://gumroad.com) — international coverage
- **Source code**: Public on GitHub (MIT) at `github.com/Trareon-com/Transcribe`

## Binary Builds

Packaging scripts produce ready-to-distribute installers:

| Platform | Script | Output | Bundle details |
|----------|--------|--------|----------------|
| macOS | `scripts/package_macos.sh` | `.dmg` | Ad-hoc signed by default; Developer ID + notarized when `MACOS_SIGN_IDENTITY` is set |
| Windows | `scripts/package_windows.ps1` | `.zip` | Self-signed certificate (v1), whisper `tiny` model bundled |
| Linux | `scripts/package_linux.sh` | `.tar.gz` + `.AppImage` | Models bundled when present in `models/` |
| Linux | `scripts/package_deb.sh` | `.deb` (amd64) | Bundle in `/opt`, wrapper in `/usr/bin`, models **not** bundled |

All scripts:
1. Build Rust engine (`cargo build --release --lib`)
2. Build Flutter for the target platform
3. Generate a SHA256 checksum file
4. Output to `dist/`

Run from the repo root:
```bash
# macOS
bash scripts/package_macos.sh "1.0.0"

# Windows (PowerShell)
.\scripts\package_windows.ps1 -Version "1.0.0"

# Linux — tar.gz + AppImage
bash scripts/package_linux.sh "1.0.0"

# Linux — Debian/Ubuntu package
bash scripts/package_deb.sh "1.0.0"
sudo apt install ./dist/trareon-transcribe_1.0.0_amd64.deb
```

### Why the `.deb` does not bundle models

`ggml-base.bin` is 142 MB and `ggml-large-v3-turbo-q5_0.bin` is 548 MB. A
700 MB package is hostile to Debian mirrors and to anyone on Indonesian home
broadband, and the app already downloads models on first run into
`~/.cache/TrareonTranscribe/models/`. Pass `--with-models` to override for an
offline/air-gapped deployment:

```bash
bash scripts/package_deb.sh "1.0.0" --with-models
```

### AppImage on hosts without FUSE

`appimagetool` mounts its own runtime via FUSE. On a host without `libfuse2`
(including the GitHub Actions runners), export
`APPIMAGE_EXTRACT_AND_RUN=1` before building, and run the resulting AppImage
the same way:

```bash
APPIMAGE_EXTRACT_AND_RUN=1 ./dist/trareon-transcribe-1.0.0-linux-x86_64.AppImage
# or, equivalently
./dist/trareon-transcribe-1.0.0-linux-x86_64.AppImage --appimage-extract-and-run
```

## CI & Release Workflow

Trareon Transcribe's CI pipeline (GitHub Actions) runs on every push and pull request:
- **Rust**: `cargo fmt --check`, `cargo clippy -D warnings`, `cargo test`, `cargo audit`, `cargo deny`
- **Flutter**: `flutter analyze`, `flutter test`, builds for macOS/Windows/Linux  
- **Smoke tests**: macOS DMG and Windows ZIP packaging verified on every push

CI status: [![CI](https://github.com/Trareon-com/Transcribe/actions/workflows/ci.yml/badge.svg)](https://github.com/Trareon-com/Transcribe/actions/workflows/ci.yml)

Pushing a `v*` tag triggers `.github/workflows/release.yml`:
1. Source tarball (GitHub Releases — for transparency)
2. macOS `.dmg` — signed and notarized when the Apple secrets are configured
3. Linux `.tar.gz`, `.AppImage` and `.deb` (the `.deb` is installed and
   removed again on the runner, so a broken `Depends:` line fails the release)
4. Windows `.zip`

Every build job uploads to a workflow artifact rather than straight to the
release. A final `publish` job collects all of them, writes one `SHA256SUMS`
covering every file, verifies it with `sha256sum --check --strict`, and
uploads the artifacts together with the manifest. Verify a download with:

```bash
sha256sum --check --ignore-missing SHA256SUMS
```

### Required secrets for macOS notarization

Notarization steps are **gated on these secrets being present**. A fork, or
this repo before an Apple Developer account exists, still produces a working
ad-hoc signed DMG — a missing secret is a configuration state, not a build
failure.

| Secret | What it is | How to get it |
|--------|-----------|---------------|
| `APPLE_CERTIFICATE_P12_BASE64` | Developer ID Application certificate + private key, exported as `.p12` then `base64` | Xcode → Settings → Accounts → Manage Certificates; export, then `base64 -i cert.p12 \| pbcopy` |
| `APPLE_CERTIFICATE_PASSWORD` | Password set when exporting the `.p12` | Chosen at export time |
| `APPLE_KEYCHAIN_PASSWORD` | Any throwaway string; unlocks the temporary keychain on the runner | Generate one |
| `APPLE_SIGN_IDENTITY` | Identity name, e.g. `Developer ID Application: Trareon (TEAMID123)` | `security find-identity -v -p codesigning` |
| `APPLE_NOTARY_USER` | Apple ID of the Developer account | The account email |
| `APPLE_NOTARY_PASSWORD` | **App-specific** password, not the Apple ID password | appleid.apple.com → Sign-In and Security → App-Specific Passwords |
| `APPLE_TEAM_ID` | 10-character team identifier | developer.apple.com → Membership |

Requires a paid Apple Developer account ($99/yr) — ADR-12 defers this to
post-v1, which is why the gate exists rather than a hard requirement.

## Signing Status (v1)

| Requirement | macOS | Windows | Linux |
|-------------|-------|---------|-------|
| Code signing | ✅ Ad-hoc (`codesign --sign -`) | 🔶 Self-signed (makecert) | N/A |
| Notarization | 🔶 Workflow ready, gated on secrets (requires $99/yr Apple Developer) | N/A | N/A |
| Gatekeeper warning | ⚠️ "Apple cannot verify" until notarized | N/A | N/A |
| SmartScreen warning | N/A | ⚠️ "Unrecognized app" | N/A |
| Checksums | ✅ `SHA256SUMS` | ✅ `SHA256SUMS` | ✅ `SHA256SUMS` |
| User documentation | ✅ Described on download page | ✅ Described on download page | ✅ Described on download page |

**Why ad-hoc / self-signed?** The blueprint ADR-12 defers paid certificates to
post-v1. Users see one warning dialog on first launch; subsequent launches are
silent (macOS Gatekeeper remembers the user's "Open Anyway" choice; Windows
SmartScreen learns after enough reputation).

## Lynk.ID Product Page Checklist

- [ ] Title: "Trareon Transcribe — Offline Meeting Transcriber"
- [ ] Price: $5 (or IDR equivalent)
- [ ] Description mentions:
  - 100% offline, zero network calls during transcription
  - macOS + Windows support
  - **Important**: ad-hoc signing warning for macOS ("Apple cannot verify")
  - **Important**: SmartScreen warning for Windows
  - Whisper model `tiny` bundled (larger models downloaded on-demand)
  - All export formats: Markdown, TXT, JSON, SRT, VTT, HTML, DOCX, WAV
- [ ] Known limitations listed:
  - No notarization (macOS)
  - No auto-update (manual check only in v1)
  - Large model downloads require internet on first use
- [ ] Link to GitHub source (MIT)
- [ ] Link to documentation / user guide

## Manual Release Steps

```bash
# 1. Tag and push
git tag -a v1.0.0 -m "v1.0.0 — initial release"
git push origin v1.0.0

# 2. CI builds automatically (watch Actions tab)

# 3. Download artifacts from CI, verify checksums
sha256sum -c transcribe-*.sha256

# 4. Upload to Lynk.ID + Gumroad

# 5. Create GitHub Release (source only)
# CI creates this automatically via softprops/action-gh-release

# 6. Update CHANGELOG.md if not already done

# 7. Post-release bump: pubspec.yaml version → 1.1.0-dev
```

## Model Bundling

The `tiny` model (~75 MB) is bundled inside each installer so first-run
download is optional. User-chosen larger models (base/small/medium/large-v3-turbo)
are downloaded on-demand via HTTPS with SHA256 verification.

Model cache location: `~/Library/Caches/TrareonTranscribe/models/` (macOS) /
`%LOCALAPPDATA%\TrareonTranscribe\models\` (Windows).

## Update Strategy (v1)

- **No auto-update.** User checks manually via Help → Check for Updates.
- Update checker uses HTTPS HEAD request to a version manifest URL.
- Full auto-update with Ed25519 binary signature is roadmap for v2.

## Hotfix Protocol

1. Branch: `hotfix/v1.0.1` from tag `v1.0.0`
2. Fix, commit, test
3. Tag: `git tag v1.0.1`
4. Target: 24-hour turnaround for critical bugs
