# Pemetaan Kendali Trareon ke UU No. 27 Tahun 2022

**Undang-Undang Republik Indonesia Nomor 27 Tahun 2022 tentang
Pelindungan Data Pribadi** ("UU PDP").

> **Status dokumen.** Pemetaan kendali, bukan pernyataan kepatuhan dan
> bukan nasihat hukum. Kewajiban UU PDP dibebankan pada **Pengendali Data
> Pribadi** — yaitu instansi yang merekam rapat — bukan pada aplikasi.
> Kolom "siapa" di setiap tabel menyebut pihak yang bertanggung jawab.
>
> **Verifikasi nomor pasal.** Nomor pasal dan pokok materinya diverifikasi
> pada **7 Oktober 2026** terhadap:
> - teks resmi: <https://peraturan.bpk.go.id/Download/224884/UU%20Nomor%2027%20Tahun%202022.pdf>
> - penelusuran per pasal: <https://pasal.id/peraturan/uu/uu-no-27-tahun-2022>
>
> Pasal 31, 34, 46, dan 53 diverifikasi dengan membaca kutipan teks
> pasalnya. Pasal lain diverifikasi pada tingkat **pokok materi**
> (judul/subjek pasal) dari sumber di atas; bila instansi akan mengutip
> bunyi pasal dalam dokumen resmi, kutip dari PDF BPK, bukan dari sini.
> Hal yang tidak dapat diverifikasi diberi tanda **(belum diverifikasi)**.

---

## 0. Peran para pihak

| Peran UU PDP | Dalam penggelaran Trareon |
|--------------|---------------------------|
| **Subjek Data Pribadi** | Peserta rapat yang suaranya direkam dan namanya muncul di transkrip/notulen |
| **Pengendali Data Pribadi** | Instansi yang menyelenggarakan rapat dan memutuskan rapat itu direkam |
| **Prosesor Data Pribadi** | **Tidak ada.** Trareon berjalan di perangkat notulis; tidak ada pihak ketiga yang memproses data atas nama instansi — kecuali instansi sendiri mengarahkan endpoint LLM ke server luar (lihat risiko R-1 di §6) |
| Pengembang Trareon | Penyedia perangkat lunak. Tidak menerima, tidak menyimpan, dan tidak dapat mengakses data rapat |

Konsekuensi penting: karena tidak ada prosesor, instansi **tidak perlu**
perjanjian pemrosesan data (Pasal 51–52) untuk pemakaian Trareon pada
konfigurasi baku. Ini perbedaan nyata dibanding layanan notulen berbasis
awan, yang selalu memunculkan prosesor dan sering memunculkan transfer
lintas yurisdiksi (Pasal 56).

---

## 1. Hak Subjek Data Pribadi (Pasal 5–15)

| Pasal | Hak | Kendali Trareon | Siapa |
|-------|-----|-----------------|-------|
| 5 | Hak atas informasi identitas pengendali, dasar hukum, tujuan, akuntabilitas | **Pemberitahuan perekaman** — teks siap-tempel yang dibuat aplikasi dan dapat disunting instansi (`rust_core/src/pdp/mod.rs`, `DEFAULT_CONSENT_NOTICE`, `consent_notice()`), dapat disalin ke obrolan Zoom/Meet/Teams dari Pengaturan → Kepatuhan PDP | Teks: Trareon · Penyampaian: instansi |
| 6 | Hak melengkapi/memperbarui/memperbaiki | Transkrip dan notulen **dapat disunting penuh** di aplikasi; nama pembicara dapat diubah; notulen hasil LLM selalu melewati formulir sunting sebelum diekspor | Instansi |
| 7 | Hak memperoleh akses dan salinan | Seluruh data satu rapat berada di satu direktori sesi; ekspor tersedia dalam Markdown, DOCX, PDF, dan teks | Instansi |
| 8 | Hak mengakhiri pemrosesan, menghapus dan/atau memusnahkan | Hapus sesi dari Pustaka; penghapusan terencana via kebijakan retensi (lihat §4 dan `PROSEDUR-RETENSI-DAN-PENGHAPUSAN.md`) | Instansi |
| 9 | Hak menarik persetujuan | Tidak ada mekanisme persetujuan di dalam aplikasi — persetujuan dikelola instansi di luar aplikasi. Setelah ditarik, instansi menjalankan prosedur penghapusan §4 | **Instansi** (Trareon: tidak ada kendali) |
| 10 | Hak menolak pengambilan keputusan otomatis | Trareon **tidak mengambil keputusan apa pun** tentang orang. Keluaran LLM adalah draf dokumen yang wajib ditinjau manusia; tidak ada penskoran, pemeringkatan, atau rekomendasi tentang individu | Trareon (secara desain) |
| 11 | Hak menunda atau membatasi pemrosesan | Tidak ada status "ditangguhkan" per sesi di aplikasi. Yang tersedia: hentikan perekaman, hapus audio saja (transkrip tetap), atau hapus seluruh sesi | **Sebagian** — lihat kesenjangan G-3 di §6 |
| 12 | Hak menuntut dan menerima ganti kerugian | Di luar lingkup perangkat lunak | Instansi |
| 13 | Hak portabilitas dalam format yang dapat dibaca sistem lain | Ekspor Markdown/DOCX/PDF; **sidecar metadata SRIKANDI** (`rust_core/src/srikandi.rs`) untuk naskah dinas elektronik | Trareon menyediakan format; instansi menyerahkan |
| 14 | Tata cara pelaksanaan hak | Di luar lingkup perangkat lunak | Instansi |
| 15 | Pembatasan hak tertentu | Di luar lingkup perangkat lunak | Instansi |

---

## 2. Dasar pemrosesan dan pemberitahuan (Pasal 20, 21, 22)

### Pasal 20 — dasar pemrosesan

Pasal 20 ayat (2) memuat enam dasar pemrosesan: persetujuan; pelaksanaan
perjanjian; pemenuhan kewajiban hukum; pelindungan kepentingan vital;
pelaksanaan kewenangan/pelayanan publik/kepentingan umum; dan kepentingan
sah lainnya.

Untuk notulen rapat instansi, dua yang biasanya relevan:

- **Pasal 20 ayat (2) huruf e** — pelaksanaan kewenangan, pelayanan
  publik, atau kepentingan umum. Ini dasar yang paling lazim untuk rapat
  dinas: notulen adalah naskah dinas yang wajib dibuat, bukan pilihan.
- **Pasal 20 ayat (2) huruf a** — persetujuan. Relevan bila rapat
  melibatkan pihak luar instansi (narasumber, warga, vendor) yang tidak
  berada dalam hubungan kedinasan.

**Trareon tidak memilih dasar pemrosesan dan tidak bisa.** Instansi
menetapkannya dan mencatatnya di DPIA (`TEMPLAT-DPIA.md` §3). Yang
disediakan Trareon adalah kendali yang membuat dasar mana pun bisa
dijalankan secara wajar: pemberitahuan sebelum merekam, penyamaran saat
ekspor, dan retensi terbatas.

> Rujukan riset internal: pilihan dasar hukum untuk pemrosesan rekaman
> rapat terbuka dibahas di `trareon-sprints/OPEN-QUESTIONS-LLM-SRIKANDI-LEGAL.md`
> §C.2, yang menyimpulkan Pasal 20 ayat (2) huruf e sebagai yang paling
> dapat diterapkan untuk rekaman rapat terbuka lembaga negara.

### Pasal 21 — kewajiban memberitahu sebelum memproses

Pasal 21 mewajibkan pengendali memberitahukan antara lain legalitas
pemrosesan, tujuan, jenis dan relevansi data, **jangka waktu retensi**,
rincian informasi yang dikumpulkan, jangka waktu pemrosesan, dan hak
subjek data.

| Unsur Pasal 21 | Didukung Trareon? |
|----------------|-------------------|
| Legalitas dan tujuan pemrosesan | Teks pemberitahuan baku menyebut tujuan ("penyusunan notulen"); legalitas harus ditambahkan instansi |
| Jenis data | Teks baku menyebut rekaman dan transkrip |
| **Jangka waktu retensi** | Angka diambil dari kebijakan retensi yang diatur instansi (§4); aplikasi **tidak** otomatis menyisipkannya ke teks pemberitahuan — lihat kesenjangan G-4 |
| Ke mana data pergi | Teks baku menyatakan "diproses secara lokal … tidak diunggah ke layanan pihak ketiga" — pernyataan yang dapat dibuktikan secara teknis (§5) |
| Hak subjek data | **Tidak** termuat di teks baku; instansi harus menambahkannya |

Teks baku sengaja pendek agar benar-benar dibacakan. Instansi yang perlu
pemberitahuan Pasal 21 secara lengkap **wajib** mengganti teks itu di
Pengaturan → Kepatuhan PDP → Pemberitahuan perekaman. Lampiran A
`TEMPLAT-DPIA.md` memuat contoh teks yang memenuhi seluruh unsur Pasal 21.

### Pasal 22 — bentuk permintaan persetujuan

Tidak ada kendali Trareon. Persetujuan, bila itu dasar yang dipakai,
dikumpulkan instansi di luar aplikasi. Contoh formulir persetujuan yang
sudah dipakai proyek ini untuk perekaman dataset ada di
`ml/record_kit/CONSENT.md` dan dapat dijadikan titik awal.

---

## 3. Kewajiban pengendali: ketepatan, pencatatan, keamanan (Pasal 29–39)

| Pasal | Kewajiban | Kendali Trareon | Siapa |
|-------|-----------|-----------------|-------|
| 29 | Menjaga ketepatan, kelengkapan, dan konsistensi data | **Provenance** (`rust_core/src/provenance.rs`): setiap butir notulen tertaut ke nomor segmen transkrip. **Fact check** (`rust_core/src/notulen/factcheck.rs`): butir yang tidak didukung transkrip ditandai sebelum notulis menyetujui. **Pemeriksaan angka** (`rust_core/src/notulen/angka.rs`) untuk nilai rupiah dan persentase | Trareon menyediakan alat; ketepatan akhir tanggung jawab notulis |
| 30 | Memperbarui/memperbaiki dalam 3x24 jam sejak permintaan | Penyuntingan transkrip dan notulen tersedia seketika; pemenuhan tenggat adalah proses instansi | Instansi |
| 31 | **"Pengendali Data Pribadi wajib melakukan perekaman terhadap seluruh kegiatan pemrosesan Data Pribadi."** (teks diverifikasi) | **Log audit append-only** (`rust_core/src/pdp/audit.rs`, `audit.jsonl` di direktori konfigurasi pengguna): mencatat sesi dibuat, transkrip diekspor, ringkasan dikirim ke endpoint, sesi/audio/transkrip dihapus, pemberitahuan diakui, penyamaran diterapkan, retensi dijalankan, log diekspor, model diunduh. **Tidak memuat isi rapat** — hanya bahwa suatu tindakan terjadi dan ke mana. Dapat diekspor ke CSV | **Trareon memenuhi sebagian besar** — lihat kesenjangan G-1 (log tidak tahan-ubah) |
| 32 | Memberikan akses dalam 3x24 jam | Data satu rapat ada di satu direktori; ekspor seketika | Instansi |
| 33 | Alasan penolakan akses | Di luar lingkup | Instansi |
| 34 | **Penilaian dampak** untuk pemrosesan berisiko tinggi (teks diverifikasi; pemicu: keputusan otomatis berakibat hukum, data pribadi spesifik, skala besar, evaluasi/penskoran/pemantauan sistematis) | `TEMPLAT-DPIA.md` — templat yang sudah terisi bagian teknisnya untuk diselesaikan instansi | Instansi mengisi; Trareon menyediakan templat dan fakta teknisnya |
| 35 | Langkah teknis dan operasional pengamanan | Lihat tabel §3.1 | Terbagi |
| 36 | Menjaga kerahasiaan | Tidak ada akun, tidak ada berbagi, tidak ada unggahan pada konfigurasi baku; data berada di direktori konfigurasi per-pengguna, bukan `/tmp` (`rust_core/src/session.rs:1113`) | Terbagi |
| 37 | Mengawasi pihak yang terlibat pemrosesan | Satu pengguna, satu perangkat; tidak ada pihak lain yang terlibat | Instansi |
| 38 | Melindungi dari pemrosesan yang tidak sah | Lihat §5 (bukti luring) | Trareon |
| 39 | Mencegah akses tidak sah dengan sistem keamanan | **Kesenjangan nyata** — Trareon tidak memiliki enkripsi penyimpanan maupun autentikasi tingkat aplikasi. Lihat kesenjangan G-2 dan kewajiban instansi K-1 | **Instansi** |

### 3.1 Langkah pengamanan (Pasal 35, 39) secara rinci

| Langkah | Ada di Trareon | Catatan |
|---------|----------------|---------|
| Data tidak keluar perangkat saat transkripsi | **Ya, diuji otomatis** | `rust_core/src/privacy.rs::transcribe_path_no_network_calls` |
| Minimisasi saat pengungkapan | **Ya** | Penyamaran NIK, NPWP, telepon, email, nomor rekening, nama pilihan — hanya pada salinan ekspor |
| Pembatasan penyimpanan | **Ya, manual** | Kebijakan retensi dengan jam terpisah untuk audio dan transkrip |
| Pencatatan aktivitas | **Ya** | `audit.jsonl` |
| Penulisan berkas atomik (temp + rename) | **Ya** | Mencegah berkas setengah tertulis saat daya mati |
| Isolasi per-pengguna OS | **Ya** | Direktori konfigurasi pengguna |
| **Enkripsi saat disimpan** | **Tidak** | Tidak ada enkripsi tingkat aplikasi. Bergantung pada LUKS/BitLocker/FileVault — **wajib** diaktifkan instansi |
| **Autentikasi tingkat aplikasi** | **Tidak** | Siapa pun yang membuka sesi OS pengguna dapat membuka Trareon. Batas keamanannya adalah akun OS |
| Kendali akses berbasis peran | **Tidak** | Aplikasi desktop satu pengguna; tidak relevan secara arsitektur |
| Log tahan-ubah (hash chain/tanda tangan) | **Tidak** | Lihat G-1 |

---

## 4. Penghentian, penghapusan, pemusnahan (Pasal 40–45)

| Pasal | Kewajiban | Kendali Trareon |
|-------|-----------|-----------------|
| 40 | Menghentikan pemrosesan setelah persetujuan ditarik (3x24 jam) | Hentikan perekaman; hapus sesi. Proses instansi |
| 41 | Menunda/membatasi pemrosesan (3x24 jam) | Lihat kesenjangan G-3 |
| 42 | Penghentian pemrosesan (masa retensi berakhir, tujuan tercapai, atau permintaan subjek) | Kebijakan retensi menghitung sesi yang melewati batas |
| 43 | **Penghapusan** data pribadi | `rust_core/src/pdp/retention.rs::apply` menghapus berkas audio dan/atau seluruh direktori sesi, setelah pengguna melihat daftarnya dan mengonfirmasi. Dicatat ke log audit sebagai `AudioDeleted` / `TranscriptDeleted` / `RetentionApplied` |
| 44 | **Pemusnahan** data pribadi | **Sebagian.** Trareon menghapus berkas lewat panggilan berkas OS biasa; ia **tidak** menimpa blok disk dan tidak dapat menjangkau salinan di cadangan atau di berkas jurnal berkas-sistem. Pemusnahan yang memenuhi syarat memerlukan prosedur instansi — lihat `PROSEDUR-RETENSI-DAN-PENGHAPUSAN.md` §5 |
| 45 | Pemberitahuan penghapusan/pemusnahan | **Tidak ada** pemberitahuan otomatis ke subjek data. Log audit menyediakan catatan untuk dirujuk dalam pemberitahuan manual instansi |

Keputusan desain yang perlu disebut: **tidak ada yang dihapus secara
otomatis.** `retention::plan` murni dan tidak menghapus apa pun;
`retention::apply` hanya berjalan setelah pengguna melihat daftar dan
menekan "Hapus sekarang". Alasannya tertulis di
`rust_core/src/pdp/retention.rs:11` — penghapusan otomatis yang baru
diketahui pengguna setelah terjadi tidak dapat dibedakan dari kehilangan
data. Konsekuensi kepatuhannya: **pemenuhan masa retensi menjadi proses
yang harus dijadwalkan instansi**, bukan sesuatu yang terjadi sendiri.
Prosedurnya ada di `PROSEDUR-RETENSI-DAN-PENGHAPUSAN.md` §3.

---

## 5. Kegagalan pelindungan dan akuntabilitas (Pasal 46, 47)

### Pasal 46 — pemberitahuan kegagalan pelindungan

Teks diverifikasi: dalam hal terjadi kegagalan pelindungan data pribadi,
pengendali wajib menyampaikan pemberitahuan tertulis **paling lambat
3 x 24 jam** kepada subjek data pribadi dan lembaga, memuat sekurangnya:
data pribadi yang terungkap; kapan dan bagaimana terungkap; serta upaya
penanganan dan pemulihan.

| Unsur | Yang dapat dipasok Trareon |
|-------|----------------------------|
| Data pribadi apa yang terungkap | Log audit menyebut sesi dan tujuan ekspor, **bukan isinya**. Isi harus ditentukan dari berkas sesi yang masih ada |
| Kapan dan bagaimana | Cap waktu log audit untuk setiap ekspor, pengiriman ke endpoint, dan penghapusan |
| Upaya penanganan | Proses instansi |

Trareon **tidak** mendeteksi insiden, **tidak** memberi peringatan, dan
**tidak** melaporkan apa pun ke mana pun. Deteksi dan pelaporan adalah
kewajiban instansi, dan untuk instansi pemerintah disalurkan lewat
CSIRT/mekanisme BSSN (lihat `PEMETAAN-ISO-27001-27701.md` §4).

### Pasal 47 — akuntabilitas

Yang membuat akuntabilitas Trareon tidak sekadar pernyataan di README
adalah bahwa klaim utamanya **diperiksa oleh uji yang menggagalkan build**:

```sh
cd rust_core && cargo test --lib privacy        # gerbang luring sisi Rust
flutter test test/privacy_proof_test.dart       # gerbang luring sisi Dart
```

Uji-uji itu memindai berkas sumber jalur transkripsi untuk pola jaringan
(`reqwest`, `http://`, `https://`, `tokio::net`) dan menggagalkan build
bila salah satu muncul (`rust_core/src/privacy.rs:60-200`). Uji terpisah
memastikan modul fitur yang didokumentasikan sebagai lokal — arsip, PDP,
provenance, map-reduce, notulen, SRIKANDI — tidak dapat membuka soket.

Konsekuensi untuk pengadaan: pernyataan "transkripsi tidak pernah
meninggalkan perangkat" dapat diverifikasi panitia dengan menjalankan satu
perintah pada kode sumber, bukan dengan mempercayai brosur.

---

## 6. Risiko, kesenjangan, dan kewajiban instansi

### Risiko konfigurasi

| ID | Risiko | Penjelasan | Mitigasi |
|----|--------|------------|----------|
| **R-1** | **Endpoint LLM dapat diarahkan ke luar perangkat** | Endpoint ringkasan/notulen dapat dikonfigurasi (`rust_core/src/summary.rs`, `SummaryEndpoint.base_url`). Baku-nya loopback (`http://localhost:11434`), tetapi instansi **dapat** mengarahkannya ke penyedia awan. Bila itu dilakukan, transkrip dikirim keluar perangkat, muncul Prosesor Data Pribadi (Pasal 51–52), dan bila penyedia di luar negeri muncul juga transfer lintas yurisdiksi (Pasal 56) | Instansi **wajib** menetapkan dalam kebijakan bahwa endpoint tetap loopback, dan memverifikasinya di Pengaturan → Ringkasan AI. Setiap pengiriman tercatat di log audit sebagai `SummarySent` |
| **R-2** | Unduhan model menyentuh internet | Unduh model Whisper menghubungi `huggingface.co` (SHA256 dipin di kode, `rust_core/src/model.rs:70-131`). Dimulai pengguna, bukan otomatis. **Tidak ada data rapat yang dikirim** — hanya permintaan GET | Instansi dapat memasang model lebih dulu ke direktori model dan menjalankan Trareon di jaringan tertutup |
| **R-3** | Pemeriksaan pembaruan menyentuh internet | "Cek Pembaruan" mengambil satu berkas `VERSION` dari `raw.githubusercontent.com` (`lib/app_version.dart:24`). Dimulai pengguna, bukan otomatis; tidak ada data rapat yang dikirim; tercatat di Laporan Privasi | Jangan gunakan di jaringan tertutup; perbarui lewat distribusi paket instansi |

Keempat/kelima titik keluar jaringan dicatat lengkap di
`ALUR-DATA.md` §3 dan di `lib/state/privacy_report_model.dart:5-24`.
Layar **Laporan Privasi** di aplikasi menghitung setiap panggilan jaringan
sejak aplikasi dibuka, sehingga pengguna dapat melihat sendiri bahwa
transkripsi tidak menambah hitungan.

### Kesenjangan kendali Trareon (jujur)

| ID | Kesenjangan | Pasal terkait | Status |
|----|-------------|---------------|--------|
| **G-1** | Log audit append-only secara konvensi API, **tidak tahan-ubah secara kriptografis**. Tidak ada hash chain, tidak ada tanda tangan. Pengguna dengan akses tulis ke `audit.jsonl` dapat menyuntingnya | 31, 47 | Terbuka. Kandidat backlog: rantai hash per entri |
| **G-2** | **Tidak ada enkripsi saat disimpan dan tidak ada autentikasi aplikasi** | 35, 39 | Terbuka secara desain; dialihkan ke kendali OS (K-1) |
| **G-3** | Tidak ada status "pemrosesan ditangguhkan" per sesi | 11, 41 | Terbuka. Yang tersedia hanya hapus audio / hapus sesi |
| **G-4** | Teks pemberitahuan baku tidak otomatis memuat masa retensi dan daftar hak subjek data | 21 | Terbuka; instansi menggantinya secara manual |
| **G-5** | Penghapusan adalah unlink berkas biasa, bukan pemusnahan aman | 44 | Terbuka secara desain; dialihkan ke prosedur instansi |
| **G-6** | Tidak ada pemberitahuan otomatis ke subjek data saat data dihapus | 45 | Terbuka; manual |

### Kewajiban yang tetap pada instansi

| ID | Kewajiban | Pasal |
|----|-----------|-------|
| **K-1** | Mengaktifkan enkripsi cakram penuh (LUKS/BitLocker/FileVault) pada setiap laptop notulis, dengan sandi akun OS yang kuat dan kunci layar otomatis | 35, 39 |
| **K-2** | Menetapkan dan mendokumentasikan dasar pemrosesan | 20 |
| **K-3** | Menyampaikan pemberitahuan Pasal 21 yang lengkap sebelum merekam, dan mengelola persetujuan bila dasarnya persetujuan | 21, 22 |
| **K-4** | Melakukan DPIA bila pemicu Pasal 34 terpenuhi (mis. rapat membahas data kesehatan/keuangan pribadi pegawai, atau perekaman rapat berskala besar dan sistematis) | 34 |
| **K-5** | Menetapkan masa retensi, **menjadwalkan** eksekusinya, dan mencatat hasilnya | 42–44 |
| **K-6** | Menunjuk Pejabat Pelindungan Data Pribadi bila termasuk kriteria Pasal 53 — yang mencakup pemrosesan untuk pelayanan publik, sehingga **sebagian besar instansi pemerintah termasuk** | 53 |
| **K-7** | Menyiapkan prosedur penanganan dan pemberitahuan kegagalan pelindungan dalam 3x24 jam | 46 |
| **K-8** | Menjaga endpoint LLM tetap lokal, atau — bila tidak — melaksanakan seluruh kewajiban prosesor dan transfer lintas negara | 51, 52, 56 |
| **K-9** | Menyimpan catatan kegiatan pemrosesan tingkat instansi; `audit.jsonl` adalah masukan untuk catatan itu, bukan penggantinya | 31 |

---

## 7. Peraturan lain

Dicantumkan hanya bila teksnya dapat dirujuk; sisanya ditandai.

| Peraturan | Relevansi | Status verifikasi |
|-----------|-----------|-------------------|
| **UU No. 28 Tahun 2014 tentang Hak Cipta, Pasal 42** | Tidak ada hak cipta atas hasil rapat terbuka lembaga negara, peraturan perundang-undangan, pidato pejabat pemerintah, dan putusan pengadilan. Relevan untuk penggunaan rekaman rapat terbuka sebagai data latih | **Terverifikasi** 4 Okt 2026 terhadap dgip.go.id dan WIPO Lex; dicatat di `ml/DATA_CARD.md:40` |
| **PERANRI No. 5 Tahun 2025 tentang Tata Naskah Dinas** (ANRI) | Format naskah dinas, termasuk Notula dan Berita Acara (kepala, batang tubuh, kaki, lampiran) — dasar keempat tata letak notulen Trareon | **Terverifikasi** 4 Okt 2026 terhadap anri.go.id (28 Apr 2025); berlaku 21 Maret 2025 |
| **Permenkumham No. 14 Tahun 2024** | Tata naskah dinas dengan format Notula | **Terverifikasi** 4 Okt 2026 terhadap peraturan.bpk.go.id |
| **Perpres No. 95 Tahun 2018 tentang SPBE** | Dasar SRIKANDI sebagai aplikasi umum bidang kearsipan dinamis | **Terverifikasi** 4 Okt 2026 |
| **Peraturan BSSN No. 8 Tahun 2020 tentang Sistem Pengamanan dalam Penyelenggaraan Sistem Elektronik** | Kategorisasi sistem elektronik dan kewajiban SMKI merujuk SNI ISO/IEC 27001 | **Terverifikasi** 7 Okt 2026 terhadap bssn.go.id dan pasal.id |
| **PP No. 33 Tahun 2026** (peraturan pelaksanaan UU PDP) | Dilaporkan memerinci pemicu DPIA dan kewajiban DPO; dilaporkan berlaku 16 Januari 2027 | **BELUM DIVERIFIKASI terhadap teks resmi.** Bersumber dari ringkasan firma hukum (AHP client alert 2 Sep 2026; HLC client alert 2026) via `trareon-sprints/OPEN-QUESTIONS-LLM-SRIKANDI-LEGAL.md` §C.2. Unit hukum instansi **harus** memeriksa nomor, tanggal, dan isi terhadap JDIH sebelum mengutipnya |
| PermenPANRB / peraturan Kemendagri tentang tata naskah dinas daerah | Relevan untuk pemda | **Belum diverifikasi** — nomor spesifik belum diperiksa |

---

## 8. Yang tidak boleh dikatakan tentang dokumen ini

- Bukan "Trareon patuh UU PDP". Yang patuh atau tidak patuh adalah
  **instansi**; Trareon menyediakan kendali.
- Bukan sertifikasi, bukan akreditasi, bukan hasil audit pihak ketiga.
- Bukan nasihat hukum. Diperlukan tinjauan unit hukum instansi.
- Tidak ada nomor pasal di sini yang boleh dikutip dalam dokumen resmi
  tanpa dicocokkan ke teks di JDIH atau peraturan.bpk.go.id.

---

*Disusun 7 Oktober 2026 · Trareon Transcribe Sprint 7*
