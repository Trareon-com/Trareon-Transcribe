//! Structured action items (F6).
//!
//! "Tindak lanjut" is the part of a notulen anyone actually acts on, and
//! it is the part a wall of prose hides. This module turns the model's
//! answer into a checklist with four fields — tugas, penanggung jawab,
//! tenggat, status — that the player can edit and the user can export to
//! a calendar or a spreadsheet.
//!
//! # Parsing is the whole problem
//!
//! The request asks for JSON and most models comply, but "most" is not a
//! contract. A 0.5B model running locally on a notulis's laptop will
//! return the JSON wrapped in a ```json fence, or with a sentence in
//! front of it, or as a Markdown table because that is what the rest of
//! the summary looks like. [`parse_action_items`] tries, in order:
//!
//! 1. the whole body as JSON,
//! 2. the first balanced `[...]` or `{...}` in it,
//! 3. a Markdown table with a tugas-ish first column,
//! 4. bullet lines of the form `- tugas — PJ — tenggat`.
//!
//! Falling all the way through yields an empty list, never an error: a
//! summary that produced no parseable tasks is a summary with no tasks in
//! it, and failing the whole summary over that would be worse.

use serde::{Deserialize, Serialize};

/// Where a task stands. Mirrors what a notulis writes in the column.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
pub enum ActionStatus {
    #[default]
    Belum,
    Berjalan,
    Selesai,
    Dibatalkan,
}

impl ActionStatus {
    #[flutter_rust_bridge::frb(ignore)]
    pub fn label(self) -> &'static str {
        match self {
            ActionStatus::Belum => "Belum mulai",
            ActionStatus::Berjalan => "Sedang berjalan",
            ActionStatus::Selesai => "Selesai",
            ActionStatus::Dibatalkan => "Dibatalkan",
        }
    }

    /// Parses the word a model or a user typed. Unknown → `Belum`, which
    /// is the safe default: marking an unfinished task done loses it.
    #[flutter_rust_bridge::frb(ignore)]
    pub fn parse(raw: &str) -> Self {
        match raw.trim().to_lowercase().as_str() {
            "selesai" | "done" | "completed" | "tuntas" => ActionStatus::Selesai,
            "berjalan" | "in progress" | "in_progress" | "berlangsung" | "proses" => {
                ActionStatus::Berjalan
            }
            "dibatalkan" | "cancelled" | "canceled" | "batal" => ActionStatus::Dibatalkan,
            _ => ActionStatus::Belum,
        }
    }

    /// RFC 5545 `STATUS` for a `VTODO`.
    fn ics_status(self) -> &'static str {
        match self {
            ActionStatus::Belum => "NEEDS-ACTION",
            ActionStatus::Berjalan => "IN-PROCESS",
            ActionStatus::Selesai => "COMPLETED",
            ActionStatus::Dibatalkan => "CANCELLED",
        }
    }
}

/// One row of "Tindak Lanjut".
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ActionItem {
    /// Stable within a session, so the UI can edit a row without
    /// renumbering the rest and the `.ics` UID stays the same across
    /// re-exports.
    pub id: String,
    pub tugas: String,
    #[serde(default)]
    pub penanggung_jawab: String,
    /// As written: "Jumat", "12 Oktober", "akhir bulan". Kept verbatim
    /// because an un-parseable deadline is still information, and
    /// normalising it to a date the model guessed would be worse.
    #[serde(default)]
    pub tenggat: String,
    #[serde(default)]
    pub status: ActionStatus,
    /// Transcript segment indices the model cited, so the checklist can
    /// jump to where the task was agreed (shares F7's machinery).
    #[serde(default)]
    pub segment_ids: Vec<u32>,
}

impl ActionItem {
    #[flutter_rust_bridge::frb(ignore)]
    pub fn new(id: impl Into<String>, tugas: impl Into<String>) -> Self {
        Self {
            id: id.into(),
            tugas: tugas.into(),
            penanggung_jawab: String::new(),
            tenggat: String::new(),
            status: ActionStatus::default(),
            segment_ids: Vec::new(),
        }
    }
}

/// The instruction appended to a summary request when the user wants a
/// checklist. Asks for JSON and names every field, including the segment
/// ids, so the checklist can cite where each task came from.
pub fn action_items_instruction() -> String {
    "Setelah ringkasan, keluarkan DAFTAR TINDAK LANJUT dalam satu blok JSON \
     saja, tanpa penjelasan tambahan, dengan bentuk persis:\n\
     {\"tindak_lanjut\":[{\"tugas\":\"...\",\"penanggung_jawab\":\"...\",\
     \"tenggat\":\"...\",\"status\":\"belum|berjalan|selesai\",\
     \"segmen\":[12,13]}]}\n\
     Aturan: `tugas` wajib dan harus berupa kalimat tindakan. \
     `penanggung_jawab` diisi nama orang yang disebut di rapat, kosongkan \
     bila tidak ada. `tenggat` disalin apa adanya dari rapat (\"Jumat\", \
     \"akhir bulan\"), kosongkan bila tidak disebut. `segmen` berisi nomor \
     segmen transkrip tempat tugas itu disepakati. Jika tidak ada tindak \
     lanjut sama sekali, keluarkan {\"tindak_lanjut\":[]}."
        .to_string()
}

/// Every action item in `raw`, however the model chose to format it.
pub fn parse_action_items(raw: &str) -> Vec<ActionItem> {
    for candidate in json_candidates(raw) {
        let items = from_json(&candidate);
        if !items.is_empty() {
            return finish(items);
        }
    }
    let items = from_markdown(raw);
    finish(items)
}

/// Assigns ids and drops rows with no task in them.
fn finish(items: Vec<ActionItem>) -> Vec<ActionItem> {
    items
        .into_iter()
        .filter(|item| !item.tugas.trim().is_empty())
        .enumerate()
        .map(|(index, mut item)| {
            item.tugas = item.tugas.trim().to_string();
            item.penanggung_jawab = item.penanggung_jawab.trim().to_string();
            item.tenggat = item.tenggat.trim().to_string();
            if item.id.trim().is_empty() {
                item.id = format!("t{}", index + 1);
            }
            item
        })
        .collect()
}

/// Strings worth trying as JSON: the whole body, then whatever is inside
/// a fenced block, then the first balanced array or object.
fn json_candidates(raw: &str) -> Vec<String> {
    let mut out = vec![raw.trim().to_string()];
    for fence in ["```json", "```JSON", "```"] {
        if let Some(start) = raw.find(fence) {
            let after = &raw[start + fence.len()..];
            if let Some(end) = after.find("```") {
                out.push(after[..end].trim().to_string());
            }
        }
    }
    if let Some(block) = balanced(raw, '{', '}') {
        out.push(block);
    }
    if let Some(block) = balanced(raw, '[', ']') {
        out.push(block);
    }
    out
}

/// The first balanced `open…close` run in `text`, ignoring brackets
/// inside JSON strings.
fn balanced(text: &str, open: char, close: char) -> Option<String> {
    let start = text.find(open)?;
    let mut depth = 0usize;
    let mut in_string = false;
    let mut escaped = false;
    for (offset, c) in text[start..].char_indices() {
        if escaped {
            escaped = false;
            continue;
        }
        match c {
            '\\' if in_string => escaped = true,
            '"' => in_string = !in_string,
            _ if in_string => {}
            c if c == open => depth += 1,
            c if c == close => {
                depth -= 1;
                if depth == 0 {
                    return Some(text[start..start + offset + c.len_utf8()].to_string());
                }
            }
            _ => {}
        }
    }
    None
}

/// Accepts both `{"tindak_lanjut":[…]}` and a bare `[…]`, and tolerates
/// the field-name variants models reach for.
fn from_json(raw: &str) -> Vec<ActionItem> {
    let Ok(value) = serde_json::from_str::<serde_json::Value>(raw) else {
        return Vec::new();
    };
    let array = match &value {
        serde_json::Value::Array(items) => items.clone(),
        serde_json::Value::Object(map) => {
            let key = [
                "tindak_lanjut",
                "tindakLanjut",
                "action_items",
                "actions",
                "tasks",
            ]
            .iter()
            .find_map(|key| map.get(*key))
            .cloned();
            match key {
                Some(serde_json::Value::Array(items)) => items,
                _ => return Vec::new(),
            }
        }
        _ => return Vec::new(),
    };
    array.iter().filter_map(item_from_value).collect()
}

fn item_from_value(value: &serde_json::Value) -> Option<ActionItem> {
    let map = value.as_object()?;
    let text = |keys: &[&str]| -> String {
        keys.iter()
            .find_map(|key| map.get(*key).and_then(|v| v.as_str()))
            .unwrap_or_default()
            .to_string()
    };
    let tugas = text(&["tugas", "task", "action", "item", "deskripsi"]);
    if tugas.trim().is_empty() {
        return None;
    }
    let ids = map
        .get("segmen")
        .or_else(|| map.get("segments"))
        .or_else(|| map.get("segment_ids"))
        .and_then(|v| v.as_array())
        .map(|array| {
            array
                .iter()
                .filter_map(|v| v.as_u64())
                .map(|v| v as u32)
                .collect()
        })
        .unwrap_or_default();
    Some(ActionItem {
        id: text(&["id"]),
        tugas,
        penanggung_jawab: text(&[
            "penanggung_jawab",
            "penanggungJawab",
            "pj",
            "owner",
            "assignee",
        ]),
        tenggat: text(&["tenggat", "deadline", "due", "due_date", "batas_waktu"]),
        status: ActionStatus::parse(&text(&["status"])),
        segment_ids: ids,
    })
}

/// Last resort: a Markdown table or a bullet list.
///
/// A local 0.5B model asked for JSON inside a Markdown summary will often
/// produce the table instead, and the user's tasks are no less real for
/// having arrived in the wrong container.
fn from_markdown(raw: &str) -> Vec<ActionItem> {
    let mut out = Vec::new();
    for line in raw.lines() {
        let trimmed = line.trim();
        if trimmed.starts_with('|') && trimmed.ends_with('|') && trimmed.len() > 2 {
            let cells: Vec<&str> = trimmed
                .trim_matches('|')
                .split('|')
                .map(str::trim)
                .collect();
            // Header and separator rows carry no task.
            if cells
                .iter()
                .all(|c| c.chars().all(|ch| ch == '-' || ch == ':' || ch == ' '))
            {
                continue;
            }
            let first = cells.first().copied().unwrap_or_default();
            if is_header_cell(first) {
                continue;
            }
            if first.is_empty() {
                continue;
            }
            out.push(ActionItem {
                id: String::new(),
                tugas: first.to_string(),
                penanggung_jawab: cells.get(1).copied().unwrap_or_default().to_string(),
                tenggat: cells.get(2).copied().unwrap_or_default().to_string(),
                status: ActionStatus::parse(cells.get(3).copied().unwrap_or_default()),
                segment_ids: Vec::new(),
            });
            continue;
        }
        if let Some(rest) = trimmed
            .strip_prefix("- ")
            .or_else(|| trimmed.strip_prefix("* "))
            .or_else(|| strip_numbered(trimmed))
        {
            // "tugas — PJ — tenggat", with an em dash, a hyphen-with-spaces
            // or a semicolon between the fields.
            let parts: Vec<&str> = rest
                .split(['—', ';'])
                .flat_map(|chunk| chunk.split(" - "))
                .map(str::trim)
                .filter(|chunk| !chunk.is_empty())
                .collect();
            let Some(tugas) = parts.first() else { continue };
            out.push(ActionItem {
                id: String::new(),
                tugas: tugas.to_string(),
                penanggung_jawab: strip_label(parts.get(1).copied().unwrap_or_default()),
                tenggat: strip_label(parts.get(2).copied().unwrap_or_default()),
                status: ActionStatus::default(),
                segment_ids: Vec::new(),
            });
        }
    }
    out
}

fn is_header_cell(cell: &str) -> bool {
    matches!(
        cell.to_lowercase().as_str(),
        "tugas" | "task" | "tindak lanjut" | "aksi" | "kegiatan"
    )
}

fn strip_numbered(line: &str) -> Option<&str> {
    let mut chars = line.char_indices();
    let mut digits = 0;
    for (index, c) in chars.by_ref() {
        if c.is_ascii_digit() {
            digits += 1;
            continue;
        }
        if digits > 0 && (c == '.' || c == ')') {
            return line[index + c.len_utf8()..].trim_start().into();
        }
        return None;
    }
    None
}

/// Drops a "PJ:" / "Tenggat:" prefix a model put in front of a value.
fn strip_label(value: &str) -> String {
    let lower = value.to_lowercase();
    for label in [
        "penanggung jawab:",
        "penanggung jawab",
        "pj:",
        "pj",
        "tenggat:",
        "tenggat",
        "deadline:",
        "deadline",
        "batas:",
    ] {
        if let Some(rest) = lower.strip_prefix(label) {
            let offset = value.len() - rest.len();
            return value[offset..]
                .trim_start_matches([':', ' '])
                .trim()
                .to_string();
        }
    }
    value.trim().to_string()
}

/// Removes the machine-readable JSON block from a summary.
///
/// The model is asked to emit both prose and a JSON block; once the
/// block has been parsed into a checklist, leaving it in the rendered
/// summary shows the user the same tasks twice, the second time as
/// unreadable JSON.
pub fn strip_json_block(summary: &str) -> String {
    let mut out = summary.to_string();
    // Fenced first: removing the bare braces would leave an empty fence.
    for fence in ["```json", "```JSON"] {
        while let Some(start) = out.find(fence) {
            let Some(end) = out[start + fence.len()..].find("```") else {
                break;
            };
            let stop = start + fence.len() + end + 3;
            if !out[start..stop].contains("tindak_lanjut") {
                break;
            }
            out.replace_range(start..stop, "");
        }
    }
    while let Some(block) = balanced(&out, '{', '}') {
        if !block.contains("tindak_lanjut") && !block.contains("action_items") {
            break;
        }
        let Some(start) = out.find(&block) else { break };
        out.replace_range(start..start + block.len(), "");
    }
    // Collapse the blank run the removal leaves behind.
    while out.contains("\n\n\n") {
        out = out.replace("\n\n\n", "\n\n");
    }
    out.trim().to_string()
}

// --- Export ----------------------------------------------------------

/// RFC 5545 calendar holding one `VTODO` per item, plus a `VEVENT` for
/// each item whose deadline resolves to a date.
///
/// Both, because calendar clients disagree: Thunderbird and Apple
/// Reminders show `VTODO`, Google Calendar silently ignores it. A
/// follow-up that does not appear in the user's calendar is a follow-up
/// that does not happen.
pub fn to_ics(items: &[ActionItem], calendar_name: &str, today: &str) -> String {
    let mut out = String::from("BEGIN:VCALENDAR\r\nVERSION:2.0\r\n");
    out.push_str("PRODID:-//Trareon Transcribe//Tindak Lanjut//ID\r\n");
    out.push_str("CALSCALE:GREGORIAN\r\n");
    out.push_str(&fold(&format!("X-WR-CALNAME:{}", escape(calendar_name))));
    let stamp = format!("{}T000000Z", compact_date(today).unwrap_or_default());

    for item in items {
        let due = parse_deadline(&item.tenggat, today);
        out.push_str("BEGIN:VTODO\r\n");
        out.push_str(&format!("UID:{}@trareon\r\n", uid(item)));
        out.push_str(&format!("DTSTAMP:{stamp}\r\n"));
        out.push_str(&fold(&format!("SUMMARY:{}", escape(&item.tugas))));
        if !item.penanggung_jawab.is_empty() {
            out.push_str(&fold(&format!(
                "DESCRIPTION:Penanggung jawab: {}",
                escape(&item.penanggung_jawab)
            )));
            out.push_str(&fold(&format!(
                "ATTENDEE;CN={}:mailto:unknown@invalid",
                escape(&item.penanggung_jawab)
            )));
        }
        if let Some(date) = &due {
            out.push_str(&format!("DUE;VALUE=DATE:{date}\r\n"));
        }
        out.push_str(&format!("STATUS:{}\r\n", item.status.ics_status()));
        out.push_str("END:VTODO\r\n");

        if let Some(date) = due {
            out.push_str("BEGIN:VEVENT\r\n");
            out.push_str(&format!("UID:{}-event@trareon\r\n", uid(item)));
            out.push_str(&format!("DTSTAMP:{stamp}\r\n"));
            out.push_str(&format!("DTSTART;VALUE=DATE:{date}\r\n"));
            out.push_str(&fold(&format!("SUMMARY:Tenggat: {}", escape(&item.tugas))));
            if !item.penanggung_jawab.is_empty() {
                out.push_str(&fold(&format!(
                    "DESCRIPTION:Penanggung jawab: {}",
                    escape(&item.penanggung_jawab)
                )));
            }
            out.push_str("END:VEVENT\r\n");
        }
    }
    out.push_str("END:VCALENDAR\r\n");
    out
}

fn uid(item: &ActionItem) -> String {
    let slug: String = item
        .tugas
        .chars()
        .filter(|c| c.is_ascii_alphanumeric())
        .take(16)
        .collect();
    format!("{}-{}", item.id, slug.to_lowercase())
}

/// RFC 5545 line folding at 75 octets, and the CRLF every line needs.
///
/// Without it a long Indonesian task description produces a line no
/// parser will accept, and the export validates nowhere.
fn fold(line: &str) -> String {
    const LIMIT: usize = 73;
    let mut out = String::new();
    let mut current = 0usize;
    for c in line.chars() {
        let width = c.len_utf8();
        if current + width > LIMIT {
            out.push_str("\r\n ");
            current = 1;
        }
        out.push(c);
        current += width;
    }
    out.push_str("\r\n");
    out
}

/// RFC 5545 TEXT escaping: backslash, semicolon, comma, newline.
fn escape(value: &str) -> String {
    value
        .replace('\\', "\\\\")
        .replace(';', "\\;")
        .replace(',', "\\,")
        .replace('\n', "\\n")
        .replace('\r', "")
}

/// Spreadsheet export, same columns as the notulen table.
pub fn to_csv(items: &[ActionItem]) -> String {
    let mut out = String::from("tugas,penanggung_jawab,tenggat,status\n");
    for item in items {
        out.push_str(&format!(
            "{},{},{},{}\n",
            csv_field(&item.tugas),
            csv_field(&item.penanggung_jawab),
            csv_field(&item.tenggat),
            csv_field(item.status.label()),
        ));
    }
    out
}

fn csv_field(value: &str) -> String {
    let cleaned = value.replace(['\r', '\n'], " ");
    if cleaned.contains(',') || cleaned.contains('"') {
        format!("\"{}\"", cleaned.replace('"', "\"\""))
    } else {
        cleaned
    }
}

// --- Indonesian deadline parsing --------------------------------------

const MONTHS: [&str; 12] = [
    "januari",
    "februari",
    "maret",
    "april",
    "mei",
    "juni",
    "juli",
    "agustus",
    "september",
    "oktober",
    "november",
    "desember",
];

const WEEKDAYS: [&str; 7] = [
    "senin", "selasa", "rabu", "kamis", "jumat", "sabtu", "minggu",
];

/// `today` in `YYYY-MM-DD` → compact `YYYYMMDD`.
fn compact_date(today: &str) -> Option<String> {
    let date = chrono::NaiveDate::parse_from_str(today, "%Y-%m-%d").ok()?;
    Some(date.format("%Y%m%d").to_string())
}

/// Resolves an Indonesian deadline to a `YYYYMMDD` date, relative to
/// `today` (`YYYY-MM-DD`).
///
/// Returns `None` for anything it cannot pin down — "akhir bulan",
/// "secepatnya", or an empty string. A `VEVENT` on a guessed date is
/// worse than no `VEVENT`: it puts a wrong commitment in the user's
/// calendar, which they then have to notice and remove.
pub fn parse_deadline(raw: &str, today: &str) -> Option<String> {
    use chrono::{Datelike, Duration, NaiveDate};
    let text = raw.trim().to_lowercase();
    if text.is_empty() {
        return None;
    }
    let today = NaiveDate::parse_from_str(today, "%Y-%m-%d").ok()?;

    // Explicit numeric dates.
    for format in ["%d/%m/%Y", "%d-%m-%Y", "%Y-%m-%d", "%d/%m/%y"] {
        if let Ok(date) = NaiveDate::parse_from_str(text.trim(), format) {
            return Some(date.format("%Y%m%d").to_string());
        }
    }

    // "12 Oktober", "12 Oktober 2026".
    let words: Vec<&str> = text.split_whitespace().collect();
    for (index, word) in words.iter().enumerate() {
        let Some(month) = MONTHS.iter().position(|m| word.starts_with(m)) else {
            continue;
        };
        let day: u32 = index
            .checked_sub(1)
            .and_then(|prev| words.get(prev))
            .and_then(|w| w.trim_matches(|c: char| !c.is_ascii_digit()).parse().ok())?;
        let year: i32 = words
            .get(index + 1)
            .and_then(|w| w.parse().ok())
            .unwrap_or(today.year());
        let candidate = NaiveDate::from_ymd_opt(year, month as u32 + 1, day)?;
        // A bare "12 Oktober" said in November means next year.
        return Some(
            if words.len() <= index + 1 && candidate < today {
                NaiveDate::from_ymd_opt(year + 1, month as u32 + 1, day)?
            } else {
                candidate
            }
            .format("%Y%m%d")
            .to_string(),
        );
    }

    if text.contains("besok") {
        return Some((today + Duration::days(1)).format("%Y%m%d").to_string());
    }
    if text.contains("lusa") {
        return Some((today + Duration::days(2)).format("%Y%m%d").to_string());
    }
    if text.contains("hari ini") {
        return Some(today.format("%Y%m%d").to_string());
    }
    if text.contains("minggu depan") || text.contains("pekan depan") {
        return Some((today + Duration::days(7)).format("%Y%m%d").to_string());
    }

    // A bare weekday means the next one of those, never today.
    if let Some(index) = WEEKDAYS
        .iter()
        .position(|day| text.split_whitespace().any(|word| word.starts_with(day)))
    {
        let target = index as i64;
        let current = today.weekday().num_days_from_monday() as i64;
        let ahead = ((target - current) + 7) % 7;
        let ahead = if ahead == 0 { 7 } else { ahead };
        return Some((today + Duration::days(ahead)).format("%Y%m%d").to_string());
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;

    const TODAY: &str = "2026-10-04"; // a Sunday

    // --- parsing ------------------------------------------------------

    #[test]
    fn clean_json_parses() {
        let raw = r#"{"tindak_lanjut":[
            {"tugas":"Siapkan laporan keuangan","penanggung_jawab":"Budi",
             "tenggat":"Jumat","status":"belum","segmen":[12,13]}]}"#;
        let items = parse_action_items(raw);
        assert_eq!(items.len(), 1);
        assert_eq!(items[0].tugas, "Siapkan laporan keuangan");
        assert_eq!(items[0].penanggung_jawab, "Budi");
        assert_eq!(items[0].tenggat, "Jumat");
        assert_eq!(items[0].status, ActionStatus::Belum);
        assert_eq!(items[0].segment_ids, vec![12, 13]);
        assert_eq!(items[0].id, "t1");
    }

    #[test]
    fn a_bare_array_parses() {
        let items = parse_action_items(r#"[{"tugas":"Kirim undangan"}]"#);
        assert_eq!(items.len(), 1);
        assert_eq!(items[0].tugas, "Kirim undangan");
    }

    #[test]
    fn a_fenced_block_parses() {
        // What a local model actually returns most of the time.
        let raw = "Berikut daftarnya:\n\n```json\n{\"tindak_lanjut\":[{\"tugas\":\
                   \"Revisi anggaran\",\"penanggung_jawab\":\"Siti\"}]}\n```\n\
                   Semoga membantu.";
        let items = parse_action_items(raw);
        assert_eq!(items.len(), 1);
        assert_eq!(items[0].penanggung_jawab, "Siti");
    }

    #[test]
    fn json_buried_in_prose_parses() {
        let raw = "Saya menemukan dua tindak lanjut. \
                   {\"tindak_lanjut\":[{\"tugas\":\"A\"},{\"tugas\":\"B\"}]} \
                   Itu saja.";
        assert_eq!(parse_action_items(raw).len(), 2);
    }

    #[test]
    fn alternative_field_names_are_accepted() {
        let raw = r#"{"action_items":[{"task":"Follow up vendor","owner":"Rina",
                     "due":"12 Oktober","status":"in progress"}]}"#;
        let items = parse_action_items(raw);
        assert_eq!(items[0].tugas, "Follow up vendor");
        assert_eq!(items[0].penanggung_jawab, "Rina");
        assert_eq!(items[0].tenggat, "12 Oktober");
        assert_eq!(items[0].status, ActionStatus::Berjalan);
    }

    #[test]
    fn a_markdown_table_is_the_fallback() {
        let raw = "## Tindak Lanjut\n\n\
                   | Tugas | PJ | Tenggat | Status |\n\
                   |---|---|---|---|\n\
                   | Siapkan laporan | Budi | Jumat | belum |\n\
                   | Kirim undangan | Siti | besok | selesai |\n";
        let items = parse_action_items(raw);
        assert_eq!(items.len(), 2);
        assert_eq!(items[0].tugas, "Siapkan laporan");
        assert_eq!(items[0].penanggung_jawab, "Budi");
        assert_eq!(items[1].status, ActionStatus::Selesai);
    }

    #[test]
    fn a_bullet_list_is_the_last_fallback() {
        let raw = "Tindak lanjut:\n\
                   - Siapkan laporan keuangan — Budi — Jumat\n\
                   - Kirim undangan rapat — Siti — besok\n";
        let items = parse_action_items(raw);
        assert_eq!(items.len(), 2);
        assert_eq!(items[0].tugas, "Siapkan laporan keuangan");
        assert_eq!(items[1].penanggung_jawab, "Siti");
        assert_eq!(items[1].tenggat, "besok");
    }

    #[test]
    fn a_numbered_list_parses() {
        let items = parse_action_items("1. Revisi RAB — Budi — Senin\n2. Kirim ke PPK — Siti\n");
        assert_eq!(items.len(), 2);
        assert_eq!(items[0].tugas, "Revisi RAB");
        assert_eq!(items[1].tugas, "Kirim ke PPK");
    }

    #[test]
    fn labelled_bullet_fields_lose_their_labels() {
        let items = parse_action_items("- Revisi RAB — PJ: Budi — Tenggat: Jumat\n");
        assert_eq!(items[0].penanggung_jawab, "Budi");
        assert_eq!(items[0].tenggat, "Jumat");
    }

    #[test]
    fn no_tasks_is_an_empty_list_not_an_error() {
        assert!(parse_action_items(r#"{"tindak_lanjut":[]}"#).is_empty());
        assert!(parse_action_items("Rapat ini tidak menghasilkan tindak lanjut.").is_empty());
        assert!(parse_action_items("").is_empty());
    }

    #[test]
    fn a_row_with_no_task_is_dropped() {
        let raw = r#"{"tindak_lanjut":[{"tugas":""},{"tugas":"   "},{"tugas":"Nyata"}]}"#;
        let items = parse_action_items(raw);
        assert_eq!(items.len(), 1);
        assert_eq!(items[0].tugas, "Nyata");
        assert_eq!(items[0].id, "t1", "ids renumber after the drop");
    }

    #[test]
    fn a_truncated_response_does_not_panic() {
        for raw in [
            r#"{"tindak_lanjut":[{"tugas":"Sia"#,
            "```json\n{\"tindak",
            "[[[[[",
            "}{",
        ] {
            let _ = parse_action_items(raw);
        }
    }

    #[test]
    fn an_unknown_status_is_not_marked_done() {
        // Guessing "selesai" would quietly close a task nobody did.
        assert_eq!(ActionStatus::parse("entahlah"), ActionStatus::Belum);
        assert_eq!(ActionStatus::parse(""), ActionStatus::Belum);
    }

    // --- deadlines -----------------------------------------------------

    #[test]
    fn numeric_dates_resolve() {
        assert_eq!(
            parse_deadline("12/10/2026", TODAY).as_deref(),
            Some("20261012")
        );
        assert_eq!(
            parse_deadline("2026-12-31", TODAY).as_deref(),
            Some("20261231")
        );
    }

    #[test]
    fn indonesian_month_names_resolve() {
        assert_eq!(
            parse_deadline("12 Oktober 2026", TODAY).as_deref(),
            Some("20261012")
        );
        assert_eq!(
            parse_deadline("sebelum 20 November", TODAY).as_deref(),
            Some("20261120")
        );
    }

    #[test]
    fn relative_days_resolve_against_today() {
        assert_eq!(parse_deadline("besok", TODAY).as_deref(), Some("20261005"));
        assert_eq!(parse_deadline("lusa", TODAY).as_deref(), Some("20261006"));
        assert_eq!(
            parse_deadline("hari ini", TODAY).as_deref(),
            Some("20261004")
        );
        assert_eq!(
            parse_deadline("minggu depan", TODAY).as_deref(),
            Some("20261011")
        );
    }

    #[test]
    fn a_weekday_means_the_next_one() {
        // 2026-10-04 is a Sunday; the next Friday is the 9th.
        assert_eq!(parse_deadline("Jumat", TODAY).as_deref(), Some("20261009"));
        assert_eq!(
            parse_deadline("paling lambat hari Jumat", TODAY).as_deref(),
            Some("20261009")
        );
        // Never "today": a deadline said today means the next one.
        assert_eq!(parse_deadline("Minggu", TODAY).as_deref(), Some("20261011"));
    }

    #[test]
    fn a_vague_deadline_resolves_to_nothing() {
        // A VEVENT on a guessed date is a wrong commitment in the user's
        // calendar that they then have to notice and remove.
        for vague in [
            "",
            "akhir bulan",
            "secepatnya",
            "menunggu konfirmasi",
            "ASAP",
        ] {
            assert_eq!(parse_deadline(vague, TODAY), None, "{vague}");
        }
    }

    // --- ics -----------------------------------------------------------

    fn sample() -> Vec<ActionItem> {
        vec![
            ActionItem {
                id: "t1".into(),
                tugas: "Siapkan laporan keuangan kuartal 4".into(),
                penanggung_jawab: "Budi Santoso".into(),
                tenggat: "Jumat".into(),
                status: ActionStatus::Belum,
                segment_ids: vec![12],
            },
            ActionItem {
                id: "t2".into(),
                tugas: "Kirim undangan; cc: PPK, bagian umum".into(),
                penanggung_jawab: String::new(),
                tenggat: "akhir bulan".into(),
                status: ActionStatus::Berjalan,
                segment_ids: vec![],
            },
        ]
    }

    #[test]
    fn the_calendar_has_the_structure_rfc5545_requires() {
        let ics = to_ics(&sample(), "Rapat Anggaran", TODAY);
        assert!(ics.starts_with("BEGIN:VCALENDAR\r\n"));
        assert!(ics.ends_with("END:VCALENDAR\r\n"));
        assert!(ics.contains("VERSION:2.0\r\n"));
        assert!(ics.contains("PRODID:"));
        assert_eq!(ics.matches("BEGIN:VTODO").count(), 2);
        assert_eq!(ics.matches("END:VTODO").count(), 2);
        // Only the item with a resolvable deadline gets a VEVENT.
        assert_eq!(ics.matches("BEGIN:VEVENT").count(), 1);
        assert!(ics.contains("DUE;VALUE=DATE:20261009"));
        assert!(ics.contains("STATUS:NEEDS-ACTION"));
        assert!(ics.contains("STATUS:IN-PROCESS"));
    }

    #[test]
    fn every_line_ends_crlf_and_fits_the_octet_limit() {
        let ics = to_ics(&sample(), "Rapat Anggaran", TODAY);
        for line in ics.split("\r\n") {
            assert!(line.len() <= 75, "line too long ({}): {line}", line.len());
        }
        assert!(!ics.contains('\n') || ics.matches('\n').count() == ics.matches("\r\n").count());
    }

    #[test]
    fn semicolons_and_commas_in_a_task_are_escaped() {
        let ics = to_ics(&sample(), "Rapat", TODAY);
        assert!(
            ics.contains("Kirim undangan\\; cc: PPK\\, bagian umum"),
            "{ics}"
        );
    }

    #[test]
    fn the_calendar_parses_back_into_the_same_tasks() {
        // The exit criterion: an .ics the app writes must read back as the
        // tasks that went into it.
        let items = sample();
        let ics = to_ics(&items, "Rapat Anggaran", TODAY);
        let parsed = parse_ics_summaries(&ics);
        assert_eq!(
            parsed,
            vec![
                "Siapkan laporan keuangan kuartal 4".to_string(),
                "Kirim undangan; cc: PPK, bagian umum".to_string(),
            ]
        );
    }

    #[test]
    fn an_empty_list_still_produces_a_valid_empty_calendar() {
        let ics = to_ics(&[], "Rapat", TODAY);
        assert!(ics.starts_with("BEGIN:VCALENDAR"));
        assert!(ics.ends_with("END:VCALENDAR\r\n"));
        assert!(!ics.contains("BEGIN:VTODO"));
    }

    /// Minimal RFC 5545 reader: unfolds continuation lines, then returns
    /// each VTODO's SUMMARY with the TEXT escaping undone. Independent of
    /// the writer on purpose — a round trip through the same escaping bug
    /// proves nothing.
    fn parse_ics_summaries(ics: &str) -> Vec<String> {
        let mut unfolded: Vec<String> = Vec::new();
        for line in ics.split("\r\n") {
            if let Some(rest) = line.strip_prefix(' ') {
                if let Some(last) = unfolded.last_mut() {
                    last.push_str(rest);
                    continue;
                }
            }
            unfolded.push(line.to_string());
        }
        let mut out = Vec::new();
        let mut in_todo = false;
        for line in unfolded {
            if line == "BEGIN:VTODO" {
                in_todo = true;
            } else if line == "END:VTODO" {
                in_todo = false;
            } else if in_todo {
                if let Some(value) = line.strip_prefix("SUMMARY:") {
                    out.push(unescape(value));
                }
            }
        }
        out
    }

    fn unescape(value: &str) -> String {
        let mut out = String::new();
        let mut chars = value.chars();
        while let Some(c) = chars.next() {
            if c != '\\' {
                out.push(c);
                continue;
            }
            match chars.next() {
                Some('n') | Some('N') => out.push('\n'),
                Some(other) => out.push(other),
                None => {}
            }
        }
        out
    }

    // --- csv -----------------------------------------------------------

    #[test]
    fn the_csv_has_a_header_and_quotes_what_it_must() {
        let csv = to_csv(&sample());
        let lines: Vec<&str> = csv.lines().collect();
        assert_eq!(lines[0], "tugas,penanggung_jawab,tenggat,status");
        assert_eq!(
            lines[1],
            "Siapkan laporan keuangan kuartal 4,Budi Santoso,Jumat,Belum mulai"
        );
        assert!(
            lines[2].starts_with("\"Kirim undangan; cc: PPK, bagian umum\""),
            "{}",
            lines[2]
        );
    }

    #[test]
    fn an_empty_list_still_has_the_header() {
        assert_eq!(to_csv(&[]), "tugas,penanggung_jawab,tenggat,status\n");
    }

    #[test]
    fn the_json_block_is_stripped_from_the_rendered_summary() {
        let summary = "## Ringkasan\n\nRapat membahas anggaran.\n\n\
                       ```json\n{\"tindak_lanjut\":[{\"tugas\":\"A\"}]}\n```\n";
        let stripped = strip_json_block(summary);
        assert!(stripped.contains("Rapat membahas anggaran."));
        assert!(!stripped.contains("tindak_lanjut"), "{stripped}");
        assert!(!stripped.contains("```"), "{stripped}");
    }

    #[test]
    fn a_bare_json_block_is_stripped_too() {
        let summary = "Ringkasan.\n\n{\"tindak_lanjut\":[{\"tugas\":\"A\"}]}";
        assert_eq!(strip_json_block(summary), "Ringkasan.");
    }

    #[test]
    fn a_summary_with_no_json_is_returned_unchanged() {
        let summary = "## Ringkasan\n\nRapat membahas anggaran { tidak JSON }.";
        assert_eq!(strip_json_block(summary), summary);
    }

    #[test]
    fn the_instruction_names_every_field_and_the_empty_case() {
        let instruction = action_items_instruction();
        for needle in ["tugas", "penanggung_jawab", "tenggat", "status", "segmen"] {
            assert!(instruction.contains(needle), "missing {needle}");
        }
        assert!(instruction.contains("\"tindak_lanjut\":[]"));
    }
}
