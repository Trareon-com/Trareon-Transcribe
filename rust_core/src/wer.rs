//! Word and character error rate (F18).
//!
//! The app has had no way to answer "is this model actually better for
//! Indonesian meetings?" except by reading transcripts and forming an
//! impression. This module is the arithmetic behind a number instead:
//! Levenshtein distance over words (WER) and over characters (CER),
//! against a reference a human wrote.
//!
//! # Normalisation
//!
//! Comparing raw strings measures punctuation habits, not transcription
//! quality — Whisper's commas are its own and no reference agrees with
//! them. So both sides are case-folded, stripped of punctuation and
//! whitespace-collapsed before alignment. Deliberately *not* done:
//! number expansion ("12" vs "dua belas") and abbreviation expansion
//! ("RAB" vs "rencana anggaran biaya"). Both are judgement calls that
//! would make this harness flatter one model over another, and a harness
//! that bakes in a preference is worse than no harness.
//!
//! CER is reported alongside WER because Indonesian affixation makes WER
//! brutal: "mempertanggungjawabkan" misheard by one syllable is a whole
//! word wrong, and CER says how near the miss was.

use serde::Serialize;

/// Case-folded, punctuation-free, whitespace-collapsed words.
///
/// Apostrophes and hyphens inside a word are kept: "sa'at" and
/// "undang-undang" are single Indonesian words, and splitting them would
/// invent two errors out of one.
pub fn normalise(text: &str) -> Vec<String> {
    text.split_whitespace()
        .map(|word| {
            word.chars()
                .filter(|c| c.is_alphanumeric() || *c == '\'' || *c == '-')
                .flat_map(|c| c.to_lowercase())
                .collect::<String>()
        })
        .map(|word| word.trim_matches('-').to_string())
        .filter(|word| !word.is_empty())
        .collect()
}

/// Edit operations between a reference and a hypothesis.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Serialize)]
pub struct EditCounts {
    pub substitutions: usize,
    pub deletions: usize,
    pub insertions: usize,
    /// Length of the *reference*, which is what an error rate divides by.
    pub reference_len: usize,
}

impl EditCounts {
    pub fn errors(&self) -> usize {
        self.substitutions + self.deletions + self.insertions
    }

    /// Errors per reference token.
    ///
    /// An empty reference with a non-empty hypothesis is 1.0, not
    /// infinity: a rate is what callers average and format, and `inf`
    /// poisons every aggregate it touches. An empty reference *and* an
    /// empty hypothesis is 0.0 — nothing was asked and nothing was got
    /// wrong.
    pub fn rate(&self) -> f64 {
        if self.reference_len == 0 {
            return if self.insertions == 0 { 0.0 } else { 1.0 };
        }
        self.errors() as f64 / self.reference_len as f64
    }
}

/// Levenshtein alignment counting substitutions, deletions and insertions
/// separately.
///
/// Two rows rather than a full matrix: a three-hour meeting is ~30 000
/// words, and the full table would be 900 million cells.
fn align<T: PartialEq>(reference: &[T], hypothesis: &[T]) -> EditCounts {
    // (cost, substitutions, deletions, insertions)
    type Cell = (usize, usize, usize, usize);

    let mut previous: Vec<Cell> = (0..=hypothesis.len())
        .map(|insertions| (insertions, 0, 0, insertions))
        .collect();
    let mut current: Vec<Cell> = vec![(0, 0, 0, 0); hypothesis.len() + 1];

    for (i, reference_token) in reference.iter().enumerate() {
        current[0] = (i + 1, 0, i + 1, 0);
        for (j, hypothesis_token) in hypothesis.iter().enumerate() {
            let matched = reference_token == hypothesis_token;
            let substitute = {
                let (cost, s, d, ins) = previous[j];
                if matched {
                    (cost, s, d, ins)
                } else {
                    (cost + 1, s + 1, d, ins)
                }
            };
            let delete = {
                let (cost, s, d, ins) = previous[j + 1];
                (cost + 1, s, d + 1, ins)
            };
            let insert = {
                let (cost, s, d, ins) = current[j];
                (cost + 1, s, d, ins + 1)
            };
            // Ties go substitution → deletion → insertion, which is the
            // conventional ordering and keeps the counts reproducible
            // across runs.
            current[j + 1] = [substitute, delete, insert]
                .into_iter()
                .min_by_key(|(cost, _, _, _)| *cost)
                .unwrap();
        }
        std::mem::swap(&mut previous, &mut current);
    }

    let (_, substitutions, deletions, insertions) = previous[hypothesis.len()];
    EditCounts {
        substitutions,
        deletions,
        insertions,
        reference_len: reference.len(),
    }
}

/// Word error rate between a reference and a hypothesis.
pub fn word_errors(reference: &str, hypothesis: &str) -> EditCounts {
    align(&normalise(reference), &normalise(hypothesis))
}

/// Character error rate, measured on the normalised words joined by
/// single spaces — so a missing word costs its characters plus one space,
/// not an arbitrary amount of whitespace.
pub fn char_errors(reference: &str, hypothesis: &str) -> EditCounts {
    let reference: Vec<char> = normalise(reference).join(" ").chars().collect();
    let hypothesis: Vec<char> = normalise(hypothesis).join(" ").chars().collect();
    align(&reference, &hypothesis)
}

/// One (audio, reference) pair's result.
#[derive(Debug, Clone, Serialize)]
pub struct ClipScore {
    pub clip: String,
    pub words: EditCounts,
    pub chars: EditCounts,
    /// Seconds of audio, for the real-time factor.
    pub audio_secs: f64,
    /// Seconds spent transcribing.
    pub elapsed_secs: f64,
    pub hypothesis: String,
}

impl ClipScore {
    /// Audio seconds per wall-clock second. Below 1.0 cannot keep up live.
    pub fn rtf(&self) -> f64 {
        if self.elapsed_secs <= 0.0 {
            return 0.0;
        }
        self.audio_secs / self.elapsed_secs
    }
}

/// Totals for one model across a manifest.
#[derive(Debug, Clone, Serialize)]
pub struct ModelScore {
    pub model: String,
    pub clips: Vec<ClipScore>,
}

impl ModelScore {
    /// Corpus-level WER: errors over the *whole* corpus, not the mean of
    /// per-clip rates.
    ///
    /// Averaging rates weights a four-word clip the same as a four-minute
    /// one, which is how a harness ends up reporting that the worse model
    /// won.
    pub fn word_error_rate(&self) -> f64 {
        Self::pooled(self.clips.iter().map(|c| c.words))
    }

    pub fn char_error_rate(&self) -> f64 {
        Self::pooled(self.clips.iter().map(|c| c.chars))
    }

    fn pooled(counts: impl Iterator<Item = EditCounts>) -> f64 {
        let mut total = EditCounts::default();
        for count in counts {
            total.substitutions += count.substitutions;
            total.deletions += count.deletions;
            total.insertions += count.insertions;
            total.reference_len += count.reference_len;
        }
        total.rate()
    }

    pub fn mean_rtf(&self) -> f64 {
        let audio: f64 = self.clips.iter().map(|c| c.audio_secs).sum();
        let elapsed: f64 = self.clips.iter().map(|c| c.elapsed_secs).sum();
        if elapsed <= 0.0 {
            0.0
        } else {
            audio / elapsed
        }
    }
}

/// Markdown comparison table, best WER first.
pub fn render_table(scores: &[ModelScore]) -> String {
    let mut ordered: Vec<&ModelScore> = scores.iter().collect();
    ordered.sort_by(|a, b| a.word_error_rate().total_cmp(&b.word_error_rate()));

    let mut out = String::from("| Model | WER | CER | RTF | Klip |\n|---|---|---|---|---|\n");
    for score in ordered {
        out.push_str(&format!(
            "| {} | {:.1}% | {:.1}% | {:.2}× | {} |\n",
            score.model,
            score.word_error_rate() * 100.0,
            score.char_error_rate() * 100.0,
            score.mean_rtf(),
            score.clips.len(),
        ));
    }
    out
}

/// Directive a manifest puts in a comment to permit empty references.
///
/// Opt-in rather than always-on: see [`parse_manifest`].
pub const ALLOW_EMPTY_REFERENCE: &str = "allow-empty-reference";

/// One line of a manifest: an audio path and the reference text.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ManifestEntry {
    pub audio: String,
    pub reference: String,
}

/// Parses a TSV manifest: `path<TAB>reference text`.
///
/// Blank lines and `#` comments are skipped so a manifest can be
/// annotated. A line without a tab is an error rather than a silently
/// skipped clip — a manifest that quietly measures fewer clips than it
/// lists produces a number nobody can reproduce.
///
/// A blank reference is an error **unless** the manifest opts in with
/// the directive [`ALLOW_EMPTY_REFERENCE`] in a comment line.
///
/// Both halves of that matter. A reference someone forgot to fill in is
/// a mistake worth refusing, which is why it stays an error by default.
/// But a *deliberately* empty reference is how a hallucination test set
/// is written: the audio is silence, so every word a model emits is an
/// insertion and a WER of 0% means it stayed quiet. `EditCounts::rate`
/// already handles a zero-length reference for exactly that case; only
/// this parser had no way to let one through.
///
/// Making the manifest declare its intent once, rather than inferring it
/// from whether anything follows the tab, keeps the two cases apart
/// without depending on whitespace an editor might add or strip.
pub fn parse_manifest(content: &str) -> Result<Vec<ManifestEntry>, String> {
    let allow_empty = content
        .lines()
        .take_while(|line| {
            let trimmed = line.trim();
            trimmed.is_empty() || trimmed.starts_with('#')
        })
        .any(|line| line.contains(ALLOW_EMPTY_REFERENCE));

    let mut entries = Vec::new();
    for (index, line) in content.lines().enumerate() {
        let trimmed = line.trim();
        if trimmed.is_empty() || trimmed.starts_with('#') {
            continue;
        }
        // Split the untrimmed line: trimming first eats a trailing tab,
        // which is exactly how an empty reference is written.
        let Some((audio, reference)) = line.split_once('\t') else {
            return Err(format!(
                "baris {} tidak punya TAB antara berkas dan teks acuan: {trimmed:?}",
                index + 1
            ));
        };
        let audio = audio.trim();
        if audio.is_empty() {
            return Err(format!("baris {} tidak punya nama berkas", index + 1));
        }
        let reference = reference.trim();
        if reference.is_empty() && !allow_empty {
            return Err(format!(
                "baris {} tidak punya teks acuan (tambahkan komentar \
                 `# {ALLOW_EMPTY_REFERENCE}` di kepala manifes bila ini \
                 memang set hening)",
                index + 1
            ));
        }
        entries.push(ManifestEntry {
            audio: audio.to_string(),
            reference: reference.to_string(),
        });
    }
    if entries.is_empty() {
        return Err("manifes tidak berisi satu pun klip".to_string());
    }
    Ok(entries)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn identical_text_has_no_errors() {
        let counts = word_errors("Rapat anggaran dimulai", "Rapat anggaran dimulai");
        assert_eq!(counts.errors(), 0);
        assert_eq!(counts.rate(), 0.0);
    }

    #[test]
    fn punctuation_and_case_are_not_errors() {
        let counts = word_errors("Rapat anggaran dimulai.", "rapat, anggaran  dimulai!");
        assert_eq!(counts.errors(), 0, "{counts:?}");
    }

    #[test]
    fn indonesian_hyphenated_words_stay_one_word() {
        assert_eq!(normalise("undang-undang dasar"), ["undang-undang", "dasar"]);
        let counts = word_errors("undang-undang", "undang undang");
        // One word became two: a substitution plus an insertion, not a
        // free pass.
        assert_eq!(counts.reference_len, 1);
        assert!(counts.errors() >= 1);
    }

    #[test]
    fn counts_each_edit_kind_separately() {
        // reference: a b c d ; hypothesis: a x c d e  (1 sub, 1 ins)
        let counts = word_errors("a b c d", "a x c d e");
        assert_eq!(counts.substitutions, 1, "{counts:?}");
        assert_eq!(counts.insertions, 1, "{counts:?}");
        assert_eq!(counts.deletions, 0, "{counts:?}");
        assert_eq!(counts.reference_len, 4);
        assert_eq!(counts.rate(), 0.5);
    }

    #[test]
    fn a_dropped_word_is_a_deletion() {
        let counts = word_errors("satu dua tiga", "satu tiga");
        assert_eq!(counts.deletions, 1, "{counts:?}");
        assert_eq!(counts.substitutions, 0);
        assert_eq!(counts.insertions, 0);
    }

    #[test]
    fn an_empty_hypothesis_is_a_total_loss_not_a_crash() {
        let counts = word_errors("satu dua tiga", "");
        assert_eq!(counts.deletions, 3);
        assert_eq!(counts.rate(), 1.0);
    }

    #[test]
    fn an_empty_reference_does_not_produce_infinity() {
        assert_eq!(word_errors("", "").rate(), 0.0);
        let hallucinated = word_errors("", "terima kasih telah menonton");
        assert_eq!(hallucinated.rate(), 1.0);
        assert!(hallucinated.rate().is_finite());
    }

    #[test]
    fn cer_is_gentler_than_wer_on_a_near_miss() {
        let reference = "mempertanggungjawabkan anggaran";
        let hypothesis = "mempertanggung jawabkan anggaran";
        let wer = word_errors(reference, hypothesis).rate();
        let cer = char_errors(reference, hypothesis).rate();
        assert!(
            cer < wer,
            "CER {cer} should be below WER {wer} for a one-space miss"
        );
    }

    #[test]
    fn corpus_wer_pools_errors_rather_than_averaging_rates() {
        let clip = |clip: &str, reference: &str, hypothesis: &str| ClipScore {
            clip: clip.to_string(),
            words: word_errors(reference, hypothesis),
            chars: char_errors(reference, hypothesis),
            audio_secs: 10.0,
            elapsed_secs: 5.0,
            hypothesis: hypothesis.to_string(),
        };
        let score = ModelScore {
            model: "tiny".into(),
            clips: vec![
                // 1 error in 1 word = 100%
                clip("short", "satu", "dua"),
                // 0 errors in 9 words = 0%
                clip(
                    "long",
                    "satu dua tiga empat lima enam tujuh delapan sembilan",
                    "satu dua tiga empat lima enam tujuh delapan sembilan",
                ),
            ],
        };
        // Pooled: 1 error / 10 reference words.
        assert!((score.word_error_rate() - 0.1).abs() < 1e-9);
        // The mean of the two rates would have been 50%.
        assert_eq!(score.mean_rtf(), 2.0);
    }

    #[test]
    fn the_table_puts_the_best_model_first() {
        let make = |model: &str, reference: &str, hypothesis: &str| ModelScore {
            model: model.to_string(),
            clips: vec![ClipScore {
                clip: "c".into(),
                words: word_errors(reference, hypothesis),
                chars: char_errors(reference, hypothesis),
                audio_secs: 10.0,
                elapsed_secs: 10.0,
                hypothesis: hypothesis.to_string(),
            }],
        };
        let table = render_table(&[
            make("buruk", "satu dua tiga", "empat lima enam"),
            make("bagus", "satu dua tiga", "satu dua tiga"),
        ]);
        let lines: Vec<&str> = table.lines().collect();
        assert!(lines[2].contains("bagus"), "got:\n{table}");
        assert!(lines[3].contains("buruk"), "got:\n{table}");
        assert!(table.contains("0.0%"));
    }

    #[test]
    fn manifest_parsing_skips_comments_and_blanks() {
        let entries = parse_manifest(
            "# FLEURS id_id, 3 klip\n\nklip1.wav\tSelamat pagi semua\nklip2.wav\tRapat dimulai\n",
        )
        .unwrap();
        assert_eq!(
            entries,
            vec![
                ManifestEntry {
                    audio: "klip1.wav".into(),
                    reference: "Selamat pagi semua".into()
                },
                ManifestEntry {
                    audio: "klip2.wav".into(),
                    reference: "Rapat dimulai".into()
                },
            ]
        );
    }

    #[test]
    fn an_empty_reference_is_a_silence_clip_not_a_malformed_line() {
        // How a hallucination test set is written: the audio is silence,
        // so the reference is deliberately empty and any word the model
        // emits is an insertion.
        let entries = parse_manifest(
            "# set hening\n# allow-empty-reference\naudio/0000.wav\t\naudio/0001.wav\t\n",
        )
        .unwrap();
        assert_eq!(entries.len(), 2);
        assert_eq!(entries[0].audio, "audio/0000.wav");
        assert!(entries[0].reference.is_empty());
    }

    #[test]
    fn a_silence_clip_transcribed_as_silence_scores_zero() {
        let counts = word_errors("", "");
        assert_eq!(counts.rate(), 0.0);
        assert_eq!(counts.errors(), 0);
    }

    #[test]
    fn a_hallucination_on_a_silence_clip_is_counted() {
        let counts = word_errors("", "terima kasih telah menonton");
        assert_eq!(counts.insertions, 4);
        assert_eq!(counts.rate(), 1.0);
    }

    #[test]
    fn an_empty_reference_without_the_directive_is_still_an_error() {
        // A reference someone forgot to fill in stays a mistake.
        let error = parse_manifest("audio/0000.wav\t\n").unwrap_err();
        assert!(error.contains("teks acuan"), "got: {error}");
        assert!(error.contains(ALLOW_EMPTY_REFERENCE), "got: {error}");
    }

    #[test]
    fn the_directive_only_counts_in_the_header() {
        // Otherwise a stray mention in a reference would silently relax
        // the whole manifest.
        let error = parse_manifest(
            "audio/0.wav\tteks biasa\n# allow-empty-reference\naudio/1.wav\t\n",
        )
        .unwrap_err();
        assert!(error.contains("teks acuan"), "got: {error}");
    }

    #[test]
    fn a_line_with_no_name_before_the_tab_is_still_an_error() {
        let error = parse_manifest("\tSelamat pagi\n").unwrap_err();
        assert!(error.contains("nama berkas"), "got: {error}");
    }

    #[test]
    fn a_malformed_manifest_line_is_an_error_not_a_skipped_clip() {
        let error = parse_manifest("klip1.wav Selamat pagi\n").unwrap_err();
        assert!(error.contains("TAB"), "got: {error}");
        assert!(parse_manifest("klip.wav\t   \n").is_err());
        assert!(parse_manifest("# only a comment\n").is_err());
    }

    #[test]
    fn rtf_of_an_unmeasured_clip_is_zero_not_a_division_by_zero() {
        let score = ClipScore {
            clip: "c".into(),
            words: EditCounts::default(),
            chars: EditCounts::default(),
            audio_secs: 10.0,
            elapsed_secs: 0.0,
            hypothesis: String::new(),
        };
        assert_eq!(score.rtf(), 0.0);
    }
}
