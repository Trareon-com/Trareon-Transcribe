//! Kamus istilah — custom vocabulary fed to Whisper and (optionally) used to
//! repair near-misses in its output.
//!
//! Indonesian meetings are dense with acronyms and institution names Whisper
//! has never seen in its training distribution (`PPBJ`, `SPBE`, `UU PDP`,
//! `Kemenkeu`, `Musrenbang`, `RKAKL`). Two cheap, fully-local mechanisms make
//! a measurable difference:
//!
//! 1. **`initial_prompt` biasing** ([`build_initial_prompt`]). Whisper
//!    conditions decoding on the prompt, so simply listing the terms makes it
//!    far likelier to emit them. The prompt is capped, so the terms are
//!    prioritised (see below).
//! 2. **Post-correction** ([`apply_corrections`]). A deliberately conservative
//!    case-insensitive fuzzy replacement that only ever rewrites a word that
//!    is already *within an edit-distance budget* of a glossary term.
//!
//! Neither mechanism touches the network; this module is part of the
//! transcription hot path and `privacy::tests` scans it as such.

use serde::{Deserialize, Serialize};

/// Whisper keeps at most `n_text_ctx / 2` prompt tokens, which is 224 for
/// every model in the catalogue.
pub const MAX_PROMPT_TOKENS: usize = 224;

/// Glossary terms plus the two switches, as carried on a session.
///
/// Split into global and per-session lists rather than one merged list
/// because the split is exactly what the prioritisation rule needs: when
/// the prompt budget cannot hold everything, the terms the notulis typed
/// *for this meeting* are the ones that must survive.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct GlossaryConfig {
    /// Terms added for this meeting only. Highest priority.
    #[serde(default)]
    pub session_terms: Vec<String>,
    /// The persistent list from Settings.
    #[serde(default)]
    pub global_terms: Vec<String>,
    /// Run [`apply_corrections`] over each segment after inference.
    #[serde(default)]
    pub post_correction: bool,
}

impl GlossaryConfig {
    /// Terms in priority order: per-session first, then global, with
    /// case-insensitive duplicates and blanks removed.
    #[flutter_rust_bridge::frb(ignore)]
    pub fn prioritised_terms(&self) -> Vec<String> {
        let mut out: Vec<String> = Vec::new();
        let mut seen: Vec<String> = Vec::new();
        for term in self.session_terms.iter().chain(self.global_terms.iter()) {
            let cleaned = term.trim();
            if cleaned.is_empty() {
                continue;
            }
            let key = cleaned.to_lowercase();
            if seen.contains(&key) {
                continue;
            }
            seen.push(key);
            out.push(cleaned.to_string());
        }
        out
    }

    #[flutter_rust_bridge::frb(ignore)]
    pub fn is_empty(&self) -> bool {
        self.prioritised_terms().is_empty()
    }
}

/// What [`build_initial_prompt`] produced, plus how much of the glossary fit.
///
/// `terms_used` / `terms_total` exist so Settings can say "18 dari 40 istilah
/// dipakai" instead of silently dropping half the user's vocabulary — an
/// over-long prompt is known to *degrade* Whisper output, so the cap is real
/// and has to be visible.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct GlossaryPrompt {
    pub text: String,
    pub terms_used: usize,
    pub terms_total: usize,
}

/// Conservative token estimate for Indonesian text under Whisper's
/// multilingual BPE: roughly one token per three characters, plus one per
/// whitespace-separated word for the sub-word splits acronyms provoke.
///
/// Deliberately pessimistic — over-estimating costs a few dropped low-priority
/// terms, under-estimating silently truncates the prompt inside whisper.cpp.
#[flutter_rust_bridge::frb(ignore)]
pub fn estimate_tokens(text: &str) -> usize {
    let trimmed = text.trim();
    if trimmed.is_empty() {
        return 0;
    }
    let chars = trimmed.chars().count();
    let words = trimmed.split_whitespace().count();
    chars.div_ceil(3) + words
}

/// The Indonesian lead-in that tells Whisper the list is vocabulary rather
/// than transcript.
const TERM_LEAD_IN: &str = "Istilah: ";

/// Builds the `initial_prompt` for one inference call.
///
/// Layout is `"<context tail>\nIstilah: A, B, C."` — the glossary goes
/// **last** on purpose: whisper.cpp keeps the *final* `n_text_ctx / 2` tokens
/// of the prompt and discards the front, so if [`estimate_tokens`] ever
/// under-counts it is the rolling transcript tail that gets clipped, not the
/// vocabulary the user explicitly asked for. Within the list, global terms
/// come before per-session terms for the same reason.
///
/// Returns `None` for the prompt text when there is nothing to say at all.
#[flutter_rust_bridge::frb(ignore)]
pub fn build_initial_prompt(glossary: &GlossaryConfig, context_tail: &str) -> GlossaryPrompt {
    let all = glossary.prioritised_terms();
    let terms_total = all.len();
    let tail = context_tail.trim();

    // The tail is context, not vocabulary: it may use at most half the
    // budget, so a chatty meeting can never squeeze the glossary out.
    let tail_budget = MAX_PROMPT_TOKENS / 2;
    let tail = if estimate_tokens(tail) > tail_budget {
        clip_to_tokens(tail, tail_budget)
    } else {
        tail.to_string()
    };

    let mut budget = MAX_PROMPT_TOKENS.saturating_sub(estimate_tokens(&tail));
    if terms_total > 0 {
        // The lead-in and the closing period are part of the prompt too.
        budget = budget.saturating_sub(estimate_tokens(TERM_LEAD_IN) + 1);
    }

    // Greedy fill in priority order (session terms first).
    let mut chosen: Vec<String> = Vec::new();
    for term in all {
        // `, ` between entries.
        let cost = estimate_tokens(&term) + usize::from(!chosen.is_empty());
        if cost > budget {
            continue;
        }
        budget -= cost;
        chosen.push(term);
    }
    let terms_used = chosen.len();

    // Render lowest priority first so the highest-priority terms sit closest
    // to the end of the prompt (see the note above about truncation).
    chosen.reverse();

    let mut text = String::new();
    if !tail.is_empty() {
        text.push_str(&tail);
    }
    if !chosen.is_empty() {
        if !text.is_empty() {
            text.push('\n');
        }
        text.push_str(TERM_LEAD_IN);
        text.push_str(&chosen.join(", "));
        text.push('.');
    }

    GlossaryPrompt {
        text,
        terms_used,
        terms_total,
    }
}

/// Keeps the tail end of `text` within `max_tokens` on a word boundary.
fn clip_to_tokens(text: &str, max_tokens: usize) -> String {
    let words: Vec<&str> = text.split_whitespace().collect();
    let mut start = 0usize;
    while start < words.len() {
        let candidate = words[start..].join(" ");
        if estimate_tokens(&candidate) <= max_tokens {
            return candidate;
        }
        start += 1;
    }
    String::new()
}

// ---------------------------------------------------------------------------
// Post-correction
// ---------------------------------------------------------------------------

/// Edit-distance budget for a term of `len` characters.
///
/// Short terms — which is most acronyms — get **zero** budget: they are only
/// ever normalised when they already match case-insensitively, because one
/// edit away from `SPBE` is `SPSE`, a different real agency system.
fn distance_budget(len: usize) -> usize {
    match len {
        0..=5 => 0,
        6..=8 => 1,
        _ => 2,
    }
}

/// Levenshtein distance, bailing out as soon as it exceeds `limit`.
fn edit_distance_within(a: &[char], b: &[char], limit: usize) -> Option<usize> {
    if a.len().abs_diff(b.len()) > limit {
        return None;
    }
    let mut previous: Vec<usize> = (0..=b.len()).collect();
    let mut current = vec![0usize; b.len() + 1];
    for (i, ca) in a.iter().enumerate() {
        current[0] = i + 1;
        let mut row_best = current[0];
        for (j, cb) in b.iter().enumerate() {
            let cost = usize::from(ca != cb);
            current[j + 1] = (previous[j] + cost)
                .min(previous[j + 1] + 1)
                .min(current[j] + 1);
            row_best = row_best.min(current[j + 1]);
        }
        if row_best > limit {
            return None;
        }
        std::mem::swap(&mut previous, &mut current);
    }
    let distance = previous[b.len()];
    (distance <= limit).then_some(distance)
}

/// True when `candidate` is a fuzzy (not exact) hit for `term`.
///
/// Three guards keep this from mangling ordinary Indonesian prose:
/// the first character must agree (case-insensitively), the lengths must be
/// within the budget, and the edit distance must be within it too. Words that
/// are nowhere near a glossary term therefore cannot be touched.
fn is_fuzzy_match(candidate: &str, term: &str) -> bool {
    let term_lower: Vec<char> = term.to_lowercase().chars().collect();
    let cand_lower: Vec<char> = candidate.to_lowercase().chars().collect();
    if term_lower == cand_lower {
        return false;
    }
    let limit = distance_budget(term_lower.len());
    if limit == 0 || term_lower.first() != cand_lower.first() {
        return false;
    }
    edit_distance_within(&cand_lower, &term_lower, limit).is_some()
}

/// Picks the glossary spelling `candidate` should be rewritten to, or `None`
/// to leave it alone.
///
/// An exact case-insensitive hit wins outright: a word that *is* a glossary
/// term may only ever have its casing normalised, never be fuzzed into a
/// neighbouring term (`SPSE` must not become `SPBE` just because both are in
/// the list).
fn choose_term<'a>(candidate: &str, terms: &[&'a str], words: usize) -> Option<&'a str> {
    let sized = || {
        terms
            .iter()
            .copied()
            .filter(|t| t.split_whitespace().count() == words)
    };
    if let Some(exact) = sized().find(|t| t.to_lowercase() == candidate.to_lowercase()) {
        return (exact != candidate).then_some(exact);
    }
    sized().find(|t| is_fuzzy_match(candidate, t))
}

/// A word token or the run of separators between two of them.
#[derive(Debug)]
enum Token<'a> {
    Word(&'a str),
    Gap(&'a str),
}

fn is_word_char(c: char) -> bool {
    c.is_alphanumeric() || c == '\''
}

fn tokenize(text: &str) -> Vec<Token<'_>> {
    let mut out = Vec::new();
    let mut rest = text;
    while !rest.is_empty() {
        let is_word = rest.chars().next().is_some_and(is_word_char);
        let end = rest
            .char_indices()
            .find(|(_, c)| is_word_char(*c) != is_word)
            .map_or(rest.len(), |(i, _)| i);
        let (head, tail) = rest.split_at(end);
        out.push(if is_word {
            Token::Word(head)
        } else {
            Token::Gap(head)
        });
        rest = tail;
    }
    out
}

/// Rewrites near-misses of `terms` in `text` to the glossary's spelling.
///
/// Multi-word terms are matched as whole windows, longest first, and only
/// when the words are separated by a single space — so `"UU PDP"` is repaired
/// as a unit and a line break is never swallowed.
///
/// Guarantees (asserted by the tests): a word that is not within
/// [`distance_budget`] of any term is returned byte-for-byte unchanged, and
/// all whitespace and punctuation is preserved.
#[flutter_rust_bridge::frb(ignore)]
pub fn apply_corrections(text: &str, terms: &[String]) -> String {
    let cleaned: Vec<&str> = terms
        .iter()
        .map(|t| t.trim())
        .filter(|t| !t.is_empty())
        .collect();
    if cleaned.is_empty() || text.trim().is_empty() {
        return text.to_string();
    }

    // Group terms by word count so windows are compared only against terms
    // of the same length, longest window first.
    let max_words = cleaned
        .iter()
        .map(|t| t.split_whitespace().count())
        .max()
        .unwrap_or(1)
        .max(1);

    let tokens = tokenize(text);
    // Indices into `tokens` that are words.
    let word_positions: Vec<usize> = tokens
        .iter()
        .enumerate()
        .filter_map(|(i, t)| matches!(t, Token::Word(_)).then_some(i))
        .collect();

    // `replacement[k]` = (words consumed, text) for the window starting at
    // the k-th word.
    let mut replacement: Vec<Option<(usize, String)>> = vec![None; word_positions.len()];
    let mut k = 0usize;
    while k < word_positions.len() {
        let mut matched = None;
        for window in (1..=max_words).rev() {
            if k + window > word_positions.len() {
                continue;
            }
            // Multi-word windows must be joined by exactly one space.
            let mut candidate = String::new();
            let mut joinable = true;
            for step in 0..window {
                let pos = word_positions[k + step];
                if step > 0 {
                    let gap = match tokens.get(pos - 1) {
                        Some(Token::Gap(g)) => *g,
                        _ => "",
                    };
                    if gap != " " {
                        joinable = false;
                        break;
                    }
                    candidate.push(' ');
                }
                if let Some(Token::Word(w)) = tokens.get(pos) {
                    candidate.push_str(w);
                }
            }
            if !joinable {
                continue;
            }
            if let Some(term) = choose_term(&candidate, &cleaned, window) {
                matched = Some((window, term.to_string()));
                break;
            }
        }
        match matched {
            Some((window, term)) => {
                replacement[k] = Some((window, term));
                k += window;
            }
            None => k += 1,
        }
    }

    // Re-emit, substituting matched windows.
    let mut out = String::with_capacity(text.len());
    let mut word_index = 0usize;
    // Token index the current multi-word substitution runs up to (exclusive).
    let mut swallow_until = 0usize;
    for (i, token) in tokens.iter().enumerate() {
        if i < swallow_until {
            if matches!(token, Token::Word(_)) {
                word_index += 1;
            }
            continue;
        }
        match token {
            Token::Gap(gap) => out.push_str(gap),
            Token::Word(word) => {
                match &replacement[word_index] {
                    Some((window, term)) => {
                        out.push_str(term);
                        // Swallow the (window - 1) following words and the
                        // single spaces between them.
                        if *window > 1 {
                            swallow_until = word_positions[word_index + window - 1] + 1;
                        }
                    }
                    None => out.push_str(word),
                }
                word_index += 1;
            }
        }
    }
    out
}

/// Applies [`apply_corrections`] to every segment's text in place.
#[flutter_rust_bridge::frb(ignore)]
pub fn correct_segments(segments: &mut [crate::export::Segment], terms: &[String]) {
    if terms.is_empty() {
        return;
    }
    for segment in segments.iter_mut() {
        let fixed = apply_corrections(&segment.text, terms);
        if fixed != segment.text {
            segment.text = fixed;
        }
    }
}

// ---------------------------------------------------------------------------
// Import / export
// ---------------------------------------------------------------------------

/// First field of one delimited line, honouring RFC-4180 double quoting.
///
/// A term may legitimately contain the delimiter (`Rp1.000,00`), so a naive
/// `split(',')` would import half a term.
fn first_field(line: &str) -> String {
    let mut chars = line.trim_start().chars().peekable();
    if chars.peek() != Some(&'"') {
        return line
            .split(['\t', ';', ','])
            .next()
            .unwrap_or(line)
            .to_string();
    }
    chars.next();
    let mut out = String::new();
    while let Some(c) = chars.next() {
        if c != '"' {
            out.push(c);
            continue;
        }
        // `""` inside a quoted field is a literal quote.
        if chars.peek() == Some(&'"') {
            chars.next();
            out.push('"');
        } else {
            break;
        }
    }
    out
}

/// Parses a user-supplied glossary file.
///
/// Accepts both shapes the brief asks for, without asking the user which is
/// which: one term per line (`.txt`), or CSV/semicolon/tab-separated where
/// only the **first column** is the term (so a spreadsheet with a
/// "keterangan" column imports cleanly). `#` starts a comment line, blank
/// lines are skipped, a leading UTF-8 BOM is stripped, and a header row
/// whose first cell is `istilah`/`term` is dropped.
#[flutter_rust_bridge::frb(ignore)]
pub fn parse_glossary(content: &str) -> Vec<String> {
    let mut out: Vec<String> = Vec::new();
    let mut seen: Vec<String> = Vec::new();
    for (index, raw_line) in content.lines().enumerate() {
        let line = if index == 0 {
            raw_line.trim_start_matches('\u{feff}')
        } else {
            raw_line
        };
        let line = line.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        let first_cell = first_field(line);
        let first_cell = first_cell.trim();
        if first_cell.is_empty() {
            continue;
        }
        if index == 0 && matches!(first_cell.to_lowercase().as_str(), "istilah" | "term") {
            continue;
        }
        let key = first_cell.to_lowercase();
        if seen.contains(&key) {
            continue;
        }
        seen.push(key);
        out.push(first_cell.to_string());
    }
    out
}

/// Renders the glossary for export. `csv` produces a one-column CSV with an
/// Indonesian header (so Excel/LibreOffice shows something meaningful);
/// otherwise it is one term per line.
#[flutter_rust_bridge::frb(ignore)]
pub fn render_glossary(terms: &[String], csv: bool) -> String {
    let cleaned: Vec<&str> = terms
        .iter()
        .map(|t| t.trim())
        .filter(|t| !t.is_empty())
        .collect();
    let mut out = String::new();
    if csv {
        out.push_str("istilah\n");
        for term in cleaned {
            // Quote only when necessary, the way a spreadsheet expects.
            if term.contains([',', '"', ';', '\n']) {
                out.push('"');
                out.push_str(&term.replace('"', "\"\""));
                out.push_str("\"\n");
            } else {
                out.push_str(term);
                out.push('\n');
            }
        }
    } else {
        for term in cleaned {
            out.push_str(term);
            out.push('\n');
        }
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    fn config(session: &[&str], global: &[&str]) -> GlossaryConfig {
        GlossaryConfig {
            session_terms: session.iter().map(|s| s.to_string()).collect(),
            global_terms: global.iter().map(|s| s.to_string()).collect(),
            post_correction: true,
        }
    }

    fn terms(list: &[&str]) -> Vec<String> {
        list.iter().map(|s| s.to_string()).collect()
    }

    // --- prioritisation --------------------------------------------------

    #[test]
    fn session_terms_come_first_and_duplicates_collapse() {
        let cfg = config(&["PPBJ", "kemenkeu"], &["Kemenkeu", "SPBE", "  "]);
        assert_eq!(
            cfg.prioritised_terms(),
            terms(&["PPBJ", "kemenkeu", "SPBE"])
        );
    }

    #[test]
    fn an_empty_glossary_is_reported_as_empty() {
        assert!(GlossaryConfig::default().is_empty());
        assert!(config(&["   "], &[""]).is_empty());
        assert!(!config(&[], &["SPBE"]).is_empty());
    }

    // --- prompt ----------------------------------------------------------

    #[test]
    fn prompt_lists_the_terms_after_the_context_tail() {
        let prompt = build_initial_prompt(&config(&["PPBJ"], &["SPBE"]), "kita lanjut ke agenda");
        assert!(prompt.text.starts_with("kita lanjut ke agenda"));
        assert!(prompt.text.contains("Istilah: "));
        assert!(prompt.text.ends_with("PPBJ."), "got: {}", prompt.text);
        assert_eq!(prompt.terms_used, 2);
        assert_eq!(prompt.terms_total, 2);
    }

    #[test]
    fn prompt_is_empty_when_there_is_nothing_to_say() {
        let prompt = build_initial_prompt(&GlossaryConfig::default(), "  ");
        assert!(prompt.text.is_empty());
        assert_eq!(prompt.terms_total, 0);
    }

    #[test]
    fn prompt_without_a_glossary_is_just_the_tail() {
        let prompt = build_initial_prompt(&GlossaryConfig::default(), "halo semua");
        assert_eq!(prompt.text, "halo semua");
    }

    #[test]
    fn prompt_respects_the_token_cap_and_reports_what_was_dropped() {
        // 400 distinct multi-syllable terms cannot fit in 224 tokens.
        let many: Vec<String> = (0..400).map(|i| format!("Istilahpanjang{i}")).collect();
        let cfg = GlossaryConfig {
            session_terms: vec!["PPBJ".to_string()],
            global_terms: many,
            post_correction: false,
        };
        let prompt = build_initial_prompt(&cfg, "");
        assert!(estimate_tokens(&prompt.text) <= MAX_PROMPT_TOKENS);
        assert_eq!(prompt.terms_total, 401);
        assert!(prompt.terms_used > 0 && prompt.terms_used < 401);
        // The per-session term is never the one dropped.
        assert!(prompt.text.contains("PPBJ"), "session term must survive");
    }

    #[test]
    fn a_very_long_context_tail_cannot_crowd_out_the_glossary() {
        let tail = "kata ".repeat(400);
        let prompt = build_initial_prompt(&config(&["Musrenbang"], &[]), &tail);
        assert!(estimate_tokens(&prompt.text) <= MAX_PROMPT_TOKENS);
        assert!(prompt.text.contains("Musrenbang"));
        assert_eq!(prompt.terms_used, 1);
    }

    #[test]
    fn token_estimate_is_monotonic_and_pessimistic() {
        assert_eq!(estimate_tokens("   "), 0);
        assert!(estimate_tokens("Kemenkeu") >= 2);
        assert!(estimate_tokens("a b c d") > estimate_tokens("a b c"));
    }

    // --- post-correction -------------------------------------------------

    #[test]
    fn casing_of_a_known_acronym_is_normalised() {
        assert_eq!(
            apply_corrections(
                "kita bahas ppbj dan spbe hari ini",
                &terms(&["PPBJ", "SPBE"])
            ),
            "kita bahas PPBJ dan SPBE hari ini"
        );
    }

    #[test]
    fn a_near_miss_of_a_long_term_is_repaired() {
        assert_eq!(
            apply_corrections("anggaran Kemenku naik", &terms(&["Kemenkeu"])),
            "anggaran Kemenkeu naik"
        );
        assert_eq!(
            apply_corrections("hasil musrembang desa", &terms(&["Musrenbang"])),
            "hasil Musrenbang desa"
        );
    }

    #[test]
    fn short_terms_are_never_fuzzy_matched() {
        // One edit from SPBE is SPSE — a different, real system. Correcting
        // across that gap would silently falsify the minutes.
        assert_eq!(
            apply_corrections("aplikasi SPSE dipakai", &terms(&["SPBE"])),
            "aplikasi SPSE dipakai"
        );
        assert_eq!(
            apply_corrections("data DIPA turun", &terms(&["DIPB"])),
            "data DIPA turun"
        );
    }

    #[test]
    fn words_far_from_every_term_are_returned_untouched() {
        let input = "rapat koordinasi membahas rencana pembangunan tahun depan";
        assert_eq!(
            apply_corrections(input, &terms(&["Kemenkeu", "Musrenbang", "PPBJ", "RKAKL"])),
            input
        );
    }

    #[test]
    fn punctuation_and_whitespace_survive_exactly() {
        let input = "  Baik, ppbj (2026)?\n\tLanjut: spbe...  ";
        let out = apply_corrections(input, &terms(&["PPBJ", "SPBE"]));
        assert_eq!(out, "  Baik, PPBJ (2026)?\n\tLanjut: SPBE...  ");
    }

    #[test]
    fn multi_word_terms_are_matched_as_a_unit() {
        assert_eq!(
            apply_corrections("sesuai uu pdp pasal 5", &terms(&["UU PDP"])),
            "sesuai UU PDP pasal 5"
        );
        // A line break between the words is not a single space, so the window
        // must not match and the newline must not be swallowed.
        assert_eq!(
            apply_corrections("uu\npdp", &terms(&["UU PDP"])),
            "uu\npdp",
            "a window may not span a line break"
        );
    }

    #[test]
    fn the_longest_matching_window_wins() {
        // "UU PDP" must not be split into "UU" + a fuzzy match on "PDP".
        let out = apply_corrections("aturan uu pdp berlaku", &terms(&["UU", "UU PDP"]));
        assert_eq!(out, "aturan UU PDP berlaku");
    }

    #[test]
    fn correction_is_idempotent() {
        let list = terms(&["PPBJ", "Kemenkeu", "UU PDP"]);
        let once = apply_corrections("ppbj kemenku uu pdp", &list);
        assert_eq!(apply_corrections(&once, &list), once);
    }

    #[test]
    fn an_empty_glossary_is_a_no_op() {
        assert_eq!(apply_corrections("halo dunia", &[]), "halo dunia");
        assert_eq!(apply_corrections("", &terms(&["PPBJ"])), "");
    }

    #[test]
    fn correct_segments_rewrites_in_place() {
        let mut segments = vec![crate::export::Segment {
            source: "mic".into(),
            speaker: "MIC".into(),
            text: "anggaran kemenku disetujui".into(),
            timestamp: 0.0,
            duration: 1.0,
            language: "id".into(),
            confidence: 0.9,
            avg_log_prob: -0.3,
            is_partial: false,
            low_confidence: false,
            words: Vec::new(),
        }];
        correct_segments(&mut segments, &terms(&["Kemenkeu"]));
        assert_eq!(segments[0].text, "anggaran Kemenkeu disetujui");
    }

    // --- import / export -------------------------------------------------

    #[test]
    fn parses_one_term_per_line() {
        assert_eq!(
            parse_glossary("PPBJ\n\nSPBE\n# catatan\nKemenkeu\n"),
            terms(&["PPBJ", "SPBE", "Kemenkeu"])
        );
    }

    #[test]
    fn parses_csv_first_column_only() {
        let csv = "istilah,keterangan\nPPBJ,Pengadaan Barang/Jasa\n\"UU PDP\",Undang-undang\n";
        assert_eq!(parse_glossary(csv), terms(&["PPBJ", "UU PDP"]));
    }

    #[test]
    fn parsing_strips_a_bom_and_collapses_duplicates() {
        assert_eq!(
            parse_glossary("\u{feff}PPBJ\nppbj\nSPBE"),
            terms(&["PPBJ", "SPBE"])
        );
    }

    #[test]
    fn render_roundtrips_through_parse() {
        let original = terms(&["PPBJ", "UU PDP", "Kemenkeu"]);
        for csv in [false, true] {
            let rendered = render_glossary(&original, csv);
            assert_eq!(parse_glossary(&rendered), original, "csv={csv}");
        }
    }

    #[test]
    fn csv_export_quotes_terms_containing_a_comma() {
        let rendered = render_glossary(&terms(&["Rp1.000,00"]), true);
        assert!(rendered.contains("\"Rp1.000,00\""), "got: {rendered}");
        assert_eq!(parse_glossary(&rendered), terms(&["Rp1.000,00"]));
    }
}
