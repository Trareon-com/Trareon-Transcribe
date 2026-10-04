pub mod api;
/// Synthetic 5 000-segment / 3-hour meeting used by the performance tests.
#[cfg(test)]
pub mod bench_fixture;
pub mod benchmark;
pub mod confidence;
pub mod doctor;
pub mod error;
mod frb_generated;

pub mod audio;
pub mod decode;
pub mod dedupe;
pub mod diarization;
/// Free-space checks for the library volume.
pub mod disk;
pub mod export;
pub mod flight_recorder;
/// Kamus istilah: Whisper `initial_prompt` biasing + conservative
/// post-correction. Part of the transcription hot path.
pub mod glossary;
/// Continuous transcript journal (crash recovery). Driven from `session`,
/// never from Dart.
pub mod journal;
pub mod memory;
pub mod model;
pub mod pipeline;
pub mod preprocess;
pub mod privacy;
pub mod progressive;
pub mod session;
pub mod settings;
pub mod singleton;
pub mod stt;
pub mod summary;
pub mod vad;
pub mod watchdog;
