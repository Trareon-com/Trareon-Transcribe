//! The notulen JSON schema, and a parser tolerant enough for a 4B model.
//!
//! # Why JSON and not Markdown headings
//!
//! Sprint 3 asked the model for `## Keputusan` and parsed the headings
//! back out. Measured against real local models that fails in three ways
//! that all look like "the feature is broken":
//!
//! * The heading gets renamed — "Kesimpulan", "Rencana Aksi",
//!   "**Keputusan:**" — and the section silently lands in Pembahasan.
//! * Tindak lanjut arrives as prose instead of a table, so PJ and tenggat
//!   are lost even though the model said them.
//! * There is nowhere to hang per-claim provenance: a `[#12]` marker in
//!   the middle of a Markdown line cannot be attached to *one* keputusan.
//!
//! A single JSON object fixes all three. The keys are fixed, the
//! follow-ups are objects with named fields, and each claim carries its
//! own `segmen` array.
//!
//! # Tolerance is the whole job
//!
//! Small models do not emit clean JSON. Observed, repeatedly: a
//! ```` ```json ```` fence; a sentence of preamble ("Berikut notulen
//! rapatnya:"); a trailing comma before `}`; `keputusan` as an array of
//! bare strings instead of objects; `segmen` as `"12, 13"` instead of
//! `[12, 13]`; a `<think>` block from a reasoning model. Rejecting those
//! means rejecting the model, so [`parse`] repairs each of them and
//! records what it had to repair — the repair list is itself a quality
//! signal, and `ml/notulen_bench` scores on it.

use serde::{Deserialize, Serialize};

use crate::error::TranscribeError;

/// One discussion topic.
#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct Pembahasan {
    #[serde(default, alias = "judul", alias = "pokok_bahasan")]
    pub topik: String,
    #[serde(default, alias = "isi", alias = "ringkasan", alias = "detail")]
    pub uraian: String,
    #[serde(default, deserialize_with = "segment_ids")]
    pub segmen: Vec<u32>,
}

/// One intervention in a risalah: who said what, in order.
#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct Intervensi {
    #[serde(default, alias = "nama", alias = "speaker", alias = "penutur")]
    pub pembicara: String,
    #[serde(default, alias = "isi", alias = "uraian", alias = "pernyataan")]
    pub pokok: String,
    #[serde(default, deserialize_with = "segment_ids")]
    pub segmen: Vec<u32>,
}

/// One decision taken.
#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct Keputusan {
    #[serde(default, alias = "keputusan", alias = "teks", alias = "uraian")]
    pub isi: String,
    #[serde(default, deserialize_with = "segment_ids")]
    pub segmen: Vec<u32>,
}

/// One follow-up, with the two fields that make it actionable.
#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct TindakLanjut {
    #[serde(default, alias = "kegiatan", alias = "action", alias = "uraian")]
    pub tugas: String,
    #[serde(
        default,
        alias = "pj",
        alias = "pic",
        alias = "owner",
        alias = "penanggungjawab"
    )]
    pub penanggung_jawab: String,
    #[serde(default, alias = "batas_waktu", alias = "due", alias = "deadline")]
    pub tenggat: String,
    #[serde(default, deserialize_with = "segment_ids")]
    pub segmen: Vec<u32>,
}

/// The whole notulen, as the model is asked to produce it.
///
/// Every field is `#[serde(default)]`: a model that omits `agenda`
/// entirely must still produce a usable notulen, and the *structure
/// check* — not the parser — is what reports a missing required section.
#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct NotulenJson {
    #[serde(default)]
    pub ringkasan: String,
    #[serde(default, deserialize_with = "string_list")]
    pub peserta: Vec<String>,
    #[serde(default, deserialize_with = "string_list", alias = "acara")]
    pub agenda: Vec<String>,
    /// Berita acara only: "kami yang bertanda tangan di bawah ini".
    #[serde(default, deserialize_with = "string_list", alias = "para_pihak")]
    pub pihak: Vec<String>,
    #[serde(default, deserialize_with = "intervensi_list", alias = "jalannya")]
    pub jalannya_rapat: Vec<Intervensi>,
    #[serde(default, deserialize_with = "pembahasan_list")]
    pub pembahasan: Vec<Pembahasan>,
    #[serde(
        default,
        deserialize_with = "keputusan_list",
        alias = "kesimpulan",
        alias = "kesepakatan"
    )]
    pub keputusan: Vec<Keputusan>,
    #[serde(
        default,
        deserialize_with = "tindak_lanjut_list",
        alias = "action_items",
        alias = "rencana_aksi"
    )]
    pub tindak_lanjut: Vec<TindakLanjut>,
}

/// What [`parse`] produced, plus everything it had to forgive.
#[derive(Debug, Clone, Default, PartialEq)]
pub struct ParsedNotulen {
    pub notulen: NotulenJson,
    /// Human-readable list of repairs applied, in Indonesian. Empty means
    /// the model emitted exactly the requested JSON.
    pub perbaikan: Vec<String>,
}

// ---------------------------------------------------------------------------
// Deserialisation helpers: the shapes models actually emit
// ---------------------------------------------------------------------------

/// Accepts `[1,2]`, `["1","2"]`, `"1, 2"`, `"[#1,2]"`, `3`, or `null`.
fn segment_ids<'de, D>(deserializer: D) -> Result<Vec<u32>, D::Error>
where
    D: serde::Deserializer<'de>,
{
    let value = serde_json::Value::deserialize(deserializer)?;
    Ok(collect_ids(&value))
}

fn collect_ids(value: &serde_json::Value) -> Vec<u32> {
    match value {
        serde_json::Value::Null => Vec::new(),
        serde_json::Value::Number(n) => n.as_u64().map(|v| vec![v as u32]).unwrap_or_default(),
        serde_json::Value::String(s) => ids_from_text(s),
        serde_json::Value::Array(items) => items.iter().flat_map(collect_ids).collect(),
        _ => Vec::new(),
    }
}

/// Pulls every run of digits out of free text. `"[#12, 13]"` → `[12, 13]`.
fn ids_from_text(text: &str) -> Vec<u32> {
    let mut out = Vec::new();
    let mut digits = String::new();
    for ch in text.chars().chain(std::iter::once(' ')) {
        if ch.is_ascii_digit() {
            digits.push(ch);
        } else if !digits.is_empty() {
            if let Ok(id) = digits.parse::<u32>() {
                out.push(id);
            }
            digits.clear();
        }
    }
    out
}

/// Accepts `["a","b"]`, `"a, b"`, `"a\nb"`, `[{"nama":"a"}]`, or `null`.
fn string_list<'de, D>(deserializer: D) -> Result<Vec<String>, D::Error>
where
    D: serde::Deserializer<'de>,
{
    let value = serde_json::Value::deserialize(deserializer)?;
    Ok(collect_strings(&value))
}

fn collect_strings(value: &serde_json::Value) -> Vec<String> {
    match value {
        serde_json::Value::Null => Vec::new(),
        serde_json::Value::String(s) => split_people(s),
        serde_json::Value::Array(items) => items.iter().flat_map(collect_strings).collect(),
        serde_json::Value::Object(map) => map
            .get("nama")
            .or_else(|| map.get("name"))
            .or_else(|| map.get("jabatan"))
            .map(collect_strings)
            .unwrap_or_default(),
        other => vec![other.to_string()],
    }
}

/// Maps whatever shape a list field arrived in onto typed entries.
///
/// A model that emits `keputusan` as an array of bare strings, as one
/// multi-line string, or as a single object instead of an array is giving
/// the right *content* in the wrong container. Rejecting it would reject
/// the model, so every container is accepted and the content is kept.
fn to_items<T>(
    value: &serde_json::Value,
    build: impl Fn(&serde_json::Value) -> Option<T>,
) -> Vec<T> {
    match value {
        serde_json::Value::Null => Vec::new(),
        serde_json::Value::Array(items) => items.iter().filter_map(&build).collect(),
        serde_json::Value::String(text) => text
            .lines()
            .map(|line| line.trim().trim_start_matches(['-', '*', '•']).trim())
            .filter(|line| !line.is_empty())
            .filter_map(|line| build(&serde_json::Value::String(line.to_string())))
            .collect(),
        other => build(other).into_iter().collect(),
    }
}

/// Splits `"Pagu disetujui. [#7,8]"` into its text and its segment ids.
///
/// The prompt asks for `segmen` as a field, but a model that has seen
/// `crate::provenance`-style instructions in its training data writes the
/// marker inline instead. Both are accepted.
fn split_inline_citation(text: &str) -> (String, Vec<u32>) {
    let trimmed = text.trim();
    let Some(open) = trimmed.rfind("[#") else {
        return (trimmed.to_string(), Vec::new());
    };
    let Some(close) = trimmed[open..].find(']') else {
        return (trimmed.to_string(), Vec::new());
    };
    let ids = ids_from_text(&trimmed[open..open + close]);
    if ids.is_empty() {
        return (trimmed.to_string(), Vec::new());
    }
    let mut body = String::from(&trimmed[..open]);
    body.push_str(&trimmed[open + close + 1..]);
    (body.trim().to_string(), ids)
}

fn keputusan_list<'de, D>(deserializer: D) -> Result<Vec<Keputusan>, D::Error>
where
    D: serde::Deserializer<'de>,
{
    let value = serde_json::Value::deserialize(deserializer)?;
    Ok(to_items(&value, |item| match item {
        serde_json::Value::String(text) => {
            let (isi, segmen) = split_inline_citation(text);
            Some(Keputusan { isi, segmen })
        }
        serde_json::Value::Object(_) => serde_json::from_value(item.clone()).ok(),
        _ => None,
    }))
}

fn pembahasan_list<'de, D>(deserializer: D) -> Result<Vec<Pembahasan>, D::Error>
where
    D: serde::Deserializer<'de>,
{
    let value = serde_json::Value::deserialize(deserializer)?;
    Ok(to_items(&value, |item| match item {
        serde_json::Value::String(text) => {
            let (uraian, segmen) = split_inline_citation(text);
            Some(Pembahasan {
                topik: String::new(),
                uraian,
                segmen,
            })
        }
        serde_json::Value::Object(_) => serde_json::from_value(item.clone()).ok(),
        _ => None,
    }))
}

fn intervensi_list<'de, D>(deserializer: D) -> Result<Vec<Intervensi>, D::Error>
where
    D: serde::Deserializer<'de>,
{
    let value = serde_json::Value::deserialize(deserializer)?;
    Ok(to_items(&value, |item| match item {
        serde_json::Value::String(text) => {
            let (body, segmen) = split_inline_citation(text);
            // `"Pimpinan Rapat: membuka rapat"` carries the speaker in the
            // line, which is how a model writes a risalah when it is not
            // given an object shape.
            let (pembicara, pokok) = match body.split_once(':') {
                Some((head, rest)) if looks_like_speaker(head) => {
                    (head.trim().to_string(), rest.trim().to_string())
                }
                _ => (String::new(), body),
            };
            Some(Intervensi {
                pembicara,
                pokok,
                segmen,
            })
        }
        serde_json::Value::Object(_) => serde_json::from_value(item.clone()).ok(),
        _ => None,
    }))
}

/// Whether the text before a colon is a name or jabatan rather than the
/// opening clause of a sentence.
///
/// A name or jabatan is title case throughout ("Pimpinan Rapat", "Kepala
/// Bagian Perencanaan dan Keuangan", "Dr. Siti Aminah"); a sentence is
/// not ("Rapat menyepakati tiga hal berikut"). Lowercase connectors are
/// allowed because jabatan contain them.
fn looks_like_speaker(head: &str) -> bool {
    const CONNECTORS: &[&str] = &["dan", "atau", "serta", "a.n.", "u.b.", "de", "bin", "binti"];
    let words: Vec<&str> = head.split_whitespace().collect();
    if words.is_empty() || words.len() > 6 || head.len() > 64 {
        return false;
    }
    words.iter().all(|word| {
        CONNECTORS.contains(&word.to_lowercase().as_str())
            || word
                .chars()
                .next()
                .is_some_and(|c| c.is_uppercase() || c.is_ascii_digit())
    })
}

fn tindak_lanjut_list<'de, D>(deserializer: D) -> Result<Vec<TindakLanjut>, D::Error>
where
    D: serde::Deserializer<'de>,
{
    let value = serde_json::Value::deserialize(deserializer)?;
    Ok(to_items(&value, |item| match item {
        serde_json::Value::String(text) => {
            let (body, segmen) = split_inline_citation(text);
            Some(TindakLanjut {
                tugas: body,
                penanggung_jawab: String::new(),
                tenggat: String::new(),
                segmen,
            })
        }
        serde_json::Value::Object(_) => serde_json::from_value(item.clone()).ok(),
        _ => None,
    }))
}

/// Splits one line that holds several names.
///
/// Newlines and semicolons always separate. A comma only separates when
/// the line has no newline, because "Dr. Siti Aminah, M.Si." is one
/// person and splitting on its comma invents a participant called
/// "M.Si.".
fn split_people(text: &str) -> Vec<String> {
    let has_lines = text.contains('\n') || text.contains(';');
    let parts: Vec<&str> = if has_lines {
        text.split(['\n', ';']).collect()
    } else {
        text.split(',').collect()
    };
    parts
        .into_iter()
        .map(|p| p.trim().trim_start_matches(['-', '*', '•']).trim())
        .filter(|p| !p.is_empty())
        .map(str::to_string)
        .collect()
}

// ---------------------------------------------------------------------------
// The parser
// ---------------------------------------------------------------------------

/// Strips a reasoning model's `<think>…</think>` preamble.
fn strip_thinking(raw: &str) -> (String, bool) {
    let lower = raw.to_lowercase();
    if let Some(start) = lower.find("<think>") {
        if let Some(end) = lower[start..].find("</think>") {
            let mut out = String::with_capacity(raw.len());
            out.push_str(&raw[..start]);
            out.push_str(&raw[start + end + "</think>".len()..]);
            return (out, true);
        }
        // An unterminated <think> means the whole answer is reasoning and
        // the JSON never arrived; keep the text so the caller sees why.
        return (raw[..start].to_string(), true);
    }
    (raw.to_string(), false)
}

/// Finds the outermost `{…}` object, ignoring braces inside strings.
///
/// Models wrap the object in prose, in a ```` ``` ```` fence, or both.
/// Scanning for balance rather than trimming fences handles every
/// combination and also survives a fence the model forgot to close.
fn extract_object(text: &str) -> Option<&str> {
    let bytes = text.as_bytes();
    let start = text.find('{')?;
    let mut depth = 0i32;
    let mut in_string = false;
    let mut escaped = false;
    for (index, &ch) in bytes.iter().enumerate().skip(start) {
        if in_string {
            if escaped {
                escaped = false;
            } else if ch == b'\\' {
                escaped = true;
            } else if ch == b'"' {
                in_string = false;
            }
            continue;
        }
        match ch {
            b'"' => in_string = true,
            b'{' => depth += 1,
            b'}' => {
                depth -= 1;
                if depth == 0 {
                    return text.get(start..=index);
                }
            }
            _ => {}
        }
    }
    None
}

/// Removes `,` that immediately precedes `}` or `]`, outside strings.
fn strip_trailing_commas(text: &str) -> (String, bool) {
    let mut out = String::with_capacity(text.len());
    let mut in_string = false;
    let mut escaped = false;
    let mut changed = false;
    let chars: Vec<char> = text.chars().collect();
    for (index, &ch) in chars.iter().enumerate() {
        if in_string {
            out.push(ch);
            if escaped {
                escaped = false;
            } else if ch == '\\' {
                escaped = true;
            } else if ch == '"' {
                in_string = false;
            }
            continue;
        }
        if ch == '"' {
            in_string = true;
            out.push(ch);
            continue;
        }
        if ch == ',' {
            let next = chars[index + 1..]
                .iter()
                .find(|c| !c.is_whitespace())
                .copied();
            if matches!(next, Some('}') | Some(']')) {
                changed = true;
                continue;
            }
        }
        out.push(ch);
    }
    (out, changed)
}

/// Turns whatever the model said into a [`NotulenJson`].
///
/// Returns an error only when there is no JSON object in the answer at
/// all; every lesser deviation is repaired and recorded in
/// [`ParsedNotulen::perbaikan`].
#[flutter_rust_bridge::frb(ignore)]
pub fn parse(raw: &str) -> Result<ParsedNotulen, TranscribeError> {
    let mut perbaikan: Vec<String> = Vec::new();

    let (without_thinking, had_thinking) = strip_thinking(raw);
    if had_thinking {
        perbaikan.push("blok penalaran <think> dibuang".to_string());
    }

    let object = extract_object(&without_thinking).ok_or_else(|| {
        TranscribeError::Summary(format!(
            "jawaban model tidak memuat objek JSON notulen — {}",
            preview(raw)
        ))
    })?;
    if object.len() + 8 < without_thinking.trim().len() {
        perbaikan.push("teks di luar objek JSON dibuang".to_string());
    }

    let (cleaned, had_trailing) = strip_trailing_commas(object);
    if had_trailing {
        perbaikan.push("koma berlebih sebelum penutup dibuang".to_string());
    }

    let notulen: NotulenJson = serde_json::from_str(&cleaned).map_err(|e| {
        TranscribeError::Summary(format!(
            "objek JSON notulen tidak bisa dibaca: {e} — {}",
            preview(&cleaned)
        ))
    })?;

    let before = notulen.clone();
    let notulen = normalise(notulen);
    if notulen != before {
        perbaikan.push("baris kosong dan spasi berlebih dirapikan".to_string());
    }
    Ok(ParsedNotulen { notulen, perbaikan })
}

/// Trims every string and drops entries that carry no text at all.
fn normalise(mut notulen: NotulenJson) -> NotulenJson {
    fn trim_each(items: &mut Vec<String>) {
        for item in items.iter_mut() {
            *item = item.trim().to_string();
        }
        items.retain(|item| !item.is_empty() && !is_placeholder(item));
    }
    notulen.ringkasan = notulen.ringkasan.trim().to_string();
    trim_each(&mut notulen.peserta);
    trim_each(&mut notulen.agenda);
    trim_each(&mut notulen.pihak);

    for item in notulen.jalannya_rapat.iter_mut() {
        item.pembicara = item.pembicara.trim().to_string();
        item.pokok = item.pokok.trim().to_string();
    }
    notulen.jalannya_rapat.retain(|i| !i.pokok.is_empty());

    for item in notulen.pembahasan.iter_mut() {
        item.topik = item.topik.trim().to_string();
        item.uraian = item.uraian.trim().to_string();
    }
    notulen
        .pembahasan
        .retain(|p| !p.topik.is_empty() || !p.uraian.is_empty());

    for item in notulen.keputusan.iter_mut() {
        item.isi = item.isi.trim().to_string();
    }
    notulen
        .keputusan
        .retain(|k| !k.isi.is_empty() && !is_placeholder(&k.isi));

    for item in notulen.tindak_lanjut.iter_mut() {
        item.tugas = item.tugas.trim().to_string();
        item.penanggung_jawab = blank_placeholder(&item.penanggung_jawab);
        item.tenggat = blank_placeholder(&item.tenggat);
    }
    notulen
        .tindak_lanjut
        .retain(|t| !t.tugas.is_empty() && !is_placeholder(&t.tugas));
    notulen
}

/// The strings a model emits to mean "nothing here".
///
/// Kept as data because each one was observed: left in place they become
/// a keputusan reading "Tidak ada" and a PJ called "-".
fn is_placeholder(text: &str) -> bool {
    const EMPTY: &[&str] = &[
        "-",
        "–",
        "—",
        "n/a",
        "na",
        "null",
        "none",
        "tidak ada",
        "tidak ada.",
        "tidak disebutkan",
        "tidak disebutkan.",
        "belum ada",
        "...",
        "…",
    ];
    let lower = text.trim().to_lowercase();
    EMPTY.contains(&lower.as_str())
}

fn blank_placeholder(text: &str) -> String {
    let trimmed = text.trim();
    if is_placeholder(trimmed) {
        String::new()
    } else {
        trimmed.to_string()
    }
}

fn preview(text: &str) -> String {
    let trimmed = text.trim();
    if trimmed.is_empty() {
        return "(jawaban kosong)".to_string();
    }
    let short: String = trimmed.chars().take(160).collect();
    if trimmed.chars().count() > 160 {
        format!("{short}…")
    } else {
        short
    }
}

// ---------------------------------------------------------------------------
// Structure compliance
// ---------------------------------------------------------------------------

/// Which required sections a parsed notulen actually filled.
#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct StructureReport {
    /// Headings that are required and empty, in Bahasa Indonesia.
    pub bagian_kosong: Vec<String>,
    /// Required sections filled, over required sections total.
    pub terisi: u32,
    pub wajib: u32,
}

impl StructureReport {
    #[flutter_rust_bridge::frb(ignore)]
    pub fn lengkap(&self) -> bool {
        self.bagian_kosong.is_empty()
    }

    /// `0.0..=1.0`, the fraction of required sections present.
    #[flutter_rust_bridge::frb(ignore)]
    pub fn skor(&self) -> f64 {
        if self.wajib == 0 {
            return 1.0;
        }
        f64::from(self.terisi) / f64::from(self.wajib)
    }
}

/// Checks a parsed notulen against its template's required sections.
#[flutter_rust_bridge::frb(ignore)]
pub fn check_structure(notulen: &NotulenJson, template: super::NotulenTemplate) -> StructureReport {
    let mut bagian_kosong = Vec::new();
    let mut terisi = 0u32;
    let required = template.required_sections();
    for section in &required {
        let filled = match section.key {
            "ringkasan" => !notulen.ringkasan.is_empty(),
            "peserta" => !notulen.peserta.is_empty(),
            "agenda" => !notulen.agenda.is_empty(),
            "pihak" => !notulen.pihak.is_empty(),
            "jalannya_rapat" => !notulen.jalannya_rapat.is_empty(),
            "pembahasan" => !notulen.pembahasan.is_empty(),
            "keputusan" => !notulen.keputusan.is_empty(),
            "tindak_lanjut" => !notulen.tindak_lanjut.is_empty(),
            _ => true,
        };
        if filled {
            terisi += 1;
        } else {
            bagian_kosong.push(section.heading.to_string());
        }
    }
    StructureReport {
        bagian_kosong,
        terisi,
        wajib: required.len() as u32,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::notulen::NotulenTemplate;

    const CLEAN: &str = r#"{
  "ringkasan": "Rapat membahas pagu indikatif 2027.",
  "peserta": ["Dr. Siti Aminah", "Budi Santoso"],
  "agenda": ["Evaluasi pagu indikatif"],
  "pembahasan": [{"topik": "Pagu", "uraian": "Pagu naik 4 persen.", "segmen": [3, 4]}],
  "keputusan": [{"isi": "Pagu disetujui.", "segmen": [7]}],
  "tindak_lanjut": [
    {"tugas": "Susun draf RKAKL", "penanggung_jawab": "Budi Santoso", "tenggat": "10 Oktober 2026", "segmen": [9]}
  ]
}"#;

    #[test]
    fn clean_json_parses_with_no_repairs() {
        let parsed = parse(CLEAN).unwrap();
        assert!(
            parsed.perbaikan.is_empty(),
            "unexpected repairs: {:?}",
            parsed.perbaikan
        );
        assert_eq!(
            parsed.notulen.peserta,
            vec!["Dr. Siti Aminah", "Budi Santoso"]
        );
        assert_eq!(parsed.notulen.keputusan[0].segmen, vec![7]);
        assert_eq!(
            parsed.notulen.tindak_lanjut[0].penanggung_jawab,
            "Budi Santoso"
        );
    }

    #[test]
    fn a_fenced_object_with_preamble_and_trailing_prose_is_recovered() {
        let raw = format!("Berikut notulen rapatnya:\n\n```json\n{CLEAN}\n```\n\nSemoga membantu.");
        let parsed = parse(&raw).unwrap();
        assert_eq!(parsed.notulen.keputusan.len(), 1);
        assert!(parsed
            .perbaikan
            .iter()
            .any(|p| p.contains("di luar objek JSON")));
    }

    #[test]
    fn a_reasoning_models_think_block_is_removed_before_parsing() {
        let raw = format!("<think>Saya harus mencari keputusan…</think>\n{CLEAN}");
        let parsed = parse(&raw).unwrap();
        assert_eq!(parsed.notulen.keputusan.len(), 1);
        assert!(parsed.perbaikan.iter().any(|p| p.contains("<think>")));
    }

    #[test]
    fn a_think_block_containing_braces_does_not_swallow_the_answer() {
        // A reasoning model that drafts JSON inside its own reasoning used
        // to have that draft parsed instead of the final answer.
        let raw = format!("<think>mungkin {{\"keputusan\": []}} ?</think>\n{CLEAN}");
        let parsed = parse(&raw).unwrap();
        assert_eq!(parsed.notulen.keputusan.len(), 1, "the final answer wins");
    }

    #[test]
    fn trailing_commas_are_repaired() {
        let raw = r#"{"keputusan": [{"isi": "Pagu disetujui.",}],}"#;
        let parsed = parse(raw).unwrap();
        assert_eq!(parsed.notulen.keputusan[0].isi, "Pagu disetujui.");
        assert!(parsed.perbaikan.iter().any(|p| p.contains("koma berlebih")));
    }

    #[test]
    fn a_comma_inside_a_string_is_not_mistaken_for_a_trailing_one() {
        let raw = r#"{"ringkasan": "Pagu naik, lalu disetujui,"}"#;
        let parsed = parse(raw).unwrap();
        assert_eq!(parsed.notulen.ringkasan, "Pagu naik, lalu disetujui,");
    }

    #[test]
    fn keputusan_given_as_bare_strings_still_parses() {
        // Observed on small models: the array is strings, not objects.
        let raw = r#"{"keputusan": ["Pagu disetujui.", "Rapat lanjutan 15 Oktober."]}"#;
        let notulen = parse(raw).unwrap().notulen;
        assert_eq!(notulen.keputusan.len(), 2);
        assert_eq!(notulen.keputusan[1].isi, "Rapat lanjutan 15 Oktober.");
        assert!(notulen.keputusan[0].segmen.is_empty());
    }

    #[test]
    fn an_inline_citation_marker_is_pulled_out_of_a_string_entry() {
        let raw = r#"{"keputusan": ["Pagu disetujui. [#7,8]"]}"#;
        let notulen = parse(raw).unwrap().notulen;
        assert_eq!(notulen.keputusan[0].isi, "Pagu disetujui.");
        assert_eq!(notulen.keputusan[0].segmen, vec![7, 8]);
    }

    #[test]
    fn a_section_given_as_one_multiline_string_becomes_a_list() {
        let raw = "{\"keputusan\": \"- Pagu disetujui.\\n- Rapat lanjutan 15 Oktober.\"}";
        let notulen = parse(raw).unwrap().notulen;
        assert_eq!(
            notulen
                .keputusan
                .iter()
                .map(|k| k.isi.as_str())
                .collect::<Vec<_>>(),
            vec!["Pagu disetujui.", "Rapat lanjutan 15 Oktober."]
        );
    }

    #[test]
    fn a_single_object_instead_of_an_array_is_accepted() {
        let raw = r#"{"tindak_lanjut": {"tugas": "Kirim surat", "pj": "Rina"}}"#;
        let notulen = parse(raw).unwrap().notulen;
        assert_eq!(notulen.tindak_lanjut.len(), 1);
        assert_eq!(notulen.tindak_lanjut[0].penanggung_jawab, "Rina");
    }

    #[test]
    fn a_risalah_line_with_the_speaker_inline_is_split() {
        let raw = r#"{"jalannya_rapat": ["Pimpinan Rapat: membuka rapat pukul 09.00 WIB"]}"#;
        let notulen = parse(raw).unwrap().notulen;
        assert_eq!(notulen.jalannya_rapat[0].pembicara, "Pimpinan Rapat");
        assert_eq!(
            notulen.jalannya_rapat[0].pokok,
            "membuka rapat pukul 09.00 WIB"
        );
    }

    #[test]
    fn a_risalah_line_with_no_speaker_keeps_its_whole_text() {
        // A sentence that merely contains a colon must not lose its head
        // to the speaker field.
        let raw = r#"{"jalannya_rapat": ["Rapat menyepakati tiga hal berikut: a, b, dan c."]}"#;
        let notulen = parse(raw).unwrap().notulen;
        assert!(notulen.jalannya_rapat[0].pembicara.is_empty());
        assert!(notulen.jalannya_rapat[0]
            .pokok
            .starts_with("Rapat menyepakati"));
    }

    #[test]
    fn renamed_keys_are_accepted_through_aliases() {
        let raw = r#"{
            "acara": ["Pembukaan"],
            "kesimpulan": [{"keputusan": "Anggaran disetujui.", "segmen": "[#5]"}],
            "rencana_aksi": [{"kegiatan": "Kirim surat", "pic": "Rina", "batas_waktu": "Jumat"}]
        }"#;
        let parsed = parse(raw).unwrap();
        assert_eq!(parsed.notulen.agenda, vec!["Pembukaan"]);
        assert_eq!(parsed.notulen.keputusan[0].isi, "Anggaran disetujui.");
        assert_eq!(parsed.notulen.keputusan[0].segmen, vec![5]);
        assert_eq!(parsed.notulen.tindak_lanjut[0].penanggung_jawab, "Rina");
        assert_eq!(parsed.notulen.tindak_lanjut[0].tenggat, "Jumat");
    }

    #[test]
    fn segment_ids_are_read_from_every_shape_a_model_emits() {
        let raw = r#"{"pembahasan": [
            {"uraian": "a", "segmen": [1, 2]},
            {"uraian": "b", "segmen": ["3", "4"]},
            {"uraian": "c", "segmen": "5, 6"},
            {"uraian": "d", "segmen": "[#7,8]"},
            {"uraian": "e", "segmen": 9},
            {"uraian": "f", "segmen": null}
        ]}"#;
        let ids: Vec<Vec<u32>> = parse(raw)
            .unwrap()
            .notulen
            .pembahasan
            .iter()
            .map(|p| p.segmen.clone())
            .collect();
        assert_eq!(
            ids,
            vec![
                vec![1, 2],
                vec![3, 4],
                vec![5, 6],
                vec![7, 8],
                vec![9],
                vec![],
            ]
        );
    }

    #[test]
    fn a_participant_list_given_as_one_line_is_split() {
        let raw = r#"{"peserta": "Dr. Siti Aminah, Budi Santoso"}"#;
        assert_eq!(
            parse(raw).unwrap().notulen.peserta,
            vec!["Dr. Siti Aminah", "Budi Santoso"]
        );
    }

    #[test]
    fn a_name_with_an_academic_title_is_not_split_into_two_people() {
        // "Dr. Siti Aminah, M.Si." is one participant. Splitting on the
        // comma invented a participant called "M.Si." in testing.
        let raw = "{\"peserta\": \"Dr. Siti Aminah, M.Si.\\nBudi Santoso, S.E.\"}";
        assert_eq!(
            parse(raw).unwrap().notulen.peserta,
            vec!["Dr. Siti Aminah, M.Si.", "Budi Santoso, S.E."]
        );
    }

    #[test]
    fn placeholder_entries_are_dropped_not_rendered() {
        let raw = r#"{
            "peserta": ["Tidak disebutkan"],
            "keputusan": [{"isi": "-"}, {"isi": "Pagu disetujui."}],
            "tindak_lanjut": [{"tugas": "Kirim surat", "penanggung_jawab": "-", "tenggat": "N/A"}]
        }"#;
        let notulen = parse(raw).unwrap().notulen;
        assert!(notulen.peserta.is_empty());
        assert_eq!(notulen.keputusan.len(), 1);
        assert_eq!(notulen.keputusan[0].isi, "Pagu disetujui.");
        assert!(notulen.tindak_lanjut[0].penanggung_jawab.is_empty());
        assert!(notulen.tindak_lanjut[0].tenggat.is_empty());
    }

    #[test]
    fn an_answer_with_no_json_at_all_is_an_error_with_a_preview() {
        let err = parse("Maaf, saya tidak bisa membantu.")
            .unwrap_err()
            .to_string();
        assert!(err.contains("tidak memuat objek JSON"), "got: {err}");
        assert!(err.contains("Maaf"), "the error must show what arrived");
    }

    #[test]
    fn an_error_preview_stays_toast_sized() {
        let err = parse(&"x".repeat(20_000)).unwrap_err().to_string();
        assert!(err.len() < 400, "too long: {}", err.len());
    }

    // --- structure check -------------------------------------------------

    #[test]
    fn structure_check_reports_each_missing_required_section() {
        let notulen = parse(r#"{"pembahasan": [{"uraian": "a"}]}"#)
            .unwrap()
            .notulen;
        let report = check_structure(&notulen, NotulenTemplate::Dinas);
        assert!(!report.lengkap());
        assert_eq!(
            report.bagian_kosong,
            vec!["Peserta", "Keputusan", "Tindak Lanjut"]
        );
        assert_eq!(report.terisi, 1);
        assert_eq!(report.wajib, 4);
        assert!((report.skor() - 0.25).abs() < 1e-9);
    }

    #[test]
    fn a_complete_notulen_passes_the_structure_check() {
        let notulen = parse(CLEAN).unwrap().notulen;
        let report = check_structure(&notulen, NotulenTemplate::Dinas);
        assert!(report.lengkap(), "missing: {:?}", report.bagian_kosong);
        assert!((report.skor() - 1.0).abs() < 1e-9);
    }

    #[test]
    fn risalah_demands_the_ordered_record_and_dinas_does_not() {
        let notulen = parse(CLEAN).unwrap().notulen;
        // The same object: complete as a notulen dinas, incomplete as a
        // risalah, because a risalah's body is `jalannya_rapat`.
        assert!(check_structure(&notulen, NotulenTemplate::Dinas).lengkap());
        let risalah = check_structure(&notulen, NotulenTemplate::Risalah);
        assert_eq!(risalah.bagian_kosong, vec!["Jalannya Rapat"]);
    }

    #[test]
    fn berita_acara_demands_para_pihak() {
        let notulen = parse(CLEAN).unwrap().notulen;
        let report = check_structure(&notulen, NotulenTemplate::BeritaAcara);
        assert_eq!(report.bagian_kosong, vec!["Para Pihak"]);
    }
}
