//! First-run setup for the local notulen model.
//!
//! # The problem this solves
//!
//! Before this, the notulen feature's failure mode for a new user was a
//! toast reading "tidak bisa menghubungi http://localhost:11434". That
//! is accurate and useless: the user has not installed Ollama, does not
//! know what Ollama is, and has no way to find out from the app.
//!
//! So the setup step detects the runtime, explains how to install it for
//! the operating system the user is actually on, recommends a model that
//! fits the machine the user actually has, and pulls it with visible
//! progress.
//!
//! # Local-only, and listed as such
//!
//! Everything here is pure: hardware thresholds, the catalogue, the
//! install text, and the parser for Ollama's pull-progress stream. The
//! two functions that open a socket — detection and the pull itself —
//! live in [`crate::summary`], which is one of the two modules
//! `privacy.rs` allows to do that. This module is in that gate's
//! `local_only` list, so moving an HTTP call in here fails the build.
//!
//! # Why the recommendation is hardware-aware
//!
//! A 9B model at Q4 needs around 6 GB resident. On a 16 GB laptop that
//! is fine; on an 8 GB one it swaps, and swapping makes a notulen take
//! twenty minutes instead of two — which the user experiences as "the
//! feature is broken", not as "my laptop is small". The thresholds come
//! from the resident footprints `ml/notulen_bench` measured through
//! Ollama's `/api/ps`, not from the download sizes, which understate the
//! requirement by the size of the KV cache.

use serde::{Deserialize, Serialize};

/// What the machine can run.
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct HardwareProfile {
    pub ram_gb: f64,
    /// Dedicated GPU memory, or 0.0 when there is none or it is unknown.
    pub vram_gb: f64,
    pub cpu_threads: u32,
}

impl HardwareProfile {
    /// Reads RAM and thread count from the running system.
    ///
    /// VRAM is left at 0.0: there is no portable way to read it without
    /// a GPU dependency this app does not otherwise need, and the
    /// recommendation degrades gracefully — a machine with a GPU gets
    /// the CPU-safe answer, which is slower than it could be but never
    /// wrong. The UI lets the user raise it.
    #[flutter_rust_bridge::frb(ignore)]
    pub fn probe() -> Self {
        use sysinfo::System;
        let mut sys = System::new();
        sys.refresh_memory();
        Self {
            ram_gb: sys.total_memory() as f64 / 1024.0 / 1024.0 / 1024.0,
            vram_gb: 0.0,
            cpu_threads: std::thread::available_parallelism()
                .map(|n| n.get() as u32)
                .unwrap_or(1),
        }
    }

    /// Memory the model may use: VRAM when there is enough of it to hold
    /// a model, otherwise RAM minus what the rest of the machine needs.
    ///
    /// 4 GB held back, not a percentage: the figure that matters is the
    /// absolute working set of the desktop, the browser the user has
    /// open, and Trareon's own Whisper model, and that does not shrink
    /// on a smaller machine.
    #[flutter_rust_bridge::frb(ignore)]
    pub fn usable_gb(&self) -> f64 {
        let from_ram = (self.ram_gb - 4.0).max(0.0);
        if self.vram_gb >= 4.0 {
            self.vram_gb.max(from_ram)
        } else {
            from_ram
        }
    }
}

/// Which of the three answers a machine gets.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum LlmTier {
    /// Runs on a 4-core laptop with no GPU. Slow but finishes.
    Ringan,
    /// The default: the best quality that fits a 16 GB machine.
    Seimbang,
    /// For a workstation or a GPU with 8 GB or more.
    Berat,
}

impl LlmTier {
    #[flutter_rust_bridge::frb(ignore)]
    pub fn label(self) -> &'static str {
        match self {
            Self::Ringan => "Ringan",
            Self::Seimbang => "Seimbang (disarankan)",
            Self::Berat => "Berat",
        }
    }
}

/// One entry of the model catalogue the setup step offers.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ModelOption {
    /// Ollama tag, exactly as `ollama pull` takes it.
    pub tag: String,
    pub label: String,
    pub tier: LlmTier,
    /// Download size, GiB, converted from what `ollama list` reports in
    /// decimal GB.
    pub unduh_gb: f64,
    /// Resident footprint while generating, GiB — measured from
    /// `/api/ps`, not derived from the download size.
    ///
    /// Usually larger than [`Self::unduh_gb`], but not always: a
    /// multimodal tag ships a vision projector that a text-only request
    /// never loads, so Gemma 3 4B downloads 3.1 GiB and resides in 2.7.
    pub residen_gb: f64,
    /// Context window the tag advertises, in tokens.
    pub konteks: u32,
    pub lisensi: String,
    /// One or two sentences, in Indonesian, on when to pick this.
    pub catatan: String,
}

/// The model the app configures when the user accepts the default.
///
/// Chosen by the bake-off in `ml/NOTULEN-BENCHMARK.md`, not by
/// reputation: the two prior research rounds recommended two different
/// models and neither recommendation was measurable from the literature.
///
/// Deliberately **not** the highest-scoring model. Gemma 3 12B won the
/// composite (0.868 against 0.816), and three things keep it out of the
/// default slot — see `NOTULEN-BENCHMARK.md` §8.1:
///
/// * its licence has conditions, and the default is the one model the
///   app configures *without asking*;
/// * its citation accuracy is 0.715 against this model's 1.000, so
///   provenance and the fact check would flag three statements in ten as
///   untraceable for a user who chose nothing;
/// * it needs 8.3 GiB resident against 6.1.
pub const DEFAULT_MODEL: &str = "qwen3:8b";

/// The catalogue, in the order the setup step lists it.
///
/// Both size columns come from the bake-off run on a 6 GB GPU
/// (`ml/NOTULEN-BENCHMARK.md` §6.3): `residen_gb` is what Ollama's
/// `/api/ps` reported while generating, `unduh_gb` is `ollama list`
/// converted to GiB. On a CPU-only machine the resident figure is the
/// same but the speed is roughly an order of magnitude lower.
///
/// Two models that were measured are deliberately absent — see
/// `the_two_models_the_bake_off_rejected_stay_out_of_the_catalogue`.
#[flutter_rust_bridge::frb(ignore)]
pub fn catalogue() -> Vec<ModelOption> {
    vec![
        ModelOption {
            tag: "qwen3:4b".to_string(),
            label: "Qwen3 4B".to_string(),
            tier: LlmTier::Ringan,
            unduh_gb: 2.3,
            residen_gb: 3.6,
            konteks: 40_960,
            lisensi: "Apache-2.0".to_string(),
            catatan: "Pilihan untuk laptop tanpa kartu grafis: 29 detik per \
                      rapat dan tidak mengarang satu keputusan pun di uji \
                      banding. Lisensi Apache-2.0. Kelemahannya ada di \
                      kelengkapan — bagian wajib lebih sering kosong \
                      daripada bawaan, dan satu dari delapan rapat uji gagal \
                      menghasilkan JSON yang sah."
                .to_string(),
        },
        ModelOption {
            tag: "gemma3:4b".to_string(),
            label: "Gemma 3 4B".to_string(),
            tier: LlmTier::Ringan,
            unduh_gb: 3.1,
            residen_gb: 2.7,
            konteks: 131_072,
            lisensi: "Gemma Terms of Use".to_string(),
            catatan: "Paling cepat di uji banding — 23 detik per rapat, \
                      sepuluh kali lebih cepat daripada bawaan. Tetapi ia \
                      mengarang satu keputusan pada rapat yang tidak \
                      memutuskan apa pun, dan hanya 61% pernyataannya \
                      menautkan nomor segmen yang cocok sehingga Periksa \
                      Fakta sulit menelusurinya. Lisensi Gemma perlu \
                      ditelaah. Pilih bila kecepatan lebih penting daripada \
                      ketelitian, dan periksa hasilnya."
                .to_string(),
        },
        ModelOption {
            tag: "qwen3:8b".to_string(),
            label: "Qwen3 8B".to_string(),
            tier: LlmTier::Seimbang,
            unduh_gb: 4.8,
            residen_gb: 6.1,
            konteks: 40_960,
            lisensi: "Apache-2.0".to_string(),
            catatan: "Bawaan Trareon. Skor tertinggi pada uji banding \
                      notulen (komposit 0,816), satu-satunya model yang \
                      tidak mengarang satu keputusan pun sekaligus \
                      menautkan nomor segmen dengan tepat pada setiap \
                      pernyataan. Lisensi Apache-2.0 sehingga bebas dipakai \
                      di instansi. Lebih lambat: sekitar 226 detik per \
                      rapat pada kartu grafis 6 GB. Rincian: \
                      ml/NOTULEN-BENCHMARK.md."
                .to_string(),
        },
        ModelOption {
            tag: "gemma3:12b".to_string(),
            label: "Gemma 3 12B".to_string(),
            tier: LlmTier::Berat,
            unduh_gb: 7.5,
            residen_gb: 8.3,
            konteks: 131_072,
            lisensi: "Gemma Terms of Use".to_string(),
            catatan: "Skor tertinggi di uji banding (komposit 0,868): \
                      semua bagian wajib terisi, tidak mengarang keputusan, \
                      dan tabel tindak lanjutnya paling lengkap. Bukan \
                      bawaan karena tiga hal: lisensi Gemma perlu ditelaah, \
                      hanya 72% pernyataannya menautkan nomor segmen yang \
                      cocok, dan ia butuh 8,3 GB saat bekerja. Paling \
                      lambat juga — 277 detik per rapat pada kartu 6 GB. \
                      Pilih bila mesin Anda besar dan lisensinya sudah \
                      ditelaah instansi."
                .to_string(),
        },
    ]
}

/// The catalogue entry for `tag`, if it is one of ours.
#[flutter_rust_bridge::frb(ignore)]
pub fn option_for(tag: &str) -> Option<ModelOption> {
    catalogue().into_iter().find(|option| option.tag == tag)
}

/// What the setup step recommends for this machine.
#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct Recommendation {
    pub model: ModelOption,
    /// Why this one, in Indonesian, naming the machine's numbers.
    pub alasan: String,
    /// `true` when nothing in the catalogue fits and the recommendation
    /// is the lightest option as a best effort.
    pub terlalu_kecil: bool,
}

/// Picks the heaviest catalogue entry whose resident footprint fits.
///
/// Prefers [`DEFAULT_MODEL`] when it fits rather than the absolute
/// heaviest: the default won the bake-off, and a bigger model that
/// scored lower is not an upgrade.
#[flutter_rust_bridge::frb(ignore)]
pub fn recommend(hardware: &HardwareProfile) -> Recommendation {
    let usable = hardware.usable_gb();
    let catalogue = catalogue();
    let default = catalogue
        .iter()
        .find(|option| option.tag == DEFAULT_MODEL)
        .cloned()
        .unwrap_or_else(|| catalogue[0].clone());

    if usable >= default.residen_gb {
        return Recommendation {
            alasan: format!(
                "RAM terpasang {:.0} GB, tersedia sekitar {:.0} GB untuk model. \
                 {} butuh {:.1} GB dan merupakan bawaan Trareon.",
                hardware.ram_gb, usable, default.label, default.residen_gb
            ),
            model: default,
            terlalu_kecil: false,
        };
    }

    let fitting = catalogue
        .iter()
        .filter(|option| usable >= option.residen_gb)
        .max_by(|a, b| a.residen_gb.total_cmp(&b.residen_gb))
        .cloned();
    match fitting {
        Some(model) => Recommendation {
            alasan: format!(
                "RAM terpasang {:.0} GB, tersedia sekitar {:.0} GB untuk model, \
                 sehingga {} ({:.1} GB) belum masuk. {} adalah pilihan terbaik \
                 yang muat.",
                hardware.ram_gb, usable, default.label, default.residen_gb, model.label
            ),
            model,
            terlalu_kecil: false,
        },
        None => {
            let lightest = catalogue
                .iter()
                .min_by(|a, b| a.residen_gb.total_cmp(&b.residen_gb))
                .cloned()
                .unwrap_or(default);
            Recommendation {
                alasan: format!(
                    "RAM terpasang {:.0} GB, hanya sekitar {:.0} GB yang bisa \
                     dipakai model. {} ({:.1} GB) tetap bisa dicoba, tetapi \
                     komputer akan memakai swap dan prosesnya jauh lebih lama. \
                     Pertimbangkan menambah RAM atau memakai endpoint di \
                     komputer lain.",
                    hardware.ram_gb, usable, lightest.label, lightest.residen_gb
                ),
                model: lightest,
                terlalu_kecil: true,
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Install guidance
// ---------------------------------------------------------------------------

/// How to install Ollama on one operating system.
#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct InstallGuide {
    /// "macOS", "Windows", "Linux".
    pub sistem: String,
    /// Numbered steps, in Indonesian.
    pub langkah: Vec<String>,
    /// The official download page.
    pub tautan: String,
    /// A command the user can copy, or empty when the install is a
    /// downloaded installer.
    pub perintah: String,
}

/// The guidance for `os`, which is `std::env::consts::OS` or anything
/// recognisable.
///
/// Returns the Linux guidance for an unknown platform rather than
/// nothing: the one-line script is correct on every Linux-like system,
/// and an empty panel teaches the user nothing.
#[flutter_rust_bridge::frb(ignore)]
pub fn install_guide(os: &str) -> InstallGuide {
    let lower = os.to_lowercase();
    if lower.contains("mac") || lower.contains("darwin") || lower.contains("ios") {
        return InstallGuide {
            sistem: "macOS".to_string(),
            langkah: vec![
                "Unduh Ollama untuk macOS dari ollama.com/download.".to_string(),
                "Buka berkas .zip, lalu pindahkan Ollama ke folder Applications.".to_string(),
                "Jalankan Ollama sekali; ikonnya akan muncul di menu bar dan \
                 layanannya berjalan di latar belakang."
                    .to_string(),
                "Kembali ke Trareon dan tekan \"Periksa lagi\".".to_string(),
            ],
            tautan: "https://ollama.com/download".to_string(),
            perintah: "brew install --cask ollama".to_string(),
        };
    }
    if lower.contains("win") {
        return InstallGuide {
            sistem: "Windows".to_string(),
            langkah: vec![
                "Unduh OllamaSetup.exe dari ollama.com/download.".to_string(),
                "Jalankan pemasangnya. Pemasangan tidak memerlukan hak \
                 administrator."
                    .to_string(),
                "Ollama berjalan otomatis setelah pemasangan dan muncul di \
                 area notifikasi."
                    .to_string(),
                "Kembali ke Trareon dan tekan \"Periksa lagi\".".to_string(),
            ],
            tautan: "https://ollama.com/download".to_string(),
            perintah: "winget install Ollama.Ollama".to_string(),
        };
    }
    InstallGuide {
        sistem: "Linux".to_string(),
        langkah: vec![
            "Jalankan perintah pemasangan di terminal.".to_string(),
            "Pemasang akan membuat layanan systemd bernama ollama dan \
             menjalankannya."
                .to_string(),
            "Periksa dengan `systemctl status ollama` bila layanannya tidak \
             langsung berjalan."
                .to_string(),
            "Kembali ke Trareon dan tekan \"Periksa lagi\".".to_string(),
        ],
        tautan: "https://ollama.com/download/linux".to_string(),
        perintah: "curl -fsSL https://ollama.com/install.sh | sh".to_string(),
    }
}

// ---------------------------------------------------------------------------
// Pull progress
// ---------------------------------------------------------------------------

/// One line of Ollama's `/api/pull` stream, parsed.
#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct PullProgress {
    /// Ollama's own status text, e.g. "pulling manifest".
    pub status: String,
    /// Indonesian rendering of `status`, for the UI.
    pub label: String,
    pub selesai_bytes: u64,
    pub total_bytes: u64,
    /// `true` once the pull has finished successfully.
    pub done: bool,
}

impl PullProgress {
    /// `0.0..=1.0`, or `0.0` while the size is still unknown.
    #[flutter_rust_bridge::frb(ignore)]
    pub fn fraction(&self) -> f64 {
        if self.done {
            return 1.0;
        }
        if self.total_bytes == 0 {
            return 0.0;
        }
        (self.selesai_bytes as f64 / self.total_bytes as f64).clamp(0.0, 1.0)
    }
}

/// Translates Ollama's status strings, which are English and not stable
/// enough to match exhaustively.
fn status_label(status: &str) -> String {
    let lower = status.to_lowercase();
    if lower.contains("manifest") {
        "Mengambil daftar berkas model…".to_string()
    } else if lower.contains("pulling") {
        "Mengunduh model…".to_string()
    } else if lower.contains("verifying") {
        "Memverifikasi berkas…".to_string()
    } else if lower.contains("writing") || lower.contains("extracting") {
        "Menulis ke penyimpanan…".to_string()
    } else if lower.contains("success") {
        "Selesai.".to_string()
    } else if lower.is_empty() {
        "Menyiapkan…".to_string()
    } else {
        // Unknown but non-empty: show it rather than hide it. A status
        // the app does not recognise is still information.
        status.to_string()
    }
}

/// Parses one newline-delimited JSON line of the pull stream.
///
/// Returns `None` for a blank line or anything that is not JSON, which
/// the stream does contain: Ollama sends keep-alive newlines.
#[flutter_rust_bridge::frb(ignore)]
pub fn parse_pull_line(line: &str) -> Option<PullProgress> {
    let trimmed = line.trim();
    if trimmed.is_empty() {
        return None;
    }
    let value: serde_json::Value = serde_json::from_str(trimmed).ok()?;
    if let Some(error) = value.get("error").and_then(|e| e.as_str()) {
        return Some(PullProgress {
            status: "error".to_string(),
            label: format!("Gagal: {error}"),
            selesai_bytes: 0,
            total_bytes: 0,
            done: false,
        });
    }
    let status = value
        .get("status")
        .and_then(|s| s.as_str())
        .unwrap_or_default()
        .to_string();
    Some(PullProgress {
        label: status_label(&status),
        done: status.eq_ignore_ascii_case("success"),
        selesai_bytes: value.get("completed").and_then(|v| v.as_u64()).unwrap_or(0),
        total_bytes: value.get("total").and_then(|v| v.as_u64()).unwrap_or(0),
        status,
    })
}

/// Whether a pull stream's lines ended in success.
#[flutter_rust_bridge::frb(ignore)]
pub fn pull_succeeded(lines: &[String]) -> bool {
    lines
        .iter()
        .filter_map(|line| parse_pull_line(line))
        .any(|progress| progress.done)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn machine(ram_gb: f64, vram_gb: f64) -> HardwareProfile {
        HardwareProfile {
            ram_gb,
            vram_gb,
            cpu_threads: 8,
        }
    }

    // --- hardware --------------------------------------------------------

    #[test]
    fn usable_memory_holds_back_what_the_rest_of_the_machine_needs() {
        assert_eq!(machine(16.0, 0.0).usable_gb(), 12.0);
        assert_eq!(machine(8.0, 0.0).usable_gb(), 4.0);
        // Not negative on a tiny machine.
        assert_eq!(machine(2.0, 0.0).usable_gb(), 0.0);
    }

    #[test]
    fn a_real_gpu_raises_the_budget_but_a_tiny_one_does_not() {
        // 8 GB of VRAM beats 4 GB of spare RAM.
        assert_eq!(machine(8.0, 8.0).usable_gb(), 8.0);
        // 2 GB of VRAM cannot hold a model, so RAM still decides.
        assert_eq!(machine(16.0, 2.0).usable_gb(), 12.0);
    }

    #[test]
    fn probing_the_real_machine_reports_something_plausible() {
        let profile = HardwareProfile::probe();
        assert!(profile.ram_gb > 0.1, "ram: {}", profile.ram_gb);
        assert!(profile.cpu_threads >= 1);
    }

    // --- recommendation --------------------------------------------------

    #[test]
    fn a_sixteen_gigabyte_machine_gets_the_benchmark_default() {
        let recommendation = recommend(&machine(16.0, 0.0));
        assert_eq!(recommendation.model.tag, DEFAULT_MODEL);
        assert!(!recommendation.terlalu_kecil);
        assert!(recommendation.alasan.contains("16 GB"));
    }

    #[test]
    fn an_eight_gigabyte_machine_is_offered_the_light_model() {
        let recommendation = recommend(&machine(8.0, 0.0));
        assert_eq!(recommendation.model.tier, LlmTier::Ringan);
        assert!(!recommendation.terlalu_kecil);
        // The reason names both the default and why it does not fit.
        assert!(recommendation.alasan.contains("Qwen3 8B"));
        assert!(recommendation.alasan.contains("belum masuk"));
    }

    #[test]
    fn a_machine_too_small_for_anything_is_told_so_plainly() {
        let recommendation = recommend(&machine(4.0, 0.0));
        assert!(recommendation.terlalu_kecil);
        assert!(recommendation.alasan.contains("swap"));
        assert!(recommendation.alasan.contains("menambah RAM"));
        // Still names a model: "nothing fits" must not mean "no button".
        assert!(!recommendation.model.tag.is_empty());
    }

    #[test]
    fn a_large_machine_still_gets_the_default_not_the_biggest_model() {
        // The heaviest catalogue entry scored lower in the bake-off, so
        // more memory is not a reason to recommend it.
        let recommendation = recommend(&machine(64.0, 24.0));
        assert_eq!(recommendation.model.tag, DEFAULT_MODEL);
    }

    // --- catalogue -------------------------------------------------------

    #[test]
    fn the_catalogue_covers_every_tier_and_names_a_licence() {
        let catalogue = catalogue();
        assert!(catalogue.len() >= 4);
        for tier in [LlmTier::Ringan, LlmTier::Seimbang, LlmTier::Berat] {
            assert!(
                catalogue.iter().any(|option| option.tier == tier),
                "no option for {tier:?}"
            );
        }
        for option in &catalogue {
            assert!(!option.lisensi.is_empty(), "{} has no licence", option.tag);
            assert!(!option.catatan.is_empty(), "{} has no note", option.tag);
            assert!(option.konteks >= 8_192, "{} context too small", option.tag);
            // Both figures are real measurements, so both must be set.
            //
            // This used to assert `residen > unduh`, on the reasoning
            // that the KV cache always adds to the weights. The bake-off
            // disproved it: Gemma 3 4B downloads 3.1 GiB and resides in
            // 2.7, because the tag ships a vision projector that a
            // text-only request never loads. The assumption was wrong,
            // not the measurement.
            assert!(option.unduh_gb > 0.0, "{} has no download size", option.tag);
            assert!(
                option.residen_gb > 0.0,
                "{} has no resident size",
                option.tag
            );
        }
    }

    #[test]
    fn the_default_model_is_in_the_catalogue_and_is_cleanly_licensed() {
        let default = option_for(DEFAULT_MODEL).expect("default is not in the catalogue");
        assert_eq!(default.tier, LlmTier::Seimbang);
        // The app configures this one without asking, so it cannot be a
        // licence that needs review first.
        assert_eq!(default.lisensi, "Apache-2.0");
    }

    #[test]
    fn an_unknown_tag_is_not_in_the_catalogue() {
        assert!(option_for("llama3:70b").is_none());
    }

    #[test]
    fn the_two_models_the_bake_off_rejected_stay_out_of_the_catalogue() {
        // Both are Indonesian/SEA-tuned and both are tempting to list for
        // that reason alone. `ml/NOTULEN-BENCHMARK.md` §8.4 is why they
        // are not here:
        //
        // * Sahabat-AI 9B answered the notulen prompt with an unrelated
        //   boilerplate object (`{"name": "John Doe", ...}`) in six of
        //   eight cases and failed to parse in the other two. Structure
        //   score 0.000.
        // * Apertus-SEA-LION v4 8B failed four of eight — two of them by
        //   running past 900 s — and invented a decision for a meeting
        //   that took none.
        //
        // The catalogue is what the app *recommends*. A model that fails
        // half the time cannot be recommended, however good its licence.
        for rejected in [
            "Supa-AI/gemma2-9b-cpt-sahabatai-v1-instruct:q4_k_s",
            "aisingapore/Apertus-SEA-LION-v4-8B-IT:q4_k_m",
        ] {
            assert!(
                option_for(rejected).is_none(),
                "{rejected} failed the bake-off; see ml/NOTULEN-BENCHMARK.md §8.4"
            );
        }
    }

    #[test]
    fn the_light_tier_offers_both_a_clean_licence_and_the_fast_one() {
        let light: Vec<_> = catalogue()
            .into_iter()
            .filter(|option| option.tier == LlmTier::Ringan)
            .collect();
        // The fastest light model measured well but invented a decision
        // and cites poorly, so it cannot be the only light option — a
        // user on a small laptop must still be able to pick one whose
        // licence needs no review.
        assert!(
            light.iter().any(|option| option.lisensi == "Apache-2.0"),
            "no cleanly-licensed light option"
        );
        assert!(light.len() >= 2, "the light tier should offer a choice");
    }

    // --- install guidance ------------------------------------------------

    #[test]
    fn each_platform_gets_its_own_steps_and_a_copyable_command() {
        for (os, expected) in [
            ("macos", "macOS"),
            ("darwin", "macOS"),
            ("windows", "Windows"),
            ("linux", "Linux"),
        ] {
            let guide = install_guide(os);
            assert_eq!(guide.sistem, expected, "for {os}");
            assert!(guide.langkah.len() >= 3, "for {os}");
            assert!(guide.tautan.starts_with("https://ollama.com"), "for {os}");
            assert!(!guide.perintah.is_empty(), "for {os}");
            // Every platform ends by telling the user what to do next in
            // Trareon, which is the step a download page cannot give.
            assert!(
                guide.langkah.last().unwrap().contains("Periksa lagi"),
                "for {os}"
            );
        }
    }

    #[test]
    fn an_unknown_platform_falls_back_to_linux_rather_than_nothing() {
        let guide = install_guide("freebsd");
        assert_eq!(guide.sistem, "Linux");
        assert!(!guide.langkah.is_empty());
    }

    // --- pull progress ---------------------------------------------------

    #[test]
    fn pull_progress_is_read_from_the_stream_and_translated() {
        let progress = parse_pull_line(
            r#"{"status":"pulling 5d0a4b1f","digest":"sha256:ab","total":5200000000,"completed":2600000000}"#,
        )
        .unwrap();
        assert_eq!(progress.label, "Mengunduh model…");
        assert_eq!(progress.total_bytes, 5_200_000_000);
        assert!((progress.fraction() - 0.5).abs() < 1e-9);
        assert!(!progress.done);
    }

    #[test]
    fn the_manifest_and_success_lines_are_recognised() {
        let manifest = parse_pull_line(r#"{"status":"pulling manifest"}"#).unwrap();
        assert!(manifest.label.contains("daftar berkas"));
        assert_eq!(manifest.fraction(), 0.0, "size not known yet");

        let success = parse_pull_line(r#"{"status":"success"}"#).unwrap();
        assert!(success.done);
        assert_eq!(success.fraction(), 1.0);
    }

    #[test]
    fn an_unrecognised_status_is_shown_rather_than_hidden() {
        let progress = parse_pull_line(r#"{"status":"quantizing Q4_K_M"}"#).unwrap();
        assert_eq!(progress.label, "quantizing Q4_K_M");
    }

    #[test]
    fn an_error_line_becomes_an_indonesian_failure() {
        let progress = parse_pull_line(r#"{"error":"model \"nope\" not found"}"#).unwrap();
        assert!(progress.label.starts_with("Gagal:"));
        assert!(progress.label.contains("not found"));
        assert!(!progress.done);
    }

    #[test]
    fn blank_and_non_json_lines_are_skipped() {
        assert!(parse_pull_line("").is_none());
        assert!(parse_pull_line("   \n").is_none());
        assert!(parse_pull_line("<html>502</html>").is_none());
    }

    #[test]
    fn a_stream_without_a_success_line_did_not_succeed() {
        let partial = vec![
            r#"{"status":"pulling manifest"}"#.to_string(),
            r#"{"status":"pulling ab","total":10,"completed":4}"#.to_string(),
        ];
        assert!(!pull_succeeded(&partial));

        let mut complete = partial.clone();
        complete.push(r#"{"status":"success"}"#.to_string());
        assert!(pull_succeeded(&complete));
    }

    #[test]
    fn a_fraction_never_leaves_the_unit_interval() {
        // Ollama has reported completed > total mid-stream.
        let progress =
            parse_pull_line(r#"{"status":"pulling ab","total":10,"completed":99}"#).unwrap();
        assert_eq!(progress.fraction(), 1.0);
    }
}
