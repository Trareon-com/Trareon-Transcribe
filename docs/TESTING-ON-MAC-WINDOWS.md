# Menguji build beta di macOS dan Windows

Dokumen ini untuk pemilik produk yang menguji build beta Trareon Transcribe di
MacBook (Apple Silicon) dan laptop Windows. Build ini **bukan rilis publik**:
tidak ada GitHub Release, tidak ada tautan permanen. Yang ada hanya *artifact*
dari satu kali jalan workflow, dan berlaku 30 hari.

Rilis publik hanya dibuat satu kali, dari tag `v*`, ketika semuanya sudah
lengkap dan akurat.

---

## 1. Menjalankan build

1. Buka repositori di GitHub, lalu tab **Actions**.
2. Di daftar workflow sebelah kiri, pilih **Test builds**.
3. Klik **Run workflow** di kanan atas.
   - Biarkan **bundle_models** dalam keadaan mati untuk unduhan kecil
     (aplikasi mengunduh model saat pertama kali dijalankan).
   - Nyalakan **bundle_models** jika laptop penguji akan dipakai tanpa
     internet sama sekali. Artifact-nya bertambah sekitar 700 MB.
4. Tunggu keempat job selesai (sekitar 20 sampai 35 menit). Job `SHA256SUMS`
   baru jalan setelah ketiga platform selesai.

Workflow ini juga jalan otomatis pada setiap push ke `main`, jadi biasanya
sudah ada build siap pakai tanpa perlu menekan apa pun.

## 2. Mengunduh artifact

1. Klik baris workflow run yang sudah hijau.
2. Gulir ke bagian **Artifacts** di bagian bawah halaman ringkasan run.
3. Unduh yang Anda butuhkan:

| Artifact | Isi |
|---|---|
| `beta-macos-arm64` | `Trareon Transcribe-<versi>.dmg` (ad-hoc signed, arm64) |
| `beta-windows-x64` | `transcribe-<versi>-windows.zip` (portabel) dan `TrareonTranscribe-<versi>-windows-setup.exe` (installer) |
| `beta-linux-x86_64` | `.AppImage` dan `.deb` |
| `beta-SHA256SUMS` | `SHA256SUMS.txt` untuk semua berkas di atas |

GitHub membungkus setiap artifact menjadi `.zip`, jadi berkas yang Anda unduh
perlu diekstrak satu kali sebelum isinya terlihat.

### Memastikan berkas utuh

Setelah mengekstrak, cocokkan sidik jarinya dengan `SHA256SUMS.txt`.

macOS atau Linux:

```sh
shasum -a 256 -c SHA256SUMS.txt
```

Windows (PowerShell):

```powershell
Get-FileHash .\TrareonTranscribe-1.0.0-beta.12-windows-setup.exe -Algorithm SHA256
```

Lalu bandingkan baris yang sesuai di `SHA256SUMS.txt`.

---

## 3. Membuka pertama kali di macOS

Build beta **ditandatangani ad-hoc**, bukan dengan Developer ID Apple, dan
belum dinotarisasi. Gatekeeper akan menolaknya pada percobaan pertama dengan
pesan semacam *"Trareon Transcribe" tidak dapat dibuka karena Apple tidak dapat
memeriksa apakah ada perangkat lunak berbahaya di dalamnya*.

Ini normal untuk beta. Dua cara melewatinya:

**Cara 1, lewat Finder (paling mudah).**
1. Buka `.dmg`, seret **Trareon Transcribe** ke folder **Applications**.
2. Buka folder Applications, **klik kanan** (atau Control-klik) pada
   Trareon Transcribe, pilih **Open**.
3. Pada dialog yang muncul, tekan **Open** sekali lagi.

Hanya perlu sekali. Membuka dengan klik dua kali setelah itu sudah berjalan
normal.

**Cara 2, lewat Terminal.** Jika macOS tetap menolak (kadang terjadi pada
Sequoia ke atas), buang atribut karantinanya:

```sh
xattr -dr com.apple.quarantine "/Applications/Trareon Transcribe.app"
```

Lalu buka seperti biasa.

**Izin yang akan diminta.** Saat pertama kali merekam, macOS akan meminta dua
izin terpisah:

- **Mikrofon**: untuk mode Rapat Offline dan Rapat Online.
- **Perekaman Layar & Audio Sistem**: untuk mode Rapat Online dan Webinar.
  macOS menyatukan audio sistem ke dalam izin ini; aplikasi tidak mengambil
  gambar layar.

Keduanya ada di **System Settings, Privacy & Security**. Setelah memberi izin
Perekaman Layar, macOS meminta aplikasi dijalankan ulang.

---

## 4. Membuka pertama kali di Windows

Build beta tidak ditandatangani dengan sertifikat kode berbayar, jadi
SmartScreen akan menampilkan **"Windows protected your PC"**.

1. Klik **More info**.
2. Klik **Run anyway**.

Untuk `TrareonTranscribe-<versi>-windows-setup.exe`, installer memasang per
pengguna, jadi tidak memerlukan hak administrator. Untuk versi portabel, cukup
ekstrak `.zip` lalu jalankan `transcribe.exe` dari dalam folder hasil ekstrak
(jangan jalankan langsung dari dalam arsip: DLL di sebelahnya tidak akan
terbaca).

Jika Windows Defender atau antivirus kantor mengarantina berkasnya, itu karena
berkasnya belum bertanda tangan, bukan karena isinya. Catat nama deteksinya dan
kirimkan bersama laporan.

---

## 5. Yang perlu diuji

Centang sambil mencoba. Urutannya mengikuti alur kerja nyata.

### Tampilan dan rasa

- [ ] Jendela terbuka pada ukuran 1280x800 dan tidak ada yang terpotong.
- [ ] Mengubah ukuran jendela sampai sekecil 900x600: tidak ada teks terpotong,
      tidak ada tombol yang hilang di luar tepi.
- [ ] Ganti tema di **Pengaturan, Tampilan** antara Terang, Gelap dan Sistem.
      Keduanya terbaca nyaman, tidak ada teks abu-abu di atas abu-abu.
- [ ] Ikon aplikasi terlihat benar di Dock (macOS) dan Taskbar (Windows),
      termasuk pada ukuran kecil.
- [ ] Sidebar bisa disembunyikan dan ditampilkan lagi (tombol di pojok kanan
      atas sidebar, atau pintasan yang tertera di tooltip-nya).
- [ ] Tutup lalu buka lagi aplikasi: ukuran dan posisi jendela diingat.

### Merekam

- [ ] Layar awal menampilkan tiga kartu mode dengan penjelasan satu baris.
- [ ] Pilih mode, isi judul, tekan **Mulai Rekam**.
- [ ] Indikator level mikrofon bergerak saat Anda bicara.
- [ ] Titik merah "sedang merekam" berdenyut pelan, timer berjalan tanpa
      melompat-lompat lebarnya.
- [ ] Badge "rekaman terkonfirmasi" muncul setelah beberapa detik.
- [ ] Tekan tombol tandai (ikon bookmark) di tengah rekaman.
- [ ] Transkrip muncul bertahap. Teks sementara terlihat lebih redup lalu
      menjadi tegas saat final.
- [ ] Tekan **Berhenti**. Ringkasan integritas muncul sebagai panel di bawah,
      bukan sebagai dialog yang menutupi seluruh layar.

### Membaca kembali

- [ ] Sesi yang baru selesai muncul di sidebar di bawah **Hari ini**.
- [ ] Buka sesi itu: kolom bacaan terbatasnya nyaman dibaca, tidak melebar
      sampai ujung layar.
- [ ] Pemutar audio di bawah: tekan play, gelombang dan posisi bergerak.
- [ ] Klik satu baris transkrip: audio melompat ke momen itu.
- [ ] Ubah kecepatan putar.
- [ ] Buat ringkasan, lalu buka **Notulen Resmi** dan lihat pratinjau dokumen
      sebelum mengekspor.

### Impor berkas (tanpa merekam)

- [ ] Sidebar, **Impor berkas**: jatuhkan satu berkas audio.
- [ ] Proses selesai dan hasilnya jadi sesi baru.

### Keyboard

- [ ] Tekan pintasan panel bantuan (tertera di pojok kanan bawah). Semua
      pintasan yang tercantum benar-benar berfungsi.
- [ ] Pada macOS pintasan ditampilkan dengan simbol Command, pada Windows
      dengan tulisan Ctrl.
- [ ] Tab melalui layar utama: setiap kontrol yang disorot punya cincin fokus
      yang terlihat jelas.

### Hal yang sengaja belum diuji di Windows

Perekaman mikrofon atau audio sistem secara langsung di laptop Windows kantor
**tidak dilakukan tanpa izin pemilik**, karena ruangannya dipakai bersama. Uji
Windows pada build ini terbatas pada impor berkas, tampilan, dan pintasan.

---

## 6. Mengirim balik log kalau ada masalah

Aplikasi punya perekam penerbangan (flight recorder) yang mencatat metadata
saja: waktu, nama perangkat, panjang audio, jenis kesalahan. **Tidak ada isi
transkrip dan tidak ada audio di dalamnya.**

1. Buka **Pengaturan**, kategori **Penyiapan & Diagnostik**.
2. Pada kartu **Log Diagnostik**, tekan **Ekspor Log Diagnostik**.
3. Pilih folder tujuan. Berkasnya berupa `.zip`.
4. Kirimkan berkas itu bersama:
   - Sistem operasi dan versinya (misalnya macOS 15.3, atau Windows 11 23H2).
   - Langkah yang Anda lakukan sampai masalahnya muncul.
   - Tangkapan layar, kalau masalahnya kelihatan.
   - Versi beta yang tertera di **Pengaturan, Tentang**.

Kalau aplikasi tidak bisa dibuka sama sekali sehingga menu di atas tidak
terjangkau, lognya tetap ada di disk:

| Platform | Lokasi |
|---|---|
| macOS | `~/Library/Caches/TrareonTranscribe/logs/` |
| Windows | `%LOCALAPPDATA%\TrareonTranscribe\logs\` |
| Linux | `~/.cache/TrareonTranscribe/logs/` |

---

## 7. Mencopot pemasangan

- **macOS**: seret **Trareon Transcribe** dari Applications ke Trash. Data sesi
  tetap ada di `~/TrareonTranscribe` (atau folder perpustakaan yang Anda pilih)
  dan tidak ikut terhapus.
- **Windows (installer)**: Settings, Apps, cari **Trareon Transcribe**,
  Uninstall.
- **Windows (portabel)**: hapus folder hasil ekstrak.

Data rapat tidak pernah ikut terhapus oleh pencopotan. Hapus manual dari folder
perpustakaan kalau memang diinginkan.

---

## 8. Build dari source di macOS (untuk developer)

**Pakai rustup, BUKAN Rust dari Homebrew.** `brew install rust` memasang Rust
1.95; proc-macro dylib yang dihasilkannya ditolak dyld pada toolchain build
proyek ini. Pasang lewat [rustup.rs](https://rustup.rs/) dan pastikan
`~/.cargo/bin` berada **di depan** `$PATH` (di depan direktori Homebrew),
supaya `cargo`/`rustc` yang terpanggil adalah punya rustup:

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
export PATH="$HOME/.cargo/bin:$PATH"   # taruh baris ini SEBELUM baris brew di shell profile
rustup target add aarch64-apple-darwin x86_64-apple-darwin
which cargo   # harus menunjuk ke ~/.cargo/bin/cargo, bukan /opt/homebrew/bin/cargo
```

**`librust_core.dylib` ditolak dyld ("mis-aligned LINKEDIT string pool").**
Ditemukan 9 Okt 2026 di MacBook arm64 (macOS 27, Xcode 27): `Cargo.toml`
men-set `strip = true` pada profil release, dan langkah strip eksternal yang
dijalankan rustc di bawah skrip build Xcode 27 menghasilkan dylib yang rusak
— `dyld_info -validate_only` gagal, dan app crash di `main()`
(`tryLoadRustCoreLibrary`). Perbaikannya sudah diterapkan di
`macos/Runner.xcodeproj/project.pbxproj` (fase build "Build rust_core
dylib" memakai `CARGO_PROFILE_RELEASE_STRIP=none cargo build --release
--lib`, lalu memvalidasi hasilnya dengan `dyld_info -validate_only` bila
tersedia) dan di `scripts/package_macos.sh`. Build Linux/Windows tidak
disentuh — hanya invokasi macOS yang di-override.

**Tanda tangan rusak setelah build ("nested code is modified or
invalid").** `librust_core.dylib` disalin ke bundle SETELAH Xcode
menandatangani app secara otomatis, sehingga tanda tangan app tidak lagi
cocok dengan isinya. `project.pbxproj` sekarang punya fase build terakhir
("Re-sign after embedding rust_core dylib") yang menandatangani ulang app
secara ad-hoc (atau dengan `MACOS_SIGN_IDENTITY` bila diset) memakai
`macos/Runner/Release.entitlements`, setelah semua fase penyalinan selesai.
`scripts/package_macos.sh` melakukan hal yang sama saat membuat DMG.
Verifikasi dengan `codesign -v --verbose=2 "Trareon Transcribe.app"` —
harus bersih tanpa pesan apa pun.

> Kedua perbaikan di atas ditulis berdasarkan laporan uji nyata di Mac,
> tetapi **belum bisa diverifikasi ulang di mesin Linux** yang menjalankan
> sprint ini. Lihat "PERLU VERIFIKASI DI MAC" di `docs/SPRINT-REPORTS.md`.

## 9. Hook screenshot jarak jauh (`TRAREON_SCREENSHOT_DIR`)

`lib/utils/debug_screenshot.dart` menulis PNG tiap 2 detik (maksimum 120
kali) selama env var `TRAREON_SCREENSHOT_DIR` diset — tanpa env var ini,
perilaku app identik dengan build normal (tidak ada `RepaintBoundary`
tambahan, tidak ada timer).

Di macOS, app ter-*sandbox* (`com.apple.security.app-sandbox`), jadi
direktori tujuan HARUS berada di dalam container aplikasi sendiri, bukan
di `/tmp` biasa:

```bash
export TRAREON_SCREENSHOT_DIR="$HOME/Library/Containers/com.trareon.transcribe/Data/tmp/screenshots"
mkdir -p "$TRAREON_SCREENSHOT_DIR"
open "Trareon Transcribe.app"
# ... tunggu, lalu:
ls "$TRAREON_SCREENSHOT_DIR"   # shot-0000.png, shot-0001.png, ...
```

File ditulis atomik (temp lalu rename di direktori yang sama), jadi aman
disalin (`scp`) sewaktu app masih berjalan — tidak akan terlihat file PNG
yang setengah tertulis.
