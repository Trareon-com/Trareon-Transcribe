# Paket Kepatuhan Trareon Transcribe

Berkas di direktori ini adalah **bahan kerja untuk instansi yang akan
menggelar Trareon Transcribe**, bukan sertifikat dan bukan nasihat hukum.

## Isi paket

| Berkas | Untuk siapa | Isi |
|--------|-------------|-----|
| [`Ringkasan-Kepatuhan-untuk-Pengadaan.md`](Ringkasan-Kepatuhan-untuk-Pengadaan.md) | Panitia pengadaan, PPK | Satu halaman: apa yang Trareon kerjakan, apa yang tidak, dan apa yang tetap menjadi kewajiban instansi |
| [`PEMETAAN-UU-PDP-27-2022.md`](PEMETAAN-UU-PDP-27-2022.md) | Pejabat pelindungan data, unit hukum | Kendali Trareon dipetakan ke pasal UU No. 27 Tahun 2022 |
| [`PEMETAAN-ISO-27001-27701.md`](PEMETAAN-ISO-27001-27701.md) | Auditor SMKI, tim keamanan informasi | Pemetaan ke ISO/IEC 27001:2022 Annex A, ISO/IEC 27701:2019, dan rujukan BSSN |
| [`ALUR-DATA.md`](ALUR-DATA.md) | Semua pembaca | Diagram alur data (mermaid), inventaris aset, titik keluar jaringan |
| [`TEMPLAT-DPIA.md`](TEMPLAT-DPIA.md) | Pengendali data instansi | Templat penilaian dampak pelindungan data pribadi untuk diisi instansi |
| [`PROSEDUR-RETENSI-DAN-PENGHAPUSAN.md`](PROSEDUR-RETENSI-DAN-PENGHAPUSAN.md) | Notulis, admin TI, unit kearsipan | Prosedur operasional retensi, penghapusan, pemusnahan, dan penanganan permintaan subjek data |

Versi DOCX dari setiap berkas ada di [`docx/`](docx/), dihasilkan oleh
[`../../scripts/build_compliance_docx.py`](../../scripts/build_compliance_docx.py).
Markdown adalah sumber kebenaran; DOCX adalah turunan — jangan sunting DOCX.

```sh
/usr/bin/python3 scripts/build_compliance_docx.py
```

## Tiga hal yang perlu dibaca sebelum yang lain

**1. Trareon adalah perangkat lunak, bukan program kepatuhan.**
UU PDP membebankan kewajiban pada **Pengendali Data Pribadi** — yaitu
instansi, bukan aplikasi. Trareon menyediakan kendali teknis yang membuat
sebagian kewajiban itu bisa dipenuhi dan dibuktikan. Sisanya (dasar
pemrosesan, pemberitahuan ke subjek data, penunjukan pejabat, penanganan
insiden) tetap pekerjaan instansi. Setiap baris pemetaan di paket ini
menyebut dengan jelas bagian mana yang mana.

**2. Tidak ada sertifikasi dan tidak ada akreditasi.**
Trareon Transcribe **belum** disertifikasi ISO/IEC 27001, **belum**
disertifikasi ISO/IEC 27701, **belum** mendapat penetapan kategori sistem
elektronik dari BSSN, dan **belum** terdaftar sebagai PSE. Pemetaan ke
standar di paket ini adalah pemetaan kendali — alat bantu audit internal —
bukan klaim pemenuhan standar. Siapa pun yang menyebut paket ini sebagai
"bersertifikat ISO" salah membacanya.

**3. Yang ditandai "belum diverifikasi" memang belum diverifikasi.**
Nomor pasal dan nomor kendali di paket ini diverifikasi terhadap sumber
yang dicantumkan pada tanggal yang dicantumkan. Apa pun yang tidak bisa
diverifikasi terhadap teks aslinya diberi tanda **(belum diverifikasi)**
dan harus dikonfirmasi oleh unit hukum instansi sebelum dipakai dalam
dokumen resmi. Tidak ada nomor yang ditebak tanpa tanda.

## Dasar bukti teknis

Klaim teknis di paket ini merujuk ke berkas sumber dengan nomor baris agar
bisa diperiksa sendiri, dan ke uji otomatis yang menjaga klaim itu tetap
benar:

- `rust_core/src/privacy.rs` — uji yang menggagalkan build jika jalur
  transkripsi menyentuh jaringan.
- `test/privacy_proof_test.dart` — uji sisi Dart untuk hal yang sama.
- `rust_core/src/pdp/` — penyamaran, retensi, log audit.

Perintah untuk memverifikasi sendiri ada di
[`Ringkasan-Kepatuhan-untuk-Pengadaan.md`](Ringkasan-Kepatuhan-untuk-Pengadaan.md).

---

*Disusun: 7 Oktober 2026 · Trareon Transcribe Sprint 7 · Dokumen ini akan
basi: tanggal verifikasi setiap sitasi dicantumkan di masing-masing berkas.*
