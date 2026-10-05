# Benchmark: Indonesian Meeting ASR v0

- Dibuat: 2026-10-05T10:54:17+00:00
- Mesin: Linux x86_64, Intel(R) Core(TM) i3-7100T CPU @ 3.40GHz, 4 thread
- Commit: `77a46fb`
- Normalisasi: `id_meeting/id-norm-1` (lihat `ml/eval/normalize.py`)

RTF = detik audio per detik jam dinding. Di bawah 1,0 berarti model tidak bisa mengikuti rapat langsung di mesin ini.

**RTF juga bergantung pada apa lagi yang berjalan saat pengukuran.** Angka di bawah diambil di mesin yang sedang dipakai mengerjakan hal lain, jadi perlakukan RTF sebagai urutan besaran (apakah model ini bisa real-time di kelas mesin ini?) dan bukan sebagai tolok ukur yang presisi. WER dan CER tidak terpengaruh beban.

## Ucapan baca (read speech)

FLEURS dan Common Voice adalah ucapan **dibaca**, satu penutur, mikrofon dekat. Model yang bagus di sini BELUM terbukti bisa menangani rapat empat orang lewat mikrofon laptop.

### fleurs-id

- Jenis: ucapan baca, satu penutur, mikrofon dekat
- Klip terukur: 10  ⚠️ uji asap, bukan WER definitif
- Lisensi: CC-BY 4.0

| Model | WER | CER | RTF | Subst | Hapus | Sisip | Gagal |
|---|---:|---:|---:|---:|---:|---:|---:|
| turbo-q5 | 6.9% | 2.6% | 0.10× | 7 | 1 | 3 | 0 |
| small | 17.0% | 4.8% | 0.38× | 21 | 3 | 3 | 0 |
| base | 34.0% | 12.6% | 1.17× | 48 | 2 | 4 | 0 |
| tiny | 50.3% | 17.5% | 1.62× | 65 | 6 | 9 | 0 |

## Ucapan rapat / spontan

Inilah beban kerja sebenarnya aplikasi ini. Angka di sini dan di blok atas **tidak boleh dirata-ratakan**.

### codeswitch-synth-id-en

- Jenis: peralihan bahasa ID<->EN dalam satu jendela dekode (SINTETIS)
- Klip terukur: 8  ⚠️ uji asap, bukan WER definitif
- Lisensi: CC-BY 4.0 (FLEURS id_id + en_us digabung)
- Catatan: SINTETIS: dua ujaran baca digabung, bukan code-switching alami intra-kalimat. Mengukur kegagalan terdokumentasi Whisper memilih SATU token bahasa per jendela 30 detik. Code-switching alami diperkirakan JAUH lebih buruk - lihat ml/eval/build_sets.py.

| Model | WER | CER | RTF | Subst | Hapus | Sisip | Gagal |
|---|---:|---:|---:|---:|---:|---:|---:|
| turbo-q5 | 30.8% | 25.0% | 0.13× | 7 | 96 | 2 | 0 |
| small | 45.2% | 34.6% | 0.57× | 42 | 102 | 10 | 0 |
| base | 58.1% | 39.0% | 1.47× | 75 | 114 | 9 | 0 |
| tiny | 65.7% | 43.2% | 0.56× | 91 | 127 | 6 | 0 |

### silence

- Jenis: hening - menguji halusinasi, acuan kosong
- Klip terukur: 4  ⚠️ uji asap, bukan WER definitif
- Lisensi: Dibuat sendiri (ml/eval/build_sets.py)
- Catatan: Acuan kosong: setiap kata yang keluar adalah sisipan. WER 0% = tidak berhalusinasi.

| Model | WER | CER | RTF | Subst | Hapus | Sisip | Gagal |
|---|---:|---:|---:|---:|---:|---:|---:|
| tiny | 0.0% | 0.0% | 45.28× | 0 | 0 | 0 | 0 |
| base | 0.0% | 0.0% | 137.93× | 0 | 0 | 0 | 0 |
| small | 0.0% | 0.0% | 235.29× | 0 | 0 | 0 | 0 |
| turbo-q5 | 0.0% | 0.0% | 230.77× | 0 | 0 | 0 | 0 |

## Cara membaca tabel ini

1. WER Bahasa Indonesia kejam karena afiksasi: `mempertanggungjawabkan` yang salah satu suku kata tetap satu kata salah utuh. CER menunjukkan seberapa dekat kesalahannya.
2. Angka dari korpus < 25 klip adalah uji asap. Jangan dikutip sebagai WER model.
3. RTF hanya berarti bersama nama mesin di atas.
4. Kolom Subst/Hapus/Sisip membedakan model yang salah dengar dari model yang menghilangkan atau mengarang kata - dua kegagalan yang sangat berbeda bagi pengguna.
