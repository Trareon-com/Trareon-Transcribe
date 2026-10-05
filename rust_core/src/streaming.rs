//! LocalAgreement-2: deciding which words of a live hypothesis are safe to
//! show as final.
//!
//! # The problem
//!
//! Whisper is not a streaming model. To transcribe speech that is still
//! arriving you must hand it a window of audio that ends mid-sentence, and
//! the last few words of that window are the ones it gets wrong — it has no
//! right context for them. Re-run the same window a second later, with two
//! more words of audio on the end, and those words change.
//!
//! Before this module the live path cut the audio into fixed 5-second
//! chunks and treated every word of every chunk as final. That is why the
//! live transcript used to disagree with the post-meeting one in the middle
//! of sentences, and why words at chunk boundaries were sometimes lost
//! outright: a word split across two chunks is heard by neither.
//!
//! # The policy
//!
//! LocalAgreement-*n* (Macháček et al. 2023, <https://arxiv.org/pdf/2307.14743>,
//! as implemented in `ufal/whisper_streaming`): run inference on an
//! *overlapping, growing* window and commit only the prefix that two
//! consecutive hypotheses agree on. A word survives two independent
//! decodes with different amounts of right context before the user is told
//! it is final. Everything after the agreed prefix is shown as
//! uncommitted — the greyed "sementara" tail — and is free to change.
//!
//! `n = 2` is the whole policy; there is no threshold to tune. Higher `n`
//! buys accuracy for latency, and the paper measures 2 as the knee.
//!
//! # What this module is and is not
//!
//! [`HypothesisBuffer`] is pure: hypotheses in, commits out, no audio and
//! no engine. [`StreamingBuffer`] owns the growing audio window and knows
//! how to trim it at a committed sentence boundary. Both are heavily unit
//! tested, because every interesting bug in a streaming ASR integration is
//! an off-by-one in exactly this arithmetic. The part that runs Whisper
//! lives in [`crate::pipeline`].

use crate::export::WordTimestamp;

/// Agreement depth. Two consecutive hypotheses must contain a word before
/// it is committed.
pub const AGREEMENT: usize = 2;

/// How much new audio must arrive before the window is decoded again.
///
/// The paper uses 1.0 s on a GPU. On a CPU that runs `tiny` at roughly 3×
/// realtime over a 10-second window, decoding every second means the
/// decoder is busy ~3× more often than it needs to be and the backlog
/// never drains. 2 s halves the inference rate and costs at most 1 s of
/// extra commit latency, which is the right trade on the hardware this
/// app targets. Measured both ways in `docs/SPRINT-REPORTS.md`.
pub const MIN_CHUNK_SECS: f64 = 2.0;

/// Longest audio window handed to one decode.
///
/// Whisper's encoder is defined on 30 s, and inference cost grows with the
/// window, so the window must be trimmed. 18 s leaves room for a long
/// Indonesian sentence to be re-decoded whole — trimming mid-sentence
/// costs the right context that makes the policy work in the first place.
pub const MAX_WINDOW_SECS: f64 = 18.0;

/// Silence after which the uncommitted tail is committed regardless of
/// agreement.
///
/// Without this the last words of every utterance would sit in the
/// "sementara" tail until the speaker said something else — so a meeting
/// where someone makes a point and stops would show its final clause as
/// provisional for minutes. The speaker has stopped talking; there is no
/// more right context coming, and a second decode of the same audio would
/// return the same words. This is `ufal/whisper_streaming`'s `finish()`,
/// applied at every utterance end rather than only at end of stream.
pub const UTTERANCE_END_SECS: f64 = 0.8;

/// Audio kept in the window while the room is silent.
///
/// The window cannot simply be emptied at an utterance end: the first
/// syllable of the next sentence arrives in the same 100 ms buffer the
/// silence did, and a decode that starts exactly on a word onset clips it.
/// Half a second of pre-roll is enough for Whisper to hear the attack.
pub const PRE_ROLL_SECS: f64 = 0.5;

/// One word of a hypothesis, at absolute recording time.
#[derive(Debug, Clone, PartialEq)]
pub struct HypoWord {
    pub text: String,
    pub start: f64,
    pub end: f64,
    pub prob: f32,
}

impl From<WordTimestamp> for HypoWord {
    fn from(word: WordTimestamp) -> Self {
        Self {
            text: word.word,
            start: word.start,
            end: word.end,
            prob: word.prob,
        }
    }
}

impl From<HypoWord> for WordTimestamp {
    fn from(word: HypoWord) -> Self {
        Self {
            word: word.text,
            start: word.start,
            end: word.end,
            prob: word.prob,
        }
    }
}

/// The comparison key for "is this the same word".
///
/// Lowercased, with leading/trailing punctuation removed. Whisper changes
/// a word's capitalisation and its trailing comma freely between decodes
/// of overlapping windows — `"Baik,"` in one hypothesis and `"baik"` in
/// the next are the same word heard twice, and comparing them literally
/// (as the reference implementation does) stalls the commit until the
/// *next* word agrees. The committed text keeps the newer spelling, which
/// is the one decoded with more context.
fn word_key(text: &str) -> String {
    text.trim_matches(|c: char| !c.is_alphanumeric())
        .to_lowercase()
}

/// The LocalAgreement-2 state machine.
///
/// Holds the previous hypothesis' uncommitted tail and the time of the
/// last committed word. Feed it one hypothesis per decode.
#[derive(Debug, Default)]
pub struct HypothesisBuffer {
    /// Uncommitted tail of the previous hypothesis — the sequence the next
    /// one is compared against.
    previous: Vec<HypoWord>,
    /// End time of the last word committed, so a re-decode of already
    /// committed audio cannot commit it twice.
    committed_through: f64,
    /// How many words have been committed in total. The pipeline drains
    /// the per-call commits as they come, so this is the only running
    /// total — it is what the live-coverage figure in the sprint report is
    /// computed from.
    committed_count: usize,
}

/// What one hypothesis produced.
#[derive(Debug, Clone, PartialEq, Default)]
pub struct Commit {
    /// Words now final. In order, never re-emitted.
    pub committed: Vec<HypoWord>,
    /// The rest of the latest hypothesis — shown greyed as "sementara".
    pub tentative: Vec<HypoWord>,
}

impl HypothesisBuffer {
    pub fn new() -> Self {
        Self::default()
    }

    /// Feeds one hypothesis over the current window and returns the words
    /// it agrees with the previous one about.
    ///
    /// `hypothesis` must be in time order with absolute timestamps.
    pub fn insert(&mut self, hypothesis: Vec<HypoWord>) -> Commit {
        // Drop anything the window re-decoded that is already committed.
        // The 0.1 s slack is the reference implementation's: a re-decode
        // moves a word's boundary by a few tens of milliseconds, and
        // comparing exactly would let a committed word back in.
        let fresh: Vec<HypoWord> = hypothesis
            .into_iter()
            .filter(|word| word.start > self.committed_through - 0.1)
            .collect();

        let mut committed = Vec::new();
        let mut index = 0;
        while index < fresh.len() && index < self.previous.len() {
            if word_key(&fresh[index].text) != word_key(&self.previous[index].text) {
                break;
            }
            self.committed_through = fresh[index].end;
            committed.push(fresh[index].clone());
            index += 1;
        }
        self.committed_count += committed.len();
        let tentative = fresh[index..].to_vec();
        self.previous = tentative.clone();
        Commit {
            committed,
            tentative,
        }
    }

    /// Commits the whole uncommitted tail, with no second opinion.
    ///
    /// For an utterance end (the speaker stopped) and for end of stream
    /// (Stop was pressed). Both are cases where no further right context
    /// is coming, so waiting for agreement would wait forever.
    pub fn flush(&mut self) -> Vec<HypoWord> {
        let tail = std::mem::take(&mut self.previous);
        if let Some(last) = tail.last() {
            self.committed_through = last.end;
        }
        self.committed_count += tail.len();
        tail
    }

    /// End time of the last committed word. The point the audio window can
    /// safely be trimmed back to.
    pub fn committed_through(&self) -> f64 {
        self.committed_through
    }

    /// How many words have been committed in total.
    pub fn committed_count(&self) -> usize {
        self.committed_count
    }

    /// Whether anything is waiting on a second opinion.
    pub fn has_tentative(&self) -> bool {
        !self.previous.is_empty()
    }
}

/// The growing audio window a streaming decode runs over.
///
/// Holds raw 16 kHz mono f32 together with the absolute recording time of
/// its first sample, so a hypothesis' timestamps can be made absolute
/// without the caller tracking the offset itself — which is where the
/// previous chunked implementation's timestamp drift came from.
#[derive(Debug)]
pub struct StreamingBuffer {
    samples: Vec<f32>,
    /// Absolute recording time of `samples[0]`.
    start_secs: f64,
    sample_rate: f64,
}

impl StreamingBuffer {
    pub fn new(sample_rate: u32) -> Self {
        Self {
            samples: Vec::new(),
            start_secs: 0.0,
            sample_rate: sample_rate as f64,
        }
    }

    pub fn push(&mut self, incoming: &[f32]) {
        self.samples.extend_from_slice(incoming);
    }

    pub fn samples(&self) -> &[f32] {
        &self.samples
    }

    pub fn start_secs(&self) -> f64 {
        self.start_secs
    }

    pub fn duration_secs(&self) -> f64 {
        self.samples.len() as f64 / self.sample_rate
    }

    pub fn end_secs(&self) -> f64 {
        self.start_secs + self.duration_secs()
    }

    pub fn is_empty(&self) -> bool {
        self.samples.is_empty()
    }

    /// Drops everything before absolute time `secs`.
    ///
    /// Clamped to the window: trimming past the end would leave the buffer
    /// claiming to start in the future, and every subsequent hypothesis
    /// would be stamped accordingly.
    pub fn trim_to(&mut self, secs: f64) {
        let target = secs.clamp(self.start_secs, self.end_secs());
        let drop_samples = ((target - self.start_secs) * self.sample_rate).round() as usize;
        let drop_samples = drop_samples.min(self.samples.len());
        if drop_samples == 0 {
            return;
        }
        self.samples.drain(..drop_samples);
        self.start_secs += drop_samples as f64 / self.sample_rate;
    }

    /// Trims the window back to the last committed word when it has grown
    /// past `max_secs`.
    ///
    /// Returns whether anything was dropped. `committed_through` of 0 (or
    /// anything before the window) means nothing has been committed inside
    /// this window yet: trimming then would throw away audio that has
    /// never been transcribed, which is the one thing this whole subsystem
    /// exists to prevent. In that case the window is trimmed to
    /// `max_secs` worth of its own tail and the dropped span is reported
    /// so the caller can account for it — the post-stop completion pass
    /// transcribes it from the WAV.
    pub fn trim_window(&mut self, committed_through: f64, max_secs: f64) -> Option<(f64, f64)> {
        if self.duration_secs() <= max_secs {
            return None;
        }
        let safe = committed_through.max(self.start_secs);
        if safe > self.start_secs {
            self.trim_to(safe);
            return None;
        }
        // Nothing committed in a full window: the decoder cannot keep up.
        // Keep the newest `max_secs` and tell the caller what was dropped.
        let drop_until = self.end_secs() - max_secs;
        let dropped = (self.start_secs, drop_until);
        self.trim_to(drop_until);
        Some(dropped)
    }
}

/// Groups committed words into transcript lines.
///
/// A line ends at sentence punctuation, or after [`Self::max_words`] words
/// when the speaker has not produced any — Indonesian meeting speech often
/// runs for a minute without a full stop, and a single 400-word segment is
/// not something a player can highlight or a reader can scan.
#[derive(Debug)]
pub struct LineBuilder {
    words: Vec<HypoWord>,
    max_words: usize,
}

impl Default for LineBuilder {
    fn default() -> Self {
        Self {
            words: Vec::new(),
            // ~20 words is one or two spoken clauses: short enough to
            // appear promptly, long enough not to shred a sentence.
            max_words: 20,
        }
    }
}

impl LineBuilder {
    pub fn new(max_words: usize) -> Self {
        Self {
            words: Vec::new(),
            max_words: max_words.max(1),
        }
    }

    /// Adds committed words, returning every complete line they finish.
    pub fn push(&mut self, words: impl IntoIterator<Item = HypoWord>) -> Vec<Vec<HypoWord>> {
        let mut lines = Vec::new();
        for word in words {
            let ends_sentence = ends_sentence(&word.text);
            self.words.push(word);
            if ends_sentence || self.words.len() >= self.max_words {
                lines.push(std::mem::take(&mut self.words));
            }
        }
        lines
    }

    /// Takes whatever is in progress, finished or not. For an utterance end
    /// and for Stop.
    pub fn take(&mut self) -> Option<Vec<HypoWord>> {
        if self.words.is_empty() {
            return None;
        }
        Some(std::mem::take(&mut self.words))
    }

    pub fn is_empty(&self) -> bool {
        self.words.is_empty()
    }
}

/// Whether `word` ends a sentence. `?` and `!` as well as `.`; a trailing
/// `…` counts too. An abbreviation's full stop ("dsb.", "Rp.") is a false
/// positive that costs a line break, not a lost word.
fn ends_sentence(word: &str) -> bool {
    word.trim_end()
        .chars()
        .next_back()
        .is_some_and(|c| matches!(c, '.' | '?' | '!' | '…'))
}

/// Joins words into the text of a transcript line.
pub fn join_words(words: &[HypoWord]) -> String {
    words
        .iter()
        .map(|word| word.text.as_str())
        .collect::<Vec<_>>()
        .join(" ")
}

#[cfg(test)]
mod tests {
    use super::*;

    fn w(text: &str, start: f64, end: f64) -> HypoWord {
        HypoWord {
            text: text.to_string(),
            start,
            end,
            prob: 0.9,
        }
    }

    fn texts(words: &[HypoWord]) -> Vec<&str> {
        words.iter().map(|word| word.text.as_str()).collect()
    }

    // --- HypothesisBuffer ----------------------------------------------

    #[test]
    fn the_first_hypothesis_commits_nothing() {
        // Nothing has agreed with anything yet. Committing here is exactly
        // the bug LocalAgreement exists to fix.
        let mut buffer = HypothesisBuffer::new();
        let commit = buffer.insert(vec![w("Selamat", 0.0, 0.5), w("pagi", 0.5, 1.0)]);
        assert!(commit.committed.is_empty());
        assert_eq!(texts(&commit.tentative), ["Selamat", "pagi"]);
    }

    #[test]
    fn a_prefix_two_hypotheses_agree_on_is_committed() {
        let mut buffer = HypothesisBuffer::new();
        buffer.insert(vec![w("Selamat", 0.0, 0.5), w("pagi", 0.5, 1.0)]);
        // Second decode, one more word of audio. The first two words
        // survived, so they are final; "semuanya" has not been seen twice.
        let commit = buffer.insert(vec![
            w("Selamat", 0.0, 0.5),
            w("pagi", 0.5, 1.0),
            w("semuanya", 1.0, 1.6),
        ]);
        assert_eq!(texts(&commit.committed), ["Selamat", "pagi"]);
        assert_eq!(texts(&commit.tentative), ["semuanya"]);
        assert_eq!(buffer.committed_through(), 1.0);
    }

    #[test]
    fn disagreement_stops_the_commit_at_that_word() {
        let mut buffer = HypothesisBuffer::new();
        buffer.insert(vec![
            w("Anggaran", 0.0, 0.6),
            w("naik", 0.6, 1.0),
            w("sepuluh", 1.0, 1.5),
        ]);
        // The decoder changed its mind about the third word, which is
        // exactly the case the policy is for.
        let commit = buffer.insert(vec![
            w("Anggaran", 0.0, 0.6),
            w("naik", 0.6, 1.0),
            w("sembilan", 1.0, 1.5),
            w("persen", 1.5, 2.0),
        ]);
        assert_eq!(texts(&commit.committed), ["Anggaran", "naik"]);
        assert_eq!(texts(&commit.tentative), ["sembilan", "persen"]);
    }

    #[test]
    fn a_word_is_never_committed_twice() {
        let mut buffer = HypothesisBuffer::new();
        buffer.insert(vec![w("satu", 0.0, 0.5), w("dua", 0.5, 1.0)]);
        buffer.insert(vec![
            w("satu", 0.0, 0.5),
            w("dua", 0.5, 1.0),
            w("tiga", 1.0, 1.5),
        ]);
        // A third decode of the same window re-reports the committed words.
        let commit = buffer.insert(vec![
            w("satu", 0.0, 0.5),
            w("dua", 0.5, 1.0),
            w("tiga", 1.0, 1.5),
            w("empat", 1.5, 2.0),
        ]);
        assert_eq!(
            texts(&commit.committed),
            ["tiga"],
            "satu/dua are already final and must not be emitted again"
        );
    }

    #[test]
    fn capitalisation_and_punctuation_do_not_block_agreement() {
        // Whisper flips these freely between decodes of overlapping
        // windows. Comparing literally stalls the commit by a word every
        // time it happens.
        let mut buffer = HypothesisBuffer::new();
        buffer.insert(vec![w("Baik", 0.0, 0.4), w("lanjut", 0.4, 0.9)]);
        let commit = buffer.insert(vec![
            w("baik,", 0.0, 0.4),
            w("lanjut", 0.4, 0.9),
            w("ke", 0.9, 1.1),
        ]);
        assert_eq!(
            texts(&commit.committed),
            ["baik,", "lanjut"],
            "the newer spelling is the one decoded with more context"
        );
    }

    #[test]
    fn a_shorter_second_hypothesis_commits_only_what_it_contains() {
        let mut buffer = HypothesisBuffer::new();
        buffer.insert(vec![
            w("satu", 0.0, 0.5),
            w("dua", 0.5, 1.0),
            w("tiga", 1.0, 1.5),
        ]);
        let commit = buffer.insert(vec![w("satu", 0.0, 0.5)]);
        assert_eq!(texts(&commit.committed), ["satu"]);
        assert!(commit.tentative.is_empty());
    }

    #[test]
    fn flush_commits_the_tail_without_a_second_opinion() {
        let mut buffer = HypothesisBuffer::new();
        buffer.insert(vec![w("terima", 0.0, 0.4), w("kasih.", 0.4, 0.9)]);
        assert!(buffer.has_tentative());
        let tail = buffer.flush();
        assert_eq!(texts(&tail), ["terima", "kasih."]);
        assert!(!buffer.has_tentative());
        assert_eq!(buffer.committed_through(), 0.9);
        // And flushing again yields nothing rather than the same words.
        assert!(buffer.flush().is_empty());
    }

    #[test]
    fn flushing_an_empty_buffer_is_not_an_error() {
        let mut buffer = HypothesisBuffer::new();
        assert!(buffer.flush().is_empty());
        assert_eq!(buffer.committed_through(), 0.0);
    }

    #[test]
    fn audio_before_the_commit_point_is_ignored() {
        // The window still contains committed audio after a trim, so the
        // decoder re-reports it. Without the filter those words would be
        // compared against the *tentative* tail and corrupt the alignment.
        let mut buffer = HypothesisBuffer::new();
        buffer.insert(vec![w("satu", 10.0, 10.5), w("dua", 10.5, 11.0)]);
        buffer.insert(vec![w("satu", 10.0, 10.5), w("dua", 10.5, 11.0)]);
        assert_eq!(buffer.committed_through(), 11.0);
        let commit = buffer.insert(vec![
            w("satu", 10.0, 10.5),
            w("dua", 10.5, 11.0),
            w("tiga", 11.0, 11.5),
        ]);
        assert!(commit.committed.is_empty(), "nothing new has agreed twice");
        assert_eq!(texts(&commit.tentative), ["tiga"]);
    }

    #[test]
    fn committed_count_counts_flushes_too() {
        let mut buffer = HypothesisBuffer::new();
        buffer.insert(vec![w("a", 0.0, 0.1), w("b", 0.1, 0.2)]);
        buffer.insert(vec![w("a", 0.0, 0.1), w("b", 0.1, 0.2), w("c", 0.2, 0.3)]);
        assert_eq!(buffer.committed_count(), 2);
        buffer.flush();
        assert_eq!(buffer.committed_count(), 3);
    }

    // --- StreamingBuffer -----------------------------------------------

    #[test]
    fn a_fresh_buffer_starts_at_zero() {
        let buffer = StreamingBuffer::new(16_000);
        assert!(buffer.is_empty());
        assert_eq!(buffer.start_secs(), 0.0);
        assert_eq!(buffer.duration_secs(), 0.0);
    }

    #[test]
    fn pushing_extends_the_window_forward() {
        let mut buffer = StreamingBuffer::new(16_000);
        buffer.push(&vec![0.0; 16_000]);
        assert_eq!(buffer.duration_secs(), 1.0);
        assert_eq!(buffer.end_secs(), 1.0);
        buffer.push(&vec![0.0; 8_000]);
        assert_eq!(buffer.duration_secs(), 1.5);
    }

    #[test]
    fn trimming_moves_the_window_start_with_the_audio() {
        let mut buffer = StreamingBuffer::new(16_000);
        buffer.push(&vec![0.0; 16_000 * 10]);
        buffer.trim_to(4.0);
        assert_eq!(buffer.start_secs(), 4.0);
        assert_eq!(buffer.duration_secs(), 6.0);
        assert_eq!(
            buffer.end_secs(),
            10.0,
            "the end of the audio has not moved"
        );
    }

    #[test]
    fn trimming_is_clamped_to_the_window() {
        let mut buffer = StreamingBuffer::new(16_000);
        buffer.push(&vec![0.0; 16_000 * 5]);
        // Past the end: the buffer may not end up claiming to start in
        // the future.
        buffer.trim_to(99.0);
        assert_eq!(buffer.start_secs(), 5.0);
        assert_eq!(buffer.end_secs(), 5.0);
        assert!(buffer.is_empty());
        // Backwards: a no-op, not a panic.
        buffer.trim_to(0.0);
        assert_eq!(buffer.start_secs(), 5.0);
    }

    #[test]
    fn a_window_under_the_cap_is_not_trimmed() {
        let mut buffer = StreamingBuffer::new(16_000);
        buffer.push(&vec![0.0; 16_000 * 10]);
        assert_eq!(buffer.trim_window(5.0, MAX_WINDOW_SECS), None);
        assert_eq!(buffer.start_secs(), 0.0);
    }

    #[test]
    fn an_over_long_window_is_trimmed_to_the_commit_point() {
        let mut buffer = StreamingBuffer::new(16_000);
        buffer.push(&vec![0.0; 16_000 * 20]);
        assert_eq!(buffer.trim_window(12.0, MAX_WINDOW_SECS), None);
        assert_eq!(buffer.start_secs(), 12.0);
        assert_eq!(buffer.duration_secs(), 8.0);
    }

    #[test]
    fn a_full_window_with_nothing_committed_reports_what_it_drops() {
        // The decoder cannot keep up. Audio has to go, and the caller has
        // to know which seconds so the post-stop pass can recover them —
        // silently dropping them is the Sprint 4 regression this guards.
        let mut buffer = StreamingBuffer::new(16_000);
        buffer.push(&vec![0.0; 16_000 * 25]);
        let dropped = buffer.trim_window(0.0, MAX_WINDOW_SECS);
        assert_eq!(dropped, Some((0.0, 7.0)));
        assert_eq!(buffer.start_secs(), 7.0);
        assert_eq!(buffer.duration_secs(), MAX_WINDOW_SECS);
    }

    #[test]
    fn a_commit_point_behind_the_window_does_not_rewind_it() {
        let mut buffer = StreamingBuffer::new(16_000);
        buffer.push(&vec![0.0; 16_000 * 30]);
        buffer.trim_to(10.0);
        // `committed_through` from before the trim.
        let dropped = buffer.trim_window(5.0, MAX_WINDOW_SECS);
        assert_eq!(dropped, Some((10.0, 12.0)));
        assert_eq!(buffer.start_secs(), 12.0);
    }

    // --- LineBuilder ---------------------------------------------------

    #[test]
    fn a_line_ends_at_sentence_punctuation() {
        let mut builder = LineBuilder::default();
        let lines = builder.push(vec![
            w("Selamat", 0.0, 0.5),
            w("pagi.", 0.5, 1.0),
            w("Kita", 1.0, 1.3),
        ]);
        assert_eq!(lines.len(), 1);
        assert_eq!(join_words(&lines[0]), "Selamat pagi.");
        assert!(!builder.is_empty(), "'Kita' is still in progress");
    }

    #[test]
    fn question_and_exclamation_marks_end_lines_too() {
        let mut builder = LineBuilder::default();
        assert_eq!(builder.push(vec![w("Benar?", 0.0, 0.5)]).len(), 1);
        assert_eq!(builder.push(vec![w("Bagus!", 0.5, 1.0)]).len(), 1);
        assert_eq!(builder.push(vec![w("Lalu…", 1.0, 1.5)]).len(), 1);
    }

    #[test]
    fn a_sentence_that_never_ends_is_broken_at_the_word_cap() {
        // Indonesian meeting speech runs for a minute without a full stop.
        let mut builder = LineBuilder::new(3);
        let lines = builder.push((0..7).map(|i| w("dan", i as f64, i as f64 + 1.0)));
        assert_eq!(lines.len(), 2, "7 words at a cap of 3 completes two lines");
        assert_eq!(lines[0].len(), 3);
        assert_eq!(lines[1].len(), 3);
        assert_eq!(builder.take().unwrap().len(), 1);
    }

    #[test]
    fn take_yields_the_partial_line_once() {
        let mut builder = LineBuilder::default();
        builder.push(vec![w("Baik", 0.0, 0.4)]);
        assert_eq!(join_words(&builder.take().unwrap()), "Baik");
        assert!(builder.take().is_none());
    }

    #[test]
    fn a_zero_word_cap_still_produces_lines() {
        // `max_words` of 0 would otherwise mean every line is empty and
        // the loop emits forever.
        let mut builder = LineBuilder::new(0);
        let lines = builder.push(vec![w("satu", 0.0, 0.5)]);
        assert_eq!(lines.len(), 1);
        assert_eq!(lines[0].len(), 1);
    }

    #[test]
    fn joining_words_separates_them_with_single_spaces() {
        assert_eq!(
            join_words(&[w("Rapat", 0.0, 0.5), w("dimulai.", 0.5, 1.0)]),
            "Rapat dimulai."
        );
        assert_eq!(join_words(&[]), "");
    }

    #[test]
    fn word_timestamps_round_trip_through_hypo_words() {
        let original = WordTimestamp {
            word: "anggaran".into(),
            start: 1.25,
            end: 1.9,
            prob: 0.73,
        };
        let round_tripped: WordTimestamp = HypoWord::from(original.clone()).into();
        assert_eq!(round_tripped, original);
    }

    #[test]
    fn the_tuned_constants_are_what_the_report_quotes() {
        const { assert!(AGREEMENT == 2) };
        assert_eq!(MIN_CHUNK_SECS, 2.0);
        assert_eq!(MAX_WINDOW_SECS, 18.0);
        assert_eq!(UTTERANCE_END_SECS, 0.8);
        // The window must hold several decode steps or the policy never
        // gets a second opinion on anything.
        assert!(MAX_WINDOW_SECS > MIN_CHUNK_SECS * AGREEMENT as f64);
    }
}
