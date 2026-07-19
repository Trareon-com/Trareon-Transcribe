# Security Policy

## Reporting a vulnerability

Email security concerns to the Trareon maintainers via GitHub Security Advisories on this repository.
Please do **not** open a public issue for sensitive reports.

## Privacy guarantees

- Audio and transcripts stay on the local device during normal operation.
- Network access is only used during setup (dependency/model downloads) or when the user explicitly enables optional features that require it (e.g. first-time Hugging Face model fetch for pyannote).
- There is no telemetry or analytics.

## Secrets

- Hugging Face tokens are stored in the OS keyring, never in `config.json`.
- Do not commit tokens, `.env` files, or model credentials.

## Supported versions

Security fixes target the latest `main` release branch.
