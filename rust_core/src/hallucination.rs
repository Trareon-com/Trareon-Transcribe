//! Non-speech / silence-hallucination filter.
//!
//! Whisper does not know how to say "nothing was said". Fed a stretch of
//! silence it emits its training data's most common captions instead: the
//! bracketed sound-effect tokens from subtitle corpora (`[Musik]`,
//! `[Applause]`, and — on Indonesian audio — `[MENGENI]`), and the
//! sign-offs YouTube subtitles end with ("Terima kasih telah menonton",
//! "Subtitle by ...").
//!
//! Measured on a real 6-minute session recorded by this app: of 15 lines
//! produced by re-transcribing `speaker.wav`, 12 were `[MENGENI]` over
//! stretches whose RMS was flat silence.
//!
//! The filter is deliberately conservative, because the failure mode on the
//! other side is deleting something the user actually said:
//!
//! * It only ever rejects a *whole* segment. A hallucinated token embedded
//!   in a real sentence is left alone — removing it would rewrite speech.
//! * Bracketed rejection requires the entire segment to be one bracketed
//!   group of at most [`MAX_BRACKET_WORDS`] words, so an aside a speaker
//!   genuinely dictated ("buka kurung ini penting tutup kurung") survives.
//! * The phrase list is matched on the full normalised text, not as a
//!   substring: "terima kasih telah menonton presentasi Pak Budi" is real
//!   speech and stays.

use crate::export::Segment;

/// Longest bracketed group still treated as a sound-effect caption.
/// `[Musik]`, `[MENGENI]`, `[suara tepuk tangan]` are 1-3 words; anything
/// longer is more likely to be dictated content.
const MAX_BRACKET_WORDS: usize = 3;

/// Exact (normalised) captions Whisper emits over silence.
///
/// Sources: the subtitle corpora in Whisper's training set. Indonesian
/// entries come from Indonesian YouTube sign-offs, which is what the model
/// falls back to when the language is pinned to `id`.
const SILENCE_CAPTIONS: &[&str] = &[
    // Indonesian YouTube sign-offs
    "terima kasih telah menonton",
    "terima kasih telah menonton video ini",
    "terima kasih sudah menonton",
    "terima kasih sudah menonton video ini",
    "terima kasih telah menyaksikan",
    "terima kasih",
    "sampai jumpa di video berikutnya",
    "sampai jumpa di video selanjutnya",
    "jangan lupa like dan subscribe",
    "jangan lupa subscribe",
    "jangan lupa like dan subscribe ya",
    "like dan subscribe",
    "subscribe",
    "sama sama",
    // Malay sign-offs — "kerana" (because) where Indonesian says
    // "telah"/"sudah". Measured on a macOS session: the mic buffer was
    // absolute digital silence (no permission granted) and Whisper still
    // produced "Terima kasih kerana menonton!".
    "terima kasih kerana menonton",
    "terima kasih kerana menonton video ini",
    "terima kasih kerana menyaksikan",
    // Subtitle credits
    "subtitle by",
    "subtitles by",
    "sub by",
    "diterjemahkan oleh",
    "terjemahan oleh",
    "amara org",
    "amara org community",
    "disubtitle oleh",
    // English sign-offs (Whisper reaches for these even on id audio)
    "thanks for watching",
    "thank you for watching",
    "thank you",
    "you",
    "bye",
    // Bare sound-effect words that survive bracket stripping
    "musik",
    "music",
    "applause",
    "tepuk tangan",
];

/// Prefixes that mark a credit line whose tail is a name — the name varies,
/// so the exact-match list above cannot catch them.
const CREDIT_PREFIXES: &[&str] = &[
    "subtitle by",
    "subtitles by",
    "sub by",
    "diterjemahkan oleh",
    "terjemahan oleh",
    "disubtitle oleh",
    "transcribed by",
    "ditranskripsi oleh",
];

/// Whether `text`, taken as an entire segment, is a non-speech artifact
/// rather than something a person said.
pub fn is_non_speech(text: &str) -> bool {
    let trimmed = text.trim();
    if trimmed.is_empty() {
        return true;
    }
    // Musical-note runs: "♪♪♪", "♪ ♪".
    if trimmed
        .chars()
        .all(|c| c == '♪' || c == '♫' || c.is_whitespace())
    {
        return true;
    }
    if let Some(inner) = strip_enclosing_brackets(trimmed) {
        if inner.split_whitespace().count() <= MAX_BRACKET_WORDS {
            return true;
        }
    }
    // A single "word" that is one short unit repeated — "MENENENENEN…",
    // "aaaaaaaaaa", "hahahahaha" — is the decoder stuck in a loop, not
    // speech. Observed in a live session: four seconds of room tone before
    // the meeting started came back as one 59-character segment, at
    // confidence 0.75, which is far too high for any threshold to reject.
    if is_degenerate_repeat(trimmed) || is_whole_word_loop(trimmed) {
        return true;
    }
    let normalised = normalise(trimmed);
    if normalised.is_empty() {
        return true;
    }
    if SILENCE_CAPTIONS.contains(&normalised.as_str()) {
        return true;
    }
    // A credit line is "<prefix> <name>" — the prefix alone is enough, and
    // the tail is short. `"diterjemahkan oleh tim humas kementerian"` is
    // eight words and stays; `"subtitle by rizky"` goes.
    CREDIT_PREFIXES.iter().any(|prefix| {
        normalised
            .strip_prefix(prefix)
            .is_some_and(|tail| !tail.is_empty() && tail.split_whitespace().count() <= 4)
    })
}

/// Shortest repeating unit a degenerate run is built from. `"NE"` in
/// `"MENENENE…"`, `"a"` in `"aaaa"`. Longer units than this start being
/// real words a person might stammer.
const MAX_REPEAT_UNIT: usize = 4;

/// How many characters a run must reach before it is unmistakably a loop.
///
/// Deliberately long. `"hahaha"` (6) is laughter somebody actually
/// produced; `"MENENENENENENENENENENENENENENENENENENENENENENENENENENENENEN"`
/// (59) is not language. 20 sits well clear of every Indonesian word and
/// of ordinary reduplication — `"berlari-lari"`, `"kupu-kupu"` — which
/// this must never touch.
const MIN_REPEAT_LEN: usize = 20;

/// Whether `text` is a single token made of one short unit repeated.
///
/// Only fires on a *whole segment that is one word*: a loop inside a
/// sentence is left alone, for the same reason a bracketed token inside a
/// sentence is — rewriting speech is worse than leaving an oddity in it.
fn is_degenerate_repeat(text: &str) -> bool {
    let token = text.trim();
    if token.split_whitespace().count() != 1 {
        return false;
    }
    let chars: Vec<char> = token
        .chars()
        .filter(|c| c.is_alphanumeric())
        .flat_map(|c| c.to_lowercase())
        .collect();
    if chars.len() < MIN_REPEAT_LEN {
        return false;
    }
    // The cycle need not start at the first character: the observed case
    // is `M` + `ENENEN…`, where the leading consonant is outside the loop.
    // So each unit length is tried at every offset inside one period.
    (1..=MAX_REPEAT_UNIT).any(|unit| {
        (0..unit).any(|offset| {
            let tail = &chars[offset.min(chars.len())..];
            // At least four whole repeats, and every one of them equal.
            tail.len() >= unit * 4 && tail.chunks(unit).all(|c| c == &tail[..c.len()])
        })
    })
}

/// Whether `text` is one whole word repeated three or more times, joined by
/// hyphens and/or spaces: `"Pertama-Pertama-Pertama-…"`, the exact decoder
/// loop a live macOS session produced. [`is_degenerate_repeat`] only looks
/// inside a *single token* at the character level (unit length up to
/// [`MAX_REPEAT_UNIT`]), so a loop built out of a whole 7-letter word never
/// matched it; this catches that case without touching
/// [`MAX_REPEAT_UNIT`], which would start swallowing short reduplicated
/// words it must never touch.
///
/// Requires *three* repeats, not two, so Indonesian reduplication
/// (`"kupu-kupu"`, `"masing-masing"`) — always exactly two — is untouched.
fn is_whole_word_loop(text: &str) -> bool {
    let tokens: Vec<String> = text
        .split(|c: char| c == '-' || c.is_whitespace())
        .filter(|s| !s.is_empty())
        .map(|s| s.to_lowercase())
        .collect();
    if tokens.len() < 3 {
        return false;
    }
    let first = &tokens[0];
    // Short units are already covered at the character level; leaving this
    // check out at that length keeps the two detectors from double-judging
    // the same short reduplicated word differently.
    if first.chars().count() <= MAX_REPEAT_UNIT {
        return false;
    }
    tokens.iter().all(|t| t == first)
}

/// Returns the inside of `text` when the whole string is one bracketed
/// group: `[Musik]`, `(Musik)`, `*Musik*`. `None` when it is not, including
/// `"[a] dan [b]"` — two groups, so the string is not itself a caption.
fn strip_enclosing_brackets(text: &str) -> Option<&str> {
    let (open, close) = match text.chars().next()? {
        '[' => ('[', ']'),
        '(' => ('(', ')'),
        '{' => ('{', '}'),
        '<' => ('<', '>'),
        '*' => ('*', '*'),
        _ => return None,
    };
    let rest = text.strip_prefix(open)?.strip_suffix(close)?;
    // Any further opening bracket means the string is not a single group.
    if rest.contains(open) || rest.contains(close) {
        return None;
    }
    Some(rest)
}

/// Lowercase, drop punctuation, collapse whitespace. Keeps letters, digits
/// and spaces so "Terima kasih, telah menonton!" matches the list entry.
fn normalise(text: &str) -> String {
    let mut out = String::with_capacity(text.len());
    let mut last_was_space = true;
    for c in text.chars() {
        if c.is_alphanumeric() {
            for lower in c.to_lowercase() {
                out.push(lower);
            }
            last_was_space = false;
        } else if !last_was_space {
            out.push(' ');
            last_was_space = true;
        }
    }
    out.trim_end().to_string()
}

/// Drops every segment [`is_non_speech`] rejects. Returns how many went.
pub fn filter_segments(segments: &mut Vec<Segment>) -> usize {
    let before = segments.len();
    segments.retain(|segment| !is_non_speech(&segment.text));
    before - segments.len()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn seg(text: &str) -> Segment {
        Segment {
            source: "file".into(),
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

    #[test]
    fn the_mengeni_hallucination_is_rejected() {
        // The exact token observed 12 times in one 6-minute session.
        assert!(is_non_speech("[MENGENI]"));
        assert!(is_non_speech(" [MENGENI] "));
        assert!(is_non_speech("[Mengeni]"));
    }

    #[test]
    fn bracketed_sound_effects_are_rejected() {
        for text in [
            "[Musik]",
            "(Musik)",
            "[MUSIC]",
            "[Applause]",
            "[Tepuk tangan]",
            "(suara tepuk tangan)",
            "*musik*",
            "<Musik>",
        ] {
            assert!(is_non_speech(text), "{text} must be rejected");
        }
    }

    #[test]
    fn musical_notes_are_rejected() {
        assert!(is_non_speech("♪"));
        assert!(is_non_speech("♪♪♪"));
        assert!(is_non_speech("♪ ♪ ♪"));
    }

    #[test]
    fn indonesian_signoffs_are_rejected() {
        for text in [
            "Terima kasih telah menonton.",
            "terima kasih sudah menonton",
            "Terima kasih telah menonton video ini!",
            "Jangan lupa like dan subscribe",
            "Subtitle by Rizky",
            "Diterjemahkan oleh Budi Santoso",
        ] {
            assert!(is_non_speech(text), "{text} must be rejected");
        }
    }

    #[test]
    fn malay_signoffs_are_rejected() {
        // Measured on a macOS session with no mic permission granted (the
        // buffer was absolute digital silence): Whisper still produced
        // this exact Malay-spelled sign-off.
        for text in [
            "Terima kasih kerana menonton!",
            "terima kasih kerana menonton video ini",
            "Sama-sama!",
        ] {
            assert!(is_non_speech(text), "{text} must be rejected");
        }
    }

    #[test]
    fn sampai_jumpa_selanjutnya_variant_is_rejected() {
        assert!(is_non_speech("Sampai jumpa di video selanjutnya."));
    }

    #[test]
    fn a_whole_word_decoder_loop_is_rejected() {
        // The exact segment a live macOS session produced: the same
        // 7-letter word repeated, hyphen-joined, with no silence to blame
        // (the character-level loop detector never sees a unit this long).
        assert!(is_non_speech(
            "Pertama-Pertama-Pertama-Pertama-Pertama-Pertama-Pertama"
        ));
        assert!(is_non_speech("Pertama Pertama Pertama Pertama"));
    }

    #[test]
    fn two_repeats_of_a_long_word_is_not_a_loop() {
        // Three is the floor: two is indistinguishable from a speaker
        // repeating themselves for emphasis.
        assert!(!is_non_speech("Pertama-Pertama"));
    }

    #[test]
    fn a_decoder_stuck_in_a_loop_is_rejected() {
        // The exact segment a live session produced over four seconds of
        // room tone, at confidence 0.75 — too high for any probability
        // threshold to catch.
        assert!(is_non_speech(
            "MENENENENENENENENENENENENENENENENENENENENENENENENENENENENEN"
        ));
        assert!(is_non_speech("aaaaaaaaaaaaaaaaaaaaaaaaaa"));
        assert!(is_non_speech("hahahahahahahahahahahahahaha"));
        assert!(is_non_speech("abcabcabcabcabcabcabcabcabc"));
    }

    #[test]
    fn indonesian_reduplication_is_not_a_loop() {
        // The words this rule must never touch. Indonesian builds plurals
        // and intensifiers by repeating a whole word, and a rule that
        // cannot tell those from a decoder loop would delete real speech.
        for text in [
            "kupu-kupu",
            "berlari-lari",
            "kura-kura",
            "undang-undang",
            "sehari-hari",
            "tiba-tiba",
            "masing-masing",
            "sebaik-baiknya",
            "hahaha",
            "Terima-kasih-banyak-sekali-Pak",
        ] {
            assert!(!is_non_speech(text), "{text} must be kept");
        }
    }

    #[test]
    fn a_loop_inside_a_sentence_is_left_alone() {
        // Same rule as the bracketed tokens: rewriting speech is worse
        // than leaving an oddity in it.
        assert!(!is_non_speech(
            "Jadi anggarannya MENENENENENENENENENENENENENEN naik."
        ));
    }

    #[test]
    fn a_short_repeat_is_not_long_enough_to_judge() {
        // Under the length floor nothing is rejected, whatever its shape.
        assert!(!is_non_speech("nananana"));
        assert!(!is_non_speech("blablabla"));
    }

    #[test]
    fn real_indonesian_speech_survives() {
        // These are the cases the filter must never touch. Each one is
        // something a person plausibly says in a rapat.
        for text in [
            "Selamat pagi semuanya, terima kasih telah hadir di rapat ini.",
            "Terima kasih telah menonton presentasi dari tim keuangan tadi.",
            "Baik, kita lanjut ke agenda berikutnya yaitu anggaran triwulan.",
            "Musiknya tolong dimatikan dulu ya, suaranya masuk ke rekaman.",
            "Saya setuju dengan usulan Pak Budi soal penjadwalan ulang.",
            "Tepuk tangan untuk tim yang sudah menyelesaikan laporan ini tepat waktu.",
            "[Catatan: angka ini masih menunggu konfirmasi dari bagian keuangan]",
        ] {
            assert!(!is_non_speech(text), "{text} must be kept");
        }
    }

    #[test]
    fn a_hallucinated_token_inside_a_sentence_is_left_alone() {
        // Rewriting speech is worse than leaving a stray token in it.
        let text = "Jadi anggarannya [Musik] naik sepuluh persen.";
        assert!(!is_non_speech(text));
    }

    #[test]
    fn two_bracketed_groups_are_not_a_caption() {
        assert!(!is_non_speech("[a] dan [b]"));
    }

    #[test]
    fn a_long_bracketed_aside_survives() {
        assert!(!is_non_speech(
            "(ini catatan panjang dari notulis tentang anggaran)"
        ));
    }

    #[test]
    fn empty_and_punctuation_only_are_rejected() {
        assert!(is_non_speech(""));
        assert!(is_non_speech("   "));
        assert!(is_non_speech("..."));
        assert!(is_non_speech("-"));
    }

    #[test]
    fn filter_segments_reports_what_it_dropped() {
        let mut segments = vec![
            seg("[MENGENI]"),
            seg("Selamat pagi, rapat kita mulai sekarang."),
            seg("[MENGENI]"),
            seg("[Musik]"),
            seg("Agenda pertama adalah laporan keuangan."),
        ];
        let dropped = filter_segments(&mut segments);
        assert_eq!(dropped, 3);
        assert_eq!(segments.len(), 2);
        assert!(segments[0].text.starts_with("Selamat pagi"));
        assert!(segments[1].text.starts_with("Agenda pertama"));
    }

    #[test]
    fn filtering_a_clean_transcript_changes_nothing() {
        let mut segments = vec![
            seg("Selamat pagi semuanya."),
            seg("Kita bahas anggaran dulu ya."),
        ];
        assert_eq!(filter_segments(&mut segments), 0);
        assert_eq!(segments.len(), 2);
    }

    #[test]
    fn normalise_strips_punctuation_and_case() {
        assert_eq!(
            normalise("Terima Kasih, Telah Menonton!"),
            "terima kasih telah menonton"
        );
        assert_eq!(normalise("  ...  "), "");
    }
}
