//! Formal register: EYD V and Tata Naskah Dinas language rules.
//!
//! A notulen can be structurally perfect and still be unusable, because
//! what a government secretariat circulates is *naskah dinas* — bahasa
//! Indonesia baku per KBBI and the Pedoman Tata Naskah Dinas (Pedoman
//! Menteri Kominfo No. 03/2019 butir P; Peraturan ANRI No. 5/2021). A
//! speech-to-text transcript is spoken Indonesian, so a model that
//! summarises faithfully reproduces "oke, nanti kita bikin" — faithful
//! and unsignable.
//!
//! This module is deliberately split in two:
//!
//! * [`check`] *reports*. Every finding names the rule, so the user can
//!   disagree. It never edits.
//! * [`normalise`] *edits*, and only the subset of findings where the
//!   replacement is unambiguous — a misspelling has exactly one baku
//!   form, whereas rewriting a colloquial clause is a judgement call that
//!   belongs to the notulis.
//!
//! # Why a lexicon and not a model
//!
//! The model that wrote the notulen is the model that produced the
//! register errors; asking it to grade itself finds nothing. A fixed list
//! of the errors the Pedoman and the KBBI actually name is checkable,
//! offline, instant, and explains itself.

use serde::Serialize;

/// Which rule a finding comes from, so the UI can group and the report
/// can cite.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
pub enum RegisterRule {
    /// Colloquial word with no place in a naskah dinas ("bikin", "oke").
    KataTidakBaku,
    /// Misspelling of a word whose baku form is in the KBBI
    /// ("analisa" → "analisis").
    EjaanBaku,
    /// Time, money or date written outside the Pedoman's format
    /// ("Jam 09:00" → "pukul 09.00 WIB").
    FormatAngka,
    /// Phrasing the Pedoman forbids ("dan lain-lain" in a naskah resmi).
    GayaDinas,
}

impl RegisterRule {
    #[flutter_rust_bridge::frb(ignore)]
    pub fn label(self) -> &'static str {
        match self {
            Self::KataTidakBaku => "Kata tidak baku",
            Self::EjaanBaku => "Ejaan baku (KBBI)",
            Self::FormatAngka => "Format angka/waktu",
            Self::GayaDinas => "Gaya naskah dinas",
        }
    }
}

/// One register problem found in the text.
#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct RegisterFinding {
    pub rule: RegisterRule,
    /// The offending text, exactly as it appears.
    pub ditemukan: String,
    /// The baku replacement, or an explanation when there is no single
    /// replacement.
    pub saran: String,
    /// 1-based line number in the checked text.
    pub baris: u32,
    /// True when [`normalise`] will apply `saran` automatically.
    pub otomatis: bool,
}

/// `(colloquial, baku)` — replaced automatically.
///
/// Every entry is a word whose formal equivalent is a single word, so the
/// substitution cannot change meaning. Colloquialisms that need a clause
/// rewritten are in [`FLAG_ONLY`] instead.
const BAKU: &[(&str, &str)] = &[
    // Spoken contractions that reach the transcript verbatim.
    ("gak", "tidak"),
    ("nggak", "tidak"),
    ("enggak", "tidak"),
    ("udah", "sudah"),
    ("udh", "sudah"),
    ("blm", "belum"),
    ("kalo", "kalau"),
    ("gimana", "bagaimana"),
    ("kenapa", "mengapa"),
    ("bikin", "membuat"),
    ("ngasih", "memberikan"),
    ("dikasih", "diberikan"),
    ("kerjain", "kerjakan"),
    ("nanya", "bertanya"),
    ("ngomong", "menyampaikan"),
    ("bareng", "bersama"),
    ("dapet", "mendapat"),
    ("pengen", "ingin"),
    ("makasih", "terima kasih"),
    ("oke", "baik"),
    ("ok", "baik"),
    // KBBI spellings the Pedoman's own checklist names.
    ("analisa", "analisis"),
    ("aktifitas", "aktivitas"),
    ("efektifitas", "efektivitas"),
    ("kreatifitas", "kreativitas"),
    ("praktek", "praktik"),
    ("resiko", "risiko"),
    ("obyek", "objek"),
    ("subyek", "subjek"),
    ("standarisasi", "standardisasi"),
    ("managemen", "manajemen"),
    ("menejemen", "manajemen"),
    ("jadual", "jadwal"),
    ("nomer", "nomor"),
    ("ijin", "izin"),
    ("sekedar", "sekadar"),
    ("silahkan", "silakan"),
    ("mempengaruhi", "memengaruhi"),
    ("seksama", "saksama"),
    ("komplit", "lengkap"),
    ("kordinasi", "koordinasi"),
    ("rapot", "rapor"),
    ("prosentase", "persentase"),
    ("dimana", "di mana"),
    ("kemana", "ke mana"),
    ("kesini", "ke sini"),
    ("disana", "di sana"),
    ("kebijaksanaan anggaran", "kebijakan anggaran"),
];

/// Colloquialisms that are reported but never auto-replaced, because the
/// repair is a rewrite rather than a word swap.
const FLAG_ONLY: &[(&str, &str)] = &[
    (
        "banget",
        "ganti dengan \"sangat\" dan susun ulang kalimatnya",
    ),
    (
        "kayak",
        "ganti dengan \"seperti\" dan susun ulang kalimatnya",
    ),
    ("aja", "hilangkan; tulis kalimat lengkap"),
    ("sih", "hilangkan; partikel percakapan"),
    ("deh", "hilangkan; partikel percakapan"),
    ("dong", "hilangkan; partikel percakapan"),
    ("nih", "hilangkan; partikel percakapan"),
    ("tuh", "hilangkan; partikel percakapan"),
    ("kok", "hilangkan; partikel percakapan"),
    ("lho", "hilangkan; partikel percakapan"),
    ("ya kan", "hilangkan; penegas percakapan"),
    ("gitu", "ganti dengan \"demikian\""),
    ("gini", "ganti dengan \"seperti ini\""),
    (
        "dan lain-lain",
        "Pedoman melarang \"dan lain-lain\" di naskah resmi — sebutkan rinciannya",
    ),
    (
        "dll",
        "Pedoman melarang \"dll.\" di naskah resmi — sebutkan rinciannya",
    ),
    (
        "dsb",
        "Pedoman melarang \"dsb.\" di naskah resmi — sebutkan rinciannya",
    ),
];

/// True when `haystack[at..at+len]` is a whole word.
fn is_word_boundary(haystack: &str, at: usize, len: usize) -> bool {
    let before = haystack[..at].chars().next_back();
    let after = haystack[at + len..].chars().next();
    let is_part = |c: Option<char>| c.is_some_and(|c| c.is_alphanumeric() || c == '-');
    !is_part(before) && !is_part(after)
}

/// Case-insensitive whole-word search, returning byte offsets into
/// `line` itself.
///
/// Matching is done in place rather than against a lowercased copy: for
/// a character whose lowercase form has a different UTF-8 length the two
/// strings' byte offsets diverge, and an offset taken from the copy then
/// slices `line` mid-character and panics. Every needle here is ASCII,
/// so comparing ASCII-lowered bytes of equal length is exact.
fn find_words(line: &str, needle: &str) -> Vec<usize> {
    debug_assert!(needle.is_ascii(), "needles are ASCII by construction");
    let bytes = line.as_bytes();
    let needle = needle.as_bytes();
    if needle.is_empty() || bytes.len() < needle.len() {
        return Vec::new();
    }
    let mut hits = Vec::new();
    let mut at = 0usize;
    while at + needle.len() <= bytes.len() {
        let matches = bytes[at..at + needle.len()]
            .iter()
            .zip(needle)
            .all(|(a, b)| a.eq_ignore_ascii_case(b));
        if matches && is_word_boundary(line, at, needle.len()) {
            hits.push(at);
            at += needle.len();
        } else {
            at += 1;
        }
    }
    hits
}

/// Reports every register problem in `text`, line by line.
#[flutter_rust_bridge::frb(ignore)]
pub fn check(text: &str) -> Vec<RegisterFinding> {
    let mut findings = Vec::new();
    for (index, line) in text.lines().enumerate() {
        let baris = index as u32 + 1;
        for (bad, good) in BAKU {
            for _ in find_words(line, bad) {
                findings.push(RegisterFinding {
                    rule: if bad.len() <= 7 && !bad.contains(' ') && is_colloquial(bad) {
                        RegisterRule::KataTidakBaku
                    } else {
                        RegisterRule::EjaanBaku
                    },
                    ditemukan: (*bad).to_string(),
                    saran: (*good).to_string(),
                    baris,
                    otomatis: true,
                });
            }
        }
        for (bad, advice) in FLAG_ONLY {
            for _ in find_words(line, bad) {
                findings.push(RegisterFinding {
                    rule: if matches!(*bad, "dan lain-lain" | "dll" | "dsb") {
                        RegisterRule::GayaDinas
                    } else {
                        RegisterRule::KataTidakBaku
                    },
                    ditemukan: (*bad).to_string(),
                    saran: (*advice).to_string(),
                    baris,
                    otomatis: false,
                });
            }
        }
        findings.extend(number_findings(line, baris));
    }
    findings
}

/// The colloquial half of [`BAKU`], distinguished from the misspellings
/// so findings can be grouped by rule.
fn is_colloquial(word: &str) -> bool {
    const SPOKEN: &[&str] = &[
        "gak", "nggak", "udah", "udh", "blm", "kalo", "bikin", "dapet", "pengen", "oke", "ok",
        "bareng", "nanya",
    ];
    SPOKEN.contains(&word)
}

/// Time, money and date formats the Pedoman specifies.
fn number_findings(line: &str, baris: u32) -> Vec<RegisterFinding> {
    let mut findings = Vec::new();
    let chars: Vec<char> = line.chars().collect();

    // `09:00` — the Pedoman writes the hour with a full stop.
    for (index, window) in chars.windows(5).enumerate() {
        if window[0].is_ascii_digit()
            && window[1].is_ascii_digit()
            && window[2] == ':'
            && window[3].is_ascii_digit()
            && window[4].is_ascii_digit()
        {
            let found: String = chars[index..index + 5].iter().collect();
            let replacement = found.replace(':', ".");
            findings.push(RegisterFinding {
                rule: RegisterRule::FormatAngka,
                ditemukan: found,
                saran: format!("pukul {replacement} WIB"),
                baris,
                otomatis: true,
            });
        }
    }

    // `Rp. 8.500.000,-` — no full stop after Rp, no space, sen as `,00`.
    for at in find_words(line, "rp") {
        // The amount is at most two whitespace-separated tokens: "Rp."
        // plus the figure, or one token when they are written together.
        let amount: String = line[at..]
            .split_whitespace()
            .take(2)
            .collect::<Vec<_>>()
            .join(" ");
        let amount = amount.trim_end_matches(['.', ',', ';']);
        let lower = amount.to_lowercase();
        let saran = if lower.starts_with("rp.") || lower.starts_with("rp ") {
            "tulis tanpa titik dan tanpa spasi, mis. Rp8.500.000,00"
        } else if amount.contains(",-") {
            "akhiri dengan \",00\", bukan \",-\""
        } else {
            continue;
        };
        findings.push(RegisterFinding {
            rule: RegisterRule::FormatAngka,
            ditemukan: amount.to_string(),
            saran: saran.to_string(),
            baris,
            otomatis: false,
        });
    }

    // `5-10-2026` — the Pedoman writes the month in words.
    let mut digits = 0usize;
    let mut dashes = 0usize;
    let mut start = 0usize;
    for (index, ch) in chars.iter().enumerate() {
        if ch.is_ascii_digit() {
            if digits == 0 && dashes == 0 {
                start = index;
            }
            digits += 1;
        } else if (*ch == '-' || *ch == '/') && digits > 0 {
            dashes += 1;
            digits = 0;
        } else {
            if dashes == 2 && digits >= 2 {
                let found: String = chars[start..index].iter().collect();
                findings.push(RegisterFinding {
                    rule: RegisterRule::FormatAngka,
                    ditemukan: found,
                    saran: "tulis tanggal lengkap, mis. 5 Oktober 2026".to_string(),
                    baris,
                    otomatis: false,
                });
            }
            digits = 0;
            dashes = 0;
        }
    }
    if dashes == 2 && digits >= 2 {
        let found: String = chars[start..].iter().collect();
        findings.push(RegisterFinding {
            rule: RegisterRule::FormatAngka,
            ditemukan: found,
            saran: "tulis tanggal lengkap, mis. 5 Oktober 2026".to_string(),
            baris,
            otomatis: false,
        });
    }
    findings
}

/// Applies every unambiguous replacement, preserving the original
/// capitalisation of the first letter.
///
/// Only [`BAKU`] and the `hh:mm` time form are touched. Anything whose
/// repair is a rewrite is left exactly as the model wrote it, because
/// silently rephrasing a decision is how a notulen stops being a record
/// of the meeting.
#[flutter_rust_bridge::frb(ignore)]
pub fn normalise(text: &str) -> String {
    let mut out = text.to_string();
    for (bad, good) in BAKU {
        out = replace_words(&out, bad, good);
    }
    out = replace_clock(&out);
    out
}

fn replace_words(text: &str, needle: &str, replacement: &str) -> String {
    let mut out = String::with_capacity(text.len());
    let mut rest = text;
    loop {
        let hits = find_words(rest, needle);
        let Some(&at) = hits.first() else {
            out.push_str(rest);
            return out;
        };
        out.push_str(&rest[..at]);
        let original = &rest[at..at + needle.len()];
        out.push_str(&match_case(original, replacement));
        rest = &rest[at + needle.len()..];
    }
}

/// Mirrors the original's capitalisation onto the replacement, so
/// "Analisa" becomes "Analisis" and not "analisis" mid-sentence.
fn match_case(original: &str, replacement: &str) -> String {
    let starts_upper = original.chars().next().is_some_and(char::is_uppercase);
    if !starts_upper {
        return replacement.to_string();
    }
    let mut chars = replacement.chars();
    match chars.next() {
        Some(first) => first.to_uppercase().collect::<String>() + chars.as_str(),
        None => String::new(),
    }
}

fn replace_clock(text: &str) -> String {
    let chars: Vec<char> = text.chars().collect();
    let mut out = String::with_capacity(text.len());
    let mut index = 0usize;
    while index < chars.len() {
        if index + 5 <= chars.len()
            && chars[index].is_ascii_digit()
            && chars[index + 1].is_ascii_digit()
            && chars[index + 2] == ':'
            && chars[index + 3].is_ascii_digit()
            && chars[index + 4].is_ascii_digit()
        {
            out.push(chars[index]);
            out.push(chars[index + 1]);
            out.push('.');
            out.push(chars[index + 3]);
            out.push(chars[index + 4]);
            index += 5;
            continue;
        }
        out.push(chars[index]);
        index += 1;
    }
    out
}

/// `0.0..=1.0` formality score: findings per 100 words, inverted.
///
/// Reported rather than enforced. The benchmark needs one number per
/// model and "how many register errors per 100 words" is the number that
/// means something; a notulen with no findings scores 1.0.
#[flutter_rust_bridge::frb(ignore)]
pub fn formality_score(text: &str) -> f64 {
    let words = text.split_whitespace().count().max(1);
    let findings = check(text).len();
    let per_hundred = findings as f64 * 100.0 / words as f64;
    (1.0 - per_hundred / 5.0).clamp(0.0, 1.0)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn colloquial_words_are_found_and_replaced() {
        let text = "Kita gak perlu bikin laporan baru, udah ada.";
        let findings = check(text);
        let found: Vec<&str> = findings.iter().map(|f| f.ditemukan.as_str()).collect();
        assert!(found.contains(&"gak"), "got {found:?}");
        assert!(found.contains(&"bikin"));
        assert!(found.contains(&"udah"));
        assert_eq!(
            normalise(text),
            "Kita tidak perlu membuat laporan baru, sudah ada."
        );
    }

    #[test]
    fn kbbi_misspellings_are_corrected_keeping_capitalisation() {
        assert_eq!(
            normalise("Analisa risiko dan praktek standarisasi mempengaruhi jadual."),
            "Analisis risiko dan praktik standardisasi memengaruhi jadwal."
        );
    }

    #[test]
    fn a_word_is_not_matched_inside_a_longer_word() {
        // "oke" inside "Tokek", "ok" inside "pokok", "analisa" inside
        // "menganalisanya" — the last one is a real word form and must be
        // left alone rather than corrupted mid-token.
        let text = "Pokok bahasan tentang Tokek dan menganalisanya.";
        assert_eq!(normalise(text), text);
        assert!(check(text).is_empty(), "{:?}", check(text));
    }

    #[test]
    fn particles_are_reported_but_never_rewritten_automatically() {
        let text = "Anggarannya besar banget, ya kan.";
        let findings = check(text);
        assert!(findings.iter().any(|f| f.ditemukan == "banget"));
        assert!(findings.iter().any(|f| f.ditemukan == "ya kan"));
        assert!(
            findings
                .iter()
                .all(|f| !f.otomatis || f.ditemukan != "banget"),
            "a clause rewrite must not be automatic"
        );
        // normalise leaves them: rewriting a sentence is the notulis's call.
        assert!(normalise(text).contains("banget"));
    }

    #[test]
    fn dan_lain_lain_is_flagged_as_a_pedoman_violation() {
        let findings = check("Peserta membahas anggaran, jadwal, dan lain-lain.");
        let finding = findings
            .iter()
            .find(|f| f.ditemukan == "dan lain-lain")
            .expect("not flagged");
        assert_eq!(finding.rule, RegisterRule::GayaDinas);
        assert!(!finding.otomatis);
    }

    #[test]
    fn the_clock_format_is_corrected_to_a_full_stop() {
        let findings = check("Rapat dimulai 09:00 dan selesai 11:30.");
        assert_eq!(
            findings.iter().filter(|f| f.ditemukan == "09:00").count(),
            1
        );
        assert!(findings
            .iter()
            .any(|f| f.saran == "pukul 09.00 WIB" && f.otomatis));
        assert_eq!(
            normalise("Rapat dimulai 09:00 dan selesai 11:30."),
            "Rapat dimulai 09.00 dan selesai 11.30."
        );
    }

    #[test]
    fn rupiah_written_the_wrong_way_is_flagged_but_not_rewritten() {
        let findings = check("Pagu Rp. 8.500.000,- disetujui.");
        let finding = findings
            .iter()
            .find(|f| f.rule == RegisterRule::FormatAngka && f.ditemukan.starts_with("Rp"))
            .expect("not flagged");
        assert!(!finding.otomatis, "money needs the notulis to confirm");
        assert!(finding.saran.contains("Rp8.500.000,00"));
    }

    #[test]
    fn a_numeric_date_is_flagged() {
        let findings = check("Surat tanggal 5-10-2026 sudah diterima.");
        assert!(findings
            .iter()
            .any(|f| f.ditemukan == "5-10-2026" && f.saran.contains("5 Oktober 2026")));
    }

    #[test]
    fn a_clean_naskah_dinas_paragraph_produces_no_findings() {
        let text = "Rapat dilaksanakan pada pukul 09.00 WIB di Ruang Rapat Lantai 5. \
                    Pimpinan rapat menyampaikan bahwa pagu indikatif naik 4 (empat) persen \
                    dan meminta analisis risiko disusun sebelum 10 Oktober 2026.";
        assert_eq!(check(text), Vec::new());
        assert!((formality_score(text) - 1.0).abs() < 1e-9);
    }

    #[test]
    fn the_formality_score_falls_as_findings_accumulate() {
        let clean = "Rapat dilaksanakan sesuai jadwal yang telah disepakati bersama.";
        let messy = "Oke gak usah bikin laporan, udah kayak gitu aja sih.";
        assert!(formality_score(clean) > formality_score(messy));
        assert!(formality_score(messy) < 0.5, "{}", formality_score(messy));
        assert!((0.0..=1.0).contains(&formality_score(messy)));
    }

    #[test]
    fn findings_carry_the_line_they_came_from() {
        let findings = check("Baris pertama bersih.\nBaris kedua pakai analisa.");
        assert_eq!(findings.len(), 1);
        assert_eq!(findings[0].baris, 2);
    }

    #[test]
    fn normalise_is_idempotent() {
        let once = normalise("Analisa praktek di 09:00 gak selesai.");
        assert_eq!(normalise(&once), once);
    }
}
