//! "Periksa fakta" — flags notulen statements the transcript does not
//! support.
//!
//! # The failure this exists to catch
//!
//! A local 4B model asked for a notulen will, reliably, produce one.
//! Asked for a notulen of a meeting where nothing was decided, it will
//! *still* produce decisions, because "## Keputusan" is in the prompt and
//! an empty section looks like a failure to the model. The invented
//! decision is written in the same formal register as the real ones and
//! arrives in a document that is about to be signed and archived.
//!
//! So nothing here trusts the model. Every keputusan, every tugas and
//! every penanggung jawab is checked back against the transcript, and
//! what cannot be traced is reported to the notulis before export.
//!
//! # What "supported" means
//!
//! Three independent checks, each catching a different kind of
//! invention — from `naskah-dinas` QA practice, where "fakta harus
//! terverifikasi" is the rule a telaahan staf lives or dies by:
//!
//! 1. **Provenance.** A claim should cite the segments it came from. A
//!    citation outside the transcript's range is a fabrication the model
//!    dressed as proof ([`FaktaMasalah::RujukanTidakSah`]).
//! 2. **Lexical support.** The claim's content words must actually occur
//!    in the cited segments, or — for an uncited claim — somewhere in the
//!    transcript ([`FaktaMasalah::DukunganLemah`]).
//! 3. **Entities.** Numbers and proper names are what a notulen is read
//!    for and what a model invents most confidently: a deadline nobody
//!    said, a percentage off by a factor of ten, a penanggung jawab who
//!    was not in the room ([`FaktaMasalah::AngkaTidakAda`],
//!    [`FaktaMasalah::NamaTidakAda`]).
//!
//! # What it deliberately does not do
//!
//! It does not reject. A low-overlap finding can be a correct summary of
//! a long exchange that happens to share few words with it — the same
//! caveat [`crate::provenance::verify_citations`] documents. The output
//! is a list the notulis reads, not a gate that silently deletes
//! sections.

use serde::Serialize;

use crate::export::Segment;
use crate::notulen::schema::NotulenJson;

/// Why one statement was flagged.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
pub enum FaktaMasalah {
    /// No `segmen` cited at all. Mild: the statement may still be true.
    TanpaRujukan,
    /// A cited segment number does not exist in this transcript.
    RujukanTidakSah,
    /// Too few of the statement's content words occur in its evidence.
    DukunganLemah,
    /// A number in the statement is nowhere in the transcript.
    AngkaTidakAda,
    /// A proper name in the statement is nowhere in the transcript.
    NamaTidakAda,
}

impl FaktaMasalah {
    /// Short Indonesian label for the UI chip.
    #[flutter_rust_bridge::frb(ignore)]
    pub fn label(self) -> &'static str {
        match self {
            Self::TanpaRujukan => "Tanpa rujukan segmen",
            Self::RujukanTidakSah => "Rujukan segmen tidak ada",
            Self::DukunganLemah => "Dukungan transkrip lemah",
            Self::AngkaTidakAda => "Angka tidak ada di transkrip",
            Self::NamaTidakAda => "Nama tidak ada di transkrip",
        }
    }

    /// Whether this finding should block an unreviewed export.
    ///
    /// An invented number or name, and a citation that points nowhere,
    /// are factual errors. A missing citation is a documentation gap.
    #[flutter_rust_bridge::frb(ignore)]
    pub fn berat(self) -> bool {
        matches!(
            self,
            Self::RujukanTidakSah | Self::AngkaTidakAda | Self::NamaTidakAda
        )
    }
}

/// One flagged statement.
#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct TemuanFakta {
    /// Section heading the statement came from, in Indonesian.
    pub bagian: String,
    /// The statement, verbatim.
    pub pernyataan: String,
    pub masalah: FaktaMasalah,
    /// What exactly was not found, so the notulis can check it.
    pub rincian: String,
}

/// The result of a whole "Periksa fakta" pass.
#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct LaporanFakta {
    pub temuan: Vec<TemuanFakta>,
    /// Statements examined.
    pub diperiksa: u32,
    /// Statements with no finding at all.
    pub bersih: u32,
}

impl LaporanFakta {
    /// `0.0..=1.0`: the fraction of statements with no finding.
    #[flutter_rust_bridge::frb(ignore)]
    pub fn skor(&self) -> f64 {
        if self.diperiksa == 0 {
            return 1.0;
        }
        f64::from(self.bersih) / f64::from(self.diperiksa)
    }

    /// Findings serious enough to warn about before export.
    #[flutter_rust_bridge::frb(ignore)]
    pub fn temuan_berat(&self) -> usize {
        self.temuan.iter().filter(|t| t.masalah.berat()).count()
    }
}

/// Minimum fraction of a claim's content words that must occur in its
/// evidence.
///
/// 0.35 rather than a majority: a one-sentence keputusan distilled from a
/// two-minute exchange legitimately reuses only a third of its words,
/// and a stricter bar flagged correct summaries faster than invented
/// ones. Measured against the `ml/notulen_bench` set, see
/// `ml/NOTULEN-BENCHMARK.md`.
pub const MIN_DUKUNGAN: f64 = 0.35;

/// Indonesian function words. Counting them would make every statement
/// look supported, since a transcript contains all of them.
const STOPWORDS: &[&str] = &[
    "yang", "dan", "dari", "untuk", "pada", "dengan", "ini", "itu", "adalah", "akan", "sudah",
    "telah", "tidak", "ada", "juga", "oleh", "atau", "dalam", "kita", "kami", "saya", "bahwa",
    "agar", "serta", "para", "bagi", "dapat", "harus", "lebih", "masih", "kepada", "sebagai",
    "tentang", "setelah", "sebelum", "karena", "sehingga", "antara", "secara", "bisa", "perlu",
    "saja", "maka", "hal", "sesuai", "terkait", "rapat",
];

/// Reduces an Indonesian word to a rough root.
///
/// Affixation is why a naive word match fails here. A speaker says
/// "kita setujui"; the notulen writes "disetujui"; a literal comparison
/// sees two different words and reports a correct decision as
/// unsupported. Measured on the `ml/notulen_bench` set, stemming moved
/// correct-decision overlap from roughly a third to roughly two thirds —
/// the difference between a report nobody can trust and a usable one.
///
/// This is a deliberately small subset of Nazief-Adriani: the common
/// derivational affixes plus the four morphophonemic restorations
/// (`meny-`→`s`, `meng-`→∅, `mem-`→∅, `men-`→∅). It over-stems. For a
/// fuzzy overlap score that is the right trade: a spurious match costs a
/// missed finding, while a missed match costs a false accusation of
/// invention, and the second is what makes users stop reading the report.
fn stem(word: &str) -> String {
    const SUFFIXES: &[&str] = &["nya", "lah", "kah", "pun", "kan", "an", "i"];
    // Longest first: `mem` must not win over `memper`.
    const PREFIXES: &[&str] = &[
        "memper", "diper", "meny", "meng", "peny", "peng", "mem", "men", "pem", "pen", "ber",
        "bel", "ter", "tel", "per", "pel", "di", "ke", "se", "me", "pe",
    ];
    let mut root = word.to_string();
    // One suffix: stacking more strips real words down to two letters.
    for suffix in SUFFIXES {
        if let Some(shorter) = root.strip_suffix(suffix) {
            if shorter.chars().count() >= 4 {
                root = shorter.to_string();
                break;
            }
        }
    }
    // Prefixes *do* stack, and have to be stripped to a fixed point:
    // `disetujui` reaches `setuju` after one pass while the transcript's
    // own `setuju` would stay put, and two words that mean the same thing
    // would stem differently — which is the bug stemming exists to fix.
    loop {
        let before = root.clone();
        for prefix in PREFIXES {
            let Some(shorter) = root.strip_prefix(prefix) else {
                continue;
            };
            if shorter.chars().count() < 3 {
                continue;
            }
            // `menyetujui` → `setuju`, not `etuju`: the `s` that nasal
            // assimilation swallowed is restored.
            root = if matches!(*prefix, "meny" | "peny") {
                format!("s{shorter}")
            } else {
                shorter.to_string()
            };
            break;
        }
        if root == before {
            return root;
        }
    }
}

/// Content words of `text`, lowercased and stemmed.
///
/// Stopwords are removed *before* stemming: the stems of function words
/// collide with content roots ("dalam" → "alam").
fn content_words(text: &str) -> Vec<String> {
    text.to_lowercase()
        .split(|c: char| !c.is_alphanumeric())
        .filter(|word| word.chars().count() > 2 && !STOPWORDS.contains(word))
        .map(stem)
        .collect()
}

/// Fraction of `claim`'s content words present in `evidence`.
fn overlap(claim: &str, evidence: &[String]) -> f64 {
    let words = content_words(claim);
    if words.is_empty() {
        // Nothing checkable: a claim of only function words and digits is
        // handled by the number check instead.
        return 1.0;
    }
    let hits = words
        .iter()
        .filter(|word| evidence.iter().any(|other| other == *word))
        .count();
    hits as f64 / words.len() as f64
}

/// Every number in `text`, as written.
fn numbers(text: &str) -> Vec<String> {
    let mut out = Vec::new();
    let mut current = String::new();
    for ch in text.chars().chain(std::iter::once(' ')) {
        if ch.is_ascii_digit() {
            current.push(ch);
        } else if (ch == '.' || ch == ',') && !current.is_empty() {
            // Keep thousands separators and decimal commas inside the
            // token: "8.500.000" is one number, not three.
            current.push(ch);
        } else {
            if !current.is_empty() {
                let trimmed = current.trim_end_matches(['.', ',']).to_string();
                if !trimmed.is_empty() {
                    out.push(trimmed);
                }
            }
            current.clear();
        }
    }
    out
}

/// Indonesian spellings of the digits a transcript is likely to contain
/// as words where the notulen writes them as figures.
///
/// A speaker says "empat persen"; a competent notulen writes "4 persen".
/// Flagging that as an invented number would make the check useless, so
/// the word form counts as support for the figure.
const ANGKA_KATA: &[(&str, &str)] = &[
    ("0", "nol"),
    ("1", "satu"),
    ("2", "dua"),
    ("3", "tiga"),
    ("4", "empat"),
    ("5", "lima"),
    ("6", "enam"),
    ("7", "tujuh"),
    ("8", "delapan"),
    ("9", "sembilan"),
    ("10", "sepuluh"),
    ("11", "sebelas"),
    ("12", "dua belas"),
    ("15", "lima belas"),
    ("20", "dua puluh"),
    ("30", "tiga puluh"),
    ("50", "lima puluh"),
    ("100", "seratus"),
    ("1000", "seribu"),
];

/// Whether `number` as written, or its Indonesian word form, occurs in
/// the transcript.
fn number_supported(number: &str, haystack_lower: &str) -> bool {
    if haystack_lower.contains(number) {
        return true;
    }
    // "8.500.000" spoken as "delapan setengah juta" is not recoverable,
    // but "8500000" written without separators is.
    let bare: String = number.chars().filter(char::is_ascii_digit).collect();
    if !bare.is_empty() && bare != number && haystack_lower.contains(&bare) {
        return true;
    }
    ANGKA_KATA
        .iter()
        .find(|(digit, _)| *digit == number)
        .is_some_and(|(_, word)| haystack_lower.contains(word))
}

/// Name-shaped tokens: capitalised words that are not the first word of
/// a sentence and not ordinary vocabulary that happens to be capitalised.
///
/// Deliberately conservative. A false "invented name" finding on every
/// notulen would train the user to ignore the whole report, which costs
/// more than the occasional missed invention.
fn proper_names(text: &str) -> Vec<String> {
    /// Capitalised words that are not personal names: months, dinas
    /// vocabulary, institutions, and the section headings themselves.
    const BUKAN_NAMA: &[&str] = &[
        "januari",
        "februari",
        "maret",
        "april",
        "mei",
        "juni",
        "juli",
        "agustus",
        "september",
        "oktober",
        "november",
        "desember",
        "senin",
        "selasa",
        "rabu",
        "kamis",
        "jumat",
        "sabtu",
        "minggu",
        "rapat",
        "notulen",
        "notula",
        "risalah",
        "berita",
        "acara",
        "keputusan",
        "kesimpulan",
        "pembahasan",
        "tindak",
        "lanjut",
        "peserta",
        "agenda",
        "pimpinan",
        "notulis",
        "sekretaris",
        "ketua",
        "kepala",
        "direktur",
        "direktorat",
        "jenderal",
        "kementerian",
        "sekretariat",
        "biro",
        "bagian",
        "subbagian",
        "bidang",
        "unit",
        "kerja",
        "tim",
        "panitia",
        "kelompok",
        "lampiran",
        "nomor",
        "tanggal",
        "waktu",
        "tempat",
        "hari",
        "pukul",
        "wib",
        "wita",
        "wit",
        "indonesia",
        "republik",
        "pemerintah",
        "daerah",
        "provinsi",
        "kabupaten",
        "kota",
        "jakarta",
        "bapak",
        "ibu",
        "saudara",
        "yth",
        "dan",
        "atau",
        "dengan",
        "untuk",
        "pada",
        "dari",
        "oleh",
        "sebagai",
        "yang",
        "akan",
        "telah",
        "tidak",
        "dalam",
        "para",
        "seluruh",
        "semua",
    ];

    let mut names = Vec::new();
    for sentence in text.split(['.', '!', '?', '\n', ';', ':']) {
        let words: Vec<&str> = sentence.split_whitespace().collect();
        for (index, word) in words.iter().enumerate() {
            let clean = word.trim_matches(|c: char| !c.is_alphanumeric());
            if clean.chars().count() < 3 {
                continue;
            }
            let mut chars = clean.chars();
            let first_upper = chars.next().is_some_and(char::is_uppercase);
            // ALL CAPS is a heading or an acronym, not a personal name.
            let all_upper = clean
                .chars()
                .filter(|c| c.is_alphabetic())
                .all(char::is_uppercase);
            if !first_upper || all_upper {
                continue;
            }
            // The first word of a sentence is capitalised by grammar.
            if index == 0 {
                continue;
            }
            if BUKAN_NAMA.contains(&clean.to_lowercase().as_str()) {
                continue;
            }
            names.push(clean.to_string());
        }
    }
    names.sort();
    names.dedup();
    names
}

/// One statement to check, with the section it belongs to.
struct Pernyataan<'a> {
    bagian: &'static str,
    teks: String,
    segmen: &'a [u32],
    /// Only `keputusan` and `tindak_lanjut` get the entity checks: a
    /// pembahasan paragraph legitimately paraphrases, and running name
    /// detection over prose produces noise rather than findings.
    periksa_entitas: bool,
}

/// Runs the whole pass.
#[flutter_rust_bridge::frb(ignore)]
pub fn periksa(notulen: &NotulenJson, segments: &[Segment]) -> LaporanFakta {
    let usable: Vec<&Segment> = segments.iter().filter(|s| !s.is_partial).collect();
    let transcript: String = usable
        .iter()
        .map(|s| s.text.trim())
        .collect::<Vec<_>>()
        .join(" ");
    let transcript_lower = transcript.to_lowercase();
    let transcript_words = content_words(&transcript);

    let mut statements: Vec<Pernyataan> = Vec::new();
    for item in &notulen.keputusan {
        statements.push(Pernyataan {
            bagian: "Keputusan",
            teks: item.isi.clone(),
            segmen: &item.segmen,
            periksa_entitas: true,
        });
    }
    for item in &notulen.tindak_lanjut {
        let mut teks = item.tugas.clone();
        if !item.penanggung_jawab.is_empty() {
            teks.push_str(" — penanggung jawab ");
            teks.push_str(&item.penanggung_jawab);
        }
        if !item.tenggat.is_empty() {
            teks.push_str(", tenggat ");
            teks.push_str(&item.tenggat);
        }
        statements.push(Pernyataan {
            bagian: "Tindak Lanjut",
            teks,
            segmen: &item.segmen,
            periksa_entitas: true,
        });
    }
    for item in &notulen.pembahasan {
        statements.push(Pernyataan {
            bagian: "Pembahasan",
            teks: item.uraian.clone(),
            segmen: &item.segmen,
            periksa_entitas: false,
        });
    }
    for item in &notulen.jalannya_rapat {
        statements.push(Pernyataan {
            bagian: "Jalannya Rapat",
            teks: item.pokok.clone(),
            segmen: &item.segmen,
            periksa_entitas: false,
        });
    }

    let mut temuan = Vec::new();
    let mut diperiksa = 0u32;
    let mut bersih = 0u32;

    for statement in statements {
        if statement.teks.trim().is_empty() {
            continue;
        }
        diperiksa += 1;
        let before = temuan.len();

        // --- provenance ---------------------------------------------------
        let mut valid_ids: Vec<u32> = Vec::new();
        for &id in statement.segmen {
            match id
                .checked_sub(1)
                .and_then(|index| usable.get(index as usize))
            {
                Some(_) => valid_ids.push(id),
                None => temuan.push(TemuanFakta {
                    bagian: statement.bagian.to_string(),
                    pernyataan: statement.teks.clone(),
                    masalah: FaktaMasalah::RujukanTidakSah,
                    rincian: format!(
                        "segmen [{id}] tidak ada; transkrip punya {} segmen",
                        usable.len()
                    ),
                }),
            }
        }
        if statement.segmen.is_empty() {
            temuan.push(TemuanFakta {
                bagian: statement.bagian.to_string(),
                pernyataan: statement.teks.clone(),
                masalah: FaktaMasalah::TanpaRujukan,
                rincian: "model tidak menyebut segmen transkrip untuk pernyataan ini".to_string(),
            });
        }

        // --- lexical support ----------------------------------------------
        let evidence: Vec<String> = if valid_ids.is_empty() {
            transcript_words.clone()
        } else {
            valid_ids
                .iter()
                .filter_map(|&id| usable.get((id - 1) as usize))
                .flat_map(|segment| content_words(&segment.text))
                .collect()
        };
        let score = overlap(&statement.teks, &evidence);
        if score < MIN_DUKUNGAN {
            temuan.push(TemuanFakta {
                bagian: statement.bagian.to_string(),
                pernyataan: statement.teks.clone(),
                masalah: FaktaMasalah::DukunganLemah,
                rincian: format!(
                    "hanya {:.0}% kata kunci pernyataan ini muncul di {}",
                    score * 100.0,
                    if valid_ids.is_empty() {
                        "transkrip".to_string()
                    } else {
                        format!("segmen yang dirujuk ({valid_ids:?})")
                    }
                ),
            });
        }

        // --- entities ------------------------------------------------------
        if statement.periksa_entitas {
            for number in numbers(&statement.teks) {
                if !number_supported(&number, &transcript_lower) {
                    temuan.push(TemuanFakta {
                        bagian: statement.bagian.to_string(),
                        pernyataan: statement.teks.clone(),
                        masalah: FaktaMasalah::AngkaTidakAda,
                        rincian: format!("angka \"{number}\" tidak ditemukan di transkrip"),
                    });
                }
            }
            for name in proper_names(&statement.teks) {
                if !transcript_lower.contains(&name.to_lowercase()) {
                    temuan.push(TemuanFakta {
                        bagian: statement.bagian.to_string(),
                        pernyataan: statement.teks.clone(),
                        masalah: FaktaMasalah::NamaTidakAda,
                        rincian: format!("nama \"{name}\" tidak ditemukan di transkrip"),
                    });
                }
            }
        }

        if temuan.len() == before {
            bersih += 1;
        }
    }

    LaporanFakta {
        temuan,
        diperiksa,
        bersih,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::notulen::schema;

    fn seg(text: &str, ts: f64) -> Segment {
        Segment {
            source: "mic".into(),
            speaker: "Pimpinan".into(),
            text: text.into(),
            timestamp: ts,
            duration: 5.0,
            language: "id".into(),
            confidence: 0.9,
            avg_log_prob: -0.3,
            is_partial: false,
            low_confidence: false,
            words: Vec::new(),
        }
    }

    fn transcript() -> Vec<Segment> {
        vec![
            seg(
                "selamat pagi, rapat koordinasi penyusunan anggaran kita mulai",
                0.0,
            ),
            seg(
                "pagu indikatif tahun depan naik empat persen dibanding tahun ini",
                10.0,
            ),
            seg("saya setuju pagu itu kita setujui hari ini", 20.0),
            seg(
                "Budi tolong susun draf rencana kerja sebelum sepuluh Oktober",
                30.0,
            ),
            seg("baik, saya akan susun draf rencana kerja itu", 40.0),
        ]
    }

    #[test]
    fn a_well_cited_decision_passes_clean() {
        let notulen = schema::parse(
            r#"{"keputusan": [{"isi": "Pagu indikatif disetujui.", "segmen": [3]}]}"#,
        )
        .unwrap()
        .notulen;
        let report = periksa(&notulen, &transcript());
        assert_eq!(report.diperiksa, 1);
        assert_eq!(report.bersih, 1, "findings: {:?}", report.temuan);
        assert!((report.skor() - 1.0).abs() < 1e-9);
    }

    #[test]
    fn an_invented_decision_is_flagged_as_weakly_supported() {
        let notulen = schema::parse(
            r#"{"keputusan": [{"isi": "Kantor memutuskan membeli kendaraan operasional baru.", "segmen": [2]}]}"#,
        )
        .unwrap()
        .notulen;
        let report = periksa(&notulen, &transcript());
        assert_eq!(report.bersih, 0);
        assert!(report
            .temuan
            .iter()
            .any(|t| t.masalah == FaktaMasalah::DukunganLemah));
    }

    #[test]
    fn a_citation_past_the_end_of_the_transcript_is_flagged() {
        let notulen =
            schema::parse(r#"{"keputusan": [{"isi": "Pagu disetujui.", "segmen": [99]}]}"#)
                .unwrap()
                .notulen;
        let report = periksa(&notulen, &transcript());
        let finding = report
            .temuan
            .iter()
            .find(|t| t.masalah == FaktaMasalah::RujukanTidakSah)
            .expect("not flagged");
        assert!(finding.rincian.contains("99"));
        assert!(finding.rincian.contains('5'), "says how many exist");
        assert!(finding.masalah.berat());
    }

    #[test]
    fn segment_zero_does_not_panic() {
        // A model that counts from zero used to underflow the id.
        let notulen =
            schema::parse(r#"{"keputusan": [{"isi": "Pagu disetujui.", "segmen": [0]}]}"#)
                .unwrap()
                .notulen;
        let report = periksa(&notulen, &transcript());
        assert!(report
            .temuan
            .iter()
            .any(|t| t.masalah == FaktaMasalah::RujukanTidakSah));
    }

    #[test]
    fn an_uncited_statement_is_noted_but_checked_against_the_whole_transcript() {
        let notulen = schema::parse(r#"{"keputusan": [{"isi": "Pagu indikatif disetujui."}]}"#)
            .unwrap()
            .notulen;
        let report = periksa(&notulen, &transcript());
        assert!(report
            .temuan
            .iter()
            .any(|t| t.masalah == FaktaMasalah::TanpaRujukan));
        // …and not also flagged as unsupported, because it is supported.
        assert!(!report
            .temuan
            .iter()
            .any(|t| t.masalah == FaktaMasalah::DukunganLemah));
        assert!(!report.temuan[0].masalah.berat(), "a gap, not an error");
    }

    #[test]
    fn a_number_nobody_said_is_flagged() {
        let notulen = schema::parse(
            r#"{"keputusan": [{"isi": "Pagu indikatif naik 40 persen.", "segmen": [2]}]}"#,
        )
        .unwrap()
        .notulen;
        let report = periksa(&notulen, &transcript());
        let finding = report
            .temuan
            .iter()
            .find(|t| t.masalah == FaktaMasalah::AngkaTidakAda)
            .expect("not flagged");
        assert!(finding.rincian.contains("40"));
    }

    #[test]
    fn a_figure_spoken_as_an_indonesian_word_counts_as_support() {
        // The transcript says "empat persen"; writing "4 persen" is what a
        // competent notulen does and must not be flagged.
        let notulen = schema::parse(
            r#"{"keputusan": [{"isi": "Pagu indikatif naik 4 persen.", "segmen": [2]}]}"#,
        )
        .unwrap()
        .notulen;
        let report = periksa(&notulen, &transcript());
        assert!(
            !report
                .temuan
                .iter()
                .any(|t| t.masalah == FaktaMasalah::AngkaTidakAda),
            "findings: {:?}",
            report.temuan
        );
    }

    #[test]
    fn an_invented_penanggung_jawab_is_flagged_by_name() {
        let notulen = schema::parse(
            r#"{"tindak_lanjut": [{"tugas": "Susun draf rencana kerja", "penanggung_jawab": "Rina Marlina", "tenggat": "10 Oktober", "segmen": [4]}]}"#,
        )
        .unwrap()
        .notulen;
        let report = periksa(&notulen, &transcript());
        let names: Vec<&str> = report
            .temuan
            .iter()
            .filter(|t| t.masalah == FaktaMasalah::NamaTidakAda)
            .map(|t| t.rincian.as_str())
            .collect();
        assert!(
            names.iter().any(|r| r.contains("Rina")),
            "an owner who was never mentioned must be flagged: {names:?}"
        );
    }

    #[test]
    fn a_real_penanggung_jawab_is_not_flagged() {
        let notulen = schema::parse(
            r#"{"tindak_lanjut": [{"tugas": "Susun draf rencana kerja", "penanggung_jawab": "Budi", "tenggat": "10 Oktober", "segmen": [4]}]}"#,
        )
        .unwrap()
        .notulen;
        let report = periksa(&notulen, &transcript());
        assert_eq!(report.bersih, 1, "findings: {:?}", report.temuan);
    }

    #[test]
    fn month_names_and_dinas_vocabulary_are_not_treated_as_personal_names() {
        // "Oktober" is in the transcript, but "Keputusan Rapat Koordinasi"
        // style vocabulary is not — and must not be reported as invented.
        let notulen = schema::parse(
            r#"{"keputusan": [{"isi": "Pagu indikatif disetujui pada Rapat Koordinasi hari Senin.", "segmen": [3]}]}"#,
        )
        .unwrap()
        .notulen;
        let report = periksa(&notulen, &transcript());
        assert!(
            !report
                .temuan
                .iter()
                .any(|t| t.masalah == FaktaMasalah::NamaTidakAda),
            "findings: {:?}",
            report.temuan
        );
    }

    #[test]
    fn prose_sections_are_not_entity_checked() {
        // Pembahasan paraphrases; name detection over prose is noise.
        let notulen = schema::parse(
            r#"{"pembahasan": [{"topik": "Pagu", "uraian": "Pagu indikatif naik empat persen menurut Kementerian Keuangan.", "segmen": [2]}]}"#,
        )
        .unwrap()
        .notulen;
        let report = periksa(&notulen, &transcript());
        assert!(!report
            .temuan
            .iter()
            .any(|t| t.masalah == FaktaMasalah::NamaTidakAda));
    }

    #[test]
    fn an_empty_notulen_scores_one_rather_than_dividing_by_zero() {
        let report = periksa(&NotulenJson::default(), &transcript());
        assert_eq!(report.diperiksa, 0);
        assert!((report.skor() - 1.0).abs() < 1e-9);
        assert_eq!(report.temuan_berat(), 0);
    }

    #[test]
    fn partial_segments_are_not_citable_evidence() {
        // The live quick pass is superseded; citing it would let a model
        // point at text the finished transcript does not contain.
        let mut segments = transcript();
        let mut partial = seg("kita beli kendaraan operasional baru", 50.0);
        partial.is_partial = true;
        segments.push(partial);
        let notulen = schema::parse(
            r#"{"keputusan": [{"isi": "Membeli kendaraan operasional baru.", "segmen": [6]}]}"#,
        )
        .unwrap()
        .notulen;
        let report = periksa(&notulen, &segments);
        assert!(report
            .temuan
            .iter()
            .any(|t| t.masalah == FaktaMasalah::RujukanTidakSah));
    }

    #[test]
    fn the_report_counts_statements_not_findings() {
        // One statement with three findings is still one dirty statement.
        let notulen = schema::parse(
            r#"{"keputusan": [{"isi": "Rina Marlina menyetujui anggaran 40 miliar.", "segmen": [99]}]}"#,
        )
        .unwrap()
        .notulen;
        let report = periksa(&notulen, &transcript());
        assert_eq!(report.diperiksa, 1);
        assert_eq!(report.bersih, 0);
        assert!(report.temuan.len() >= 3, "{:?}", report.temuan);
        assert!((report.skor() - 0.0).abs() < 1e-9);
    }

    // --- helpers ---------------------------------------------------------

    #[test]
    fn affixed_forms_of_one_root_stem_together() {
        // The whole point: what the speaker said and what the notulen
        // wrote must land on the same root.
        for group in [
            ["setuju", "setujui", "disetujui", "menyetujui"].as_slice(),
            ["susun", "menyusun", "penyusunan", "disusun"].as_slice(),
            ["anggaran", "menganggarkan"].as_slice(),
        ] {
            let stems: Vec<String> = group.iter().map(|w| stem(w)).collect();
            assert!(
                stems.windows(2).all(|pair| pair[0] == pair[1]),
                "{group:?} stemmed apart: {stems:?}"
            );
        }
    }

    #[test]
    fn stemming_is_a_fixed_point() {
        for word in ["disetujui", "penyusunan", "keputusan", "pemerintah"] {
            let once = stem(word);
            assert_eq!(stem(&once), once, "{word} keeps shrinking");
        }
    }

    #[test]
    fn stemming_leaves_short_words_alone() {
        // Over-stemming a four-letter word leaves noise that matches
        // everything.
        for word in ["pagu", "hari", "draf", "baru"] {
            assert_eq!(stem(word), word);
        }
    }

    #[test]
    fn numbers_keep_their_thousand_separators() {
        assert_eq!(
            numbers("Pagu Rp8.500.000,00 untuk 4 kegiatan."),
            vec!["8.500.000,00".to_string(), "4".to_string()]
        );
    }

    #[test]
    fn a_number_written_with_separators_matches_a_bare_one_in_the_transcript() {
        assert!(number_supported("8.500.000", "anggaran 8500000 rupiah"));
        assert!(!number_supported("9.500.000", "anggaran 8500000 rupiah"));
    }

    #[test]
    fn proper_names_skip_sentence_openers_and_acronyms() {
        let names = proper_names("Budi menyetujui usulan RKAKL. Siti Aminah menolak.");
        // "Budi" and "Siti" open their sentences; "Aminah" does not, and
        // "RKAKL" is an acronym.
        assert_eq!(names, vec!["Aminah".to_string()]);
    }
}
