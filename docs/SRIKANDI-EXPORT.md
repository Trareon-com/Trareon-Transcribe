# Ekspor Notulen Siap-Unggah ke SRIKANDI

**Prosedur manual · Trareon Transcribe**

> **Trareon tidak terintegrasi dengan SRIKANDI, dan tidak mengaku
> terintegrasi.** Unggahan dilakukan sendiri oleh pengguna lewat antarmuka
> SRIKANDI instansi. Yang dilakukan Trareon adalah menghilangkan satu-satunya
> gesekan nyata pada jalur manual itu: menyiapkan metadata registrasi di
> samping dokumen, sehingga pengisian formulir SRIKANDI menjadi salin-tempel
> alih-alih menurunkan ulang dari dokumen yang tidak memuat sebagian besar
> datanya.

---

## 1. Mengapa unggahan manual

SRIKANDI (Sistem Informasi Kearsipan Dinamis Terintegrasi) adalah aplikasi
umum bidang kearsipan dinamis yang wajib dipakai instansi pemerintah, bagian
dari ekosistem SPBE.

Versi 3 memang memiliki fitur **API management**, tetapi:

- tidak ada dokumentasi API publik yang menjelaskan endpoint, autentikasi,
  atau format permintaan/tanggapan;
- akses pihak ketiga, bila ada, memerlukan pengaturan dengan ANRI;
- tidak ada jalur resmi bagi aplikasi desktop pihak ketiga untuk mengunggah
  naskah atas nama pengguna.

Karena itu **integrasi otomatis tidak dapat dibangun dengan jujur hari ini**.
Klaim "terintegrasi SRIKANDI" dari penyedia mana pun yang tidak menyebut
nomor perjanjiannya dengan ANRI patut diperiksa.

Status verifikasi rujukan ini: ditelusuri 4 Oktober 2026 terhadap FAQ
SRIKANDI V3 di layanan.arsip.go.id. Rangkumannya ada di
`trareon-sprints/OPEN-QUESTIONS-LLM-SRIKANDI-LEGAL.md` §B.

---

## 2. Yang dihasilkan Trareon

Satu tindakan ekspor menghasilkan **empat berkas** di dalam folder sesi
(`rust_core/src/api.rs::export_notulen_srikandi`):

| Berkas | Isi | Untuk apa |
|--------|-----|-----------|
| `<Jenis Naskah> - <Judul>.docx` | Naskah dinas sesuai tata letak PERANRI | **Salinan yang ditandatangani** dan diunggah |
| `<Jenis Naskah> - <Judul>.pdf` | Naskah yang sama, teks biasa | Pengedaran dan pengarsipan sementara |
| `<Jenis Naskah> - <Judul> - metadata.json` | Metadata registrasi, terstruktur | Dibaca mesin; untuk alat bantu instansi |
| `<Jenis Naskah> - <Judul> - metadata.csv` | Metadata yang sama, satu baris | Dibuka di lembar kerja; salin-tempel per kolom |

Semua ditulis atomik (berkas sementara lalu *rename* di direktori yang sama),
sehingga mati daya tidak meninggalkan DOCX setengah jadi.

### Bidang metadata

Mengikuti bidang yang lazim diminta saat registrasi naskah
(`rust_core/src/srikandi.rs::SrikandiMetadata`):

| Bidang | Keterangan | Diisi otomatis? |
|--------|-----------|-----------------|
| `nomor` | Nomor naskah | **Tidak — lihat §3** |
| `tanggal` | Tanggal naskah | Ya, dari tanggal rapat |
| `jenis_naskah` | Notula / Risalah Rapat / Berita Acara | Ya, dari templat yang dipilih |
| `perihal` | Hal | Ya, dari judul rapat — **periksa**, judul sesi bukan selalu perihal yang benar |
| `sifat` | Sangat Segera / Segera / Biasa | Baku **Biasa** |
| `klasifikasi_keamanan` | Sangat Rahasia / Rahasia / Terbatas / Biasa | Baku **Biasa** — **ubah bila rapat membahas data pribadi spesifik** |
| `kode_klasifikasi_arsip` | Kode klasifikasi arsip instansi | **Tidak** — milik arsiparis unit |
| `unit_pengolah` | Unit kerja | Ya, dari Pengaturan → Notulen Resmi |
| `penandatangan_nama`, `penandatangan_jabatan` | Penanda tangan | Sebagian, dari formulir notulen |
| `jumlah_lampiran` | Jumlah lampiran | Ya |
| `tingkat_perkembangan` | Asli / Tembusan / Salinan / Petikan | Baku **Asli** |
| `catatan` | Catatan bebas | Tidak |

---

## 3. Satu bidang yang tidak akan pernah diisi Trareon: `nomor`

Nomor naskah berasal dari Tata Usaha unit atau aplikasi persuratan instansi.
Nomor yang terlihat masuk akal tetapi dibuat sendiri akan **mendaftarkan
dokumen dengan identitas yang sudah menjadi milik dokumen lain** — kesalahan
kearsipan yang jauh lebih mahal daripada kolom kosong.

Karena itu `validate()` hanya **menandai** nomor yang masih berupa
*placeholder*, dan `nomor_shape_ok()` hanya memeriksa **bentuknya**:

```
[sifat-]urut/KODE UNIT/KODE KLASIFIKASI/MM/TTTT
```

- Awalan sifat opsional: `B-`, `R-`, `SR-`, `T-`
- `urut`, `MM`, dan `TTTT` harus angka; `MM` dua digit antara 01–12;
  `TTTT` empat digit
- `KODE UNIT` dan `KODE KLASIFIKASI` tidak boleh kosong

Contoh yang lolos bentuk: `B-125/TU.01/KP.03/10/2026`

Apakah kode unit dan kode klasifikasinya **benar** adalah pertanyaan untuk
arsiparis unit, dan pemeriksa yang berpura-pura tahu akan lebih buruk
daripada tidak ada pemeriksa.

---

## 4. Prosedur unggah

### Sebelum mengekspor

1. Isi Pengaturan → **Notulen Resmi**: instansi/unit kerja, tempat, nama
   notulis, dan kop surat. Isian ini terpakai di setiap rapat.
2. Mintakan **nomor naskah** ke Tata Usaha unit.
3. Mintakan **kode klasifikasi arsip** ke arsiparis unit bila belum hafal.
4. Tentukan **klasifikasi keamanan**. Baku `Biasa`; naikkan bila rapat
   membahas data pribadi spesifik (kesehatan, keuangan pribadi, dugaan
   pelanggaran, data anak) atau hal yang dibatasi peraturan instansi.

### Mengekspor

5. Selesaikan dan tinjau notulen. **Periksa setiap butir yang ditandai
   pemeriksaan fakta** sebelum melanjutkan — butir bertanda adalah
   pernyataan yang tidak ditemukan dukungannya di transkrip.
6. Jalankan ekspor SRIKANDI. Empat berkas di §2 muncul di folder sesi.
7. Bila Mode Kepatuhan PDP aktif, penyamaran berjalan pada salinan ekspor;
   **buka DOCX dan periksa hasilnya** — penyamaran bekerja pada pola, bukan
   pada makna (lihat `docs/compliance/PROSEDUR-RETENSI-DAN-PENGHAPUSAN.md` §6).

### Menandatangani

8. Tanda tangan basah, atau TTE tersertifikasi bila unit sudah memiliki
   sertifikat BSrE. Banyak unit masih memakai tanda tangan manual, dan itu
   tetap sah.

### Mengunggah

9. Buka SRIKANDI instansi, pilih registrasi naskah keluar/internal sesuai
   jenis naskah.
10. Buka berkas `… - metadata.csv` di lembar kerja, atau `… - metadata.json`
    di penampil teks.
11. Salin tiap bidang ke formulir SRIKANDI. Urutannya sudah disamakan
    dengan urutan bidang pada formulir registrasi yang lazim, sehingga
    pengisian bisa berurutan tanpa melompat-lompat.
12. Unggah berkas **DOCX** yang sudah ditandatangani sebagai naskahnya.
    PDF dipakai untuk pengedaran, bukan sebagai arsip utama.
13. Simpan. Catat nomor registrasi yang diberikan SRIKANDI di buku kendali
    unit.

### Setelah mengunggah

14. Bila Mode Kepatuhan PDP aktif, ekspor tercatat di log audit sebagai
    `SessionExported`. Catatan itu adalah bukti **ekspor**, bukan bukti
    **unggah** — SRIKANDI-lah yang mencatat unggahannya.
15. Berkas ekspor di folder sesi kini menjadi salinan kedua dari naskah yang
    sudah teregistrasi. Masukkan ke prosedur retensi instansi
    (`docs/compliance/PROSEDUR-RETENSI-DAN-PENGHAPUSAN.md` §5.1 butir 3).

---

## 5. Pemeriksaan sebelum unggah

`siap_unggah()` bernilai benar hanya bila tidak ada temuan bertingkat
**Wajib**. Temuan bertingkat **Saran** tidak menghalangi unggahan tetapi
layak dibaca.

| Temuan | Tingkat | Artinya |
|--------|---------|---------|
| Nomor belum diisi atau bentuknya salah | Wajib | Ambil dari Tata Usaha; jangan menetapkan sendiri |
| Tanggal belum diisi | Wajib | |
| Tanggal tidak lengkap dengan nama bulan | Saran | Tulis "5 Oktober 2026", bukan "05/10/26" |
| Hal/perihal belum diisi | Wajib | |

---

## 6. Batasan yang perlu disebut terang

| Hal | Status |
|-----|--------|
| Unggah otomatis via API | **Tidak ada**, dan tidak direncanakan selama API publik belum ada |
| TTE otomatis | **Tidak ada** — bergantung sertifikat BSrE instansi |
| Validasi kode klasifikasi arsip terhadap daftar instansi | **Tidak ada** — hanya bentuk nomor yang diperiksa |
| Formulir metadata yang dapat disunting di aplikasi | **Belum ada antarmukanya.** Mesin dan API-nya lengkap (`srikandi_metadata_default`, `srikandi_validate`, `srikandi_siap_unggah`, `export_notulen_srikandi`) dan sudah teruji, tetapi belum ada layar Flutter yang memanggilnya. Sampai layar itu ada, metadata hanya terisi dari nilai bawaan formulir notulen dan tidak dapat disunting pengguna — lihat laporan Sprint 7 |
| Pendaftaran ke SIKN/JIKN | Di luar lingkup |

---

*Disusun 7 Oktober 2026 · Trareon Transcribe Sprint 7*
