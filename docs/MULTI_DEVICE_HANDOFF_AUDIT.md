# Audit: sinkronisasi/handoff lintas-device (F25, Sprint 15)

**Status: audit saja, bukan implementasi.** Keputusan arsitektur di bawah ini
menyentuh prinsip privasi-lokal yang jadi moat produk ini dan butuh
persetujuan Master sebelum dibangun.

## 1. Apakah ada cara pindah sesi antar device sekarang?

Tidak. Dibaca langsung dari kode:

- `lib/services/session_store.dart` dan `lib/services/library_index.dart`
  hanya tahu cara membaca/menulis folder sesi **di disk lokal** yang
  ditunjuk `AppSettings.libraryPath`. `loadLibraryIndex()`
  (`library_index.dart:253`) men-scan direktori itu; tidak ada kode yang
  tahu cara mengirim atau menerima sesi dari device lain.
- `lib/screens/library_screen.dart` punya satu jalur masuk data dari luar:
  `FileUploadZone` (dipakai di baris 525) — tapi itu untuk **mengimpor file
  audio mentah untuk ditranskrip**, bukan untuk mengimpor sesi Trareon yang
  sudah lengkap (transkrip + sidecar + audio asli).
- Satu-satunya cara sesi "berpindah" hari ini adalah **manual lewat
  file manager**: user menyalin seluruh folder sesi (file transkrip
  `.json`, `trareon-session.json` sidecar, dan audio sumber) ke device lain
  lewat USB/AirDrop/apa saja, lalu menunjuk `libraryPath` device kedua ke
  folder yang sama atau menaruh folder itu di dalamnya. Ini **sudah
  bekerja** karena format sesi adalah folder biasa — tapi tidak ada UI yang
  memandu atau memvalidasi langkah ini, dan tidak ada yang memastikan
  semua file (termasuk backup transkrip, sidecar) ikut tersalin.
- Tidak ada akun, tidak ada server, tidak ada mekanisme "device B
  tahu device A punya sesi baru" dalam bentuk apa pun. Ini konsisten dengan
  `rust_core/src/privacy.rs` dan `test/privacy_proof_test.dart`: capture,
  transkripsi, dan ekspor memang murni lokal, tanpa jalur keluar.

**Kesimpulan audit:** belum ada fitur handoff sama sekali, hanya
kemungkinan manual yang tidak dibantu UI.

## 2. Opsi paling ringan: ekspor/impor arsip sesi (.zip)

Diusulkan — **belum dibangun**:

- **"Ekspor sesi sebagai arsip"**: satu tombol di kartu sesi (library
  screen, di samping tombol ekspor `.docx`/`.csv` yang sudah ada) yang
  men-zip seluruh folder sesi (audio asli + transkrip `.json` + sidecar
  `trareon-session.json` + backup transkrip bila ada) menjadi satu berkas
  `.zip` bernama dari judul+tanggal sesi. User lalu memindahkan `.zip` itu
  sendiri lewat USB/AirDrop/Tailscale file share/apa pun miliknya.
- **"Impor arsip sesi"**: tombol di library screen yang membuka file
  picker untuk `.zip`, mengekstraknya ke `libraryPath` device tujuan, dan
  memvalidasi bahwa hasil ekstraksi punya bentuk folder sesi yang sah
  (ada transkrip, sidecar terbaca) sebelum memunculkannya di library —
  sidecar yang sudah ditulis tolerant-of-garbage (`SessionMeta.fromJson`,
  `session_store.dart:202`) sudah mendukung ini tanpa perubahan skema.
- Kedua arah ini **manual dan sekali-jalan**: tidak ada watch-folder, tidak
  ada "device tahu device lain", tidak ada akun. User yang memutuskan kapan
  dan ke mana sesi berpindah, sama seperti dia memindahkan file apa pun.

## 3. Trade-off

| | Sync otomatis (cloud/akun) | Ekspor/impor manual (.zip) |
|---|---|---|
| Effort | Besar: butuh server, akun, resolusi konflik, keamanan transport, kebijakan retensi | Kecil: satu fungsi zip + satu fungsi unzip-dan-validasi, memakai format sesi yang sudah ada |
| Prinsip privasi-lokal | **Melanggar**: audio/transkrip rapat keluar dari mesin user ke server pihak ketiga (atau server sendiri yang tetap butuh host) — ini justru yang jadi alasan `privacy.rs` ada dan jadi pembeda produk ini dari kompetitor cloud-based (`docs/COMPETITOR-RESEARCH.md`) | **Konsisten**: data tidak pernah transit lewat apa pun yang bukan milik/kendali user. Sama prinsipnya dengan ekspor `.ics`/`.docx` yang sudah ada |
| Risiko keamanan | Permukaan serangan baru: auth, token, server yang menyimpan rapat sensitif | Tidak ada permukaan baru — `.zip` adalah file biasa, user yang memilih media transfer dan keamanannya |
| Pengalaman user | Otomatis, tidak perlu mikir | Satu langkah ekstra ("ekspor", lalu "impor" di device lain) — tapi jelas dan bisa diaudit, user tahu pasti kapan datanya "pergi" |

## Rekomendasi

**Ekspor/impor manual (.zip)**, bukan sync otomatis — alasan utamanya bukan
effort (meskipun itu juga jauh lebih kecil), tapi karena sync otomatis
mengharuskan rapat yang direkam (seringnya berisi informasi sensitif/rahasia
instansi, sesuai target pengguna di
`docs/TRAREON-V1-PRODUCTION-BLUEPRINT.md`) transit lewat infrastruktur yang
bukan milik user. Itu bertentangan langsung dengan alasan `privacy.rs` ada
dan dengan moat "privasi-lokal" yang membedakan Trareon dari kompetitor
cloud (Otter.ai, Fireflies, dll — lihat `docs/COMPETITOR-RESEARCH.md`).
Ekspor/impor manual memberi 90% dari manfaat (sesi *bisa* berpindah device)
tanpa mengorbankan prinsip itu sama sekali.

**Keputusan ini butuh persetujuan Master** sebelum dikerjakan — baik untuk
opsi manual yang direkomendasikan di atas maupun opsi sync otomatis, karena
keduanya mengubah pernyataan privasi produk ("semua transkripsi berjalan di
komputer ini") yang saat ini benar secara mutlak dan sebaiknya tidak
diubah tanpa sepengetahuan Master, walau opsi manual tidak membuka jalur
keluar otomatis apa pun.

Sprint ini **tidak mengimplementasikan** salah satu opsi di atas — F25
adalah audit dan rekomendasi saja, sesuai brief.
