# Uji Banding LLM Notulen Indonesia

**Trareon Transcribe · Sprint 7 · diukur 5–7 Oktober 2026**

Dokumen ini memilih model bawaan Trareon untuk penyusunan notulen, dan
menggantikan dua rekomendasi dari putaran riset sebelumnya yang saling
bertentangan dan tidak satu pun terukur. Harness, dataset, dan metrik ada di
`ml/notulen_bench/`; hasil mentah per kasus ada di
`ml/notulen_bench/results/results.jsonl`.

> **Aturan kejujuran dokumen ini.** Setiap angka di bawah berasal dari satu
> catatan JSONL yang dihasilkan satu permintaan nyata ke Ollama. Tidak ada
> angka yang diperkirakan, diinterpolasi, atau disalin dari publikasi. Hal
> yang tidak dijalankan ditulis **"TIDAK DIJALANKAN"** beserta alasannya,
> bukan diisi perkiraan.

---

## 1. Pertanyaan yang dijawab

Putaran riset Sprint 0 (`trareon-sprints/OPEN-QUESTIONS-LLM-SRIKANDI-LEGAL.md`
§A.7) merekomendasikan **Gemma-SEA-LION-v3-9B-IT** sebagai bawaan dengan
**Qwen3 8B** sebagai cadangan; putaran riset lain merekomendasikan yang
sebaliknya. Keduanya bersandar pada SEA-HELM dan ROUGE dari literatur —
tidak satu pun mengukur **tugas yang sebenarnya dikerjakan Trareon**:
mengubah transkrip rapat Indonesia menjadi naskah dinas berstruktur tetap,
tanpa mengarang.

Tiga pertanyaan yang dijawab di sini:

1. **Apakah pelatihan khusus bahasa Indonesia mengalahkan model umum yang
   lebih kuat?** Dijawab dengan memasangkan model yang di-*post-train* untuk
   Asia Tenggara (Sahabat-AI, Apertus-SEA-LION) melawan model umum (Qwen3,
   Gemma 3).
2. **Apakah 8–12B membeli sesuatu dibanding 4B di laptop?** Dijawab dengan
   memasangkan Qwen3 4B/8B dan Gemma 3 4B/12B.
3. **Berapa harga yang dibayar dalam waktu tunggu?** Diukur sebagai detik per
   rapat dan token/detik pada perangkat keras nyata, bukan diperkirakan.

---

## 2. Perangkat pengukuran

| Butir | Nilai |
|-------|-------|
| Mesin | Laptop Windows 11 Pro |
| CPU | Intel Core i7-10750H @ 2.60 GHz |
| RAM | 15.8 GiB |
| GPU | NVIDIA GeForce RTX 2060, **6 GiB** VRAM, driver 555.99 |
| Ollama | 0.32.14 |
| Python | 3.14.7 |
| Mode | non-streaming, `format: json`, `temperature: 0.2`, `think: false` |

**6 GiB VRAM adalah fakta terpenting di tabel ini.** Model 8B pada Q4 sudah
melebihi 6 GiB begitu *KV cache* ikut dihitung, jadi sebagian lapisan jatuh
ke RAM sistem. Angka latensi di bawah karenanya adalah angka **laptop
kelas menengah dengan GPU kecil** — bukan angka server, dan bukan angka
laptop tanpa GPU sama sekali (yang akan jauh lebih lambat lagi).

### Mengapa `num_ctx` disesuaikan per kasus

Ollama mengalokasikan *KV cache* untuk seluruh `num_ctx` di muka. Meminta
16K pada kartu 6 GiB mendorong lapisan transformer kembali ke CPU: terukur
pada `01-rakor-pagu` dengan qwen3:4b, 16K butuh 229 detik dan 8K butuh 37
detik untuk prompt yang sama dan skor yang hampir identik. Konteks tetap
yang besar akan membuat setiap model di tabel ini tampak enam kali lebih
lambat daripada sebenarnya, jadi `run.context_for()` memilih jendela
terkecil yang memuat prompt dan jawaban kasus itu.

---

## 3. Dataset

24 rapat, 234 menit transkrip, 89.044 karakter, di `ml/notulen_bench/data/`.

| Templat | Jumlah kasus |
|---------|--------------|
| Notulen Dinas | 12 |
| Notulen Ringkas | 5 |
| Risalah Rapat | 4 |
| Berita Acara | 3 |

> **Seluruhnya sintetis.** Setiap berkas kasus menuliskan `sumber: sintetis`
> di kepalanya. Tidak ada rekaman rapat nyata, tidak ada data pengguna, dan
> tidak ada transkrip instansi yang dipakai. Transkrip disusun untuk
> menyerupai rapat dinas Indonesia — termasuk disfluensi, interupsi, angka
> yang diucapkan sebagai kata, dan alih-kode ID–EN — tetapi **tidak boleh
> dikutip sebagai ukuran kinerja pada rapat nyata.** Lihat §9.

Setiap kasus membawa notulen rujukan bergaya Tata Naskah Dinas: daftar
keputusan, daftar tindak lanjut dengan penanggung jawab dan tenggat, serta
peserta — yang menjadi *gold* bagi metrik di §5.

### Himpunan pembanding: 8 kasus

Enam model × 24 kasus adalah inferensi berjam-jam pada GPU 6 GiB, dan
anggaran sprint tidak memuatnya. Perbandingan antarmodel karenanya dihitung
atas **himpunan 8 kasus yang sama**, dipilih supaya setiap templat dan
setiap sifat yang diuji terwakili:

| Kasus | Templat | Yang diuji |
|-------|---------|------------|
| `01-rakor-pagu` | Notulen Dinas | Angka anggaran, tenggat eksplisit |
| `02-rapat-teknis-spbe` | Notulen Dinas | **Alih-kode ID–EN berat**, istilah teknis |
| `03-ba-serah-terima` | Berita Acara | Para pihak, nomor dan jumlah barang |
| `04-risalah-rdp-komisi` | Risalah Rapat | Urutan pembicara, interupsi |
| `05-standup-produk` | Notulen Ringkas | **Alih-kode ID–EN berat**, ragam percakapan |
| `07-sosialisasi-tanpa-keputusan` | Notulen Dinas | **Uji anti-halusinasi** — rapat tanpa keputusan |
| `08-ba-pemeriksaan-kas` | Berita Acara | Angka rupiah berdekatan, selisih kas |
| `10-risalah-sidang-etik` | Risalah Rapat | Urutan ketat, bahasa formal tinggi |

Dua model yang lebih dulu dijalankan (Qwen3 4B dan 8B) menyelesaikan lebih
banyak kasus — 24 dan 16 — tetapi **tabel utama tetap dihitung atas 8 kasus
yang sama untuk semua**, karena rata-rata atas himpunan kasus yang berbeda
tidak dapat dibandingkan. Angka himpunan penuh dilaporkan terpisah di §7.4.

### Prompt yang dipakai adalah prompt aplikasi

Prompt sistem dan prompt pengguna di `ml/notulen_bench/prompts/` **bukan**
tulisan baru untuk benchmark: keduanya dicetak dari
`rust_core/src/notulen/prompt.rs` yang dipakai aplikasi, lewat

```sh
TRAREON_DUMP_PROMPTS=1 cargo test --lib notulen::prompt
```

Benchmark yang memakai prompt sendiri akan mengukur prompt itu, bukan
produknya.

### Gerbang paritas Rust ↔ Python

Pemeriksaan isi (*stemming*, penguraian angka Indonesia, nama diri, aturan
ragam bahasa, penguraian JSON yang toleran) ada **dua kali**: sekali di Rust
untuk aplikasi, sekali di Python untuk benchmark. Keduanya membaca fixture
yang sama, `ml/notulen_bench/fixtures/parity.json`, dari
`rust_core/src/notulen/parity.rs` dan `ml/tests/test_notulen_bench.py`. Tidak
ada sisi yang bisa lolos dengan menyunting harapannya sendiri — satu-satunya
cara menjaga benchmark tetap jujur tentang produk yang tidak ia jalankan.

---

## 4. Kandidat dan lisensi

| Model | Tag Ollama | Param | Kuantisasi | Konteks | Lisensi | Boleh dibundel? | Khusus Indonesia? |
|-------|-----------|-------|------------|---------|---------|-----------------|-------------------|
| Qwen3 4B | `qwen3:4b` | 4.0B | Q4_K_M | 40.960 | Apache-2.0 | **Ya** | Tidak |
| Qwen3 8B | `qwen3:8b` | 8.2B | Q4_K_M | 40.960 | Apache-2.0 | **Ya** | Tidak |
| Gemma 3 4B | `gemma3:4b` | 4.3B | Q4_K_M | 131.072 | Gemma Terms of Use | Perlu kajian hukum | Tidak |
| Gemma 3 12B | `gemma3:12b` | 12.2B | Q4_K_M | 131.072 | Gemma Terms of Use | Perlu kajian hukum | Tidak |
| Sahabat-AI 9B | `Supa-AI/gemma2-9b-cpt-sahabatai-v1-instruct:q4_k_s` | 9.2B | Q4_K_S | 8.192 | Gemma Community License | Perlu kajian hukum | **Ya** |
| Apertus-SEA-LION v4 8B | `aisingapore/Apertus-SEA-LION-v4-8B-IT:q4_k_m` | 8.1B | Q4_K_M | 65.536 | Apache-2.0 | **Ya** | **Ya** |

### Catatan lisensi

- **Apache-2.0** (Qwen3, Apertus-SEA-LION): izin tanpa syarat untuk
  penggunaan komersial, modifikasi, dan distribusi. Ini satu-satunya kelas
  lisensi yang dapat direkomendasikan tanpa catatan kepada instansi.
- **Gemma Terms of Use** (Gemma 3): mengizinkan penggunaan komersial tetapi
  membawa **kebijakan pembatasan penggunaan** dan **kewajiban meneruskan
  ketentuan** pada setiap redistribusi. Dapat *direkomendasikan*; sebelum
  *dibundel* perlu tinjauan hukum.
- **Gemma Community License** (Sahabat-AI, yang merupakan CPT di atas
  Gemma 2): sama seperti di atas. Tambahan: GGUF yang dipakai di sini
  diterbitkan ulang oleh pihak ketiga (Supa-AI), **bukan** oleh penulis
  modelnya — satu lapisan kepercayaan lagi yang harus ditanggung instansi.

Trareon **tidak membundel bobot model apa pun**. Pengguna memasangnya lewat
Ollama, dan lisensinya adalah hubungan antara pengguna dan penerbit model.
Yang diputuskan dokumen ini adalah **apa yang direkomendasikan aplikasi**,
dan rekomendasi baku jatuh ke lisensi Apache-2.0 justru karena pembedaan
ini tidak perlu dijelaskan kepada panitia pengadaan.

### Model yang dipertimbangkan dan dikeluarkan

| Model | Alasan dikeluarkan |
|-------|--------------------|
| Sahabat-AI v2 70B (Llama 3.1 70B) | 70B pada Q4 ≈ 40 GB; di luar semua laptop yang ditarget produk |
| Gemma-SEA-LION-v4 27B-IT | 27B pada Q4 ≈ 17 GB; di luar mesin target 16 GB |
| SEA-LION v4 (Qwen 32B) | 32B pada Q4 ≈ 20 GB; alasan yang sama |
| Cendol-7B, Komodo-7B | Tidak ada tag Ollama aktif dan tidak ada aktivitas penerbit 2026; putaran riset terdahulu sudah menandai keduanya belum terverifikasi |
| Gemma-SEA-LION-v3-9B-IT | Digantikan lini v4 — keluarga yang sama dengan konteks lebih panjang dan lisensi lebih jelas. **Ini model yang direkomendasikan riset Sprint 0 sebagai bawaan**, dan penggantinya (Apertus-SEA-LION v4 8B) yang diuji di sini |

---

## 5. Metrik

Enam metrik, masing-masing ada karena sebuah model bisa unggul di yang lain
dan tetap tidak terpakai.

| Metrik | Yang diukur | Mengapa perlu |
|--------|-------------|---------------|
| **Struktur** | Bagian wajib templat yang terisi | Naskah dinas yang kehilangan satu bagian wajib tidak sah sebagai naskah |
| **Faithfulness** | Pernyataan yang didukung transkrip (ambang tumpang-tindih kata isi 0,35, mencerminkan `factcheck::MIN_DUKUNGAN`) | Keputusan yang dikarang di dalam naskah yang ditandatangani adalah satu-satunya kegagalan yang berakibat hukum |
| **Akurasi sitasi** | Pernyataan yang nomor segmennya ada **dan** cocok | Pernyataan benar dengan tautan rusak adalah cacat yang berbeda dari pernyataan yang dikarang; dilaporkan terpisah |
| **Formalitas** | Taat aturan ragam dinas (EYD V, istilah dinas) | Notulen dalam ragam percakapan harus ditulis ulang dengan tangan, yang menghapus alasan membuatnya dengan mesin |
| **Tindak lanjut F1** | Tugas yang cocok dengan *gold* pada ambang tumpang-tindih 0,5 (cocok pada parafrasa, menolak dua tugas berbeda yang berbagi satu kata benda) | Tabel tindak lanjut adalah yang dibaca pimpinan |
| **PJ benar** | Penanggung jawab yang benar, **atas tugas yang cocok saja** | Model bisa menyusun ringkasan indah dan menjatuhkan setiap penanggung jawab |
| **Keputusan dikarang** | Jumlah keputusan yang dihasilkan untuk rapat yang *gold*-nya tidak punya keputusan | Modus kegagalan paling merusak; diuji langsung oleh kasus 07 |
| Latensi, token/detik, jejak memori | Diukur runner dari tanggapan Ollama dan `/api/ps` | Model bisa unggul di semuanya pada 0,4 token/detik di perangkat yang dimiliki pengguna |

### Komposit

```
komposit = 0,35 × faithfulness
         + 0,25 × struktur
         + 0,20 × tindak lanjut F1
         + 0,20 × formalitas
```

Bobotnya, dan alasannya: **faithfulness 0,35** karena keputusan yang dikarang
di naskah bertanda tangan adalah satu-satunya kegagalan yang berakibat
hukum; **struktur 0,25** karena bagian wajib yang hilang membuat dokumen
tidak terpakai sebagai naskah dinas; **tindak lanjut 0,20** karena itu yang
dibaca pimpinan; **formalitas 0,20** karena ragam yang salah berarti
penulisan ulang manual. Kasus yang gagal diparsing berkomposit **0**, bukan
dikeluarkan dari rata-rata.

Bobot adalah bagian dari laporan, bukan bagian dari data: `report._composite`
menghitung ulang dari metrik tersimpan, sehingga mengubah bobot tidak
menuntut mengulang inferensi berjam-jam.

### ROUGE dilaporkan, tidak diperingkat

ROUGE ada karena itu angka yang dilaporkan literatur, dan **dikeluarkan dari
komposit** karena alasan yang terus ditemukan ulang literatur: ia mengganjar
peniruan kata-kata rujukan. Notulen yang baik bisa memakai diksi dinas yang
berbeda dari notulen rujukan dan tetap benar. ROUGE dilaporkan sebagai
konteks, bukan sebagai peringkat.

### Bagian yang tidak diproduksi rapat tidak dituntut

Kasus 07 adalah sosialisasi yang tidak mengambil keputusan. Menurunkan
nilainya karena bagian **Keputusan** kosong akan mengganjar persis pengarangan
yang hendak ditangkap pemeriksaan fakta, jadi bagian yang *gold*-nya kosong
dilewati dari penilaian struktur dan dipakai sebagai uji anti-halusinasi.

---

## 6. Hasil

<!-- BAKEOFF-TABLES-START -->
<!-- BAKEOFF-TABLES-END -->
