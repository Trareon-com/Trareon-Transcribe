# Model Card — *(nama model)*

**Versi:** *(isi)* · **Tanggal rilis:** *(isi)* · **Lisensi:** *(isi — lihat §6)*

`ml/train/merge_export.py` mengisi bagian ringkasan di atas kartu ini
secara otomatis. Bagian bertanda **TODO** harus dilengkapi manusia
sebelum model dirilis.

---

## 1. Ringkasan

| | |
|---|---|
| Arsitektur | Whisper *(base / small / large-v3-turbo)* + LoRA yang digabungkan |
| Model basis | *(isi, mis. `openai/whisper-small`)* |
| Bahasa | Bahasa Indonesia *(sebutkan bila code-switching ID–EN dilatih)* |
| Tugas | `transcribe` |
| Format | `transformers` (fp16) dan GGML *(f16 / q5_0 / q8_0)* |
| Dibuat untuk | Transkripsi rapat **offline** di laptop pengguna |

## 2. Penggunaan yang dimaksudkan

**Dimaksudkan untuk:** transkripsi rapat Bahasa Indonesia pada perangkat
pengguna, tanpa mengirim audio ke mana pun.

**TIDAK dimaksudkan untuk** *(dan tidak diuji untuk)*:

- identifikasi atau verifikasi penutur (**jangan** dipakai sebagai
  biometrik — lihat `ml/DATA_CARD.md` §5.1);
- pengambilan keputusan otomatis yang berdampak hukum pada seseorang;
- transkripsi bahasa daerah (Jawa, Sunda, dll.) — tidak dilatih untuk itu;
- rekaman medis, hukum, atau penegakan hukum yang menuntut akurasi
  terverifikasi tanpa pemeriksaan manusia.

**Transkrip model ini bukan dokumen resmi.** Risalah resmi tetap harus
diperiksa dan disahkan manusia.

## 3. Data latih

| Sumber | Jam | Jenis ucapan | Lisensi | Catatan |
|---|---:|---|---|---|
| *(isi)* | *(isi)* | *(isi)* | *(isi)* | *(isi)* |

- **Total jam latih:** *(isi)*
- **Jam yang dibuang penyelarasan dan sebabnya:** *(isi — dari
  `report-*.json` pipeline penyelarasan)*
- **Gerbang `anchor_rate` yang dipakai:** *(isi)*
- **Dataset ter-align dirilis?** *(ya/tidak — bila ya, tautkan)*

Rincian dasar hukum dan batasan setiap sumber: **`ml/DATA_CARD.md`**.

## 4. Prosedur pelatihan

| | |
|---|---|
| Metode | LoRA (PEFT) |
| `r` / `alpha` / `dropout` | *(isi)* |
| Modul target | *(isi)* |
| Lapisan encoder yang dilatih | *(isi)* |
| Kuantisasi basis saat latih | *(fp16 / 8-bit / 4-bit NF4)* |
| Batch efektif | *(isi)* |
| Langkah | *(isi)* |
| Learning rate / scheduler | *(isi)* |
| SpecAugment | *(isi)* |
| Perangkat | *(isi, mis. 1× RTX 2060 6 GB)* |
| Durasi latih | *(isi)* |
| Config lengkap | `config.resolved.yaml` di direktori keluaran |

## 5. Evaluasi

Diukur dengan `ml/eval/run_benchmark.py`. **Sebutkan kebijakan
normalisasi dan versinya** — angka WER tanpa keduanya tidak dapat
direproduksi.

- Kebijakan normalisasi: *(mis. `id_meeting/id-norm-1`)*
- Mesin pengukur: *(isi — RTF tidak berarti tanpa ini)*
- Commit: *(isi)*

### 5.1 Ucapan baca

| Set uji | Klip | WER | CER | RTF | Basis sebelum fine-tune |
|---|---:|---:|---:|---:|---:|
| fleurs-id | | | | | |
| cv-id | | | | | |

### 5.2 Ucapan rapat / spontan

**Jangan merata-ratakan blok ini dengan blok 5.1** — hasilnya tidak
menggambarkan keduanya.

| Set uji | Klip | WER | CER | RTF | Basis sebelum fine-tune |
|---|---:|---:|---:|---:|---:|
| gs2-id-test | | | | | |
| mk-holdout | | | | | |
| dpr-holdout | | | | | |
| codeswitch-synth-id-en | | | | | |
| codeswitch-id-en (alami) | | | | | |
| silence (halusinasi) | | *(sisipan, bukan WER)* | | | |

### 5.3 Yang angka-angka itu TIDAK katakan

- Set `codeswitch-synth-id-en` adalah **sintetis**: dua ujaran baca
  digabung. Code-switching **alami** intra-kalimat jauh lebih sulit
  (riset terverifikasi: CER di atas 80%). **Jangan** mengutip angka
  sintetis sebagai kemampuan code-switching.
- Set ucapan baca (FLEURS, Common Voice) direkam satu penutur dengan
  mikrofon dekat. Nilai bagus di sana **belum** membuktikan apa pun
  tentang rapat empat orang lewat mikrofon laptop dengan AC menyala.
- Korpus di bawah 25 klip adalah uji asap, bukan WER model.

## 6. Lisensi dan pembatasan

- **Lisensi model:** *(isi)*
- **Boleh dipakai komersial:** *(ya/tidak)*

> ⚠️ **Bila GigaSpeech 2 ikut dilatih, model ini WAJIB dirilis
> non-komersial (mis. CC-BY-NC-4.0) dengan pengungkapan yang jelas.**
> `ml/train/data.py::check_licences` memeriksa hal ini dan hasilnya
> tercatat di `train_metrics.json`.

- **Bila rekaman DPR/MK ikut dilatih:** sebutkan status izin lembaga
  penyiaran. Tanpa izin, model **tidak boleh** dirilis publik. Lihat
  `ml/DATA_CARD.md` §2.1.
- Atribusi yang wajib diteruskan: *(mis. FLEURS — CC-BY 4.0)*

## 7. Keterbatasan dan bias

- *(isi; mulai dari `ml/DATA_CARD.md` §7 dan tambahkan yang khusus model ini)*
- Dialek/aksen yang kurang terwakili: *(isi)*
- Jenis derau yang belum diuji: *(isi)*
- Kecenderungan berhalusinasi pada keheningan: *(isi hasil set `silence`)*

## 8. Pertimbangan etis dan pelindungan data

- Model ini **tidak** menghasilkan atau menyimpan *speaker embedding*.
- Pelatihan memakai sesi **terbuka** dan/atau rekaman ber-consent.
- Prosedur takedown dan penghapusan: `ml/DATA_CARD.md` §5.3.
- Penutur yang menarik persetujuan setelah rilis: data dikeluarkan dari
  pelatihan **berikutnya**; model yang sudah dirilis tidak dapat
  "melupakan" seketika. Hal ini disampaikan di muka di
  `ml/record_kit/CONSENT.md` §9.
- Penghapusan yang telah dilakukan sejak versi sebelumnya: *(isi)*

## 9. Cara memakai

### whisper.cpp / Trareon Transcribe

```bash
# Salin ke folder model
#   macOS/Linux : ~/Library/Caches/TrareonTranscribe/models/
#   Windows     : %LOCALAPPDATA%\TrareonTranscribe\models\
# Lalu di Pengaturan → Model, pilih "Model lain di komputer ini".
```

### transformers

```python
from transformers import pipeline

asr = pipeline("automatic-speech-recognition", model="(isi)")
print(asr("rapat.wav", generate_kwargs={"language": "id", "task": "transcribe"})["text"])
```

## 10. Reproduksi

```bash
cd ml
uv sync --extra train --extra gpu --extra data
./train/train.sh (nama-config)
```

- Config: `ml/train/configs/(isi).yaml`
- Commit: *(isi)*
- SHA256 berkas GGML: *(isi — dicetak oleh skrip konversi)*

## 11. Kontak

*(isi: narahubung, dan ke mana permintaan penghapusan dikirim)*
