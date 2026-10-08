//! The notulen engine: templates, strict JSON schema, fact check, register.
//!
//! # Why a second notulen module
//!
//! [`crate::export::notulen`] renders a *finished* [`NotulenForm`] into
//! DOCX. It knows nothing about where the form's contents came from. This
//! module is the other half: turning a transcript plus a language model
//! into that form, and then checking the result before a civil servant
//! signs it.
//!
//! Three things made the Sprint 3/4 path too weak to sign:
//!
//! 1. **Markdown round-trip.** The model was asked for `##` headings and
//!    the parser guessed the sections back out of prose. A model that
//!    renamed "Tindak Lanjut" to "Rencana Aksi" silently produced a
//!    notulen with no follow-ups. [`schema`] replaces that with one JSON
//!    object whose keys are fixed.
//! 2. **No provenance on the sections that matter.** Citations existed
//!    (`crate::provenance`) but only as free-text `[#12]` markers inside
//!    a Markdown line. Here every keputusan and every tugas carries its
//!    own `segmen` list, so [`factcheck`] can check each one
//!    individually.
//! 3. **No register discipline.** A notulen dinas written with "oke, nanti
//!    kita bikin" is not a naskah dinas, whatever its structure.
//!    [`register`] is the EYD V / Tata Naskah Dinas checker.
//!
//! # The four templates
//!
//! [`NotulenTemplate`] follows the naskah-dinas family rather than
//! inventing shapes: Notulen Dinas (the full notula form), Risalah Rapat
//! (verbatim-ringkas, the per-speaker record a sidang produces), Berita
//! Acara (para pihak + "telah melaksanakan"), and Notulen Ringkas (one
//! page, for circulation).
//!
//! Every template fills the *same* [`schema::NotulenJson`]; what differs
//! is which fields are required, what the prompt asks for, and how
//! [`crate::export::notulen`] lays it out. One schema means one parser
//! and one fact checker rather than four.

use serde::{Deserialize, Serialize};

pub mod angka;
pub mod factcheck;
#[cfg(test)]
mod parity;
pub mod prompt;
pub mod register;
pub mod schema;

/// Which naskah-dinas layout the notulen is being written as.
///
/// Serialised by name into `settings.json` and the session's saved form,
/// so the variant names are a storage format: renaming one needs a
/// migration.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
pub enum NotulenTemplate {
    /// Full notula per Pedoman Tata Naskah Dinas: identitas rapat,
    /// peserta, acara, jalannya rapat, kesimpulan, tindak lanjut, tanda
    /// tangan notulis + pimpinan.
    #[default]
    Dinas,
    /// Risalah rapat, verbatim-ringkas: the order of speakers is the
    /// point, so `jalannya_rapat` is required and carries one entry per
    /// intervention.
    Risalah,
    /// Berita acara: para pihak, what was carried out, and the closing
    /// formula. Used for serah terima, pemeriksaan and kesepakatan.
    BeritaAcara,
    /// One page, no kop surat, no signature block.
    Ringkas,
}

/// One section of the schema, as the prompt and the structure check see it.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct SectionSpec {
    /// JSON key in [`schema::NotulenJson`].
    pub key: &'static str,
    /// Heading shown in the document, in Bahasa Indonesia.
    pub heading: &'static str,
    /// A notulen missing a required section fails the structure check.
    pub required: bool,
}

const RINGKASAN: SectionSpec = SectionSpec {
    key: "ringkasan",
    heading: "Ringkasan",
    required: false,
};
const PESERTA: SectionSpec = SectionSpec {
    key: "peserta",
    heading: "Peserta",
    required: true,
};
const AGENDA: SectionSpec = SectionSpec {
    key: "agenda",
    heading: "Acara",
    required: false,
};
const JALANNYA_RAPAT: SectionSpec = SectionSpec {
    key: "jalannya_rapat",
    heading: "Jalannya Rapat",
    required: false,
};
const JALANNYA_RAPAT_WAJIB: SectionSpec = SectionSpec {
    key: "jalannya_rapat",
    heading: "Jalannya Rapat",
    required: true,
};
const PEMBAHASAN: SectionSpec = SectionSpec {
    key: "pembahasan",
    heading: "Pembahasan",
    required: true,
};
const KEPUTUSAN: SectionSpec = SectionSpec {
    key: "keputusan",
    heading: "Keputusan",
    required: true,
};
const TINDAK_LANJUT: SectionSpec = SectionSpec {
    key: "tindak_lanjut",
    heading: "Tindak Lanjut",
    required: true,
};
const PIHAK: SectionSpec = SectionSpec {
    key: "pihak",
    heading: "Para Pihak",
    required: true,
};
const PELAKSANAAN: SectionSpec = SectionSpec {
    key: "pembahasan",
    heading: "Pelaksanaan",
    required: true,
};
const KESEPAKATAN: SectionSpec = SectionSpec {
    key: "keputusan",
    heading: "Kesepakatan",
    required: true,
};

impl NotulenTemplate {
    /// Stable identifier used in settings, the benchmark harness and the
    /// sidecar metadata.
    #[flutter_rust_bridge::frb(ignore)]
    pub fn id(self) -> &'static str {
        match self {
            Self::Dinas => "notulen_dinas",
            Self::Risalah => "risalah_rapat",
            Self::BeritaAcara => "berita_acara",
            Self::Ringkas => "notulen_ringkas",
        }
    }

    /// What the document calls itself, centred and capitalised at the top
    /// of the first page.
    #[flutter_rust_bridge::frb(ignore)]
    pub fn document_title(self) -> &'static str {
        match self {
            Self::Dinas => "NOTULA RAPAT",
            Self::Risalah => "RISALAH RAPAT",
            Self::BeritaAcara => "BERITA ACARA",
            Self::Ringkas => "NOTULEN RINGKAS",
        }
    }

    /// Menu label.
    #[flutter_rust_bridge::frb(ignore)]
    pub fn label(self) -> &'static str {
        match self {
            Self::Dinas => "Notulen Dinas",
            Self::Risalah => "Risalah Rapat (verbatim-ringkas)",
            Self::BeritaAcara => "Berita Acara",
            Self::Ringkas => "Notulen Ringkas",
        }
    }

    /// One line explaining when to pick this one, for the export form.
    #[flutter_rust_bridge::frb(ignore)]
    pub fn description(self) -> &'static str {
        match self {
            Self::Dinas => {
                "Notula lengkap sesuai Tata Naskah Dinas: identitas rapat, \
                 peserta, acara, jalannya rapat, kesimpulan, tindak lanjut, \
                 dan ruang tanda tangan notulis serta pimpinan rapat."
            }
            Self::Risalah => {
                "Catatan berurutan per pembicara, mendekati verbatim tetapi \
                 diringkas. Dipakai untuk sidang dan rapat yang perlu \
                 merekam siapa menyampaikan apa."
            }
            Self::BeritaAcara => {
                "Naskah pembuktian: menyebut para pihak, apa yang telah \
                 dilaksanakan, hasilnya, dan ditutup dengan formula baku \
                 \"Demikian Berita Acara ini dibuat dengan sesungguhnya\"."
            }
            Self::Ringkas => {
                "Satu halaman tanpa kop surat dan tanpa tanda tangan, untuk \
                 diedarkan cepat setelah rapat."
            }
        }
    }

    /// Sections this template asks the model for, in document order.
    #[flutter_rust_bridge::frb(ignore)]
    pub fn sections(self) -> &'static [SectionSpec] {
        match self {
            Self::Dinas => &[
                RINGKASAN,
                PESERTA,
                AGENDA,
                JALANNYA_RAPAT,
                PEMBAHASAN,
                KEPUTUSAN,
                TINDAK_LANJUT,
            ],
            Self::Risalah => &[
                PESERTA,
                AGENDA,
                JALANNYA_RAPAT_WAJIB,
                KEPUTUSAN,
                TINDAK_LANJUT,
            ],
            Self::BeritaAcara => &[PIHAK, PELAKSANAAN, KESEPAKATAN, TINDAK_LANJUT],
            Self::Ringkas => &[RINGKASAN, PEMBAHASAN, KEPUTUSAN, TINDAK_LANJUT],
        }
    }

    /// The subset of [`Self::sections`] whose absence is a failure.
    #[flutter_rust_bridge::frb(ignore)]
    pub fn required_sections(self) -> Vec<SectionSpec> {
        self.sections()
            .iter()
            .copied()
            .filter(|s| s.required)
            .collect()
    }

    /// Whether the rendered document carries a kop surat, a nomor and a
    /// signature block.
    #[flutter_rust_bridge::frb(ignore)]
    pub fn is_formal(self) -> bool {
        matches!(self, Self::Dinas | Self::Risalah | Self::BeritaAcara)
    }

    /// Every template, for a dropdown.
    #[flutter_rust_bridge::frb(ignore)]
    pub fn all() -> &'static [NotulenTemplate] {
        &[Self::Dinas, Self::Risalah, Self::BeritaAcara, Self::Ringkas]
    }
}

/// Fills a [`NotulenForm`] from the model's JSON, keeping whatever the
/// user already typed.
///
/// `base` is the form as the user left it — instansi, nomor, hari,
/// notulis and the rest. Only the body sections the model produced are
/// overwritten, because regenerating a notulen must not wipe the
/// identity block the notulis filled in by hand.
///
/// `pembahasan` is rendered as Markdown rather than kept structured: the
/// DOCX renderer already parses Markdown for the body (headings,
/// bullets, tables), the user edits it as text in the export form, and a
/// second structured path would mean two renderers to keep in step.
#[flutter_rust_bridge::frb(ignore)]
pub fn to_form(
    notulen: &schema::NotulenJson,
    template: NotulenTemplate,
    base: &crate::export::notulen::NotulenForm,
) -> crate::export::notulen::NotulenForm {
    use crate::export::notulen::{NotulenForm, RisalahEntry, TindakLanjut};

    let mut pembahasan = String::new();
    for item in &notulen.pembahasan {
        if !item.topik.trim().is_empty() {
            pembahasan.push_str(&format!("## {}\n", item.topik.trim()));
        }
        if !item.uraian.trim().is_empty() {
            pembahasan.push_str(item.uraian.trim());
            pembahasan.push('\n');
        }
        pembahasan.push('\n');
    }

    NotulenForm {
        template,
        ringkasan: notulen.ringkasan.trim().to_string(),
        peserta: if notulen.peserta.is_empty() {
            base.peserta.clone()
        } else {
            notulen.peserta.clone()
        },
        agenda: if notulen.agenda.is_empty() {
            base.agenda.clone()
        } else {
            notulen.agenda.clone()
        },
        pihak: if notulen.pihak.is_empty() {
            base.pihak.clone()
        } else {
            notulen.pihak.clone()
        },
        pembahasan: pembahasan.trim().to_string(),
        jalannya_rapat: notulen
            .jalannya_rapat
            .iter()
            .map(|item| RisalahEntry {
                pembicara: item.pembicara.trim().to_string(),
                pokok: item.pokok.trim().to_string(),
            })
            .collect(),
        keputusan: notulen
            .keputusan
            .iter()
            .map(|item| item.isi.trim().to_string())
            .filter(|isi| !isi.is_empty())
            .collect(),
        tindak_lanjut: notulen
            .tindak_lanjut
            .iter()
            .map(|item| TindakLanjut {
                tugas: item.tugas.trim().to_string(),
                penanggung_jawab: item.penanggung_jawab.trim().to_string(),
                tenggat: item.tenggat.trim().to_string(),
            })
            .collect(),
        // Everything the audio cannot supply survives untouched.
        instansi: base.instansi.clone(),
        unit_kerja: base.unit_kerja.clone(),
        nomor: base.nomor.clone(),
        judul: base.judul.clone(),
        hari: base.hari.clone(),
        tanggal: base.tanggal.clone(),
        waktu: base.waktu.clone(),
        tempat: base.tempat.clone(),
        pimpinan: base.pimpinan.clone(),
        notulis: base.notulis.clone(),
        poin_penting: base.poin_penting.clone(),
        kop_surat_path: base.kop_surat_path.clone(),
        lampirkan_transkrip: base.lampirkan_transkrip,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn to_form_keeps_the_identity_block_the_notulis_typed() {
        let base = crate::export::notulen::NotulenForm {
            instansi: "KEMENTERIAN X".into(),
            nomor: "112/SJ.5/UM.03.01/01/2026".into(),
            hari: "Senin".into(),
            notulis: "Budi".into(),
            judul: "Rapat Koordinasi".into(),
            lampirkan_transkrip: true,
            ..Default::default()
        };
        let notulen = schema::parse(
            r#"{"ringkasan": "Rapat singkat.",
                "peserta": ["Siti"],
                "pembahasan": [{"topik": "Pagu", "uraian": "Pagu naik."}],
                "keputusan": [{"isi": "Pagu disetujui."}],
                "tindak_lanjut": [{"tugas": "Susun draf", "pj": "Budi", "tenggat": "Jumat"}]}"#,
        )
        .unwrap()
        .notulen;

        let form = to_form(&notulen, NotulenTemplate::Dinas, &base);
        // Model output fills the body…
        assert_eq!(form.ringkasan, "Rapat singkat.");
        assert_eq!(form.peserta, vec!["Siti"]);
        assert_eq!(form.pembahasan, "## Pagu\nPagu naik.");
        assert_eq!(form.keputusan, vec!["Pagu disetujui."]);
        assert_eq!(form.tindak_lanjut[0].penanggung_jawab, "Budi");
        // …and nothing the model cannot know is touched.
        assert_eq!(form.instansi, "KEMENTERIAN X");
        assert_eq!(form.nomor, "112/SJ.5/UM.03.01/01/2026");
        assert_eq!(form.hari, "Senin");
        assert_eq!(form.notulis, "Budi");
        assert_eq!(form.judul, "Rapat Koordinasi");
        assert!(form.lampirkan_transkrip);
    }

    #[test]
    fn to_form_keeps_a_hand_typed_participant_list_when_the_model_found_none() {
        let base = crate::export::notulen::NotulenForm {
            peserta: vec!["Siti".into(), "Budi".into()],
            agenda: vec!["Pembukaan".into()],
            ..Default::default()
        };
        let notulen = schema::parse(r#"{"keputusan": [{"isi": "Selesai."}]}"#)
            .unwrap()
            .notulen;
        let form = to_form(&notulen, NotulenTemplate::Dinas, &base);
        assert_eq!(form.peserta, vec!["Siti", "Budi"]);
        assert_eq!(form.agenda, vec!["Pembukaan"]);
    }

    #[test]
    fn to_form_carries_the_risalah_record_and_the_parties() {
        let notulen = schema::parse(
            r#"{"jalannya_rapat": [{"pembicara": "Ketua", "pokok": "membuka rapat"}],
                "pihak": ["Sumarno", "Herlina"],
                "keputusan": [{"isi": "Sepakat."}]}"#,
        )
        .unwrap()
        .notulen;
        let form = to_form(
            &notulen,
            NotulenTemplate::Risalah,
            &crate::export::notulen::NotulenForm::default(),
        );
        assert_eq!(form.jalannya_rapat.len(), 1);
        assert_eq!(form.jalannya_rapat[0].pembicara, "Ketua");
        assert_eq!(form.pihak, vec!["Sumarno", "Herlina"]);
        assert_eq!(form.template, NotulenTemplate::Risalah);
    }

    #[test]
    fn to_form_renders_an_untitled_topic_as_plain_prose() {
        let notulen = schema::parse(
            r#"{"pembahasan": [{"uraian": "Satu."}, {"uraian": "Dua."}],
                "keputusan": [{"isi": "Selesai."}]}"#,
        )
        .unwrap()
        .notulen;
        let form = to_form(
            &notulen,
            NotulenTemplate::Ringkas,
            &crate::export::notulen::NotulenForm::default(),
        );
        assert_eq!(form.pembahasan, "Satu.\n\nDua.");
        assert!(!form.pembahasan.contains("##"), "no empty headings");
    }

    #[test]
    fn every_template_requires_the_three_core_sections_or_explains_itself() {
        for template in NotulenTemplate::all() {
            let required: Vec<&str> = template.required_sections().iter().map(|s| s.key).collect();
            // "Pembahasan, Keputusan, Tindak Lanjut" is the contract the
            // whole engine is built on — a template that drops one of them
            // produces a document the fact checker cannot reason about.
            // Risalah substitutes `jalannya_rapat` for `pembahasan`: its
            // body *is* the ordered record of interventions.
            assert!(
                required.contains(&"keputusan"),
                "{:?} does not require keputusan",
                template
            );
            assert!(
                required.contains(&"tindak_lanjut"),
                "{:?} does not require tindak_lanjut",
                template
            );
            assert!(
                required.contains(&"pembahasan") || required.contains(&"jalannya_rapat"),
                "{:?} has no required discussion body",
                template
            );
        }
    }

    #[test]
    fn template_ids_and_titles_are_unique() {
        let mut ids: Vec<&str> = NotulenTemplate::all().iter().map(|t| t.id()).collect();
        let count = ids.len();
        ids.sort_unstable();
        ids.dedup();
        assert_eq!(ids.len(), count, "template ids collide");

        let mut titles: Vec<&str> = NotulenTemplate::all()
            .iter()
            .map(|t| t.document_title())
            .collect();
        titles.sort_unstable();
        titles.dedup();
        assert_eq!(titles.len(), count, "document titles collide");
    }

    #[test]
    fn berita_acara_names_its_sections_in_naskah_dinas_terms() {
        // The same JSON keys, different headings: a berita acara says
        // "Para Pihak" and "Kesepakatan", never "Pembahasan".
        let headings: Vec<&str> = NotulenTemplate::BeritaAcara
            .sections()
            .iter()
            .map(|s| s.heading)
            .collect();
        assert_eq!(
            headings,
            vec!["Para Pihak", "Pelaksanaan", "Kesepakatan", "Tindak Lanjut"]
        );
        let keys: Vec<&str> = NotulenTemplate::BeritaAcara
            .sections()
            .iter()
            .map(|s| s.key)
            .collect();
        assert!(keys.contains(&"pembahasan"), "same schema key underneath");
    }

    #[test]
    fn only_the_ringkas_variant_drops_the_formal_apparatus() {
        assert!(!NotulenTemplate::Ringkas.is_formal());
        for template in [
            NotulenTemplate::Dinas,
            NotulenTemplate::Risalah,
            NotulenTemplate::BeritaAcara,
        ] {
            assert!(template.is_formal(), "{template:?} must carry a kop surat");
        }
    }

    #[test]
    fn the_default_template_is_the_full_dinas_form() {
        assert_eq!(NotulenTemplate::default(), NotulenTemplate::Dinas);
    }

    /// `(path, contents)` of the fixture Dart's copy of the table is
    /// checked against.
    fn template_fixture() -> (std::path::PathBuf, String) {
        let root = std::path::PathBuf::from(
            std::env::var("CARGO_MANIFEST_DIR").unwrap_or_else(|_| ".".into()),
        );
        let mut rows = Vec::new();
        for template in NotulenTemplate::all() {
            rows.push(serde_json::json!({
                "id": template.id(),
                "label": template.label(),
                "description": template.description(),
                "document_title": template.document_title(),
                "jenis_naskah": template.jenis_naskah(),
                "formal": template.is_formal(),
                "required_sections": template
                    .required_sections()
                    .iter()
                    .map(|section| section.heading)
                    .collect::<Vec<_>>(),
            }));
        }
        let text = format!(
            "{}\n",
            serde_json::to_string_pretty(&serde_json::Value::Array(rows)).unwrap()
        );
        (root.join("../test/fixtures/notulen_templates.json"), text)
    }

    /// The Dart picker shows labels and descriptions this enum owns.
    ///
    /// They are duplicated in `lib/state/notulen_templates.dart` because
    /// the picker is built inside `build()` and a bridge round trip there
    /// would make the dialog open empty. The duplication is only safe if
    /// it is checked, so both sides compare against this one file.
    #[test]
    fn the_template_table_dart_copies_is_current() {
        let (path, expected) = template_fixture();
        let actual = std::fs::read_to_string(&path).unwrap_or_else(|e| {
            panic!(
                "{} is missing ({e}); regenerate with \
                 TRAREON_DUMP_PROMPTS=1 cargo test --lib notulen::tests",
                path.display()
            )
        });
        assert_eq!(
            actual.trim_end(),
            expected.trim_end(),
            "{} drifted; regenerate with TRAREON_DUMP_PROMPTS=1 cargo test \
             --lib notulen::tests, then update lib/state/notulen_templates.dart",
            path.display()
        );
    }

    /// Writes the fixture when `TRAREON_DUMP_PROMPTS` is set.
    #[test]
    fn dump_notulen_templates() {
        if std::env::var("TRAREON_DUMP_PROMPTS").is_err() {
            return;
        }
        let (path, text) = template_fixture();
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent).unwrap();
        }
        std::fs::write(path, text).unwrap();
    }
}
