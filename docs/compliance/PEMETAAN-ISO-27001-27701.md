# Pemetaan Kendali Trareon ke ISO/IEC 27001:2022, ISO/IEC 27701:2019, dan Rujukan BSSN

> **Status dokumen.** Pemetaan kendali untuk membantu audit internal dan
> asesmen pengadaan. **Bukan sertifikat, bukan laporan audit, dan bukan
> klaim kepatuhan.**
>
> Trareon Transcribe **belum** disertifikasi ISO/IEC 27001, **belum**
> disertifikasi ISO/IEC 27701, **belum** mendapat penetapan kategori sistem
> elektronik dari BSSN, dan **belum** terdaftar sebagai Penyelenggara
> Sistem Elektronik. Dokumen ini memetakan kendali teknis produk ke nomor
> kendali standar agar auditor instansi dapat menempatkannya di dalam SMKI
> instansi sendiri.
>
> **Verifikasi nomor kendali.** Nomor dan judul kendali diambil dari
> struktur standar yang berlaku umum: ISO/IEC 27001:2022 Annex A (93
> kendali dalam empat tema — 5 Organizational, 6 People, 7 Physical, 8
> Technological) dan ISO/IEC 27701:2019 Annex A (kendali tambahan bagi
> **PII controller**). Standarnya berhak cipta dan tidak dapat dikutip
> penuh di sini; judul kendali ditulis ringkas. Nomor yang **tidak dapat
> dipastikan** diberi tanda **(belum diverifikasi)**. Auditor instansi
> wajib mencocokkan ke salinan standar resmi (atau SNI padanannya) yang
> dimiliki instansi.

---

## 1. Lingkup dan batasan pemetaan

Trareon Transcribe adalah **aplikasi desktop satu pengguna** yang berjalan
di perangkat notulis. Akibatnya, seluruh tema **7 Physical** dan sebagian
besar tema **6 People** di Annex A tidak dapat dipenuhi produk: itu kendali
atas gedung, perangkat, dan orang — yang dimiliki instansi, bukan aplikasi.

| Tema Annex A | Siapa yang memegang kendali |
|--------------|------------------------------|
| **5 Organizational** (5.1–5.37) | Terutama instansi; produk mendukung beberapa |
| **6 People** (6.1–6.8) | **Instansi sepenuhnya** |
| **7 Physical** (7.1–7.14) | **Instansi sepenuhnya** |
| **8 Technological** (8.1–8.34) | Terbagi; di sinilah kendali produk berada |

Pemetaan di bawah hanya memuat kendali yang **benar-benar bersinggungan**
dengan Trareon. Kendali yang tidak disinggung bukan berarti tidak relevan
bagi instansi — hanya berarti produk tidak punya kendali atasnya.

---

## 2. ISO/IEC 27001:2022 Annex A

### 2.1 Tema 5 — Organizational

| Kendali | Judul ringkas | Kendali Trareon | Pemegang |
|---------|---------------|-----------------|----------|
| **A.5.9** | Inventaris informasi dan aset terkait | Inventaris aset data lengkap dengan lokasi per OS: `ALUR-DATA.md` §2 dan §4 | Produk memasok inventaris; instansi memeliharanya |
| **A.5.10** | Penggunaan aset yang dapat diterima | — | Instansi |
| **A.5.12** | Klasifikasi informasi | Trareon tidak mengklasifikasi otomatis. Kategori data yang mungkin muncul didaftar di `TEMPLAT-DPIA.md` §2.2 | Instansi |
| **A.5.13** | Pelabelan informasi | Keluaran notulen mengikuti format naskah dinas (PERANRI 5/2025) yang memuat ruang untuk klasifikasi/sifat naskah; sidecar SRIKANDI (`srikandi.rs`) membawa metadata naskah dinas | Terbagi |
| **A.5.14** | Pemindahan informasi | Ekspor hanya ke berkas lokal yang dipilih pengguna; tidak ada pengiriman otomatis, tidak ada integrasi email/awan. Setiap ekspor dicatat `SessionExported` | Produk membatasi; instansi mengatur pemindahan selanjutnya |
| **A.5.15** | Kendali akses | **Tidak ada kendali akses tingkat aplikasi.** Batasnya adalah akun OS | **Instansi** |
| **A.5.19** | Keamanan informasi dalam hubungan pemasok | Tidak ada pemasok yang memproses data pada konfigurasi baku — tidak ada layanan awan, tidak ada akun. Pemasok muncul hanya bila instansi mengarahkan endpoint LLM ke luar | Instansi |
| **A.5.23** | Keamanan informasi untuk penggunaan layanan awan | **Tidak ada layanan awan** pada konfigurasi baku. Fakta ini ditegakkan uji build, bukan kebijakan: `rust_core/src/privacy.rs` | Produk |
| **A.5.31** | Persyaratan hukum, perundang-undangan, regulasi, dan kontrak | `PEMETAAN-UU-PDP-27-2022.md` memetakan kewajiban UU PDP ke kendali dan kesenjangan | Terbagi |
| **A.5.33** | Pelindungan rekaman | Log audit append-only yang di-fsync (`pdp/audit.rs`), tanpa rotasi dan tanpa API hapus. **Tidak tahan-ubah secara kriptografis** (kesenjangan G-1) | Terbagi |
| **A.5.34** | Privasi dan pelindungan PII | Seluruh modul `rust_core/src/pdp/`; Mode Kepatuhan PDP; Laporan Privasi | Produk |
| **A.5.37** | Prosedur operasional terdokumentasi | `PROSEDUR-RETENSI-DAN-PENGHAPUSAN.md`; `README.md` paket ini | Produk memasok; instansi mengadopsi |

### 2.2 Tema 6 — People

Seluruh tema ini milik instansi. Satu kendali layak disebut karena produk
menciptakan kebutuhannya:

| Kendali | Judul ringkas | Catatan |
|---------|---------------|---------|
| **A.6.3** | Kesadaran, pendidikan, dan pelatihan keamanan informasi | Notulis perlu dilatih tiga hal yang tidak dapat dipaksakan perangkat lunak: menyampaikan pemberitahuan **sebelum** merekam, **meninjau** butir notulen yang ditandai `factcheck.rs`, dan **menjalankan** retensi sesuai jadwal. Butir 14 Lampiran B `TEMPLAT-DPIA.md` |

### 2.3 Tema 7 — Physical

Milik instansi sepenuhnya. Dua yang paling menentukan bagi Trareon:

| Kendali | Judul ringkas | Mengapa penting di sini |
|---------|---------------|-------------------------|
| **A.7.10** | Media penyimpanan | Audio dan transkrip ada di cakram laptop notulis tanpa enkripsi aplikasi. Enkripsi cakram penuh adalah kendali pengganti, dan **wajib** |
| **A.7.14** | Pembuangan atau penggunaan ulang peralatan yang aman | Laptop notulis yang dialihkan atau dibuang memuat sisa data rapat. `PROSEDUR-RETENSI-DAN-PENGHAPUSAN.md` §5 |

### 2.4 Tema 8 — Technological

| Kendali | Judul ringkas | Kendali Trareon | Pemegang |
|---------|---------------|-----------------|----------|
| **A.8.1** | Perangkat titik akhir pengguna | Trareon **adalah** beban kerja titik akhir. Pengerasan titik akhir (enkripsi, kunci layar, patch) adalah prasyarat penggelaran | **Instansi** |
| **A.8.5** | Autentikasi aman | **Tidak ada.** Tidak ada akun, tidak ada kata sandi aplikasi. Autentikasi adalah milik akun OS (kesenjangan G-2) | **Instansi** |
| **A.8.10** | Penghapusan informasi | `pdp/retention.rs` — rencana, pratinjau, konfirmasi, hapus; jam terpisah audio/transkrip; hasil dicatat ke log audit. **Bukan** penghapusan aman tingkat blok (kesenjangan G-5) | Terbagi |
| **A.8.11** | Penyamaran data | `pdp/redaction.rs` — NIK, NPWP, telepon, email, nomor rekening, nama pilihan. Berjalan **hanya pada salinan ekspor**; transkrip tersimpan tidak berubah. Pemindai ditulis tangan dengan kesadaran konteks (mis. angka 16 digit diuji terhadap kode provinsi; deret digit dianggap rekening hanya bila ada kata "rekening" atau nama bank di dekatnya) justru agar tidak merusak angka anggaran | **Produk** |
| **A.8.12** | Pencegahan kebocoran data | Kendali terkuat produk, dan sifatnya arsitektural: jalur transkripsi **tidak dapat** membuka soket, ditegakkan uji yang menggagalkan build (`privacy.rs::transcribe_path_no_network_calls`). Modul fitur lokal — arsip, PDP, provenance, map-reduce, notulen, SRIKANDI — juga dilarang menyentuh jaringan (`local_only_features_stay_local`) | **Produk** |
| **A.8.13** | Pencadangan informasi | **Tidak ada fitur cadangan.** Pencadangan OS yang mencakup direktori konfigurasi menjadi risiko RS-6, bukan kendali | **Instansi** |
| **A.8.15** | Pencatatan (logging) | `audit.jsonl`: 11 jenis tindakan (sesi dibuat, diekspor, ringkasan dikirim, sesi/audio/transkrip dihapus, pemberitahuan diakui, penyamaran diterapkan, retensi dijalankan, log diekspor, model diunduh). **Tanpa isi rapat** — mencatat *bahwa* transkrip diekspor dan ke mana, bukan apa isinya | **Produk** |
| **A.8.16** | Aktivitas pemantauan | **Tidak ada.** Trareon tidak mendeteksi anomali dan tidak memberi peringatan. Tersedia Laporan Privasi yang menghitung panggilan jaringan sejak aplikasi dibuka — pemantauan untuk pengguna, bukan untuk SOC | **Instansi** |
| **A.8.20** | Keamanan jaringan | Lima titik keluar jaringan, semuanya dimulai pengguna, didaftar lengkap di `ALUR-DATA.md` §3 | Terbagi |
| **A.8.21** | Keamanan layanan jaringan | Endpoint LLM baku loopback. Risiko salah konfigurasi: RS-5 | Terbagi |
| **A.8.24** | Penggunaan kriptografi | **Terbatas.** Tidak ada enkripsi penyimpanan dan tidak ada enkripsi di dalam aplikasi untuk data rapat. Kriptografi yang **ada**: SHA-256 dipin untuk setiap model Whisper yang diunduh, diverifikasi setelah unduh dan **tidak** dipercaya dari server (`model.rs:70-131`); serta TLS untuk unduhan itu | Terbagi; kesenjangan G-2 |
| **A.8.25** | Daur hidup pengembangan yang aman | Gerbang verifikasi wajib hijau sebelum setiap commit: `cargo fmt --check`, `cargo clippy --all-targets -- -D warnings`, `cargo test --lib`, `flutter analyze` (nol isu termasuk tingkat info), `flutter test`, `flutter build linux --release` | Produk |
| **A.8.26** | Persyaratan keamanan aplikasi | Persyaratan privasi ditulis sebagai **uji**, bukan sebagai dokumen: `privacy.rs`, `test/privacy_proof_test.dart` | Produk |
| **A.8.28** | Pengodean yang aman | Rust tanpa `unsafe` di jalur fitur; clippy `-D warnings`; id sesi yang datang dari Dart dibersihkan sebelum masuk jalur berkas (`session.rs::sanitize_session_id`); penulisan berkas atomik (temp + rename di direktori yang sama) untuk semua yang dipersistenkan | Produk |
| **A.8.29** | Pengujian keamanan dalam pengembangan dan penerimaan | Gerbang privasi dijalankan di CI pada setiap perubahan | Produk |
| **A.8.31** | Pemisahan lingkungan pengembangan, uji, dan produksi | Berkas uji memakai penimpaan direktori (`RECOVERY_DIR_OVERRIDE`) sehingga uji tidak pernah menyentuh data pengguna | Produk |
| **A.8.32** | Manajemen perubahan | Commit konvensional kecil; laporan per sprint di `docs/SPRINT-REPORTS.md` | Produk |
| **A.8.33** | Informasi uji | Dataset bake-off notulen (`ml/notulen_bench/data/`) **seluruhnya sintetis** — 24 rapat yang disusun untuk uji, bukan rapat nyata. Tidak ada data rapat pengguna yang dipakai sebagai data uji | Produk |

### 2.5 Ringkasan: kendali produk versus kendali instansi

| Kategori | Jumlah kendali dipetakan | Keterangan |
|----------|--------------------------|------------|
| Dipenuhi **produk** | 8 | A.5.23, A.5.34, A.8.11, A.8.12, A.8.15, A.8.25, A.8.26, A.8.28 (+ A.8.29, A.8.31, A.8.32, A.8.33 untuk proses pengembangan) |
| **Terbagi** | 9 | A.5.13, A.5.14, A.5.31, A.5.33, A.5.37, A.8.10, A.8.20, A.8.21, A.8.24 |
| **Instansi sepenuhnya** | 8 | A.5.10, A.5.12, A.5.15, A.5.19, A.6.3, A.7.10, A.7.14, A.8.1, A.8.5, A.8.13, A.8.16 |
| **Kesenjangan produk yang diakui** | 3 | A.8.5 (tanpa autentikasi), A.8.24 (tanpa enkripsi penyimpanan), A.5.33 (log tidak tahan-ubah) |

---

## 3. ISO/IEC 27701:2019 — kendali tambahan bagi PII controller

Nomor mengikuti **Annex A ISO/IEC 27701:2019** (kendali tambahan bagi PII
controller). Instansi adalah PII controller; Trareon adalah perangkat
lunak yang dipakainya, bukan PII processor pada konfigurasi baku.

### 3.1 A.7.2 — Kondisi pengumpulan dan pemrosesan

| Kendali | Judul ringkas | Kendali Trareon | Pemegang |
|---------|---------------|-----------------|----------|
| **A.7.2.1** | Mengidentifikasi dan mendokumentasikan tujuan | `TEMPLAT-DPIA.md` §2 | Instansi |
| **A.7.2.2** | Mengidentifikasi dasar hukum | `TEMPLAT-DPIA.md` §3, dipetakan ke Pasal 20 UU PDP | Instansi |
| **A.7.2.3** | Menentukan kapan dan bagaimana persetujuan diperoleh | Pengingat pemberitahuan sebelum merekam; teks yang dapat disunting | Terbagi |
| **A.7.2.4** | Memperoleh dan mencatat persetujuan | **Tidak ada pencatatan persetujuan per-orang.** Yang ada: `ConsentAcknowledged` di log audit, yang mencatat bahwa notulis menyampaikan pemberitahuan — bukan bahwa setiap peserta setuju | **Instansi** — kesenjangan produk |
| **A.7.2.5** | Penilaian dampak privasi | `TEMPLAT-DPIA.md` | Instansi mengisi; produk memasok templat dan fakta teknis |
| **A.7.2.6** | Kontrak dengan PII processor | **Tidak diperlukan** pada konfigurasi baku — tidak ada processor. Diperlukan bila endpoint LLM diarahkan ke luar | Instansi |
| **A.7.2.7** | PII controller bersama | Tidak berlaku | Instansi |
| **A.7.2.8** | Catatan terkait pemrosesan PII | `audit.jsonl` adalah **masukan** untuk catatan kegiatan pemrosesan instansi, bukan penggantinya (= Pasal 31 UU PDP) | Terbagi |

### 3.2 A.7.3 — Kewajiban kepada PII principal

| Kendali | Judul ringkas | Kendali Trareon | Pemegang |
|---------|---------------|-----------------|----------|
| **A.7.3.1** | Menentukan dan memenuhi kewajiban kepada PII principal | `PEMETAAN-UU-PDP-27-2022.md` §1 | Instansi |
| **A.7.3.2** | Menentukan informasi untuk PII principal | Lampiran A `TEMPLAT-DPIA.md` | Terbagi |
| **A.7.3.3** | Menyampaikan informasi kepada PII principal | Teks pemberitahuan + tombol salin | Produk menyediakan sarana; instansi menyampaikan |
| **A.7.3.4** | Sarana mengubah atau menarik persetujuan | **Tidak ada di aplikasi** | **Instansi** |
| **A.7.3.5** | Sarana menolak pemrosesan | **Tidak ada di aplikasi** | **Instansi** |
| **A.7.3.6** | Akses, koreksi, dan/atau penghapusan | Ekspor (akses), penyuntingan penuh (koreksi), hapus sesi dan retensi (penghapusan) | Produk menyediakan kemampuan; instansi menjalankan prosesnya |
| **A.7.3.7** | Kewajiban controller memberi tahu pihak ketiga | **Tidak ada** pelacakan penerima berkas ekspor di aplikasi. Log audit mencatat tujuan ekspor di berkas sistem, bukan siapa yang menerima dokumennya | **Instansi** |
| **A.7.3.8** | Menyediakan salinan PII yang diproses | Ekspor Markdown/DOCX/PDF/TXT + sidecar SRIKANDI | Produk |
| **A.7.3.9** | Penanganan permintaan | `PROSEDUR-RETENSI-DAN-PENGHAPUSAN.md` §6 | Instansi |
| **A.7.3.10** | Pengambilan keputusan otomatis | **Tidak berlaku** — Trareon tidak mengambil keputusan tentang orang; keluaran LLM adalah draf yang wajib ditinjau manusia | Produk (secara desain) |

### 3.3 A.7.4 — Privacy by design dan privacy by default

Bagian terkuat pemetaan ini.

| Kendali | Judul ringkas | Kendali Trareon | Pemegang |
|---------|---------------|-----------------|----------|
| **A.7.4.1** | Membatasi pengumpulan | VAD hanya menyimpan potongan berisi suara. Tetap: sebut jujur bahwa ini **efisiensi**, bukan mitigasi privasi — pembicaraan sebelum agenda tetap tertangkap bila perekaman sudah berjalan (risiko RS-9) | Terbagi |
| **A.7.4.2** | Membatasi pemrosesan | Mode Kepatuhan PDP **mati secara baku**, dan dengan itu aplikasi berperilaku seperti sebelumnya. Keputusan desain yang dicatat di `pdp/mod.rs:17`: mode kepatuhan yang diam-diam menghapus rekaman atau menulis ulang notulen adalah masalah yang lebih besar daripada yang dipecahkannya | Produk |
| **A.7.4.3** | Ketepatan dan kualitas | Provenance butir→segmen, `factcheck.rs`, pemeriksaan angka rupiah/persentase | Produk |
| **A.7.4.4** | Tujuan minimisasi PII | Penyamaran saat ekspor; log audit tanpa isi rapat | Produk |
| **A.7.4.5** | De-identifikasi dan penghapusan PII pada akhir pemrosesan | Penyamaran (de-identifikasi pada salinan) + retensi (penghapusan). Catatan: penyamaran **tidak** mengubah transkrip tersimpan — itu disengaja, karena notulen yang kehilangan angka anggaran aslinya tidak lagi menjadi naskah dinas | Produk |
| **A.7.4.6** | Berkas sementara | Penulisan atomik memakai berkas temp **di direktori tujuan yang sama**, lalu rename — sehingga berkas sementara tidak pernah mendarat di `/tmp` yang dapat dibaca semua pengguna. Berkas `.part` WAV selama perekaman berada di direktori sesi, dan ikut terhapus bersama sesi | Produk |
| **A.7.4.7** | Retensi | Jam terpisah untuk audio dan transkrip — pemisahan yang disengaja, karena rekamanlah yang membawa suara dan sebagian besar aturan retensi ingin rekaman hilang jauh sebelum notulennya (`pdp/retention.rs:4-10`) | Produk menyediakan mekanisme; **instansi menetapkan angka dan menjadwalkan eksekusinya** |
| **A.7.4.8** | Pembuangan | Hapus berkas dan direktori sesi dengan konfirmasi. **Bukan** penimpaan blok; tidak menjangkau cadangan (kesenjangan G-5, risiko RS-6) | Terbagi |
| **A.7.4.9** | Kendali transmisi PII | Pada konfigurasi baku **tidak ada transmisi PII** — ditegakkan uji build. Bila endpoint LLM diarahkan ke luar, transmisi terjadi lewat TLS ke endpoint itu dan dicatat `SummarySent` | Produk |

### 3.4 A.7.5 — Pembagian, transfer, dan pengungkapan PII

| Kendali | Judul ringkas | Kendali Trareon | Pemegang |
|---------|---------------|-----------------|----------|
| **A.7.5.1** | Dasar transfer PII antaryurisdiksi | **Tidak ada transfer** pada konfigurasi baku. Bila endpoint LLM diarahkan ke penyedia luar negeri, Pasal 56 UU PDP berlaku dan dasar transfer wajib ada | Instansi |
| **A.7.5.2** | Negara dan organisasi internasional tujuan transfer | Tidak berlaku pada konfigurasi baku | Instansi |
| **A.7.5.3** | Catatan transfer PII | `SummarySent` di log audit mencatat setiap pengiriman ke endpoint | Terbagi |
| **A.7.5.4** | Catatan pengungkapan PII ke pihak ketiga | `SessionExported` mencatat ekspor dan tujuan berkasnya. **Tidak** mencatat kepada siapa dokumen kemudian diedarkan | **Instansi** |

### 3.5 Annex B (PII processor)

**Tidak dipetakan.** Annex B berlaku bagi PII processor. Pada konfigurasi
baku Trareon tidak ada PII processor: tidak ada pihak yang memproses data
rapat atas nama instansi. Bila instansi mengarahkan endpoint LLM ke
penyedia pihak ketiga, penyedia itu menjadi processor dan Annex B berlaku
**baginya**, bukan bagi Trareon.

---

## 4. Rujukan BSSN dan regulasi SPBE

| Rujukan | Relevansi untuk penggelaran Trareon | Status verifikasi |
|---------|--------------------------------------|-------------------|
| **Peraturan BSSN No. 8 Tahun 2020 tentang Sistem Pengamanan dalam Penyelenggaraan Sistem Elektronik** | Mengatur kategorisasi sistem elektronik berdasarkan penilaian sendiri oleh penyelenggara, dan kewajiban menerapkan standar manajemen keamanan informasi yang merujuk **SNI ISO/IEC 27001**. Penyelenggara yang sistemnya berkategori Strategis atau Tinggi wajib menerapkan dan memperoleh sertifikasi SNI ISO/IEC 27001 | **Terverifikasi** 7 Okt 2026 terhadap <https://www.bssn.go.id/kategorisasi-sistem-elektronik-2/> dan <https://pasal.id/peraturan/perban/peraturan-bssn-no-8-tahun-2020> |
| **Indeks KAMI (Keamanan Informasi)** — BSSN | Alat penilaian mandiri yang dipakai penyelenggara sistem elektronik untuk bersiap menerapkan SNI ISO/IEC 27001. Pemetaan Annex A di §2 dokumen ini dapat menjadi masukan untuk area "Pengelolaan Aset Informasi" dan "Teknologi dan Keamanan Informasi" pada Indeks KAMI instansi | **Terverifikasi** 7 Okt 2026 terhadap bssn.go.id |
| **Perpres No. 95 Tahun 2018 tentang SPBE** | Kerangka Sistem Pemerintahan Berbasis Elektronik; dasar SRIKANDI sebagai aplikasi umum bidang kearsipan dinamis. Relevan karena keluaran Trareon ditujukan untuk masuk SRIKANDI | **Terverifikasi** 4 Okt 2026 |
| **PERANRI No. 5 Tahun 2025 tentang Tata Naskah Dinas** | Format naskah dinas termasuk Notula dan Berita Acara (kepala, batang tubuh, kaki, lampiran) — dasar keempat tata letak notulen Trareon | **Terverifikasi** 4 Okt 2026 terhadap anri.go.id (28 Apr 2025); berlaku 21 Maret 2025 |
| Peraturan BSSN tentang CSIRT / tim tanggap insiden siber | Jalur pelaporan insiden untuk instansi pemerintah; relevan untuk kewajiban Pasal 46 UU PDP (pemberitahuan 3x24 jam) | **BELUM DIVERIFIKASI** — nomor dan tahun peraturan belum diperiksa terhadap teks resmi. Instansi memiliki jalur CSIRT sendiri; pakai itu |
| PP No. 71 Tahun 2019 tentang Penyelenggaraan Sistem dan Transaksi Elektronik | Kewajiban pendaftaran PSE dan pengamanan sistem elektronik | **BELUM DIVERIFIKASI** untuk konteks ini — penerapannya pada aplikasi desktop yang tidak menyelenggarakan layanan daring perlu ditelaah unit hukum instansi |

### 4.1 Catatan penting tentang kategorisasi BSSN

Peraturan BSSN 8/2020 membebankan kategorisasi dan kewajiban SMKI pada
**penyelenggara sistem elektronik** — yaitu instansi yang
menyelenggarakannya. Trareon Transcribe adalah perangkat lunak yang
dipasang di titik akhir, bukan sistem elektronik yang diselenggarakan
pengembangnya; tidak ada server, tidak ada layanan, dan tidak ada akun.

Konsekuensi praktis untuk pengadaan: pertanyaan "apakah produk ini sudah
dikategorisasi BSSN" tidak memiliki jawaban yang berarti bagi perangkat
lunak titik akhir. Yang berarti adalah **sistem elektronik instansi**
tempat Trareon menjadi salah satu komponennya. Pemetaan Annex A di §2
disediakan agar komponen itu dapat ditempatkan di dalam SMKI instansi.

---

## 5. Daftar kesenjangan terhadap standar — ringkas dan jujur

| Kesenjangan | Kendali terkait | Status |
|-------------|-----------------|--------|
| Tidak ada enkripsi penyimpanan tingkat aplikasi | A.8.24, A.7.10 | Terbuka secara desain; dialihkan ke enkripsi cakram penuh OS |
| Tidak ada autentikasi tingkat aplikasi | A.8.5, A.5.15 | Terbuka secara desain; batasnya akun OS |
| Log audit tidak tahan-ubah secara kriptografis | A.5.33, A.8.15 | Terbuka; kandidat backlog (rantai hash per entri) |
| Penghapusan bukan penimpaan aman | A.8.10, A.7.4.8 | Terbuka secara desain; prosedur instansi |
| Tidak ada pencatatan persetujuan per-orang | A.7.2.4 | Terbuka; dikelola instansi di luar aplikasi |
| Tidak ada sarana penarikan persetujuan/penolakan di aplikasi | A.7.3.4, A.7.3.5 | Terbuka; dikelola instansi |
| Tidak ada pemantauan/peringatan keamanan | A.8.16 | Di luar lingkup aplikasi desktop satu pengguna |
| Tidak ada fitur pencadangan | A.8.13 | Di luar lingkup; cadangan OS menjadi risiko RS-6 |
| **Belum ada sertifikasi ISO/IEC 27001 maupun 27701** | — | Tidak ada, dan tidak diklaim |

---

*Disusun 7 Oktober 2026 · Trareon Transcribe Sprint 7 · Pemetaan kendali,
bukan sertifikat. Nomor kendali wajib dicocokkan ke salinan standar resmi
milik instansi.*
