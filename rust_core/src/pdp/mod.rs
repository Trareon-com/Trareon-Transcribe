//! Mode Kepatuhan UU PDP (F13).
//!
//! Indonesia's UU No. 27/2022 tentang Pelindungan Data Pribadi puts four
//! duties on whoever records a meeting, and this module is the engine side
//! of each:
//!
//! * **Minimisation at disclosure** — [`redaction`] masks NIK, NPWP, phone
//!   numbers, emails, rekening numbers and named individuals on the way
//!   out, never in the stored transcript.
//! * **Storage limitation** — [`retention`] plans (and, on confirmation,
//!   carries out) deletion of audio and transcripts past their limits,
//!   with separate clocks because the recording is the sensitive part.
//! * **Accountability** — [`audit`] keeps a local, append-only record of
//!   the acts that move data.
//! * **Transparency** — [`consent_notice`] produces the sentence the
//!   notulis pastes into the meeting chat before pressing record.
//!
//! None of it is on by default. A compliance mode that silently deletes
//! recordings or rewrites minutes would be a worse problem than the one it
//! solves, so every destructive step is previewed and confirmed, and
//! redaction only ever runs on a copy bound for export.
//!
//! Nothing in this module reaches the network. `privacy::tests` enforces
//! that: an audit log or retention sweep that phoned home would be an
//! extraordinary thing for a privacy feature to do.

pub mod audit;
pub mod redaction;
pub mod retention;

use serde::{Deserialize, Serialize};

/// Everything "Mode Kepatuhan PDP" switches on, as stored in settings.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct PdpSettings {
    /// Master switch. With it off the app behaves exactly as before.
    #[serde(default)]
    pub enabled: bool,
    #[serde(default)]
    pub redaction: redaction::RedactionConfig,
    #[serde(default)]
    pub retention: retention::RetentionPolicy,
    /// Show the consent reminder before a recording starts.
    #[serde(default)]
    pub consent_reminder: bool,
    /// The reminder text, so an organisation can use its own wording.
    /// Empty falls back to [`DEFAULT_CONSENT_NOTICE`].
    #[serde(default)]
    pub consent_text: String,
}

impl PdpSettings {
    /// Whether redaction should actually run on an export.
    #[flutter_rust_bridge::frb(ignore)]
    pub fn redacts(&self) -> bool {
        self.enabled && !self.redaction.is_noop()
    }
}

/// The default notice, written to be pasted into a Zoom/Meet/Teams chat.
///
/// It says the three things UU PDP asks a notice to say — that recording
/// is happening, what it is for, and where the data goes — in one
/// paragraph nobody will skip, and the "diproses secara lokal" clause is
/// the honest and unusual part: there is no cloud transcription service in
/// this app to disclose.
pub const DEFAULT_CONSENT_NOTICE: &str = "Rapat ini direkam dan ditranskripsi secara lokal di \
perangkat notulis untuk keperluan penyusunan notulen. Rekaman dan transkrip tidak diunggah ke \
layanan pihak ketiga. Jika Anda keberatan, silakan sampaikan sekarang.";

/// The notice for a meeting, with `{judul}` and `{tanggal}` filled in.
///
/// Placeholders rather than string concatenation so an organisation can
/// put them wherever its own wording needs them — or leave them out.
pub fn consent_notice(template: &str, title: &str, date: &str) -> String {
    let text = if template.trim().is_empty() {
        DEFAULT_CONSENT_NOTICE
    } else {
        template
    };
    text.replace("{judul}", title).replace("{tanggal}", date)
}

/// Records that the notice was actually delivered.
///
/// The acknowledgement is the auditable part: the text existing in
/// settings proves nothing about any particular meeting.
pub fn acknowledge_consent(title: &str, note: &str) {
    audit::record(
        audit::AuditEntry::new(audit::AuditAction::ConsentAcknowledged, title.to_string())
            .with_detail(note.to_string()),
    );
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_default_notice_says_what_a_notice_has_to_say() {
        let text = consent_notice("", "Rapat Anggaran", "4 Oktober 2026");
        assert!(text.contains("direkam"), "it must say recording happens");
        assert!(text.contains("lokal"), "it must say where the data goes");
        assert!(text.contains("keberatan"), "it must offer an objection");
    }

    #[test]
    fn a_custom_template_fills_in_the_meeting() {
        let text = consent_notice(
            "Rapat \"{judul}\" pada {tanggal} direkam.",
            "Evaluasi Q4",
            "4 Oktober 2026",
        );
        assert_eq!(text, "Rapat \"Evaluasi Q4\" pada 4 Oktober 2026 direkam.");
    }

    #[test]
    fn a_template_without_placeholders_is_used_verbatim() {
        assert_eq!(
            consent_notice("Rapat ini direkam.", "apa pun", "kapan pun"),
            "Rapat ini direkam."
        );
    }

    #[test]
    fn whitespace_only_falls_back_to_the_default() {
        assert_eq!(consent_notice("   \n ", "a", "b"), DEFAULT_CONSENT_NOTICE);
    }

    #[test]
    fn compliance_mode_is_off_by_default() {
        let settings = PdpSettings::default();
        assert!(!settings.enabled);
        assert!(!settings.redacts());
        assert!(settings.retention.is_noop());
        assert!(!settings.consent_reminder);
    }

    #[test]
    fn redaction_needs_both_the_master_switch_and_a_category() {
        let mut settings = PdpSettings {
            enabled: true,
            ..PdpSettings::default()
        };
        assert!(!settings.redacts(), "no category selected is a no-op");
        settings.redaction.nik = true;
        assert!(settings.redacts());
        settings.enabled = false;
        assert!(!settings.redacts(), "the master switch wins");
    }
}
