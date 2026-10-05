//! Trareon Transcribe engine.

// Both `ort` and `sherpa-onnx-sys` statically link their own copy of ONNX
// Runtime. Enabling both produces several hundred duplicate-symbol errors
// from the linker, hundreds of lines after the point where anyone stops
// reading. Say it once, at the top, in words.
#[cfg(all(feature = "silero-onnx", feature = "neural-diarization"))]
compile_error!(
    "features `silero-onnx` and `neural-diarization` cannot be enabled \
     together: `ort` and `sherpa-onnx-sys` each statically link their own \
     ONNX Runtime, and the two sets of symbols collide at link time. Use \
     whisper.cpp's built-in Silero VAD (vad::whisper_silero, no feature \
     required) alongside `neural-diarization`."
);

/// Structured action items (tugas / PJ / tenggat / status) with .ics
/// and CSV export.
pub mod actions;
pub mod api;
/// Local full-text index over every session ("Tanya arsip rapat").
pub mod archive;
/// Synthetic 5 000-segment / 3-hour meeting used by the performance tests.
#[cfg(test)]
pub mod bench_fixture;
pub mod benchmark;
pub mod capabilities;
pub mod confidence;
pub mod doctor;
pub mod error;
mod frb_generated;

pub mod audio;
/// Post-stop transcript completion: re-transcribes the stretches the live
/// worker never reached, from the saved WAV.
pub mod completion;
/// Which seconds of a recording the transcript actually accounts for.
pub mod coverage;
pub mod decode;
pub mod dedupe;
pub mod denoise;
pub mod diarization;
/// Free-space checks for the library volume.
pub mod disk;
pub mod export;
pub mod flight_recorder;
/// Kamus istilah: Whisper `initial_prompt` biasing + conservative
/// post-correction. Part of the transcription hot path.
pub mod glossary;
/// Rejects the captions Whisper invents over silence.
pub mod hallucination;
/// Continuous transcript journal (crash recovery). Driven from `session`,
/// never from Dart.
pub mod journal;
/// Long-meeting summarisation: time windows → partial notes → one
/// document.
pub mod mapreduce;
pub mod memory;
pub mod model;
/// Mesin notulen: templat naskah dinas, skema JSON ketat, periksa fakta,
/// dan pemeriksa ragam bahasa baku. Local-only — the model round trip
/// itself belongs to `summary`.
pub mod notulen;
/// Mode Kepatuhan UU PDP: redaction, retention, audit log, consent.
pub mod pdp;
pub mod pipeline;
pub mod preprocess;
pub mod privacy;
pub mod progressive;
/// Summary citations back into the transcript.
pub mod provenance;
pub mod session;
pub mod settings;
pub mod singleton;
/// Metadata sidecar for registering a notulen in SRIKANDI by hand.
/// Local-only: there is no SRIKANDI API to call.
pub mod srikandi;
/// LocalAgreement-2: which words of a live hypothesis are safe to show as
/// final. Pure policy; the engine side is in `pipeline`.
pub mod streaming;
pub mod stt;
pub mod summary;
pub mod vad;
pub mod watchdog;
pub mod wer;
