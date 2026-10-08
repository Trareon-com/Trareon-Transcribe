//! Rust ↔ Python parity for the notulen checks.
//!
//! The app runs [`crate::notulen::factcheck`], [`crate::notulen::register`],
//! [`crate::notulen::angka`] and [`crate::notulen::schema`]. The bake-off
//! that chose the default model runs Python mirrors of all four
//! (`ml/notulen_bench/`). A divergence means the benchmark recommended a
//! model on numbers the product does not reproduce — the one failure mode
//! that cannot be caught by testing either side on its own.
//!
//! So both sides read the *same* expectations, from
//! `ml/notulen_bench/fixtures/parity.json`. Neither can be made to pass
//! by editing its own copy.
//!
//! `ml/` is not part of the build (see `ml/README.md`), so the fixture is
//! read at test time rather than included at compile time, and a checkout
//! without `ml/` skips.

#![cfg(test)]

use super::{angka, factcheck, register, schema};

fn fixture() -> Option<serde_json::Value> {
    let root = std::path::PathBuf::from(
        std::env::var("CARGO_MANIFEST_DIR").unwrap_or_else(|_| ".".into()),
    );
    let path = root.join("../ml/notulen_bench/fixtures/parity.json");
    let text = std::fs::read_to_string(&path).ok()?;
    Some(serde_json::from_str(&text).unwrap_or_else(|e| {
        panic!("{} is not valid JSON: {e}", path.display());
    }))
}

/// Runs `body` against the named fixture section, or reports the skip.
fn with_section(name: &str, body: impl Fn(&Vec<serde_json::Value>)) {
    let Some(data) = fixture() else {
        eprintln!("ml/notulen_bench/fixtures/parity.json absent — skipping parity check");
        return;
    };
    let section = data
        .get(name)
        .and_then(|v| v.as_array())
        .unwrap_or_else(|| panic!("fixture has no array section '{name}'"));
    assert!(!section.is_empty(), "fixture section '{name}' is empty");
    body(section);
}

#[test]
fn stemming_matches_the_python_mirror() {
    with_section("stem", |cases| {
        for case in cases {
            let word = case[0].as_str().unwrap();
            let expected = case[1].as_str().unwrap();
            assert_eq!(
                factcheck::stem_for_parity(word),
                expected,
                "stem({word:?}) diverged from ml/notulen_bench/stem.py"
            );
        }
    });
}

#[test]
fn number_spelling_matches_the_python_mirror() {
    with_section("spell_integer", |cases| {
        for case in cases {
            let value = case[0].as_u64().unwrap();
            let expected = case[1].as_str().unwrap();
            assert_eq!(
                angka::spell_integer(value).as_deref(),
                Some(expected),
                "spell_integer({value}) diverged"
            );
        }
    });
}

#[test]
fn spoken_forms_match_the_python_mirror() {
    with_section("spoken_forms", |cases| {
        for case in cases {
            let written = case[0].as_str().unwrap();
            let expected: Vec<String> = case[1]
                .as_array()
                .unwrap()
                .iter()
                .map(|v| v.as_str().unwrap().to_string())
                .collect();
            assert_eq!(
                angka::spoken_forms(written),
                expected,
                "spoken_forms({written:?}) diverged"
            );
        }
    });
}

#[test]
fn number_extraction_matches_the_python_mirror() {
    with_section("numbers", |cases| {
        for case in cases {
            let text = case[0].as_str().unwrap();
            let expected: Vec<String> = case[1]
                .as_array()
                .unwrap()
                .iter()
                .map(|v| v.as_str().unwrap().to_string())
                .collect();
            assert_eq!(
                factcheck::numbers_for_parity(text),
                expected,
                "numbers({text:?}) diverged"
            );
        }
    });
}

#[test]
fn proper_name_detection_matches_the_python_mirror() {
    with_section("proper_names", |cases| {
        for case in cases {
            let text = case[0].as_str().unwrap();
            let expected: Vec<String> = case[1]
                .as_array()
                .unwrap()
                .iter()
                .map(|v| v.as_str().unwrap().to_string())
                .collect();
            assert_eq!(
                factcheck::proper_names_for_parity(text),
                expected,
                "proper_names({text:?}) diverged"
            );
        }
    });
}

#[test]
fn register_findings_and_normalisation_match_the_python_mirror() {
    with_section("register", |cases| {
        for case in cases {
            let text = case[0].as_str().unwrap();
            // Compared as a sorted multiset: both sides walk their
            // lexicon in the same order, so findings come out in lexicon
            // order rather than text order, and which order that is
            // carries no meaning for the reader.
            let mut expected: Vec<String> = case[1]
                .as_array()
                .unwrap()
                .iter()
                .map(|v| v.as_str().unwrap().to_string())
                .collect();
            expected.sort();
            let mut found: Vec<String> = register::check(text)
                .into_iter()
                .map(|f| f.ditemukan)
                .collect();
            found.sort();
            assert_eq!(found, expected, "register::check({text:?}) diverged");
            assert_eq!(
                register::normalise(text),
                case[2].as_str().unwrap(),
                "register::normalise({text:?}) diverged"
            );
        }
    });
}

#[test]
fn tolerant_json_parsing_matches_the_python_mirror() {
    with_section("schema", |cases| {
        for case in cases {
            let name = case["name"].as_str().unwrap();
            let raw = case["raw"].as_str().unwrap();
            let parsed = schema::parse(raw)
                .unwrap_or_else(|e| panic!("{name}: Rust refused what Python accepts: {e}"));

            let keputusan: Vec<(String, Vec<u64>)> = parsed
                .notulen
                .keputusan
                .iter()
                .map(|k| {
                    (
                        k.isi.clone(),
                        k.segmen.iter().map(|&i| u64::from(i)).collect(),
                    )
                })
                .collect();
            let expected_keputusan: Vec<(String, Vec<u64>)> = case["keputusan"]
                .as_array()
                .unwrap()
                .iter()
                .map(|entry| {
                    (
                        entry[0].as_str().unwrap().to_string(),
                        entry[1]
                            .as_array()
                            .unwrap()
                            .iter()
                            .map(|v| v.as_u64().unwrap())
                            .collect(),
                    )
                })
                .collect();
            assert_eq!(keputusan, expected_keputusan, "{name}: keputusan diverged");

            let follow_ups: Vec<(String, String, String)> = parsed
                .notulen
                .tindak_lanjut
                .iter()
                .map(|t| {
                    (
                        t.tugas.clone(),
                        t.penanggung_jawab.clone(),
                        t.tenggat.clone(),
                    )
                })
                .collect();
            let expected_follow_ups: Vec<(String, String, String)> = case["tindak_lanjut"]
                .as_array()
                .unwrap()
                .iter()
                .map(|entry| {
                    (
                        entry[0].as_str().unwrap().to_string(),
                        entry[1].as_str().unwrap().to_string(),
                        entry[2].as_str().unwrap().to_string(),
                    )
                })
                .collect();
            assert_eq!(
                follow_ups, expected_follow_ups,
                "{name}: tindak_lanjut diverged"
            );
        }
    });
}
