# kasus
id: 20-rapat-transkrip-berisik
judul: Rapat Koordinasi Pemindahan Pusat Data
templat: notulen_dinas
jenis: rapat koordinasi
sumber: sintetis
menit: 9
ciri: transkrip dengan salah dengar dan disfluensi, uji ketahanan

# transkrip
[00:00] Pimpinan Rapat: eh selamat pagi, ya, rapat koordinasi pemindahan pusat data ini kita mulai ya
[00:14] Pimpinan Rapat: jadi anu, intinya kita harus pindah dari ruang server lama ke pusat data nasional
[00:28] Pimpinan Rapat: eh, mohon, tolong siapa yang punya datanya
[00:37] Pengelola Infrastruktur: saya Pak, jadi kita punya eh empat puluh dua server fisik, tapi yang masih aktif tiga puluh satu
[00:52] Pengelola Infrastruktur: sebelas sudah eh di luar masa pakai, itu bisa langsung dihapuskan
[01:04] Pimpinan Rapat: tiga puluh satu itu semuanya harus pindah
[01:13] Pengelola Infrastruktur: idealnya tidak Pak, sembilan belas bisa dijadikan mesin virtual, sisanya dua belas harus fisik
[01:28] Pengelola Aplikasi: eh izin, dua belas itu yang mana
[01:37] Pengelola Infrastruktur: yang basis data besar dan yang eh yang pakai perangkat keras khusus
[01:49] Pengelola Aplikasi: oh, kalau basis data besar itu sebenarnya bisa Pak, tapi eh butuh uji beban dulu
[02:02] Pimpinan Rapat: ya sudah, kita uji dulu, jangan asal pindah
[02:12] Pimpinan Rapat: eh berapa lama uji bebannya
[02:20] Pengelola Aplikasi: dua pekan Pak untuk tiga basis data utama
[02:29] Pimpinan Rapat: baik, uji beban tiga basis data utama dua pekan, jadi eh dua puluh Oktober dua ribu dua puluh enam
[02:44] Pengelola Aplikasi: siap Pak
[02:49] Pimpinan Rapat: terus, eh, jadwal pemindahannya
[02:58] Pengelola Infrastruktur: usulan kami akhir November sampai Desember, bertahap, tiga gelombang
[03:11] Pimpinan Rapat: kenapa tidak sekaligus
[03:18] Pengelola Infrastruktur: kalau sekaligus layanan mati lebih dari dua hari Pak, itu tidak bisa diterima
[03:31] Pimpinan Rapat: betul, eh, jadi bertahap, tiga gelombang
[03:41] Pengelola Jaringan: Pak, mohon diperhatikan juga sambungan jaringan ke pusat data nasional
[03:53] Pengelola Jaringan: sekarang kita cuma punya satu jalur, kalau putus layanan mati total
[04:04] Pimpinan Rapat: berarti perlu jalur kedua
[04:12] Pengelola Jaringan: perlu Pak, tapi pengadaan jalur kedua itu eh butuh waktu dan anggaran
[04:24] Pimpinan Rapat: ya, tapi tidak boleh kita pindah tanpa jalur kedua
[04:35] Pimpinan Rapat: jadi keputusannya, pemindahan tidak dimulai sebelum jalur jaringan kedua tersedia
[04:48] Pengelola Jaringan: siap Pak, saya hitung kebutuhannya
[04:57] Pimpinan Rapat: eh kapan hitungannya selesai
[05:05] Pengelola Jaringan: sepuluh Oktober dua ribu dua puluh enam Pak
[05:14] Pimpinan Rapat: baik. terus server yang sebelas unit itu
[05:24] Pengelola Infrastruktur: usul kami dihapuskan, prosesnya lewat Bagian Umum
[05:35] Pimpinan Rapat: ya, eh, Bagian Umum tolong proses penghapusan sebelas server
[05:47] Kepala Bagian Umum: baik Pak, tapi eh harus ada berita acara kondisi dari pengelola infrastruktur dulu
[06:00] Pengelola Infrastruktur: saya siapkan, tiga hari kerja
[06:09] Pimpinan Rapat: oke eh, sudah ya, saya tutup rapatnya, terima kasih

# referensi
## Pembahasan
### Kondisi Server
Terdapat 42 (empat puluh dua) server fisik, dengan 31 (tiga puluh satu) di antaranya masih aktif dan 11 (sebelas) telah melewati masa pakai sehingga diusulkan untuk dihapuskan. Dari 31 (tiga puluh satu) server aktif, 19 (sembilan belas) dapat dijadikan mesin virtual, sedangkan 12 (dua belas) dinilai harus tetap berbentuk fisik karena memuat basis data besar atau menggunakan perangkat keras khusus. Pengelola Aplikasi menyampaikan bahwa basis data besar sebenarnya dapat dipindahkan setelah dilakukan uji beban.

### Jadwal Pemindahan
Pemindahan diusulkan berlangsung bertahap dalam 3 (tiga) gelombang pada akhir November sampai Desember 2026, karena pemindahan sekaligus mengakibatkan layanan berhenti lebih dari 2 (dua) hari.

### Kesiapan Jaringan
Pengelola Jaringan menyampaikan bahwa sambungan ke pusat data nasional saat ini hanya 1 (satu) jalur, sehingga kegagalan jalur tersebut mengakibatkan layanan berhenti total. Pengadaan jalur kedua memerlukan waktu dan anggaran.

## Keputusan
1. Pemindahan pusat data dilaksanakan secara bertahap dalam 3 (tiga) gelombang, tidak sekaligus.
2. Pemindahan tidak dimulai sebelum jalur jaringan kedua tersedia.
3. Pemindahan basis data besar didahului uji beban.
4. Sebanyak 11 (sebelas) server yang telah melewati masa pakai diproses penghapusannya melalui Bagian Umum.

## Tindak Lanjut
| Tugas | Penanggung Jawab | Tenggat |
|---|---|---|
| Melaksanakan uji beban 3 (tiga) basis data utama | Pengelola Aplikasi | 20 Oktober 2026 |
| Menghitung kebutuhan jalur jaringan kedua | Pengelola Jaringan | 10 Oktober 2026 |
| Menyiapkan berita acara kondisi 11 (sebelas) server | Pengelola Infrastruktur | 3 (tiga) hari kerja |
| Memproses penghapusan 11 (sebelas) server | Kepala Bagian Umum | Setelah berita acara kondisi tersedia |

# emas
## peserta
- Pimpinan Rapat
- Pengelola Infrastruktur
- Pengelola Aplikasi
- Pengelola Jaringan
- Kepala Bagian Umum
## keputusan
- Pemindahan pusat data dilaksanakan bertahap dalam tiga gelombang, tidak sekaligus.
- Pemindahan tidak dimulai sebelum jalur jaringan kedua tersedia.
- Pemindahan basis data besar didahului uji beban.
- Sebelas server yang telah melewati masa pakai diproses penghapusannya melalui Bagian Umum.
## tindak_lanjut
- Melaksanakan uji beban tiga basis data utama | Pengelola Aplikasi | 20 Oktober 2026
- Menghitung kebutuhan jalur jaringan kedua | Pengelola Jaringan | 10 Oktober 2026
- Menyiapkan berita acara kondisi sebelas server | Pengelola Infrastruktur | tiga hari kerja
- Memproses penghapusan sebelas server | Kepala Bagian Umum | setelah berita acara kondisi tersedia
