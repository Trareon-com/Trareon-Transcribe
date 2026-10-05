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
        "completion.rs",
        "coverage.rs",
        "hallucination.rs",
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

    /// Features the app describes as local must be local.
    ///
    /// Each of these was added as a *local* capability and each has an
    /// obvious cloud version someone could reach for later: an archive
    /// index that calls an embedding API, a compliance log that ships to
    /// a server, a WER benchmark that uploads its audio. The Privacy
    /// Report tells the user none of that happens, so the claim is
    /// checked here rather than maintained by memory.
    ///
    /// `archive` is the interesting one: the "Tanya arsip rapat" answer
    /// *is* networked, deliberately. It reaches the network by handing a
    /// prompt to `summary::ask` — the one place in the crate that owns an
    /// HTTP client — and this test is what keeps it that way.
    #[test]
    fn local_only_features_stay_local() {
        let base = manifest_dir().join("src");
        let local_only = [
            "archive.rs",
            "pdp/mod.rs",
            "pdp/audit.rs",
            "pdp/redaction.rs",
            "pdp/retention.rs",
            "actions.rs",
            "provenance.rs",
            "mapreduce.rs",
            "coverage.rs",
            "completion.rs",
            "hallucination.rs",
            // The setup step's thresholds, catalogue, install text and
            // pull-progress parser. The socket it describes belongs to
            // `summary.rs`; if an HTTP call ever moves in here, this
            // fails.
            "llm_setup.rs",
            "notulen/mod.rs",
            "notulen/schema.rs",
            "notulen/factcheck.rs",
            "notulen/register.rs",
            "notulen/prompt.rs",
            "notulen/angka.rs",
            "srikandi.rs",
        ];
        let forbidden = [
            "reqwest",
            "http://",
            "https://",
            "tokio::net",
            "download_with_resume",
        ];
        // `llow_setup.rs` is exempt from the *URL-literal* half of the
        // scan only, and `the_setup_module_names_urls_only_as_instructions`
        // below is what makes that exemption safe. It is the one
        // local-only module that legitimately holds URLs: it tells the
        // user where to download Ollama, which is display text and not a
        // request. The request primitives are still forbidden here.
        const URL_EXEMPT: &[&str] = &["llm_setup.rs"];
        for relative in local_only {
            let path = base.join(relative);
            let content = std::fs::read_to_string(&path)
                .unwrap_or_else(|e| panic!("{relative} must exist for this scan: {e}"));
            for pattern in &forbidden {
                if URL_EXEMPT.contains(&relative) && pattern.starts_with("http") {
                    continue;
                }
                assert!(
                    !content.contains(pattern),
                    "{relative} contains '{pattern}' — it is documented as a \
                     local-only feature"
                );
            }
        }
    }

    /// The setup module may name a URL, and only this kind of URL.
    ///
    /// It exists to tell a user who has never heard of Ollama where to
    /// get it, so forbidding the string outright would mean the
    /// instructions live somewhere worse. What must stay true is that
    /// every URL in it points at Ollama's own download page — a URL
    /// pointing anywhere else would be either a hardcoded endpoint or an
    /// instruction to install something the app did not vet.
    #[test]
    fn the_setup_module_names_urls_only_as_instructions() {
        let content = std::fs::read_to_string(manifest_dir().join("src/llm_setup.rs"))
            .expect("llm_setup.rs must exist");
        for pattern in ["reqwest", "tokio::net", "TcpStream", "download_with_resume"] {
            assert!(
                !content.contains(pattern),
                "llm_setup.rs contains '{pattern}' — the socket belongs to summary.rs"
            );
        }

        let mut urls = 0usize;
        let mut rest = content.as_str();
        while let Some(at) = rest.find("http") {
            rest = &rest[at..];
            let url: String = rest
                .chars()
                .take_while(|c| !c.is_whitespace() && *c != '"' && *c != '`')
                .collect();
            // Ollama's download page, or a loopback address quoted in
            // prose. Both are safe for the reason this gate exists:
            // neither can carry a transcript off the machine, and the
            // loopback default itself is owned by `summary.rs`.
            assert!(
                url.starts_with("https://ollama.com")
                    || url.starts_with("http://localhost")
                    || url.starts_with("http://127.0.0.1"),
                "llm_setup.rs names {url:?}, which is neither Ollama's download \
                 page nor a loopback address"
            );
            urls += 1;
            rest = &rest[url.len()..];
        }
        assert!(urls >= 2, "the install guidance lost its download links");
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

    /// The capability table the user reads and this gate must agree.
    ///
    /// This is what makes `crate::capabilities` a source of truth rather
    /// than a second place to keep the same claim. A row saying "Lokal"
    /// whose module contains a network primitive fails here, and so does
    /// a row claiming to use the network from a module that is not one of
    /// the two allowed to.
    #[test]
    fn the_capability_table_matches_what_the_source_actually_does() {
        use crate::capabilities::{capabilities, RunsAt, NETWORKED_MODULES};

        let base = manifest_dir().join("src");
        let forbidden = [
            "reqwest::get",
            "reqwest::Client",
            "download_with_resume",
            "TcpStream",
            "tokio::net",
        ];

        for capability in capabilities(&crate::settings::AppSettings::default()) {
            let path = base.join(&capability.module);
            let content = std::fs::read_to_string(&path).unwrap_or_else(|e| {
                panic!(
                    "capability '{}' names {} which cannot be read: {e}",
                    capability.id, capability.module
                )
            });

            match capability.runs_at {
                RunsAt::Local => {
                    for pattern in &forbidden {
                        assert!(
                            !content.contains(pattern),
                            "capability '{}' is advertised as local, but {} \
                             contains '{pattern}'",
                            capability.id,
                            capability.module
                        );
                    }
                }
                RunsAt::SummaryEndpoint | RunsAt::Internet => {
                    assert!(
                        NETWORKED_MODULES.contains(&capability.module.as_str()),
                        "capability '{}' is advertised as networked from {}, \
                         which is not one of the modules allowed to open a \
                         socket ({NETWORKED_MODULES:?})",
                        capability.id,
                        capability.module
                    );
                }
            }
        }

        // And the allow-list the table shares with the HTTP scan above is
        // the same list, not a copy that drifted.
        assert_eq!(NETWORKED_MODULES, &["model.rs", "summary.rs"]);
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
