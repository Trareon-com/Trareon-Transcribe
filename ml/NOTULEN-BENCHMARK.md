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

### 6.1 Tabel utama — 8 kasus yang sama untuk setiap model

| Model | Komposit | Struktur | Faithful | Sitasi | Formal | Tindak lanjut F1 | PJ benar | Keputusan dikarang | ROUGE-1 | ROUGE-L | Detik/rapat | tok/s | Kasus ok |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Gemma 3 12B | **0.868** | **1.000** | 0.912 | 0.715 | 1.000 | **0.495** | **0.875** | **0** | **0.593** | **0.454** | 277 | 3.7 | **8/8** |
| **Qwen3 8B** *(bawaan)* | **0.816** | 0.906 | **1.000** | **1.000** | 0.996 | 0.202 | 0.750 | **0** | 0.507 | 0.356 | 226 | 7.8 | **8/8** |
| Gemma 3 4B | **0.810** | 0.969 | 0.835 | 0.613 | 1.000 | 0.377 | 0.625 | **1** | 0.536 | 0.386 | **23** | **62.1** | **8/8** |
| Qwen3 4B | **0.760** | 0.821 | 0.917 | 0.857 | 0.994 | 0.177 | 0.714 | **0** | 0.442 | 0.307 | 29 | 60.6 | 7/8 |
| Apertus-SEA-LION v4 8B | **0.703** | 0.688 | 0.875 | **1.000** | 1.000 | 0.125 | 0.750 | **1** | 0.359 | 0.234 | 159 | 9.4 | **4/8** |
| Sahabat-AI 9B (Gemma2 CPT) | **0.350** | **0.000** | 1.000\* | 1.000\* | 0.000 | 0.000 | 0.000 | 0 | 0.000 | 0.000 | 85 | 7.5 | 6/8 |

\* hampa — tidak ada pernyataan untuk diperiksa.

Rata-rata hanya atas kasus yang berhasil; kolom **Kasus ok** adalah
penyebutnya. Model yang gagal separuh set dan unggul di sisanya belum
menang, dan rata-rata yang menyembunyikan penyebutnya akan membiarkannya
menang.

> **Membaca baris Sahabat-AI.** Komposit 0,350 bukan "lumayan". Struktur
> 0,000 berarti **tidak satu pun bagian wajib terisi di satu kasus pun**.
> Faithfulness dan akurasi sitasi bernilai 1,000 secara hampa — tidak ada
> pernyataan untuk diperiksa. Angka 0,350 yang tersisa seluruhnya datang
> dari bobot faithfulness, dan itu adalah **lantai metrik, bukan skor**.
> Lihat §6.4.

### 6.2 Komposit per kasus

| Kasus | Gemma 3 12B | Qwen3 8B | Gemma 3 4B | Qwen3 4B | Apertus 8B | Sahabat-AI 9B |
|---|---|---|---|---|---|---|
| `01-rakor-pagu` | 0.856 | **0.857** | 0.770 | 0.827 | 0.738 | 0.350 |
| `02-rapat-teknis-spbe` (alih-kode) | **0.914** | 0.668 | 0.867 | 0.667 | GAGAL | GAGAL |
| `03-ba-serah-terima` | **1.000** | 0.933 | **1.000** | 0.613 | 0.900 | GAGAL |
| `04-risalah-rdp-komisi` | **0.933** | 0.871 | 0.837 | **0.933** | GAGAL | 0.350 |
| `05-standup-produk` (alih-kode) | 0.780 | **0.800** | 0.660 | 0.683 | 0.633 | 0.350 |
| `07-sosialisasi-tanpa-keputusan` | **0.800** | **0.800** | 0.783 | **0.800** | 0.542 | 0.350 |
| `08-ba-pemeriksaan-kas` | 0.763 | **0.800** | 0.763 | GAGAL | GAGAL | 0.350 |
| `10-risalah-sidang-etik` | **0.900** | 0.800 | 0.800 | 0.800 | GAGAL | 0.350 |

Gemma 3 12B unggul paling lebar justru pada kasus yang paling sulit:
`02-rapat-teknis-spbe` (alih-kode ID–EN berat, 0,914 lawan 0,668 milik
Qwen3 8B) dan `10-risalah-sidang-etik` (ragam formal tinggi, 0,900 lawan
0,800).

### 6.3 Ukuran, lisensi, dan jejak memori terukur

| Model | Parameter | Kuantisasi | Konteks | Lisensi | Boleh dibundel? | Residen (GiB) | Muat di VRAM (GiB) |
|---|---|---|---|---|---|---|---|
| Gemma 3 12B | 12.2B | Q4_K_M | 131.072 tok | Gemma Terms of Use | perlu kajian hukum | **8.3** | 3.2 |
| Qwen3 8B | 8.2B | Q4_K_M | 40.960 tok | **Apache-2.0** | **ya** | 6.1 | 3.9 |
| Gemma 3 4B | 4.3B | Q4_K_M | 131.072 tok | Gemma Terms of Use | perlu kajian hukum | **2.7** | 2.7 |
| Qwen3 4B | 4.0B | Q4_K_M | 40.960 tok | **Apache-2.0** | **ya** | 3.6 | 3.6 |
| Apertus-SEA-LION v4 8B | 8.1B | Q4_K_M | 65.536 tok | **Apache-2.0** | **ya** | 5.9 | 4.0 |
| Sahabat-AI 9B | 9.2B | Q4_K_S | 8.192 tok | Gemma Community License | perlu kajian hukum | 6.7 | 3.6 |

**Residen** adalah jejak total saat menghasilkan; **Muat di VRAM** adalah
bagian yang benar-benar berada di kartu. Selisihnya ditanggung RAM
sistem, dan selisih itulah yang menjelaskan tabel latensi: Gemma 3 4B muat
seluruhnya (2,7 dari 2,7 GiB) dan berjalan 62 token/detik; Gemma 3 12B
hanya menaruh 3,2 dari 8,3 GiB di kartu dan turun ke 3,7 token/detik —
enam belas kali lebih lambat untuk model dari keluarga yang sama.

Catatan satuan: `ollama list` melaporkan GB desimal, `/api/ps` melaporkan
bita. Keduanya di sini dinyatakan dalam GiB. Gemma 3 4B diunduh 3,1 GiB
tetapi residen hanya 2,7 — tag multimodalnya membawa proyektor visi yang
tidak pernah dimuat permintaan teks.

### 6.4 Kasus yang gagal — seluruhnya

| Model | Kasus | Kegagalan |
|---|---|---|
| Qwen3 4B | `08-ba-pemeriksaan-kas` | jawaban model tidak memuat objek JSON notulen |
| Apertus-SEA-LION v4 8B | `02-rapat-teknis-spbe` | **batas waktu 900 detik terlampaui** |
| Apertus-SEA-LION v4 8B | `04-risalah-rdp-komisi` | jawaban model tidak memuat objek JSON notulen |
| Apertus-SEA-LION v4 8B | `08-ba-pemeriksaan-kas` | **batas waktu 900 detik terlampaui** |
| Apertus-SEA-LION v4 8B | `10-risalah-sidang-etik` | jawaban model tidak memuat objek JSON notulen |
| Sahabat-AI 9B | `02-rapat-teknis-spbe` | jawaban model tidak memuat objek JSON notulen |
| Sahabat-AI 9B | `03-ba-serah-terima` | jawaban model tidak memuat objek JSON notulen |

Gemma 3 12B, Gemma 3 4B, dan Qwen3 8B tidak gagal sekali pun.

#### Sahabat-AI 9B: yang sebenarnya dikembalikan

Enam kasus "berhasil" Sahabat-AI adalah JSON yang sah dan sama sekali
bukan notulen. Keluaran mentah untuk `01-rakor-pagu`, apa adanya
(`results/raw/Supa-AI_gemma2-9b-cpt-sahabatai-v1-instruct_q4_k_s__01-rakor-pagu.txt`):

```json
{
  "id": "1",
  "name": "John Doe",
  "email": "john.doe@example.com",
  "phone": "123-456-7890",
  "address": {
    "street": "123 Main St",
    "city": "Anytown",
    "state": "CA",
    "zip": "90210"
  }
}
```

Model ini mengabaikan seluruh prompt — transkrip rapat Indonesia 11
menit, skema notulen, dan instruksi ragam dinas — lalu mengeluarkan objek
contoh generik. Bukan sekali: pola yang sama di enam kasus, dan dua kasus
sisanya gagal diparsing sama sekali.

Prompt kasus 01 berukuran ~2.500 token, jauh di bawah jendela 8.192 token
model ini, jadi ini **bukan** pemotongan konteks. Dugaan paling masuk akal
adalah interaksi antara `format: json` Ollama dengan model yang
di-*continued-pretrain* untuk percakapan bahasa Indonesia dan tidak
di-*post-train* untuk keluaran berskema — tetapi penyebabnya tidak
diinvestigasi lebih jauh, dan **pernyataan ini adalah dugaan, bukan
temuan**.

Yang pasti dan terukur: **model dengan skor SEA-HELM bahasa Indonesia
tertinggi di kelasnya tidak dapat menjalankan tugas ini sama sekali.**

#### Apertus-SEA-LION v4 8B: tidak dapat diandalkan

Empat dari delapan kasus gagal. Dua di antaranya **melewati batas 900
detik** — pada `02-rapat-teknis-spbe` percobaan pertama bahkan berjalan
lebih dari 1.300 detik sebelum dihentikan. Kasus yang berhasil pun lambat
dan tidak merata: 413 detik untuk `01-rakor-pagu`, 37 detik untuk
`05-standup-produk`.

Pada kasus `07` — uji anti-halusinasi — ia mengarang satu keputusan untuk
rapat yang tidak mengambil keputusan apa pun:

> "Materi paparannya bisa dibagikan, nanti saya kirim ke pemandu acara
> untuk diteruskan" → dicatat sebagai **keputusan rapat**

Sebuah ucapan percakapan dipromosikan menjadi keputusan dalam naskah yang
akan ditandatangani. Itu persis modus kegagalan yang paling mahal.

---

## 7. Jawaban atas tiga pertanyaan

### 7.1 Apakah pelatihan khusus bahasa Indonesia menang? **Tidak.**

Kedua model yang di-*post-train* untuk Asia Tenggara menempati dua
peringkat terbawah:

| Model | Khusus Indonesia? | Komposit | Kasus ok |
|-------|-------------------|----------|----------|
| Gemma 3 12B | Tidak | **0.868** | 8/8 |
| Qwen3 8B | Tidak | 0.816 | 8/8 |
| Gemma 3 4B | Tidak | 0.810 | 8/8 |
| Qwen3 4B | Tidak | 0.760 | 7/8 |
| Apertus-SEA-LION v4 8B | **Ya** | 0.703 | 4/8 |
| Sahabat-AI 9B | **Ya** | 0.350 | 6/8 (hampa) |

Angka yang menjelaskan mengapa ada di kolom **Formal**: setiap model yang
menghasilkan teks sama sekali mencetak ≥ 0,994 formalitas. Ragam bahasa
Indonesia dinas **tidak pernah menjadi hambatan** bagi satu pun model
dalam uji ini.

Yang menjadi hambatan adalah hal lain: mematuhi skema JSON, mengisi
bagian wajib, menautkan nomor segmen, dan menolak mengarang. Itu
kemampuan mengikuti instruksi berstruktur, bukan kemampuan berbahasa —
dan di situlah model umum yang kuat unggul.

Bukti yang paling tajam ada di kasus alih-kode. `02-rapat-teknis-spbe`
adalah rapat teknis dengan alih-kode ID–EN berat, persis jenis teks yang
seharusnya menjadi keunggulan model Asia Tenggara. Hasilnya: Gemma 3 12B
0,914, Gemma 3 4B 0,867 — sementara kedua model khusus Asia Tenggara
**gagal total** di kasus itu.

Konsekuensi untuk rekomendasi riset Sprint 0: usulan
**Gemma-SEA-LION-v3-9B-IT sebagai bawaan** tidak dapat dipertahankan.
Penggantinya di lini v4 gagal separuh set, dan model dengan skor SEA-HELM
bahasa Indonesia tertinggi di kelasnya tidak dapat menjalankan tugas ini
sama sekali. **Skor benchmark bahasa tidak memprediksi kinerja pada tugas
ini.**

### 7.2 Apakah model lebih besar membeli sesuatu? **Ya, tetapi bukan di tempat yang diduga.**

| Pasangan | Komposit | Struktur | Tindak lanjut F1 | Sitasi | Keputusan dikarang | Detik/rapat |
|----------|----------|----------|------------------|--------|--------------------|-------------|
| Gemma 3 **4B** | 0.810 | 0.969 | 0.377 | 0.613 | **1** | **23** |
| Gemma 3 **12B** | **0.868** | **1.000** | **0.495** | 0.715 | **0** | 277 |
| Qwen3 **4B** | 0.760 | 0.821 | 0.177 | 0.857 | 0 | 29 |
| Qwen3 **8B** | 0.816 | 0.906 | 0.202 | **1.000** | 0 | 226 |

Dua pola, dan keduanya berlaku di dalam keluarga, bukan antarkeluarga:

- **Naik ukuran membeli kelengkapan dan tindak lanjut.** Gemma 3 4B → 12B:
  struktur 0,969 → 1,000, tindak lanjut F1 0,377 → 0,495, dan keputusan
  dikarang 1 → 0. Qwen3 4B → 8B: struktur 0,821 → 0,906, sitasi 0,857 →
  1,000.
- **Naik ukuran tidak membeli sitasi, dan keluarga yang menentukan.**
  Kedua model Gemma berada di 0,61–0,72 akurasi sitasi; kedua model Qwen3
  di 0,86–1,00. Selisih 12 miliar parameter tidak menutup selisih
  keluarga.

Itu penting karena akurasi sitasi adalah yang membuat provenance dan
Periksa Fakta Trareon berguna: pernyataan yang nomor segmennya tidak
cocok tidak dapat ditelusuri balik ke transkrip oleh notulis maupun oleh
mesin.

### 7.3 Berapa harganya dalam waktu tunggu? **Sampai enam belas kali.**

23 detik (Gemma 3 4B) versus 277 detik (Gemma 3 12B) per rapat, pada GPU
6 GiB yang sama, untuk model dari keluarga yang sama. Penyebabnya terbaca
di §6.3: Gemma 3 4B muat seluruhnya di VRAM; Gemma 3 12B hanya menaruh
3,2 dari 8,3 GiB di kartu, sisanya di RAM sistem — 3,7 token/detik lawan
62,1.

Untuk rapat satu jam pada mesin tanpa GPU sama sekali, semua angka itu
naik satu orde besaran lagi. Itulah sebabnya katalog aplikasi tetap
menawarkan pilihan ringan dan tidak memaksa bawaan.

### 7.4 Angka himpunan penuh (bukan pembanding)

Dua model dijalankan atas lebih banyak kasus. Angkanya **tidak boleh**
disandingkan dengan tabel §6.1 — himpunan kasusnya berbeda — tetapi
berguna sebagai pemeriksaan kestabilan:

| Model | Kasus | Komposit | Struktur | Faithful | Sitasi | Tindak lanjut F1 |
|-------|-------|----------|----------|----------|--------|------------------|
| Qwen3 8B | 16 | 0.816 | 0.870 | 0.988 | 0.988 | 0.265 |
| Qwen3 4B | 24 | 0.769 | 0.757 | 0.964 | 0.862 | 0.212 |

Komposit Qwen3 8B **tidak bergerak** dari 8 ke 16 kasus (0,816 → 0,816),
dan Qwen3 4B naik tipis (0,760 → 0,769). Peringkat keduanya stabil.

### 7.5 Kelemahan yang dimiliki **semua** model

**Ekstraksi tindak lanjut.** F1 tertinggi di seluruh tabel adalah **0,495**
(Gemma 3 12B); bawaan hanya 0,202. Artinya: bahkan model terbaik
melewatkan atau salah menyusun sekitar separuh baris tabel tindak lanjut —
tabel yang justru paling dibaca pimpinan.

Akurasi penanggung jawab (0,609–0,875) diukur **hanya atas tugas yang
cocok**, jadi angka itu tidak menebus F1 yang rendah; ia hanya mengatakan
bahwa dari tugas yang berhasil ditemukan, sebagian besar penanggung
jawabnya benar.

Ini **celah terukur yang paling jelas** dari seluruh uji banding, dan
kandidat utama untuk penyetelan halus (lihat §9, Item 5).

---

## 8. Keputusan

### 8.1 Model dengan skor tertinggi **bukan** model bawaan

Gemma 3 12B menang di komposit (0,868), struktur (1,000), tindak lanjut
(0,495), penanggung jawab (0,875), dan ROUGE — tanpa satu pun kasus gagal
dan tanpa satu pun keputusan dikarang. Dokumen ini tetap menetapkan
**Qwen3 8B** sebagai bawaan. Alasannya harus disebut terang, karena ini
keputusan yang bertentangan dengan angka utamanya:

| | Qwen3 8B | Gemma 3 12B |
|---|---|---|
| Komposit | 0.816 | **0.868** |
| **Akurasi sitasi** | **1.000** | 0.715 |
| **Lisensi** | **Apache-2.0** | Gemma Terms of Use |
| Residen | **6.1 GiB** | 8.3 GiB |
| Kecepatan | **7.8 tok/s** | 3.7 tok/s |

Tiga alasan, berurut:

1. **Lisensi.** Bawaan adalah model yang dikonfigurasi aplikasi **tanpa
   bertanya** kepada pengguna. Gemma Terms of Use mengizinkan penggunaan
   komersial tetapi membawa kebijakan pembatasan penggunaan dan kewajiban
   meneruskan ketentuan. Memilihkan lisensi berkondisi untuk instansi
   tanpa bertanya bukan keputusan yang boleh diambil perangkat lunak.
   Dikunci uji: `the_default_model_is_in_the_catalogue_and_is_cleanly_licensed`.
2. **Akurasi sitasi 1,000 lawan 0,715.** Provenance butir→segmen dan
   Periksa Fakta adalah fitur yang membedakan Trareon; keduanya hanya
   bekerja bila nomor segmen yang disebut model benar-benar cocok. Bawaan
   dengan sitasi 0,715 akan menampilkan tanda "rujukan tidak cocok" pada
   hampir tiga dari sepuluh pernyataan, pada pengguna yang tidak memilih
   apa pun.
3. **Jejak memori.** 8,3 GiB residen pada mesin 16 GB menyisakan sedikit
   untuk sisa sistem plus model Whisper Trareon sendiri; 6,1 GiB tidak.

**Gemma 3 12B tetap ditawarkan sebagai pilihan Berat**, dengan catatan
yang menyebut bahwa ia **berskor tertinggi di uji banding** sekaligus
menyebut tiga harga di atas. Pengguna yang membaca dan memilihnya
mengambil keputusan yang berbeda dari bawaan dengan sadar — dan itu sah.

### 8.2 Model bawaan: **Qwen3 8B** (`qwen3:8b`)

`rust_core/src/llm_setup.rs::DEFAULT_MODEL`

1. **Akurasi sitasi 1,000** — satu-satunya model yang membuat provenance
   Trareon bekerja sepenuhnya.
2. **Nol keputusan dikarang** di seluruh kasus — satu-satunya kegagalan
   yang berakibat hukum pada naskah bertanda tangan.
3. **8/8 keluaran dapat diparsing**, dan komposit tidak bergerak dari 8 ke
   16 kasus.
4. **Apache-2.0** — tidak ada kajian lisensi yang harus dijelaskan kepada
   panitia pengadaan.
5. Komposit kedua tertinggi (0,816).

Harga yang dibayar: 226 detik per rapat pada GPU 6 GiB, dan tindak lanjut
F1 hanya 0,202 — jauh di bawah 0,495 milik Gemma 3 12B. Kelemahan kedua
itu adalah sasaran langsung penyetelan halus (§9).

### 8.3 Pilihan ringan: **Qwen3 4B** dan **Gemma 3 4B**, keduanya ditawarkan

Gemma 3 4B **mengukur lebih tinggi** (0,810 vs 0,760) dan sedikit lebih
cepat (23 vs 29 detik). Qwen3 4B tetap didahulukan di daftar karena:

| | Qwen3 4B | Gemma 3 4B |
|---|---|---|
| Keputusan dikarang | **0** | **1** |
| Akurasi sitasi | 0.857 | **0.613** |
| Lisensi | **Apache-2.0** | Gemma Terms of Use |

Gemma 3 4B mengarang satu keputusan pada `07-sosialisasi-tanpa-keputusan`,
sebuah rapat yang tidak memutuskan apa pun:

> "Narasumber akan melakukan kajian lebih lanjut mengenai perlakuan
> terhadap rekaman rapat yang berisi suara pegawai." → dicatat sebagai
> **keputusan rapat**

Keduanya tetap ada di katalog, dan catatan Gemma 3 4B menyebut dua hal itu
apa adanya, karena kecepatannya nyata dan sebagian pengguna akan tetap
memilihnya.

### 8.4 Pilihan berat: **Gemma 3 12B** (`gemma3:12b`)

Skor tertinggi di uji banding; lihat §8.1 untuk mengapa ia bukan bawaan.

### 8.5 Dikeluarkan dari katalog aplikasi

| Model | Alasan |
|-------|--------|
| **Sahabat-AI 9B** | Tidak menghasilkan notulen sama sekali (§6.4). Menawarkan model ini di layar penyiapan berarti menyuruh pengguna mengunduh 5,5 GB untuk mendapatkan objek "John Doe". |
| **Apertus-SEA-LION v4 8B** | Gagal 4 dari 8 kasus, dua di antaranya melewati 900 detik, dan mengarang satu keputusan. Lisensinya bersih dan ia khusus Asia Tenggara — tetapi katalog adalah daftar yang **direkomendasikan aplikasi**, dan model yang gagal separuh waktu tidak dapat direkomendasikan. |

Keduanya tetap ada di himpunan kandidat benchmark
(`ml/notulen_bench/models.py`) supaya hasilnya dapat diulang dan supaya
rilis berikutnya dari kedua keluarga dapat diukur ulang terhadap angka
yang sama. Keputusan ini dikunci uji
`the_two_models_the_bake_off_rejected_stay_out_of_the_catalogue`.

### 8.6 Katalog aplikasi setelah uji banding

| Tingkat | Model | Lisensi | Alasan |
|---------|-------|---------|--------|
| Ringan | Qwen3 4B | Apache-2.0 | Laptop tanpa kartu grafis; nol keputusan dikarang |
| Ringan | Gemma 3 4B | Gemma Terms of Use | Tercepat (23 dtk/rapat); **mengarang satu keputusan**, sitasi lemah |
| **Seimbang (bawaan)** | **Qwen3 8B** | **Apache-2.0** | Sitasi sempurna, nol karangan, lisensi bersih |
| Berat | Gemma 3 12B | Gemma Terms of Use | **Skor tertinggi**; butuh 8,3 GiB dan lisensinya perlu kajian |

---

## 9. Batasan — baca sebelum mengutip angka mana pun

| # | Batasan |
|---|---------|
| 1 | **Dataset sintetis.** 24 rapat disusun untuk uji ini, bukan rapat nyata. Angka di sini mengukur kinerja pada transkrip yang menyerupai rapat dinas, bukan pada rapat dinas. |
| 2 | **Satu mesin.** Seluruh latensi diukur pada satu laptop RTX 2060 6 GiB. Pada GPU yang lebih besar peringkat kecepatannya pasti berubah — Gemma 3 12B paling dirugikan 6 GiB dan paling diuntungkan kartu besar. Peringkat kualitasnya tidak bergantung perangkat keras. |
| 3 | **Himpunan 8 kasus.** Cukup untuk memisahkan kegagalan besar dari keberhasilan, terlalu kecil untuk memisahkan 0,816 dari 0,810 secara statistik. Selisih Qwen3 8B dan Gemma 3 4B **tidak** signifikan; keputusan §8.3 diambil atas modus kegagalan, bukan atas selisih komposit. Selisih Gemma 3 12B (0,868) terhadap keduanya lebih lebar, tetapi tetap atas delapan kasus. |
| 4 | **Satu kali jalan per pasangan.** `temperature: 0.2`, bukan 0. Tidak ada pengulangan, jadi tidak ada ukuran varians. |
| 5 | **Tanpa tinjauan manusia menyeluruh.** Metrik isi bersifat leksikal. Keluaran mentah ditinjau untuk kasus yang mencolok (§6.4), bukan dinilai per butir oleh notulis. |
| 6 | **Jalur map-reduce tidak diuji di sini.** Himpunan 8 kasus tidak memuat rapat 30 menit (`23-risalah-panjang-anggaran`), sehingga jalur peringkasan bertahap untuk rapat panjang tidak terwakili tabel ini. |
| 7 | **ROUGE bukan peringkat.** Lihat §5. |

### Yang TIDAK DIJALANKAN

| Hal | Status | Alasan |
|-----|--------|--------|
| 16 kasus sisa untuk Gemma 3 12B, Gemma 3 4B, Apertus, Sahabat-AI | **TIDAK DIJALANKAN** | Anggaran inferensi sprint. Tabel pembanding sengaja dibatasi ke 8 kasus yang sama untuk semua. |
| 8 kasus sisa untuk Qwen3 8B (dari 24) | **TIDAK DIJALANKAN** | Sama. |
| Pengulangan per pasangan untuk mengukur varians | **TIDAK DIJALANKAN** | Sama. |
| Pengukuran pada CPU tanpa GPU | **TIDAK DIJALANKAN** | Mesin uji punya GPU. Angka CPU-saja akan menjadi tebakan, dan dokumen ini tidak memuat tebakan. |
| Penyebab kegagalan Sahabat-AI | **TIDAK DIINVESTIGASI** | Dugaan di §6.4 ditandai sebagai dugaan. |
| Penyetelan halus (Item 5 brief sprint) | **TIDAK DIJALANKAN** | Celahnya **sudah teridentifikasi** dan tajam — ekstraksi tindak lanjut, F1 ≤ 0,495 untuk setiap model, dan hanya 0,202 untuk bawaan (§7.5). Kit penyetelan tidak dibuat karena GPU yang sama terpakai penuh untuk uji banding ini sepanjang sprint. Direkomendasikan sebagai pekerjaan sprint berikutnya, dengan sasaran yang sudah jelas: ekstraksi tugas/penanggung jawab/tenggat di atas Qwen3 4B, dievaluasi ulang dengan harness yang sama sehingga angkanya langsung sebanding dengan §6.1. |

---

## 10. Mengulang pengukuran ini

```sh
cd ml

# 1. Cetak ulang prompt dari mesin, supaya benchmark menguji produknya
#    (dijalankan dari rust_core/)
TRAREON_DUMP_PROMPTS=1 cargo test --lib notulen::prompt

# 2. Lihat pekerjaan yang tertunda tanpa menjalankan apa pun
python -m notulen_bench.run --list

# 3. Jalankan, dapat dilanjutkan dan berbatas waktu
python -m notulen_bench.run \
  --models qwen3:8b qwen3:4b gemma3:4b gemma3:12b \
  --cases 01-rakor-pagu 02-rapat-teknis-spbe 03-ba-serah-terima \
          04-risalah-rdp-komisi 05-standup-produk \
          07-sosialisasi-tanpa-keputusan 08-ba-pemeriksaan-kas \
          10-risalah-sidang-etik \
  --budget 3600 --timeout 900

# 4. Ringkas, dibatasi ke himpunan kasus yang sama
python -m notulen_bench.report --cases 01-rakor-pagu 02-rapat-teknis-spbe \
  03-ba-serah-terima 04-risalah-rdp-komisi 05-standup-produk \
  07-sosialisasi-tanpa-keputusan 08-ba-pemeriksaan-kas 10-risalah-sidang-etik

# 5. Gerbang paritas: kedua sisi membaca fixture yang sama
python -m pytest tests/test_notulen_bench.py        # dari ml/
cargo test --lib notulen::parity                    # dari rust_core/
```

Setiap pasangan (model, kasus) ditulis ke JSONL begitu selesai, dan
pemanggilan berikutnya melewati apa yang sudah ada. `--budget` berhenti
dengan rapi pada batas waktu, sehingga uji berjam-jam dapat dijalankan
dalam irisan. Kegagalan transport — termasuk batas waktu — dicatat sebagai
kasus gagal dan tidak menghentikan sisanya.

---

*Diukur 5–7 Oktober 2026 · Trareon Transcribe Sprint 7 ·
`ml/notulen_bench/results/results.jsonl` adalah datanya; dokumen ini
hanya membacanya.*
