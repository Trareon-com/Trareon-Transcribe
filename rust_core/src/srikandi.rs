//! SRIKANDI-ready export: the metadata a naskah needs to be registered.
//!
//! # What this is, and what it is not
//!
//! SRIKANDI (Sistem Informasi Kearsipan Dinamis Terintegrasi, the
//! mandatory government archiving application under KepmenPANRB
//! 679/2020) has no public API. There is an "API management" feature in
//! version 3, but no published endpoints, authentication or payload
//! format, and third-party access would need an arrangement with ANRI.
//!
//! So Trareon does **not** integrate with SRIKANDI and this module does
//! not claim to. What it does is remove the only real friction in the
//! manual path: a civil servant who exports a notulen then has to retype
//! its registration metadata into the application's form, from a
//! document that does not state most of it. This module produces that
//! metadata as a sidecar next to the document — JSON for a machine, CSV
//! for a spreadsheet — so the upload becomes copy-and-paste instead of
//! re-derivation.
//!
//! `docs/SRIKANDI-EXPORT.md` is the procedure, including the explicit
//! statement that the upload is manual.
//!
//! # Why the validator refuses to invent a nomor
//!
//! The field this module is most tempted to fill is `nomor`, and it is
//! the one field it must never fill. A naskah number comes from the
//! unit's Tata Usaha or its correspondence application; a plausible
//! invented number registers a document under an identifier that belongs
//! to a different one. [`validate`] therefore *flags* a nomor that still
//! holds a placeholder rather than generating one, and
//! [`nomor_shape_ok`] checks only the shape the Pedoman specifies
//! (`[sifat-]urut/KODE UNIT/KODE KLAS/MM/YYYY`).

use serde::{Deserialize, Serialize};

use crate::export::notulen::NotulenForm;
use crate::notulen::NotulenTemplate;

/// Kecepatan penyampaian, per the Pedoman Tata Naskah Dinas.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
pub enum Sifat {
    /// 24 jam.
    SangatSegera,
    /// 2 × 24 jam.
    Segera,
    #[default]
    Biasa,
}

impl Sifat {
    #[flutter_rust_bridge::frb(ignore)]
    pub fn label(self) -> &'static str {
        match self {
            Self::SangatSegera => "Sangat Segera",
            Self::Segera => "Segera",
            Self::Biasa => "Biasa",
        }
    }

    /// Prefix the Pedoman puts on a surat dinas number.
    ///
    /// Notula and berita acara are not numbered with a sifat prefix, so
    /// this is only used when the user chooses a surat-style nomor.
    #[flutter_rust_bridge::frb(ignore)]
    pub fn nomor_prefix(self) -> &'static str {
        match self {
            Self::SangatSegera => "SR",
            Self::Segera => "R",
            Self::Biasa => "B",
        }
    }

    #[flutter_rust_bridge::frb(ignore)]
    pub fn all() -> &'static [Sifat] {
        &[Self::SangatSegera, Self::Segera, Self::Biasa]
    }
}

/// Klasifikasi keamanan dan akses.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
pub enum KlasifikasiKeamanan {
    SangatRahasia,
    Rahasia,
    Terbatas,
    #[default]
    Biasa,
}

impl KlasifikasiKeamanan {
    #[flutter_rust_bridge::frb(ignore)]
    pub fn label(self) -> &'static str {
        match self {
            Self::SangatRahasia => "Sangat Rahasia",
            Self::Rahasia => "Rahasia",
            Self::Terbatas => "Terbatas",
            Self::Biasa => "Biasa",
        }
    }

    #[flutter_rust_bridge::frb(ignore)]
    pub fn all() -> &'static [KlasifikasiKeamanan] {
        &[
            Self::SangatRahasia,
            Self::Rahasia,
            Self::Terbatas,
            Self::Biasa,
        ]
    }
}

/// Tingkat perkembangan naskah.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
pub enum TingkatPerkembangan {
    #[default]
    Asli,
    Salinan,
    Tembusan,
    Pertinggal,
}

impl TingkatPerkembangan {
    #[flutter_rust_bridge::frb(ignore)]
    pub fn label(self) -> &'static str {
        match self {
            Self::Asli => "Asli",
            Self::Salinan => "Salinan",
            Self::Tembusan => "Tembusan",
            Self::Pertinggal => "Pertinggal",
        }
    }

    #[flutter_rust_bridge::frb(ignore)]
    pub fn all() -> &'static [TingkatPerkembangan] {
        &[Self::Asli, Self::Salinan, Self::Tembusan, Self::Pertinggal]
    }
}

/// The placeholder [`defaults_from_form`] puts in `nomor`.
///
/// Deliberately not a number: anything numeric would eventually be
/// uploaded as if it were real.
pub const NOMOR_PLACEHOLDER: &str = "…/[KODE UNIT]/[KODE KLASIFIKASI]/MM/YYYY";

/// Everything SRIKANDI's registration form asks for that a notulen does
/// not already state.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SrikandiMetadata {
    /// Nomor naskah, from the unit's Tata Usaha. Never generated.
    pub nomor: String,
    /// Written date, e.g. "5 Oktober 2026".
    pub tanggal: String,
    /// Jenis naskah dinas, e.g. "Notula Rapat".
    pub jenis_naskah: String,
    /// Hal / perihal, one line, no trailing full stop.
    pub perihal: String,
    pub sifat: Sifat,
    pub klasifikasi_keamanan: KlasifikasiKeamanan,
    /// Kode klasifikasi arsip, e.g. "UM.03.01". From the unit's
    /// klasifikasi-arsip pedoman, not derivable from the document.
    pub kode_klasifikasi_arsip: String,
    /// Unit pengolah — the unit that created the naskah.
    pub unit_pengolah: String,
    pub penandatangan_nama: String,
    pub penandatangan_jabatan: String,
    pub jumlah_lampiran: u32,
    pub tingkat_perkembangan: TingkatPerkembangan,
    /// Free-text note carried into the sidecar, e.g. a retention remark.
    pub catatan: String,
}

impl Default for SrikandiMetadata {
    fn default() -> Self {
        Self {
            nomor: NOMOR_PLACEHOLDER.to_string(),
            tanggal: String::new(),
            jenis_naskah: NotulenTemplate::default().jenis_naskah().to_string(),
            perihal: String::new(),
            sifat: Sifat::default(),
            klasifikasi_keamanan: KlasifikasiKeamanan::default(),
            kode_klasifikasi_arsip: String::new(),
            unit_pengolah: String::new(),
            penandatangan_nama: String::new(),
            penandatangan_jabatan: String::new(),
            jumlah_lampiran: 0,
            tingkat_perkembangan: TingkatPerkembangan::default(),
            catatan: String::new(),
        }
    }
}

/// Prefills what the notulen form already knows, and only that.
///
/// Fields the document cannot supply — kode klasifikasi arsip, unit
/// pengolah, the nomor — are left empty or placeholdered so the export
/// form shows the user exactly what still needs filling in.
#[flutter_rust_bridge::frb(ignore)]
pub fn defaults_from_form(form: &NotulenForm) -> SrikandiMetadata {
    SrikandiMetadata {
        nomor: if form.nomor.trim().is_empty() {
            NOMOR_PLACEHOLDER.to_string()
        } else {
            form.nomor.trim().to_string()
        },
        tanggal: form.tanggal.trim().to_string(),
        jenis_naskah: form.template.jenis_naskah().to_string(),
        perihal: form.judul.trim().trim_end_matches('.').to_string(),
        kode_klasifikasi_arsip: String::new(),
        unit_pengolah: form.unit_kerja.trim().to_string(),
        penandatangan_nama: form.pimpinan.trim().to_string(),
        penandatangan_jabatan: String::new(),
        jumlah_lampiran: u32::from(form.lampirkan_transkrip),
        ..SrikandiMetadata::default()
    }
}

/// How serious a validation finding is.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
pub enum Tingkat {
    /// The sidecar cannot be registered without this.
    Wajib,
    /// Registration will work; an archivist will ask about it.
    Saran,
}

/// One thing wrong with the metadata.
#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct TemuanMetadata {
    pub bidang: String,
    pub tingkat: Tingkat,
    pub pesan: String,
}

/// Whether `nomor` has the shape the Pedoman specifies:
/// `[sifat-]urut/KODE UNIT/KODE KLAS/MM/YYYY`.
///
/// Shape only. Whether the unit code and the klasifikasi are the right
/// ones is a question for the unit's archivist, and a checker that
/// pretended otherwise would be worse than none.
#[flutter_rust_bridge::frb(ignore)]
pub fn nomor_shape_ok(nomor: &str) -> bool {
    let trimmed = nomor.trim();
    if trimmed.is_empty() || trimmed.contains('[') || trimmed.contains('…') {
        return false;
    }
    // An optional `B-` / `R-` / `SR-` / `T-` sifat prefix sits before the
    // running number.
    let body = match trimmed.split_once('-') {
        Some((prefix, rest)) if matches!(prefix, "B" | "R" | "SR" | "T") => rest,
        _ => trimmed,
    };
    let parts: Vec<&str> = body.split('/').collect();
    if parts.len() != 5 {
        return false;
    }
    let running = parts[0];
    let month = parts[3];
    let year = parts[4];
    let all_digits = |s: &str| !s.is_empty() && s.chars().all(|c| c.is_ascii_digit());
    all_digits(running)
        && all_digits(month)
        && month.len() == 2
        && month.parse::<u32>().is_ok_and(|m| (1..=12).contains(&m))
        && all_digits(year)
        && year.len() == 4
        && parts[1..3].iter().all(|part| !part.trim().is_empty())
}

/// Checks the metadata against what registration needs.
#[flutter_rust_bridge::frb(ignore)]
pub fn validate(metadata: &SrikandiMetadata) -> Vec<TemuanMetadata> {
    let mut out: Vec<TemuanMetadata> = Vec::new();
    let mut push = |bidang: &str, tingkat: Tingkat, pesan: &str| {
        out.push(TemuanMetadata {
            bidang: bidang.to_string(),
            tingkat,
            pesan: pesan.to_string(),
        });
    };

    if !nomor_shape_ok(&metadata.nomor) {
        push(
            "nomor",
            Tingkat::Wajib,
            "Nomor naskah belum diisi atau belum sesuai bentuk \
             nomor/KODE UNIT/KODE KLASIFIKASI/MM/TTTT. Ambil nomor dari Tata \
             Usaha unit atau aplikasi persuratan — jangan menetapkannya sendiri.",
        );
    }
    if metadata.tanggal.trim().is_empty() {
        push("tanggal", Tingkat::Wajib, "Tanggal naskah belum diisi.");
    } else if !tanggal_shape_ok(&metadata.tanggal) {
        push(
            "tanggal",
            Tingkat::Saran,
            "Tanggal sebaiknya ditulis lengkap dengan nama bulan, \
             misalnya 5 Oktober 2026.",
        );
    }
    if metadata.perihal.trim().is_empty() {
        push("perihal", Tingkat::Wajib, "Hal/perihal belum diisi.");
    } else if metadata.perihal.trim().ends_with('.') {
        push(
            "perihal",
            Tingkat::Saran,
            "Hal ditulis tanpa tanda baca di akhir.",
        );
    }
    if metadata.kode_klasifikasi_arsip.trim().is_empty() {
        push(
            "kode_klasifikasi_arsip",
            Tingkat::Wajib,
            "Kode klasifikasi arsip belum diisi. Ambil dari pedoman \
             klasifikasi arsip unit Anda; kode ini menentukan retensi arsip.",
        );
    }
    if metadata.unit_pengolah.trim().is_empty() {
        push(
            "unit_pengolah",
            Tingkat::Wajib,
            "Unit pengolah belum diisi.",
        );
    }
    if metadata.penandatangan_jabatan.trim().is_empty() {
        push(
            "penandatangan_jabatan",
            Tingkat::Wajib,
            "Jabatan penanda tangan belum diisi. Nama jabatan pada baris \
             pertama tidak boleh disingkat.",
        );
    }
    if metadata.penandatangan_nama.trim().is_empty() {
        push(
            "penandatangan_nama",
            Tingkat::Saran,
            "Nama penanda tangan belum diisi.",
        );
    }
    out
}

/// `true` for "5 Oktober 2026" and friends.
fn tanggal_shape_ok(tanggal: &str) -> bool {
    const BULAN: &[&str] = &[
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
    ];
    let lower = tanggal.to_lowercase();
    let parts: Vec<&str> = lower.split_whitespace().collect();
    parts.len() == 3
        && parts[0].parse::<u32>().is_ok_and(|d| (1..=31).contains(&d))
        && BULAN.contains(&parts[1])
        && parts[2].len() == 4
        && parts[2].chars().all(|c| c.is_ascii_digit())
}

/// Whether the metadata is complete enough to register.
#[flutter_rust_bridge::frb(ignore)]
pub fn siap_unggah(metadata: &SrikandiMetadata) -> bool {
    !validate(metadata)
        .iter()
        .any(|t| t.tingkat == Tingkat::Wajib)
}

// ---------------------------------------------------------------------------
// The sidecar
// ---------------------------------------------------------------------------

/// Field order for both sidecar formats.
///
/// One list, used by the JSON writer and the CSV header, so the two
/// cannot drift — a CSV whose header does not match its row is worse
/// than no CSV.
const FIELDS: &[&str] = &[
    "nomor",
    "tanggal",
    "jenis_naskah",
    "perihal",
    "sifat",
    "klasifikasi_keamanan",
    "kode_klasifikasi_arsip",
    "unit_pengolah",
    "penandatangan_nama",
    "penandatangan_jabatan",
    "jumlah_lampiran",
    "tingkat_perkembangan",
    "catatan",
    "berkas_naskah",
    "dibuat_oleh",
];

fn value_for(metadata: &SrikandiMetadata, field: &str, berkas: &str) -> String {
    match field {
        "nomor" => metadata.nomor.trim().to_string(),
        "tanggal" => metadata.tanggal.trim().to_string(),
        "jenis_naskah" => metadata.jenis_naskah.trim().to_string(),
        "perihal" => metadata.perihal.trim().to_string(),
        "sifat" => metadata.sifat.label().to_string(),
        "klasifikasi_keamanan" => metadata.klasifikasi_keamanan.label().to_string(),
        "kode_klasifikasi_arsip" => metadata.kode_klasifikasi_arsip.trim().to_string(),
        "unit_pengolah" => metadata.unit_pengolah.trim().to_string(),
        "penandatangan_nama" => metadata.penandatangan_nama.trim().to_string(),
        "penandatangan_jabatan" => metadata.penandatangan_jabatan.trim().to_string(),
        "jumlah_lampiran" => metadata.jumlah_lampiran.to_string(),
        "tingkat_perkembangan" => metadata.tingkat_perkembangan.label().to_string(),
        "catatan" => metadata.catatan.trim().to_string(),
        "berkas_naskah" => berkas.to_string(),
        // Stated in the sidecar rather than inferred by whoever reads it:
        // an archivist needs to know a tool produced this.
        "dibuat_oleh" => "Trareon Transcribe (ekspor manual, bukan integrasi SRIKANDI)".to_string(),
        _ => String::new(),
    }
}

/// The sidecar as JSON, keys in [`FIELDS`] order.
#[flutter_rust_bridge::frb(ignore)]
pub fn to_json(metadata: &SrikandiMetadata, berkas: &str) -> String {
    let mut out = String::from("{\n");
    for (index, field) in FIELDS.iter().enumerate() {
        let value = value_for(metadata, field, berkas);
        let comma = if index + 1 == FIELDS.len() { "" } else { "," };
        if *field == "jumlah_lampiran" {
            out.push_str(&format!("  \"{field}\": {value}{comma}\n"));
        } else {
            out.push_str(&format!("  \"{field}\": {}{comma}\n", json_string(&value)));
        }
    }
    out.push_str("}\n");
    out
}

fn json_string(raw: &str) -> String {
    let mut out = String::with_capacity(raw.len() + 2);
    out.push('"');
    for ch in raw.chars() {
        match ch {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            c if (c as u32) < 0x20 => out.push_str(&format!("\\u{:04x}", c as u32)),
            c => out.push(c),
        }
    }
    out.push('"');
    out
}

/// The sidecar as a one-row CSV, header in [`FIELDS`] order.
///
/// CRLF and a UTF-8 BOM: this file is opened in Excel on Windows by
/// people whose Excel is configured for Indonesian, and without the BOM
/// it renders "Dirjen Pengawasan" as mojibake.
#[flutter_rust_bridge::frb(ignore)]
pub fn to_csv(metadata: &SrikandiMetadata, berkas: &str) -> String {
    let mut out = String::from("\u{feff}");
    out.push_str(&FIELDS.join(","));
    out.push_str("\r\n");
    let row: Vec<String> = FIELDS
        .iter()
        .map(|field| csv_field(&value_for(metadata, field, berkas)))
        .collect();
    out.push_str(&row.join(","));
    out.push_str("\r\n");
    out
}

fn csv_field(raw: &str) -> String {
    if raw.contains([',', '"', '\n', '\r', ';']) {
        format!("\"{}\"", raw.replace('"', "\"\""))
    } else {
        raw.to_string()
    }
}

impl NotulenTemplate {
    /// The jenis naskah dinas this template produces, as an archivist
    /// names it.
    #[flutter_rust_bridge::frb(ignore)]
    pub fn jenis_naskah(self) -> &'static str {
        match self {
            Self::Dinas => "Notula Rapat",
            Self::Risalah => "Risalah Rapat",
            Self::BeritaAcara => "Berita Acara",
            Self::Ringkas => "Notulen Ringkas",
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn form() -> NotulenForm {
        NotulenForm {
            template: NotulenTemplate::Dinas,
            unit_kerja: "DIREKTORAT JENDERAL ANGGARAN".into(),
            nomor: "112/SJ.5/UM.03.01/01/2026".into(),
            judul: "Rapat Koordinasi Penyusunan Pagu Indikatif 2027.".into(),
            tanggal: "5 Oktober 2026".into(),
            pimpinan: "Dr. Siti Aminah".into(),
            lampirkan_transkrip: true,
            ..NotulenForm::default()
        }
    }

    fn complete() -> SrikandiMetadata {
        SrikandiMetadata {
            nomor: "112/SJ.5/UM.03.01/01/2026".into(),
            tanggal: "5 Oktober 2026".into(),
            jenis_naskah: "Notula Rapat".into(),
            perihal: "Rapat Koordinasi Penyusunan Pagu Indikatif 2027".into(),
            kode_klasifikasi_arsip: "UM.03.01".into(),
            unit_pengolah: "DIREKTORAT JENDERAL ANGGARAN".into(),
            penandatangan_nama: "Dr. Siti Aminah".into(),
            penandatangan_jabatan: "Direktur Jenderal Anggaran".into(),
            ..SrikandiMetadata::default()
        }
    }

    // --- prefill ---------------------------------------------------------

    #[test]
    fn prefill_takes_what_the_document_knows_and_no_more() {
        let metadata = defaults_from_form(&form());
        assert_eq!(metadata.nomor, "112/SJ.5/UM.03.01/01/2026");
        assert_eq!(metadata.tanggal, "5 Oktober 2026");
        assert_eq!(metadata.jenis_naskah, "Notula Rapat");
        // The trailing full stop of a meeting title is not part of a Hal.
        assert_eq!(
            metadata.perihal,
            "Rapat Koordinasi Penyusunan Pagu Indikatif 2027"
        );
        assert_eq!(metadata.unit_pengolah, "DIREKTORAT JENDERAL ANGGARAN");
        assert_eq!(metadata.jumlah_lampiran, 1);
        // Not derivable from the document, so left for the user.
        assert!(metadata.kode_klasifikasi_arsip.is_empty());
        assert!(metadata.penandatangan_jabatan.is_empty());
    }

    #[test]
    fn a_form_without_a_nomor_gets_a_placeholder_not_a_number() {
        let mut blank = form();
        blank.nomor.clear();
        let metadata = defaults_from_form(&blank);
        assert_eq!(metadata.nomor, NOMOR_PLACEHOLDER);
        assert!(!nomor_shape_ok(&metadata.nomor));
        assert!(
            !NOMOR_PLACEHOLDER.chars().any(|c| c.is_ascii_digit()),
            "a numeric placeholder would eventually be uploaded as real"
        );
    }

    #[test]
    fn every_template_names_its_jenis_naskah() {
        let mut seen: Vec<&str> = Vec::new();
        for template in NotulenTemplate::all() {
            let jenis = template.jenis_naskah();
            assert!(!jenis.is_empty());
            assert!(!seen.contains(&jenis), "{template:?} duplicates a jenis");
            seen.push(jenis);
        }
    }

    // --- nomor shape -----------------------------------------------------

    #[test]
    fn a_nomor_in_the_pedoman_shape_is_accepted() {
        assert!(nomor_shape_ok("112/SJ.5/UM.03.01/01/2026"));
        assert!(nomor_shape_ok("B-245/SJ/KU.01.02/01/2026"));
        assert!(nomor_shape_ok("SR-7/SJ.5/KP.01.06/12/2026"));
    }

    #[test]
    fn a_placeholder_or_malformed_nomor_is_rejected() {
        for bad in [
            "",
            "   ",
            NOMOR_PLACEHOLDER,
            "…/[KODE UNIT]/UM.03.01/01/2026",
            "112/SJ.5/UM.03.01/2026",
            "112/SJ.5/UM.03.01/13/2026",
            "112/SJ.5/UM.03.01/1/2026",
            "112/SJ.5/UM.03.01/01/26",
            "abc/SJ.5/UM.03.01/01/2026",
            "112//UM.03.01/01/2026",
        ] {
            assert!(!nomor_shape_ok(bad), "accepted {bad:?}");
        }
    }

    #[test]
    fn an_unknown_sifat_prefix_is_not_stripped() {
        // "X-112/..." is not a Pedoman prefix, so the whole thing is the
        // running number and the shape check fails on it.
        assert!(!nomor_shape_ok("X-112/SJ.5/UM.03.01/01/2026"));
    }

    // --- validation ------------------------------------------------------

    #[test]
    fn complete_metadata_is_ready_to_upload() {
        assert_eq!(validate(&complete()), Vec::new());
        assert!(siap_unggah(&complete()));
    }

    #[test]
    fn every_registration_field_is_required_by_name() {
        let findings = validate(&SrikandiMetadata::default());
        let required: Vec<&str> = findings
            .iter()
            .filter(|f| f.tingkat == Tingkat::Wajib)
            .map(|f| f.bidang.as_str())
            .collect();
        for field in [
            "nomor",
            "tanggal",
            "perihal",
            "kode_klasifikasi_arsip",
            "unit_pengolah",
            "penandatangan_jabatan",
        ] {
            assert!(required.contains(&field), "{field} is not required");
        }
        assert!(!siap_unggah(&SrikandiMetadata::default()));
    }

    #[test]
    fn the_nomor_finding_tells_the_user_where_to_get_one() {
        let findings = validate(&SrikandiMetadata::default());
        let nomor = findings.iter().find(|f| f.bidang == "nomor").unwrap();
        assert!(nomor.pesan.contains("Tata Usaha"), "{}", nomor.pesan);
        assert!(nomor.pesan.contains("jangan menetapkannya sendiri"));
    }

    #[test]
    fn a_numeric_date_is_a_suggestion_not_a_blocker() {
        let mut metadata = complete();
        metadata.tanggal = "5-10-2026".into();
        let findings = validate(&metadata);
        let tanggal = findings.iter().find(|f| f.bidang == "tanggal").unwrap();
        assert_eq!(tanggal.tingkat, Tingkat::Saran);
        assert!(siap_unggah(&metadata), "a shape hint must not block upload");
    }

    #[test]
    fn a_hal_with_a_trailing_full_stop_is_flagged() {
        let mut metadata = complete();
        metadata.perihal = "Undangan Rapat.".into();
        let findings = validate(&metadata);
        assert!(findings
            .iter()
            .any(|f| f.bidang == "perihal" && f.tingkat == Tingkat::Saran));
    }

    // --- sidecar ---------------------------------------------------------

    #[test]
    fn the_json_sidecar_is_valid_json_with_every_field() {
        let text = to_json(&complete(), "Notulen - Rapat Koordinasi.docx");
        let parsed: serde_json::Value = serde_json::from_str(&text).unwrap();
        for field in FIELDS {
            assert!(parsed.get(field).is_some(), "{field} missing");
        }
        assert_eq!(parsed["nomor"], "112/SJ.5/UM.03.01/01/2026");
        assert_eq!(parsed["sifat"], "Biasa");
        assert_eq!(parsed["tingkat_perkembangan"], "Asli");
        // A number, not a string: a spreadsheet should sum it.
        assert_eq!(parsed["jumlah_lampiran"], 0);
        assert_eq!(parsed["berkas_naskah"], "Notulen - Rapat Koordinasi.docx");
        assert!(parsed["dibuat_oleh"]
            .as_str()
            .unwrap()
            .contains("bukan integrasi SRIKANDI"));
    }

    #[test]
    fn json_escapes_characters_that_would_break_the_file() {
        let mut metadata = complete();
        metadata.catatan = "Baris \"satu\"\nBaris\tdua\\".into();
        let text = to_json(&metadata, "a.docx");
        let parsed: serde_json::Value = serde_json::from_str(&text).unwrap();
        assert_eq!(parsed["catatan"], "Baris \"satu\"\nBaris\tdua\\");
    }

    #[test]
    fn the_csv_header_and_row_have_the_same_columns() {
        let text = to_csv(&complete(), "a.docx");
        let lines: Vec<&str> = text.trim_end_matches("\r\n").split("\r\n").collect();
        assert_eq!(lines.len(), 2, "header plus one row");
        let header = lines[0].trim_start_matches('\u{feff}');
        assert_eq!(header.split(',').count(), FIELDS.len());
        // Counting the row's columns needs quote awareness, so this
        // checks the simple case plus the quoted one below.
        assert!(lines[1].starts_with("112/SJ.5/UM.03.01/01/2026,"));
    }

    #[test]
    fn the_csv_carries_a_bom_and_crlf_for_excel() {
        let text = to_csv(&complete(), "a.docx");
        assert!(text.starts_with('\u{feff}'), "Excel needs the BOM");
        assert!(text.contains("\r\n"));
    }

    #[test]
    fn csv_quotes_a_field_containing_a_separator() {
        let mut metadata = complete();
        metadata.catatan = "Retensi 10 tahun, lalu musnah".into();
        let text = to_csv(&metadata, "a.docx");
        assert!(text.contains("\"Retensi 10 tahun, lalu musnah\""));

        metadata.catatan = "Kata \"kunci\"".into();
        assert!(to_csv(&metadata, "a.docx").contains("\"Kata \"\"kunci\"\"\""));
    }

    #[test]
    fn the_two_sidecar_formats_describe_the_same_fields() {
        // The CSV header and the JSON keys come from one list, so a field
        // added to one is in the other.
        let json: serde_json::Value =
            serde_json::from_str(&to_json(&complete(), "a.docx")).unwrap();
        let csv = to_csv(&complete(), "a.docx");
        let header = csv
            .lines()
            .next()
            .unwrap()
            .trim_start_matches('\u{feff}')
            .to_string();
        for key in json.as_object().unwrap().keys() {
            assert!(header.contains(key), "CSV header lacks {key}");
        }
    }

    #[test]
    fn the_enums_expose_every_value_for_a_dropdown() {
        assert_eq!(Sifat::all().len(), 3);
        assert_eq!(KlasifikasiKeamanan::all().len(), 4);
        assert_eq!(TingkatPerkembangan::all().len(), 4);
        for sifat in Sifat::all() {
            assert!(!sifat.label().is_empty());
            assert!(!sifat.nomor_prefix().is_empty());
        }
    }

    #[test]
    fn the_default_metadata_is_the_least_dangerous_one() {
        let metadata = SrikandiMetadata::default();
        assert_eq!(metadata.sifat, Sifat::Biasa);
        assert_eq!(metadata.klasifikasi_keamanan, KlasifikasiKeamanan::Biasa);
        assert_eq!(metadata.tingkat_perkembangan, TingkatPerkembangan::Asli);
    }
}
