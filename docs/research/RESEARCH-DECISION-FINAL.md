# RISET LENGKAP → DOKUMEN KEPUTUSAN (Trareon Transcribe 2027)
4 Okt 2026 · Hermes. Semua angka di dokumen ini SUDAH diverifikasi ke sumber (URL). Laporan subagent mentah ada di folder yang sama; bila bertentangan, dokumen INI yang benar.

## A. Daftar laporan
| File | Isi | Catatan kualitas |
|---|---|---|
| COMPETITOR-RESEARCH.md (repo docs/) | 17 kompetitor, fitur & UX (ronde 1) | baik |
| RESEARCH-ROUND2.md | dikte/meeting app baru + teknik engine | ada blok KOREKSI (Parakeet/Moonshine tidak dukung ID) |
| FUTURE-A-meeting-assistants.md | arah pasar asisten rapat | tren terverifikasi sebagian |
| FUTURE-B-dictation-oss-indonesia.md | dikte, OSS, pemain Indonesia | klaim kunci terverifikasi |
| FUTURE-C-platforms-asr-llm.md | Apple/Google/MS, model ASR, LLM | terverifikasi (Apple 10 bahasa, Meet 8 bahasa) |
| FUTURE-D-train-or-moat.md | training vs moat | pasal hak cipta salah sebut (42, bukan 43); belum tahu Rafiqspace |
| DATA-SOURCES-ID-EN.md | katalog data | **jam Common Voice salah; GigaSpeech 2 terlewat** — pakai tabel C di bawah |
| OPEN-QUESTIONS-LLM-SRIKANDI-LEGAL.md | LLM notulen, SRIKANDI, hukum, WER | **angka WER rapat salah** — pakai tabel B di bawah |
| FUTURE-VERIFICATION.md, STRATEGY-2027.md | verifikasi & draf strategi | draf strategi diperbarui di §E |

## B. Fakta akurasi (terverifikasi)
- Whisper di FLEURS-id (audio dibaca, bersih; paper Whisper, Tabel 13): tiny 51,7 · base 33,1 · small 16,3 · medium 10,2 · large 8,5 · large-v2 7,1 % WER. https://www.matthewswong.com/en/blog/speech-to-text-bahasa-indonesia-production/
- **Ucapan spontan jauh lebih buruk**: studi Okt 2024, korpus campuran 80,54 jam (sidang parlemen, berita, podcast, talk show, CV, FLEURS): whisper-small **30,87% WER**; dibaca/formal 27,22% vs **spontan/informal 40,66%** (sumber sama).
- **Code-switching ID–EN = masalah terbuka**: Whisper memilih SATU token bahasa per jendela 30 detik; studi 2024: CER Indonesia monolingual 4,10%, code-switch sintetis 37,57%, code-switch natural >80% (sumber sama).
- Rafiqspace (fine-tune Parakeet, data parlemen dll.): WER 2,3% di test set mereka; rapat pemerintah 95,57% akurasi vs Gemini Pro 91,78%. https://www.nvidia.com/en-gb/case-studies/transcription-accuracy-with-nemotron
→ **Kesimpulan:** celah akurasi rapat Bahasa Indonesia & code-switching itu NYATA dan BESAR; fine-tune terbukti menutupnya.

## C. Data terbuka ber-transkrip (terverifikasi)
| Sumber | Ukuran | Jenis | Lisensi / status | Untuk |
|---|---|---|---|---|
| Common Voice 27.0 (id) | 67,53 jam rekaman, **34,25 jam tervalidasi**, 678 penutur | dibaca | CC0 | train + eval | 
| FLEURS id_id | kecil (~10-an jam) | dibaca | CC-BY 4.0 | eval |
| **GigaSpeech 2 (id)** | **6.000 jam "refined"** (YouTube, label otomatis) + **DEV 10 jam & TEST 10 jam dianotasi manusia profesional** | multi-domain, realistis | akses **riset non-komersial**; mereka menyatakan lisensi model terpisah dari dataset ("fair use") → **area abu-abu untuk model yang dirilis terbuka** | eval (TEST 10 jam sangat berharga); training = perlu kajian hukum |
| Mahkamah Konstitusi — risalah sidang + siaran ulang video | ratusan sidang/tahun (risalah PDF verbatim dapat diunduh; video siaran ulang tersedia) | sidang, spontan-formal | teks: tanpa hak cipta (UU 28/2014 Ps. 42 huruf a/d); **rekaman siaran: hak terkait lembaga penyiaran — perlu izin** | train/eval setelah alignment |
| DPR RI — risalah rapat + video TV Parlemen | sangat banyak | rapat parlemen | sama seperti MK; akses risalah historisnya dikritik kurang terbuka (IPC) | train/eval |
| Pidato pejabat (setkab/presidenri) | puluhan jam | pidato formal | Ps. 42 huruf c | train |
| ASR-IndoCSC (MagicHub/SEACrowd) | 4,54 jam, 7 percakapan | percakapan spontan | CC-BY-NC-ND (riset) | eval saja |
| BabelSpeech Indonesian Colloquial | ±40–50 jam (kartu dataset tidak konsisten) | kolokial | gated, lisensi **belum jelas** | tanyakan pemilik |
| OpenSLR Jawa (SLR35) / Sunda (SLR36) | ratusan jam | dibaca, bahasa daerah | CC-BY-SA 4.0 | bahasa daerah (nanti) |
| NVIDIA Granary | — | — | **25 bahasa Eropa, tanpa Indonesia** | tidak relevan |
- Celah data: **rapat code-switching ID–EN berlisensi terbuka praktis tidak ada** → harus direkam sendiri (relawan/rapat internal ber-consent) atau sintetis.

## D. LLM notulen, SRIKANDI, hukum
- LLM: dua riset memberi rekomendasi berbeda (Sahabat-AI Gemma2 9B vs Qwen3-8B). **Belum bisa diputuskan dari literatur** → uji sendiri pada 20–30 pasangan transkrip→notulen (Sprint 7). Kandidat: Qwen3-8B (Apache-2.0, konteks panjang), Sahabat-AI 9B (khusus ID, lisensi Gemma), Gemma 3 12B.
- SRIKANDI (Aplikasi Umum Kearsipan, KepmenPANRB 679/2020): **tidak ditemukan API publik**. Yang realistis sekarang: ekspor DOCX/PDF sesuai Tata Naskah Dinas untuk diunggah manual; integrasi resmi butuh jalur SPBE/ANRI (kerja sama formal). Rincian "17 field metadata" dari subagent BELUM terverifikasi.
- Hukum: UU 28/2014 **Ps. 42**: tidak ada hak cipta atas hasil rapat terbuka lembaga negara, peraturan, pidato pejabat, putusan pengadilan (terverifikasi). Rekaman siaran (TV Parlemen, kanal MK) kemungkinan memiliki **hak terkait lembaga penyiaran** → minta izin/ kerja sama, atau rekam ulang dari sumber resmi dengan izin. Klaim "lisensi wajib 3 tahun Ps. 53" BELUM terverifikasi.
- UU PDP: data biometrik = karakteristik fisik/fisiologis/perilaku yang memungkinkan identifikasi unik (contoh di penjelasan: wajah, sidik jari). Suara **bisa** tergolong biometrik bila dipakai untuk identifikasi (mis. voice profile/diarization embedding). → Untuk training ASR: gunakan sesi terbuka, jangan simpan embedding identitas, model card, mekanisme takedown, **DPIA** dianjurkan. PP 33/2026 (pelaksana UU PDP) sudah terbit; Badan PDP belum dibentuk.

## E. Strategi yang direkomendasikan (final)
1. **Fondasi (sedang jalan):** Sprint 4 (transkrip lengkap, anti-halusinasi) → 4b (LocalAgreement, VAD, timestamp kata, diarization) → 5 (desain + beta macOS/Windows).
2. **Sprint 6 — Benchmark & Model Rapat Indonesia (moat #1):**
   - Benchmark: GigaSpeech2-id TEST (10 j, manusia) + FLEURS + CV + **set rapat sendiri** (MK/DPR ter-align, dengan izin rekaman) + **set code-switching** yang direkam sendiri (relawan, consent).
   - Baseline semua model (tiny→turbo, cahya) di laptop Master.
   - Fine-tune LoRA turbo (GPU cloud) pada data legal: CV + pidato + risalah ter-align (+ GigaSpeech2 hanya bila kajian hukum mengizinkan).
   - Target: model rapat ID+code-switch terbuka pertama yang jalan offline di laptop.
3. **Sprint 7 — Mesin Notulen (moat #2):** uji LLM lokal, template Tata Naskah Dinas, ekspor siap-SRIKANDI (manual upload), lalu fine-tune bila perlu.
4. **Compliance pack (moat #3):** pemetaan PP 33/2026 / UU PDP / ISO 27001/27701 / BSSN + DPIA template — keahlian Master.
5. Ditunda/diturunkan: server on-prem (Rafiqspace sudah di sana), cloud BYO-key (opsional), bahasa daerah (setelah ID-EN matang).

## F. Keputusan yang diminta dari Master
1. Setuju arah §E (tambah Sprint 6 & 7)?
2. Anggaran GPU cloud eksperimen: ±$50–150 (fase 1).
3. Data: (a) rekam sesi code-switching dengan relawan/rapat internal ber-consent? (b) ajukan izin/kerja sama data rekaman ke DPR/MK (mungkin via jalur Komdigi)? (c) GigaSpeech 2: pakai untuk eval saja, atau minta kajian hukum untuk training?
4. LLM notulen: setuju diputuskan lewat uji banding sendiri di Sprint 7?
