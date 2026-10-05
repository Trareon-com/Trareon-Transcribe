//! PII detection and masking for Indonesian meeting transcripts (F13).
//!
//! UU No. 27/2022 (Pelindungan Data Pribadi) makes the *controller*
//! responsible for what leaves the building. A notulen that is emailed
//! around with a participant's NIK in it is a disclosure, whether or not
//! anyone meant it: NIKs, phone numbers and rekening numbers get read out
//! loud in exactly the kind of meeting this app records.
//!
//! So redaction happens at export, on a copy, and the user sees what will
//! change before it does. Nothing here edits the stored transcript.
//!
//! # Why hand-written scanners and not regexes
//!
//! The patterns are digit runs with Indonesian-specific lengths and
//! prefixes, and the hard part is not matching them — it is *not* matching
//! the year, the budget figure and the agenda item number that share their
//! shape. A scanner that can look at its own context (is there a bank name
//! nearby? does this 16-digit run start with a valid province code?) says
//! no more often than a regex can, and every one of those refusals is a
//! line of real transcript that survives.
//!
//! # The two failure modes
//!
//! Missing a NIK leaks it. Masking "Rp 1.500.000" as a bank account
//! destroys the minutes. Both are tested below with Indonesian samples,
//! and the second has more tests than the first, because it is the one
//! that happens every meeting.

use serde::{Deserialize, Serialize};

/// What a match is, which decides its placeholder and its precedence.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum PiiKind {
    /// Nomor Induk Kependudukan — 16 digits.
    Nik,
    /// Nomor Pokok Wajib Pajak — 15 digits, often dotted.
    Npwp,
    Phone,
    Email,
    /// A digit run a bank keyword vouches for.
    BankAccount,
    /// A name the user put on the list.
    Name,
}

impl PiiKind {
    /// The Indonesian placeholder that replaces a match.
    #[flutter_rust_bridge::frb(ignore)]
    pub fn placeholder(self) -> &'static str {
        match self {
            PiiKind::Nik => "[NIK]",
            PiiKind::Npwp => "[NPWP]",
            PiiKind::Phone => "[NOMOR TELEPON]",
            PiiKind::Email => "[EMAIL]",
            PiiKind::BankAccount => "[NOMOR REKENING]",
            PiiKind::Name => "[NAMA]",
        }
    }

    /// User-facing name for the preview list.
    #[flutter_rust_bridge::frb(ignore)]
    pub fn label(self) -> &'static str {
        match self {
            PiiKind::Nik => "NIK",
            PiiKind::Npwp => "NPWP",
            PiiKind::Phone => "Nomor telepon",
            PiiKind::Email => "Alamat email",
            PiiKind::BankAccount => "Nomor rekening",
            PiiKind::Name => "Nama",
        }
    }

    /// Higher wins when two matches overlap. The specific beats the
    /// general: a 16-digit NIK that a bank keyword also vouches for is a
    /// NIK, not an account number.
    fn precedence(self) -> u8 {
        match self {
            PiiKind::Email => 5,
            PiiKind::Nik => 4,
            PiiKind::Npwp => 4,
            PiiKind::Phone => 3,
            PiiKind::BankAccount => 2,
            PiiKind::Name => 1,
        }
    }
}

/// Which categories to mask, plus the names only this user can know about.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct RedactionConfig {
    pub nik: bool,
    pub npwp: bool,
    pub phone: bool,
    pub email: bool,
    pub bank_account: bool,
    /// Names to mask wherever they appear. Matched whole-word and
    /// case-insensitively; a one- or two-character entry is ignored,
    /// because masking every "di" in the transcript is not redaction.
    pub names: Vec<String>,
}

impl RedactionConfig {
    /// Everything except names, which only the user can supply. This is
    /// what "Mode UU PDP" turns on.
    #[flutter_rust_bridge::frb(ignore)]
    pub fn all() -> Self {
        Self {
            nik: true,
            npwp: true,
            phone: true,
            email: true,
            bank_account: true,
            names: Vec::new(),
        }
    }

    #[flutter_rust_bridge::frb(ignore)]
    pub fn wants(&self, kind: PiiKind) -> bool {
        match kind {
            PiiKind::Nik => self.nik,
            PiiKind::Npwp => self.npwp,
            PiiKind::Phone => self.phone,
            PiiKind::Email => self.email,
            PiiKind::BankAccount => self.bank_account,
            PiiKind::Name => !self.names.is_empty(),
        }
    }

    #[flutter_rust_bridge::frb(ignore)]
    pub fn is_noop(&self) -> bool {
        !self.nik
            && !self.npwp
            && !self.phone
            && !self.email
            && !self.bank_account
            && self.names.is_empty()
    }
}

/// One thing that would be masked. Byte offsets into the text scanned, so
/// the UI can highlight in place.
#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct PiiMatch {
    pub kind: PiiKind,
    pub start: u32,
    pub end: u32,
    /// The text as it appears, for the preview. This is itself personal
    /// data: it is shown to the user who already has the transcript open
    /// and is never written anywhere.
    pub text: String,
    pub replacement: String,
}

/// Words that make a nearby digit run an account number rather than a
/// quantity. Without one of these in the preceding
/// [`BANK_CONTEXT_WINDOW`] bytes, a bare 10-digit number is left alone —
/// in a rapat it is far more often a budget line than a rekening.
const BANK_KEYWORDS: &[&str] = &[
    "rekening",
    "rek.",
    "no rek",
    "no. rek",
    "norek",
    "a/n",
    "atas nama",
    "virtual account",
    "va ",
    "bca",
    "bni",
    "bri",
    "mandiri",
    "bsi",
    "btn",
    "cimb",
    "niaga",
    "permata",
    "danamon",
    "maybank",
    "ocbc",
    "panin",
    "bjb",
    "muamalat",
];

/// How far back a bank keyword counts. One clause, not one paragraph:
/// "Rekening sudah ditutup. Anggaran tahun ini 1500000000" must not have
/// its budget figure masked.
const BANK_CONTEXT_WINDOW: usize = 48;

/// Every match in `text` the config asks for, in document order and
/// without overlaps.
pub fn find_pii(text: &str, config: &RedactionConfig) -> Vec<PiiMatch> {
    if config.is_noop() {
        return Vec::new();
    }
    let mut found = Vec::new();
    if config.email {
        find_emails(text, &mut found);
    }
    find_number_runs(text, config, &mut found);
    find_names(text, &config.names, &mut found);
    resolve_overlaps(found)
}

/// `text` with every match replaced by its placeholder.
pub fn redact(text: &str, config: &RedactionConfig) -> String {
    let matches = find_pii(text, config);
    if matches.is_empty() {
        return text.to_string();
    }
    let mut out = String::with_capacity(text.len());
    let mut cursor = 0usize;
    for found in &matches {
        let start = found.start as usize;
        let end = found.end as usize;
        if start < cursor || end > text.len() {
            continue;
        }
        out.push_str(&text[cursor..start]);
        out.push_str(&found.replacement);
        cursor = end;
    }
    out.push_str(&text[cursor..]);
    out
}

/// Redacts a transcript in place and reports what it masked.
///
/// Call this on a *copy* bound for export. Rewriting the stored transcript
/// would destroy evidence the user may need and cannot get back.
pub fn redact_segments(
    segments: &mut [crate::export::Segment],
    config: &RedactionConfig,
) -> Vec<PiiMatch> {
    let mut all = Vec::new();
    for segment in segments.iter_mut() {
        let found = find_pii(&segment.text, config);
        if found.is_empty() {
            continue;
        }
        segment.text = redact(&segment.text, config);
        all.extend(found);
    }
    all
}

// --- scanners ---------------------------------------------------------

fn find_emails(text: &str, out: &mut Vec<PiiMatch>) {
    let bytes = text.as_bytes();
    for (index, byte) in bytes.iter().enumerate() {
        if *byte != b'@' {
            continue;
        }
        let mut start = index;
        while start > 0 && is_email_local(bytes[start - 1]) {
            start -= 1;
        }
        let mut end = index + 1;
        while end < bytes.len() && is_email_domain(bytes[end]) {
            end += 1;
        }
        // Trim a trailing dot ("tulis ke budi@contoh.go.id.").
        while end > index + 1 && bytes[end - 1] == b'.' {
            end -= 1;
        }
        if start == index || end == index + 1 {
            continue;
        }
        let domain = &text[index + 1..end];
        // A domain needs a dot and a TLD of at least two letters, or
        // "pukul 09@30" would be an address.
        let Some((_, tld)) = domain.rsplit_once('.') else {
            continue;
        };
        if tld.len() < 2 || !tld.bytes().all(|b| b.is_ascii_alphabetic()) {
            continue;
        }
        push(out, PiiKind::Email, start, end, text);
    }
}

fn is_email_local(byte: u8) -> bool {
    byte.is_ascii_alphanumeric() || matches!(byte, b'.' | b'_' | b'%' | b'+' | b'-')
}

fn is_email_domain(byte: u8) -> bool {
    byte.is_ascii_alphanumeric() || matches!(byte, b'.' | b'-')
}

/// Finds digit runs (allowing the separators Indonesians actually type)
/// and classifies each by length, prefix and context.
fn find_number_runs(text: &str, config: &RedactionConfig, out: &mut Vec<PiiMatch>) {
    let bytes = text.as_bytes();
    let mut index = 0usize;
    while index < bytes.len() {
        if !bytes[index].is_ascii_digit() && bytes[index] != b'+' {
            index += 1;
            continue;
        }
        let start = index;
        if bytes[index] == b'+' {
            // Only "+62…" is a number here; a bare '+' is arithmetic.
            if index + 1 >= bytes.len() || !bytes[index + 1].is_ascii_digit() {
                index += 1;
                continue;
            }
            index += 1;
        }
        let mut digits = String::new();
        let mut end = index;
        while end < bytes.len() {
            let byte = bytes[end];
            if byte.is_ascii_digit() {
                digits.push(byte as char);
                end += 1;
            } else if matches!(byte, b'-' | b'.' | b' ' | b'(' | b')')
                && end + 1 < bytes.len()
                && bytes[end + 1].is_ascii_digit()
            {
                // A separator only continues the run if a digit follows,
                // so "1500000. Berikutnya 3" stays two runs.
                end += 1;
            } else {
                break;
            }
        }
        // Don't swallow a trailing separator.
        while end > start && !bytes[end - 1].is_ascii_digit() {
            end -= 1;
        }
        if let Some(kind) = classify_run(text, start, &digits) {
            if config.wants(kind) {
                push(out, kind, start, end, text);
            }
        }
        index = end.max(start + 1);
    }
}

/// What a digit run is, if anything.
///
/// Returning `None` is the common case and the important one: most numbers
/// in a rapat are money, dates and item counts.
fn classify_run(text: &str, start: usize, digits: &str) -> Option<PiiKind> {
    let length = digits.len();
    let first = digits.as_bytes().first().copied()?;

    // NIK: exactly 16 digits, and the first two are a real province code
    // (11 Aceh … 94 Papua). That one check is what keeps a 16-digit
    // transaction reference from being masked as an identity number.
    if length == 16 {
        let province: u32 = digits[..2].parse().ok()?;
        if (11..=94).contains(&province) {
            return Some(PiiKind::Nik);
        }
    }
    // NPWP: 15 digits, or 16 since the 2024 NIK-as-NPWP transition — the
    // 16-digit case is already covered above.
    //
    // BRI account numbers are also 15 digits, so the label goes to
    // whichever word is standing next to it. Both are masked either way;
    // this only decides which placeholder the reader sees, and a preview
    // that calls a rekening an NPWP undermines trust in the rest.
    if length == 15 {
        return Some(if has_bank_context(text, start) {
            PiiKind::BankAccount
        } else {
            PiiKind::Npwp
        });
    }
    // Indonesian mobile numbers: 08xx (10-13 digits) or +62/62 8xx.
    if first == b'0' && digits.as_bytes().get(1) == Some(&b'8') && (10..=14).contains(&length) {
        return Some(PiiKind::Phone);
    }
    if digits.starts_with("62")
        && digits.as_bytes().get(2) == Some(&b'8')
        && (11..=15).contains(&length)
    {
        return Some(PiiKind::Phone);
    }
    // Landlines are written with an area code: 021-5551234.
    if first == b'0' && (9..=12).contains(&length) && text[start..].starts_with('0') {
        let has_separator = text[start..]
            .chars()
            .take(length + 4)
            .any(|c| c == '-' || c == ' ');
        if has_separator {
            return Some(PiiKind::Phone);
        }
    }
    // Account numbers only when something nearby says so.
    if (8..=16).contains(&length) && has_bank_context(text, start) {
        return Some(PiiKind::BankAccount);
    }
    None
}

fn has_bank_context(text: &str, start: usize) -> bool {
    let from = start.saturating_sub(BANK_CONTEXT_WINDOW);
    // Snap to a char boundary; `text` is arbitrary user content.
    let from = (from..=start)
        .find(|index| text.is_char_boundary(*index))
        .unwrap_or(start);
    let window = text[from..start].to_lowercase();
    BANK_KEYWORDS.iter().any(|keyword| window.contains(keyword))
}

/// Whole-word, case-insensitive matches of the user's name list.
fn find_names(text: &str, names: &[String], out: &mut Vec<PiiMatch>) {
    if names.is_empty() {
        return;
    }
    let haystack = text.to_lowercase();
    // Lowercasing can change byte lengths (ß, İ). When it does, offsets
    // into the lowercased copy are meaningless, so fall back to a
    // case-sensitive scan rather than masking the wrong span.
    let aligned = haystack.len() == text.len();
    for name in names {
        let needle = name.trim();
        // One or two characters match half the transcript.
        if needle.chars().count() < 3 {
            continue;
        }
        let needle_lower = needle.to_lowercase();
        let (hay, pattern) = if aligned {
            (haystack.as_str(), needle_lower.as_str())
        } else {
            (text, needle)
        };
        let mut from = 0usize;
        while let Some(offset) = hay[from..].find(pattern) {
            let start = from + offset;
            let end = start + pattern.len();
            if is_word_boundary(hay, start, end) {
                push(out, PiiKind::Name, start, end, text);
            }
            from = end.max(start + 1);
        }
    }
}

fn is_word_boundary(text: &str, start: usize, end: usize) -> bool {
    let before = text[..start].chars().next_back();
    let after = text[end..].chars().next();
    !before.is_some_and(|c| c.is_alphanumeric()) && !after.is_some_and(|c| c.is_alphanumeric())
}

fn push(out: &mut Vec<PiiMatch>, kind: PiiKind, start: usize, end: usize, text: &str) {
    if start >= end || end > text.len() {
        return;
    }
    out.push(PiiMatch {
        kind,
        start: start as u32,
        end: end as u32,
        text: text[start..end].to_string(),
        replacement: kind.placeholder().to_string(),
    });
}

/// Keeps the strongest match where two overlap, and sorts by position.
fn resolve_overlaps(mut matches: Vec<PiiMatch>) -> Vec<PiiMatch> {
    matches.sort_by(|a, b| {
        a.start.cmp(&b.start).then_with(|| {
            b.kind
                .precedence()
                .cmp(&a.kind.precedence())
                .then_with(|| (b.end - b.start).cmp(&(a.end - a.start)))
        })
    });
    let mut kept: Vec<PiiMatch> = Vec::with_capacity(matches.len());
    for found in matches {
        match kept.last() {
            Some(last) if found.start < last.end => continue,
            _ => kept.push(found),
        }
    }
    kept
}

#[cfg(test)]
mod tests {
    use super::*;

    fn all() -> RedactionConfig {
        RedactionConfig::all()
    }

    fn kinds(text: &str) -> Vec<PiiKind> {
        find_pii(text, &all()).into_iter().map(|m| m.kind).collect()
    }

    // --- what must be masked -------------------------------------------

    #[test]
    fn a_nik_read_out_in_a_meeting_is_masked() {
        let text = "NIK beliau 3174012509800003, tolong dicatat.";
        assert_eq!(kinds(text), vec![PiiKind::Nik]);
        assert_eq!(redact(text, &all()), "NIK beliau [NIK], tolong dicatat.");
    }

    #[test]
    fn niks_from_several_provinces_are_recognised() {
        for nik in [
            "1171022003910002", // Aceh/Banda Aceh
            "3273010101900001", // Bandung
            "6471015006850002", // Balikpapan
            "9471010101800001", // Papua
        ] {
            assert_eq!(
                kinds(&format!("nomor {nik}")),
                vec![PiiKind::Nik],
                "{nik} must be a NIK"
            );
        }
    }

    #[test]
    fn indonesian_mobile_numbers_are_masked() {
        for phone in [
            "081234567890",
            "0812-3456-7890",
            "0812 3456 7890",
            "+6281234567890",
            "+62 812 3456 7890",
            "6281234567890",
        ] {
            assert_eq!(
                kinds(&format!("hubungi {phone} ya")),
                vec![PiiKind::Phone],
                "{phone} must be a phone number"
            );
        }
    }

    #[test]
    fn a_landline_with_an_area_code_is_masked() {
        assert_eq!(kinds("telepon kantor 021-5551234"), vec![PiiKind::Phone]);
    }

    #[test]
    fn emails_are_masked() {
        let text = "kirim ke budi.santoso@kemenkeu.go.id sebelum Jumat.";
        assert_eq!(kinds(text), vec![PiiKind::Email]);
        assert_eq!(redact(text, &all()), "kirim ke [EMAIL] sebelum Jumat.");
    }

    #[test]
    fn a_trailing_full_stop_is_not_part_of_the_address() {
        let text = "alamatnya budi@contoh.go.id.";
        assert_eq!(redact(text, &all()), "alamatnya [EMAIL].");
    }

    #[test]
    fn npwp_is_masked_in_both_notations() {
        assert_eq!(kinds("NPWP 012345678901234"), vec![PiiKind::Npwp]);
        assert_eq!(kinds("NPWP 01.234.567.8-901.234"), vec![PiiKind::Npwp]);
    }

    #[test]
    fn an_account_number_with_a_bank_nearby_is_masked() {
        for text in [
            "transfer ke rekening 1234567890 atas nama Budi",
            "No. Rek 8810023456 BCA",
            "rekening BRI 003801000123456",
            "virtual account 8808123456789012",
        ] {
            assert!(
                kinds(text).contains(&PiiKind::BankAccount) || kinds(text).contains(&PiiKind::Nik),
                "{text} must be masked, got {:?}",
                kinds(text)
            );
        }
    }

    #[test]
    fn listed_names_are_masked_wherever_they_appear() {
        let config = RedactionConfig {
            names: vec!["Budi Santoso".into(), "Siti".into()],
            ..RedactionConfig::default()
        };
        let text = "Budi Santoso dan Siti hadir. budi santoso memimpin rapat.";
        assert_eq!(
            redact(text, &config),
            "[NAMA] dan [NAMA] hadir. [NAMA] memimpin rapat."
        );
    }

    // --- what must NOT be masked ---------------------------------------
    //
    // These outnumber the tests above on purpose. A notulen with a
    // redacted budget figure is unusable, and unlike a missed NIK the
    // user cannot even tell what was taken.

    #[test]
    fn money_amounts_survive() {
        for text in [
            "anggaran Rp 1.500.000.000 untuk tahun depan",
            "biaya operasional 250000000 rupiah",
            "harga satuannya 125000",
            "total 15.000.000",
        ] {
            assert!(
                find_pii(text, &all()).is_empty(),
                "{text} must not be redacted, got {:?}",
                kinds(text)
            );
        }
    }

    #[test]
    fn dates_times_and_counts_survive() {
        for text in [
            "rapat tanggal 4 Oktober 2026 pukul 09:30",
            "kuartal 4 tahun 2026",
            "ada 120 peserta yang hadir",
            "agenda nomor 3 dan 4",
            "pasal 27 ayat 3",
            "UU No. 27 Tahun 2022 tentang PDP",
        ] {
            assert!(
                find_pii(text, &all()).is_empty(),
                "{text} must not be redacted, got {:?}",
                kinds(text)
            );
        }
    }

    #[test]
    fn a_bare_ten_digit_number_without_a_bank_nearby_survives() {
        // In a rapat this is a budget line far more often than a rekening.
        assert!(find_pii("nilainya 1234567890", &all()).is_empty());
    }

    #[test]
    fn a_bank_mentioned_a_paragraph_earlier_does_not_reach() {
        let text = "Rekening lama sudah ditutup bulan lalu oleh bagian keuangan \
                    kami. Anggaran tahun ini 1500000000 rupiah.";
        assert!(find_pii(text, &all()).is_empty(), "got {:?}", kinds(text));
    }

    #[test]
    fn a_sixteen_digit_number_with_an_impossible_province_is_not_a_nik() {
        // 99 is not a province code; this is a transaction reference.
        assert!(find_pii("referensi 9912345678901234", &all()).is_empty());
    }

    #[test]
    fn a_short_name_entry_is_ignored() {
        // Masking every "di" would redact the transcript, not the PII.
        let config = RedactionConfig {
            names: vec!["Di".into(), "AB".into()],
            ..RedactionConfig::default()
        };
        assert_eq!(
            redact("Di ruang rapat AB hadir semua", &config),
            "Di ruang rapat AB hadir semua"
        );
    }

    #[test]
    fn a_name_inside_a_longer_word_is_not_a_match() {
        let config = RedactionConfig {
            names: vec!["Ani".into()],
            ..RedactionConfig::default()
        };
        assert_eq!(
            redact("Panitia animasi sudah siap, Ani yang pimpin", &config),
            "Panitia animasi sudah siap, [NAMA] yang pimpin"
        );
    }

    #[test]
    fn an_at_sign_in_a_time_is_not_an_email() {
        assert!(find_pii("mulai 09@30 katanya", &all()).is_empty());
    }

    // --- configuration -------------------------------------------------

    #[test]
    fn a_disabled_category_is_left_alone() {
        let config = RedactionConfig {
            nik: true,
            ..RedactionConfig::default()
        };
        let text = "NIK 3174012509800003 dan email budi@contoh.go.id";
        assert_eq!(
            redact(text, &config),
            "NIK [NIK] dan email budi@contoh.go.id"
        );
    }

    #[test]
    fn an_empty_config_changes_nothing() {
        let text = "NIK 3174012509800003 hp 081234567890";
        assert_eq!(redact(text, &RedactionConfig::default()), text);
        assert!(find_pii(text, &RedactionConfig::default()).is_empty());
    }

    // --- mechanics ------------------------------------------------------

    #[test]
    fn several_kinds_in_one_line_are_all_masked_in_order() {
        let text = "Peserta: NIK 3174012509800003, HP 081234567890, \
                    email budi@contoh.go.id.";
        assert_eq!(
            kinds(text),
            vec![PiiKind::Nik, PiiKind::Phone, PiiKind::Email]
        );
        assert_eq!(
            redact(text, &all()),
            "Peserta: NIK [NIK], HP [NOMOR TELEPON], email [EMAIL]."
        );
    }

    #[test]
    fn offsets_point_at_the_text_they_claim() {
        let text = "hubungi 081234567890 sekarang";
        let found = find_pii(text, &all());
        let single = found.first().expect("one match");
        assert_eq!(
            &text[single.start as usize..single.end as usize],
            "081234567890"
        );
        assert_eq!(single.text, "081234567890");
    }

    #[test]
    fn overlapping_matches_keep_the_more_specific_one() {
        // A NIK that a bank keyword also vouches for is still a NIK.
        let found = find_pii("rekening 3174012509800003", &all());
        assert_eq!(found.len(), 1);
        assert_eq!(found[0].kind, PiiKind::Nik);
    }

    #[test]
    fn redaction_is_idempotent() {
        let text = "NIK 3174012509800003 hp 081234567890";
        let once = redact(text, &all());
        assert_eq!(redact(&once, &all()), once);
    }

    #[test]
    fn non_ascii_text_does_not_panic_or_corrupt() {
        let text = "Pak Müller — NIK 3174012509800003 — hadir ✓";
        let out = redact(text, &all());
        assert!(out.contains("[NIK]"));
        assert!(out.contains("Müller"));
        assert!(out.contains('✓'));
    }

    #[test]
    fn segments_are_redacted_in_place_and_reported() {
        let mut segments = vec![
            seg("NIK saya 3174012509800003."),
            seg("Rapat dimulai pukul sembilan."),
            seg("Email: budi@contoh.go.id"),
        ];
        let found = redact_segments(&mut segments, &all());
        assert_eq!(found.len(), 2);
        assert_eq!(segments[0].text, "NIK saya [NIK].");
        assert_eq!(segments[1].text, "Rapat dimulai pukul sembilan.");
        assert_eq!(segments[2].text, "Email: [EMAIL]");
    }

    fn seg(text: &str) -> crate::export::Segment {
        crate::export::Segment {
            source: "spk".into(),
            speaker: "Peserta 1".into(),
            text: text.into(),
            timestamp: 0.0,
            duration: 1.0,
            language: "id".into(),
            confidence: 0.9,
            avg_log_prob: -0.3,
            is_partial: false,
            low_confidence: false,
            words: Vec::new(),
        }
    }
}
