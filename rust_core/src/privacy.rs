//! Privacy proof — compile-time assurance that the transcribe audio path
//! makes zero network calls. Scans source files for known network patterns.
//!
//! The crate has exactly two modules that are allowed to open a socket:
//!
//! * `model.rs`   — downloading a Whisper model, SHA256-pinned, user-initiated.
//! * `summary.rs` — the opt-in AI summary, user-initiated per request,
//!   defaulting to a loopback endpoint.
//!
//! Everything else — capture, VAD, decode, inference, diarization, session
//! bookkeeping, export — must stay offline, and the tests below fail the
//! build if that ever stops being true.

#[cfg(test)]
mod tests {
    use std::path::PathBuf;

    fn manifest_dir() -> PathBuf {
        std::env::var("CARGO_MANIFEST_DIR")
            .map(PathBuf::from)
            .unwrap_or_else(|_| PathBuf::from("."))
    }

    /// Every module that touches user audio, from capture to on-disk export.
    const TRANSCRIBE_HOT_PATH: &[&str] = &[
        "stt/mod.rs",
        "stt/file.rs",
        "stt/whisper_cd.rs",
        "progressive.rs",
        "pipeline.rs",
        "decode/mod.rs",
        "preprocess.rs",
        "vad/mod.rs",
        "vad/silero.rs",
        "diarization.rs",
        "dedupe/mod.rs",
        "glossary.rs",
        "session.rs",
        "export/mod.rs",
        "audio/capture.rs",
        "audio/loopback.rs",
        "audio/ring_buffer.rs",
    ];

    fn read_hot_path_sources() -> Vec<(String, String)> {
        let base = manifest_dir().join("src");
        TRANSCRIBE_HOT_PATH
            .iter()
            .filter_map(|relative| {
                let path = base.join(relative);
                // Some files are platform-specific and may be absent.
                let content = std::fs::read_to_string(&path).ok()?;
                Some((relative.to_string(), content))
            })
            .collect()
    }

    #[test]
    fn transcribe_path_no_network_calls() {
        // Patterns that would indicate network I/O in the hot transcribe path.
        // `download_with_resume` is allowed in model.rs (download phase) but
        // must NOT appear in the real-time transcribe modules above.
        let forbidden = [
            "reqwest::get",
            "reqwest::Client",
            "download_with_resume",
            "http://",
            "https://",
            "reqwest::",
            "tokio::net",
        ];

        let sources = read_hot_path_sources();
        assert!(
            !sources.is_empty(),
            "hot-path scan found no sources — the file list is stale"
        );
        for (name, content) in sources {
            for pattern in &forbidden {
                assert!(
                    !content.contains(pattern),
                    "{name} contains forbidden network pattern '{pattern}'"
                );
            }
        }
    }

    /// The AI summary is the one networked feature. Keeping it out of the hot
    /// path is what makes "network only for summaries, only on demand"
    /// checkable rather than a claim in a README: if any capture/inference
    /// module ever reaches for it, this fails.
    #[test]
    fn transcribe_path_cannot_reach_the_summary_module() {
        // `export` is excluded: it *receives* an already-generated summary as
        // a plain `&str` parameter and writes it into the Markdown/DOCX
        // output. That is the documented data flow, and the HTTP scan above
        // still covers it — what must never happen is export *fetching* one.
        let exempt = ["export/mod.rs"];
        let forbidden = ["crate::summary", "use super::summary", "generate_summary"];
        for (name, content) in read_hot_path_sources() {
            if exempt.contains(&name.as_str()) {
                continue;
            }
            for pattern in &forbidden {
                assert!(
                    !content.contains(pattern),
                    "{name} references the networked summary module via '{pattern}' — \
                     summaries must never run inside the transcription path"
                );
            }
        }
    }

    /// Enumerates every module performing HTTP, so adding a third one is a
    /// deliberate, reviewed act rather than an accident.
    #[test]
    fn only_model_download_and_summary_may_use_http() {
        let src = manifest_dir().join("src");
        let allowed = ["model.rs", "summary.rs"];
        let mut offenders = Vec::new();

        let mut stack = vec![src.clone()];
        while let Some(dir) = stack.pop() {
            let Ok(entries) = std::fs::read_dir(&dir) else {
                continue;
            };
            for entry in entries.flatten() {
                let path = entry.path();
                if path.is_dir() {
                    stack.push(path);
                    continue;
                }
                if path.extension().and_then(|e| e.to_str()) != Some("rs") {
                    continue;
                }
                let relative = path
                    .strip_prefix(&src)
                    .unwrap_or(&path)
                    .to_string_lossy()
                    .replace('\\', "/");
                // Generated bridge glue mirrors whatever api.rs exposes.
                if relative == "frb_generated.rs" || relative == "privacy.rs" {
                    continue;
                }
                let Ok(content) = std::fs::read_to_string(&path) else {
                    continue;
                };
                if content.contains("reqwest::Client") && !allowed.contains(&relative.as_str()) {
                    offenders.push(relative);
                }
            }
        }

        assert!(
            offenders.is_empty(),
            "unexpected HTTP client outside {allowed:?}: {offenders:?}"
        );
    }

    /// The shipped default must not reach the public internet.
    #[test]
    fn summary_defaults_to_a_loopback_endpoint_and_is_disabled() {
        let settings = crate::settings::AppSettings::default();
        assert!(
            !settings.summary.enabled,
            "summaries must be opt-in, not on by default"
        );
        assert!(
            settings.summary.base_url.contains("localhost")
                || settings.summary.base_url.contains("127.0.0.1"),
            "default summary endpoint must be loopback, got {}",
            settings.summary.base_url
        );
    }
}
