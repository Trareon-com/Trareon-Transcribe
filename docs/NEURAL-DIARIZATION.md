# Pemisahan pembicara akurat (sherpa-onnx)

Status per platform, dan mengapa fiturnya ada di belakang *cargo feature*.
Sprint 4b, item 4.

## Apa ini

Diarization lengkap, seluruhnya lokal dan ONNX:

| Tahap | Model | Ukuran |
|---|---|---|
| Segmentasi ("siapa bicara kapan") | pyannote-segmentation 3.0 | 6,0 MB |
| Sidik suara | 3D-Speaker CAM++ | 28,3 MB |
| Pengelompokan | *fast clustering* bawaan sherpa-onnx, ambang 0,5 | — |

Kode: `rust_core/src/diarization/neural.rs`. Katalog model:
`rust_core/src/model.rs` (`AssetKind::Diarization`). Sakelar pengguna:
Pengaturan → Audio & Suara → "Pemisahan pembicara akurat".

Dipakai pada jalur **pasca-rapat** saja — impor berkas, "Transkrip Ulang",
dan *completion pass* setelah Stop — karena ia membaca seluruh rekaman
sekaligus. Pratinjau langsung tetap memakai pengelompokan akustik ringan
(`diarization/mod.rs`), yang untuk kasus dua sumber (mikrofon = Anda,
audio sistem = peserta) memang sudah benar.

Label mengikuti `speaker_label` yang sama dengan jalur akustik, jadi
transkrip neural dan transkrip akustik terbaca serupa, dan **penggantian
nama oleh pengguna tetap berlaku**: klaster dinomori ulang berdasarkan
urutan kemunculan pertama di rekaman, bukan berdasarkan indeks internal
sherpa (yang bisa berubah antar-jalan). `speaker_aliases.dart` memetakan
nama berdasarkan label, jadi penomoran yang stabil itulah yang membuat
"Pembicara 2 → Pak Budi" selamat dari "Transkrip Ulang".

## Mengapa di belakang cargo feature

`sherpa-onnx-sys` **mengunduh pustaka native pra-bangun dari GitHub
Releases saat *build*** — bukan saat jalan:

| Target | Arsip | Ukuran |
|---|---|---|
| linux-x64 | `sherpa-onnx-v1.13.8-linux-x64-shared-lib.tar.bz2` | ~23 MB (varian static) |
| osx-arm64 | `sherpa-onnx-v1.13.8-osx-arm64-*-lib.tar.bz2` | ~21 MB |
| win-x64 | `sherpa-onnx-v1.13.8-win-x64-*-MT-Release-lib.tar.bz2` | ~123 MB |

Menjadikannya dependensi wajib berarti menaruh ketersediaan GitHub di
jalur `cargo test` setiap kontributor. Jadi:

```toml
default = []
neural-diarization = ["dep:sherpa-onnx"]
```

## Dua temuan yang harus diketahui sebelum menyentuh ini

### 1. `shared`, bukan `static`

`sherpa-onnx-sys` secara bawaan menautkan ONNX Runtime **secara statis**.
Pada Linux itu **menggagalkan proses saat jalan**:

```
free(): invalid pointer
process didn't exit successfully: ... (signal: 6, SIGABRT)
```

Tidak deterministik — kadang di `process()`, kadang saat `Drop` — yang khas
untuk kerusakan heap akibat dua `libstdc++`/alokator bercampur dalam satu
proses. Diverifikasi di mesin sprint ini (Kali, Linux 6.18, 4 inti):
`static` abort, `shared` berjalan bersih. Karena itu `Cargo.toml` memaksa:

```toml
sherpa-onnx = { version = "1.13.8", optional = true,
                default-features = false, features = ["shared"] }
```

Jangan kembalikan ke `static` tanpa menjalankan
`rust_core/tests/neural_diarization_live.rs` lebih dulu.

### 2. Tidak bisa digabung dengan `silero-onnx`

`ort` (fitur `silero-onnx`) dan `sherpa-onnx-sys` masing-masing membawa
ONNX Runtime sendiri. Menyalakan keduanya menghasilkan ratusan baris
`duplicate symbol: onnxruntime::...` dari *linker*. `rust_core/src/lib.rs`
mengubahnya menjadi satu `compile_error!` yang bisa dibaca.

Ini bukan masalah dalam praktik: Sprint 4b memindahkan gerbang VAD ke
Silero bawaan whisper.cpp (`vad/whisper_silero.rs`), yang tidak butuh
runtime ONNX kedua — dan `silero-onnx` dikeluarkan dari fitur bawaan
sekalian, karena tidak ada pemasangan yang pernah benar-benar
memakainya (tidak ada apa pun yang mengirimkan `models/silero_vad.onnx`,
jadi setiap `SileroDetector` jatuh ke detektor energi RMS).

## Status per platform

| Platform | Build | Jalan | Catatan |
|---|---|---|---|
| Linux x64 | ✅ terverifikasi | ✅ terverifikasi | `shared`. Tes integrasi lulus pada `rapat_id.mp3`: satu pembicara → tepat 1 klaster di seluruh 7 segmen. |
| Windows x64 | ⚠️ belum diuji | ⚠️ belum diuji | Arsip 123 MB ada (HTTP 200 diperiksa). Varian pra-bangun `MT-Release`; sisa dependensi C proyek ini `/MD`, jadi pencampuran CRT perlu diperiksa sebelum dipercaya. |
| macOS (arm64/x64) | ⚠️ belum diuji | ⚠️ belum diuji | Arsip ada. Tidak ada mesin macOS di lingkungan sprint. |

CI hanya membangun fitur ini di Linux. Pada platform lain aplikasi
dikompilasi **tanpa** fitur, dan sakelar Pengaturan berbunyi "Tidak
tersedia di build ini" (`capabilities.rs`, baris `diarization_neural`) —
bukan menyala lalu diam-diam tidak melakukan apa pun.

## Menjalankan tesnya

```bash
cd rust_core
cargo test --features neural-diarization \
           --test neural_diarization_live -- --nocapture --test-threads=1
```

Tes melewatkan dirinya sendiri (dengan pesan) jika modelnya belum
diunduh — "model belum dipasang" adalah keadaan normal sebuah *checkout*
baru, bukan kegagalan. Unduh lewat Pengaturan → Audio & Suara, atau
langsung:

```
~/Library/Caches/TrareonTranscribe/models/sherpa-onnx-pyannote-segmentation-3-0.onnx
~/Library/Caches/TrareonTranscribe/models/3dspeaker_speech_campplus_sv_zh-cn_16k-common.onnx
```

Logika penugasan segmen (`assign_from_turns`) diuji **tanpa** fitur, di
setiap platform, di dalam `neural.rs` sendiri — di situlah setiap bug
*off-by-one* integrasi diarization bersarang, dan ia tidak boleh
bergantung pada pustaka native untuk bisa diuji.

## Privasi

Kedua model diunduh hanya saat pengguna menekan Unduh, diverifikasi
terhadap SHA256 yang dipatok di dalam biner (bukan yang dikirim server),
dan dicatat di Laporan Privasi lewat `recordModelDownload`. Diarization
sendiri tidak membuka soket apa pun; `privacy.rs` memindai
`diarization/neural.rs` sebagai modul lokal dan tesnya gagal bila modul
itu menyebut `reqwest` atau `TcpStream`.
