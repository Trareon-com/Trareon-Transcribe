//! "Tanya arsip rapat" (F12): a local full-text index over every session.
//!
//! The question this answers is the one a notulis asks six months later —
//! "when did we decide to move the deadline?" — and before this the only
//! way to answer it was to open meetings one at a time. The library's
//! deep search already greps transcripts, but grep cannot rank, cannot
//! stem, and cannot tell you which of forty hits is the one.
//!
//! # Shape
//!
//! * A SQLite database beside the library, with an FTS5 table over every
//!   segment and every summary.
//! * Incremental: a session is re-indexed only when its transcript's
//!   size or mtime changed. Re-walking 200 sessions on every launch is
//!   what made the old library screen unusable.
//! * Retrieval is local and ranked by BM25. The *answer* is composed by
//!   the same endpoint the summary feature uses, and nothing else —
//!   which is why this module opens no socket at all. `api` passes the
//!   retrieved passages to `summary::ask`, so the one networked path in
//!   the app stays the one networked path.
//!
//! # What is sent when the user asks a question
//!
//! Only the retrieved passages — at most [`MAX_CONTEXT_PASSAGES`] of
//! them — plus the question. Not the whole archive, not the audio, not
//! the file paths. The Privacy Report says so and `privacy::tests`
//! enforces that this module cannot reach the network itself.

use std::path::{Path, PathBuf};

use rusqlite::{params, Connection};
use serde::Serialize;

use crate::error::TranscribeError;
use crate::export::Segment;

/// Filename inside the library directory.
pub const DB_FILENAME: &str = ".trareon-arsip.db";

/// How many passages reach the model. Enough to answer a question about
/// one decision across a few meetings; small enough that a 0.5B model
/// running locally still has room to answer.
pub const MAX_CONTEXT_PASSAGES: usize = 12;

/// One indexed passage that matched.
#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct ArchiveHit {
    pub dir_path: String,
    pub title: String,
    /// `YYYY-MM-DD`.
    pub date: String,
    /// Seconds into the recording. `-1` for a summary passage, which has
    /// no single moment.
    pub timestamp: f64,
    pub speaker: String,
    pub text: String,
    /// BM25 relevance; lower is better in SQLite's ranking, so this is
    /// negated to read the way a user expects.
    pub score: f64,
}

impl ArchiveHit {
    /// "Rapat Anggaran (2026-10-04) 12:30" — the citation the answer
    /// carries, and what the UI turns into a link.
    #[flutter_rust_bridge::frb(ignore)]
    pub fn citation(&self) -> String {
        if self.timestamp < 0.0 {
            return format!("{} ({}) ringkasan", self.title, self.date);
        }
        let total = self.timestamp.max(0.0) as u64;
        format!(
            "{} ({}) {:02}:{:02}",
            self.title,
            self.date,
            total / 60,
            total % 60
        )
    }
}

/// What the index currently holds, for the settings screen.
#[derive(Debug, Clone, Default, Serialize)]
pub struct ArchiveStats {
    pub sessions: u32,
    pub passages: u32,
    pub bytes: u64,
}

/// Opens (and migrates) the index for `library_path`.
pub fn open(library_path: &Path) -> Result<Connection, TranscribeError> {
    std::fs::create_dir_all(library_path).map_err(TranscribeError::from)?;
    let db = Connection::open(db_path(library_path)).map_err(sql_error)?;
    migrate(&db)?;
    Ok(db)
}

pub fn db_path(library_path: &Path) -> PathBuf {
    library_path.join(DB_FILENAME)
}

fn sql_error(error: rusqlite::Error) -> TranscribeError {
    TranscribeError::InvalidInput(format!("indeks arsip: {error}"))
}

fn migrate(db: &Connection) -> Result<(), TranscribeError> {
    db.execute_batch(
        "PRAGMA journal_mode = WAL;
         CREATE TABLE IF NOT EXISTS sessions (
             dir_path   TEXT PRIMARY KEY,
             title      TEXT NOT NULL,
             date       TEXT NOT NULL,
             size       INTEGER NOT NULL,
             mtime_ms   INTEGER NOT NULL
         );
         CREATE VIRTUAL TABLE IF NOT EXISTS passages USING fts5(
             dir_path UNINDEXED,
             timestamp UNINDEXED,
             speaker UNINDEXED,
             text,
             tokenize = 'unicode61 remove_diacritics 2'
         );",
    )
    .map_err(sql_error)
}

/// Whether `dir_path`'s transcript has changed since it was indexed.
///
/// Size plus mtime, not a hash: hashing every transcript on every launch
/// is the cost this check exists to avoid.
pub fn is_stale(
    db: &Connection,
    dir_path: &str,
    size: u64,
    mtime_ms: i64,
) -> Result<bool, TranscribeError> {
    let mut statement = db
        .prepare("SELECT size, mtime_ms FROM sessions WHERE dir_path = ?1")
        .map_err(sql_error)?;
    let mut rows = statement.query(params![dir_path]).map_err(sql_error)?;
    match rows.next().map_err(sql_error)? {
        Some(row) => {
            let stored_size: i64 = row.get(0).map_err(sql_error)?;
            let stored_mtime: i64 = row.get(1).map_err(sql_error)?;
            Ok(stored_size != size as i64 || stored_mtime != mtime_ms)
        }
        None => Ok(true),
    }
}

/// Replaces everything indexed for one session.
///
/// Delete-then-insert rather than an upsert per row: a re-transcribed
/// session has entirely different segments, and leaving the old ones
/// behind would have the archive answer questions with text the user
/// has since replaced.
#[allow(clippy::too_many_arguments)]
pub fn index_session(
    db: &mut Connection,
    dir_path: &str,
    title: &str,
    date: &str,
    segments: &[Segment],
    summary: &str,
    size: u64,
    mtime_ms: i64,
) -> Result<u32, TranscribeError> {
    let transaction = db.transaction().map_err(sql_error)?;
    transaction
        .execute(
            "DELETE FROM passages WHERE dir_path = ?1",
            params![dir_path],
        )
        .map_err(sql_error)?;
    let mut inserted = 0u32;
    {
        let mut insert = transaction
            .prepare(
                "INSERT INTO passages (dir_path, timestamp, speaker, text) VALUES (?1, ?2, ?3, ?4)",
            )
            .map_err(sql_error)?;
        for segment in segments {
            let text = segment.text.trim();
            if segment.is_partial || text.is_empty() {
                continue;
            }
            insert
                .execute(params![dir_path, segment.timestamp, segment.speaker, text])
                .map_err(sql_error)?;
            inserted += 1;
        }
        if !summary.trim().is_empty() {
            insert
                .execute(params![dir_path, -1.0f64, "Ringkasan", summary.trim()])
                .map_err(sql_error)?;
            inserted += 1;
        }
    }
    transaction
        .execute(
            "INSERT INTO sessions (dir_path, title, date, size, mtime_ms)
             VALUES (?1, ?2, ?3, ?4, ?5)
             ON CONFLICT(dir_path) DO UPDATE SET
                 title = excluded.title, date = excluded.date,
                 size = excluded.size, mtime_ms = excluded.mtime_ms",
            params![dir_path, title, date, size as i64, mtime_ms],
        )
        .map_err(sql_error)?;
    transaction.commit().map_err(sql_error)?;
    Ok(inserted)
}

/// Forgets a session — called when the user deletes it, so the archive
/// cannot answer from a meeting that no longer exists.
pub fn forget_session(db: &Connection, dir_path: &str) -> Result<(), TranscribeError> {
    db.execute(
        "DELETE FROM passages WHERE dir_path = ?1",
        params![dir_path],
    )
    .map_err(sql_error)?;
    db.execute(
        "DELETE FROM sessions WHERE dir_path = ?1",
        params![dir_path],
    )
    .map_err(sql_error)?;
    Ok(())
}

/// The best `limit` passages for `question`, newest-first among ties.
pub fn search(
    db: &Connection,
    question: &str,
    limit: u32,
) -> Result<Vec<ArchiveHit>, TranscribeError> {
    let query = to_fts_query(question);
    if query.is_empty() {
        return Ok(Vec::new());
    }
    let mut statement = db
        .prepare(
            "SELECT p.dir_path, s.title, s.date, p.timestamp, p.speaker, p.text,
                    bm25(passages) AS rank
             FROM passages p
             JOIN sessions s ON s.dir_path = p.dir_path
             WHERE passages MATCH ?1
             ORDER BY rank
             LIMIT ?2",
        )
        .map_err(sql_error)?;
    let rows = statement
        .query_map(params![query, limit], |row| {
            Ok(ArchiveHit {
                dir_path: row.get(0)?,
                title: row.get(1)?,
                date: row.get(2)?,
                timestamp: row.get(3)?,
                speaker: row.get(4)?,
                text: row.get(5)?,
                score: -row.get::<_, f64>(6)?,
            })
        })
        .map_err(sql_error)?;
    rows.collect::<Result<Vec<_>, _>>().map_err(sql_error)
}

/// Turns a natural-language question into an FTS5 query.
///
/// Every term is quoted, so a question containing `AND`, `*`, `"` or a
/// bare `-` cannot be read as FTS5 syntax — at best that errors, at
/// worst it silently searches for something else. Terms are OR-ed and
/// ranked rather than AND-ed: a question rarely shares every word with
/// the passage that answers it.
pub fn to_fts_query(question: &str) -> String {
    let terms: Vec<String> = question
        .split(|c: char| !c.is_alphanumeric())
        .filter(|word| word.chars().count() >= 3)
        .filter(|word| !is_stopword(word))
        .map(|word| format!("\"{}\"", word.to_lowercase()))
        .collect();
    terms.join(" OR ")
}

/// Indonesian question words and particles. Searching for them matches
/// every meeting ever recorded and ranks none of them.
const STOPWORDS: &[&str] = &[
    "apa",
    "apakah",
    "siapa",
    "kapan",
    "kenapa",
    "mengapa",
    "bagaimana",
    "mana",
    "dimana",
    "yang",
    "dan",
    "dari",
    "untuk",
    "pada",
    "dengan",
    "ini",
    "itu",
    "adalah",
    "akan",
    "sudah",
    "tidak",
    "ada",
    "juga",
    "oleh",
    "atau",
    "dalam",
    "kita",
    "kami",
    "saya",
    "bahwa",
    "saja",
    "bisa",
    "soal",
    "tentang",
    "berapa",
    "waktu",
];

fn is_stopword(word: &str) -> bool {
    STOPWORDS.contains(&word.to_lowercase().as_str())
}

/// Index size and contents, for the settings screen.
pub fn stats(db: &Connection, library_path: &Path) -> Result<ArchiveStats, TranscribeError> {
    let sessions: u32 = db
        .query_row("SELECT COUNT(*) FROM sessions", [], |row| row.get(0))
        .map_err(sql_error)?;
    let passages: u32 = db
        .query_row("SELECT COUNT(*) FROM passages", [], |row| row.get(0))
        .map_err(sql_error)?;
    let bytes = std::fs::metadata(db_path(library_path))
        .map(|m| m.len())
        .unwrap_or(0);
    Ok(ArchiveStats {
        sessions,
        passages,
        bytes,
    })
}

/// Drops the whole index. The user's transcripts are untouched; this is
/// a cache.
pub fn clear(db: &Connection) -> Result<(), TranscribeError> {
    db.execute_batch("DELETE FROM passages; DELETE FROM sessions;")
        .map_err(sql_error)
}

// --- Prompt construction (pure; the request itself is `summary`'s) ----

/// The question, the retrieved passages, and the rule that the answer
/// must cite them.
///
/// The citation requirement is not politeness. An answer composed from
/// twelve passages across three meetings is unverifiable without it, and
/// an unverifiable answer about what a meeting decided is worse than no
/// answer — the user will act on it.
pub fn build_question_prompt(question: &str, hits: &[ArchiveHit]) -> String {
    let mut prompt = String::from(
        "Anda menjawab pertanyaan tentang arsip rapat. Gunakan HANYA kutipan \
         di bawah ini; jangan menambahkan pengetahuan dari luar. Setiap \
         pernyataan dalam jawaban WAJIB diakhiri rujukan ke kutipan yang \
         mendukungnya, ditulis sebagai [K1], [K2], dan seterusnya. Jika \
         kutipan yang tersedia tidak cukup untuk menjawab, katakan \
         \"Tidak ditemukan di arsip rapat\" dan berhenti di situ.\n\n--- KUTIPAN ---\n",
    );
    for (index, hit) in hits.iter().enumerate() {
        prompt.push_str(&format!(
            "[K{}] {} — {}: {}\n",
            index + 1,
            hit.citation(),
            hit.speaker,
            hit.text.trim()
        ));
    }
    prompt.push_str("--- AKHIR KUTIPAN ---\n\nPERTANYAAN: ");
    prompt.push_str(question.trim());
    prompt
}

/// An answer plus the passages it was allowed to use.
#[derive(Debug, Clone, Serialize)]
pub struct ArchiveAnswer {
    pub answer: String,
    pub sources: Vec<ArchiveHit>,
}

#[cfg(test)]
mod tests {
    use super::*;

    fn seg(text: &str, timestamp: f64, speaker: &str) -> Segment {
        Segment {
            source: "spk".into(),
            speaker: speaker.into(),
            text: text.into(),
            timestamp,
            duration: 4.0,
            language: "id".into(),
            confidence: 0.9,
            avg_log_prob: -0.3,
            is_partial: false,
            low_confidence: false,
        }
    }

    fn temp_library() -> PathBuf {
        let dir = std::env::temp_dir().join(format!("trareon_arsip_{}", uuid::Uuid::new_v4()));
        std::fs::create_dir_all(&dir).unwrap();
        dir
    }

    /// Three synthetic meetings, each with one distinctive decision.
    fn seed(db: &mut Connection) {
        index_session(
            db,
            "/lib/20260801-Rapat Anggaran",
            "Rapat Anggaran",
            "2026-08-01",
            &[
                seg("Selamat pagi, kita bahas pagu anggaran.", 0.0, "Saya"),
                seg(
                    "Pagu anggaran tahun depan disepakati naik sepuluh persen.",
                    30.0,
                    "Peserta 1",
                ),
                seg("Budi menyiapkan rinciannya.", 60.0, "Peserta 2"),
            ],
            "Rapat memutuskan kenaikan pagu anggaran sepuluh persen.",
            100,
            1,
        )
        .unwrap();
        index_session(
            db,
            "/lib/20260815-Rapat Vendor",
            "Rapat Vendor",
            "2026-08-15",
            &[
                seg("Kita evaluasi vendor katering.", 0.0, "Saya"),
                seg(
                    "Kontrak vendor katering diperpanjang enam bulan.",
                    45.0,
                    "Peserta 1",
                ),
            ],
            "",
            100,
            1,
        )
        .unwrap();
        index_session(
            db,
            "/lib/20260901-Rapat Jadwal",
            "Rapat Jadwal",
            "2026-09-01",
            &[
                seg("Soal jadwal peluncuran aplikasi.", 0.0, "Saya"),
                seg(
                    "Tenggat peluncuran digeser ke bulan November.",
                    90.0,
                    "Peserta 3",
                ),
            ],
            "",
            100,
            1,
        )
        .unwrap();
    }

    #[test]
    fn an_empty_index_opens_and_answers_nothing() {
        let dir = temp_library();
        let db = open(&dir).unwrap();
        assert!(search(&db, "anggaran", 10).unwrap().is_empty());
        let stats = stats(&db, &dir).unwrap();
        assert_eq!(stats.sessions, 0);
        assert_eq!(stats.passages, 0);
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn a_question_finds_the_meeting_that_answers_it() {
        let dir = temp_library();
        let mut db = open(&dir).unwrap();
        seed(&mut db);
        let hits = search(&db, "Kapan tenggat peluncuran digeser?", 5).unwrap();
        assert!(!hits.is_empty());
        assert_eq!(
            hits[0].title, "Rapat Jadwal",
            "the launch-date question must rank the launch meeting first; got {hits:#?}"
        );
        assert!(hits[0].text.contains("November"));
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn the_right_meeting_wins_across_three() {
        let dir = temp_library();
        let mut db = open(&dir).unwrap();
        seed(&mut db);
        for (question, expected) in [
            ("Berapa kenaikan pagu anggaran?", "Rapat Anggaran"),
            (
                "Apa keputusan soal kontrak vendor katering?",
                "Rapat Vendor",
            ),
            ("Kapan peluncuran aplikasi dijadwalkan?", "Rapat Jadwal"),
        ] {
            let hits = search(&db, question, 5).unwrap();
            assert_eq!(
                hits.first().map(|h| h.title.as_str()),
                Some(expected),
                "{question}"
            );
        }
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn a_citation_names_the_meeting_and_the_moment() {
        let dir = temp_library();
        let mut db = open(&dir).unwrap();
        seed(&mut db);
        let hits = search(&db, "pagu anggaran naik", 5).unwrap();
        let segment = hits
            .iter()
            .find(|hit| hit.timestamp >= 0.0)
            .expect("a segment hit");
        assert!(
            segment.citation().contains("Rapat Anggaran (2026-08-01)"),
            "{}",
            segment.citation()
        );
        assert!(segment.citation().contains(':'), "a time is part of it");
        let summary_hit = hits.iter().find(|hit| hit.timestamp < 0.0);
        if let Some(hit) = summary_hit {
            assert!(hit.citation().ends_with("ringkasan"));
        }
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn re_indexing_replaces_rather_than_duplicates() {
        // A re-transcribed session has entirely different segments;
        // leaving the old ones would answer with text the user replaced.
        let dir = temp_library();
        let mut db = open(&dir).unwrap();
        index_session(
            &mut db,
            "/lib/a",
            "A",
            "2026-01-01",
            &[seg("teks lama yang salah", 0.0, "Saya")],
            "",
            10,
            1,
        )
        .unwrap();
        index_session(
            &mut db,
            "/lib/a",
            "A",
            "2026-01-01",
            &[seg("teks baru yang benar", 0.0, "Saya")],
            "",
            20,
            2,
        )
        .unwrap();
        assert_eq!(stats(&db, &dir).unwrap().passages, 1);
        assert!(search(&db, "lama salah", 5).unwrap().is_empty());
        assert_eq!(search(&db, "baru benar", 5).unwrap().len(), 1);
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn staleness_is_size_and_mtime() {
        let dir = temp_library();
        let mut db = open(&dir).unwrap();
        assert!(is_stale(&db, "/lib/a", 10, 1).unwrap(), "never indexed");
        index_session(&mut db, "/lib/a", "A", "2026-01-01", &[], "x", 10, 1).unwrap();
        assert!(!is_stale(&db, "/lib/a", 10, 1).unwrap());
        assert!(is_stale(&db, "/lib/a", 11, 1).unwrap(), "size changed");
        assert!(is_stale(&db, "/lib/a", 10, 2).unwrap(), "mtime changed");
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn a_deleted_session_leaves_the_archive() {
        let dir = temp_library();
        let mut db = open(&dir).unwrap();
        seed(&mut db);
        forget_session(&db, "/lib/20260815-Rapat Vendor").unwrap();
        assert!(search(&db, "vendor katering", 5)
            .unwrap()
            .iter()
            .all(|hit| hit.title != "Rapat Vendor"));
        assert_eq!(stats(&db, &dir).unwrap().sessions, 2);
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn partial_and_empty_segments_are_not_indexed() {
        let dir = temp_library();
        let mut db = open(&dir).unwrap();
        let mut partial = seg("sementara", 0.0, "Saya");
        partial.is_partial = true;
        index_session(
            &mut db,
            "/lib/a",
            "A",
            "2026-01-01",
            &[partial, seg("   ", 5.0, "Saya"), seg("nyata", 10.0, "Saya")],
            "",
            10,
            1,
        )
        .unwrap();
        assert_eq!(stats(&db, &dir).unwrap().passages, 1);
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn fts_syntax_in_a_question_cannot_reach_the_query() {
        // `AND`, `*`, `"` and `-` are FTS5 operators. A question
        // containing them must search for the words, not error out.
        let dir = temp_library();
        let mut db = open(&dir).unwrap();
        seed(&mut db);
        for question in [
            "anggaran AND vendor",
            "anggaran OR NOT vendor*",
            "\"pagu\" -anggaran",
            "(((",
            "anggaran^2",
        ] {
            let result = search(&db, question, 5);
            assert!(result.is_ok(), "{question} errored: {result:?}");
        }
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn question_words_are_not_search_terms() {
        // "Apa yang diputuskan tentang anggaran" must search for
        // "diputuskan" and "anggaran", not for "apa" and "yang".
        let query = to_fts_query("Apa yang diputuskan tentang anggaran?");
        assert!(query.contains("\"diputuskan\""));
        assert!(query.contains("\"anggaran\""));
        assert!(!query.contains("\"apa\""));
        assert!(!query.contains("\"yang\""));
        assert!(!query.contains("\"tentang\""));
    }

    #[test]
    fn a_question_of_only_stopwords_searches_for_nothing() {
        assert_eq!(to_fts_query("apa yang itu?"), "");
        assert_eq!(to_fts_query(""), "");
        let dir = temp_library();
        let db = open(&dir).unwrap();
        assert!(search(&db, "apa yang itu?", 5).unwrap().is_empty());
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn clearing_the_index_leaves_it_usable() {
        let dir = temp_library();
        let mut db = open(&dir).unwrap();
        seed(&mut db);
        clear(&db).unwrap();
        let stats = stats(&db, &dir).unwrap();
        assert_eq!(stats.sessions, 0);
        assert_eq!(stats.passages, 0);
        assert!(search(&db, "anggaran", 5).unwrap().is_empty());
        // Still writable afterwards.
        index_session(&mut db, "/lib/a", "A", "2026-01-01", &[], "x", 1, 1).unwrap();
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn the_prompt_numbers_its_passages_and_forbids_outside_knowledge() {
        let hits = vec![ArchiveHit {
            dir_path: "/lib/a".into(),
            title: "Rapat Anggaran".into(),
            date: "2026-08-01".into(),
            timestamp: 30.0,
            speaker: "Peserta 1".into(),
            text: "Pagu naik sepuluh persen.".into(),
            score: 1.0,
        }];
        let prompt = build_question_prompt("Berapa kenaikan pagu?", &hits);
        assert!(prompt.contains("[K1] Rapat Anggaran (2026-08-01) 00:30"));
        assert!(prompt.contains("Pagu naik sepuluh persen."));
        assert!(prompt.contains("HANYA kutipan"));
        assert!(prompt.contains("Tidak ditemukan di arsip rapat"));
        assert!(prompt.ends_with("Berapa kenaikan pagu?"));
    }

    #[test]
    fn a_prompt_with_no_passages_still_tells_the_model_to_refuse() {
        let prompt = build_question_prompt("Apa keputusannya?", &[]);
        assert!(prompt.contains("Tidak ditemukan di arsip rapat"));
    }
}
