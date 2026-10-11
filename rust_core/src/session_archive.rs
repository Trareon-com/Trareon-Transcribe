// Copyright 2026 YSF Studio. Licensed under Privacy-Preserving Software License v1.0.
// SPDX-License-Identifier: PPSL
//
//! "Ekspor/Impor arsip sesi" (F26/F27, Sprint 16): pack a whole session
//! folder — source audio, transcript `*.json`, the `trareon-session.json`
//! sidecar, the re-transcribe backup when present — into one portable
//! `.zip`, and unpack one back.
//!
//! This exists so a session can move between devices (USB/AirDrop/Tailscale
//! file share/whatever the user already has) without a watch-folder, an
//! account or a server: the user presses "Ekspor", moves the `.zip`
//! themselves, then presses "Impor" on the other device. See
//! `docs/MULTI_DEVICE_HANDOFF_AUDIT.md` for why that is the whole feature
//! and nothing more — anything that sent data without an explicit button
//! press would contradict `privacy.rs`.
//!
//! Only the mechanical zip/unzip lives here. *Validating* that an extracted
//! folder is actually a Trareon session (sidecar readable, transcript
//! present) is deliberately left to the Dart side, which already has the
//! tolerant `SessionMeta.fromJson` parser — duplicating that here would be
//! two parsers to keep in sync.
//!
//! Same `zip` crate and write pattern (temp file + rename) as
//! `flight_recorder::write_diagnostics_bundle`, which already does exactly
//! this for the diagnostics bundle.

use std::fs::{self, File};
use std::io::{self, Read, Write};
use std::path::{Path, PathBuf};

/// Zips every regular file directly inside `session_dir` (a session folder
/// is flat — no subdirectories) into `destination`.
///
/// Writes atomically: a half-written zip must never be left at the
/// destination path for the user to hand to another device.
pub fn write_session_archive(session_dir: &Path, destination: &Path) -> io::Result<PathBuf> {
    if !session_dir.is_dir() {
        return Err(io::Error::new(
            io::ErrorKind::NotFound,
            format!("session dir not found: {}", session_dir.display()),
        ));
    }

    let mut buffer = io::Cursor::new(Vec::new());
    {
        let mut writer = zip::ZipWriter::new(&mut buffer);
        let options = zip::write::SimpleFileOptions::default()
            .compression_method(zip::CompressionMethod::Deflated);
        let mut read_dir: Vec<_> = fs::read_dir(session_dir)?
            .filter_map(|e| e.ok())
            .map(|e| e.path())
            .filter(|p| p.is_file())
            .collect();
        // Deterministic entry order so the same session produces a byte-
        // identical archive on repeated export (and so tests can assert on
        // entry order without sorting themselves).
        read_dir.sort();
        for path in read_dir {
            let Some(name) = path.file_name().and_then(|n| n.to_str()) else {
                continue;
            };
            writer.start_file(name, options).map_err(io::Error::other)?;
            let mut file = File::open(&path)?;
            let mut contents = Vec::new();
            file.read_to_end(&mut contents)?;
            writer.write_all(&contents)?;
        }
        writer.finish().map_err(io::Error::other)?;
    }

    if let Some(parent) = destination.parent() {
        fs::create_dir_all(parent)?;
    }
    let temp = PathBuf::from(format!("{}.tmp", destination.display()));
    fs::write(&temp, buffer.into_inner())?;
    if fs::rename(&temp, destination).is_err() {
        fs::copy(&temp, destination)?;
        let _ = fs::remove_file(&temp);
    }
    Ok(destination.to_path_buf())
}

/// Entry names inside `archive_path`, without extracting anything. Lets the
/// Dart side (or a test) inspect a `.zip`'s contents cheaply.
///
/// Returns an `Io` error for anything that is not a readable zip — a
/// corrupt file or one that is not a zip at all — so the caller can show
/// "bukan arsip sesi yang valid" rather than crash.
pub fn list_archive_entries(archive_path: &Path) -> io::Result<Vec<String>> {
    let file = File::open(archive_path)?;
    let archive = zip::ZipArchive::new(file).map_err(io::Error::other)?;
    Ok(archive.file_names().map(|s| s.to_string()).collect())
}

/// Extracts every file in `archive_path` directly into `destination_dir`
/// (created if missing), flattened — a session folder has no
/// subdirectories, and an entry name is never trusted as a path to create
/// one.
///
/// Zip-slip safe: `enclosed_name()` refuses absolute paths and `..`
/// components outright (returning `None`), so an entry trying to escape
/// `destination_dir` is skipped rather than written anywhere.
///
/// Returns the file names written. An unreadable/corrupt zip is an `Io`
/// error; nothing is written to `destination_dir` in that case.
pub fn extract_archive(archive_path: &Path, destination_dir: &Path) -> io::Result<Vec<String>> {
    let file = File::open(archive_path)?;
    let mut archive = zip::ZipArchive::new(file).map_err(io::Error::other)?;
    fs::create_dir_all(destination_dir)?;

    let mut written = Vec::new();
    for i in 0..archive.len() {
        let mut entry = archive.by_index(i)?;
        if entry.is_dir() {
            continue;
        }
        let Some(enclosed) = entry.enclosed_name() else {
            continue;
        };
        let Some(name) = enclosed.file_name().and_then(|n| n.to_str()) else {
            continue;
        };
        let out_path = destination_dir.join(name);
        let mut out_file = File::create(&out_path)?;
        io::copy(&mut entry, &mut out_file)?;
        written.push(name.to_string());
    }
    Ok(written)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn temp_dir(tag: &str) -> PathBuf {
        let base = std::env::temp_dir().join(format!(
            "trareon-session-archive-{tag}-{}-{}",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        fs::create_dir_all(&base).unwrap();
        base
    }

    #[test]
    fn roundtrips_a_session_folder() {
        let session_dir = temp_dir("session");
        fs::write(session_dir.join("transcript.json"), b"[]").unwrap();
        fs::write(
            session_dir.join("trareon-session.json"),
            br#"{"version":1,"title":"Rapat"}"#,
        )
        .unwrap();
        fs::write(session_dir.join("audio.wav"), b"RIFF....").unwrap();

        let zip_path = temp_dir("zipdir").join("rapat.zip");
        write_session_archive(&session_dir, &zip_path).unwrap();
        assert!(zip_path.exists());

        let mut entries = list_archive_entries(&zip_path).unwrap();
        entries.sort();
        assert_eq!(
            entries,
            vec!["audio.wav", "transcript.json", "trareon-session.json"]
        );

        let extract_dir = temp_dir("extract");
        let mut written = extract_archive(&zip_path, &extract_dir).unwrap();
        written.sort();
        assert_eq!(
            written,
            vec!["audio.wav", "transcript.json", "trareon-session.json"]
        );
        assert_eq!(
            fs::read_to_string(extract_dir.join("transcript.json")).unwrap(),
            "[]"
        );
        assert_eq!(
            fs::read(extract_dir.join("audio.wav")).unwrap(),
            b"RIFF...."
        );
    }

    #[test]
    fn write_fails_for_missing_session_dir() {
        let missing = temp_dir("missing").join("does-not-exist");
        let zip_path = temp_dir("out").join("x.zip");
        assert!(write_session_archive(&missing, &zip_path).is_err());
    }

    #[test]
    fn extract_rejects_corrupt_archive() {
        let bogus = temp_dir("bogus").join("not-a-zip.zip");
        fs::write(&bogus, b"this is not a zip file").unwrap();
        let extract_dir = temp_dir("extract-bogus");
        assert!(extract_archive(&bogus, &extract_dir).is_err());
        assert!(list_archive_entries(&bogus).is_err());
    }

    #[test]
    fn extract_ignores_path_traversal_entries() {
        // Build a zip by hand whose entry name tries to escape the
        // destination directory, and confirm nothing lands outside it.
        let zip_path = temp_dir("traversal").join("evil.zip");
        {
            let file = File::create(&zip_path).unwrap();
            let mut writer = zip::ZipWriter::new(file);
            let options = zip::write::SimpleFileOptions::default();
            writer.start_file("../../evil.txt", options).unwrap();
            writer.write_all(b"pwned").unwrap();
            writer.finish().unwrap();
        }
        let extract_dir = temp_dir("traversal-out");
        let written = extract_archive(&zip_path, &extract_dir).unwrap();
        // `enclosed_name()` refuses the traversing entry outright, so
        // nothing is written for it — not inside `extract_dir`, and
        // certainly not above it.
        assert!(written.is_empty());
        assert!(!extract_dir.join("evil.txt").exists());
        assert!(!extract_dir
            .parent()
            .unwrap()
            .parent()
            .unwrap()
            .join("evil.txt")
            .exists());
    }
}
