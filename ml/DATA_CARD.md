# Data Card — Indonesian Meeting ASR (Trareon Transcribe)

**Versi:** 0.1 · **Tanggal:** 5 Oktober 2026 · **Status:** pilot

Dokumen ini mencatat setiap sumber data yang dipakai atau direncanakan,
dasar hukumnya, batasan lisensinya, dan apa akibatnya terhadap lisensi
model yang dilatih darinya.

> **Bukan nasihat hukum.** Dokumen ini disusun dengan itikad baik atas
> dasar `docs/research/RESEARCH-DECISION-FINAL.md` (riset terverifikasi
> proyek ini). Butir yang bertanda **PERLU KAJIAN HUKUM** harus ditelaah
> penasihat hukum sebelum rilis publik.

---

## 1. Ringkasan sumber

| Sumber | Jenis ucapan | Lisensi / dasar hukum | Boleh latih? | Boleh komersial? | Status di sprint ini |
|---|---|---|---|---|---|
| FLEURS `id_id` | baca, 1 penutur | CC-BY 4.0 | ya | ya | **terunduh**, 60 klip |
| FLEURS `en_us` | baca, 1 penutur | CC-BY 4.0 | ya | ya | **terunduh**, 40 klip (bahan code-switch sintetis) |
| Common Voice `id` | baca, banyak penutur | CC0 1.0 | ya | ya | **TIDAK terunduh** — lihat §3.2 |
| GigaSpeech 2 `id` TEST/DEV | multi-domain, anotasi manusia | riset **non-komersial** | lihat §3.3 | **TIDAK** | **TIDAK terunduh** — butuh akses |
| GigaSpeech 2 `id` refined (train) | multi-domain, label otomatis | riset **non-komersial** | **PERLU KAJIAN HUKUM** | **TIDAK** | tidak dipakai |
| Mahkamah Konstitusi — risalah sidang | sidang, spontan-formal | teks: UU 28/2014 Ps. 42 | ya (teks) | ya (teks) | **TERBLOKIR** — lihat §4 |
| Mahkamah Konstitusi — rekaman kanal resmi | sidang | hak terkait lembaga penyiaran | **perlu izin** | **perlu izin** | audio dapat diakses, izin belum ada |
| DPR RI — risalah rapat | rapat parlemen | teks: UU 28/2014 Ps. 42 | ya (teks) | ya (teks) | **TERBLOKIR** — lihat §4 |
| DPR RI — rekaman TV Parlemen | rapat parlemen | hak terkait lembaga penyiaran | **perlu izin** | **perlu izin** | audio dapat diakses, izin belum ada |
| Pidato pejabat (setkab/presidenri) | pidato formal | UU 28/2014 Ps. 42 huruf c | ya | ya | belum dikumpulkan |
| Rekaman code-switching sendiri | rapat campur ID–EN | persetujuan UU PDP | ya | ya | **belum direkam** — `ml/record_kit/` |
| Code-switch sintetis (FLEURS id+en) | baca, digabung | CC-BY 4.0 | eval saja | ya | **dibangun**, 40 klip |
| Hening (buatan sendiri) | — | tanpa hak pihak ketiga | eval saja | ya | **dibangun**, 12 klip |
| ASR-IndoCSC (MagicHub) | percakapan spontan | CC-BY-NC-ND | **tidak** | **TIDAK** | tidak dipakai |
| BabelSpeech Indonesian Colloquial | kolokial | **belum jelas** | tidak sampai jelas | ? | tidak dipakai |

---

## 2. Dasar hukum teks risalah (Indonesia)

**UU No. 28 Tahun 2014 tentang Hak Cipta, Pasal 42** menyatakan tidak ada
hak cipta atas:

- hasil rapat terbuka lembaga negara (huruf a);
- peraturan perundang-undangan (huruf b);
- pidato kenegaraan atau pidato pejabat pemerintah (huruf c);
- putusan pengadilan atau penetapan hakim (huruf d).

Risalah sidang MK dan risalah rapat terbuka DPR termasuk huruf a dan/atau
huruf d. **Teksnya karena itu bebas dipakai**, termasuk sebagai label data
latih.

> Catatan koreksi: laporan `FUTURE-D-train-or-moat.md` menyebut "Pasal 43".
> Yang benar **Pasal 42**, sebagaimana dikoreksi di
> `docs/research/RESEARCH-DECISION-FINAL.md` §D.

### 2.1 Rekaman adalah persoalan terpisah

Bebasnya teks **tidak** membuat rekamannya bebas. Rekaman siaran TV
Parlemen dan kanal resmi MK kemungkinan memiliki **hak terkait lembaga
penyiaran** (*related rights*). Karena itu:

- Setiap rekaman yang dikumpulkan `ml/collect/youtube.py` ditandai
  `licence_note` sebagai **perlu izin**.
- Pilot memperlakukan audio pemerintah sebagai **evaluasi saja** sampai
  ada jawaban resmi dari DPR/MK.
- Rilis dataset berisi audio pemerintah **tidak boleh dilakukan** sebelum
  izin diperoleh. **PERLU KAJIAN HUKUM.**

Klaim "lisensi wajib 3 tahun Pasal 53" yang muncul di salah satu laporan
riset **belum terverifikasi** dan tidak dijadikan dasar apa pun di sini.

---

## 3. Dataset pihak ketiga

### 3.1 FLEURS (Google) — CC-BY 4.0
Dipakai untuk evaluasi dan sebagai bahan set code-switching sintetis.
Atribusi wajib: *Google FLEURS, CC-BY 4.0*. Boleh untuk pelatihan dan
penggunaan komersial.

### 3.2 Common Voice `id` (Mozilla) — CC0 1.0
Lisensinya paling longgar dari semua sumber di daftar ini (CC0 = tanpa
syarat). **Hambatannya teknis, bukan hukum:**

- Repositori `mozilla-foundation/common_voice_17_0` di Hugging Face tidak
  lagi menyajikan berkas data secara anonim (diukur 5 Okt 2026:
  `EmptyDatasetError — doesn't contain any data files`).
- Rilis Common Voice terbaru dibagikan lewat **Mozilla Data Collective**
  dan menuntut pendaftaran.
- Pemuat berbasis skrip juga tidak lagi didukung sejak `datasets` 3.x,
  yang mematikan jalur unduh lama.

Langkah yang harus dilakukan manusia tercantum di
`ml/collect/hf_sets.py` (`COMMON_VOICE_ID.access_steps`) dan ditampilkan
oleh `uv run python -m eval.fetch_sets --status`.

### 3.3 GigaSpeech 2 `id` — non-komersial ⚠️

Ini sumber paling berharga dan paling berbahaya dalam daftar ini.

**Berharga:** split TEST dan DEV masing-masing 10 jam, **dianotasi
manusia profesional**, multi-domain. Satu-satunya bahan uji Bahasa
Indonesia realistis yang ada. Split `refined` berisi 6.000 jam.

**Berbahaya:** aksesnya diberikan untuk **riset non-komersial**.

> **Akibatnya tegas: model apa pun yang dilatih dengan GigaSpeech 2
> harus dirilis dengan lisensi NON-KOMERSIAL (mis. CC-BY-NC-4.0) dan
> dengan pengungkapan yang jelas.**

Ini ditegakkan oleh kode, bukan oleh ingatan:
`ml/train/data.py::check_licences` memeriksa nama set latih, dan
`train_metrics.json` serta `MODEL_CARD.md` yang dihasilkan
`ml/train/merge_export.py` mencatat lisensi yang disarankan.

**Ketidaksesuaian yang harus diselesaikan:** kartu dataset di Hugging
Face mencantumkan `license: apache-2.0`, sementara riset terverifikasi
proyek ini mencatat ketentuan akses riset non-komersial dan menyatakan
pembuatnya memisahkan lisensi model dari lisensi dataset ("fair use") —
yang disebut **area abu-abu** untuk model terbuka. Sikap yang diambil di
sini adalah yang **konservatif** (perlakukan sebagai non-komersial).
**PERLU KAJIAN HUKUM** sebelum dipakai untuk pelatihan.

Sampai kajian itu ada: **evaluasi saja**.

---

## 4. Yang tidak bisa diambil, dan mengapa

Diukur 5 Oktober 2026 dari mesin pengembang (Kali Linux, IP rumahan):

| Sumber | Hasil | Rinci |
|---|---|---|
| `www.mkri.id` (indeks risalah) | **403 — tantangan anti-bot** | Cloudflare menyajikan halaman "Just a moment..." Semua jalur (`/`, `/index.php?page=web.RisalahSidang`, `/public/`) menolak. |
| `www.dpr.go.id` (indeks risalah) | **200, tetapi tanpa dokumen** | Halaman termuat (559 KB) tetapi daftar risalah dirender di sisi klien; tidak ada tautan PDF di HTML. |

**Keputusan yang diambil, dan alasannya:**

1. **Tantangan anti-bot tidak dilewati.** `common/fetch.py` mendeteksi
   halaman tantangan dan **berhenti** (`ChallengeDetected`). Menembus
   kontrol anti-bot bukan "kesopanan", dan dokumen ini memang disediakan
   untuk diminta lewat jalur resmi.

2. **`User-Agent` tanpa URL.** Diukur: WAF DPR menjawab **403 untuk
   setiap** `User-Agent` yang memuat URL, dan **200** untuk string yang
   sama tanpa URL. Konvensi menulis alamat kontak sebagai URL karena itu
   menghilangkan seluruh akses tanpa menambah identifikasi apa pun di
   atas nama repositori. `User-Agent` tetap menyebut proyek, tujuan, dan
   jalur kontak. Ini **bukan penyamaran**.

3. **`Disallow` yang salah tempat tidak dibaca sebagai izin.**
   `www.dpr.go.id/robots.txt` memuat blok

   ```
   User-agent: YandexBot
   Allow: /

   # Disallow admin and private areas
   Disallow: /admin/
   Disallow: /api/
   ```

   Karena baris `Disallow` berada **setelah** baris `User-agent`
   terakhir, menurut standar ia milik rekaman YandexBot, dan `Allow: /`
   sebelumnya menang untuk semua agen — `can_fetch` mengembalikan `True`
   untuk `/api/` bahkan bagi Googlebot. Komentar di atasnya menyatakan
   maksud sebenarnya dengan jelas. Membaca salah-tempat itu sebagai izin
   adalah akal-akalan, bukan persetujuan, sehingga
   `common/fetch.py::INTENT_DISALLOW` tetap melarang jalur tersebut —
   dengan akibat nyata bahwa daftar risalah DPR (yang dimuat front-end
   Next.js dari `/api/`) **tidak** dikumpulkan otomatis.

**Jalan ke depan:** ajukan permintaan data resmi melalui **PPID** masing-
masing lembaga (atau kerja sama lewat Komdigi), lalu muat hasilnya dengan
`ml/collect/gov_sources.py::load_index` — separuh pipeline
(unduh/cocokkan/manifest/align) sudah siap dan teruji.

---

## 5. Pelindungan data pribadi (UU PDP)

Dasar: UU No. 27 Tahun 2022 (UU PDP) dan PP No. 33 Tahun 2026.

### 5.1 Suara dan data biometrik

UU PDP menggolongkan data biometrik sebagai data pribadi **spesifik**.
Suara **dapat** tergolong biometrik **apabila dipakai untuk identifikasi
unik** seseorang — misalnya lewat *voice profile* atau *speaker
embedding*.

**Yang dilakukan proyek ini:**

| | |
|---|---|
| Nama penutur sebagai label teks di dataset | **ya** — hanya untuk label diarisasi, dan dapat dihapus |
| *Speaker embedding* / *voice profile* disimpan | **TIDAK** — tidak dihitung, tidak disimpan, di mana pun di pipeline ini |
| Dipakai untuk verifikasi/otentikasi identitas | **TIDAK** |
| Dipakai untuk pemantauan kinerja atau kepegawaian | **TIDAK** |

Nama penutur dalam risalah sidang/rapat **terbuka** adalah informasi yang
sudah dipublikasikan lembaga negara dalam dokumen resmi. Nama penutur
dalam rekaman sendiri hanya muncul sebagai label anonim
(`Penutur A/B/C`) bila peserta memilih demikian.

### 5.2 Cara menghapus nama penutur

Kolom `speaker` di `metadata.jsonl` setiap shard dapat dikosongkan tanpa
membangun ulang apa pun:

```bash
python3 - <<'PY'
import json, pathlib
p = pathlib.Path("data/shards/mk/metadata.jsonl")
rows = [json.loads(line) for line in p.read_text().splitlines() if line.strip()]
for row in rows:
    row["speaker"] = ""
tmp = p.with_suffix(".jsonl.tmp")
tmp.write_text("".join(json.dumps(r, ensure_ascii=False, sort_keys=True) + "\n" for r in rows))
tmp.replace(p)
PY
```

Audio dan label teks tidak tersentuh; hanya atribusi penutur hilang.

### 5.3 Prosedur penghapusan / takedown

Permintaan dikirim ke narahubung di `ml/record_kit/CONSENT.md`.

1. **Konfirmasi penerimaan: maksimal 3×24 jam.**
2. **Penyelesaian: maksimal 14 hari kerja.**
3. Tindakan:
   - potongan audio yang berasal dari pemohon dihapus dari shard;
   - baris terkait dihapus dari `metadata.jsonl`;
   - rilis dataset berikutnya tidak memuatnya;
   - penghapusan dicatat di `MODEL_CARD.md` model berikutnya.
4. **Yang tidak dapat dijanjikan:** model yang **sudah dirilis** tidak
   dapat dilatih ulang seketika untuk "melupakan" satu penutur. Data
   dikeluarkan dari pelatihan berikutnya. Hal ini disampaikan di muka di
   `CONSENT.md` §9 agar persetujuan benar-benar berdasar informasi.

Untuk materi pemerintah, permintaan takedown dari lembaga penerbit
dipenuhi dengan menghapus shard terkait, terlepas dari status Pasal 42,
karena sengketa yang dipersoalkan hampir selalu tentang **rekaman**
(§2.1), bukan tentang teks.

---

## 6. Kerangka DPIA (Data Protection Impact Assessment)

Kerangka, bukan DPIA yang sudah selesai. Diisi sebelum perekaman
code-switching berskala lebih dari satu sesi uji.

1. **Deskripsi pemrosesan** — apa yang direkam, berapa lama, oleh siapa,
   dengan perangkat apa, disimpan di mana.
2. **Tujuan dan dasar hukum** — pelatihan/pengujian model ASM offline;
   dasar: persetujuan (UU PDP Ps. 20 (2) a).
3. **Keperluan dan proporsionalitas** — mengapa data ini tidak bisa
   diganti data terbuka (jawaban terdokumentasi: tidak ada korpus rapat
   code-switching ID–EN berlisensi terbuka; lihat §1 dan riset §C).
4. **Pihak yang terdampak** — peserta sesi; pihak ketiga yang namanya
   mungkin terucap.
5. **Risiko**
   - identifikasi ulang penutur dari rekaman (Tingkat 3);
   - terucapnya data pribadi/sensitif pihak ketiga;
   - memorisasi potongan data latih oleh model;
   - kebocoran penyimpanan.
6. **Mitigasi**
   - persetujuan berlapis (Tingkat 1/2/3) di `CONSENT.md`;
   - pengingat "jangan sebut data sensitif" **di dalam rekaman**;
   - penanda `[potong]` yang dihormati **sebelum** pemotongan audio
     (ditegakkan dan diuji: `tests/test_record_kit.py`);
   - tanpa *speaker embedding* (§5.1);
   - label penutur anonim dan dapat dihapus (§5.2);
   - enkripsi saat diam; tanpa unggahan ke awan pihak ketiga;
   - batas waktu simpan yang ditetapkan.
7. **Sisa risiko dan keputusan** — dicatat dan ditandatangani pengendali
   data.
8. **Peninjauan** — ditinjau ulang setiap rilis dataset atau setiap 12
   bulan.

---

## 7. Keterbatasan dan bias yang diketahui

- **Belum ada data rapat sungguhan.** Pilot MK/DPR terblokir (§4), jadi
  pipeline penyelarasan divalidasi memakai *hearing* sintetis yang
  dibangun dari FLEURS (`ml/align/synthetic.py`). FLEURS adalah ucapan
  **dibaca**: tanpa tumpang tindih suara, tanpa mikrofon medan jauh,
  tanpa disfluensi spontan. Angka *keep rate* dari fixture itu adalah
  **batas atas**, bukan perkiraan, dari angka yang sebenarnya.
- **Code-switching masih sintetis.** Set uji yang ada menggabungkan dua
  ujaran baca; code-switching **alami** intra-kalimat jauh lebih sulit
  (riset: CER >80%). Set sintetis tidak boleh dikutip sebagai ukuran
  kemampuan code-switching.
- **Bias dialek.** FLEURS dan Common Voice condong ke Bahasa Indonesia
  baku. Sidang MK dan rapat DPR condong ke ragam formal Jakarta. Ragam
  kolokial dan aksen daerah **tidak terwakili**.
- **Bias penutur.** Risalah pemerintah didominasi pejabat — cenderung
  lebih tua, lebih laki-laki, dan lebih formal daripada rapat kantor
  biasa.
- **Label mendekati verbatim, bukan verbatim.** Risalah dirapikan oleh
  juru catat. Gerbang `anchor_rate` membuang bagian yang paling
  menyimpang, tetapi perapian kecil tetap ada di label.

---

## 8. Berkas yang menegakkan dokumen ini

| Berkas | Yang ditegakkan |
|---|---|
| `ml/common/fetch.py` | tantangan anti-bot dihormati; `INTENT_DISALLOW` |
| `ml/collect/access.py` | diagnosis akses yang dapat ditindaklanjuti |
| `ml/collect/hf_sets.py` | catatan lisensi + langkah akses per set |
| `ml/collect/gov_index.py` | penolakan penjodohan sesi yang tidak yakin |
| `ml/train/data.py` | `check_licences` → lisensi model yang disarankan |
| `ml/align/shards.py` | tanpa *embedding*; label penutur berupa teks |
| `ml/record_kit/ingest.py` | `[potong]` dihormati sebelum pemotongan |
| `ml/tests/test_fetch.py` | uji untuk kesopanan pengambilan data |
| `ml/tests/test_record_kit.py` | uji untuk kewajiban persetujuan |
