# kasus
id: 05-standup-produk
judul: Rapat Harian Tim Produk Layanan Digital
templat: notulen_ringkas
jenis: rapat harian
sumber: sintetis
menit: 6
ciri: code-switching ID-EN berat, ragam percakapan, ringkas

# transkrip
[00:00] Ketua Tim: oke standup kita mulai, singkat aja ya, lima belas menit
[00:09] Ketua Tim: mulai dari Rizky
[00:14] Rizky: kemarin aku selesaiin migrasi database ke versi baru, udah jalan di staging
[00:25] Rizky: hari ini mau handle issue timeout di endpoint laporan, kayaknya ada query yang gak pakai index
[00:38] Rizky: blocker belum ada sih
[00:43] Ketua Tim: oke, kalau ternyata perlu downtime kasih tahu aku dulu
[00:52] Rizky: noted
[00:56] Ketua Tim: Lina
[01:00] Lina: aku masih di redesign halaman pencarian, kemarin selesai wireframe, hari ini mulai high fidelity
[01:13] Lina: blockerku copywriting, belum ada teks final buat empty state
[01:23] Ketua Tim: siapa yang pegang copywriting
[01:29] Lina: biasanya tim komunikasi, tapi belum ada yang ditunjuk
[01:38] Ketua Tim: aku yang minta ke tim komunikasi hari ini, biar kamu gak nunggu lama
[01:48] Lina: makasih
[01:52] Ketua Tim: Bayu
[01:56] Bayu: aku kerjain uji coba aksesibilitas, hasilnya ada dua belas temuan
[02:07] Bayu: tujuh soal kontras warna, lima soal urutan fokus keyboard
[02:17] Bayu: yang kontras warna itu harus diputuskan desain dulu, jadi aku butuh Lina
[02:28] Lina: bisa, besok aku sisipkan di high fidelity
[02:36] Ketua Tim: bagus, kita putuskan temuan kontras warna diperbaiki di desain high fidelity, bukan di kode
[02:50] Bayu: sepakat
[02:54] Ketua Tim: urutan fokus keyboard siapa yang benerin
[03:02] Bayu: aku bisa, itu di kode frontend, selesai dua hari
[03:11] Ketua Tim: berarti sembilan Oktober dua ribu dua puluh enam
[03:19] Bayu: iya
[03:23] Ketua Tim: terakhir, pengingat, demo ke pimpinan Jumat ini, jadi jangan ada merge yang berisiko Kamis malam
[03:37] Ketua Tim: kita bekukan kode mulai Kamis jam lima sore
[03:46] Rizky: oke, aku atur migrasi sebelum itu
[03:54] Ketua Tim: sudah ya, bubar

# referensi
## Ringkasan
Rapat harian tim produk membahas kemajuan migrasi basis data, perancangan ulang halaman pencarian, dan hasil uji coba aksesibilitas. Rapat memutuskan penanganan temuan kontras warna pada tahap desain, penugasan perbaikan urutan fokus papan ketik, dan pembekuan kode menjelang pemaparan kepada pimpinan.

## Pembahasan
### Migrasi Basis Data
Migrasi basis data ke versi baru telah selesai dan berjalan pada lingkungan uji. Pekerjaan hari ini difokuskan pada penanganan gangguan waktu tunggu pada layanan laporan yang diduga disebabkan kueri tanpa indeks. Apabila diperlukan penghentian layanan, hal tersebut harus dilaporkan terlebih dahulu kepada Ketua Tim.

### Perancangan Ulang Halaman Pencarian
Kerangka tampilan telah selesai dan pengerjaan tampilan rinci dimulai. Hambatan yang dihadapi adalah belum tersedianya naskah teks final untuk tampilan tanpa hasil, dan belum ada penunjukan penanggung jawab penulisan naskah pada tim komunikasi.

### Uji Coba Aksesibilitas
Uji coba aksesibilitas menghasilkan 12 (dua belas) temuan, terdiri atas 7 (tujuh) temuan kontras warna dan 5 (lima) temuan urutan fokus papan ketik.

## Keputusan
1. Temuan kontras warna diperbaiki pada tahap desain tampilan rinci, bukan pada kode.
2. Pembekuan kode diberlakukan mulai Kamis pukul 17.00 menjelang pemaparan kepada pimpinan pada Jumat.

## Tindak Lanjut
| Tugas | Penanggung Jawab | Tenggat |
|---|---|---|
| Menangani gangguan waktu tunggu pada layanan laporan | Rizky | Hari ini |
| Meminta naskah teks final tampilan tanpa hasil kepada tim komunikasi | Ketua Tim | Hari ini |
| Menyisipkan perbaikan kontras warna pada desain tampilan rinci | Lina | Besok |
| Memperbaiki urutan fokus papan ketik pada kode antarmuka | Bayu | 9 Oktober 2026 |

# emas
## peserta
- Ketua Tim
- Rizky
- Lina
- Bayu
## keputusan
- Temuan kontras warna diperbaiki pada tahap desain tampilan rinci, bukan pada kode.
- Pembekuan kode diberlakukan mulai Kamis pukul 17.00 menjelang pemaparan kepada pimpinan.
## tindak_lanjut
- Menangani gangguan waktu tunggu pada layanan laporan | Rizky | hari ini
- Meminta naskah teks final tampilan tanpa hasil kepada tim komunikasi | Ketua Tim | hari ini
- Menyisipkan perbaikan kontras warna pada desain tampilan rinci | Lina | besok
- Memperbaiki urutan fokus papan ketik pada kode antarmuka | Bayu | 9 Oktober 2026
