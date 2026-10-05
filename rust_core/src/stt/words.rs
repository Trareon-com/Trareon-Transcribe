//! Token → word aggregation for whisper.cpp token timestamps.
//!
//! whisper.cpp hands back *tokens*, not words: BPE pieces whose boundaries
//! have nothing to do with where a word starts. `" angga"`, `"ran"`, `"nya"`
//! are three tokens of one Indonesian word. Each carries its own `t0`/`t1`
//! (in centiseconds) and a probability, so the per-word span is the union of
//! its tokens' spans and the per-word confidence is their mean.
//!
//! The rule for *where a word starts* is the one Whisper's own tokenizer
//! implies: a token that begins with a space opens a new word, every other
//! token continues the current one. That is why `aggregate_words` never
//! needs a dictionary — it is reading back the segmentation the tokenizer
//! already encoded.
//!
//! Special tokens (`<|0.00|>`, `<|transcribe|>`, `[_BEG_]`) are not speech
//! and are dropped before any of this.

use crate::export::WordTimestamp;

/// One whisper token as the engine reported it.
///
/// Times are in **seconds**, already offset by the chunk start — callers
/// convert from whisper's centiseconds so this module never has to know
/// about the unit.
#[derive(Debug, Clone, PartialEq)]
pub struct TokenSpan {
    pub text: String,
    pub start: f64,
    pub end: f64,
    /// Token probability in `0.0..=1.0` as whisper reports it.
    pub prob: f32,
}

/// Whether `text` is one of whisper's control tokens rather than speech.
///
/// Two families: the `<|...|>` markers (timestamps, language, task) and the
/// `[_...]` internals (`[_BEG_]`, `[_TT_n]`, `[_SOT_]`).
pub fn is_special_token(text: &str) -> bool {
    let t = text.trim();
    (t.starts_with("<|") && t.ends_with("|>")) || (t.starts_with("[_") && t.ends_with(']'))
}

/// Groups `tokens` into words.
///
/// A token opens a new word when its raw text starts with whitespace, and
/// the first non-special token always opens one. Tokens that are pure
/// punctuation attach to the word before them — `"Baik"` + `","` is one
/// word `"Baik,"`, not a word and a stray comma the player would try to
/// highlight on its own.
///
/// Timestamps are clamped to be monotonic and non-negative: whisper's token
/// times can go backwards by a few centiseconds around a segment boundary,
/// and a word whose `end` precedes its `start` makes the karaoke highlight
/// flicker.
pub fn aggregate_words(tokens: &[TokenSpan]) -> Vec<WordTimestamp> {
    let mut words: Vec<WordBuilder> = Vec::new();
    for token in tokens {
        if is_special_token(&token.text) {
            continue;
        }
        let trimmed = token.text.trim();
        if trimmed.is_empty() {
            continue;
        }
        let starts_word = token.text.starts_with(char::is_whitespace);
        let punctuation_only = trimmed.chars().all(|c| !c.is_alphanumeric());
        match words.last_mut() {
            // Punctuation never opens a word, even with a leading space:
            // `" —"` belongs to the sentence it closes.
            Some(last) if !starts_word || punctuation_only => last.push(trimmed, token),
            _ => words.push(WordBuilder::new(trimmed, token)),
        }
    }

    let mut out: Vec<WordTimestamp> = Vec::with_capacity(words.len());
    let mut previous_end = 0.0f64;
    for builder in words {
        let start = builder.start.max(previous_end).max(0.0);
        let end = builder.end.max(start);
        previous_end = end;
        let prob = builder.mean_prob();
        out.push(WordTimestamp {
            word: builder.text,
            start,
            end,
            prob,
        });
    }
    out
}

struct WordBuilder {
    text: String,
    start: f64,
    end: f64,
    prob_sum: f32,
    token_count: u32,
}

impl WordBuilder {
    fn new(trimmed: &str, token: &TokenSpan) -> Self {
        Self {
            text: trimmed.to_string(),
            start: token.start,
            end: token.end,
            prob_sum: token.prob,
            token_count: 1,
        }
    }

    fn push(&mut self, trimmed: &str, token: &TokenSpan) {
        self.text.push_str(trimmed);
        self.end = self.end.max(token.end);
        self.prob_sum += token.prob;
        self.token_count += 1;
    }

    fn mean_prob(&self) -> f32 {
        if self.token_count == 0 {
            return 0.0;
        }
        (self.prob_sum / self.token_count as f32).clamp(0.0, 1.0)
    }
}

/// Spreads `words` evenly across `start..start + duration`.
///
/// The fallback for a model or build that reports no usable token times at
/// all: without it, "click a word to seek" would land every word of a
/// segment on the segment's own start, which is worse than an approximation
/// the user can see is approximate. `prob` is left at 0 so
/// [`crate::confidence`] does not mistake interpolation for a measurement.
pub fn interpolate_words(text: &str, start: f64, duration: f64) -> Vec<WordTimestamp> {
    let tokens: Vec<&str> = text.split_whitespace().collect();
    if tokens.is_empty() {
        return Vec::new();
    }
    let span = duration.max(0.0) / tokens.len() as f64;
    tokens
        .iter()
        .enumerate()
        .map(|(index, word)| {
            let word_start = start + span * index as f64;
            WordTimestamp {
                word: (*word).to_string(),
                start: word_start,
                end: word_start + span,
                prob: 0.0,
            }
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn token(text: &str, start: f64, end: f64, prob: f32) -> TokenSpan {
        TokenSpan {
            text: text.to_string(),
            start,
            end,
            prob,
        }
    }

    #[test]
    fn special_tokens_are_recognised() {
        assert!(is_special_token("<|0.00|>"));
        assert!(is_special_token("<|transcribe|>"));
        assert!(is_special_token("<|id|>"));
        assert!(is_special_token("[_BEG_]"));
        assert!(is_special_token("[_TT_12]"));
        assert!(!is_special_token(" anggaran"));
        assert!(!is_special_token("[Musik]"));
    }

    #[test]
    fn bpe_pieces_of_one_word_become_one_word() {
        // " angga" + "ran" + "nya" is one Indonesian word in three tokens.
        let words = aggregate_words(&[
            token(" angga", 1.0, 1.2, 0.9),
            token("ran", 1.2, 1.4, 0.8),
            token("nya", 1.4, 1.6, 0.7),
        ]);
        assert_eq!(words.len(), 1);
        assert_eq!(words[0].word, "anggarannya");
        assert_eq!(words[0].start, 1.0);
        assert_eq!(words[0].end, 1.6);
        // Mean of the three token probabilities.
        assert!((words[0].prob - 0.8).abs() < 1e-5, "{}", words[0].prob);
    }

    #[test]
    fn a_leading_space_opens_a_new_word() {
        let words = aggregate_words(&[
            token(" Selamat", 0.0, 0.5, 0.95),
            token(" pagi", 0.5, 0.9, 0.9),
        ]);
        assert_eq!(
            words.iter().map(|w| w.word.as_str()).collect::<Vec<_>>(),
            ["Selamat", "pagi"]
        );
    }

    #[test]
    fn the_first_token_opens_a_word_even_without_a_space() {
        let words = aggregate_words(&[token("Baik", 0.0, 0.4, 0.9)]);
        assert_eq!(words.len(), 1);
        assert_eq!(words[0].word, "Baik");
    }

    #[test]
    fn punctuation_attaches_to_the_word_before_it() {
        // A standalone "," would be a word the karaoke highlight stops on.
        let words = aggregate_words(&[
            token(" Baik", 0.0, 0.4, 0.9),
            token(",", 0.4, 0.42, 0.99),
            token(" lanjut", 0.5, 0.9, 0.9),
            token(" .", 0.9, 0.92, 0.99),
        ]);
        assert_eq!(
            words.iter().map(|w| w.word.as_str()).collect::<Vec<_>>(),
            ["Baik,", "lanjut."]
        );
    }

    #[test]
    fn special_tokens_are_dropped_not_rendered() {
        let words = aggregate_words(&[
            token("<|0.00|>", 0.0, 0.0, 1.0),
            token(" halo", 0.0, 0.3, 0.9),
            token("<|0.30|>", 0.3, 0.3, 1.0),
        ]);
        assert_eq!(words.len(), 1);
        assert_eq!(words[0].word, "halo");
    }

    #[test]
    fn timestamps_are_forced_monotonic() {
        // whisper's token times go backwards around chunk boundaries.
        let words = aggregate_words(&[token(" satu", 2.0, 2.5, 0.9), token(" dua", 1.8, 2.1, 0.9)]);
        assert_eq!(words[0].end, 2.5);
        assert_eq!(
            words[1].start, 2.5,
            "a word may not start before the last ended"
        );
        assert!(words[1].end >= words[1].start);
    }

    #[test]
    fn negative_token_times_are_clamped_to_zero() {
        let words = aggregate_words(&[token(" satu", -0.5, 0.2, 0.9)]);
        assert_eq!(words[0].start, 0.0);
        assert_eq!(words[0].end, 0.2);
    }

    #[test]
    fn no_tokens_means_no_words() {
        assert!(aggregate_words(&[]).is_empty());
        assert!(aggregate_words(&[token("   ", 0.0, 1.0, 1.0)]).is_empty());
    }

    #[test]
    fn interpolation_spreads_words_across_the_segment() {
        let words = interpolate_words("satu dua tiga empat", 10.0, 4.0);
        assert_eq!(words.len(), 4);
        assert_eq!(words[0].start, 10.0);
        assert_eq!(words[0].end, 11.0);
        assert_eq!(words[3].start, 13.0);
        assert_eq!(words[3].end, 14.0);
        // Interpolated words carry no confidence claim.
        assert!(words.iter().all(|w| w.prob == 0.0));
    }

    #[test]
    fn interpolation_of_empty_text_yields_nothing() {
        assert!(interpolate_words("", 0.0, 5.0).is_empty());
        assert!(interpolate_words("   ", 0.0, 5.0).is_empty());
    }

    #[test]
    fn interpolation_survives_a_zero_length_segment() {
        let words = interpolate_words("satu dua", 3.0, 0.0);
        assert_eq!(words.len(), 2);
        assert!(words.iter().all(|w| w.start == 3.0 && w.end == 3.0));
    }
}
