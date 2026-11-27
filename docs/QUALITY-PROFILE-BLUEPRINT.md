# QUALITY-PROFILE-BLUEPRINT

**Versi:** 1.0 · **Tanggal:** 27 Nov 2026 · **Status:** keputusan produk terkunci, siap diimplementasikan
**Ruang lingkup:** layar Pengaturan Trareon-Transcribe (10 kategori, 24 kontrol) dan alur unduh komponen.
**Non-goals:** mengubah mesin transkripsi (Whisper/CrispASR), mengubah skema `AppSettings` di sisi Rust.

---

## 1. Masalah

Setiap kontrol di Pengaturan lahir dari kebutuhan nyata, dan masing-masing punya alasan teknis. Tapi
disusun sebagai satu daftar panjang, hasilnya tiga hal:

1. **Beban kognitif.** 24 sakelar di 10 kategori, dan tidak ada penanda mana yang memengaruhi mutu
   transkrip dan mana yang hanya soal kenyamanan.
2. **Sakelar yang bisa merusak.** Tiga di antaranya *menurunkan* mutu kalau salah: pengurangan derau
   (RNNoise) memakan kata pada suara yang sudah bersih, AGC menaikkan noise floor di ruangan senyap,
   dan memaksa bahasa yang salah membuat Whisper mengarang. Kode sendiri sudah mengakui yang pertama —
   lihat komentar di `settings_screen.dart` pada baris "on already-clean speech it can cost a word".
3. **Default yang tidak dijaga.** `agcEnabled` default **ON** sementara `noiseReduction` default
   **OFF** — dua tetangga di kategori yang sama, dua kebijakan yang saling berlawanan tanpa alasan
   yang tertulis.

Pengguna baru tidak punya cara untuk tahu bahwa "biarkan saja" adalah pilihan yang aman.

---

## 2. Keputusan (dikunci oleh Master, 27 Nov 2026)

| # | Keputusan | Konsekuensi |
|---|---|---|
| D1 | **Mode Sederhana sebagai default.** Kontrol lain masuk "Lanjutan" yang dilipat, tidak dihapus. | Pengguna baru melihat 4 kontrol. Yang butuh kontrol tetap bisa membukanya. |
| D2 | Empat kontrol terlihat: **Model tier (Otomatis + 5 tier) · Bahasa · Mikrofon & Speaker · Folder output**. | Sisa 20 kontrol pindah ke Lanjutan / kategori fitur. |
| D3 | **RNNoise & AGC diputuskan mesin** dari pengukuran awal rekaman (SNR + level). AGC mati kalau level sudah cukup kuat. | Butuh nilai terukur, bukan default buta. Lihat §5. |
| D4 | **Unduhan: sekali izin di awal**, total MB ditampilkan, ada opsi "tunda kalau koneksi metered", lalu mengunduh sendiri saat dibutuhkan. | Butuh dialog izin + status tunda. Lihat §6. |
| D5 | **10 kategori tidak diubah.** Di Mode Sederhana hanya kategori relevan yang tampil. | Tidak ada reorganisasi informasi; hanya penyaringan tampilan. |

---

## 3. Matriks sakelar

Kolom **Mode** menentukan di mana kontrol muncul. Kolom **Sumber nilai** menentukan siapa yang
berhak menetapkan nilainya.

| Kontrol | Kategori | Mode | Sumber nilai | Alasan |
|---|---|---|---|---|
| Model tier | Model & Mode | **Sederhana** | pengguna (`Otomatis` → resolver) | pengungkit mutu terbesar; pilihan sadar |
| Bahasa | Model & Mode | **Sederhana** | pengguna (`Otomatis` default) | bahasa salah = transkrip salah |
| Mikrofon & Speaker | Audio & Suara | **Sederhana** | pengguna | salah perangkat = tidak ada suara sama sekali |
| Folder output | Penyimpanan | **Sederhana** | pengguna | menyangkut tempat berkas pengguna |
| Akselerasi GPU | Model & Mode | Lanjutan | resolver (dapat ditimpa) | kecepatan, bukan mutu |
| Cepat dulu → diperhalus (HPT) | Model & Mode | Lanjutan | resolver | kecepatan vs mutu bertahap |
| Perhalus otomatis di latar belakang | Model & Mode | Lanjutan | pengguna | menulis ulang transkrip yang sudah selesai — harus disengaja |
| Mode default rekaman | Model & Mode | Lanjutan | pengguna | mengikuti pola kerja, bukan mesin |
| Abaikan jeda sunyi (VAD) | Audio & Suara | Lanjutan | resolver | berguna, tapi agresif = kata hilang |
| **Pengurangan derau (RNNoise)** | Audio & Suara | Lanjutan | **resolver (terukur)** | bisa memakan kata pada audio bersih |
| **AGC** | Audio & Suara | Lanjutan | **resolver (terukur)** | menaikkan noise floor di ruangan senyap |
| Hapus suara ganda (online) | Audio & Suara | Lanjutan | turunan mode | hanya relevan pada mode online |
| Berhenti sendiri saat sunyi + lamanya | Audio & Suara | Lanjutan | pengguna | kebiasaan kerja |
| Pemisahan pembicara (diarisasi) | Audio & Suara | Lanjutan | pengguna | unduhan 34 MB; mengubah tampilan hasil |
| Format ekspor default | Penyimpanan | Lanjutan | pengguna | preferensi |
| Tema | Tampilan | Lanjutan | pengguna | preferensi |
| Perbandingan kecepatan | Transkripsi | Lanjutan | info saja | bukan setelan |
| Kamus Istilah | Kamus | kategori tetap | pengguna | data milik pengguna, meningkatkan nama diri |
| Ringkasan AI | Ringkasan AI | kategori tetap | pengguna | fitur terpisah, butuh Ollama/API |
| Notulen Resmi | Notulen | kategori tetap | pengguna | fitur terpisah |
| Kepatuhan PDP | Kepatuhan PDP | kategori tetap | pengguna | kewajiban, bukan preferensi |
| Penyiapan & Diagnostik / Tentang | — | kategori tetap | — | utilitas |

**Aturan:** Mode Sederhana **menyaring tampilan**, tidak mengubah nilai. Semua nilai tetap tersimpan
dan tetap berlaku; hanya jalan menuju kontrolnya yang dilipat.

---

## 4. `QualityProfile` — otak keputusan

Fungsi murni Dart, tanpa I/O, sehingga bisa diuji tanpa perangkat.

```dart
// lib/state/quality_profile.dart

/// Angka terukur dari beberapa detik pertama sumber audio yang aktif.
class AudioMeasurement {
  /// Rasio sinyal terhadap derau dalam dB, dari pita sunyi vs pita bicara.
  final double snrDb;
  /// Tingkat puncak dalam dBFS — menentukan apakah AGC masih ada gunanya.
  final double peakDbfs;
  const AudioMeasurement({required this.snrDb, required this.peakDbfs});
}

class QualityProfile {
  final bool noiseReduction;
  final bool agc;
  final bool vad;
  final bool progressive;
  final String reason;   // satu baris Indonesia, ditampilkan di panel
}

enum TuningSource { auto, user }   // `user` = Master pernah menggeser sakelar

QualityProfile resolveQualityProfile({
  required AudioMeasurement? measurement,  // null = belum terukur
  required bool gpuAvailable,
  required bool refineModelInstalled,
  required TuningSource tuningSource,      // dari `autoAudioTuning`
});
```

### 4.1 Tabel aturan (deterministik)

| Kondisi (`measurement != null`) | `noiseReduction` | `agc` | Alasan yang ditampilkan |
|---|---|---|---|
| `snrDb >= 25` — bersih | mati | mati | "Ruangan bersih; derau dan AGC dimatikan agar tidak memakan kata" |
| `15 <= snrDb < 25` — sedang | mati | **nyala** kalau `peakDbfs < -24`, selain itu mati | "Derau ringan; hanya level yang dinaikkan" |
| `snrDb < 15` — berisik | **nyala** | nyala kalau `peakDbfs < -24` | "Derau tinggi; pengurangan derau dinyalakan" |
| `measurement == null` | mati | mati | "Belum terukur; pengaturan konservatif dipakai" |
| `tuningSource == user` | nilai pengguna | nilai pengguna | "Dipilih manual" |

`vad` = tetap `true` (perilaku hari ini) kecuali pengguna mematikannya; `progressive` = tetap `true`
hanya bila `refineModelInstalled`, selain itu `false` — supaya tidak pernah menunjuk model yang tidak ada.
`gpuAvailable == false` memaksa `progressive = false` untuk model eksperimental (CrispASR tidak punya
dua tahap).

### 4.2 Presedensi

1. **Pilihan manual pengguna selalu menang.** `tuningSource == user` → resolver tidak menyentuh
   `noiseReduction`/`agc` sama sekali.
2. Resolver menang atas default pabrik.
3. `measurement == null` → konservatif (mati), bukan default lama (`agcEnabled = true`).

### 4.3 Perubahan default pabrik

`AppSettings` default berubah: `agcEnabled: true` → **`false`**, dengan `autoAudioTuning: true`.
Alasan tertulis di kode: AGC pada audio yang sudah ternormalisasi hanya menaikkan noise floor, dan
mutu adalah prioritas di atas kenyaringan tampilan.

Migrasi pengguna lama: nilai `autoAudioTuning` **tidak** disimpan di `AppSettings` (lihat §7), jadi
instalasi lama otomatis ikut kebijakan baru. Pengguna yang pernah menggeser AGC/NR secara manual —
terdeteksi saat setter dijalankan, yang menulis `autoAudioTuning = false` — tidak dibalik.

---

## 5. Pengukuran "3 detik pertama" — dua fase

Yang dibutuhkan: SNR dan peak dari sumber aktif, **sebelum** rekaman dimulai, karena RNNoise dan AGC
dipasang saat capture dibuka (`bridge_service.dart` meneruskan keduanya ke `startSession`).

### Fase 1 (PR ini, Dart-only)

- Resolver + `AudioMeasurement` + aturan §4.1 sudah lengkap dan teruji.
- Sumber pengukuran belum ada → `measurement == null` → kebijakan konservatif yang **lebih aman**
  daripada hari ini (AGC mati, NR mati). Tidak ada regresi mutu; hanya kehilangan optimasi.
- Setiap pengguna bisa membuka Lanjutan dan menyalakan sendiri → `tuningSource = user`.

### Fase 2 (isu tindak lanjut, Rust + FRB)

- `rust_core/src/audio/probe.rs`:
  `pub fn probe_input(device_id: Option<String>, millis: u32) -> Result<AudioProbe, TranscribeError>`
  memakai primitif yang sudah ada: `silence_gate::rms_dbfs`, `silence_gate::peak`, dan pembukaan
  stream input dari jalur capture yang sama. Mengembalikan `{ snr_db, peak_dbfs, ms }`.
- Regenerasi binding FRB, lalu di Dart: sebelum `startSession`, panggil probe 3 detik dengan
  indikator progres di dialog mulai-rekaman; hasilnya diteruskan ke `resolveQualityProfile`.
- **Kenapa dipisah:** ini menyentuh jalur audio asli dan hanya bisa diverifikasi dengan mikrofon
  sungguhan. Menggabungkannya dengan perubahan UI berarti dua kelas risiko dalam satu PR.
- Kriteria selesai fase 2: pada Kali (RMS/peak terukur nyata) dan Windows, hasil probe masuk akal
  (senyap ≈ −60 dBFS, bicara ≈ −20 dBFS), dan sesi dengan NR nyala pada rekaman berisik tidak
  kehilangan kata dibanding NR mati (dibandingkan pada berkas uji yang sama).

---

## 6. Izin unduhan (D4)

### 6.1 Apa yang diunduh, berapa besar

| Komponen | Ukuran | Kapan dibutuhkan |
|---|---|---|
| Model cepat (`base`) | ~142 MB | sesi pertama |
| Model akurat (`small`) | ~466 MB | HPT / perbaikan mutu |
| Silero VAD | 0,9 MB | bila "Abaikan jeda sunyi" nyala |
| pyannote 3.0 (segmentasi) | 6 MB | bila diarisasi nyala |
| CAM++ (embedding) | 28 MB | bila diarisasi nyala |

Model eksperimental (Qwen3-ASR 0.6B/1.7B) dan `large-v3-turbo-q5` **tidak** ikut unduhan otomatis —
ukurannya besar dan hanya dipakai bila dipilih sadar.

### 6.2 Alur

1. Saat mulai pertama, satu dialog: total MB untuk rencana default (model cepat + akurat + Silero),
   dengan dua tombol: **Unduh sekarang** dan **Nanti**.
2. Checkbox **"Tunda bila koneksi metered"** (default: aktif). Belum ada deteksi metered di repo,
   jadi pada fase 1 checkbox ini berarti "jangan mulai unduhan otomatis tanpa saya konfirmasi lagi",
   disimpan sebagai `deferDownloads`. Fase 2: sambungkan ke deteksi koneksi; kontraknya sudah ada
   (`shouldStartDownload(now, networkIsMetered, consent)`), jadi hanya sumbernya yang berubah.
3. Bila ditunda: tidak ada unduhan diam-diam. Yang butuh model tanpa file terpasang mendapat ajakan
   unduh di tempat ia mencoba memakainya (pola `engine_assets_section.dart` yang sudah ada).
4. **Setiap unduhan tetap dicatat sebagai jalur keluar** di Privacy Report lewat `onNetworkRequest`
   yang sudah dipakai model dan pemeriksa pembaruan. Auto-unduh tidak boleh menjadi jalur kelima yang
   tidak terhitung — itu melanggar janji aplikasi sendiri.

---

## 7. Penyimpanan & interaksi dengan pemuatan dua fase (#66)

`autoAudioTuning`, `deferDownloads`, dan `simpleMode` adalah **preferensi Dart**, bukan bagian dari
`AppSettings` yang dicerminkan ke Rust. Karena itu:

- disimpan di `DartPrefs` (`autoAudioTuning`, `deferDownloads`, `settings.simpleMode` sebagai bool);
- dimuat pada **fase 2** pemuatan settings (lihat `SettingsNotifier._loadFromStorage`), sebagai
  penulisan aditif — pola yang sama dengan `exportFormat`/`deviceId`, sehingga tidak menimpa fase 1;
- **tidak** menambah field di `rust_core/src/settings.rs`, jadi tidak ada perubahan skema Rust dan
  tidak ada regresi format berkas settings.

Konsekuensi yang harus diterima: pengaturan ini tidak ikut bila pengguna memindah berkas settings
Rust antar mesin. Dapat diterima — ketiganya properti UI/mesin lokal, bukan properti sesi.

---

## 8. UX

### 8.1 Panel Model & Mode (Mode Sederhana)

```
Kualitas AI
  Model             [Otomatis ▾]        Otomatis: small + GPU terdeteksi
  Bahasa            [Otomatis ▾]
  Mikrofon          [Default sistem ▾]
  Speaker           [Default sistem ▾]
  Folder output     [~/Trareon ▸]

  ── diputuskan otomatis ─────────────────────────────
  Ruangan bersih · derau mati · AGC mati · model small
  Sumber: pengukuran 3 detik terakhir        [Ubah manual ▸]
```

- Baris "diputuskan otomatis" berasal dari `QualityProfile.reason` dan **selalu** ditampilkan, supaya
  "otomatis" bukan kotak hitam.
- Tombol **Ubah manual** membuka Lanjutan dengan fokus pada baris terkait, dan menulis
  `autoAudioTuning = false` saat sakelar pertama digeser.
- Tombol **Lanjutan** di kaki panel membuka seluruh kategori. Status buka/tutup tidak disimpan sebagai
  preferensi; default selalu tertutup.

### 8.2 Yang tidak berubah

Sepuluh kategori tetap ada dengan nama dan ikon yang sama. Mode Sederhana hanya menyembunyikan
kategori yang tidak relevan (Tampilan, Kamus, Ringkasan AI, Notulen, Kepatuhan PDP, Penyiapan,
Tentang) sampai pengguna menekan Lanjutan.

---

## 9. Rencana uji

**Unit (fungsi murni, tanpa perangkat):**
- batas SNR: 14,9 / 15,0 / 24,9 / 25,0 → klasifikasi yang benar
- AGC hanya nyala pada `peakDbfs < -24` di dua pita berisik/sedang
- `measurement == null` → NR mati, AGC mati, alasan "belum terukur"
- `tuningSource == user` → nilai pengguna tidak ditimpa pada semua kombinasi SNR
- `refineModelInstalled == false` → `progressive` mati
- `gpuAvailable == false` + model eksperimental → `progressive` mati

**Widget:**
- Mode Sederhana: hanya 4 kontrol + baris keputusan yang tampil; "Lanjutan" membuka 20 kontrol
- menggeser AGC di Lanjutan → `autoAudioTuning` jadi `false` dan bertahan setelah layar dibuka ulang
- dialog izin unduhan menampilkan total MB dan tidak memulai unduhan saat "Nanti"

**Gate yang sudah ada:** `flutter analyze` (fatal), `flutter test --exclude-tags golden` (757 test),
golden hanya lokal. Tidak ada test baru yang boleh bergantung pada mikrofon.

---

## 10. Risiko & mitigasi

| Risiko | Mitigasi |
|---|---|
| Resolver mematikan NR padahal pengguna di kantor bising | Alasan selalu ditampilkan; "Ubah manual" satu ketukan; pilihan manual mengunci resolver |
| Pengguna lama kaget AGC mati | Perubahan hanya menyentuh yang belum pernah menggeser AGC; Lanjutan menampilkan nilai apa adanya |
| Mode Sederhana menyembunyikan kontrol yang dibutuhkan | Tidak ada yang dihapus; Lanjutan satu tombol; kategori fitur tetap utuh |
| Auto-unduh memakan kuota | Izin sekali dengan total MB + opsi tunda; metered detection fase 2 |
| Pengukuran fase 2 salah baca (mikrofon mati) | Kontrak resolver sudah menangani `null` → konservatif; probe gagal ≠ sesi gagal |

---

## 11. Urutan implementasi

1. `QualityProfile` + `AudioMeasurement` + unit test (murni, cepat).
2. Flag `autoAudioTuning`/`deferDownloads`/`simpleMode` di `DartPrefs` + fase 2 pemuatan.
3. Default `agcEnabled` → `false`; setter menulis flag.
4. Panel Model & Mode: 4 kontrol + baris keputusan + tombol Lanjutan.
5. Dialog izin unduhan + status tunda.
6. (Isu terpisah) probe Rust + FRB + verifikasi perangkat.

Langkah 1–5 selesai dalam satu PR yang bisa diverifikasi tanpa perangkat. Langkah 6 tidak boleh
digabung, dengan alasan di §5.
