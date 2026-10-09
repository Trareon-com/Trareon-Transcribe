# Checklist QA Rilis Beta — `v1.1.0-beta.1`

Checklist manual untuk memverifikasi rilis beta sebelum dibagikan ke
penguji eksternal. Ini **bukan** pengganti gerbang otomatis (`cargo
test`, `flutter test`, CI) — ini lapisan uji manual yang tidak bisa
dicek oleh uji otomatis: tampilan nyata, interaksi platform-native, dan
alur pengguna end-to-end.

Lihat juga: [`README.md`](../README.md#jalur-instalasi-beta-v110-beta1)
untuk langkah instalasi, dan [`docs/SPRINT-REPORTS.md`](SPRINT-REPORTS.md)
untuk riwayat lengkap per item/sprint yang menjadi sumber "Known issues"
di bawah.

## Lingkungan uji

| Platform | Mesin | Status akses |
|----------|-------|---------------|
| Linux | Mesin pengembangan ini (Kali), `DISPLAY=:0` X11 nyata | Tersedia langsung, smoke test rutin per sprint |
| Windows | `win2060` (Windows 11 Pro, RTX 2060, lihat `docs/TESTING-ON-MAC-WINDOWS.md`) | Tersedia via SSH; build, unit test, dan screenshot UI terverifikasi; **capture audio live (WASAPI) butuh izin pemilik — lihat Known issues** |
| macOS | Tidak ada mesin fisik/CI macOS tersedia untuk sesi ini | **Belum pernah diverifikasi manual** sejak Sprint 1 — hanya build CI (bila hijau) yang jadi bukti |

Audio uji standar: `/home/kali/trareon-sprints/rapat_id.mp3` (rapat
Bahasa Indonesia, ~15 detik), diputar **hanya** ke sink virtual
`trareon_silent` (lihat aturan kantor di brief sprint) — tidak pernah ke
speaker/mic asli.

## Yang harus diuji manual per platform

Jalankan daftar ini pada **setiap platform yang tersedia** sebelum
menandai rilis beta siap dibagikan. Tandai ✅/❌/⏭️ (dilewati, sebutkan
alasan) per baris.

### 1. Instalasi & first-run
- [ ] Build dari sumber sesuai langkah di README (`flutter pub get` →
  `cargo build --release --lib` → `flutter build <platform> --release`)
  berhasil tanpa modifikasi langkah.
- [ ] First-run setup wizard (4 langkah: deteksi spek, pilih model,
  setup audio, tes nada) tampil dan bisa diselesaikan.
- [ ] Model bawaan (`base`, `large-v3-turbo-q5`) terdeteksi otomatis
  tanpa perlu diunduh ulang.

### 2. Impor audio & transkripsi file
- [ ] Drag-and-drop file audio (mp3/wav/m4a) ke Library menghasilkan
  transkrip yang masuk akal (Bahasa Indonesia, bukan output kosong/
  acak).
- [ ] Transkripsi CLI (`cargo run --bin transcribe -- --batch ...`)
  menghasilkan berkas yang sama kualitasnya dengan jalur UI.
- [ ] Progressive transcription: hasil cepat (model `base`) tampil dulu,
  lalu diperhalus otomatis oleh `large-v3-turbo-q5` di background.

### 3. Notulen — 4 templat
- [ ] Templat **Lengkap**, **Ringkas**, **Risalah Resmi**, dan **Aksi**
  masing-masing menghasilkan struktur yang sesuai (lihat
  `docs/SPRINT-REPORTS.md` Sprint 5/7 untuk field yang diharapkan per
  templat).
- [ ] Mode **Poin catatan** (notulen tanpa audio, Sprint 8) menghasilkan
  notulen yang koheren dari teks yang ditempel manual.
- [ ] Preset panjang **Ringkas/Sedang/Lengkap** mengubah panjang
  keluaran secara terlihat.
- [ ] Progres pembuatan notulen menunjukkan angka nyata (bukan dummy),
  dan tombol **Coba lagi** muncul serta berfungsi saat LLM gagal
  dihubungi.
- [ ] Konteks dokumen lokal (txt/md/pdf) yang dilampirkan mempengaruhi
  isi notulen yang dihasilkan.
- [ ] *(Butuh Ollama lokal aktif)* Hasil notulen nyata — bukan hanya
  jalur galat — diuji minimal sekali per rilis. **Belum dijalankan di
  sprint ini**, lihat Known issues.

### 4. Ekspor DOCX/PDF
- [ ] Ekspor DOCX dari transkrip dan dari notulen terbuka tanpa korup
  di Microsoft Word/LibreOffice Writer.
- [ ] Ekspor PDF dari transkrip dan notulen terbuka tanpa korup dan
  teks bisa diseleksi (bukan hasil rasterisasi gambar).
- [ ] Metadata siap-SRIKANDI ada pada ekspor (lihat
  `docs/SRIKANDI-EXPORT.md`).
- [ ] Format lain (Markdown, TXT, JSON, SRT, VTT, HTML, WAV) tetap
  reliabel (regresi dari ekspor atomic-write `1.0.0`).

### 5. Mode PDP (pelindungan data pribadi)
- [ ] Mengaktifkan mode PDP di Pengaturan membuat log audit tercatat
  untuk ekspor dan pemakaian konteks dokumen.
- [ ] Prosedur retensi/penghapusan (`docs/compliance/
  PROSEDUR-RETENSI-DAN-PENGHAPUSAN.md`) bisa diikuti langkah-demi-langkah
  pada data sungguhan di mesin uji.
- [ ] Privacy Report menunjukkan nihil aktivitas jaringan selama sesi
  transkripsi aktif (tanpa Ollama) dan hanya panggilan loopback saat
  notulen AI dipakai.

### 6. Riwayat / sesi
- [ ] Sesi lama (dari rilis `1.0.0`) masih bisa dibuka dan diekspor
  tanpa migrasi manual.
- [ ] Pencarian, soft-delete + undo, dan re-export dari Library screen
  berfungsi pada sesi yang sudah ada maupun baru.
- [ ] Recovery banner mendeteksi sesi yang terputus dan menawarkan
  pemulihan.

## Known issues (jujur, dari `docs/SPRINT-REPORTS.md`)

Diurutkan kira-kira dari yang paling berdampak ke penguji beta:

1. **Rendering jendela Windows pernah kosong putih** (dicatat Sprint 4b,
   `docs/SPRINT-REPORTS.md` — "Jendela aplikasi render kosong putih").
   Tidak ada bukti perbaikan atau regresi di sprint-sprint berikutnya
   karena UI Windows tidak disentuh lagi sejak itu. **Perlu
   diverifikasi ulang secara manual sebelum rilis beta dibagikan** —
   lihat checklist butir 1 di atas.
2. **Verifikasi manual macOS belum pernah dilakukan** di sprint mana
   pun pada riwayat proyek ini (tidak ada mesin macOS tersedia untuk
   sesi dev). Hanya build CI yang menjadi bukti tidak-pecahnya kompilasi;
   interaksi UI nyata (first-run wizard, dialog native, dsb.) belum
   divalidasi tangan.
3. **Kit penyetelan halus mesin notulen — NOT DONE** (Sprint 7, item 5).
   Celah target terukur (F1 ekstraksi tindak lanjut ≤ 0,377), tapi
   pelatihan sungguhan menunggu GPU dan korpus asli.
4. **Model Bahasa Indonesia khusus (fine-tune) — PARTIAL** (Sprint 4b,
   item 5). Skrip dan dokumen siap; konversi model dan pengukuran WER
   belum dijalankan. Model bawaan (`base`/`large-v3-turbo-q5`) tetap
   WER 0–4% dan cukup untuk pemakaian beta.
5. **Pilot data risalah resmi (MK/DPR) — 0 jam** (Sprint 6a, item 1).
   Kedua lembaga menolak akses otomatis; benchmark ASR Indonesia saat
   ini berdiri di atas FLEURS (lisensi bebas) + dua set buatan sendiri,
   bukan risalah sidang asli. Perlu keputusan pemilik soal permintaan
   data resmi lewat PPID.
6. **Code-switching Indonesia–Inggris — set uji masih sintetis**
   (Sprint 6a, item 6). Belum ada rekaman asli dengan consent peserta.
7. **Kepatuhan panjang keluaran notulen ("≈N kata") tidak teruji lawan
   LLM sungguhan dalam gerbang otomatis** (Sprint 8). `cargo test` hanya
   memverifikasi instruksi sampai ke prompt dengan angka yang benar;
   verifikasi hasil nyata butuh Ollama aktif dan belum dijalankan sejak
   fitur ini ditambahkan — lihat checklist butir 3 di atas.
8. **Capture audio live Windows (WASAPI mic/loopback) — PERLU IZIN
   PEMILIK**, belum pernah dijalankan di `win2060` karena aturan kantor
   (lihat brief sprint, bagian "OFFICE AUDIO RULES"). Transkripsi file
   impor sudah teruji di Windows; capture live mic/speaker Windows
   menunggu persetujuan eksplisit sebelum bisa diuji.
9. **Dua tugas CI bergantung-host (macOS, golden test)** tidak bisa
   diverifikasi dari mesin Linux dev ini (dicatat berulang di Sprint 7
   putaran CI). CI yang menjadi bukti akhir untuk keduanya.
10. **Tidak ada auto-update** di beta ini — pengecekan update manual via
    Help → Check for Updates (sudah dicatat sebagai batasan `1.0.0`,
    masih berlaku).

## Setelah checklist selesai

Catat hasil (✅/❌/⏭️ per baris, platform mana yang diuji, dan tanggal)
sebagai komentar pada PR rilis atau di `docs/SPRINT-REPORTS.md` sprint
berikutnya — jangan menandai rilis beta "siap dibagikan" sebelum minimal
Linux dan Windows (lingkungan yang tersedia untuk tim ini) lulus bagian
1–4 di atas.
