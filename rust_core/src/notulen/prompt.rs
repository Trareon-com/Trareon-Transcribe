//! The notulen prompts — the production prompts, and the benchmark's.
//!
//! # Single source of truth
//!
//! `ml/notulen_bench` chooses the app's default model. A bake-off run
//! with a prompt that is not the app's prompt measures something the user
//! will never see, so this module is the only place the prompt text
//! exists and the benchmark reads its copy from
//! `ml/notulen_bench/prompts/`. [`tests::the_benchmark_prompts_match_the_shipped_ones`]
//! fails when the two drift.
//!
//! # What the prompt has to carry
//!
//! The rules come from the Pedoman Tata Naskah Dinas (Pedoman Menteri
//! Kominfo No. 03/2019 butir P, which mandates bahasa Indonesia baku per
//! KBBI; Peraturan ANRI No. 5/2021 for the naskah structure) and from the
//! `naskah-dinas-komdigi` QA checklist. Four groups, each of which was a
//! defect before it was a rule:
//!
//! 1. **Shape.** One JSON object, keys fixed, no fence, no preamble.
//!    [`crate::notulen::schema`] repairs deviations, but a model told
//!    exactly what to emit deviates far less often.
//! 2. **Register.** Baku Indonesian, the Pedoman's number/time/money
//!    formats, no "dan lain-lain". Checked afterwards by
//!    [`crate::notulen::register`]; asking for it up front is cheaper
//!    than correcting it.
//! 3. **Provenance.** Every keputusan and tugas cites the transcript
//!    segments it came from, which is what makes
//!    [`crate::notulen::factcheck`] able to check anything at all.
//! 4. **Refusal to invent.** Named explicitly for names, numbers, dates
//!    and decisions, and paired with the instruction to leave a section
//!    empty rather than fill it — the single highest-value line in the
//!    prompt, because "## Keputusan" in a prompt is enough to make a 4B
//!    model produce decisions from a meeting that took none.

use crate::notulen::NotulenTemplate;

/// System message: who the model is and the rules it works under.
#[flutter_rust_bridge::frb(ignore)]
pub fn system_prompt(template: NotulenTemplate) -> String {
    let dokumen = template.document_title();
    format!(
        "Anda notulis naskah dinas pada instansi pemerintah Republik Indonesia. \
         Anda menyusun {dokumen} dari transkrip hasil speech-to-text yang mungkin \
         mengandung salah dengar.\n\
         \n\
         ATURAN BAHASA (Pedoman Tata Naskah Dinas, ejaan bahasa Indonesia dan KBBI):\n\
         - Tulis dalam bahasa Indonesia baku. Jangan memakai ragam percakapan \
           (\"oke\", \"bikin\", \"gak\", \"kayak\", \"banget\", \"aja\", \"sih\").\n\
         - Satu kalimat memuat satu gagasan. Pakai kata kerja aktif.\n\
         - Angka penting ditulis dengan angka dan huruf: \"4 (empat) persen\".\n\
         - Waktu: \"pukul 09.00 WIB\" atau \"09.00–11.30 WIB\". Jangan \"09:00\".\n\
         - Tanggal: \"5 Oktober 2026\". Jangan \"5-10-2026\".\n\
         - Uang: \"Rp8.500.000,00\". Jangan \"Rp. 8.500.000,-\".\n\
         - Jangan menulis \"dan lain-lain\", \"dll.\" atau \"dsb.\"; sebutkan rinciannya.\n\
         \n\
         ATURAN ISI (wajib):\n\
         - Gunakan HANYA isi transkrip. Jangan mengarang nama orang, jabatan, \
           angka, tanggal, tenggat, atau keputusan.\n\
         - Jika rapat tidak mengambil keputusan, kosongkan daftar keputusan. \
           Bagian kosong jauh lebih baik daripada keputusan yang tidak pernah \
           diambil.\n\
         - Pertahankan nama orang, istilah teknis dan angka persis seperti di \
           transkrip.\n\
         - Setiap keputusan dan setiap tugas WAJIB menyebut nomor segmen \
           transkrip yang mendasarinya pada bidang \"segmen\". Gunakan hanya \
           nomor segmen yang benar-benar ada.\n\
         \n\
         ATURAN KELUARAN (wajib):\n\
         - Keluarkan SATU objek JSON saja. Tanpa penjelasan sebelum atau \
           sesudahnya, tanpa blok kode, tanpa komentar.\n\
         - Pakai nama bidang persis seperti pada kerangka yang diberikan.\n\
         - Semua nilai teks ditulis dalam bahasa Indonesia."
    )
}

/// The JSON skeleton for `template`, with the per-field guidance inline.
#[flutter_rust_bridge::frb(ignore)]
pub fn schema_block(template: NotulenTemplate) -> String {
    let mut out = String::from("{\n");
    for section in template.sections() {
        out.push_str(&field_line(section.key, section.required));
    }
    // Trailing comma on the last field would be exactly the defect the
    // parser has to repair, so the prompt must not model it.
    while out.ends_with(",\n") {
        out.truncate(out.len() - 2);
        out.push('\n');
    }
    out.push('}');
    out
}

fn field_line(key: &str, required: bool) -> String {
    let wajib = if required { " (WAJIB)" } else { " (opsional)" };
    match key {
        "ringkasan" => format!("  \"ringkasan\": \"2-3 kalimat inti rapat{wajib}\",\n"),
        "peserta" => format!(
            "  \"peserta\": [\"nama atau jabatan peserta yang muncul di transkrip{wajib}\"],\n"
        ),
        "agenda" => format!("  \"agenda\": [\"pokok acara rapat{wajib}\"],\n"),
        "pihak" => {
            format!("  \"pihak\": [\"nama dan jabatan pihak yang membuat berita acara{wajib}\"],\n")
        }
        // For the object arrays the marker goes inside the first field's
        // description: appended after the `]` it would make the skeleton
        // itself invalid JSON, which is the opposite of the point.
        "jalannya_rapat" => format!(
            "  \"jalannya_rapat\": [{{\"pembicara\": \"nama atau jabatan{wajib}\", \
             \"pokok\": \"pokok yang disampaikan, berurutan sesuai transkrip\", \
             \"segmen\": [1, 2]}}],\n"
        ),
        "pembahasan" => format!(
            "  \"pembahasan\": [{{\"topik\": \"judul topik{wajib}\", \
             \"uraian\": \"uraian pembahasan topik itu\", \"segmen\": [3, 4]}}],\n"
        ),
        "keputusan" => format!(
            "  \"keputusan\": [{{\"isi\": \"satu keputusan, satu kalimat{wajib}\", \
             \"segmen\": [5]}}],\n"
        ),
        "tindak_lanjut" => format!(
            "  \"tindak_lanjut\": [{{\"tugas\": \"tugas yang disepakati{wajib}\", \
             \"penanggung_jawab\": \"nama atau jabatan; kosongkan bila tidak \
             disebutkan\", \"tenggat\": \"tenggat seperti disebutkan; kosongkan \
             bila tidak ada\", \"segmen\": [6]}}],\n"
        ),
        other => format!("  \"{other}\": \"\"{wajib},\n"),
    }
}

/// Extra instructions a template needs beyond the shared rules.
#[flutter_rust_bridge::frb(ignore)]
pub fn template_notes(template: NotulenTemplate) -> &'static str {
    match template {
        NotulenTemplate::Dinas => {
            "Bentuk naskah: notula rapat. Kelompokkan pembahasan per topik, bukan \
             per pembicara. Keputusan ditulis sebagai kalimat yang berdiri sendiri \
             dan dapat dilaksanakan."
        }
        NotulenTemplate::Risalah => {
            "Bentuk naskah: risalah rapat (verbatim-ringkas). Isi \
             \"jalannya_rapat\" harus BERURUTAN sesuai transkrip, satu entri per \
             pembicara setiap kali ia menyampaikan pokok baru. Ringkas kalimatnya, \
             tetapi jangan menggabungkan dua pembicara menjadi satu entri dan \
             jangan mengubah urutannya."
        }
        NotulenTemplate::BeritaAcara => {
            "Bentuk naskah: berita acara. Isi \"pihak\" dengan para pihak yang \
             hadir dan bertanda tangan, sebutkan nama beserta jabatannya seperti \
             di transkrip. \"pembahasan\" berisi apa yang TELAH DILAKSANAKAN, \
             ditulis sebagai fakta yang sudah terjadi. \"keputusan\" berisi \
             kesepakatan para pihak. Jangan menulis formula penutup \
             (\"Demikian Berita Acara ini dibuat…\") — formula itu ditambahkan \
             oleh aplikasi."
        }
        NotulenTemplate::Ringkas => {
            "Bentuk naskah: notulen ringkas satu halaman. Maksimal 5 topik \
             pembahasan dan masing-masing paling banyak 2 kalimat. Jangan \
             memanjangkan uraian."
        }
    }
}

/// The user message: instruction, schema, transcript, and the notulis's
/// own marks.
///
/// `transcript` must be the numbered rendering from
/// [`crate::provenance::numbered_transcript`] — the `segmen` field is
/// meaningless otherwise, and a model given unnumbered text invents ids
/// rather than omitting them.
#[flutter_rust_bridge::frb(ignore)]
pub fn user_prompt(template: NotulenTemplate, transcript: &str, bookmarks: &[String]) -> String {
    let mut prompt = format!(
        "Susun {} dari transkrip di bawah ini.\n\n{}\n\nKERANGKA JSON:\n{}\n\n\
         --- TRANSKRIP (bernomor segmen) ---\n{}\n--- AKHIR TRANSKRIP ---",
        template.document_title(),
        template_notes(template),
        schema_block(template),
        transcript.trim()
    );
    let marks: Vec<&str> = bookmarks
        .iter()
        .map(|b| b.trim())
        .filter(|b| !b.is_empty())
        .collect();
    if !marks.is_empty() {
        prompt.push_str(
            "\n\n--- POIN YANG DITANDAI NOTULIS (utamakan, tetapi tetap hanya \
             gunakan isi transkrip) ---\n",
        );
        prompt.push_str(&marks.join("\n"));
        prompt.push_str("\n--- AKHIR POIN DITANDAI ---");
    }
    prompt
}

/// The map step's instruction for one window of a long meeting.
///
/// Returns notes, not JSON: eighteen partial JSON objects would have to
/// be merged by a second model pass that has no way to resolve their
/// conflicts, whereas notes reduce cleanly. The reduce step is what emits
/// the schema.
#[flutter_rust_bridge::frb(ignore)]
pub fn map_prompt(index: u32, total: u32, label: &str) -> String {
    format!(
        "Ini BAGIAN {index} dari {total} sebuah rapat panjang (menit {label}). \
         Buat catatan padat dari bagian ini saja, dalam bahasa Indonesia baku: \
         topik yang dibahas, keputusan yang diambil, tugas yang disepakati \
         beserta penanggung jawab dan tenggatnya, serta angka dan nama penting \
         yang disebut. Sertakan nomor segmen dalam tanda siku di akhir setiap \
         poin, misalnya [#12]. Tulis sebagai daftar poin, bukan paragraf, dan \
         bukan JSON. Jangan menyimpulkan keseluruhan rapat — bagian lain belum \
         Anda lihat."
    )
}

/// The reduce step's instruction, over the collected notes.
#[flutter_rust_bridge::frb(ignore)]
pub fn reduce_prompt(template: NotulenTemplate, notes: &str) -> String {
    format!(
        "Di bawah ini catatan per bagian dari satu rapat panjang, berurutan, \
         dengan nomor segmen transkrip dalam tanda siku. Gabungkan menjadi SATU \
         {} utuh — bukan ringkasan dari ringkasan yang mengulang struktur per \
         bagian. Hilangkan pengulangan, gabungkan tugas yang sama, dan \
         pertahankan setiap keputusan, nama, angka, tenggat dan nomor segmen \
         yang disebut.\n\n{}\n\nKERANGKA JSON:\n{}\n\n--- CATATAN PER BAGIAN ---\n{}\n\
         --- AKHIR CATATAN ---",
        template.document_title(),
        template_notes(template),
        schema_block(template),
        notes.trim()
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_system_prompt_states_every_non_negotiable_rule() {
        for template in NotulenTemplate::all() {
            let prompt = system_prompt(*template);
            // Refusal to invent, and the permission to leave a section
            // empty — the two lines that keep a notulen signable.
            assert!(prompt.contains("Jangan mengarang"), "{template:?}");
            assert!(
                prompt.contains("kosongkan daftar keputusan"),
                "{template:?}"
            );
            // Provenance.
            assert!(prompt.contains("segmen"), "{template:?}");
            // Register, with the Pedoman's concrete formats.
            assert!(prompt.contains("bahasa Indonesia baku"), "{template:?}");
            assert!(prompt.contains("pukul 09.00 WIB"), "{template:?}");
            assert!(prompt.contains("Rp8.500.000,00"), "{template:?}");
            assert!(prompt.contains("5 Oktober 2026"), "{template:?}");
            assert!(prompt.contains("4 (empat) persen"), "{template:?}");
            assert!(prompt.contains("dan lain-lain"), "{template:?}");
            // Output shape.
            assert!(prompt.contains("SATU objek JSON"), "{template:?}");
            // And it says which document it is writing.
            assert!(prompt.contains(template.document_title()), "{template:?}");
        }
    }

    #[test]
    fn the_schema_block_is_valid_json_shaped_and_names_every_section() {
        for template in NotulenTemplate::all() {
            let block = schema_block(*template);
            assert!(
                block.starts_with('{') && block.ends_with('}'),
                "{template:?}"
            );
            assert!(
                !block.contains(",\n}"),
                "{template:?} models a trailing comma: {block}"
            );
            for section in template.sections() {
                assert!(
                    block.contains(&format!("\"{}\"", section.key)),
                    "{template:?} omits {}",
                    section.key
                );
            }
        }
    }

    #[test]
    fn required_and_optional_sections_are_marked_differently() {
        let block = schema_block(NotulenTemplate::Dinas);
        assert!(block.contains("(WAJIB)"));
        assert!(block.contains("(opsional)"));
    }

    #[test]
    fn the_schema_block_only_asks_for_the_templates_own_sections() {
        // A berita acara asked for "agenda" produces an agenda, which is
        // not part of the naskah.
        let block = schema_block(NotulenTemplate::BeritaAcara);
        assert!(block.contains("\"pihak\""));
        assert!(!block.contains("\"agenda\""));
        assert!(!block.contains("\"jalannya_rapat\""));

        let ringkas = schema_block(NotulenTemplate::Ringkas);
        assert!(
            !ringkas.contains("\"peserta\""),
            "ringkas has no peserta list"
        );
        assert!(!ringkas.contains("\"pihak\""));
    }

    #[test]
    fn template_notes_are_distinct_and_name_the_shape() {
        let mut seen: Vec<&str> = Vec::new();
        for template in NotulenTemplate::all() {
            let notes = template_notes(*template);
            assert!(notes.contains("Bentuk naskah"), "{template:?}");
            assert!(!seen.contains(&notes), "{template:?} duplicates another");
            seen.push(notes);
        }
        // The shapes that are easy to get wrong are called out.
        assert!(template_notes(NotulenTemplate::Risalah).contains("BERURUTAN"));
        assert!(template_notes(NotulenTemplate::BeritaAcara).contains("TELAH DILAKSANAKAN"));
    }

    #[test]
    fn berita_acara_is_told_not_to_write_the_closing_formula() {
        // The formula is a fixed legal sentence the renderer owns. A model
        // that writes its own version of it produces two closings, one of
        // them wrong.
        assert!(template_notes(NotulenTemplate::BeritaAcara).contains("Demikian Berita Acara"));
        assert!(template_notes(NotulenTemplate::BeritaAcara).contains("Jangan menulis"));
    }

    #[test]
    fn user_prompt_includes_length_instruction_for_each_preset() {
        for panjang in [
            NotulenLength::Ringkas,
            NotulenLength::Sedang,
            NotulenLength::Lengkap,
        ] {
            let prompt = user_prompt(NotulenTemplate::Dinas, "transkrip", &[], panjang, None);
            let target = panjang.target_words();
            assert!(
                prompt.contains(&target.to_string()),
                "prompt untuk {panjang:?} harus menyebut target {target} kata:\n{prompt}"
            );
        }
    }

    #[test]
    fn reduce_prompt_includes_length_instruction() {
        let prompt = reduce_prompt(
            NotulenTemplate::Dinas,
            "catatan",
            NotulenLength::Ringkas,
            None,
        );
        assert!(prompt.contains(&NotulenLength::Ringkas.target_words().to_string()));
    }

    #[test]
    fn user_prompt_includes_document_context_when_present() {
        let with_ctx = user_prompt(
            NotulenTemplate::Dinas,
            "transkrip",
            &[],
            NotulenLength::Sedang,
            Some("Isi dokumen rujukan."),
        );
        let without_ctx = user_prompt(
            NotulenTemplate::Dinas,
            "transkrip",
            &[],
            NotulenLength::Sedang,
            None,
        );
        assert!(with_ctx.contains("Isi dokumen rujukan."));
        assert!(!without_ctx.contains("KONTEKS DOKUMEN"));
        assert!(with_ctx.contains("KONTEKS DOKUMEN"));
    }

    #[test]
    fn the_user_prompt_embeds_schema_transcript_and_marks() {
        let prompt = user_prompt(
            NotulenTemplate::Dinas,
            "[1] 00:00 (Pimpinan): rapat dibuka",
            &["[05:12] keputusan penting".to_string()],
            NotulenLength::Sedang,
            None,
        );
        assert!(prompt.contains("KERANGKA JSON"));
        assert!(prompt.contains("\"keputusan\""));
        assert!(prompt.contains("rapat dibuka"));
        assert!(prompt.contains("--- AKHIR TRANSKRIP ---"));
        assert!(prompt.contains("[05:12] keputusan penting"));
        // The marks come after the transcript, so truncating the
        // transcript cannot drop them.
        assert!(
            prompt.find("--- AKHIR TRANSKRIP ---").unwrap()
                < prompt.find("[05:12] keputusan penting").unwrap()
        );
        // And the marks do not override the no-invention rule.
        assert!(prompt.contains("tetap hanya gunakan isi transkrip"));
    }

    #[test]
    fn a_prompt_without_marks_has_no_marks_block() {
        let plain = user_prompt(NotulenTemplate::Dinas, "[1] 00:00 (A): halo", &[]);
        let blank = user_prompt(
            NotulenTemplate::Dinas,
            "[1] 00:00 (A): halo",
            &[String::new(), "  ".to_string()],
        );
        assert_eq!(plain, blank);
        assert!(!plain.contains("DITANDAI"));
    }

    #[test]
    fn the_map_prompt_refuses_to_conclude_and_asks_for_notes() {
        let prompt = map_prompt(3, 10, "20:00–30:00");
        assert!(prompt.contains("BAGIAN 3 dari 10"));
        assert!(prompt.contains("20:00–30:00"));
        assert!(prompt.contains("bukan JSON"));
        assert!(prompt.contains("Jangan menyimpulkan keseluruhan rapat"));
        assert!(
            prompt.contains("[#12]"),
            "segment ids must survive the map step"
        );
    }

    #[test]
    fn the_reduce_prompt_asks_for_one_document_in_the_schema() {
        let prompt = reduce_prompt(NotulenTemplate::Dinas, "## Bagian 1\n- halo [#1]");
        assert!(prompt.contains("SATU NOTULA RAPAT utuh"));
        assert!(prompt.contains("KERANGKA JSON"));
        assert!(prompt.contains("\"tindak_lanjut\""));
        assert!(prompt.contains("- halo [#1]"));
        assert!(prompt.contains("nomor segmen"));
    }

    /// The bake-off that picked the default model must have used the
    /// prompt the app ships.
    ///
    /// `ml/` is not part of the build (see `ml/README.md`), so the copy is
    /// compared at test time rather than included at compile time. A
    /// checkout without `ml/` skips: the sync only has to hold where both
    /// halves exist.
    #[test]
    fn the_benchmark_prompts_match_the_shipped_ones() {
        let Some(dir) = bench_prompt_dir() else {
            eprintln!("ml/notulen_bench/prompts absent — skipping prompt sync check");
            return;
        };
        for (name, expected) in prompt_files() {
            let path = dir.join(&name);
            let actual = std::fs::read_to_string(&path).unwrap_or_else(|e| {
                panic!(
                    "{} is missing ({e}); regenerate with \
                     TRAREON_DUMP_PROMPTS=1 cargo test -p trareon_core \
                     dump_notulen_prompts",
                    path.display()
                )
            });
            assert_eq!(
                actual.trim_end(),
                expected.trim_end(),
                "{} drifted from the shipped prompt; regenerate with \
                 TRAREON_DUMP_PROMPTS=1 cargo test -p trareon_core \
                 dump_notulen_prompts",
                path.display()
            );
        }
    }

    fn bench_prompt_dir() -> Option<std::path::PathBuf> {
        let root = std::path::PathBuf::from(
            std::env::var("CARGO_MANIFEST_DIR").unwrap_or_else(|_| ".".into()),
        );
        let dir = root.join("../ml/notulen_bench/prompts");
        dir.is_dir().then_some(dir)
    }

    /// Placeholder the benchmark substitutes the transcript into.
    ///
    /// The whole user prompt is mirrored, not just its parts: the
    /// sentence that wraps them ("Susun NOTULA RAPAT dari transkrip di
    /// bawah ini") is prompt text too, and a benchmark that reassembled
    /// it from the parts would be free to reassemble it differently.
    const TRANSCRIPT_SLOT: &str = "<<TRANSKRIP>>";

    /// `(filename, contents)` for every prompt the benchmark mirrors.
    fn prompt_files() -> Vec<(String, String)> {
        let mut out = Vec::new();
        for template in NotulenTemplate::all() {
            for (suffix, text) in [
                ("system", system_prompt(*template)),
                ("notes", template_notes(*template).to_string()),
                ("schema", schema_block(*template)),
                ("user", user_prompt(*template, TRANSCRIPT_SLOT, &[])),
            ] {
                out.push((format!("{}.{suffix}.txt", template.id()), text));
            }
        }
        out
    }

    #[test]
    fn the_mirrored_user_prompt_has_exactly_one_transcript_slot() {
        for template in NotulenTemplate::all() {
            let prompt = user_prompt(*template, TRANSCRIPT_SLOT, &[]);
            assert_eq!(
                prompt.matches(TRANSCRIPT_SLOT).count(),
                1,
                "{template:?}: the benchmark substitutes this placeholder once"
            );
        }
    }

    /// Writes the benchmark's copy of the prompts when
    /// `TRAREON_DUMP_PROMPTS` is set. A no-op in the normal test run.
    ///
    /// Same pattern as `export::notulen`'s DOCX dump: the alternative is a
    /// binary in `Cargo.toml` that exists only to print four strings.
    #[test]
    fn dump_notulen_prompts() {
        if std::env::var("TRAREON_DUMP_PROMPTS").is_err() {
            return;
        }
        let dir = bench_prompt_dir().expect("ml/notulen_bench/prompts must exist to dump into");
        for (name, text) in prompt_files() {
            std::fs::write(dir.join(name), format!("{text}\n")).unwrap();
        }
    }
}
