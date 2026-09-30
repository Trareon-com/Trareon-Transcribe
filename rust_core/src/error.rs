use thiserror::Error;

/// Single error type for the entire public API surface.
/// No `unwrap`/`expect`/`panic!` in library code — every fallible
/// operation must resolve to one of these variants.
#[derive(Debug, Error)]
pub enum TranscribeError {
    #[error("audio device error: {0}")]
    AudioDevice(String),

    #[error("audio decode error: {0}")]
    AudioDecode(String),

    #[error("model error: {0}")]
    Model(String),

    #[error("transcription error: {0}")]
    Transcription(String),

    #[error("export error: {0}")]
    Export(String),

    /// String, not `std::io::Error` — the latter has no FRB `SseEncode`
    /// impl, which broke bridge codegen. Construct via
    /// `TranscribeError::from(io_err)` or `.map_err(TranscribeError::from)`.
    #[error("io error: {0}")]
    Io(String),

    #[error("invalid input: {0}")]
    InvalidInput(String),

    #[error("session not found: {0}")]
    SessionNotFound(String),

    /// AI summary generation failed (endpoint unreachable, auth rejected,
    /// unexpected response shape). Separate from `Transcription` so the UI
    /// can say "summary failed, your transcript is safe" — summaries are the
    /// one opt-in networked feature and must never look like data loss.
    #[error("summary error: {0}")]
    Summary(String),
}

impl From<std::io::Error> for TranscribeError {
    fn from(e: std::io::Error) -> Self {
        TranscribeError::Io(e.to_string())
    }
}

/// Internal-only convenience alias. FRB-exposed signatures (anything in a
/// module listed in the codegen `--rust-input`) must spell out
/// `Result<T, TranscribeError>` explicitly — the codegen doesn't resolve
/// this alias when scanning multiple modules.
pub type TranscribeResult<T> = Result<T, TranscribeError>;
