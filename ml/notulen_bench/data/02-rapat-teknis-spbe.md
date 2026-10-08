# kasus
id: 02-rapat-teknis-spbe
judul: Rapat Teknis Integrasi Aplikasi Layanan dengan Portal SPBE
templat: notulen_dinas
jenis: rapat teknis
sumber: sintetis
menit: 10
ciri: code-switching ID-EN berat, istilah teknis

# transkrip
[00:00] Ketua Tim Transformasi Digital: oke teman-teman, kita mulai rapat teknis integrasi aplikasi layanan dengan portal sistem pemerintahan berbasis elektronik
[00:14] Ketua Tim Transformasi Digital: hari ini saya ingin dapat tiga hal, status integrasi, blocker, dan timeline
[00:26] Pengembang Backend: untuk status, endpoint authentication sudah selesai, kita pakai single sign on dari portal
[00:38] Pengembang Backend: tapi endpoint pengiriman data layanan masih pending karena skemanya belum final dari pusat data
[00:52] Pengelola Pusat Data: skema sudah kami kirim Rabu lalu versi nol titik sembilan, tapi memang masih draft
[01:05] Pengembang Backend: nah itu masalahnya, kalau skema masih berubah kami harus refactor dua kali
[01:17] Ketua Tim Transformasi Digital: kapan skema bisa final
[01:23] Pengelola Pusat Data: kalau tidak ada perubahan dari biro hukum, dua minggu, jadi dua puluh Oktober
[01:35] Ketua Tim Transformasi Digital: kita pegang dua puluh Oktober dua ribu dua puluh enam sebagai tanggal final skema
[01:47] Pengelola Pusat Data: siap, saya yang pegang, atas nama pusat data
[01:55] Ketua Tim Transformasi Digital: kedua, blocker apa lagi selain skema
[02:03] Pengembang Frontend: dari sisi frontend, kami belum dapat akses ke environment staging portal
[02:14] Pengembang Frontend: jadi testing masih pakai mock, dan itu tidak bisa dipertanggungjawabkan untuk uji terima
[02:27] Pengelola Pusat Data: akses staging perlu surat permintaan resmi dari unit, bukan permintaan lewat chat
[02:39] Ketua Tim Transformasi Digital: baik, berarti kita buat nota dinas permintaan akses staging
[02:49] Ketua Tim Transformasi Digital: Bu Ratna dari sekretariat, bisa dibantu konsep nota dinasnya
[02:59] Sekretariat: bisa Pak, saya butuh daftar nama dan alamat surat elektronik yang perlu akses
[03:11] Pengembang Frontend: akan saya kirim hari ini, ada tiga orang
[03:19] Ketua Tim Transformasi Digital: nota dinas kita targetkan keluar tanggal sepuluh Oktober dua ribu dua puluh enam
[03:30] Sekretariat: siap Pak
[03:34] Ketua Tim Transformasi Digital: ketiga, timeline keseluruhan
[03:41] Pengembang Backend: kalau skema final dua puluh Oktober, integrasi selesai akhir November, lalu uji terima Desember
[03:55] Pengelola Pusat Data: uji terima harus melibatkan tim keamanan informasi juga, Pak
[04:06] Ketua Tim Transformasi Digital: betul, penetration test wajib sebelum go live
[04:15] Ketua Tim Transformasi Digital: jadi keputusannya, uji terima mencakup uji keamanan dan tidak boleh go live sebelum uji keamanan selesai
[04:30] Pengembang Backend: noted Pak
[04:34] Ketua Tim Transformasi Digital: satu hal lagi, saya minta semua perubahan skema dicatat di dokumen perubahan, jangan lewat percakapan
[04:49] Pengelola Pusat Data: setuju, kami akan buat dokumen riwayat perubahan skema
[05:00] Ketua Tim Transformasi Digital: tenggatnya ikut tanggal skema final ya, dua puluh Oktober
[05:10] Pengelola Pusat Data: siap
[05:14] Ketua Tim Transformasi Digital: oke, cukup. terima kasih semua

# referensi
## Pembahasan
### Status Integrasi
Pengembang Backend melaporkan bahwa endpoint autentikasi telah selesai dan menggunakan layanan single sign-on dari portal Sistem Pemerintahan Berbasis Elektronik. Endpoint pengiriman data layanan belum dapat diselesaikan karena skema data dari Pusat Data masih berstatus draf versi 0.9, sehingga penyelesaiannya berisiko memerlukan pengerjaan ulang.

### Hambatan Akses Lingkungan Uji
Pengembang Frontend menyampaikan bahwa pengujian masih menggunakan data tiruan karena belum memperoleh akses ke lingkungan uji portal. Pengelola Pusat Data menjelaskan bahwa pemberian akses memerlukan permintaan resmi melalui naskah dinas, bukan permintaan melalui aplikasi percakapan.

### Rencana Waktu dan Uji Terima
Dengan skema final pada 20 Oktober 2026, integrasi diperkirakan selesai pada akhir November 2026 dan uji terima dilaksanakan pada Desember 2026. Rapat menegaskan bahwa uji terima harus mencakup pengujian keamanan oleh tim keamanan informasi, serta bahwa seluruh perubahan skema harus dicatat dalam dokumen riwayat perubahan.

## Keputusan
1. Skema data layanan ditetapkan final pada 20 Oktober 2026.
2. Permintaan akses lingkungan uji portal diajukan melalui nota dinas resmi.
3. Uji terima wajib mencakup pengujian keamanan, dan penerapan ke lingkungan produksi tidak dilaksanakan sebelum pengujian keamanan selesai.
4. Seluruh perubahan skema dicatat dalam dokumen riwayat perubahan, tidak melalui aplikasi percakapan.

## Tindak Lanjut
| Tugas | Penanggung Jawab | Tenggat |
|---|---|---|
| Menetapkan skema data layanan versi final | Pengelola Pusat Data | 20 Oktober 2026 |
| Mengirimkan daftar nama dan alamat surat elektronik yang memerlukan akses lingkungan uji | Pengembang Frontend | Hari ini |
| Menyusun konsep nota dinas permintaan akses lingkungan uji | Ratna, Sekretariat | 10 Oktober 2026 |
| Menyusun dokumen riwayat perubahan skema | Pengelola Pusat Data | 20 Oktober 2026 |

# emas
## peserta
- Ketua Tim Transformasi Digital
- Pengembang Backend
- Pengembang Frontend
- Pengelola Pusat Data
- Sekretariat
## keputusan
- Skema data layanan ditetapkan final pada 20 Oktober 2026.
- Permintaan akses lingkungan uji portal diajukan melalui nota dinas resmi.
- Uji terima wajib mencakup pengujian keamanan dan tidak boleh ada penerapan produksi sebelum uji keamanan selesai.
- Seluruh perubahan skema dicatat dalam dokumen riwayat perubahan.
## tindak_lanjut
- Menetapkan skema data layanan versi final | Pengelola Pusat Data | 20 Oktober 2026
- Mengirimkan daftar nama dan alamat surat elektronik yang perlu akses lingkungan uji | Pengembang Frontend | hari ini
- Menyusun konsep nota dinas permintaan akses lingkungan uji | Ratna | 10 Oktober 2026
- Menyusun dokumen riwayat perubahan skema | Pengelola Pusat Data | 20 Oktober 2026
