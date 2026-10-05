# Formulir Persetujuan Perekaman Suara
### Pengumpulan Data Latih ASR Bahasa Indonesia–Inggris (Trareon Transcribe)

**Versi dokumen:** 1.0 · **Tanggal:** 5 Oktober 2026
**Pengendali Data Pribadi:** *(isi: nama badan/perorangan, alamat, kontak)*
**Narahubung pelindungan data:** *(isi: nama, email, nomor telepon)*

Dokumen ini disusun mengikuti Undang-Undang Nomor 27 Tahun 2022 tentang
Pelindungan Data Pribadi (UU PDP) dan Peraturan Pemerintah Nomor 33 Tahun 2026
sebagai peraturan pelaksananya.

---

## 1. Apa yang kami minta

Kami meminta izin merekam suara Anda selama satu sesi rapat/percakapan
terstruktur berdurasi sekitar 30–60 menit, serta menggunakan rekaman itu dan
transkripnya untuk **melatih dan menguji model pengenalan suara otomatis
(ASR)** Bahasa Indonesia yang bercampur Bahasa Inggris.

## 2. Mengapa data ini dibutuhkan

Model pengenalan suara yang tersedia saat ini bekerja buruk pada rapat
Bahasa Indonesia yang bercampur istilah Inggris. Tidak ada kumpulan data
terbuka untuk kondisi ini, sehingga data harus direkam sendiri dengan
persetujuan. Hasilnya dipakai agar aplikasi transkripsi dapat bekerja
**sepenuhnya di perangkat pengguna (offline)**.

## 3. Dasar hukum pemrosesan

**Persetujuan Anda** (UU PDP Pasal 20 ayat (2) huruf a). Persetujuan ini
spesifik, diberikan secara sadar, dan dapat ditarik kembali kapan saja.

## 4. Data pribadi yang diproses

| Jenis data | Keterangan | Wajib? |
|---|---|---|
| Rekaman suara | Audio sesi, 16 kHz mono | Ya |
| Transkrip | Teks hasil koreksi manual dari rekaman | Ya |
| Nama/label penutur | Dipakai **hanya** sebagai label "Penutur A/B/C" di dalam dataset | Tidak |
| Rentang usia, jenis kelamin, daerah asal/aksen | Untuk melaporkan keberagaman data secara agregat | Tidak |
| Kontak (email/telepon) | Hanya untuk menghubungi Anda bila menarik persetujuan | Ya |

**Yang TIDAK kami lakukan:**

- Kami **tidak** membuat atau menyimpan *voice profile* / *speaker embedding*
  — yaitu sidik suara numerik yang dapat dipakai mengenali seseorang di
  rekaman lain. Suara dapat tergolong **data biometrik** menurut UU PDP
  apabila dipakai untuk identifikasi unik; kami tidak memakainya demikian.
- Kami **tidak** memakai data ini untuk verifikasi identitas, otentikasi,
  pemantauan kinerja, atau keperluan kepegawaian apa pun.
- Kami **tidak** menjual data ini kepada pihak lain.

## 5. Apa yang akan dirilis ke publik

Beri tanda pada pilihan Anda (boleh memilih tingkat terkecil):

- [ ] **Tingkat 1 — Internal saja.** Rekaman dan transkrip hanya dipakai di
      dalam proyek; tidak ada yang dipublikasikan.
- [ ] **Tingkat 2 — Model saja.** Rekaman tidak dipublikasikan; hanya model
      hasil latihan yang dirilis. (Catatan jujur: model hasil latihan secara
      teoretis dapat mengingat potongan data latih, walau risikonya kecil
      untuk model ASR berukuran ini.)
- [ ] **Tingkat 3 — Dataset publik.** Rekaman dan transkrip dirilis sebagai
      dataset terbuka dengan label penutur anonim (Penutur A/B/C).

## 6. Penyimpanan dan keamanan

- Audio mentah disimpan terenkripsi di perangkat pengendali data; tidak
  diunggah ke layanan awan pihak ketiga.
- Transkrip disimpan terpisah dari data kontak Anda.
- Akses dibatasi pada orang yang mengerjakan proyek ini.

## 7. Jangka waktu penyimpanan

- **Audio mentah:** *(isi, disarankan maksimal 3 tahun)* sejak perekaman.
- **Dataset turunan (potongan + transkrip):* selama model masih dipelihara,
  maksimal *(isi, disarankan 5 tahun)*, setelah itu dinilai ulang atau dihapus.
- Bila Anda menarik persetujuan, lihat butir 9.

## 8. Hak Anda (UU PDP Pasal 5–15)

Anda berhak untuk:

1. mendapatkan informasi tentang pemrosesan data Anda (dokumen ini);
2. **mengakses** dan memperoleh salinan rekaman serta transkrip Anda;
3. **memperbaiki** transkrip yang salah;
4. **menghapus** data Anda (*hak untuk dilupakan*);
5. **menarik persetujuan** kapan saja;
6. **menolak** pengambilan keputusan otomatis;
7. menunda atau membatasi pemrosesan;
8. mengajukan **keberatan atau gugatan** atas pelanggaran.

Permintaan dikirim ke narahubung di bagian atas dokumen ini dan akan
ditindaklanjuti **paling lama 3×24 jam** untuk konfirmasi dan
**maksimal 14 hari kerja** untuk penyelesaian.

## 9. Jika Anda menarik persetujuan

- Rekaman Anda dan potongan yang berasal darinya **dihapus** dari dataset,
  dan dataset versi berikutnya dirilis tanpanya.
- **Yang tidak dapat kami janjikan:** model yang **sudah dirilis** sebelum
  penarikan tidak dapat "dilatih ulang untuk melupakan" Anda secara seketika.
  Kami akan mengeluarkan data Anda dari pelatihan berikutnya dan mencatat
  penghapusan itu di *model card*. Kami menyampaikan hal ini di muka agar
  persetujuan Anda benar-benar berdasar informasi.

## 10. Risiko

- Rekaman memuat suara dan isi ucapan Anda. Pada Tingkat 3, siapa pun dapat
  mendengarkannya.
- Jangan menyebut data pribadi sensitif (nomor rekening, NIK, data kesehatan,
  rahasia perusahaan) selama sesi. Fasilitator akan mengingatkan.
- Bila hal sensitif tetap terucap, beri tahu fasilitator; bagian itu akan
  dipotong dari rekaman sebelum diproses.

## 11. Sifat sukarela

Keikutsertaan bersifat **sukarela sepenuhnya**. Anda dapat menolak atau
berhenti di tengah sesi tanpa alasan dan **tanpa konsekuensi apa pun**,
termasuk tidak ada akibat terhadap hubungan kerja atau penilaian apa pun.

---

## Pernyataan Persetujuan

Dengan menandatangani di bawah ini, saya menyatakan bahwa:

- saya telah membaca dan memahami dokumen ini;
- saya diberi kesempatan bertanya dan pertanyaan saya telah dijawab;
- saya memberikan persetujuan secara sukarela untuk perekaman dan penggunaan
  sebagaimana dijelaskan, pada tingkat publikasi yang saya tandai di butir 5.

| | |
|---|---|
| Nama lengkap | ............................................ |
| Label penutur dalam dataset | Penutur ......... |
| Kontak (email/telepon) | ............................................ |
| Rentang usia *(opsional)* | ☐ 18–25 ☐ 26–35 ☐ 36–45 ☐ 46–55 ☐ 56+ |
| Jenis kelamin *(opsional)* | ............................................ |
| Daerah asal / aksen *(opsional)* | ............................................ |
| Tingkat publikasi (butir 5) | ☐ Tingkat 1 ☐ Tingkat 2 ☐ Tingkat 3 |
| Tanda tangan | ............................................ |
| Tanggal | ............................................ |

**Fasilitator**

| | |
|---|---|
| Nama | ............................................ |
| Tanda tangan | ............................................ |
| Tanggal | ............................................ |

---

*Satu salinan untuk peserta, satu untuk pengendali data. Simpan salinan
terpisah dari rekaman.*

> **Catatan:** dokumen ini disusun dengan itikad baik mengikuti UU PDP dan
> PP 33/2026, tetapi **bukan nasihat hukum**. Mintalah penelaahan ahli hukum
> sebelum dipakai pada pengumpulan data berskala besar atau lintas organisasi.
