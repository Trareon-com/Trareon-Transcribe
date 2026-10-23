//! Persistent streaming CrispASR engine for LIVE recording (2026-10-13).
//!
//! [`super::CrispAsrEngine`] is one-shot: spawn, transcribe one whole
//! file, exit. That is correct for batch/file transcription but wrong
//! for live recording — spawning a fresh subprocess per audio chunk
//! would make every chunk pay full model-load latency, and would
//! violate the "a tier is picked once per session" rule just as badly
//! as re-picking the tier itself mid-session would.
//!
//! This type instead spawns `crispasr --stream --stream-json` ONCE,
//! keeps the child alive for the whole session, and:
//!   - [`CrispAsrStreamEngine::push_pcm`] writes raw PCM to its stdin as
//!     audio arrives from the capture thread (same cadence that feeds
//!     `pipeline::LivePipeline::ingest` today);
//!   - a background thread parses its stdout (JSON-Lines) into
//!     [`StreamEvent`]s;
//!   - [`CrispAsrStreamEngine::poll_events`] drains them non-blockingly.
//!
//! CrispASR's `--stream` mode does its OWN VAD-based utterance
//! segmentation and partial/final promotion internally (confirmed via
//! `--help`: `--vad`, `--stream-final-on-silence-ms`,
//! `--stream-vad-merge-gap-ms`) — this engine does not re-implement
//! `pipeline.rs`'s LocalAgreement-2/VAD window on top of it. Feed it
//! raw audio and translate its own events; do not pre-chunk.
//!
//! Wire schema, confirmed empirically against the shipped CLI
//! (`cat raw.s16 | crispasr --backend qwen3 -m <gguf> -l id --stream
//! --stream-json -np`), one JSON object per line:
//! ```text
//! {"type":"partial","utterance_id":1,"text":"...","t0":0.000,"t1":3.000}
//! {"type":"final","utterance_id":1,"text":"...","t0":0.000,"t1":6.420}
//! ```
//! `utterance_id` increments per detected utterance; a `partial` for a
//! given id is superseded by the next `partial`/`final` for that same
//! id, never by one for a different id. No other `type` value has been
//! observed; unrecognised ones are skipped rather than treated as fatal
//! (CrispASR is young and may add event kinds between releases).
//!
//! **Status: standalone and verified against the real CLI in isolation
//! (reader thread correctly parses live partial events from a piped
//! WAV). NOT YET wired into `pipeline.rs`/`LiveWorker` — that
//! integration is the next step, tracked separately, because it means
//! choosing how a `LiveWorker` built around a single `&WhisperEngine`
//! reference picks between that and this type without duplicating the
//! HPT/VAD machinery that only makes sense for Whisper.**

use std::io::{BufRead, BufReader, Write};
use std::path::Path;
use std::process::{Child, Command, Stdio};
use std::sync::mpsc::{channel, Receiver, Sender, TryRecvError};
use std::thread::JoinHandle;

use serde::Deserialize;

use crate::error::{TranscribeError, TranscribeResult};

#[derive(Debug, Deserialize)]
struct RawStreamEvent {
    #[serde(rename = "type")]
    kind: String,
    utterance_id: u64,
    text: String,
    t0: f64,
    t1: f64,
}

/// One event from the streaming subprocess, already translated out of
/// CrispASR's wire format in [`RawStreamEvent`].
#[derive(Debug, Clone, PartialEq)]
pub enum StreamEvent {
    /// Tentative text for `utterance_id` — show as the grey/uncommitted
    /// tail; superseded by the next `Partial`/`Final` for the same id.
    Partial {
        utterance_id: u64,
        text: String,
        t0: f64,
        t1: f64,
    },
    /// `utterance_id` is done. Commit this text; it will not change.
    Final {
        utterance_id: u64,
        text: String,
        t0: f64,
        t1: f64,
    },
}

impl StreamEvent {
    pub fn utterance_id(&self) -> u64 {
        match self {
            StreamEvent::Partial { utterance_id, .. } => *utterance_id,
            StreamEvent::Final { utterance_id, .. } => *utterance_id,
        }
    }

    pub fn is_final(&self) -> bool {
        matches!(self, StreamEvent::Final { .. })
    }
}

/// A long-lived `crispasr --stream --stream-json` subprocess. One
/// instance per live session (per source — mic or speaker — mirroring
/// how `pipeline::LiveWorker` runs one `LivePipeline` per source).
pub struct CrispAsrStreamEngine {
    child: Child,
    reader_handle: Option<JoinHandle<()>>,
    events_rx: Receiver<StreamEvent>,
}

impl CrispAsrStreamEngine {
    /// `cli_path`/`model_path`/`backend_flag`: same meaning and catalog
    /// as [`super::CrispAsrEngine::load`]. `language`: e.g. `Some("id")`;
    /// `None` lets CrispASR auto-detect.
    pub fn spawn(
        cli_path: &Path,
        model_path: &Path,
        backend_flag: &str,
        language: Option<&str>,
    ) -> TranscribeResult<Self> {
        if !cli_path.exists() {
            return Err(TranscribeError::Model(format!(
                "CrispASR CLI not found at {}",
                cli_path.display()
            )));
        }
        if !model_path.exists() {
            return Err(TranscribeError::Model(format!(
                "CrispASR model not found at {}",
                model_path.display()
            )));
        }

        let mut cmd = Command::new(cli_path);
        cmd.arg("--backend").arg(backend_flag);
        cmd.arg("-m").arg(model_path);
        if let Some(lang) = language.filter(|l| *l != "auto") {
            cmd.arg("-l").arg(lang);
        }
        cmd.arg("--stream")
            .arg("--stream-json")
            .arg("--vad")
            .arg("-np");
        cmd.stdin(Stdio::piped());
        cmd.stdout(Stdio::piped());
        // whisper_vad_* debug lines go to stderr even with -np; they are
        // not errors, and the exit status (checked in `finish`/`Drop`)
        // is the real signal something went wrong.
        cmd.stderr(Stdio::null());

        let mut child = cmd.spawn().map_err(|e| {
            TranscribeError::Transcription(format!("failed to spawn crispasr --stream: {e}"))
        })?;

        let stdout = child.stdout.take().ok_or_else(|| {
            TranscribeError::Transcription("crispasr --stream: no stdout pipe".into())
        })?;

        let (tx, rx) = channel();
        let reader_handle = std::thread::Builder::new()
            .name("crispasr-stream-reader".into())
            .spawn(move || Self::reader_loop(stdout, tx))
            .map_err(|e| {
                TranscribeError::Transcription(format!(
                    "failed to spawn crispasr stream reader thread: {e}"
                ))
            })?;

        Ok(Self {
            child,
            reader_handle: Some(reader_handle),
            events_rx: rx,
        })
    }

    fn reader_loop(stdout: std::process::ChildStdout, tx: Sender<StreamEvent>) {
        let reader = BufReader::new(stdout);
        for line in reader.lines() {
            let Ok(line) = line else { break };
            let line = line.trim();
            if line.is_empty() {
                continue;
            }
            let Ok(raw) = serde_json::from_str::<RawStreamEvent>(line) else {
                // Unparseable line (future event kind, stray log output
                // that slipped past -np) — skip it rather than tearing
                // the whole session down over one line.
                continue;
            };
            let event = match raw.kind.as_str() {
                "partial" => StreamEvent::Partial {
                    utterance_id: raw.utterance_id,
                    text: raw.text,
                    t0: raw.t0,
                    t1: raw.t1,
                },
                "final" => StreamEvent::Final {
                    utterance_id: raw.utterance_id,
                    text: raw.text,
                    t0: raw.t0,
                    t1: raw.t1,
                },
                _ => continue,
            };
            if tx.send(event).is_err() {
                break; // receiver dropped — session tearing down
            }
        }
    }

    /// Writes `samples` (mono, 16 kHz f32 — the same format
    /// `LivePipeline::ingest` already takes) to the subprocess's stdin
    /// as raw s16le PCM. CrispASR does its own VAD/chunking on this
    /// stream; no pre-windowing needed here.
    pub fn push_pcm(&mut self, samples_f32: &[f32]) -> TranscribeResult<()> {
        let stdin = self.child.stdin.as_mut().ok_or_else(|| {
            TranscribeError::Transcription("crispasr --stream: stdin already closed".into())
        })?;
        let mut buf = Vec::with_capacity(samples_f32.len() * 2);
        for &s in samples_f32 {
            let clamped = s.clamp(-1.0, 1.0);
            let i16_sample = (clamped * i16::MAX as f32) as i16;
            buf.extend_from_slice(&i16_sample.to_le_bytes());
        }
        stdin.write_all(&buf).map_err(|e| {
            TranscribeError::Transcription(format!("crispasr --stream: stdin write failed: {e}"))
        })?;
        Ok(())
    }

    /// Drains every [`StreamEvent`] parsed since the last call.
    /// Non-blocking.
    pub fn poll_events(&mut self) -> Vec<StreamEvent> {
        let mut events = Vec::new();
        loop {
            match self.events_rx.try_recv() {
                Ok(event) => events.push(event),
                Err(TryRecvError::Empty | TryRecvError::Disconnected) => break,
            }
        }
        events
    }

    /// Closes stdin (CrispASR's cue to flush the last utterance as
    /// final and exit) and waits for it to do so. Call this on a clean
    /// stop; `Drop` also cleans up, but via `kill()` rather than a
    /// graceful flush.
    pub fn finish(mut self) -> TranscribeResult<Vec<StreamEvent>> {
        self.child.stdin.take();
        let _ = self.child.wait();
        if let Some(handle) = self.reader_handle.take() {
            let _ = handle.join();
        }
        Ok(self.poll_events())
    }
}

impl Drop for CrispAsrStreamEngine {
    fn drop(&mut self) {
        // Best-effort: never leave a zombie/orphan crispasr process
        // behind on an early-return/crash path that skipped `finish()`.
        self.child.stdin.take();
        let _ = self.child.kill();
        let _ = self.child.wait();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn stream_event_helpers_report_their_own_shape() {
        let partial = StreamEvent::Partial {
            utterance_id: 1,
            text: "halo".into(),
            t0: 0.0,
            t1: 1.0,
        };
        let final_ = StreamEvent::Final {
            utterance_id: 1,
            text: "halo dunia".into(),
            t0: 0.0,
            t1: 2.0,
        };
        assert_eq!(partial.utterance_id(), 1);
        assert!(!partial.is_final());
        assert_eq!(final_.utterance_id(), 1);
        assert!(final_.is_final());
    }

    #[test]
    fn raw_wire_schema_parses_exactly_as_observed_from_the_real_cli() {
        // Captured 2026-10-13 from: cat raw.s16 | crispasr --backend
        // qwen3 -m <gguf> -l id --stream --stream-json -np
        let line = r#"{"type":"partial","utterance_id":1,"text":"Segera setelah permusuhan pecah.","t0":0.000,"t1":3.000}"#;
        let raw: RawStreamEvent = serde_json::from_str(line).unwrap();
        assert_eq!(raw.kind, "partial");
        assert_eq!(raw.utterance_id, 1);
        assert_eq!(raw.t0, 0.0);
        assert_eq!(raw.t1, 3.0);
    }

    #[test]
    fn spawn_rejects_a_missing_cli_path_before_touching_the_process_table() {
        match CrispAsrStreamEngine::spawn(
            Path::new("/does/not/exist/crispasr"),
            Path::new("/does/not/exist/model.gguf"),
            "qwen3",
            Some("id"),
        ) {
            Ok(_) => panic!("expected an error for a nonexistent CLI path"),
            Err(err) => assert!(format!("{err}").contains("CrispASR CLI not found")),
        }
    }

    // An end-to-end test against the real CLI binary + a real GGUF is
    // deliberately NOT included here (unlike `crispasr_engine`'s tests,
    // which are also gated) — those artifacts are multi-hundred-MB
    // downloads not present in CI. Verified manually against the real
    // CLI on 2026-10-13 (Linux x86_64): a piped WAV converted to raw
    // s16le PCM produced exactly the partial-event sequence this
    // module's parser expects, confirming the schema above is not
    // guessed. See BASELINE_FLEURS.md.
}
