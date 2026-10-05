# Benchmark: Indonesian Meeting ASR v0

- Dibuat: 2026-10-05T10:48:51+00:00
- Mesin: Linux x86_64, Intel(R) Core(TM) i3-7100T CPU @ 3.40GHz, 4 thread
- Commit: `77a46fb`
- Normalisasi: `id_meeting/id-norm-1` (lihat `ml/eval/normalize.py`)

RTF = detik audio per detik jam dinding. Di bawah 1,0 berarti model tidak bisa mengikuti rapat langsung di mesin ini.

## Ucapan baca (read speech)

FLEURS dan Common Voice adalah ucapan **dibaca**, satu penutur, mikrofon dekat. Model yang bagus di sini BELUM terbukti bisa menangani rapat empat orang lewat mikrofon laptop.

### fleurs-id

- Jenis: ucapan baca, satu penutur, mikrofon dekat
- Klip terukur: 0  ⚠️ uji asap, bukan WER definitif
- Lisensi: CC-BY 4.0

| Model | WER | CER | RTF | Subst | Hapus | Sisip | Gagal |
|---|---:|---:|---:|---:|---:|---:|---:|
| tiny | 0.0% | 0.0% | 0.00× | 0 | 0 | 0 | 0 |
| base | 0.0% | 0.0% | 0.00× | 0 | 0 | 0 | 0 |
| small | 0.0% | 0.0% | 0.00× | 0 | 0 | 0 | 0 |
| turbo-q5 | 0.0% | 0.0% | 0.00× | 0 | 0 | 0 | 0 |

## Ucapan rapat / spontan

Inilah beban kerja sebenarnya aplikasi ini. Angka di sini dan di blok atas **tidak boleh dirata-ratakan**.

### codeswitch-synth-id-en

- Jenis: peralihan bahasa ID<->EN dalam satu jendela dekode (SINTETIS)
- Klip terukur: 0  ⚠️ uji asap, bukan WER definitif
- Lisensi: CC-BY 4.0 (FLEURS id_id + en_us digabung)
- Catatan: SINTETIS: dua ujaran baca digabung, bukan code-switching alami intra-kalimat. Mengukur kegagalan terdokumentasi Whisper memilih SATU token bahasa per jendela 30 detik. Code-switching alami diperkirakan JAUH lebih buruk - lihat ml/eval/build_sets.py.

| Model | WER | CER | RTF | Subst | Hapus | Sisip | Gagal |
|---|---:|---:|---:|---:|---:|---:|---:|
| tiny | 0.0% | 0.0% | 0.00× | 0 | 0 | 0 | 0 |
| base | 0.0% | 0.0% | 0.00× | 0 | 0 | 0 | 0 |
| small | 0.0% | 0.0% | 0.00× | 0 | 0 | 0 | 0 |
| turbo-q5 | 0.0% | 0.0% | 0.00× | 0 | 0 | 0 | 0 |

### silence

- Jenis: hening - menguji halusinasi, acuan kosong
- Klip terukur: 0  ⚠️ uji asap, bukan WER definitif
- Lisensi: Dibuat sendiri (ml/eval/build_sets.py)
- Catatan: Acuan kosong: setiap kata yang keluar adalah sisipan. WER 0% = tidak berhalusinasi.

| Model | WER | CER | RTF | Subst | Hapus | Sisip | Gagal |
|---|---:|---:|---:|---:|---:|---:|---:|
| tiny | 0.0% | 0.0% | 0.00× | 0 | 0 | 0 | 0 |
| base | 0.0% | 0.0% | 0.00× | 0 | 0 | 0 | 0 |
| small | 0.0% | 0.0% | 0.00× | 0 | 0 | 0 | 0 |
| turbo-q5 | 0.0% | 0.0% | 0.00× | 0 | 0 | 0 | 0 |

## Cara membaca tabel ini

1. WER Bahasa Indonesia kejam karena afiksasi: `mempertanggungjawabkan` yang salah satu suku kata tetap satu kata salah utuh. CER menunjukkan seberapa dekat kesalahannya.
2. Angka dari korpus < 25 klip adalah uji asap. Jangan dikutip sebagai WER model.
3. RTF hanya berarti bersama nama mesin di atas.
4. Kolom Subst/Hapus/Sisip membedakan model yang salah dengar dari model yang menghilangkan atau mengarang kata - dua kegagalan yang sangat berbeda bagi pengguna.
