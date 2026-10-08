# Ringkasan Kepatuhan Trareon Transcribe

**Untuk panitia pengadaan, PPK, dan unit hukum · 7 Oktober 2026**

Trareon Transcribe adalah aplikasi desktop untuk mentranskripsi rapat dan
menyusun notulen dalam format naskah dinas. Transkripsi berjalan
**sepenuhnya di perangkat notulis**: tidak ada unggahan audio, tidak ada
akun, tidak ada langganan, dan tidak ada kuota.

## Yang dilakukan Trareon

| Kemampuan | Bukti |
|-----------|-------|
| **Transkripsi luring.** Jalur dari mikrofon sampai ekspor tidak dapat membuka koneksi jaringan — ditegakkan uji yang menggagalkan build, bukan janji di brosur | `rust_core/src/privacy.rs`, `test/privacy_proof_test.dart` |
| **Mode Kepatuhan PDP.** Penyamaran NIK, NPWP, nomor telepon, email, nomor rekening, dan nama pilihan **saat ekspor, pada salinan** — transkrip tersimpan tidak diubah | `rust_core/src/pdp/redaction.rs` |
| **Batas retensi terpisah** untuk rekaman audio dan transkrip, dengan pratinjau dan konfirmasi sebelum menghapus | `rust_core/src/pdp/retention.rs` |
| **Log audit lokal append-only** atas tindakan yang memindahkan data — tanpa memuat isi rapat; dapat diekspor ke CSV | `rust_core/src/pdp/audit.rs` |
| **Teks pemberitahuan perekaman** yang dapat disunting instansi dan disalin ke obrolan rapat | `rust_core/src/pdp/mod.rs` |
| **Notulen tertelusur.** Setiap butir notulen tertaut ke nomor segmen transkrip; butir yang tidak didukung transkrip ditandai sebelum notulis menyetujui | `rust_core/src/provenance.rs`, `rust_core/src/notulen/factcheck.rs` |
| **Format naskah dinas** — empat tata letak (Notulen Dinas, Risalah Rapat, Berita Acara, Notulen Ringkas) mengikuti PERANRI No. 5 Tahun 2025, plus sidecar metadata SRIKANDI | `rust_core/src/srikandi.rs` |
| **Laporan Privasi** di dalam aplikasi: menghitung setiap panggilan jaringan sejak aplikasi dibuka, sehingga pengguna dapat melihat sendiri bahwa transkripsi tidak menambah hitungan | `lib/state/privacy_report_model.dart` |

**Lima titik keluar jaringan, semuanya atas tindakan pengguna, tidak satu
pun otomatis:** unduh model Whisper (SHA-256 dipin), permintaan
ringkasan/notulen ke endpoint LLM (**baku: loopback `localhost:11434`**),
cek pembaruan, membuka halaman rilis di peramban, dan pertanyaan arsip
rapat (endpoint yang sama, hanya petikan lokal yang dikirim). Tidak ada
telemetri, tidak ada analitik, tidak ada pelaporan galat jarak jauh.

## Yang **tidak** dilakukan Trareon — baca bagian ini

| Kesenjangan | Kendali pengganti yang **wajib** disediakan instansi |
|-------------|------------------------------------------------------|
| **Tidak ada enkripsi penyimpanan tingkat aplikasi** | Enkripsi cakram penuh: LUKS / BitLocker / FileVault |
| **Tidak ada autentikasi tingkat aplikasi.** Siapa pun yang membuka sesi OS pengguna dapat membuka Trareon | Sandi akun OS yang kuat + kunci layar otomatis |
| **Tidak ada penghapusan otomatis.** Menetapkan angka retensi tidak membuat data terhapus; eksekusi harus dijadwalkan dan ditugaskan | Jadwal dan penanggung jawab eksekusi retensi (prosedur §3) |
| **Penghapusan bukan pemusnahan aman.** Tidak menimpa blok cakram dan tidak menjangkau cadangan | Prosedur pemusnahan, termasuk penanganan cadangan (prosedur §5) |
| **Log audit tidak tahan-ubah secara kriptografis** | Salin log ke penyimpanan instansi yang hanya-tambah |
| **Endpoint LLM dapat dikonfigurasi ke luar perangkat.** Baku-nya loopback, tetapi instansi *dapat* mengarahkannya ke penyedia awan — dan bila itu dilakukan, transkrip keluar dari perangkat | Kebijakan tertulis bahwa endpoint tetap loopback + audit berkala atas pengaturan |
| **Tidak ada pencatatan persetujuan per-orang**, tidak ada sarana penarikan persetujuan di aplikasi | Proses instansi di luar aplikasi |

## Status standar dan sertifikasi — tanpa kiasan

> Trareon Transcribe **belum** disertifikasi ISO/IEC 27001, **belum**
> disertifikasi ISO/IEC 27701, **belum** mendapat penetapan kategori sistem
> elektronik dari BSSN, dan **belum** terdaftar sebagai Penyelenggara
> Sistem Elektronik. Paket kepatuhan ini adalah **pemetaan kendali** untuk
> membantu audit internal instansi — bukan sertifikat, bukan laporan audit
> pihak ketiga, dan bukan nasihat hukum.

Kepatuhan UU No. 27 Tahun 2022 adalah kewajiban **Pengendali Data
Pribadi**, yaitu instansi — bukan kewajiban aplikasi. Trareon menyediakan
kendali teknis yang membuat sebagian kewajiban itu dapat dipenuhi dan
dibuktikan; sisanya tetap pekerjaan instansi, dan daftar lengkapnya ada di
`PEMETAAN-UU-PDP-27-2022.md` §6 (sembilan kewajiban, K-1 sampai K-9).

Pada konfigurasi baku, **tidak ada Prosesor Data Pribadi** dan **tidak ada
transfer data ke luar wilayah Indonesia** — sehingga Pasal 51–52
(perjanjian pemrosesan) dan Pasal 56 (transfer lintas negara) tidak
terpicu. Ini perbedaan nyata dibanding layanan notulen berbasis awan, yang
selalu memunculkan prosesor dan sering memunculkan transfer lintas
yurisdiksi.

## Cara memverifikasi sendiri, dalam sepuluh menit

```sh
# 1. Gerbang luring sisi Rust — gagal bila jalur transkripsi menyentuh jaringan
cd rust_core && cargo test --lib privacy

# 2. Gerbang luring sisi Dart
flutter test test/privacy_proof_test.dart

# 3. Daftar seluruh literal URL di kode mesin — harus hanya tiga tempat:
#    unduh model, endpoint ringkasan, dan teks instruksi pemasangan Ollama
grep -rn "https\?://" rust_core/src/ --include=*.rs
```

Lalu uji runtime: jalankan aplikasi, transkripsikan satu berkas audio, dan
buka Pengaturan → Laporan Privasi. Hitungan panggilan jaringan harus tetap
**0** sepanjang transkripsi.

Pernyataan "transkripsi tidak pernah meninggalkan perangkat" karenanya
dapat diperiksa panitia dengan menjalankan satu perintah pada kode sumber,
bukan dengan mempercayai pernyataan penyedia.

## Prasyarat penggelaran — lima butir minimum

1. Enkripsi cakram penuh aktif di setiap laptop notulis.
2. Dasar pemrosesan (Pasal 20) ditetapkan dan didokumentasikan.
3. Teks pemberitahuan dilengkapi unsur Pasal 21 (masa retensi + daftar
   hak) dan dipasang di aplikasi — teks baku aplikasi sengaja pendek dan
   belum lengkap.
4. Angka retensi ditetapkan **dan** eksekusinya dijadwalkan dengan
   penanggung jawab bernama.
5. Endpoint LLM diverifikasi loopback (`http://localhost:11434`).

Daftar lengkap 15 butir: Lampiran B `TEMPLAT-DPIA.md`.

## Dokumen pendukung

`README.md` · `PEMETAAN-UU-PDP-27-2022.md` ·
`PEMETAAN-ISO-27001-27701.md` · `ALUR-DATA.md` · `TEMPLAT-DPIA.md` ·
`PROSEDUR-RETENSI-DAN-PENGHAPUSAN.md`

---

*Nomor pasal diverifikasi 7 Oktober 2026 terhadap peraturan.bpk.go.id dan
pasal.id; hal yang tidak dapat diverifikasi diberi tanda "belum
diverifikasi" di dokumen terkait. Wajib ditinjau unit hukum instansi
sebelum dipakai dalam dokumen resmi.*
