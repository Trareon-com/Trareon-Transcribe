# Prosedur Retensi, Penghapusan, dan Pemusnahan Data Rapat

**Trareon Transcribe — Mode Kepatuhan PDP**

> Dokumen prosedur operasional untuk diadopsi (dan disesuaikan) instansi.
> Dasar hukum: UU No. 27 Tahun 2022 **Pasal 42** (penghentian pemrosesan),
> **Pasal 43** (penghapusan), **Pasal 44** (pemusnahan), **Pasal 45**
> (pemberitahuan penghapusan/pemusnahan). Pemetaan lengkap beserta
> kesenjangan ada di `PEMETAAN-UU-PDP-27-2022.md` §4.

---

## 1. Hal pertama yang harus dipahami

**Trareon tidak menghapus apa pun secara otomatis.**

Ini keputusan desain yang disengaja, bukan fitur yang belum selesai.
Alasannya tercatat di `rust_core/src/pdp/retention.rs:11-15`: penghapusan
otomatis yang baru diketahui pengguna setelah terjadi tidak dapat
dibedakan dari kehilangan data. `retention::plan` murni dan tidak menyentuh
berkas apa pun; `retention::apply` hanya berjalan setelah pengguna melihat
daftar lengkap dan menekan konfirmasi.

Konsekuensi kepatuhan yang harus diterima instansi:

> Menetapkan angka retensi di Pengaturan **tidak** membuat data terhapus.
> Angka itu hanya membuat Trareon bisa menghitung apa yang sudah melewati
> batas. **Eksekusi adalah tugas manusia yang harus dijadwalkan dan
> ditugaskan**, sama seperti pemusnahan arsip fisik.

Instansi yang melewatkan hal ini akan mengira dirinya patuh Pasal 42–44
sementara seluruh rekaman rapat sejak hari pertama masih utuh di cakram.

---

## 2. Menetapkan kebijakan retensi

### 2.1 Dua jam yang terpisah

Trareon menyimpan dua batas yang berbeda (`RetentionPolicy` di
`rust_core/src/pdp/retention.rs`):

| Batas | Yang dihapus | Nilai `0` berarti |
|-------|--------------|-------------------|
| `audio_days` — **Hapus audio setelah** | Hanya berkas audio di dalam direktori sesi. Transkrip, notulen, dan metadata **tetap** | Simpan selamanya (nilai baku) |
| `transcript_days` — **Hapus transkrip (seluruh sesi) setelah** | **Seluruh** direktori sesi, termasuk audio yang mungkin masih ada | Simpan selamanya (nilai baku) |

Pemisahan ini ada karena rekamanlah artefak yang sensitif — ia membawa
suara, percakapan latar, dan apa pun yang terucap sebelum seseorang sadar
sedang direkam. Satu tombol "hapus sesi setelah N hari" akan memaksa
pengguna memilih antara menyimpan notulen dan menyimpan rekaman; itu bukan
pilihan yang diminta undang-undang.

### 2.2 Angka yang disarankan

Trareon **tidak** memasang angka baku apa pun (keduanya `0` = simpan
selamanya) dan tidak boleh: masa retensi arsip adalah kewenangan instansi,
diatur Jadwal Retensi Arsip (JRA) masing-masing.

Sebagai titik awal diskusi, bukan rekomendasi hukum:

| Jenis rapat | Audio | Transkrip + notulen | Pertimbangan |
|-------------|-------|---------------------|--------------|
| Rapat koordinasi internal rutin | 7–14 hari | Sesuai JRA | Audio hanya perlu sampai notulen disahkan |
| Rapat dengan pihak eksternal | 14–30 hari | Sesuai JRA | Potensi sengketa isi notulen lebih besar |
| Sidang/pemeriksaan (etik, kas, audit) | ⬜ **[ISI INSTANSI]** | Sesuai JRA | Mungkin terikat ketentuan lain; **periksa dulu** sebelum menetapkan |
| Rapat yang membahas data pribadi spesifik (kesehatan, keuangan pribadi, data anak) | **sependek mungkin** | Sesuai JRA, dengan penyamaran wajib saat ekspor | Pemicu DPIA Pasal 34 |

**Aturan yang tidak boleh dilanggar:** jangan pernah menetapkan
`transcript_days` yang lebih pendek daripada masa retensi arsip naskah
dinas dalam JRA instansi. Notulen yang sah adalah arsip; menghapusnya
lebih cepat dari JRA adalah pelanggaran kearsipan, bukan kepatuhan PDP.
Bila ragu, setel `transcript_days = 0` (simpan selamanya) dan serahkan
penghapusan transkrip ke prosedur kearsipan instansi — tetapi tetap setel
`audio_days`, karena rekaman audio biasanya **bukan** arsip yang wajib
disimpan.

### 2.3 Cara menetapkan di aplikasi

1. Pengaturan → **Kepatuhan PDP**
2. Aktifkan **Aktifkan Mode Kepatuhan PDP**
3. Bagian **Retensi data**:
   - **Hapus audio setelah** → pilih jumlah hari
   - **Hapus transkrip (seluruh sesi) setelah** → pilih jumlah hari atau
     "Simpan selamanya"

Pengaturan tersimpan dengan penulisan atomik. Catat angka yang dipilih di
DPIA (`TEMPLAT-DPIA.md` §5) dan di teks pemberitahuan perekaman (Lampiran A
`TEMPLAT-DPIA.md` — unsur "Masa penyimpanan" Pasal 21).

---

## 3. Prosedur eksekusi retensi (berkala)

**Frekuensi:** ⬜ **[ISI INSTANSI]** — disarankan **bulanan**, dan selalu
pada tanggal yang sama agar mudah diaudit.
**Penanggung jawab:** ⬜ **[ISI INSTANSI]** — notulis utama atau admin TI.
**Bukti pelaksanaan:** entri `RetentionApplied` di `audit.jsonl`, plus
catatan di buku kendali instansi.

### Langkah

| # | Langkah | Catatan |
|---|---------|---------|
| 1 | Buka Pengaturan → Kepatuhan PDP → Retensi data | |
| 2 | Tekan **"Lihat & jalankan sekarang"** | Memanggil `retention::plan` — **tidak menghapus apa pun** |
| 3 | Baca daftar yang muncul di dialog **"Jalankan kebijakan retensi?"** | Setiap baris menyebut judul sesi, umur dalam hari, dan apakah yang dihapus "Seluruh sesi" atau "Audio saja" |
| 4 | **Periksa setiap baris.** Hentikan bila ada sesi yang tidak seharusnya terhapus (mis. masih dipakai dalam sengketa, audit berjalan, atau permintaan subjek data yang belum selesai) | Dialog menyatakan "Tindakan ini tidak bisa dibatalkan" — memang begitu |
| 5 | Bila daftar sudah benar, tekan **"Hapus sekarang"** | Memanggil `retention::apply` |
| 6 | Catat di buku kendali instansi: tanggal, pelaksana, jumlah sesi audio-saja, jumlah sesi penuh | Log audit mencatat `AudioDeleted`, `TranscriptDeleted`, `RetentionApplied` |
| 7 | **Jalankan §5 (pemusnahan)** untuk salinan di luar jangkauan aplikasi | Langkah yang paling sering dilupakan |

### Bila ada sesi yang harus dikecualikan

Trareon tidak memiliki penanda "tahan dari retensi" per sesi. Yang
tersedia:

- **Cara yang disarankan:** naikkan sementara angka retensi agar sesi itu
  belum melewati batas, jalankan retensi, lalu turunkan kembali. Catat
  pengecualian dan alasannya di buku kendali.
- **Alternatif:** pindahkan direktori sesi ke lokasi lain sebelum
  menjalankan retensi, lalu kembalikan. Lebih berisiko — direktori sesi
  dapat rusak bila dipindahkan saat aplikasi berjalan. Tutup aplikasi
  lebih dulu.

Ini kesenjangan produk yang diakui; kandidat backlog adalah penanda
"tahan" (*legal hold*) per sesi.

---

## 4. Penghapusan atas permintaan subjek data (Pasal 8, 43)

**Tenggat:** UU PDP memberi batas **3x24 jam** untuk beberapa kewajiban
(Pasal 30, 32, 40, 41). Tetapkan tenggat internal yang lebih pendek.

| # | Langkah | Penanggung jawab |
|---|---------|------------------|
| 1 | Terima permintaan lewat titik kontak resmi; catat tanggal dan jam terima | ⬜ **[ISI INSTANSI]** |
| 2 | Verifikasi identitas pemohon | ⬜ **[ISI INSTANSI]** |
| 3 | Tentukan apakah permintaan dapat dipenuhi. **Pertimbangkan:** notulen yang sudah disahkan adalah arsip naskah dinas; permintaan penghapusan tidak otomatis mengalahkan kewajiban kearsipan. Pasal 15 UU PDP memuat pembatasan hak tertentu | Unit hukum / PPDP |
| 4 | Bila **tidak** dapat dipenuhi: sampaikan penolakan beserta alasannya secara tertulis | ⬜ **[ISI INSTANSI]** |
| 5 | Bila **dapat** dipenuhi sebagian — lazimnya: **hapus rekaman audio, pertahankan notulen** | ⬜ **[ISI INSTANSI]** |
| 6 | Identifikasi sesi yang terkait. Gunakan pencarian Pustaka; bila nama pemohon muncul di transkrip, pencarian teks menemukannya | Notulis |
| 7 | Jalankan penghapusan: hapus sesi dari Pustaka, atau turunkan sementara `audio_days` lalu jalankan retensi untuk menghapus audio saja | Notulis |
| 8 | **Jalankan §5** — cadangan dan berkas ekspor yang sudah diedarkan | Admin TI |
| 9 | Sampaikan pemberitahuan pelaksanaan kepada pemohon (Pasal 45). **Tidak ada pemberitahuan otomatis di aplikasi** | ⬜ **[ISI INSTANSI]** |
| 10 | Arsipkan bukti: entri log audit, berkas permintaan, berkas pemberitahuan | ⬜ **[ISI INSTANSI]** |

### Bila yang diminta adalah penundaan/pembatasan (Pasal 11, 41)

Trareon **tidak memiliki** status "pemrosesan ditangguhkan" per sesi
(kesenjangan G-3). Prosedur pengganti:

1. Hapus berkas audio sesi tersebut (penyempitan terbesar yang tersedia).
2. Tandai sesi di buku kendali instansi sebagai "pemrosesan dibatasi".
3. Instruksikan agar notulen sesi itu tidak diedarkan lebih lanjut dan
   tidak dipakai untuk pembuatan ringkasan/notulen baru.
4. Kecualikan sesi dari eksekusi retensi sampai pembatasan dicabut (§3).

---

## 5. Pemusnahan: apa yang **tidak** dilakukan Trareon (Pasal 44)

Ini bagian terpenting dokumen ini, dan yang paling mudah disalahpahami.

Trareon menghapus berkas lewat panggilan penghapusan berkas sistem operasi
biasa. Ia **tidak**:

- menimpa blok cakram (tidak ada *secure erase*, tidak ada *shredding*);
- menjangkau salinan di cadangan;
- menjangkau salinan di berkas jurnal berkas-sistem, *shadow copy*,
  *snapshot*, atau blok yang belum di-TRIM pada SSD;
- menjangkau berkas ekspor yang sudah diedarkan lewat email, folder
  bersama, atau flash disk;
- menjangkau salinan di keranjang sampah OS (bila OS mengarahkan
  penghapusan ke sana);
- menghapus entri `audit.jsonl` tentang sesi itu — **dan itu disengaja**.

### 5.1 Daftar lokasi yang harus diperiksa instansi

| # | Lokasi | Cara memeriksa | Penanggung jawab |
|---|--------|----------------|------------------|
| 1 | Keranjang sampah OS | Kosongkan setelah menjalankan retensi | Notulis |
| 2 | **Cadangan** (Time Machine, File History, agen cadangan korporat) yang mencakup direktori konfigurasi Trareon | Lihat `ALUR-DATA.md` §4 untuk jalur per OS. **Pilih satu:** (a) kecualikan direktori itu dari cadangan, atau (b) masukkan ke prosedur penghapusan selektif cadangan, atau (c) terima dan dokumentasikan bahwa retensi efektif = retensi cadangan | **Admin TI** |
| 3 | Berkas ekspor di folder Unduhan/Dokumen notulis | Instruksi tetap: simpan ekspor hanya di lokasi yang dikelola | Notulis |
| 4 | Berkas ekspor yang sudah diedarkan (email, folder bersama, SRIKANDI) | Setelah terdistribusi, di luar jangkauan teknis. **Prosedur, bukan teknologi**: batasi distribusi, pakai penyamaran saat ekspor, catat penerima | ⬜ **[ISI INSTANSI]** |
| 5 | *Shadow copy* / *snapshot* volume (Windows VSS, snapshot LVM/btrfs) | Admin TI memeriksa dan menghapus snapshot yang memuat periode terkait, bila kebijakan menghendaki | Admin TI |
| 6 | Cakram laptop yang dialihkan atau dibuang | Hapus aman seluruh cakram (*crypto-erase* bila terenkripsi penuh, atau penghapusan aman sesuai kebijakan) — A.7.14 ISO/IEC 27001 | Admin TI |

### 5.2 Kendali pengganti yang membuat ini dapat dikelola

Satu kendali membuat seluruh masalah pemusnahan jauh lebih ringan:
**enkripsi cakram penuh**. Pada laptop dengan LUKS/BitLocker/FileVault
aktif, blok yang sudah dibebaskan tetap berupa teks tersandi, dan
penghapusan kunci (*crypto-erase*) memusnahkan seluruh cakram secara
efektif dalam satu tindakan.

Karena itu enkripsi cakram penuh bukan saran di paket ini melainkan
**prasyarat penggelaran** (butir 1 Lampiran B `TEMPLAT-DPIA.md`, kewajiban
K-1 di `PEMETAAN-UU-PDP-27-2022.md`).

---

## 6. Penanganan permintaan akses dan salinan (Pasal 7, 32)

| # | Langkah |
|---|---------|
| 1 | Terima dan catat permintaan; verifikasi identitas |
| 2 | Temukan sesi terkait lewat pencarian Pustaka |
| 3 | Pertimbangkan **penyamaran**: salinan yang diberikan kepada satu subjek data tidak boleh mengungkap data pribadi peserta lain. Aktifkan Mode Kepatuhan PDP dan tambahkan nama peserta lain ke daftar "Nama yang disamarkan" sebelum mengekspor |
| 4 | Ekspor ke format yang diminta (Markdown, DOCX, PDF, TXT). Ekspor tercatat `SessionExported` di log audit |
| 5 | Periksa hasil ekspor sebelum menyerahkan — penyamaran bekerja pada pola; nama yang tidak dimasukkan ke daftar tidak akan tersamarkan |
| 6 | Serahkan; catat tanggal, penerima, dan isi yang diserahkan |

Catatan penting: **`pdp/redaction.rs` menyamarkan pola, bukan makna.** Ia
menangani NIK, NPWP, telepon, email, nomor rekening (hanya bila ada kata
"rekening" atau nama bank di dekatnya), dan nama yang **dimasukkan pengguna
ke daftar**. Ia tidak dapat menebak bahwa "anak Pak Camat yang sakit itu"
mengidentifikasi seseorang. Tinjauan manusia atas hasil ekspor tetap wajib.

---

## 7. Pemeriksaan log audit

| Butir | Isi |
|-------|-----|
| Lokasi | `audit.jsonl` di direktori konfigurasi pengguna (`ALUR-DATA.md` §4) |
| Melihat | Pengaturan → Kepatuhan PDP → Log audit → **"Lihat log"** |
| Mengekspor | **"Ekspor CSV"** → pilih lokasi simpan. Ekspor itu sendiri tercatat sebagai `AuditExported` |
| Isi | Tindakan, cap waktu, sesi/jalur terkait, tujuan ekspor. **Tanpa isi rapat** |
| Rotasi | **Tidak ada.** Log tidak pernah dirotasi dan tidak ada API untuk menghapus entri — rotasi otomatis berarti menghapus riwayat audit, satu hal yang tidak boleh dilakukan log audit atas kehendak sendiri (`pdp/audit.rs:30-33`). Pertumbuhannya kilobita per tahun |

### Prosedur pemeriksaan berkala

**Frekuensi:** ⬜ **[ISI INSTANSI]** — disarankan triwulanan.

1. Ekspor CSV log audit.
2. Periksa entri **`SummarySent`**: setiap entri berarti transkrip dikirim
   ke endpoint LLM. Pastikan jumlahnya wajar dan **pastikan endpoint masih
   loopback** (risiko RS-5). Ini pemeriksaan paling penting dalam daftar
   ini.
3. Periksa entri **`SessionExported`**: tujuan ekspor berada di lokasi yang
   dikelola, bukan di media lepas atau folder sinkronisasi awan.
4. Periksa entri **`RetentionApplied`**: ada satu untuk setiap siklus
   retensi yang dijadwalkan. Siklus yang tidak muncul berarti retensi
   tidak dijalankan.
5. Periksa entri **`ConsentAcknowledged`** terhadap jumlah sesi: sesi yang
   jauh lebih banyak daripada pemberitahuan menunjukkan pemberitahuan
   Pasal 21 dilewati.
6. Salin CSV ke penyimpanan instansi yang hanya-tambah (mitigasi
   kesenjangan G-1: log di perangkat tidak tahan-ubah).

---

## 8. Catatan kendali instansi (templat)

Salin tabel ini ke buku kendali instansi dan isi setiap siklus.

| Tanggal | Pelaksana | Siklus | Sesi audio-saja dihapus | Sesi penuh dihapus | Pengecualian + alasan | Cadangan ditangani? | Paraf |
|---------|-----------|--------|-------------------------|--------------------|-----------------------|---------------------|-------|
| | | | | | | | |

---

*Disusun 7 Oktober 2026 · Trareon Transcribe Sprint 7 · Prosedur untuk
diadopsi dan disesuaikan instansi; bukan nasihat hukum.*
