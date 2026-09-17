//! Whisper model catalog + download with resume + SHA256 verification.
//! MITM/tamper mitigation per STRIDE threat model: every known model's
//! SHA256 is pinned in [`KNOWN_MODELS`], not trusted from the server.

use std::io::Write;
use std::path::{Path, PathBuf};
use std::sync::Mutex;

use futures_util::StreamExt;
use serde::Serialize;

use crate::error::TranscribeError;

#[derive(Debug, Clone, Serialize)]
pub struct ModelInfo {
    pub id: String,
    pub name: String,
    pub url: String,
    pub sha256: String,
    pub size_bytes: u64,
    pub min_ram_gb: u32,
    pub is_bundled: bool,
}

/// Pinned catalog. URLs point at the ggerganov/whisper.cpp HF mirror.
/// `sha256` empty means "not yet pinned" — `verify_checksum` hard-fails
/// on an empty expected hash rather than silently trusting the download
/// (STRIDE §86.1), so an empty entry here blocks that model's download
/// until someone fills in the real hash, by design.
///
/// `tiny`'s hash below was captured directly from a manual download of
/// https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin
/// (`shasum -a 256`) during a live end-to-end smoke test; the rest are
/// still unpinned pending the same verification.
pub const KNOWN_MODELS: &[(&str, &str, u32, bool, &str)] = &[
    (
        "tiny",
        "ggml-tiny.bin",
        1,
        true,
        "be07e048e1e599ad46341c8d2a135645097a538221678b7acdd1b1919c6e1b21",
    ),
    (
        "base",
        "ggml-base.bin",
        1,
        true,
        "60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe",
    ),
    (
        "small",
        "ggml-small.bin",
        2,
        false,
        "1be3a9b2063867b937e64e2ec7483364a79917e157fa98c5d94b5c1fffea987b",
    ),
    (
        "medium",
        "ggml-medium.bin",
        4,
        false,
        "6c14d5adee5f86394037b4e4e8b59f1673b6cee10e3cf0b11bbdbee79c156208",
    ),
    (
        "large-v3-turbo",
        "ggml-large-v3-turbo.bin",
        6,
        false,
        "1fc70f774d38eb169993ac391eea357ef47c88757ef72ee5943879b7e8e2bc69",
    ),
    (
        "large-v3-turbo-q5",
        "ggml-large-v3-turbo-q5_0.bin",
        4,
        true,
        "394221709cd5ad1f40c46e6031ca61bce88931e6e088c188294c6d5a55ffa7e2",
    ),
];

#[flutter_rust_bridge::frb(ignore)]
pub fn list_available_models(models_dir: &Path) -> Vec<ModelInfo> {
    KNOWN_MODELS
        .iter()
        .map(|(id, filename, min_ram_gb, is_bundled, sha256)| {
            let path = models_dir.join(filename);
            let size_bytes = std::fs::metadata(&path).map(|m| m.len()).unwrap_or(0);
            ModelInfo {
                id: id.to_string(),
                name: format!("{id} ({filename})"),
                url: format!(
                    "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/{filename}"
                ),
                sha256: sha256.to_string(),
                size_bytes,
                min_ram_gb: *min_ram_gb,
                is_bundled: *is_bundled,
            }
        })
        .collect()
}

#[flutter_rust_bridge::frb(ignore)]
pub fn is_model_downloaded(models_dir: &Path, model_id: &str) -> bool {
    resolve_model_path(models_dir, model_id)
        .map(|p| p.exists())
        .unwrap_or(false)
}

#[flutter_rust_bridge::frb(ignore)]
pub fn resolve_model_path(models_dir: &Path, model_id: &str) -> Result<PathBuf, TranscribeError> {
    KNOWN_MODELS
        .iter()
        .find(|(id, ..)| *id == model_id)
        .map(|(_, filename, ..)| models_dir.join(filename))
        .ok_or_else(|| TranscribeError::Model(format!("unknown model id: {model_id}")))
}

#[flutter_rust_bridge::frb(ignore)]
pub fn resolve_model_info(models_dir: &Path, model_id: &str) -> Result<ModelInfo, TranscribeError> {
    let (id, filename, min_ram_gb, is_bundled, sha256) = KNOWN_MODELS
        .iter()
        .find(|(id, ..)| *id == model_id)
        .copied()
        .ok_or_else(|| TranscribeError::Model(format!("unknown model id: {model_id}")))?;

    let path = models_dir.join(filename);
    let size_bytes = std::fs::metadata(&path).map(|m| m.len()).unwrap_or(0);
    Ok(ModelInfo {
        id: id.to_string(),
        name: format!("{id} ({filename})"),
        url: format!("https://huggingface.co/ggerganov/whisper.cpp/resolve/main/{filename}"),
        sha256: sha256.to_string(),
        size_bytes,
        min_ram_gb,
        is_bundled,
    })
}

/// Verify a downloaded file's SHA256 against an expected hex digest.
/// Empty `expected` means "no pin configured" — treated as a hard failure
/// rather than silently trusting the download (see STRIDE §86.1).
#[flutter_rust_bridge::frb(ignore)]
pub fn verify_checksum(path: &Path, expected_sha256: &str) -> Result<(), TranscribeError> {
    use sha2::{Digest, Sha256};
    if expected_sha256.is_empty() {
        return Err(TranscribeError::Model(
            "no pinned checksum configured for this model — refusing to trust it".into(),
        ));
    }

    let bytes = std::fs::read(path).map_err(TranscribeError::from)?;
    let mut hasher = Sha256::new();
    hasher.update(&bytes);
    let actual = hex::encode(hasher.finalize());

    if actual.eq_ignore_ascii_case(expected_sha256) {
        Ok(())
    } else {
        Err(TranscribeError::Model(format!(
            "checksum mismatch: expected {expected_sha256}, got {actual}"
        )))
    }
}

/// Append-resumable download via HTTP Range requests. Caller is
/// responsible for calling [`verify_checksum`] once `total_bytes` is
/// reached — this function only moves bytes and reports progress.
#[derive(Debug, Clone)]
pub struct DownloadProgress {
    pub bytes_downloaded: u64,
    pub total_bytes: u64,
}

/// Global download progress shared between Rust engine and Dart UI.
/// Set by `download_with_resume`, read by `get_download_progress()`.
static DOWNLOAD_PROGRESS: Mutex<Option<DownloadProgress>> = Mutex::new(None);

/// Reset progress tracking (call before starting a new download).
#[flutter_rust_bridge::frb(ignore)]
pub fn reset_download_progress() {
    if let Ok(mut guard) = DOWNLOAD_PROGRESS.lock() {
        *guard = None;
    }
}

/// Read the latest download progress. FRB-exposed via `api.rs`.
#[flutter_rust_bridge::frb(ignore)]
pub fn read_download_progress() -> Option<DownloadProgress> {
    DOWNLOAD_PROGRESS.lock().ok()?.clone()
}

pub(crate) fn set_download_progress(bytes_downloaded: u64, total_bytes: u64) {
    if let Ok(mut guard) = DOWNLOAD_PROGRESS.lock() {
        *guard = Some(DownloadProgress {
            bytes_downloaded,
            total_bytes,
        });
    }
}

pub async fn download_with_resume(
    url: &str,
    dest_path: &Path,
    mut on_progress: impl FnMut(DownloadProgress),
) -> Result<(), TranscribeError> {
    let filename = dest_path
        .file_name()
        .and_then(|f| f.to_str())
        .unwrap_or("model.bin");

    let urls = vec![
        url.to_string(),
        format!("https://huggingface.co/ggerganov/whisper.cpp/raw/main/{filename}"),
        format!("https://hf-mirror.com/ggerganov/whisper.cpp/resolve/main/{filename}"),
    ];

    let mut last_error = None;
    for target_url in &urls {
        match download_single_url(target_url, dest_path, &mut on_progress).await {
            Ok(()) => return Ok(()),
            Err(e) => {
                tracing::warn!(url = %target_url, error = %e, "download attempt failed, trying fallback url");
                last_error = Some(e);
            }
        }
    }

    Err(last_error.unwrap_or_else(|| TranscribeError::Model("download failed".into())))
}

async fn download_single_url(
    url: &str,
    dest_path: &Path,
    on_progress: &mut impl FnMut(DownloadProgress),
) -> Result<(), TranscribeError> {
    let client = reqwest::Client::builder()
        .user_agent("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
        .redirect(reqwest::redirect::Policy::limited(10))
        .tcp_keepalive(std::time::Duration::from_secs(30))
        .connect_timeout(std::time::Duration::from_secs(15))
        .build()
        .map_err(|e| TranscribeError::Model(format!("failed to build HTTP client: {e}")))?;

    let already_downloaded = std::fs::metadata(dest_path).map(|m| m.len()).unwrap_or(0);
    let request = build_resume_request(client.get(url), already_downloaded);

    let response = match request.send().await {
        Ok(res) => res,
        Err(_) if already_downloaded > 0 => {
            let _ = std::fs::remove_file(dest_path);
            client
                .get(url)
                .send()
                .await
                .map_err(|e| TranscribeError::Model(format!("download request failed: {e}")))?
        }
        Err(e) => {
            return Err(TranscribeError::Model(format!(
                "download request failed: {e}"
            )))
        }
    };

    let status = response.status();
    if !status.is_success() && status.as_u16() != 206 {
        if already_downloaded > 0 {
            let _ = std::fs::remove_file(dest_path);
            let fresh_req = client.get(url);
            let fresh_res = fresh_req
                .send()
                .await
                .map_err(|e| TranscribeError::Model(format!("download request failed: {e}")))?;
            if !fresh_res.status().is_success() {
                return Err(TranscribeError::Model(format!(
                    "download failed with status {}",
                    fresh_res.status()
                )));
            }
            let content_length = fresh_res.content_length().unwrap_or(0);
            return write_download_stream(
                dest_path,
                0,
                content_length,
                fresh_res.bytes_stream(),
                on_progress,
            )
            .await;
        }
        return Err(TranscribeError::Model(format!(
            "download failed with status {status}"
        )));
    }

    let is_partial = status.as_u16() == 206;
    let start_offset = if is_partial { already_downloaded } else { 0 };

    if !is_partial && already_downloaded > 0 {
        let _ = std::fs::remove_file(dest_path);
    }

    let content_length = response.content_length().unwrap_or(0);
    let total_bytes = start_offset + content_length;

    write_download_stream(
        dest_path,
        start_offset,
        total_bytes,
        response.bytes_stream(),
        on_progress,
    )
    .await
}

fn build_resume_request(
    request: reqwest::RequestBuilder,
    already_downloaded: u64,
) -> reqwest::RequestBuilder {
    if already_downloaded > 0 {
        request.header("Range", format!("bytes={already_downloaded}-"))
    } else {
        request
    }
}

async fn write_download_stream<S, E>(
    dest_path: &Path,
    already_downloaded: u64,
    total_bytes: u64,
    mut stream: S,
    mut on_progress: impl FnMut(DownloadProgress),
) -> Result<(), TranscribeError>
where
    S: futures_util::stream::Stream<Item = Result<bytes::Bytes, E>> + Unpin,
    E: std::error::Error,
{
    if let Some(parent) = dest_path.parent() {
        std::fs::create_dir_all(parent).map_err(TranscribeError::from)?;
    }

    let mut file = std::fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(dest_path)
        .map_err(TranscribeError::from)?;

    let mut downloaded = already_downloaded;
    while let Some(chunk) = stream.next().await {
        let chunk = chunk.map_err(|e| TranscribeError::Model(format!("stream error: {e}")))?;
        file.write_all(&chunk).map_err(TranscribeError::from)?;
        downloaded += chunk.len() as u64;
        on_progress(DownloadProgress {
            bytes_downloaded: downloaded,
            total_bytes,
        });
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use bytes::Bytes;
    use futures_util::stream;
    #[test]
    fn list_models_includes_tiny_bundled() {
        let dir = std::env::temp_dir();
        let models = list_available_models(&dir);
        let tiny = models.iter().find(|m| m.id == "tiny").unwrap();
        assert!(tiny.is_bundled);
    }

    #[test]
    fn default_bundle_includes_base_and_q5() {
        let dir = std::env::temp_dir();
        let models = list_available_models(&dir);
        let base = models
            .iter()
            .find(|m| m.id == "base")
            .expect("base catalog entry");
        let q5 = models
            .iter()
            .find(|m| m.id == "large-v3-turbo-q5")
            .expect("q5 catalog entry");
        assert!(base.is_bundled, "base must be bundled for offline-first");
        assert!(
            q5.is_bundled,
            "large-v3-turbo-q5 must be bundled for zero-download refine"
        );
    }

    #[test]
    fn resolve_unknown_model_errors() {
        let dir = std::env::temp_dir();
        assert!(resolve_model_path(&dir, "not-a-real-model").is_err());
    }

    #[test]
    fn is_model_downloaded_false_when_absent() {
        let dir = std::env::temp_dir().join(format!("transcribe_models_{}", uuid::Uuid::new_v4()));
        assert!(!is_model_downloaded(&dir, "tiny"));
    }

    #[test]
    fn verify_checksum_rejects_empty_pin() {
        let path = std::env::temp_dir().join("transcribe_checksum_test.bin");
        std::fs::write(&path, b"hello").unwrap();
        let result = verify_checksum(&path, "");
        assert!(result.is_err());
        let _ = std::fs::remove_file(&path);
    }

    #[test]
    fn verify_checksum_matches_known_hash() {
        let path = std::env::temp_dir().join(format!(
            "transcribe_checksum_ok_{}.bin",
            uuid::Uuid::new_v4()
        ));
        std::fs::write(&path, b"hello").unwrap();
        let expected = "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824";
        assert!(verify_checksum(&path, expected).is_ok());
        let _ = std::fs::remove_file(&path);
    }

    #[test]
    fn verify_checksum_mismatch_errors() {
        let path = std::env::temp_dir().join(format!(
            "transcribe_checksum_bad_{}.bin",
            uuid::Uuid::new_v4()
        ));
        std::fs::write(&path, b"hello").unwrap();
        let result = verify_checksum(
            &path,
            "0000000000000000000000000000000000000000000000000000000000000",
        );
        assert!(result.is_err());
        let _ = std::fs::remove_file(&path);
    }

    #[test]
    fn resume_request_adds_range_header_after_partial_file() {
        let client = reqwest::Client::new();
        let request = build_resume_request(client.get("http://example.com/model.bin"), 3);
        let built = request.build().unwrap();
        assert_eq!(built.headers().get("Range").unwrap(), "bytes=3-");
    }

    #[test]
    fn resume_request_keeps_full_download_without_header() {
        let client = reqwest::Client::new();
        let request = build_resume_request(client.get("http://example.com/model.bin"), 0);
        let built = request.build().unwrap();
        assert!(built.headers().get("Range").is_none());
    }

    #[tokio::test]
    async fn write_download_stream_appends_to_existing_file_and_reports_progress() {
        let body = b"abcdefghi".to_vec();
        let dest = std::env::temp_dir().join(format!(
            "transcribe_resume_download_{}.bin",
            uuid::Uuid::new_v4()
        ));
        std::fs::write(&dest, b"abc").unwrap();
        let mut progress = Vec::new();
        let chunks = stream::iter(vec![
            Ok::<Bytes, std::io::Error>(Bytes::from_static(b"def")),
            Ok::<Bytes, std::io::Error>(Bytes::from_static(b"ghi")),
        ]);
        write_download_stream(&dest, 3, 9, chunks, |p| {
            progress.push((p.bytes_downloaded, p.total_bytes))
        })
        .await
        .unwrap();

        let downloaded = std::fs::read(&dest).unwrap();
        assert_eq!(downloaded, body);
        assert_eq!(progress.last().copied(), Some((9, 9)));
        assert!(verify_checksum(
            &dest,
            "19cc02f26df43cc571bc9ed7b0c4d29224a3ec229529221725ef76d021c8326f",
        )
        .is_ok());

        let _ = std::fs::remove_file(&dest);
    }
}
