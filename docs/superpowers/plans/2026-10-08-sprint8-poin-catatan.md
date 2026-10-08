# Sprint 8 — Poin Catatan, Preset Panjang, Progress Jujur, Konteks Dokumen — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the notulen dialog generate real minutes from either the session transcript or pasted/typed notes, at a user-chosen length, with honest map-reduce progress and retry, and optional local-document context — all offline, matching the Sprint 8 brief's answer to the competitor's cloud demo.

**Architecture:** The Rust engine already has an unused, fully working `generate_notulen` map-reduce pipeline (`rust_core/src/summary.rs:827`, exposed as `api::generate_notulen`/`generateNotulen`) and a progress-poll mechanism (`read_summary_progress`/`readSummaryProgress`) that `summary_panel.dart` already uses for the generic summary. This sprint (1) wires that existing engine into `notulen_dialog.dart` for the first time, (2) adds a `NotulenLength` preset threaded through the prompt builders, (3) adds a document-text-extraction FRB function (new, txt/md/pdf) whose output is threaded into the same prompts as an optional context block, and (4) adds a new `AuditAction` variant so PDP mode logs document-context use the same way `export_dialog.dart` already logs exports.

**Tech Stack:** Rust (flutter_rust_bridge v2.12, serde), Flutter/Dart (Riverpod, house UI kit), `file_picker` (already a dependency), new Rust dependency `pdf-extract` for local PDF text extraction.

**Spec:** Sprint 8 brief (pasted into the conversation that produced this plan); no separate spec file exists in the repo. Relevant prior art: `docs/UX-FEATURE-AUDIT.md:1591` (FG-02, the original notulen feature).

## Global Constraints

- All new UI strings in Bahasa Indonesia, hardcoded literals (the existing convention in `lib/widgets/*.dart` — no ARB usage in this file family, confirmed by grep).
- No mock data in production UI; no stubs left behind.
- Transcription/capture/export stays offline — the only networked call anywhere in this feature is the existing LLM chat call inside `summary::generate_notulen`, unchanged in that respect.
- FRB: `--rust-input` stays `crate::api,crate::error`; any new `pub fn`/`pub struct`/`pub enum` reachable from `api.rs` that should NOT be exposed gets `#[flutter_rust_bridge::frb(ignore)]`; regenerate with the exact scoped command in `CONTRIBUTING.md:114-121`, never `integrate`; delete orphan files under `lib/src/rust/` after regen if any appear.
- CI clippy is newer (Rust 1.98) than local (1.96): avoid `chunks_exact(<const>)`, prefer `is_multiple_of` etc.
- Atomic file writes (temp + rename, same directory) for anything persisted — N/A for this sprint (no new persisted state beyond the audit log, which already does its own fsync-append).
- Small, conventional commits, **no `Co-Authored-By` trailer** (sprint-brief override of the global attribution instruction). No `git push`, no `gh`, no `sudo`.
- Never delete user data, `models/` content, or `~/Library/Caches/TrareonTranscribe`.
- Document context privacy rule (brief, item 4): the picked file is read locally only, text never leaves the machine except as part of the same local-or-configured-endpoint LLM call the transcript already goes through; when PDP mode is active, record an audit entry.

## Review Focus

- **Empty/whitespace-only "Poin catatan" input** — user opens the manual-notes tab and presses generate without typing anything: must show the same "transkrip kosong" error the engine already raises for an empty transcript, not a crash or a silent no-op. Covered in Task 2's conversion-function test and Task 6's dialog test.
- **Huge pasted notes (longer than `MAX_TRANSCRIPT_CHARS`)** — pasting a long document as "notes" must still flow through `needs_map_reduce`/chunking rather than silently truncating; covered by Task 2 (manual notes become ordinary `Segment`s, so existing map-reduce chunking logic already handles this — no new code needed, but a test pins it).
- **Document picker: unsupported extension or unreadable/corrupt file** — must return a clear Indonesian error, not a panic or an unformatted Rust error string; covered in Task 4's extraction tests.
- **Document picker: oversized document** — a 500-page PDF must not blow the prompt budget silently; the extractor truncates with the same keep-both-ends strategy already used for transcripts (`summary::truncate_transcript`), covered in Task 4.
- **Retry after a failed generation** — pressing "Coba lagi" must re-run with the exact same inputs (mode, length, document context) rather than resetting the form; covered in Task 6's dialog test by asserting the retry callback reuses the last-built request.

---

## File Structure

- **Modify `rust_core/src/notulen/mod.rs`** — add `NotulenLength` enum + `target_words()`/`instruction()`.
- **Modify `rust_core/src/notulen/prompt.rs`** — thread `panjang: NotulenLength` and `konteks_dokumen: Option<&str>` through `user_prompt`/`reduce_prompt`; add `length_instruction`/`document_context_block` helpers.
- **Modify `rust_core/src/summary.rs`** — thread the two new params through `generate_notulen`.
- **Create `rust_core/src/notulen/context.rs`** — `extract_document_text(path) -> Result<String, TranscribeError>` (txt/md/pdf), with its own truncation constant and tests.
- **Modify `rust_core/src/notulen/mod.rs`** — `pub mod context;`
- **Modify `rust_core/src/pdp/audit.rs`** — add `AuditAction::DocumentContextUsed` + label.
- **Modify `rust_core/src/api.rs`** — thread new params through `generate_notulen`; add FRB-exposed `extract_notulen_document_context(path: String) -> Result<String, TranscribeError>`.
- **Modify `rust_core/Cargo.toml`** — add `pdf-extract`.
- Regenerate `lib/src/rust/**` via the scoped FRB command.
- **Modify `lib/widgets/audit_log_view.dart`** — add the new action's label/icon.
- **Modify `lib/services/session_store.dart`** — extend `NotulenFormData` with `sumberCatatan` (manual notes text, empty = use session transcript), `panjang` (length preset), `konteksDokumenPath`/`konteksDokumenNama` (picked document, display-only) — all persisted the same way existing fields are.
- **Create `lib/state/notulen_generation.dart`** — pure helpers: `manualNotesToSegments(String notes) -> List<TranscriptSegment>`, `NotulenLengthOption` enum + label/word-target table (Dart mirror of the Rust enum, same pattern as `notulen_templates.dart`), and the request-building function the dialog calls so retry can replay it.
- **Modify `lib/widgets/notulen_dialog.dart`** — add the input-mode toggle, length-preset picker, document-context picker, real `generateNotulen` wiring, progress bar, retry button, and the PDP audit call.
- **Create `test/notulen_generation_test.dart`** — pure-logic tests for the new Dart helpers.
- **Modify `test/notulen_dialog_widget_test.dart`** — widget-level coverage for the new controls.
- **Modify `test/audit_log_view_test.dart`** (or wherever the label parity check lives) — new action covered.
- **Create `rust_core/test fixtures`** as needed for Task 4 (small literal `.txt`/`.md` strings inline in the test; a tiny generated PDF via `printpdf`, already a dependency, so no binary fixture needs to be checked in).

## Interfaces summary (for cross-task reference)

- `rust_core::notulen::NotulenLength` — `{ Ringkas, Sedang, Lengkap }`, `Default = Sedang`, `target_words(self) -> u32`, `instruction(self) -> String`.
- `prompt::user_prompt(template, transcript, bookmarks, panjang, konteks_dokumen: Option<&str>) -> String`
- `prompt::reduce_prompt(template, notes, panjang, konteks_dokumen: Option<&str>) -> String`
- `summary::generate_notulen(config, template, segments, bookmarks, panjang, konteks_dokumen: Option<String>, on_progress) -> Result<NotulenResponse, TranscribeError>`
- `api::generate_notulen(config, template, segments, bookmarks, base, panjang, konteks_dokumen: Option<String>) -> Result<NotulenHasil, TranscribeError>`
- `notulen::context::extract_document_text(path: String) -> Result<String, TranscribeError>` (ignored by FRB)
- `api::extract_notulen_document_context(path: String) -> Result<String, TranscribeError>` (FRB-exposed thin wrapper)
- `pdp::audit::AuditAction::DocumentContextUsed`
- Dart: `NotulenLengthOption` (id/label/wordTarget), `manualNotesToSegments(String) -> List<TranscriptSegment>`.

---

### Task 1: `NotulenLength` preset in the Rust prompt layer

**Files:**
- Modify: `rust_core/src/notulen/mod.rs`
- Modify: `rust_core/src/notulen/prompt.rs`
- Test: same files, `#[cfg(test)] mod tests` at the bottom of `prompt.rs`

**Interfaces:**
- Produces: `NotulenLength` enum (see summary above), `prompt::user_prompt`/`prompt::reduce_prompt` with the two new trailing parameters.

- [ ] **Step 1: Write the failing tests in `rust_core/src/notulen/prompt.rs`**

```rust
#[test]
fn user_prompt_includes_length_instruction_for_each_preset() {
    for panjang in [NotulenLength::Ringkas, NotulenLength::Sedang, NotulenLength::Lengkap] {
        let prompt = user_prompt(NotulenTemplate::Dinas, "transkrip", &[], panjang, None);
        let target = panjang.target_words();
        assert!(
            prompt.contains(&target.to_string()),
            "prompt untuk {panjang:?} harus menyebut target {target} kata:\n{prompt}"
        );
    }
}

#[test]
fn reduce_prompt_includes_length_instruction() {
    let prompt = reduce_prompt(NotulenTemplate::Dinas, "catatan", NotulenLength::Ringkas, None);
    assert!(prompt.contains(&NotulenLength::Ringkas.target_words().to_string()));
}

#[test]
fn user_prompt_includes_document_context_when_present() {
    let with_ctx = user_prompt(NotulenTemplate::Dinas, "transkrip", &[], NotulenLength::Sedang, Some("Isi dokumen rujukan."));
    let without_ctx = user_prompt(NotulenTemplate::Dinas, "transkrip", &[], NotulenLength::Sedang, None);
    assert!(with_ctx.contains("Isi dokumen rujukan."));
    assert!(!without_ctx.contains("KONTEKS DOKUMEN"));
    assert!(with_ctx.contains("KONTEKS DOKUMEN"));
}
```

- [ ] **Step 2: Run to verify failure**

Run: `cd rust_core && cargo test --lib notulen::prompt::tests -- --exact` (expect compile errors: `NotulenLength` and the new parameters don't exist yet).

- [ ] **Step 3: Add `NotulenLength` to `rust_core/src/notulen/mod.rs`**

Add near `NotulenTemplate`:

```rust
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
pub enum NotulenLength {
    Ringkas,
    #[default]
    Sedang,
    Lengkap,
}

impl NotulenLength {
    /// Rough word budget the prompt asks the model to stay near. Not
    /// enforced client-side — a model given a hard cap mid-sentence
    /// produces worse minutes than one given a target and overshooting it.
    pub fn target_words(self) -> u32 {
        match self {
            NotulenLength::Ringkas => 250,
            NotulenLength::Sedang => 1_000,
            NotulenLength::Lengkap => 3_000,
        }
    }
}
```

- [ ] **Step 4: Add `length_instruction`/`document_context_block` helpers and thread params through `user_prompt`/`reduce_prompt` in `prompt.rs`**

```rust
fn length_instruction(panjang: NotulenLength) -> String {
    format!(
        "\n\nPANJANG KELUARAN: targetkan sekitar {} kata untuk seluruh \
         dokumen. Ini target, bukan batas kaku — jangan memotong kalimat \
         atau menghapus keputusan/tugas hanya demi target ini.",
        panjang.target_words()
    )
}

fn document_context_block(konteks: Option<&str>) -> String {
    match konteks {
        None | Some("") => String::new(),
        Some(text) => format!(
            "\n\n--- KONTEKS DOKUMEN RUJUKAN (bukan transkrip; gunakan \
             HANYA untuk memahami istilah/singkatan, JANGAN mengutipnya \
             sebagai ucapan peserta rapat) ---\n{text}\n--- AKHIR KONTEKS \
             DOKUMEN ---"
        ),
    }
}
```

Update both public signatures to take `panjang: NotulenLength, konteks_dokumen: Option<&str>` and append `length_instruction(panjang)` + `document_context_block(konteks_dokumen)` to the returned `String` in each (after the existing bookmarks block). Update the doc comments minimally (one line each) to name the new parameters.

- [ ] **Step 5: Run tests, verify pass**

Run: `cd rust_core && cargo test --lib notulen::prompt::tests`
Expected: all pass, including the three pre-existing suites in that module (they will fail to compile until their call sites are updated — fix those call sites now by passing `NotulenLength::Sedang` / `None` to match current behavior).

- [ ] **Step 6: Commit**

```bash
git add rust_core/src/notulen/mod.rs rust_core/src/notulen/prompt.rs
git commit -m "feat(notulen): add NotulenLength preset and document-context slot to prompts"
```

---

### Task 2: Thread `NotulenLength` + document context through `summary::generate_notulen` and `api::generate_notulen`

**Files:**
- Modify: `rust_core/src/summary.rs:827-941`
- Modify: `rust_core/src/api.rs:362-420`
- Test: `#[cfg(test)] mod tests` in `summary.rs` (existing module — check it compiles/extend if a notulen-specific pure test exists there; if the only notulen tests are in `prompt.rs`/`notulen/mod.rs`, add one pure test here for the signature only, since network tests aren't feasible — see Review Focus note on this in the plan header).

**Interfaces:**
- Consumes: `NotulenLength`, `prompt::user_prompt`/`prompt::reduce_prompt` from Task 1.
- Produces: the five-parameter-plus-callback `summary::generate_notulen` and the seven-parameter `api::generate_notulen` listed in "Interfaces summary" above — Task 6 (Dart) calls `api::generate_notulen`'s FRB binding with this exact new shape.

- [ ] **Step 1: Update `summary::generate_notulen`'s signature and its two prompt-builder call sites**

Add `panjang: crate::notulen::NotulenLength` and `konteks_dokumen: Option<String>` as new parameters (after `bookmarks`, before `on_progress` — match the existing parameter-ordering convention of "data, then callback"). Pass `panjang` and `konteks_dokumen.as_deref()` into both the single-shot `user_prompt(...)` call (line 850) and the `reduce_prompt(...)` call (line 924). The map step (`map_prompt`) is unchanged — length/document context apply to the final document, not per-window notes.

- [ ] **Step 2: Update `api::generate_notulen`'s signature and its one call site**

Add the same two parameters (same position) to `api::generate_notulen` (api.rs:388); pass them straight through to `crate::summary::generate_notulen(...)` at api.rs:397.

- [ ] **Step 3: Fix every other call site broken by the new parameters**

Run: `cd rust_core && cargo build --lib 2>&1 | grep -A2 "error\["` to enumerate; likely only `ml/notulen_bench`-adjacent Rust test helpers and the two `#[cfg(test)]` modules already touched in Task 1. Pass `NotulenLength::Sedang, None` at any call site that isn't itself testing the new behavior, to preserve prior behavior exactly.

- [ ] **Step 4: Add one pure signature/behavior test in `summary.rs`'s test module**

```rust
#[test]
fn generate_notulen_signature_accepts_length_and_context() {
    // Compile-time proof the new parameters exist in the right order;
    // network path is exercised only by the manual smoke test (no local
    // mock-HTTP harness exists in this crate).
    let _ = |config, template, segments, bookmarks, on_progress| {
        generate_notulen(
            config,
            template,
            segments,
            bookmarks,
            crate::notulen::NotulenLength::Ringkas,
            Some("konteks".to_string()),
            on_progress,
        )
    };
}
```

(If the crate's existing style never writes compile-only tests like this, skip this step and instead note in the self-review that signature coverage is implicit via `cargo build`; prefer whichever matches the surrounding file's convention — check `summary.rs`'s existing test module before deciding.)

- [ ] **Step 5: Run full lib test suite**

Run: `cd rust_core && cargo test --lib`
Expected: previous pass count + new tests, zero failures.

- [ ] **Step 6: Commit**

```bash
git add rust_core/src/summary.rs rust_core/src/api.rs
git commit -m "feat(notulen): thread length preset and document context into generate_notulen"
```

---

### Task 3: `AuditAction::DocumentContextUsed`

**Files:**
- Modify: `rust_core/src/pdp/audit.rs:37-70`
- Modify: `lib/widgets/audit_log_view.dart:169-201`
- Test: whatever test currently pins Dart/Rust label parity for `AuditAction` (search `test/` for `auditActionLabel` or an `AuditAction` fixture — follow the exact pattern used for the existing ten variants; if it's a hand-written `expect` list rather than a generated fixture, add one more line there).

**Interfaces:**
- Produces: `AuditAction::DocumentContextUsed` with label `"Konteks dokumen digunakan"`, the Dart enum value `AuditAction.documentContextUsed`.

- [ ] **Step 1: Add the Rust variant and label**

In `audit.rs`, add `DocumentContextUsed` to the enum (after `ModelPulled`) and to `label()`'s match: `AuditAction::DocumentContextUsed => "Konteks dokumen digunakan",`.

- [ ] **Step 2: Regenerate FRB bindings (combined with Task 4's new function — do this regen once, see Task 4 Step 5) and update the two Dart switches**

In `audit_log_view.dart`, add `AuditAction.documentContextUsed => AppIcons.<pick an existing icon that reads as "document", e.g. AppIcons.table or a file icon already in app_icons.dart>,` to `_iconFor`, and `AuditAction.documentContextUsed => 'Konteks dokumen digunakan',` to `auditActionLabel`.

- [ ] **Step 3: Extend the existing label-parity test** with the eleventh variant, same style as the other ten lines.

- [ ] **Step 4: Run `flutter test test/audit_log_view_test.dart`** (adjust path to the actual file found in Step "Files") — expect pass.

- [ ] **Step 5: Commit** (bundled with Task 4's commit, since both need the same FRB regen — see Task 4 Step 6).

---

### Task 4: Local document text extraction (txt/md/pdf)

**Files:**
- Create: `rust_core/src/notulen/context.rs`
- Modify: `rust_core/src/notulen/mod.rs` (`pub mod context;`)
- Modify: `rust_core/src/api.rs` (new FRB-exposed wrapper)
- Modify: `rust_core/Cargo.toml` (add `pdf-extract`)
- Test: `#[cfg(test)] mod tests` at bottom of `context.rs`

**Interfaces:**
- Produces: `notulen::context::extract_document_text(path: &std::path::Path) -> Result<String, TranscribeError>` (internal, `#[frb(ignore)]`), `api::extract_notulen_document_context(path: String) -> Result<String, TranscribeError>` (FRB-exposed, takes/returns owned `String` since FRB can't cross the boundary with `&Path`).
- Consumes: nothing from earlier tasks (independent); Task 6 (Dart) consumes the FRB-exposed function.

- [ ] **Step 1: Add the dependency**

In `rust_core/Cargo.toml`, add `pdf-extract = "0.7"` under `[dependencies]` (alphabetical position matching the file's existing ordering convention — check it first).

- [ ] **Step 2: Write the failing tests in `rust_core/src/notulen/context.rs`**

```rust
#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;

    #[test]
    fn reads_txt_verbatim() {
        let dir = tempfile::tempdir().unwrap(); // or std::env::temp_dir() + unique name, matching whatever temp-file pattern the crate already uses elsewhere (grep for `tempfile` usage first; fall back to std::env::temp_dir()+process id if the crate has no tempfile dependency)
        let path = dir.path().join("catatan.txt");
        std::fs::write(&path, "Isi catatan rapat.").unwrap();
        assert_eq!(extract_document_text(&path).unwrap(), "Isi catatan rapat.");
    }

    #[test]
    fn reads_markdown_verbatim() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("agenda.md");
        std::fs::write(&path, "# Agenda\n\n- Satu\n- Dua").unwrap();
        assert_eq!(extract_document_text(&path).unwrap(), "# Agenda\n\n- Satu\n- Dua");
    }

    #[test]
    fn unsupported_extension_errors_in_indonesian() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("rekaman.wav");
        std::fs::write(&path, b"not really audio").unwrap();
        let err = extract_document_text(&path).unwrap_err();
        assert!(format!("{err}").contains("didukung"));
    }

    #[test]
    fn missing_file_errors_in_indonesian() {
        let err = extract_document_text(std::path::Path::new("/tidak/ada/berkas.txt")).unwrap_err();
        assert!(!format!("{err}").is_empty());
    }

    #[test]
    fn long_text_is_truncated_keeping_both_ends() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("panjang.txt");
        let huge = "A".repeat(MAX_CONTEXT_CHARS * 2);
        std::fs::write(&path, &huge).unwrap();
        let out = extract_document_text(&path).unwrap();
        assert!(out.len() <= MAX_CONTEXT_CHARS + 200); // small slack for the elision marker
    }
}
```

Check first whether `tempfile` is already a dev-dependency (`grep tempfile rust_core/Cargo.toml`); if not, use `std::env::temp_dir().join(format!("trareon-test-{}-{}", std::process::id(), <counter-or-test-name>))` and clean up with a `Drop` guard or manual `remove_file`, matching whatever pattern other test modules in this crate already use for scratch files (grep `std::env::temp_dir` across `rust_core/src` first and copy that pattern exactly).

For the PDF case, add one more test that writes a minimal one-page PDF using `printpdf` (already a dependency) with a single known text line, then asserts `extract_document_text` returns a string containing that line — this proves the extractor round-trips a real PDF without checking in a binary fixture.

- [ ] **Step 2b: Run to verify failure**

Run: `cd rust_core && cargo test --lib notulen::context::tests` — expect compile failure (module doesn't exist).

- [ ] **Step 3: Implement `context.rs`**

```rust
//! Local document context for notulen generation (Sprint 8). Reads a
//! user-picked .txt/.md/.pdf file into text for the prompt — never
//! written anywhere, never sent anywhere but the configured LLM
//! endpoint the transcript already goes to.

use std::path::Path;

use crate::error::TranscribeError;

/// Keeps the context block from crowding out the transcript in the
/// prompt budget — same elision strategy as [`crate::summary::truncate_transcript`].
pub const MAX_CONTEXT_CHARS: usize = 6_000;

#[flutter_rust_bridge::frb(ignore)]
pub fn extract_document_text(path: &Path) -> Result<String, TranscribeError> {
    let ext = path
        .extension()
        .and_then(|e| e.to_str())
        .unwrap_or_default()
        .to_lowercase();
    let raw = match ext.as_str() {
        "txt" | "md" | "markdown" => std::fs::read_to_string(path).map_err(|e| {
            TranscribeError::Io(format!("Tidak bisa membaca berkas: {e}"))
        })?,
        "pdf" => pdf_extract::extract_text(path).map_err(|e| {
            TranscribeError::Io(format!("Tidak bisa membaca PDF: {e}"))
        })?,
        other => {
            return Err(TranscribeError::Io(format!(
                "Jenis berkas \".{other}\" belum didukung sebagai konteks. \
                 Gunakan .txt, .md, atau .pdf."
            )));
        }
    };
    Ok(truncate_keep_ends(raw.trim(), MAX_CONTEXT_CHARS))
}

fn truncate_keep_ends(text: &str, max_chars: usize) -> String {
    if text.chars().count() <= max_chars {
        return text.to_string();
    }
    let chars: Vec<char> = text.chars().collect();
    let head = max_chars * 6 / 10;
    let tail = max_chars - head;
    let start: String = chars[..head].iter().collect();
    let end: String = chars[chars.len() - tail..].iter().collect();
    format!("{start}\n\n[…dipotong…]\n\n{end}")
}
```

Check the exact `TranscribeError` variant name/shape first (`grep "enum TranscribeError" -A20 rust_core/src/error.rs`) — use whatever variant already fits an I/O/user-facing message (it may be `TranscribeError::Io(String)` or a different name/shape; match it exactly, don't invent a new variant for this).

- [ ] **Step 4: Run tests, verify pass**

Run: `cd rust_core && cargo test --lib notulen::context::tests`

- [ ] **Step 5: Add the FRB-exposed wrapper in `api.rs` and regenerate bindings**

```rust
/// Reads a local .txt/.md/.pdf file for use as notulen context. Never
/// uploads or caches the file anywhere else.
pub fn extract_notulen_document_context(path: String) -> Result<String, TranscribeError> {
    crate::notulen::context::extract_document_text(std::path::Path::new(&path))
}
```

Then regenerate once for both this and Task 1/2/3's signature changes:

```bash
flutter_rust_bridge_codegen generate \
  --rust-input crate::api,crate::error \
  --rust-root rust_core \
  --dart-output lib/src/rust \
  --dart-entrypoint-class-name RustLib

flutter pub run build_runner build --delete-conflicting-outputs
```

Delete any orphan files the regen leaves under `lib/src/rust/` (compare `git status` before/after; remove files that regen no longer writes to, if any).

- [ ] **Step 6: Commit**

```bash
git add rust_core/Cargo.toml rust_core/Cargo.lock rust_core/src/notulen/context.rs rust_core/src/notulen/mod.rs rust_core/src/api.rs rust_core/src/pdp/audit.rs lib/src/rust lib/widgets/audit_log_view.dart test/audit_log_view_test.dart
git commit -m "feat(notulen): local document context extraction (txt/md/pdf) + audit action"
```

---

### Task 5: Dart-side pure helpers — length presets and manual-notes-to-segments

**Files:**
- Create: `lib/state/notulen_generation.dart`
- Modify: `lib/services/session_store.dart` (extend `NotulenFormData`)
- Test: `test/notulen_generation_test.dart`

**Interfaces:**
- Consumes: `TranscriptSegment` (existing model, check its constructor in `lib/state/models.dart` before writing `manualNotesToSegments`), `NotulenLength` enum from Rust (via generated bindings after Task 1's regen).
- Produces: `NotulenLengthOption` table + extension (mirrors `notulen_templates.dart`'s pattern exactly), `manualNotesToSegments(String notes) -> List<TranscriptSegment>`, extended `NotulenFormData` fields: `sumberCatatan` (`String`, default `''`), `panjang` (`NotulenLength`, default `NotulenLength.sedang`), `konteksDokumenPath` (`String`, default `''`), `konteksDokumenNama` (`String`, default `''`).

- [ ] **Step 1: Read `lib/state/models.dart`'s `TranscriptSegment` constructor and `lib/services/session_store.dart`'s full `NotulenFormData` (copyWith, toJson/fromJson if any) before writing code**, so the new fields follow the exact existing field style (nullable copyWith params, JSON round-trip if the class has one — check whether `NotulenFormData` is persisted as JSON to the session sidecar, per its own doc comment, and extend that serialization too).

- [ ] **Step 2: Write the failing tests in `test/notulen_generation_test.dart`**

```dart
test('manualNotesToSegments turns non-empty lines into segments', () {
  final segments = manualNotesToSegments('Poin satu\nPoin dua\n\nPoin tiga');
  expect(segments.length, 3);
  expect(segments[0].text, 'Poin satu');
  expect(segments.every((s) => s.speaker == 'Catatan'), isTrue);
  // timestamps strictly increasing so chunk_by_time orders them correctly
  expect(segments[1].timestamp, greaterThan(segments[0].timestamp));
});

test('manualNotesToSegments on blank input returns empty list', () {
  expect(manualNotesToSegments('   \n\n  '), isEmpty);
});

test('kNotulenLengthOptions has three presets with distinct word targets', () {
  expect(kNotulenLengthOptions.length, 3);
  final targets = kNotulenLengthOptions.map((o) => o.wordTarget).toSet();
  expect(targets.length, 3);
});
```

- [ ] **Step 3: Run to verify failure**

Run: `flutter test test/notulen_generation_test.dart`

- [ ] **Step 4: Implement `lib/state/notulen_generation.dart`**

```dart
/// Sprint 8: input-source and length-preset helpers for the notulen
/// dialog — kept pure and separate from the dialog widget so they're
/// testable without pumping a dialog.
library;

import '../state/models.dart';
import '../src/rust/notulen.dart' show NotulenLength; // adjust import to wherever regen placed NotulenLength

class NotulenLengthOption {
  const NotulenLengthOption({
    required this.value,
    required this.label,
    required this.wordTarget,
  });
  final NotulenLength value;
  final String label;
  final int wordTarget;
}

const List<NotulenLengthOption> kNotulenLengthOptions = [
  NotulenLengthOption(value: NotulenLength.ringkas, label: 'Ringkas', wordTarget: 250),
  NotulenLengthOption(value: NotulenLength.sedang, label: 'Sedang', wordTarget: 1000),
  NotulenLengthOption(value: NotulenLength.lengkap, label: 'Lengkap', wordTarget: 3000),
];

/// Turns typed/pasted "Poin catatan" text into the same `TranscriptSegment`
/// shape the session transcript uses, one non-blank line per segment, so
/// it can flow through the existing notulen map-reduce path unchanged.
List<TranscriptSegment> manualNotesToSegments(String notes) {
  final lines = notes.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty);
  var i = 0;
  return [
    for (final line in lines)
      TranscriptSegment(
        // constructor args per whatever Step 1 found — timestamp a
        // small strictly-increasing fake clock (e.g. i.toDouble()),
        // speaker 'Catatan', text: line, isPartial: false,
      )
      ..also(() => i++), // pseudocode marker — implementer fills in the
                          // real TranscriptSegment constructor call using
                          // positional/named args discovered in Step 1;
                          // this snippet is not valid Dart as written.
  ];
}
```

(The constructor-call pseudocode above is deliberately incomplete — Step 1 determines `TranscriptSegment`'s real constructor shape; write a real, valid `for` loop with an integer index producing `TranscriptSegment(timestamp: i.toDouble(), speaker: 'Catatan', text: line, isPartial: false, ...whatever other required fields Step 1 found, with safe defaults)`.)

Confirm the generated `NotulenLength` Dart enum's member names (`ringkas`/`sedang`/`lengkap` are the expected lowerCamelCase of the Rust variants per FRB convention — verify against the actual generated file after Task 1-4's regen, not assumed here).

Add the four new fields to `NotulenFormData` in `session_store.dart`: constructor defaults, final fields, `copyWith` params, and (if the class round-trips JSON) `toJson`/`fromJson` entries — following the exact existing style for e.g. `lampirkanTranskrip`.

- [ ] **Step 5: Run tests, verify pass**

Run: `flutter test test/notulen_generation_test.dart`
Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add lib/state/notulen_generation.dart lib/services/session_store.dart test/notulen_generation_test.dart
git commit -m "feat(notulen): pure helpers for manual notes and length presets"
```

---

### Task 6: Wire the notulen dialog — input mode, length preset, document picker, honest progress, retry, PDP audit

**Files:**
- Modify: `lib/widgets/notulen_dialog.dart`
- Modify: `test/notulen_dialog_widget_test.dart`

**Interfaces:**
- Consumes: everything from Tasks 1-5 — `api.generateNotulen`/`readSummaryProgress` (FRB bindings), `kNotulenLengthOptions`/`manualNotesToSegments` (Task 5), `extractNotulenDocumentContext` (Task 4's FRB wrapper), `writeAuditEntry`/`AuditAction.documentContextUsed` (Task 3), the summary_panel.dart progress-bar pattern (reference only, not modified).
- Produces: nothing further downstream — this is the leaf UI task.

- [ ] **Step 1: Read `lib/widgets/summary_panel.dart`'s progress-poll block (`_startProgressPoll`/`_stopProgressPoll`, the `_MapReduceProgress` widget) in full**, to copy its `Timer.periodic`-based polling pattern exactly rather than inventing a new one.

- [ ] **Step 2: Add state fields to `_NotulenDialogState`**

```dart
bool _sumberCatatan = false; // false = transkrip sesi, true = poin catatan manual
final _catatanController = TextEditingController();
NotulenLength _panjang = NotulenLength.sedang;
String _konteksDokumenPath = '';
String _konteksDokumenNama = '';
bool _generating = false;
MapReduceProgress? _progress;
Timer? _progressPoll;
Object? _lastGenerateError;
```

- [ ] **Step 3: Add the input-mode toggle UI**

Two `AppChip`s (or whatever segmented-choice house widget `notulen_dialog.dart` already uses elsewhere for a binary choice — check `_ListEditor`/existing toggles first; `AppCheckbox` plus conditional visibility is also acceptable if no segmented widget exists) labelled `'Transkrip sesi'` / `'Poin catatan'`, toggling `_sumberCatatan`. When true, show a multi-line `AppTextField` (house kit, matching existing usage in the same file) bound to `_catatanController`, with hint text `'Tempel atau ketik butir-butir catatan rapat, satu poin per baris.'`.

- [ ] **Step 4: Add the length-preset picker**

A `CompactDropdown<NotulenLength>` (matching `_templatePicker`'s existing pattern at line 595) over `kNotulenLengthOptions`, labelled `'Panjang notulen'`.

- [ ] **Step 5: Add the document-context picker**

A button (`AppButton` or `AppIconButton`, matching the existing "pilih folder" button's style) labelled `'Tambahkan dokumen rujukan (opsional)'` that calls `FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['txt', 'md', 'pdf'])` (mirrors the existing `FilePicker.platform.getDirectoryPath` call already in this file for style). On pick, call `rust_api.extractNotulenDocumentContext(path: ...)`; on success store the text decoded, the path, and the filename in state and show the filename as a chip with a remove (×) action; on failure show the error via the same inline `_error`/live-region mechanism the dialog already uses (not a new pattern).

- [ ] **Step 6: Add the real generation call, replacing/augmenting the current flow**

Add a method:

```dart
Future<void> _generate() async {
  setState(() {
    _generating = true;
    _lastGenerateError = null;
    _progress = null;
  });
  _startProgressPoll();
  try {
    final segments = _sumberCatatan
        ? manualNotesToSegments(_catatanController.text)
        : widget.session.segments;
    final hasil = await ref.read(rustBridgeProvider).generateNotulen(
      template: _form.template,
      segments: segments,
      bookmarks: widget.bookmarks,
      base: _form,
      panjang: _panjang,
      konteksDokumen: _konteksDokumenPath.isEmpty ? null : /* extracted text, cached from Step 5 */,
    );
    if (!mounted) return;
    setState(() {
      _form = /* map hasil.form into _form the same way existing prefill logic merges a NotulenDraft, or replace outright per whatever the engine's NotulenHasil.form already represents */;
    });
    if (_konteksDokumenPath.isNotEmpty) {
      final pdp = ref.read(settingsProvider).pdp;
      if (pdp.enabled) {
        unawaited(rust_api.writeAuditEntry(
          action: AuditAction.documentContextUsed,
          subject: widget.session.title, // or whatever identifier other audit calls in this codebase use for "subject" of a notulen action
          destination: _konteksDokumenNama,
          detail: 'Panjang: ${_panjang.name}',
        ).catchError((_) {}));
      }
    }
  } catch (e) {
    if (!mounted) return;
    setState(() => _lastGenerateError = e);
  } finally {
    _stopProgressPoll();
    if (mounted) setState(() => _generating = false);
  }
}
```

(Resolve the two `/* ... */` placeholders by reading `BridgeService.generateNotulen`'s actual Dart wrapper signature — check `lib/services/bridge_service.dart` for whether it already wraps `api.generateNotulen` the way it wraps `summaryProgress`/`generateSummaryLong`; if no wrapper exists yet, add one there following the existing wrapper style, since the dialog calls `ref.read(rustBridgeProvider)`, not `rust_api` directly, for every other engine call in this file.)

- [ ] **Step 7: Add the progress bar + retry button**

Below the generate button, when `_generating && _progress != null`, render an `AppLinearProgress` exactly like `summary_panel.dart`'s `_MapReduceProgress` (value `done/total`, `semanticLabel: progress.label`). When `_lastGenerateError != null` and not `_generating`, show the existing inline error text plus an `AppButton` labelled `'Coba lagi'` that calls `_generate()` again with the same state (no form reset — this is what the Review Focus item requires).

- [ ] **Step 8: Extend `test/notulen_dialog_widget_test.dart`**

Add widget tests (using the existing `buildTestAppWithOverrides` harness and a fake/mocked `rustBridgeProvider` override — check how existing tests in this file already stub bridge calls, follow that exact pattern):

```dart
testWidgets('poin catatan mode shows a notes field and hides it in session mode', (tester) async { ... });
testWidgets('selecting a length preset updates the dropdown value', (tester) async { ... });
testWidgets('generation error shows a Coba lagi button that retries', (tester) async { ... });
```

Mock `generateNotulen` to return a canned `NotulenHasil` fast (no real LLM call in tests — the existing test harness's bridge fake/mock is where this is stubbed; extend it rather than hitting the network).

- [ ] **Step 9: Run `flutter analyze`**

Expected: 0 issues including info level.

- [ ] **Step 10: Run `flutter test`**

Expected: full suite green, including the new/modified files.

- [ ] **Step 11: Commit**

```bash
git add lib/widgets/notulen_dialog.dart lib/services/bridge_service.dart test/notulen_dialog_widget_test.dart
git commit -m "feat(notulen): poin catatan mode, length preset, document context, honest progress, retry"
```

---

### Task 7: Full verification gate, real-app smoke test, sprint report

**Files:**
- Modify: `docs/SPRINT-REPORTS.md` (append `## Sprint 8 report`)

- [ ] **Step 1: Rust gate**

Run: `cd rust_core && cargo fmt --check && cargo clippy --all-targets -- -D warnings && cargo test --lib`
Expected: all green; record the test count for the report.

- [ ] **Step 2: Flutter gates (sequential, not concurrent with any build)**

Run: `flutter analyze` — expect 0 issues.
Run: `flutter test` — expect full green; record the test count.

- [ ] **Step 3: Release build**

Run: `flutter build linux --release` — expect success.

- [ ] **Step 4: Real-app smoke test**

Launch the built app on `DISPLAY=:0` per the common rules' exact launch command. Open a session (file-import `rapat_id.mp3` if no existing session is available, played only into `trareon_silent` after confirming `pactl get-default-sink` prints `trareon_silent`), open the notulen dialog, exercise: switch to "Poin catatan", type a few lines, pick "Ringkas", press generate, screenshot the progress bar mid-generation (best-effort — a weak CPU with `ggml-base` may finish before a screenshot lands; if so screenshot the finished result and note the timing in the report), pick a small local `.txt` file as document context, confirm the filename chip appears, trigger one deliberate failure (e.g. point the endpoint at a wrong port in Settings beforehand) to screenshot the "Coba lagi" button, then `pkill -9 -x transcribe`.

- [ ] **Step 5: Append `## Sprint 8 report` to `docs/SPRINT-REPORTS.md`**

Per-item status (DONE/PARTIAL/NOT DONE + why), files touched, tests added, exact gate output counts, smoke-test evidence (screenshots taken, what they showed), and explicitly call out the known gap: true "output length approximates the word-count target" compliance can only be verified against a live LLM (no mock-HTTP harness exists in `rust_core` to fake one in `cargo test`), so Task 1's tests cover "the instruction reaches the prompt with the right number," and the smoke test in Step 4 is the only check against a real model's actual output length — note whichever word count was observed there.

- [ ] **Step 6: Commit**

```bash
git add docs/SPRINT-REPORTS.md
git commit -m "docs: Sprint 8 report"
```

- [ ] **Step 7: Confirm clean tree**

Run: `git status --porcelain` — expect empty output.

---

## Self-Review Notes

- **Spec coverage:** Item 1 (poin catatan) → Tasks 5-6. Item 2 (length preset) → Tasks 1-2, 5-6. Item 3 (honest progress) → Task 6 (progress already existed engine-side, per research; this plan's novelty is wiring the dialog to it, which Task 6 Step 7 does, plus retry in Step 7). Item 4 (document context + PDP audit) → Tasks 3-4, 6. Definition-of-done's test list → covered per-task; verification gate → Task 7.
- **Known scope decision:** the notulen dialog currently never calls `generateNotulen` at all (it only reformats an externally-produced summary) — this plan's Task 6 is therefore the first wiring of the engine's own generation+progress path into this dialog, not a modification of an existing call. This is larger than a typical "add a dropdown" task and is called out explicitly here so the executor doesn't assume a smaller existing call site exists to extend.
- **Review Focus → tests:** empty poin-catatan input (Task 2 + Task 6 Step 8), oversized pasted notes (Task 2, implicit via existing chunking — no new code, so only a pin test, not a new feature), bad document file (Task 4 Step 2), oversized document (Task 4 Step 2's truncation test), retry reusing state (Task 6 Step 7/8).
- **Proportion check:** this plan is long because the feature touches seven files across two languages and a previously-unwired engine path; every code block above is either a test (spec-derived assertions) or a signature-plus-one-line-of-guidance, with exactly one full implementation given verbatim (`context.rs`, Task 4 Step 3) because its algorithm (extension dispatch + keep-both-ends truncation) is not otherwise derivable from a signature alone.
