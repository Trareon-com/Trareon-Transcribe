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

## Keterbatasan riset (harus jujur diakui)

- Korpus **buatan sendiri** (40 dokumen+40 query ditulis sendiri) — ada
  risiko bias penulis tahu jawaban yang "benar", walau query sengaja
  diparaphrase.
- Belum tes di **hardware low-end nyata** (RTX2060 laptop/CPU tua) — angka
  latency di atas dari CPU Kali, bukan representasi perangkat pengguna akhir.
- Belum tes **dataset arsip rapat asli** (transkrip nyata hasil rekaman,
  bukan teks ditulis manual) — tes ini murni semantic retrieval teks bersih.
- Belum ada perbandingan **recall@3/recall@5** yang lebih relevan untuk
  use-case chat arsip rapat (user biasanya oke dapat jawaban dari salah satu
  dari beberapa kandidat teratas, bukan cuma ranking #1 ketat).

## Keputusan

**BELUM diputuskan ganti model produksi.** Gap kualitas (80% vs 100%) nyata
dan konsisten, tapi trade-off kecepatan 15,6x signifikan untuk target
perangkat low-end. Rekomendasi sebelum keputusan final:
1. Uji latency riil di hardware target (laptop lama/low-end), bukan cuma Kali.
2. Uji dengan transkrip rapat ASLI (bukan korpus buatan), idealnya dari
   arsip F12 yang sudah ada.
3. Kalau upgrade terjadi, evaluasi versi quantization lain (int8 penuh, atau
   model distilled) buat tutup gap kecepatan.
