//! Spelling Indonesian numbers out in words.
//!
//! The fact check has to decide whether "4 persen" in a notulen is
//! supported by a transcript that says "empat persen". There are two
//! directions to go:
//!
//! * Parse the transcript's words into numbers. Needs a grammar, and
//!   every bug in that grammar silently turns a real figure into a
//!   fabricated-number finding.
//! * Spell the notulen's figure into words and look for *that* in the
//!   transcript. Deterministic, one correct answer per input.
//!
//! The second. Same reasoning, and the same four irregularities, as
//! `ml/eval/numbers_id.py`, which does this for the WER normaliser:
//!
//! * 11 is `sebelas`, not `satu belas`; 12–19 are `<n> belas`.
//! * 100 is `seratus` and 1000 `seribu` — `se-` replaces `satu`. But
//!   1 000 000 is `satu juta`, not `sejuta`.
//! * Scale words are long-scale-free: ribu 10³, juta 10⁶, miliar 10⁹,
//!   triliun 10¹².
//! * A decimal separator is a comma, read as `koma`, after which digits
//!   are read one at a time.

const UNITS: [&str; 10] = [
    "nol", "satu", "dua", "tiga", "empat", "lima", "enam", "tujuh", "delapan", "sembilan",
];

/// 10³ᵏ scale names, index = k.
const SCALES: [&str; 6] = ["", "ribu", "juta", "miliar", "triliun", "kuadriliun"];

/// Spells a non-negative integer in Indonesian.
///
/// Returns `None` past the largest scale name known, rather than
/// producing something wrong: an unspellable figure simply cannot be
/// matched by its word form, which is the honest outcome.
#[flutter_rust_bridge::frb(ignore)]
pub fn spell_integer(value: u64) -> Option<String> {
    Some(match value {
        0..=9 => UNITS[value as usize].to_string(),
        10 => "sepuluh".to_string(),
        11 => "sebelas".to_string(),
        12..=19 => format!("{} belas", UNITS[(value % 10) as usize]),
        20..=99 => {
            let head = format!("{} puluh", UNITS[(value / 10) as usize]);
            match value % 10 {
                0 => head,
                ones => format!("{head} {}", UNITS[ones as usize]),
            }
        }
        100..=999 => {
            let head = if value / 100 == 1 {
                "seratus".to_string()
            } else {
                format!("{} ratus", UNITS[(value / 100) as usize])
            };
            match value % 100 {
                0 => head,
                rest => format!("{head} {}", spell_integer(rest)?),
            }
        }
        _ => {
            // Split into 10³ groups and name each with its scale.
            let mut groups: Vec<u64> = Vec::new();
            let mut remaining = value;
            while remaining > 0 {
                groups.push(remaining % 1000);
                remaining /= 1000;
            }
            if groups.len() > SCALES.len() {
                return None;
            }
            let mut parts: Vec<String> = Vec::new();
            for index in (0..groups.len()).rev() {
                let group = groups[index];
                if group == 0 {
                    continue;
                }
                if index == 1 && group == 1 {
                    // 1000 is "seribu", not "satu ribu".
                    parts.push("seribu".to_string());
                } else if SCALES[index].is_empty() {
                    parts.push(spell_integer(group)?);
                } else {
                    parts.push(format!("{} {}", spell_integer(group)?, SCALES[index]));
                }
            }
            parts.join(" ")
        }
    })
}

/// Every word form worth searching a transcript for, given a figure as
/// it was written in the notulen.
///
/// `"8.500.000"` yields the spelling of 8 500 000 and of its bare digit
/// run; `"08.00"` additionally yields the spelling of the hour, because
/// a speaker says "pukul delapan" where the notulen writes "08.00".
#[flutter_rust_bridge::frb(ignore)]
pub fn spoken_forms(written: &str) -> Vec<String> {
    let mut out: Vec<String> = Vec::new();
    let bare: String = written.chars().filter(char::is_ascii_digit).collect();
    if bare.is_empty() {
        return out;
    }
    // A clock reads as its hour: "pukul 08.00" is spoken "pukul
    // delapan". Checked first and exclusively — reading "08.00" as the
    // number 800 as well would let a transcript saying "delapan ratus
    // juta" vouch for a meeting time nobody stated.
    if let Some((head, tail)) = written.split_once([':', '.']) {
        let head_digits: String = head.chars().filter(char::is_ascii_digit).collect();
        let tail_digits: String = tail.chars().filter(char::is_ascii_digit).collect();
        if head_digits.len() <= 2 && tail_digits.len() == 2 && !head_digits.is_empty() {
            if let Some(words) = head_digits.parse::<u64>().ok().and_then(spell_integer) {
                out.push(words);
            }
            return out;
        }
    }
    // Otherwise the separators are thousands separators: "8.500.000" is
    // eight and a half million, not three numbers.
    if let Some(words) = bare.parse::<u64>().ok().and_then(spell_integer) {
        out.push(words);
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn units_and_the_irregular_teens() {
        assert_eq!(spell_integer(0).unwrap(), "nol");
        assert_eq!(spell_integer(4).unwrap(), "empat");
        assert_eq!(spell_integer(10).unwrap(), "sepuluh");
        assert_eq!(spell_integer(11).unwrap(), "sebelas");
        assert_eq!(spell_integer(12).unwrap(), "dua belas");
        assert_eq!(spell_integer(19).unwrap(), "sembilan belas");
    }

    #[test]
    fn tens_and_hundreds_use_se_for_one() {
        assert_eq!(spell_integer(20).unwrap(), "dua puluh");
        assert_eq!(spell_integer(25).unwrap(), "dua puluh lima");
        assert_eq!(spell_integer(100).unwrap(), "seratus");
        assert_eq!(spell_integer(180).unwrap(), "seratus delapan puluh");
        assert_eq!(spell_integer(200).unwrap(), "dua ratus");
    }

    #[test]
    fn thousand_is_seribu_but_a_million_is_satu_juta() {
        assert_eq!(spell_integer(1_000).unwrap(), "seribu");
        assert_eq!(spell_integer(1_200).unwrap(), "seribu dua ratus");
        assert_eq!(spell_integer(2_000).unwrap(), "dua ribu");
        // "sejuta" is a real word but not the canonical reading here.
        assert_eq!(spell_integer(1_000_000).unwrap(), "satu juta");
    }

    #[test]
    fn years_read_as_plain_cardinals() {
        // The failure this module was added for: a notulen writes "2026"
        // where the speaker said "dua ribu dua puluh enam".
        assert_eq!(spell_integer(2026).unwrap(), "dua ribu dua puluh enam");
        assert_eq!(
            spell_integer(1945).unwrap(),
            "seribu sembilan ratus empat puluh lima"
        );
    }

    #[test]
    fn scales_skip_empty_groups() {
        assert_eq!(spell_integer(1_000_000_000).unwrap(), "satu miliar");
        assert_eq!(
            spell_integer(82_000_000_000).unwrap(),
            "delapan puluh dua miliar"
        );
        // 1 000 001 must not become "satu juta nol ribu satu".
        assert_eq!(spell_integer(1_000_001).unwrap(), "satu juta satu");
    }

    #[test]
    fn a_figure_past_the_known_scales_is_none_not_wrong() {
        assert!(spell_integer(u64::MAX).is_none());
    }

    #[test]
    fn spoken_forms_strip_thousand_separators() {
        let forms = spoken_forms("8.500.000");
        assert!(
            forms.contains(&"delapan juta lima ratus ribu".to_string()),
            "got {forms:?}"
        );
    }

    #[test]
    fn spoken_forms_of_a_clock_include_the_hour() {
        // "08.00" is spoken "pukul delapan", so "delapan" has to be one
        // of the forms searched for.
        let forms = spoken_forms("08.00");
        assert!(forms.contains(&"delapan".to_string()), "got {forms:?}");
        let half_past = spoken_forms("9:30");
        assert!(
            half_past.contains(&"sembilan".to_string()),
            "got {half_past:?}"
        );
    }

    #[test]
    fn spoken_forms_of_a_long_figure_do_not_claim_an_hour() {
        // "2026" must not be read as a clock and matched by "dua".
        let forms = spoken_forms("2026");
        assert_eq!(forms, vec!["dua ribu dua puluh enam".to_string()]);
    }

    #[test]
    fn a_non_numeric_string_has_no_spoken_form() {
        assert!(spoken_forms("").is_empty());
        assert!(spoken_forms("abc").is_empty());
    }
}
