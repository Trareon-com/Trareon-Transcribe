# kasus
id: 12-rapat-insiden-siber
judul: Rapat Penanganan Insiden Keamanan Informasi pada Layanan Aduan
templat: notulen_ringkas
jenis: rapat penanganan insiden
sumber: sintetis
menit: 7
ciri: code-switching teknis, urgensi, keputusan cepat

# transkrip
[00:00] Ketua Tim Tanggap Insiden: kita mulai, ini rapat penanganan insiden layanan aduan
[00:11] Ketua Tim Tanggap Insiden: tolong ringkas, apa yang terjadi
[00:19] Analis Keamanan: kemarin jam sebelas malam ada upaya login brute force ke panel admin layanan aduan
[00:33] Analis Keamanan: ada sekitar dua belas ribu percobaan dari empat puluh alamat protokol internet berbeda
[00:47] Analis Keamanan: satu akun berhasil ditembus, akun operator dengan sandi lemah
[01:00] Ketua Tim Tanggap Insiden: ada data yang keluar
[01:07] Analis Keamanan: dari log, akun itu membuka halaman daftar aduan tiga kali, tidak ada unduhan massal
[01:21] Analis Keamanan: tapi kami tidak bisa pastikan tidak ada tangkapan layar
[01:31] Pengelola Aplikasi: akun itu sudah kami nonaktifkan jam satu pagi
[01:41] Ketua Tim Tanggap Insiden: bagus. sekarang keputusan yang perlu diambil
[01:51] Ketua Tim Tanggap Insiden: pertama, pembatasan percobaan login
[01:59] Pengelola Aplikasi: kami bisa aktifkan pembatasan laju dan autentikasi dua faktor untuk semua akun admin
[02:12] Pengelola Aplikasi: autentikasi dua faktor perlu dua hari karena harus sosialisasi ke operator
[02:25] Ketua Tim Tanggap Insiden: pembatasan laju hari ini, autentikasi dua faktor paling lambat delapan Oktober dua ribu dua puluh enam
[02:40] Pengelola Aplikasi: siap
[02:45] Ketua Tim Tanggap Insiden: kedua, reset sandi
[02:52] Pengelola Aplikasi: kami reset paksa semua sandi akun admin dan operator hari ini
[03:03] Ketua Tim Tanggap Insiden: setuju, reset paksa hari ini
[03:12] Pelindungan Data: izin, kalau ada kemungkinan data pribadi pelapor terekspos, ada kewajiban pemberitahuan
[03:26] Pelindungan Data: Undang-Undang Pelindungan Data Pribadi mewajibkan pemberitahuan dalam tiga kali dua puluh empat jam
[03:40] Ketua Tim Tanggap Insiden: itu penting. apakah kita sudah bisa menyimpulkan ada eksposur
[03:51] Analis Keamanan: belum, kami perlu analisis log lengkap, perlu satu hari
[04:02] Ketua Tim Tanggap Insiden: baik, analisis log selesai besok, lalu kita putuskan soal pemberitahuan
[04:14] Pelindungan Data: saya siapkan draf pemberitahuan sebagai antisipasi
[04:24] Ketua Tim Tanggap Insiden: silakan, siapkan draf tapi jangan dikirim sebelum ada kesimpulan
[04:36] Ketua Tim Tanggap Insiden: ketiga, laporan ke pimpinan
[04:44] Ketua Tim Tanggap Insiden: saya yang lapor ke Sekretaris Direktorat Jenderal siang ini
[04:54] Analis Keamanan: saya kirim ringkasan teknis satu halaman untuk bahan laporan
[05:05] Ketua Tim Tanggap Insiden: cukup. kita rapat lagi besok jam empat sore
[05:16] Pengelola Aplikasi: siap

# referensi
## Ringkasan
Rapat penanganan insiden membahas upaya penembusan panel administrasi layanan aduan yang terjadi pada malam sebelumnya, dengan satu akun operator berhasil ditembus. Rapat memutuskan pengamanan teknis segera, penyetelan ulang sandi, penyelesaian analisis catatan sistem sebelum menetapkan kewajiban pemberitahuan, serta pelaporan kepada pimpinan.

## Pembahasan
### Kronologi dan Dampak
Terjadi upaya penembusan sandi secara paksa terhadap panel administrasi layanan aduan pada pukul 23.00 dengan sekitar 12.000 (dua belas ribu) percobaan dari 40 (empat puluh) alamat protokol internet berbeda. Satu akun operator dengan sandi lemah berhasil ditembus dan telah dinonaktifkan pada pukul 01.00. Catatan sistem menunjukkan akun tersebut membuka halaman daftar aduan 3 (tiga) kali tanpa pengunduhan massal, namun kemungkinan tangkapan layar belum dapat dipastikan.

### Kewajiban Pemberitahuan
Unit Pelindungan Data menyampaikan bahwa Undang-Undang tentang Pelindungan Data Pribadi mewajibkan pemberitahuan dalam 3 x 24 (tiga kali dua puluh empat) jam apabila terdapat kemungkinan data pribadi pelapor terekspos. Kesimpulan mengenai ada atau tidaknya eksposur memerlukan analisis catatan sistem secara lengkap.

## Keputusan
1. Pembatasan laju percobaan login diaktifkan pada hari ini.
2. Autentikasi dua faktor diterapkan untuk seluruh akun administrator paling lambat 8 Oktober 2026.
3. Penyetelan ulang sandi secara paksa dilakukan pada hari ini untuk seluruh akun administrator dan operator.
4. Draf pemberitahuan insiden disiapkan namun tidak dikirim sebelum kesimpulan analisis catatan sistem tersedia.
5. Rapat lanjutan diselenggarakan pada hari berikutnya pukul 16.00.

## Tindak Lanjut
| Tugas | Penanggung Jawab | Tenggat |
|---|---|---|
| Mengaktifkan pembatasan laju percobaan login | Pengelola Aplikasi | Hari ini |
| Menerapkan autentikasi dua faktor untuk akun administrator | Pengelola Aplikasi | 8 Oktober 2026 |
| Melakukan penyetelan ulang sandi secara paksa | Pengelola Aplikasi | Hari ini |
| Menyelesaikan analisis catatan sistem secara lengkap | Analis Keamanan | Besok |
| Menyiapkan draf pemberitahuan insiden | Unit Pelindungan Data | Besok |
| Melaporkan insiden kepada Sekretaris Direktorat Jenderal | Ketua Tim Tanggap Insiden | Hari ini |
| Mengirimkan ringkasan teknis satu halaman sebagai bahan laporan | Analis Keamanan | Hari ini |

# emas
## peserta
- Ketua Tim Tanggap Insiden
- Analis Keamanan
- Pengelola Aplikasi
- Pelindungan Data
## keputusan
- Pembatasan laju percobaan login diaktifkan hari ini.
- Autentikasi dua faktor diterapkan untuk seluruh akun administrator paling lambat 8 Oktober 2026.
- Penyetelan ulang sandi secara paksa dilakukan hari ini untuk akun administrator dan operator.
- Draf pemberitahuan insiden disiapkan namun tidak dikirim sebelum kesimpulan analisis catatan sistem tersedia.
- Rapat lanjutan diselenggarakan besok pukul 16.00.
## tindak_lanjut
- Mengaktifkan pembatasan laju percobaan login | Pengelola Aplikasi | hari ini
- Menerapkan autentikasi dua faktor untuk akun administrator | Pengelola Aplikasi | 8 Oktober 2026
- Melakukan penyetelan ulang sandi secara paksa | Pengelola Aplikasi | hari ini
- Menyelesaikan analisis catatan sistem secara lengkap | Analis Keamanan | besok
- Menyiapkan draf pemberitahuan insiden | Pelindungan Data | besok
- Melaporkan insiden kepada Sekretaris Direktorat Jenderal | Ketua Tim Tanggap Insiden | hari ini
- Mengirimkan ringkasan teknis satu halaman sebagai bahan laporan | Analis Keamanan | hari ini
