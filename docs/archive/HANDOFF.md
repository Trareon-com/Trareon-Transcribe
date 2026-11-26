# Handoff — Trareon Transcribe

Ditulis 2026-07-25. Baca ini sebelum lanjut supaya agent berikutnya tidak
mengulang discovery dari nol.

## Ringkasan state sekarang

Repo: `https://github.com/Trareon-com/Transcribe`, branch `main`.

Pekerjaan yang sudah dipasang di worktree saat ini:

- CI/release/build matrix sudah diperluas untuk Linux, macOS, dan Windows.
- Flutter UI dan state sudah mencakup wizard, settings, library, transcript
  player, privacy report, usage dashboard, batch upload, dan recovery UI.
- Rust core sudah punya model catalog, resumable download, checksum,
  settings/session handling, export, dan CLI.
- Setup wizard sekarang punya aksi nyata di langkah unduh model yang
  mencatat event ke Privacy Report.

Yang paling baru ditambahkan:

- `lib/screens/setup_wizard_screen.dart`
  - langkah “Unduh Model” sekarang punya tombol `Unduh model`
  - klik tombol akan memanggil `privacyReportProvider.notifier.recordModelDownload(...)`
  - event hanya dicatat sekali per sesi wizard
- `test/setup_wizard_test.dart`
  - ada test baru yang memastikan download model menambah network call
    dan menulis history event di Privacy Report

## Verifikasi terakhir yang sudah hijau

- `flutter test test/setup_wizard_test.dart`
- `git diff --check`

## Catatan penting untuk lanjutan

- Jangan tambahkan trailer `Co-Authored-By: Claude` pada commit apa pun.
- `rust_core/src/model.rs` sudah punya download-with-resume di level Rust,
  tetapi binding/flow Flutter untuk unduh model penuh masih belum disambungkan.
- `Privacy Report` sekarang masih dicatat dari aksi UI yang eksplisit;
  jangan menambah increment otomatis dari jalur lain tanpa alasan kuat.

## Pekerjaan berikutnya yang paling masuk akal

1. Sambungkan aksi unduh model di Flutter ke alur Rust yang benar-benar
   melakukan download/resume/checksum.
2. Tambahkan test untuk memastikan unduhan nyata menaikkan privacy report
   hanya ketika user memicu aksi itu.
3. Lanjutkan wiring pipeline live audio capture jika target berikutnya
   adalah jalur transkripsi penuh.

## Batasan eksternal

- Testing/build Windows belum bisa diverifikasi dari mesin ini.
- Code signing butuh kredensial/sertifikat luar workspace.
- Checklist distribusi dan checksum model resmi masih bergantung pada
  keputusan/asset eksternal.
