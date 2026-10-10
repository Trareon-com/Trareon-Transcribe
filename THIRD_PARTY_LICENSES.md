# Third-party licenses

This file tracks source repositories Trareon Transcribe's engineering team
*read for patterns, algorithms, and API shapes* while building features in
this codebase (Sprint 13), per the project's "study, don't copy" rule.
Nothing in this app vendors or links against either repository's code —
everything is a from-scratch Rust/Flutter implementation. Where a comment
in the source explicitly says a piece was adapted close to verbatim, that
file carries its own attribution header; none did as of Sprint 13 (see
below).

## Anarlog (Fastrepl, Inc.)

- Repository: `anarlog` (private study clone, not vendored)
- Commit read: `2ca3d9841c6450d97758eeb8a4ec7909f0a95dee` (2026-10-10)
- Copyright: © 2023–present Fastrepl, Inc.
- License: MIT (full text below)
- **Not read**: `anarlog/enterprise/**` — per the project's licensing
  rule, this directory (governed by `LICENSE.enterprise`, a commercial
  license) was never opened.
- What was studied: `crates/vad-masking` (VAD-driven zero-filling of
  non-speech frames) and `crates/aec` (ONNX-based acoustic echo
  cancellation, `CircularBuffer`/block-processing structure) — both under
  the MIT-licensed `crates/` tree.
- Outcome: no code was copied. `crates/vad-masking`'s masking strategy
  (zero-fill non-speech frames in place) was compared against this crate's
  existing `vad::whisper_silero` gate (which already implements
  `min_silence_duration` hangover and `speech_pad` pre/post-roll via
  whisper.cpp's native Silero VAD) and found to offer no measurable
  improvement for this app's architecture — see Sprint 13 report, item C1.
  `crates/aec` was surveyed for architecture only (see Sprint 13 report,
  items B1–B4, marked NOT DONE: model acquisition and licensing
  verification for the ONNX weights were out of scope for this sprint).

## Meetily (Zackriya Solutions)

- Repository: `meetily` (private study clone, not vendored)
- Commit read: `a2cb62e827da7ef59f65064c97233efb2313878e` (2026-09-10)
- Copyright: © 2024 Zackriya Solutions
- License: MIT (full text below)
- What was studied: `frontend/src-tauri/src/audio_v2/{mixer,limiter,
  normalizer}.rs`.
- Outcome: no code was copied — and none of it could be, as of the
  commit read, `limiter.rs` and `normalizer.rs` are unimplemented `TODO`
  placeholders (`limiter.rs`'s `process()` does a bare hard clamp;
  `normalizer.rs`'s EBU R128 normalizer has no analyzer wired in). This
  codebase's own soft-knee limiter (`rust_core/src/agc.rs::soft_limit`,
  Sprint 13 A1) is independent, standard-DSP work, not an adaptation of
  Meetily's stub. `mixer.rs`'s `DuckingProcessor`/`CrossfadeProcessor`
  shapes were read as a reference for what "mixing mic + system audio"
  could look like, but this app's pipeline keeps mic and system-audio
  tracks separate all the way through transcription (see
  `rust_core/src/session.rs`'s `mic.wav`/`speaker.wav` convention) — there
  is no mixed signal anywhere for a mixer/ducker/normalizer to act on, so
  adopting that module would have meant building a new, unused signal
  path. See Sprint 13 report, items A2/A3 (NOT DONE, with this reasoning).

## MIT License text (applies to both repositories above, per their own copyright lines)

```
MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Model weights

No ONNX model weights were downloaded or distributed as part of Sprint 13
(the AEC item that would have needed one, B1–B4, was not implemented — see
the Sprint 13 report). This section is a placeholder for when that work
resumes: any downloaded model's own license must be checked at its source
and recorded here before it is wired into the model catalog, and the
weights themselves must never be committed to this repository.
