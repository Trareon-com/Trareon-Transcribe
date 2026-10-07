# kasus
id: 15-sprint-planning
judul: Rapat Perencanaan Iterasi Pengembangan Aplikasi Internal
templat: notulen_ringkas
jenis: rapat perencanaan iterasi
sumber: sintetis
menit: 7
ciri: code-switching ID-EN sangat berat, istilah asing tanpa padanan

# transkrip
[00:00] Manajer Produk: oke sprint planning kita mulai, sprint dua puluh tiga
[00:10] Manajer Produk: kapasitas tim minggu ini turun karena Dika cuti dua hari
[00:21] Pemimpin Teknis: jadi velocity kita anggap tiga puluh poin bukan tiga puluh lima
[00:32] Manajer Produk: setuju. backlog teratas ada tiga item
[00:41] Manajer Produk: pertama, single sign on integration, estimasi delapan poin
[00:52] Manajer Produk: kedua, audit log viewer, estimasi tiga belas poin
[01:03] Manajer Produk: ketiga, bulk export, estimasi delapan poin
[01:13] Pemimpin Teknis: kalau semua diambil tiga puluh lima poin, lewat kapasitas
[01:23] Manajer Produk: mana yang paling urgent
[01:30] Pemilik Produk: single sign on wajib, itu syarat dari tim keamanan sebelum rilis
[01:42] Pemilik Produk: audit log viewer diminta auditor internal, tapi deadline-nya akhir bulan
[01:54] Pemilik Produk: bulk export permintaan pengguna, bisa ditunda
[02:04] Manajer Produk: berarti sprint ini single sign on dan audit log viewer, bulk export keluar dari sprint
[02:18] Pemimpin Teknis: delapan tambah tiga belas sama dengan dua puluh satu, masih ada ruang sembilan poin
[02:30] Manajer Produk: sisanya kita pakai untuk technical debt, bukan ambil item baru
[02:41] Pemimpin Teknis: setuju, saya usul refactor modul notifikasi, estimasi lima poin
[02:53] Manajer Produk: ambil itu. sisa empat poin biarkan sebagai buffer
[03:04] Pemimpin Teknis: oke
[03:08] Manajer Produk: ada risiko apa di single sign on
[03:17] Pengembang: dokumentasi penyedia identitas tidak lengkap, kita mungkin perlu tanya langsung
[03:29] Manajer Produk: siapa kontaknya
[03:35] Pengembang: lewat tim infrastruktur, Bu Sari
[03:43] Manajer Produk: Pengembang yang kirim pertanyaan ke Bu Sari hari ini, jangan tunggu sampai blocked
[03:55] Pengembang: siap
[04:00] Manajer Produk: satu lagi, definition of done kita perjelas
[04:09] Manajer Produk: mulai sprint ini, item belum done kalau belum ada uji otomatis dan belum lewat review aksesibilitas
[04:24] Pemimpin Teknis: itu akan memperlambat di awal tapi bagus
[04:34] Manajer Produk: kita coba satu sprint lalu evaluasi
[04:43] Pemilik Produk: catat juga bulk export dijanjikan ke pengguna sprint depan, jangan sampai lupa
[04:55] Manajer Produk: dicatat, bulk export masuk sprint dua puluh empat
[05:05] Manajer Produk: sudah, sprint planning selesai

# referensi
## Ringkasan
Rapat perencanaan iterasi ke-23 menetapkan lingkup pekerjaan sesuai kapasitas tim yang berkurang, memprioritaskan integrasi layanan masuk tunggal dan penampil catatan audit, serta memperketat kriteria penyelesaian pekerjaan.

## Pembahasan
### Kapasitas dan Prioritas
Kapasitas tim pada iterasi ini diperkirakan 30 (tiga puluh) poin, lebih rendah dari 35 (tiga puluh lima) poin karena satu anggota tim mengambil cuti 2 (dua) hari. Tiga pekerjaan teratas memiliki estimasi 8 (delapan) poin untuk integrasi layanan masuk tunggal, 13 (tiga belas) poin untuk penampil catatan audit, dan 8 (delapan) poin untuk ekspor massal, sehingga seluruhnya melampaui kapasitas.

Pemilik Produk menyampaikan bahwa integrasi layanan masuk tunggal merupakan syarat tim keamanan sebelum perilisan, penampil catatan audit diminta auditor internal dengan batas akhir bulan, dan ekspor massal dapat ditunda.

### Risiko dan Kriteria Penyelesaian
Risiko pada integrasi layanan masuk tunggal adalah dokumentasi penyedia identitas yang tidak lengkap, sehingga diperlukan pertanyaan langsung melalui tim infrastruktur. Rapat juga membahas pengetatan kriteria penyelesaian pekerjaan.

## Keputusan
1. Iterasi ke-23 mencakup integrasi layanan masuk tunggal dan penampil catatan audit; ekspor massal dikeluarkan dari iterasi ini dan dijadwalkan pada iterasi ke-24.
2. Sisa kapasitas digunakan untuk pembenahan utang teknis berupa penataan ulang modul notifikasi sebesar 5 (lima) poin, dan 4 (empat) poin disisakan sebagai penyangga.
3. Mulai iterasi ini, suatu pekerjaan dinyatakan selesai hanya apabila telah memiliki uji otomatis dan telah melewati tinjauan aksesibilitas, dengan evaluasi setelah satu iterasi.

## Tindak Lanjut
| Tugas | Penanggung Jawab | Tenggat |
|---|---|---|
| Mengirimkan pertanyaan mengenai dokumentasi penyedia identitas kepada tim infrastruktur | Pengembang | Hari ini |
| Melaksanakan penataan ulang modul notifikasi | Pemimpin Teknis | Dalam iterasi ini |

# emas
## peserta
- Manajer Produk
- Pemimpin Teknis
- Pemilik Produk
- Pengembang
## keputusan
- Iterasi ke-23 mencakup integrasi layanan masuk tunggal dan penampil catatan audit, sedangkan ekspor massal dijadwalkan pada iterasi ke-24.
- Sisa kapasitas digunakan untuk penataan ulang modul notifikasi lima poin dan empat poin disisakan sebagai penyangga.
- Suatu pekerjaan dinyatakan selesai hanya apabila telah memiliki uji otomatis dan telah melewati tinjauan aksesibilitas.
## tindak_lanjut
- Mengirimkan pertanyaan mengenai dokumentasi penyedia identitas kepada tim infrastruktur | Pengembang | hari ini
- Melaksanakan penataan ulang modul notifikasi | Pemimpin Teknis | dalam iterasi ini
