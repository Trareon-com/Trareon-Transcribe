# Templat Penilaian Dampak Pelindungan Data Pribadi (DPIA)

**Untuk penggelaran Trareon Transcribe di lingkungan instansi**

> **Cara memakai templat ini.** Bagian yang **sudah terisi** adalah fakta
> teknis tentang Trareon yang dapat diverifikasi pada kode sumber; biarkan
> apa adanya kecuali Anda mengubah konfigurasi baku. Bagian bertanda
> ⬜ **[ISI INSTANSI]** harus diisi oleh Pengendali Data Pribadi dan tidak
> dapat diisi oleh penyedia perangkat lunak.
>
> **Dasar kewajiban.** UU No. 27 Tahun 2022 **Pasal 34**: pengendali wajib
> melakukan penilaian dampak pelindungan data pribadi dalam hal pemrosesan
> memiliki potensi risiko tinggi terhadap subjek data pribadi. Pemicunya
> meliputi pengambilan keputusan otomatis yang berakibat hukum/signifikan,
> pemrosesan data pribadi yang bersifat spesifik, pemrosesan skala besar,
> serta evaluasi/penskoran/pemantauan sistematis. (Teks pasal diverifikasi
> 7 Okt 2026 — lihat `PEMETAAN-UU-PDP-27-2022.md` §3.)
>
> Peraturan pelaksanaan yang dilaporkan memerinci pemicu ini
> (**PP No. 33 Tahun 2026**, dilaporkan berlaku 16 Januari 2027)
> **belum diverifikasi terhadap teks resmi** — periksa di JDIH sebelum
> mengutipnya.

---

## 1. Identitas dan tata kelola

| Butir | Isi |
|-------|-----|
| Nama instansi | ⬜ **[ISI INSTANSI]** |
| Unit kerja pemilik proses | ⬜ **[ISI INSTANSI]** |
| Pengendali Data Pribadi | ⬜ **[ISI INSTANSI]** — nama jabatan, bukan nama orang |
| Pejabat Pelindungan Data Pribadi (PPDP/DPO) | ⬜ **[ISI INSTANSI]** · Wajib bila termasuk kriteria **Pasal 53**, yang mencakup pemrosesan untuk pelayanan publik — **sebagian besar instansi pemerintah termasuk** |
| Prosesor Data Pribadi | **Tidak ada** pada konfigurasi baku Trareon. Bila endpoint LLM diarahkan ke penyedia pihak ketiga, prosesor **muncul** dan baris ini harus diisi beserta perjanjian pemrosesannya (Pasal 51–52) |
| Tanggal penilaian | ⬜ **[ISI INSTANSI]** |
| Tanggal tinjauan ulang | ⬜ **[ISI INSTANSI]** — disarankan setahun sekali, atau setiap kali konfigurasi berubah |
| Penyusun | ⬜ **[ISI INSTANSI]** |
| Pengesah | ⬜ **[ISI INSTANSI]** |

---

## 2. Uraian pemrosesan

### 2.1 Apa yang diproses

| Butir | Isi |
|-------|-----|
| Sistem | Trareon Transcribe — aplikasi desktop luring untuk transkripsi rapat dan penyusunan notulen |
| Versi | ⬜ **[ISI INSTANSI]** |
| Jenis rapat yang direkam | ⬜ **[ISI INSTANSI]** — mis. rapat koordinasi internal, rapat dengan pihak ketiga, sidang/pemeriksaan |
| Perkiraan jumlah rapat per bulan | ⬜ **[ISI INSTANSI]** |
| Perkiraan jumlah subjek data per rapat | ⬜ **[ISI INSTANSI]** |
| Jumlah perangkat/notulis yang menjalankan Trareon | ⬜ **[ISI INSTANSI]** |

### 2.2 Kategori data pribadi

| Kategori | Terproses? | Catatan |
|----------|------------|---------|
| Nama lengkap peserta | ⬜ **[ISI INSTANSI]** | Hampir pasti ya — notulen menyebut nama |
| Jabatan, unit kerja | ⬜ **[ISI INSTANSI]** | |
| **Rekaman suara** | **Ya** (bila merekam, bukan impor berkas) | Lihat §2.3 tentang status biometrik |
| Isi ucapan (transkrip) | **Ya** | Dapat memuat kategori apa pun yang dibicarakan |
| NIK / NPWP | ⬜ **[ISI INSTANSI]** | Bila disebut dalam rapat. Trareon menyamarkannya saat ekspor bila Mode PDP aktif |
| Nomor telepon, email | ⬜ **[ISI INSTANSI]** | Idem |
| Nomor rekening | ⬜ **[ISI INSTANSI]** | Idem |
| **Data kesehatan** | ⬜ **[ISI INSTANSI]** | **Data pribadi spesifik** (Pasal 4) → pemicu DPIA Pasal 34 |
| **Data keuangan pribadi** | ⬜ **[ISI INSTANSI]** | **Data pribadi spesifik** → pemicu DPIA |
| **Catatan kejahatan / dugaan pelanggaran** | ⬜ **[ISI INSTANSI]** | **Data pribadi spesifik** → pemicu DPIA. Relevan untuk rapat/sidang etik dan pemeriksaan |
| **Data anak** | ⬜ **[ISI INSTANSI]** | **Data pribadi spesifik** → pemicu DPIA |
| Data biometrik lain (wajah, sidik jari) | **Tidak** | Trareon tidak memproses citra |

### 2.3 Status hukum rekaman suara — pertanyaan yang harus dijawab instansi

UU PDP Pasal 4 membedakan data pribadi **spesifik** (yang perlakuannya
lebih ketat) dari data pribadi **umum**. Daftar data spesifik menyebut
data biometrik; penjelasan undang-undang memberi contoh **citra wajah**
dan **data daktiloskopi**, dan **tidak menyebut suara secara eksplisit**.

Tiga penafsiran yang beredar, dan konsekuensinya:

| Penafsiran | Argumen | Konsekuensi bila dipakai |
|------------|---------|--------------------------|
| Luas | Suara memungkinkan identifikasi unik, sehingga memenuhi rumusan "karakteristik perilaku yang memungkinkan identifikasi unik" | Rekaman = data spesifik → **DPIA wajib**, retensi lebih ketat |
| Sempit | Contoh dalam penjelasan hanya wajah dan daktiloskopi | Rekaman = data umum |
| Kehati-hatian (disarankan) | Perlakukan **rekaman audio** sebagai berisiko tinggi dan **transkrip teks** sebagai data umum, karena rekamanlah yang membawa karakteristik suara | DPIA dilakukan; retensi audio lebih pendek daripada transkrip — persis pemisahan yang disediakan Trareon |

⬜ **[ISI INSTANSI]** Penafsiran yang dipilih dan alasannya:
_________________________________________________________________

> Rujukan riset internal dengan sitasi: `trareon-sprints/OPEN-QUESTIONS-LLM-SRIKANDI-LEGAL.md`
> §C.2. Analisis itu **bukan** pendapat hukum dan harus ditinjau unit hukum
> instansi.

---

## 3. Dasar pemrosesan (Pasal 20)

⬜ **[ISI INSTANSI]** — pilih satu atau lebih dan jelaskan:

- [ ] **Pasal 20 ayat (2) huruf a** — persetujuan subjek data
- [ ] **Pasal 20 ayat (2) huruf b** — pelaksanaan perjanjian
- [ ] **Pasal 20 ayat (2) huruf c** — pemenuhan kewajiban hukum
- [ ] **Pasal 20 ayat (2) huruf d** — pelindungan kepentingan vital
- [ ] **Pasal 20 ayat (2) huruf e** — pelaksanaan kewenangan, pelayanan
      publik, atau kepentingan umum ← *paling lazim untuk rapat dinas,
      karena notulen adalah naskah dinas yang wajib dibuat*
- [ ] **Pasal 20 ayat (2) huruf f** — kepentingan sah lainnya
      *(memerlukan penilaian kepentingan sah tersendiri)*

Uraian dasar yang dipilih: _________________________________________

Bila **huruf a** dipilih: bagaimana persetujuan dikumpulkan, dicatat, dan
dapat ditarik? _____________________________________________________

Bila **huruf f** dipilih: lampirkan penilaian kepentingan sah
(kepentingan apa, mengapa pemrosesan perlu, bagaimana hak subjek data
tetap seimbang).

---

## 4. Pemicu DPIA — apakah penilaian ini wajib?

| Pemicu Pasal 34 ayat (2) | Berlaku? | Alasan |
|--------------------------|----------|--------|
| Pengambilan keputusan otomatis yang berakibat hukum/signifikan | **Tidak** | Trareon tidak mengambil keputusan tentang orang. Keluaran LLM adalah draf dokumen yang **wajib** ditinjau notulis; tidak ada penskoran, pemeringkatan, atau rekomendasi tentang individu |
| Pemrosesan data pribadi yang bersifat spesifik | ⬜ **[ISI INSTANSI]** | Ya bila rapat membahas kesehatan, keuangan pribadi, dugaan pelanggaran, atau data anak — atau bila instansi memperlakukan rekaman suara sebagai biometrik (§2.3) |
| Pemrosesan skala besar | ⬜ **[ISI INSTANSI]** | Pertimbangkan jumlah rapat/bulan × peserta/rapat × jumlah notulis |
| Evaluasi, penskoran, atau pemantauan sistematis | ⬜ **[ISI INSTANSI]** | **Jawab hati-hati.** Trareon sendiri tidak mengevaluasi siapa pun. Tetapi perekaman **setiap** rapat suatu unit secara terus-menerus dapat dipandang pemantauan sistematis terhadap pegawai, terlepas dari apa yang dilakukan perangkat lunaknya |

**Kesimpulan:** ⬜ **[ISI INSTANSI]** DPIA wajib / tidak wajib / dilakukan
secara sukarela. Alasan: ____________________________________________

---

## 5. Penilaian kebutuhan dan proporsionalitas

| Pertanyaan | Jawaban |
|------------|---------|
| Mengapa rapat perlu direkam, bukan dicatat manual saja? | ⬜ **[ISI INSTANSI]** |
| Apakah ada cara yang kurang mengganggu untuk mencapai tujuan yang sama? | ⬜ **[ISI INSTANSI]** |
| Apakah seluruh rapat perlu direkam, atau hanya jenis tertentu? | ⬜ **[ISI INSTANSI]** |
| Apakah rekaman audio perlu disimpan setelah notulen disetujui? | ⬜ **[ISI INSTANSI]** — bila tidak, setel retensi audio sependek mungkin (mis. 7 hari) |
| Bagaimana subjek data diberi tahu? | Teks pemberitahuan perekaman yang disediakan aplikasi, **dilengkapi** unsur Pasal 21 yang belum termuat (masa retensi, daftar hak) — lihat Lampiran A |

**Catatan proporsionalitas yang menguntungkan instansi:** karena Trareon
memproses seluruhnya di perangkat, tidak ada pengungkapan ke prosesor dan
tidak ada transfer lintas yurisdiksi pada konfigurasi baku. Dibanding
layanan notulen berbasis awan, jumlah pihak yang memegang data turun dari
"instansi + penyedia awan (+ subprosesornya)" menjadi "instansi saja". Ini
fakta yang layak dicatat dalam penilaian proporsionalitas.

---

## 6. Identifikasi dan penilaian risiko

Skala: Kemungkinan (K) dan Dampak (D) masing-masing 1–3; Tingkat = K × D.
Risiko di bawah sudah diidentifikasi dari arsitektur Trareon; nilai K dan
D bergantung lingkungan instansi dan harus diisi.

| ID | Risiko | Terhadap siapa | K | D | Tingkat | Mitigasi yang sudah ada di Trareon | Mitigasi tambahan instansi |
|----|--------|----------------|---|---|---------|-------------------------------------|----------------------------|
| **RS-1** | Laptop notulis hilang/dicuri; audio dan transkrip terbaca | Peserta rapat | ⬜ | ⬜ | ⬜ | Data di direktori konfigurasi per-pengguna, bukan lokasi publik. **Tidak ada enkripsi tingkat aplikasi** | **Wajib:** enkripsi cakram penuh (LUKS/BitLocker/FileVault), sandi akun kuat, kunci layar otomatis |
| **RS-2** | NIK/rekening/telepon ikut tersebar dalam notulen yang diedarkan | Peserta, pihak ketiga yang disebut | ⬜ | ⬜ | ⬜ | Penyamaran saat ekspor pada salinan (`pdp/redaction.rs`); pengguna melihat pratinjau perubahan | Aktifkan Mode Kepatuhan PDP; wajibkan tinjauan sebelum mengedarkan |
| **RS-3** | Rekaman disimpan jauh lebih lama dari yang diperlukan | Peserta | ⬜ | ⬜ | ⬜ | Kebijakan retensi dengan jam terpisah audio/transkrip | **Wajib:** tetapkan angka retensi **dan jadwalkan eksekusinya** — Trareon tidak menghapus otomatis |
| **RS-4** | Notulen memuat pernyataan yang tidak pernah diucapkan (halusinasi LLM) sehingga merugikan seseorang | Peserta yang disalahsebut | ⬜ | ⬜ | ⬜ | Provenance butir→segmen (`provenance.rs`); `factcheck.rs` menandai butir tanpa dukungan transkrip; pemeriksaan angka (`notulen/angka.rs`); draf **wajib** melewati formulir sunting | Tetapkan bahwa notulen hasil mesin tidak sah sebelum ditandatangani notulis |
| **RS-5** | Transkrip terkirim ke penyedia awan karena endpoint LLM salah konfigurasi | Semua peserta | ⬜ | ⬜ | ⬜ | Baku loopback `http://localhost:11434`; setiap pengiriman tercatat `SummarySent` di log audit | **Wajib:** kebijakan tertulis bahwa endpoint tetap loopback; audit berkala atas pengaturan; pertimbangkan perangkat tanpa akses internet |
| **RS-6** | Data rapat yang sudah "dihapus" masih ada di cadangan | Peserta | ⬜ | ⬜ | ⬜ | **Tidak ada** — di luar jangkauan aplikasi | Masukkan direktori konfigurasi Trareon ke prosedur penghapusan cadangan, atau kecualikan dari cadangan |
| **RS-7** | Log audit disunting sehingga catatan pemrosesan tidak lagi dapat dipercaya | Akuntabilitas instansi | ⬜ | ⬜ | ⬜ | `audit.jsonl` append-only secara konvensi API, di-fsync, tanpa API hapus. **Tidak tahan-ubah secara kriptografis** | Salin log ke penyimpanan hanya-tambah milik instansi; batasi akses tulis |
| **RS-8** | Pegawai merasa diawasi karena setiap rapat direkam | Pegawai instansi | ⬜ | ⬜ | ⬜ | Pemberitahuan perekaman sebelum mulai | Batasi jenis rapat yang direkam; sosialisasikan kebijakan; sediakan saluran keberatan |
| **RS-9** | Perekaman mikrofon menangkap pembicaraan sebelum/sesudah agenda | Siapa pun di ruangan | ⬜ | ⬜ | ⬜ | VAD hanya memilih potongan berisi suara — bukan mitigasi privasi, hanya efisiensi | Prosedur: mulai rekam setelah pemberitahuan, hentikan saat agenda selesai |
| **RS-10** | ⬜ **[ISI INSTANSI]** risiko khas lingkungan Anda | | ⬜ | ⬜ | ⬜ | | |

---

## 7. Hak subjek data — bagaimana dipenuhi di sini

| Hak | Pasal | Cara instansi memenuhinya dengan Trareon |
|-----|-------|-------------------------------------------|
| Informasi | 5 | Teks pemberitahuan perekaman (Lampiran A) |
| Perbaikan | 6 | Sunting transkrip/notulen; terbitkan notulen perbaikan |
| Akses dan salinan | 7 | Ekspor sesi ke Markdown/DOCX/PDF/TXT |
| Penghapusan | 8, 43 | Hapus sesi; jalankan retensi; **jangan lupa cadangan** (RS-6) |
| Penarikan persetujuan | 9 | ⬜ **[ISI INSTANSI]** prosedur di luar aplikasi |
| Menolak keputusan otomatis | 10 | Tidak berlaku — tidak ada keputusan otomatis |
| Penundaan/pembatasan | 11, 41 | ⬜ **[ISI INSTANSI]** — **tidak ada kendali aplikasi** (kesenjangan G-3). Prosedur manual: pindahkan sesi ke penyimpanan terkunci, atau hapus audio dan tahan transkrip |
| Portabilitas | 13 | Ekspor + sidecar metadata SRIKANDI |

**Titik kontak permintaan subjek data:** ⬜ **[ISI INSTANSI]**
**Tenggat internal:** UU PDP memberi batas 3x24 jam untuk beberapa
kewajiban (Pasal 30, 32, 40, 41). ⬜ **[ISI INSTANSI]** tenggat internal
yang lebih pendek agar batas itu terpenuhi.

---

## 8. Kesimpulan dan keputusan

| Butir | Isi |
|-------|-----|
| Risiko residual tertinggi setelah mitigasi | ⬜ **[ISI INSTANSI]** |
| Apakah risiko residual dapat diterima? | ⬜ **[ISI INSTANSI]** |
| Keputusan | ⬜ Lanjut / ⬜ Lanjut dengan syarat / ⬜ Tidak lanjut |
| Syarat yang harus dipenuhi sebelum mulai | ⬜ **[ISI INSTANSI]** — minimal: enkripsi cakram penuh, angka retensi ditetapkan, endpoint LLM diverifikasi lokal, teks pemberitahuan dilengkapi |
| Perlu konsultasi ke lembaga pengawas? | ⬜ **[ISI INSTANSI]** |
| Tanda tangan Pengendali Data Pribadi | ⬜ **[ISI INSTANSI]** |
| Tanda tangan PPDP/DPO | ⬜ **[ISI INSTANSI]** |

---

## Lampiran A — Teks pemberitahuan perekaman

### A.1 Teks baku aplikasi

Terpasang di `rust_core/src/pdp/mod.rs` sebagai `DEFAULT_CONSENT_NOTICE`:

> Rapat ini direkam dan ditranskripsi secara lokal di perangkat notulis
> untuk keperluan penyusunan notulen. Rekaman dan transkrip tidak diunggah
> ke layanan pihak ketiga. Jika Anda keberatan, silakan sampaikan sekarang.

Teks ini sengaja satu paragraf agar benar-benar dibacakan, dan **tidak
memuat seluruh unsur Pasal 21.**

### A.2 Teks lengkap unsur Pasal 21 — ganti di Pengaturan → Kepatuhan PDP

Salin, isi bagian ⬜, lalu tempel ke kolom "Teks pemberitahuan".
Placeholder `{judul}` dan `{tanggal}` diisi otomatis oleh aplikasi.

> **Pemberitahuan perekaman rapat**
>
> Rapat "{judul}" pada {tanggal} direkam dan ditranskripsi untuk keperluan
> penyusunan notulen rapat sebagai naskah dinas.
>
> **Pengendali data:** ⬜ [nama instansi dan unit kerja].
> **Dasar pemrosesan:** ⬜ [mis. pelaksanaan kewenangan dan pelayanan
> publik, Pasal 20 ayat (2) huruf e UU No. 27 Tahun 2022].
> **Data yang diproses:** rekaman suara peserta, transkrip ucapan, nama
> dan jabatan peserta.
> **Pemrosesan:** seluruhnya di perangkat notulis. Rekaman dan transkrip
> **tidak** diunggah ke layanan pihak ketiga.
> **Masa penyimpanan:** rekaman audio ⬜ [N] hari; transkrip dan notulen
> ⬜ [M] hari, sesuai jadwal retensi arsip instansi.
> **Hak Anda:** memperoleh informasi, mengakses dan memperoleh salinan,
> memperbaiki data yang tidak tepat, serta meminta penghentian pemrosesan
> dan penghapusan data, sesuai Pasal 5 sampai dengan Pasal 15 UU No. 27
> Tahun 2022.
> **Permintaan dan keberatan:** ⬜ [titik kontak — nama jabatan, email,
> telepon].
>
> Jika Anda keberatan direkam, silakan sampaikan sekarang sebelum
> perekaman dimulai.

### A.3 Catatan praktis

- Untuk rapat daring, tempelkan ke obrolan **sebelum** menekan rekam.
  Tombol "Salin teks pemberitahuan" ada di Pengaturan → Kepatuhan PDP.
- Untuk rapat tatap muka, bacakan dan catat di notulen bahwa pemberitahuan
  telah disampaikan. Aplikasi mencatat `ConsentAcknowledged` di log audit.
- Bila ada peserta yang keberatan dan dasar pemrosesannya adalah
  persetujuan, perekaman **tidak boleh** dijalankan untuk peserta itu —
  dan karena satu rekaman tidak dapat memisahkan satu orang, praktisnya
  berarti rapat dicatat manual.

---

## Lampiran B — Daftar periksa sebelum penggelaran

| # | Butir | Selesai |
|---|-------|---------|
| 1 | Enkripsi cakram penuh aktif di setiap laptop notulis | ⬜ |
| 2 | Sandi akun OS kuat dan kunci layar otomatis aktif | ⬜ |
| 3 | Dasar pemrosesan ditetapkan dan didokumentasikan | ⬜ |
| 4 | Teks pemberitahuan Pasal 21 dilengkapi dan dipasang di aplikasi | ⬜ |
| 5 | Mode Kepatuhan PDP diaktifkan; kategori penyamaran dipilih | ⬜ |
| 6 | Angka retensi audio dan transkrip ditetapkan | ⬜ |
| 7 | Eksekusi retensi dijadwalkan dan ada penanggung jawabnya | ⬜ |
| 8 | Endpoint LLM diverifikasi loopback (`http://localhost:11434`) | ⬜ |
| 9 | Model Whisper dan model LLM dipasang lebih dulu (bila perangkat tanpa internet) | ⬜ |
| 10 | Direktori konfigurasi Trareon masuk prosedur penghapusan cadangan | ⬜ |
| 11 | Titik kontak permintaan subjek data ditetapkan dan disosialisasikan | ⬜ |
| 12 | PPDP/DPO ditunjuk bila termasuk kriteria Pasal 53 | ⬜ |
| 13 | Prosedur penanganan kegagalan pelindungan (3x24 jam, Pasal 46) ada | ⬜ |
| 14 | Notulis dilatih: pemberitahuan, tinjauan butir bertanda, retensi | ⬜ |
| 15 | DPIA ini disahkan | ⬜ |

---

*Templat disusun 7 Oktober 2026 · Trareon Transcribe Sprint 7 · Bukan
nasihat hukum; wajib ditinjau unit hukum instansi.*
