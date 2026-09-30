# TRAREON TRANSCRIBE — Blueprint Menuju v1.0 Produksi

> 30 Sep 2026 · Sintesis 3 riset:
> 1. **Audit kode & UX** (Claude Code, read-only) → `docs/UX-FEATURE-AUDIT.md` (2.089 baris, bukti file:baris)
> 2. **Riset kompetitor** 17 aplikasi → `docs/COMPETITOR-RESEARCH.md` (semua klaim bersumber URL)
> 3. **Audit visual** build release di Kali (X11) — screenshot semua layar
>
> Klaim kunci audit sudah diverifikasi langsung di kode (✅).

---

## 1. Posisi Pasar — Peluang Kita

**Trareon satu-satunya aplikasi desktop gratis, open-source, 100% offline, dan Indonesia-first** di antara pemain yang diriset.

| Segmen | Pemain | Kelemahan yang bisa kita serang |
|---|---|---|
| Global cloud | Otter, Fireflies, tl;dv, Fathom, Notta | Bot masuk rapat, Bahasa Indonesia lemah/tidak ada, paywall menit/riwayat |
| Global local-first | Granola, Jamie, Krisp, MacWhisper | Berbayar, Mac-centric; Granola tanpa audio playback (keluhan terbesar) |
| Open source | **Meetily**, Anarlog (ex-Hyprnote), Buzz, Vibe | Tidak Indonesia-first, tanpa format notulen resmi; template di Meetily = berbayar (Pro $10/bln) |
| Lokal Indonesia | Notula.ai, Notulensi, Notulin, Transkrip.id, Meeting.ai, Prosa.ai | **Semua cloud/web** (upload audio) → isu UU PDP; berbayar Rp56rb–228rb/bln atau Rp10–20rb/file |

**Kesimpulan strategis:** jual **"notulen rapat resmi tanpa audio keluar dari laptop"** — kepatuhan UU PDP 27/2022 + format Tata Naskah Dinas + gratis. Tidak ada pesaing yang punya kombinasi ini.

**Table stakes 2026** (wajib dimiliki semua app serius) — status Trareon:

| Fitur | Status |
|---|---|
| Capture mic + system tanpa bot | ✅ (Linux baru diperbaiki Round 2) |
| Live transcript | ✅ (lambat di CPU lemah) |
| Ringkasan AI terstruktur | ✅ (baru, PR #6) |
| Action item + penanggung jawab + tenggat | ⚠️ hanya di teks ringkasan, tidak terstruktur |
| Rename speaker → berubah di seluruh transkrip | ⚠️ parsial |
| **Audio playback sinkron dengan transkrip (klik → dengar)** | ❌ |
| Full-text search | ✅ (baru) |
| Ekspor DOCX/PDF | ⚠️ DOCX ada, PDF belum |
| **Kamus istilah (custom vocabulary)** | ❌ |
| Code-switching ID/EN | ⚠️ deteksi per segmen ada, belum dievaluasi |
| Transparansi alur data | ✅ Laporan Privasi — **tapi under-report (P0)** |
| **Rekaman tahan crash** | ❌ **(P0)** |
| Library terorganisir | ⚠️ tanpa folder/tag |

---

## 2. Temuan Kritis (harus beres sebelum rilis)

### P0 — Blocker
| ID | Masalah | Bukti |
|---|---|---|
| UX-01 | **Pemulihan crash tidak memulihkan transkrip.** Snapshot hanya config + jumlah; recovery me-reset `segments: []`. Crash di jam ke-2 = transkrip 2 jam hilang, padahal banner bilang "bisa dipulihkan". | `session_model.dart:190` ✅, `session.rs:186` |
| UX-02 | **Audio hanya di RAM sampai Stop.** `raw_audio: Vec<f32>` tumbuh tanpa batas: ~1,38 GB untuk Rapat Online 3 jam, hilang total bila crash. | `session.rs:159,260` ✅ |
| PR-01 | **Laporan Privasi under-report.** `recordModelDownload` tak pernah dipanggil; update checker menghubungi `raw.githubusercontent.com` tanpa dicatat. Janji utama produk jadi tidak akurat. | `privacy_report_model.dart:40` ✅, `update_checker.dart:88` |
| NEW | **Kegagalan capture senyap.** Keluhan #1 di kategori (Granola). Kita sudah hampir kena di Round 2 (mic merekam 0 detik tanpa peringatan). Perlu indikator "rekaman terkonfirmasi" + peringatan bila satu kanal sunyi lama. | riset kompetitor §5 |

### P1 — Mayor (terverifikasi)
- **Typo nama produk** di layar pertama: "Selamat datang di **Traeon** Transcribe" (`onboarding_screen.dart:43`) ✅
- **Picker "Pengeras Suara" menampilkan daftar mikrofon** — dua-duanya memanggil `listAudioDevices` (`bridge_service.dart:598-602`) ✅
- **Tombol utama mode gelap kontras 2,44:1** (standar WCAG AA 4,5:1) — `foregroundColor: Colors.white` (`app_theme.dart:83`) ✅
- **Palet warna speaker: 7/8 gagal AA** di mode terang (`speaker_color.dart`)
- **Antrean import overflow** setelah ±5 file (`file_upload_zone.dart:156`)
- **Semua penulisan file di Dart non-atomik**, tanpa cek ruang disk (transkrip yang diedit bisa terpotong)
- **Transkrip Ulang menimpa koreksi manual** tanpa backup
- **Tema "Sistem" tidak tersimpan** → jadi "Terang" setelah restart
- **Preflight (`doctor.rs`) & Setup Wizard tidak bisa diakses** dari aplikasi; snackbar menyuruh user "selesaikan Setup Wizard" yang tak bisa dibuka
- **"Lihat Rilis" callback kosong**; update checker hardcode versi `0.1.0` vs pubspec `1.0.0`
- **Performa rapat 3 jam:** seluruh list transkrip rebuild tiap segmen; ingest segmen O(n²); library mem-parse semua sesi saat dibuka; search scan ulang per ketikan
- **Aksesibilitas ≈ nol** di luar upload zone (blocker pengadaan sektor publik)
- **Tanpa infrastruktur i18n** (0 ARB/intl) — semua string hardcode
- **Kode mati:** 4 file + ±20 fungsi FRB tak terpakai (±1.400 baris)

### Temuan audit visual (screenshot)
- **Layar utama terlalu padat:** 9 kontrol sebelum area transkrip; "Mulai" bersaing dengan "Ekspor" (aktif padahal kosong) dan "⚡ Cepat" yang menempel di field judul.
- **4 ikon header tanpa label.** Riwayat sesi (inti produk) tersembunyi di ikon folder — pesaing (Granola, Otter) memakai sidebar sesi permanen.
- **Jargon teknis ke user:** "VAD", "Echo Dedupe", "Progressive Mode", "Auto-detect", "Info". Campur Inggris–Indonesia.
- **Helper GPU kontradiktif:** label "Akselerasi GPU", keterangan "Transkripsi menggunakan CPU saja".
- **Pengaturan satu kolom ±380px**, 70% jendela kosong.
- **Upload Berkas:** tanpa daftar format/batas ukuran, tanpa pilihan bahasa/model, tanpa highlight saat drag-over; 75% layar kosong.
- **Banner pemulihan** tidak menunjukkan isi sesi & tidak bisa dihapus per sesi.
- ✅ Tidak ada overflow di 800×600.

---

## 3. Daftar Pengembangan — Fitur Baru (prioritas nilai × usaha)

| # | Fitur | Nilai | Usaha | Siapa yang punya |
|---|---|---|---|---|
| F1 | **Audio playback sinkron + klik-untuk-lompat** + auto-scroll ke segmen aktif | Kritis | M | Semua pesaing serius (keluhan terbesar Granola) |
| F2 | **Notulen Rapat resmi (DOCX/PDF)** per Tata Naskah Dinas: judul, hari/tanggal, waktu, pimpinan, peserta, pembahasan, keputusan, tindak lanjut; kop opsional | Sangat tinggi | L | Notula/Notulin/Notulensi (berbayar, cloud) |
| F3 | **Kamus istilah** (nama, singkatan instansi) → `initial_prompt` whisper + koreksi pasca | Sangat tinggi | M | Otter, Anarlog, Notulin |
| F4 | **Indikator kesehatan capture** + cek integritas saat Stop | Sangat tinggi | S | Pelajaran dari kegagalan Granola |
| F5 | **Transkrip ulang otomatis** dengan model akurat setelah rapat (background) | Tinggi | M | — (pembeda kita) |
| F6 | **Action item terstruktur** (tugas, PJ, tenggat) → checklist + ekspor `.ics`/CSV | Tinggi | M | Notulin, Jamie, Fathom, tl;dv |
| F7 | **Provenance ringkasan:** tiap poin ringkasan tertaut ke segmen + timestamp audio | Tinggi (kepatuhan notulen) | M | Granola, Meeting.ai |
| F8 | **Template ringkasan yang bisa diedit & disimpan user** | Tinggi | S | Meetily Pro ($10/bln), Granola |
| F9 | **Bookmark/highlight saat rekam** (1 tombol/hotkey) muncul di ringkasan | Tinggi | S | Krisp, tl;dv |
| F10 | **Rename speaker sekali → berubah di semua tempat** + merge speaker + pilih jumlah speaker | Tinggi | M | Whisper Notes |
| F11 | **Catatan pribadi saat rapat** yang digabung AI dengan transkrip ("enhance your notes") | Tinggi | L | Granola (moat utamanya) |
| F12 | **Chat/tanya-jawab ke seluruh arsip rapat** (SQLite FTS + Ollama lokal) | Tinggi | L | Granola, Jamie, Otter, Meeting.ai |
| F13 | **Mode UU PDP:** retensi otomatis, redaksi nama/NIK/HP di ekspor, log audit, notifikasi persetujuan rekam | Sangat tinggi (instansi) | L | Notulin (data residency) |
| F14 | **Layar "Apa jalan di mana"** — transparansi lokal vs jaringan | Sedang | S | Anarlog |
| F15 | **Ringkasan map-reduce** untuk rapat >1 jam (tidak turun kualitas) | Tinggi | M | Kelemahan Meetily |
| F16 | **Deteksi rapat otomatis** (Zoom/Meet/Teams aktif → "Mulai rekam?") + auto-stop saat sunyi | Sedang | M | MacWhisper, Jamie |
| F17 | **Reduksi noise lokal** (RNNoise) sebelum ASR | Sedang–tinggi | M | Krisp, Buzz |
| F18 | **Benchmark WER Indonesia dipublikasikan** + opsi model fine-tune ID | Tinggi (kredibilitas) | M | tl;dv; lokal klaim 95–98% tanpa bukti terbuka |
| F19 | Ekspor PDF (font tertanam) + CSV | Sedang | M | Notula, Transkrip.id |
| F20 | Folder/tag sesi, editor transkrip berbasis keyboard, filter "tinjau segmen ber-confidence rendah" | Sedang | M | — |

**Prinsip bisnis (dari riset):** jangan pernah memasang tembok menit/riwayat/kredit AI di versi gratis — model harga seperti itu sumber kekecewaan utama (Otter, Fireflies, Granola). Pendapatan: donasi (QRIS/Saweria cocok pasar ID), konsultasi & deployment instansi.

---

## 4. Perbaikan UI/UX — Arah Desain

1. **Layout baru: sidebar sesi kiri permanen** (Riwayat · Cari · Folder) + area kerja kanan. Hilangkan ikon folder/dokumen di header.
2. **Satu aksi utama per layar.** Layar kosong → tombol besar "Mulai Rekam" di tengah; "Ekspor" disembunyikan sampai ada transkrip; "⚡ Cepat" pindah ke pengaturan sesi.
3. **Kelompokkan kontrol:** *Sesi* (judul + mode) dan *Perangkat* (pill mic/speaker dengan dropdown perangkat + VU meter live).
4. **Bahasa manusia, bukan jargon:** VAD → "Abaikan jeda sunyi"; Echo Dedupe → "Hapus suara ganda"; Progressive Mode → "Cepat dulu, lalu diperhalus"; Auto-detect → "Deteksi otomatis". Semua string lewat ARB.
5. **Pengaturan 2 panel** (kategori kiri, isi kanan) memakai ruang penuh; helper text dinamis sesuai status.
6. **Upload:** zona drop besar dengan highlight saat drag, daftar format (MP3/M4A/WAV/OGG/FLAC/MP4) & batas, pilih bahasa+model sebelum proses, progres per file + batal/ulang.
7. **Banner pemulihan → dialog daftar** (judul, durasi, jumlah segmen, apa yang bisa dipulihkan) + hapus per sesi.
8. **Design tokens** (spacing/radius/tipografi) + lint larangan warna hardcode (25 literal saat ini); uji kontras otomatis di CI.
9. **Aksesibilitas:** Semantics di 8 layar, live region untuk transkrip baru, target klik 48px, tooltip semua ikon.
10. **Pemutar transkrip:** gelombang audio + klik baris untuk lompat + highlight baris aktif + kecepatan putar.

---

## 5. Roadmap Eksekusi

### Sprint 0 (1–2 hari) — *Quick wins*
Merge PR #6 · typo "Traeon" + CI grep · kontras tombol (1 baris) · picker speaker pakai `list_output_devices` · tema "Sistem" · "Lihat Rilis" + versi dari `package_info_plus` · catat unduhan model & update check di Laporan Privasi.

### Sprint 1 (2 minggu) — **"Tidak ada yang hilang, tidak ada yang bohong"**
Jurnal transkrip JSONL kontinu + recovery sungguhan · audio di-stream ke disk (di balik flag) · penulisan atomik + cek ruang disk · backup sebelum Transkrip Ulang · indikator kesehatan capture (F4) · banner pemulihan baru · antrean import scrollable · palet speaker lolos AA · hapus kode mati.
**Kriteria lulus:** `kill -9` di menit ke-90 → transkrip & audio kembali utuh.

### Sprint 2 (2 minggu) — **"Nyaman untuk rapat 3 jam"**
Fixture sintetis 5.000 segmen sebagai benchmark permanen · perbaikan rebuild list & ingest O(1) · library indeks + search debounce · **F1 audio sinkron** · preflight & wizard bisa diakses · layout sidebar baru.
**Kriteria:** 5.000 segmen scroll 60 fps; library 200 sesi terbuka <500 ms.

### Sprint 3 (2 minggu) — **"Indonesia-first sungguhan"**
**F3 kamus istilah** · **F2 notulen resmi DOCX** · F9 bookmark · F5 transkrip ulang otomatis · F8 template editable · jargon → bahasa manusia · aksesibilitas · signing/notarisasi macOS + `.deb`/AppImage + SHA256 · i18n (jalur paralel).
**Kriteria:** rapat nyata → notulen DOCX format dinas dengan istilah benar dari kamus.

### Sprint 4+ — **Pembeda jangka panjang**
F13 Mode UU PDP · F6 action item + .ics · F7 provenance · F12 chat arsip · F15 ringkasan map-reduce · F10 speaker · F11 catatan pribadi · F16 deteksi rapat · F17 noise reduction · F18 benchmark WER publik + model fine-tune ID · F19 PDF.

---

## 6. Risiko & Catatan
- **Audio ke disk** menyentuh jalur capture yang baru distabilkan di Round 2 → di balik flag satu rilis, path RAM jadi fallback.
- **Template notulen berbeda per instansi** → rilis 2–3 varian + placeholder `{{...}}`; validasi dengan format satu kementerian nyata dulu.
- **Diarization jangan dipromosikan berlebihan** — Hyprnote dikritik publik di HN karena klaim speaker ID yang belum berfungsi.
- **Belum terverifikasi:** rekaman live di Mac & Windows nyata; akurasi pada rekaman rapat asli (baru diuji dengan audio TTS).

## 7. Lampiran
- `docs/UX-FEATURE-AUDIT.md` — audit lengkap per layar, file:baris, 30 item prioritas
- `docs/COMPETITOR-RESEARCH.md` — profil 17 kompetitor, matriks fitur, sumber URL
- `docs/MEETILY-PARITY-REPORT.md` — hasil PR #6 (paritas Meetily + fix Round 2)
