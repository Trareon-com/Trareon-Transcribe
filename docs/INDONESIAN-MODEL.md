# Model Bahasa Indonesia khusus (eksperimental)

Status: **jalur manual terdokumentasi, tidak terdaftar di katalog model.**
Sprint 4b, item 5.

## Ringkasan keputusan

| | |
|---|---|
| Model terbaik yang terukur | `cahya/whisper-medium-id` — WER **3,83%** (Common Voice 11), **9,74%** (Google FLEURS) |
| Pembanding bawaan Trareon | `large-v3-turbo-q5` — WER ~12–15% untuk Bahasa Indonesia |
| Format yang tersedia | hanya `transformers` (PyTorch). Tidak ada GGML resmi. |
| Keputusan | **tidak** didaftarkan sebagai unduhan di katalog; disediakan skrip konversi + dokumen ini |

Sumber: <https://huggingface.co/cahya/whisper-medium-id>, Research Round 2
§2.5.2 (`docs/RESEARCH-ROUND2.md`).

## Mengapa tidak didaftarkan di katalog

Instruksi sprint berbunyi: daftarkan sebagai model opsional **"hanya jika
ada URL artefak terhosting"**. Pencarian HuggingFace memang menemukan satu:

```
duckywise/whisper-medium-id-ggml
  ggml-medium-id.bin        1,53 GB
  ggml-medium-id-quant.bin  0,44 GB
```

Artefak itu **tidak** dipakai, karena tiga hal yang tidak bisa diabaikan
oleh aplikasi yang memasang SHA256 di dalam binernya sendiri
(`rust_core/src/model.rs`, STRIDE §86.1):

1. **Tidak ada provenans.** Model card-nya hanya berisi lisensi dan
   `base_model: openai/whisper-medium`. Tidak menyebut `cahya` sama sekali,
   tidak menyebut cara konversi, tidak melaporkan WER. Jadi artefak ini
   bukan konversi dari model yang diminta — ia model lain yang kebetulan
   bernama mirip.
2. **Tidak ada pihak yang bisa dimintai pertanggungjawaban.** Unggahan satu
   akun perorangan, 0 unduhan, 0 *like*, terakhir diubah Oktober 2024.
3. **Memasang SHA256-nya tidak menyelesaikan apa pun.** Pin hash melindungi
   dari MITM dan dari server yang berubah; ia tidak melindungi dari berkas
   yang memang sudah tidak sesuai klaimnya sejak awal. Menaruh pin di
   katalog justru akan *terlihat* seperti verifikasi.

Hasilnya: tidak ada entri katalog. Yang disediakan adalah konversi mandiri
yang bisa diulang siapa pun, dengan SHA256 yang dicetak di akhir supaya
sebuah unit kerja bisa mendistribusikan hasilnya sendiri ke timnya.

## Jalur manual

```bash
scripts/convert_hf_whisper_to_ggml.sh cahya/whisper-medium-id --quantize q5_0
```

Yang dilakukan skrip, berurutan:

1. Klon `ggml-org/whisper.cpp` dan `openai/whisper` (shallow). Konverter
   whisper.cpp butuh repo OpenAI untuk *mel filterbank* dan kosakata
   tokenizer.
2. Buat venv Python dan pasang `torch` (CPU-only), `transformers`, `numpy`.
   Konversi hanya membaca bobot dan menulisnya ulang; model tidak pernah
   dijalankan, jadi build CUDA akan jadi unduhan 2 GB tanpa guna.
3. Unduh bobot `transformers` dari HuggingFace.
4. Jalankan `whisper.cpp/models/convert-h5-to-ggml.py` → `ggml-*.bin` (f16,
   ±1,5 GB untuk `medium`).
5. Opsional `--quantize q5_0` → ±0,5 GB.
6. Cetak SHA256 berkas hasil.

Kebutuhan: `python3`, `git`, ±8 GB ruang bebas (bobot PyTorch, GGML f16,
dan GGML terkuantisasi sempat ada bersamaan).

Setelah selesai, salin berkas ke folder model Trareon
(`~/Library/Caches/TrareonTranscribe/models/` di macOS/Linux,
`%LOCALAPPDATA%\TrareonTranscribe\models\` di Windows).

## Yang harus diukur sebelum dipakai untuk rapat sungguhan

**WER 3,83% itu diukur pada Common Voice, bukan pada rekaman rapat.**
Perbedaannya besar dan terarah:

- Common Voice adalah satu pembicara, membaca kalimat tertulis, mikrofon
  dekat, tanpa derau. Rapat adalah banyak pembicara, bicara spontan,
  mikrofon jauh, dengan AC dan kursi berderit.
- `medium` adalah 769 M parameter — lebih lambat daripada
  `large-v3-turbo-q5` pada CPU lemah, sehingga jelas tidak cocok untuk
  pratinjau langsung. Tempatnya adalah jalur pasca-rapat (impor berkas,
  "Transkrip Ulang", atau *completion pass*), yang tidak punya batas
  waktu nyata.
- Fine-tune Bahasa Indonesia bisa *lebih buruk* pada *code-switching*
  ID/EN daripada model multibahasa, karena justru itu yang dibuang saat
  fine-tuning. Rapat pemerintahan Indonesia penuh istilah Inggris.

Gunakan harness WER dari Sprint 4 untuk membandingkan pada rekaman Anda
sendiri:

```bash
cd rust_core
cargo run --release --bin wer_bench -- \
  --manifest ../bench/id_id.tsv \
  --model ~/.whisper-convert/ggml-whisper-medium-id-q5_0.bin \
  --model ~/Library/Caches/TrareonTranscribe/models/ggml-large-v3-turbo-q5_0.bin \
  --out ../docs/WER-BENCH.md
```

`scripts/fetch_wer_corpus.sh` membangun `bench/id_id.tsv` dari FLEURS
`id_id`. Tidak ada audio yang dikomit ke repositori ini.

## Status di mesin sprint ini

Konversi **belum dijalankan** pada mesin sprint. Alasannya dicatat apa
adanya: mesin ini 2 inti tanpa GPU dan hanya punya ±8 GB RAM efektif;
mengunduh bobot `medium` (±3 GB) lalu mengonversinya adalah pekerjaan
belasan menit yang akan bersaing dengan *build* dan pengujian dalam sprint
yang sama, dan hasilnya tidak bisa diverifikasi secara bermakna terhadap
satu klip 15 detik — satu-satunya audio Bahasa Indonesia yang tersedia
secara lokal (`rapat_id.mp3`). WER dari satu klip 15 detik bukan angka.

Yang sudah diverifikasi:

- Skrip lulus `bash -n`. (`shellcheck` tidak terpasang di mesin sprint ini,
  jadi tidak dijalankan — jangan anggap sudah lulus.)
- URL dan ukuran artefak di atas diperiksa langsung lewat HTTP (Oktober
  2026).
- `rust_core/src/stt/mod.rs::dtw_preset_for` sudah mengenali nama berkas
  `ggml-medium-id.bin` sebagai `DtwModelPreset::Medium`, sehingga *word
  timestamp* DTW tetap jalan untuk hasil konversi — ada tes untuk itu.

Yang perlu dilakukan oleh siapa pun yang melanjutkan: jalankan skrip di
mesin berkapasitas (mis. `win2060`, yang punya 16 GB RAM dan 220 GB ruang),
lalu jalankan `wer_bench` pada korpus FLEURS `id_id` yang utuh, bukan satu
klip.
