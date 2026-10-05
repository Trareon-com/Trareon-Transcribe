# Skenario Sesi Rekaman — Rapat Kantor Campur ID–EN

**Tujuan:** memperoleh *code-switching* Bahasa Indonesia–Inggris yang **alami
dan intra-kalimat** ("jadi kita perlu *align* dulu sebelum *deploy*"), bukan
dua bahasa yang dibacakan bergantian.

Mengapa ini penting: riset terverifikasi proyek ini mencatat CER Bahasa
Indonesia monolingual 4,10%, naik ke 37,57% pada *code-switching* sintetis,
dan **di atas 80% pada *code-switching* alami**. Set uji sintetis di
`ml/eval/build_sets.py` hanya menyentuh kasus yang paling mudah. Sesi inilah
yang menghasilkan data untuk kasus yang sebenarnya.

---

## Persiapan

**Peserta:** 3–5 orang. Minimal 2 orang yang biasa mencampur istilah Inggris
dalam pekerjaan sehari-hari.

**Sebelum mulai (wajib):**

1. Setiap peserta membaca dan menandatangani `CONSENT.md`.
2. Fasilitator mengucapkan pengingat berikut **di dalam rekaman**:

   > "Sesi ini direkam untuk melatih model transkripsi. Mohon **jangan**
   > menyebut nomor rekening, NIK, data kesehatan, atau rahasia perusahaan.
   > Kalau terucap, bilang saja 'tolong potong' dan kami hapus bagian itu."

3. Catat nomor sesi, tanggal, dan label penutur (Penutur A/B/C) di
   `session_log.tsv`.

**Aturan bicara (penting untuk kualitas data):**

- Bicara **wajar** — saling menyela sedikit itu bagus dan realistis.
- **Jangan** mengoreksi diri agar "lebih rapi". Ucapan spontan yang kami
  butuhkan, bukan pembacaan.
- Jangan membaca dari layar. Topik di bawah adalah pemicu, bukan naskah.
- Pakai istilah Inggris **sealami mungkin** — jangan dipaksa, jangan dihindari.

---

## Aturan teknis perekaman

- **16 kHz atau lebih, mono, WAV atau FLAC.** Jangan MP3 untuk master.
- Satu berkas untuk satu sesi penuh; jangan dipotong-potong saat merekam.
- **Dua kondisi mikrofon**, masing-masing minimal 15 menit, karena beban
  kerja aplikasi ini adalah mikrofon laptop di tengah meja:
  - **Kondisi A — jarak dekat:** satu mikrofon per orang (headset/lavalier).
  - **Kondisi B — medan jauh:** satu mikrofon laptop di tengah meja.
- Jangan pakai *noise suppression* bawaan sistem/aplikasi konferensi. Data
  harus mengandung derau ruangan yang sebenarnya; penapisan dilakukan
  kemudian bila perlu.
- Catat: merek mikrofon, jarak kira-kira, ukuran ruangan, ada/tidak AC
  menyala. Ini masuk ke *data card*.

> **Kantor bersama:** jangan memutar audio uji lewat *speaker* dan jangan
> membuka mikrofon ruangan tanpa izin pemilik. Perekaman sesi ini **adalah**
> pembukaan mikrofon ruangan, jadi lakukan hanya pada sesi terjadwal yang
> sudah disetujui semua peserta.

---

## Blok topik (masing-masing 8–12 menit)

Fasilitator memilih 3–4 blok. Pertanyaan pancingan sengaja mengundang
istilah Inggris tanpa menyuruh memakainya.

### Blok 1 — Anggaran dan laporan kuartalan
*Memancing: angka, tanggal, singkatan, istilah keuangan.*

- Bagaimana realisasi anggaran kuartal ini dibanding *target*?
- Pos mana yang *over budget*, dan apa penyebabnya?
- Berapa *deadline* laporan ke pimpinan, dan siapa *owner*-nya?
- Apa yang berubah dari RKA tahun lalu?

**Diharapkan muncul:** "kuartal 4", "Rp 1,5 miliar", "17 Agustus",
"*cash flow*", "*budget*", "*review*", "*approval*", "Pasal 42".

### Blok 2 — Proyek teknologi yang sedang berjalan
*Memancing: istilah Inggris teknis di tengah kalimat Indonesia.*

- Sampai mana *progress*-nya, dan apa yang jadi *blocker*?
- Apakah sudah di-*deploy* ke *staging* atau masih *local*?
- Siapa yang meng-*handle* *bug* yang kemarin dilaporkan?
- *Timeline*-nya realistis tidak?

**Diharapkan muncul:** "di-*deploy*", "*server*-nya *down*", "*meeting*",
"*follow up*", "*sharing* dulu", "nanti saya *update*".

### Blok 3 — Rapat koordinasi lintas bagian
*Memancing: banyak penutur, saling menyela, interupsi.*

- Bagian mana yang butuh data dari bagian lain, dan kapan?
- Ada tumpang tindih tugas tidak?
- Bagaimana cara koordinasi ke depan — *weekly* atau *monthly*?

**Diharapkan muncul:** interupsi, "izin Pimpinan", "boleh saya tambahkan",
tumpang tindih suara dua penutur.

### Blok 4 — Kepatuhan dan pelindungan data
*Memancing: istilah hukum Indonesia + istilah teknis Inggris.*

- Apa yang berubah setelah PP 33/2026 terbit?
- Data apa saja yang kita simpan, dan berapa lama *retention*-nya?
- Perlu *DPIA* untuk proyek ini atau tidak?
- Siapa yang jadi *DPO*?

**Diharapkan muncul:** "UU PDP", "data pribadi", "*consent*", "*retention*",
"*audit*", "ISO 27001".

### Blok 5 — Keputusan dan tindak lanjut (5 menit, selalu di akhir)
*Memancing: kalimat tindak-lanjut yang jelas — bahan uji untuk fitur
"action items" aplikasi.*

- Jadi keputusannya apa?
- Siapa melakukan apa, paling lambat kapan?

**Diharapkan muncul:** "Pak Budi *follow up* ke vendor paling lambat Jumat",
"saya yang *handle* itu", "kita putuskan minggu depan".

---

## Setelah sesi

1. Simpan audio master: `sesi-<NN>-<kondisi>.wav`.
2. Transkripsikan dengan Trareon, lalu **koreksi manual sampai verbatim**.
   Pedoman transkrip ada di `TRANSCRIPTION_GUIDE.md`.
3. Jalankan ingest:

   ```bash
   uv run python -m record_kit.ingest \
       --audio sesi-01-dekat.wav \
       --transcript sesi-01-dekat.txt \
       --session-id sesi-01-dekat \
       --out ../data/shards/codeswitch
   ```

4. Isi baris di `session_log.tsv` (durasi, jumlah penutur, kondisi mikrofon).
5. Periksa 30 potongan acak dengan lembar periksa yang dihasilkan ingest.
