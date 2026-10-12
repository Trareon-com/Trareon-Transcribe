# Benchmark Embedding: IndonesianEmbedder vs EmbeddingGemma 2

Status: **riset selesai, keputusan upgrade produksi BELUM diambil.**
Dilakukan Oktober 2026, trigger: riset kompetitor menemukan Google AI
Edge Foresight memakai EmbeddingGemma 2 sebagai model retrieval-nya
(lihat `docs/COMPETITOR-RESEARCH.md` §1.18).

## Model yang dibandingkan

| | Model kita (`IndonesianEmbedder`) | EmbeddingGemma 2 (Google) |
|---|---|---|
| Sumber | `asmud/indonesian-embedding-small` | `onnx-community/embeddinggemma-2-ONNX` |
| Lisensi | — (cek repo asal) | Apache 2.0 |
| Ukuran file (ONNX q8/q4) | 118 MB | 174 MB |
| Dimensi embedding | 384 | 768 |
| Bahasa | Bahasa Indonesia saja | 100+ bahasa (Google: "kualitas tidak seragam di semua bahasa") |
| Kemampuan | Teks saja | Multimodal (teks/gambar/video/audio) — graph ONNX unified, butuh tensor kosong `[0,512]` utk 3 modalitas kalau dipakai mode teks-saja |

## Metodologi benchmark

- **40 dokumen** potongan transkrip rapat Bahasa Indonesia realistis, lintas-domain
  (anggaran, SDM, IT, hukum, logistik, marketing, kesehatan, pemerintahan, keamanan,
  PR, keuangan, audit, pelatihan, kemitraan, pemeliharaan, mutu, layanan pelanggan,
  pengembangan produk, riset, keberlanjutan, manajemen risiko, pengadaan, fasilitas,
  transportasi, asuransi, penggajian, lembur, tunjangan, penilaian kinerja, manajemen
  proyek, pemangku kepentingan, komunikasi internal, budaya kerja, etika, pelaporan
  pelanggaran, privasi data — 40 topik berbeda total).
- **40 query** paraphrase (kosakata SENGAJA tidak identik dengan dokumennya) —
  menguji semantic understanding, bukan keyword match literal.
- Metrik: **Recall@1** (dokumen benar jadi ranking #1 dari 40 kandidat) dan **MRR**.
- Script: `/tmp/run_embedding_benchmark.py` + `/tmp/benchmark_corpus.py` (belum
  dipindah ke repo — korpus buatan sendiri, lihat caveat di bawah).

## Hasil (40 sampel, Oktober 2026)

| Model | Recall@1 | MRR | Latency CPU (per panggilan) |
|---|---|---|---|
| Indonesian-Embedding-Small (kita) | 80,00% (32/40) | 0,8771 | **11,4 ms** |
| EmbeddingGemma 2 (Google) | **100,00%** (40/40) | **1,0000** | 179,0 ms (**15,6x lebih lambat**) |

Catatan: benchmark 8-sampel pertama (smoke test awal) menunjukkan gap lebih
kecil (87,5% vs 100%) — setelah diperbesar ke 40 sampel lintas-domain, gap
kualitas jadi jauh lebih jelas dan konsisten: model kita gagal di 8/40 kasus,
termasuk satu miss parah (query "penjualan" → ranking ke-12, bukan sekadar
tertukar dengan topik berdekatan).

### Kasus miss model kita (Indonesian-Embedding-Small)
| Query | Harusnya | Malah top-1 | Rank benar |
|---|---|---|---|
| sdm | sdm | layanan_pelanggan | 2 |
| evaluasi | evaluasi | kesehatan | 3 |
| penjualan | penjualan | pelatihan | **12** |
| pr | pr | penilaian_kinerja | 2 |
| riset | riset | audit | 3 |
| keberlanjutan | keberlanjutan | riset | 2 |
| tunjangan | tunjangan | kesehatan | 3 |
| penilaian_kinerja | penilaian_kinerja | komunikasi_internal | 2 |

EmbeddingGemma 2 tidak miss sama sekali di 40 sampel ini.

## Trade-off jujur

- **Kualitas**: EmbeddingGemma 2 jelas lebih unggul pada tes ini (100% vs 80%
  Recall@1), dengan margin yang konsisten walau korpus diperbesar 5x.
- **Kecepatan**: model kita **15,6x lebih cepat** di CPU (11,4ms vs 179ms per
  panggilan) — relevan untuk perangkat low-end yang jadi target utama
  Trareon-Transcribe (CPU lemah, bukan selalu ada GPU).
- **Ukuran**: beda tipis (118 MB vs 174 MB), bukan faktor pembeda besar.
- **Bonus**: EmbeddingGemma 2 multimodal gratis (bisa embed gambar/audio/video
  sekaligus) — relevan kalau F12 (chat arsip rapat) mau diperluas ke
  attachment non-teks di masa depan.

## Benchmark dokumen rapat ASLI (public corpus)

Untuk menjawab keterbatasan korpus sintetis di atas, dilakukan benchmark
tambahan dengan dokumen rapat ASLI dari sumber publik Indonesia (non-proprietary,
di-download dan di-chunk langsung dari PDF/wget):

### Sumber dokumen

| # | Dokumen | Asal | Topik |
|---|---|---|---|
| 1 | RDP Komisi I DPR RI, 16 Jan 2018 | DPR RI (CloudFront CDN) | Persetujuan Kerjasama Pertahanan Indonesia-Arab Saudi (RUU DCA) |
| 2 | Parinsipurna Perubahan APBD 2026 & APBD 2027, 14 Sep 2026 | DPRD Kabupaten Bintan (JDIH) | Alokasi belanja modal, infrastruktur, kemiskinan, UMKM |
| 3 | Parinsipurna KUA-PPAS TA 2025, 31 Jul 2024 | DPRD Kabupaten Sumenep (site publik) | Proyeksi pendapatan daerah, belanja daerah, PAD |
| 4 | Pemantauan Rapat Baleg DPR RI, Feb-Mei 2022 | Open Parliament ID | Pembahasan perubahan UU Pembentukan PerUU (DIM, harmonisasi) |
| 5 | Harmonisasi Permenko Tukin Kemenkoinfra, Nov 2025 | JDIH Kemenkoinfra (web extract) | Tunjangan kinerja dinamis/statis, Plt/Plh, peraturan Peralihan |

### Metodologi

- **24 chunk** (~100-300 kata per chunk, dipotong per section/paragraf dari teks asli).
- **8 query realistis** — pertanyaan natural yangMENIRU cara user cari info
  di arsip rapat, berdasarkan isi dokumen ASLI yang benar-benar ada. Contoh:
  - *"Berapa alokasi belanja modal untuk jalan, jaringan, dan irigasi di Perubahan
    APBD Bintan tahun anggaran berjalan?"* (jawaban: 22,36 miliar rupiah)
  - *"Kenapa komponen tunjangan kinerja dinamis dianggap lebih baik?"*
    (jawaban: berbasis capaian kinerja, 60% total tunjangan)
- Ground truth berdasarkan konten spesifik teks asli, bukan asumsi.
- Chunk IDs: `dpr1-01` … `dpr1-04`, `bintan1-01` … `bintan1-05`,
  `sumenep1-01` … `sumenep1-05`, `openpar1-01` … `openpar1-03`,
  `kemkoinf1-01` … `kemkoinf1-03` + 4 chunk tambahan dari ekstraksi web.

### Hasil (24 chunk, 8 query, Oktober 2026)

| Model | Recall@1 | MRR | Latency CPU (avg per-call) |
|---|---|---|---|
| Indonesian-Embedding-Small (kita) | **100,00%** (8/8) | **1,0000** | **229,7 ms** |
| EmbeddingGemma 2 (Google, q4 ONNX) | **100,00%** (8/8) | **1,0000** | 494,1 ms (**2,2x lebih lambat**) |

**Tidak ada satupun miss** di kedua model pada 8 query ini.

Catatan: speed gap turun drastis dibanding benchmark sintetis (15,6x → 2,2x).
Latency absolut kedua model lebih tinggi di benchmark ini (vs benchmark
sintetis) karena teks chunk lebih panjang (100-300 kata vs ~1 kalimat
sintetis sebelumnya).

### Catatan interpretasi

- 8 query terlalu sedikit untuk kesimpulan statistik kuat — ini adalah
  *directional signal*, bukan definitive proof. Tapi hasilnya cukup untuk
  menunjukkan bahwa gap 80%→100% pada korpus sintetis **TIDAK muncul**
  pada dokumen rapat nyata yang sudah dicoba.
- Kemungkinan korpus sintetis (40 topik berbeda, setiap dokumen 1 kalimat)
  lebih mudah discribe oleh EmbeddingGemma yang memang punya vocabularium
  lebih luas, sementara dokumen rapat nyata Indonesia punya konteks yang
  lebih dalam dan spesifik — yang justru ditangkap baik oleh
  IndonesianEmbedder yang dilatih khusus untuk bahasa Indonesia.
- Di korpus asli, **kedua model sama-sama berhasil** menemukan dokumen
  dengan tepat — indikasi kuat bahwa model kita (IndonesianEmbedder)
  sudah cukup bagus untuk use case spesifik Trareon-Transcribe.

### Keterbatasan riset (korpus asli)

- Hanya **5 dokumen asli** (24 chunk) — ruang lingkup kecil, bias
  topik mungkin terjadi. Perluasan ke 10-15+ dokumen dari berbagai
  topik (kesehatan, pendidikan, lingkungan) akan memperkuat hasil.
- 8 query belum mencakup variasi cara bertanya (keyword-based, kontekstual,
  multi-hop reasoning).
- Latency diukur di CPU Kali (bukan perangkat target Trareon-Transcribe
  yang nyata).

## Keterbatasan riset (korpus sintetis)

- Korpus **buatan sendiri** (40 dokumen+40 query ditulis sendiri) — ada
  risiko bias penulis tahu jawaban yang "benar", walau query sengaja
  diparaphrase.
- Belum tes di **hardware low-end nyata** (RTX2060 laptop/CPU tua) — angka
  latency di atas dari CPU Kali, bukan representasi perangkat pengguna akhir.
- Belum tes **dataset arsip rapat asli** (transkrip nyata hasil rekaman,
  bukan teks ditulis manual) — tes sintetis murni semantic retrieval teks bersih.
- Belum ada perbandingan **recall@3/recall@5** yang lebih relevan untuk
  use-case chat arsip rapat (user biasanya oke dapat jawaban dari salah satu
  dari beberapa kandidat teratas, bukan cuma ranking #1 ketat).

## Keputusan

**BELUM diputuskan ganti model produksi.** Hasil korpus asli (8 query):
kedua model sama-sama 100% — indikasi model kita cukup capable. Tapi:
- Korpus asli masih kecil (5 dokumen, 8 query) — perlu diperbesar sebelum
  keputusan final.
- Trade-off kecepatan 2,2x (korpus asli) vs 15,6x (sintetis) cukup
  signifikan untuk perangkat low-end.

Rekomendasi sebelum keputusan final:
1. Perbesar korpus asli ke 15-20 dokumen, 20-25 query lintas-topik
   (kesehatan, pendidikan, lingkungan, ketenagakerjaan, hukum).
2. Uji latency riil di hardware target (laptop lama/low-end), bukan cuma Kali.
3. Kalau upgrade terjadi, evaluasi versi quantization lain (int8 penuh, atau
   model distilled) buat tutup gap kecepatan.
