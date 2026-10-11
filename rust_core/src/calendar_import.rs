//! F22: the inbound half of calendar integration. Export (action item →
//! `.ics`) already exists in `actions.rs`; this is "read a meeting invite
//! the user was sent" — manual `.ics` import, per the brief's own
//! fallback scope (no OAuth, no watch-folder: those are either online or
//! bigger than this pass).
//!
//! Deliberately a small, practical subset of RFC 5545, not a full
//! parser: only `SUMMARY`, `ATTENDEE` and `DTSTART` are read, which is
//! everything the "pra-isi judul + peserta" flow needs.

/// One `VEVENT` block worth of invite data.
#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct CalendarEvent {
    pub summary: String,
    /// Display names from `ATTENDEE;CN=...`. An attendee with no `CN`
    /// falls back to the `mailto:` address rather than being dropped —
    /// a participant list missing a name silently is worse than one with
    /// an email address in it.
    pub attendees: Vec<String>,
    /// Raw `DTSTART` value (e.g. `20261015T090000Z` or
    /// `20261015T090000`), unparsed: the UI only needs to show and
    /// compare it, and every calendar exporter's timezone handling is a
    /// research project of its own.
    pub dtstart: Option<String>,
}

/// Un-folds RFC 5545 line continuations: a line starting with a space or
/// tab is a continuation of the previous line, not a new property. Real
/// calendar exports (Google, Outlook) wrap long `SUMMARY`/`ATTENDEE`
/// lines this way, so skipping this step truncates them.
fn unfold_lines(ics: &str) -> Vec<String> {
    let mut out: Vec<String> = Vec::new();
    for raw in ics.lines() {
        if (raw.starts_with(' ') || raw.starts_with('\t')) && !out.is_empty() {
            let last = out.last_mut().expect("checked non-empty above");
            last.push_str(raw[1..].trim_end_matches('\r'));
        } else {
            out.push(raw.trim_end_matches('\r').to_string());
        }
    }
    out
}

/// The display name out of an `ATTENDEE` line: the `CN=` parameter if
/// present, otherwise the `mailto:` address, otherwise the line's value
/// as-is.
fn attendee_name(line: &str) -> Option<String> {
    let (params_and_prop, value) = line.split_once(':')?;
    for param in params_and_prop.split(';') {
        if let Some(cn) = param.strip_prefix("CN=") {
            let name = cn.trim();
            if !name.is_empty() {
                return Some(name.to_string());
            }
        }
    }
    let address = value.strip_prefix("mailto:").unwrap_or(value).trim();
    if address.is_empty() {
        None
    } else {
        Some(address.to_string())
    }
}

/// Parses every `VEVENT` out of [ics]. Malformed or empty input yields an
/// empty list rather than an error — an invite the user picked by
/// mistake, or a calendar export this subset cannot read, must not block
/// starting a session.
pub fn parse_ics_invite(ics: &str) -> Vec<CalendarEvent> {
    let mut events = Vec::new();
    let mut current: Option<CalendarEvent> = None;

    for line in unfold_lines(ics) {
        if line.eq_ignore_ascii_case("BEGIN:VEVENT") {
            current = Some(CalendarEvent::default());
            continue;
        }
        if line.eq_ignore_ascii_case("END:VEVENT") {
            if let Some(event) = current.take() {
                events.push(event);
            }
            continue;
        }
        let Some(event) = current.as_mut() else {
            continue;
        };

        if let Some(value) = line.strip_prefix("SUMMARY:") {
            event.summary = value.trim().to_string();
        } else if line.to_ascii_uppercase().starts_with("ATTENDEE") {
            if let Some(name) = attendee_name(&line) {
                event.attendees.push(name);
            }
        } else if line.to_ascii_uppercase().starts_with("DTSTART") {
            if let Some((_, value)) = line.split_once(':') {
                event.dtstart = Some(value.trim().to_string());
            }
        }
    }

    events
}

#[cfg(test)]
mod tests {
    use super::*;

    const FIXTURE: &str = "BEGIN:VCALENDAR\r\n\
VERSION:2.0\r\n\
BEGIN:VEVENT\r\n\
SUMMARY:Rapat Anggaran Mingguan\r\n\
DTSTART:20261015T090000Z\r\n\
ATTENDEE;CN=Budi Santoso:mailto:budi@example.com\r\n\
ATTENDEE;CN=Sari Wulandari:mailto:sari@example.com\r\n\
END:VEVENT\r\n\
END:VCALENDAR\r\n";

    #[test]
    fn parses_summary_attendees_and_dtstart() {
        let events = parse_ics_invite(FIXTURE);
        assert_eq!(events.len(), 1);
        let event = &events[0];
        assert_eq!(event.summary, "Rapat Anggaran Mingguan");
        assert_eq!(event.dtstart.as_deref(), Some("20261015T090000Z"));
        assert_eq!(event.attendees, vec!["Budi Santoso", "Sari Wulandari"]);
    }

    #[test]
    fn attendee_with_no_cn_falls_back_to_the_address() {
        let ics = "BEGIN:VEVENT\r\nATTENDEE:mailto:anon@example.com\r\nEND:VEVENT\r\n";
        let events = parse_ics_invite(ics);
        assert_eq!(events[0].attendees, vec!["anon@example.com"]);
    }

    #[test]
    fn folded_summary_line_is_unfolded_before_parsing() {
        // RFC 5545: the leading whitespace on a continuation line is the
        // fold marker itself, not a content character — a real exporter
        // folds mid-word and includes any literal space inside the
        // content before folding, hence the double space here.
        let ics = "BEGIN:VEVENT\r\nSUMMARY:Rapat Anggaran \r\n  Mingguan Tim\r\nEND:VEVENT\r\n";
        let events = parse_ics_invite(ics);
        assert_eq!(events[0].summary, "Rapat Anggaran  Mingguan Tim");
    }

    #[test]
    fn multiple_events_are_each_their_own_entry() {
        let ics = "BEGIN:VEVENT\r\nSUMMARY:Rapat A\r\nEND:VEVENT\r\n\
BEGIN:VEVENT\r\nSUMMARY:Rapat B\r\nEND:VEVENT\r\n";
        let events = parse_ics_invite(ics);
        assert_eq!(events.len(), 2);
        assert_eq!(events[0].summary, "Rapat A");
        assert_eq!(events[1].summary, "Rapat B");
    }

    #[test]
    fn garbage_input_yields_no_events_rather_than_an_error() {
        assert_eq!(parse_ics_invite("bukan ics sama sekali").len(), 0);
        assert_eq!(parse_ics_invite("").len(), 0);
    }

    #[test]
    fn an_event_with_no_summary_still_parses_its_attendees() {
        let ics = "BEGIN:VEVENT\r\nATTENDEE;CN=Budi:mailto:budi@example.com\r\nEND:VEVENT\r\n";
        let events = parse_ics_invite(ics);
        assert_eq!(events[0].summary, "");
        assert_eq!(events[0].attendees, vec!["Budi"]);
    }
}
