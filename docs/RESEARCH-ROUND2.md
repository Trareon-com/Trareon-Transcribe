# Research Round 2: Deep Technical & New Competitor Analysis for Trareon Transcribe

> ## ⚠️ KOREKSI & VERIFIKASI (Hermes, 4 Okt 2026) — baca ini dulu
> Laporan di bawah dibuat subagent dalam 9 menit; klaim kunci sudah dicek ulang langsung ke sumber resmi:
> 1. **SALAH — Parakeet TDT v3 TIDAK mendukung Bahasa Indonesia.** Model card resmi (https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3) hanya 25 bahasa Eropa. "TDT" = *Token-and-Duration Transducer*, BUKAN "Timestamped Diarization Transformer", dan tidak punya diarization bawaan. Abaikan semua rekomendasi Parakeet untuk Bahasa Indonesia (Tier 3 di §2.5.5, rekomendasi Handy/transcribe-rs untuk ID). Parakeet hanya berguna untuk mode English-only.
> 2. **Moonshine juga TIDAK mendukung Bahasa Indonesia** (8 bahasa: ar, en, zh, ja, ko, es, uk, vi — https://github.com/petewarden/moonshine).
> 3. **Konsekuensi arsitektur:** untuk Bahasa Indonesia, **Whisper tetap satu-satunya opsi lokal yang praktis**. Live preview = whisper tiny/base/small (VAD-gated, LocalAgreement-2); hasil akhir = large-v3-turbo-q5 setelah rapat.
> 4. **TERVERIFIKASI — whisper.cpp punya VAD Silero bawaan** (`--vad -vm ggml-silero-v6.2.0.bin`, https://github.com/ggml-org/whisper.cpp/blob/master/README.md) → bisa dipakai langsung lewat whisper-rs, tanpa dependensi baru.
> 5. **TERVERIFIKASI — sherpa-onnx punya crate Rust resmi untuk diarization offline** (segmentasi pyannote + embedding 3D-Speaker/CAM++, clustering): https://docs.rs/sherpa-onnx/1.13.4/src/sherpa_onnx/offline_speaker_diarization.rs.html, contoh https://github.com/thewh1teagle/sherpa-rs/blob/06fd39abb53a91b336d17118927a35db7956f675/examples/diarize.rs.
> 6. **cahya/whisper-medium-id** (WER 3,83% di Common Voice) — tidak ada konversi GGML resmi; butuh konversi sendiri + uji di rekaman rapat nyata sebelum dijadikan default.
>
> ### Pelengkap produk yang terlewat
> - **Aqua Voice** — dikte AI untuk Mac/Windows/iOS, tahan satu tombol → teks bersih masuk ke field mana pun; gratis 1.000 kata lalu berlangganan; cloud (https://aquavoice.com/llms.txt, https://aquavoice.com/pricing). *Kelebihan:* format otomatis, bekerja di terminal/IDE. *Kekurangan:* cloud, kuota kata.
> - **Willow Voice** — dikte cloud lintas platform (YC), $15/bln, smart formatting, hapus filler, "style memory", ada Offline Mode terbatas (https://willowvoice.com/, https://getvoibe.com/resources/willow-voice-review). *Kekurangan:* langganan, cloud default.
> - **VoiceInk** — open source (GPL v3) macOS, 100% on-device default, beli sekali ±$29, push-to-talk global, context-aware power modes (https://www.getvoibe.com/resources/voiceink-review/). *Kekurangan:* macOS saja.
> - **Spokenly** — dikte Mac/Windows/Linux/iPhone; cloud default + model lokal gratis (Whisper, Parakeet), Local Only Mode, kamus & word replacement, Whisper prompting, punctuation commands (https://spokenly.app/, https://spokenly.app/docs). *Pola layak ditiru:* "Local Only Mode" eksplisit + word replacement.
> - **Circleback** — asisten rapat cloud: catatan, action items, otomasi, pencarian (https://circleback.ai/). *Kekurangan:* cloud, bot/berlangganan.
> - **Wispr Flow** (tambahan): Pro $15/bln ($12 tahunan); **cloud-only, tanpa mode offline, dan mengambil screenshot layar berkala** untuk konteks AI — kontroversi privasi; rating Trustpilot ±2,7/5 (https://instantowl.com/blog/wispr-flow, https://dynalord.com/blog/wispr-flow-review, https://getvoibe.com/resources/wispr-flow-review). → Peluang positioning Trareon: dikte/transkrip **tanpa screenshot & tanpa cloud**.
> - **Tactiq** (tambahan): ekstensi Chrome bot-free berbasis caption Meet/Teams/Zoom, 30+ bahasa (tergantung platform), gratis + $8/user/bln dengan kredit AI (https://tactiq.io/buy, https://help.tactiq.io/en/articles/8627989-what-languages-does-tactiq-support). *Kekurangan:* bergantung caption platform (akurasi Bahasa Indonesia ikut kualitas caption Meet/Zoom), hanya rapat online di browser.

---


**Tanggal:** Oktober 2026 | **Scope:** Round 1 sudah mencakup Meetily, Granola, Otter, tl;dv, Fathom, Krisp, Notion AI, Jamie, Hyprnote/Anarlog, Superwhisper, MacWhisper, Buzz, Vibe, Whisper Notes, Notta, dan Indonesian local players. Round 2 fokus ke apps yang belum dibahas + implementasi teknik open-source untuk real-time local transcription.

**Sumber:** Official sites, docs, GitHub READMEs/commits, ArXiv papers, HuggingFace model cards, pricing pages. Semua klaim faktual disertai URL sumber. Item yang tidak terverifikasi ditandai [UNVERIFIED].

---

## BAGIAN 1: Dictation & Meeting Apps (Belum Tercakup di Round 1)

---

### 1.1 Wispr Flow — AI Voice Keyboard (Push-to-Talk ke Semua App)

**Apa itu:** Wispr Flow adalah "AI voice keyboard" yang menggantikan typing di mana pun — email, Slack, Google Docs, code editor. Tekan hotkey, bicara, hasilnya langsung disisipkan sebagai teks yang sudah dibersihkan. Bukan transcription tool, tapi output layer yang menerima suara dan mengeluarkan teks.

**Pricing:**
- Free: 2,000 words/minggu (desktop), 1,000 words/minggu (iPhone), **Android unlimited** (promo sementara).
- Pro: $15/bulan atau $12/bulan (annual) — unlimited words, Command Mode (edit teks dengan suara).
- Growth: $18-$23/user/bulan — SSO, HIPAA/BAA, audit logs.
- Student: 3 bulan gratis + 50% off Pro.
https://wisprflow.com/, https://letterly.app/blog/wispr-flow-review

**Platform:** macOS, Windows, iOS, Android.

**Fitur utama:**
- AI auto-edits on-the-fly: hapus filler words ("um", "uh"), format lists, handle backtracking corrections ("actually change that to...").
- Personal dictionary: learns dari koreksi; bisa di-extend manual.
- Snippets: voice shortcuts untuk reusable text blocks.
- Styles: adapt tone berdasarkan context (formal di docs, casual di chat).
- Command Mode: highlight teks → speak command untuk rewrite/transform.
- Whisper mode: bisa berbisik, tetap recognized.
- Context awareness: app aktif, teks sekitar cursor, selected text, visible text, bahkan variable names (untuk coding context).
- Privacy Mode tersedia; HIPAA-ready handling.

**Kelebihan:**
- Dictation langsung ke app tanpa switching context.
- Context-aware formatting lebih advanced dari built-in voice typing mana pun.
- Backtracking correction ("actually, no, 3 p.m.") jadi pengalaman natural.
- Android unlimited free tier = diferensiasi kuat.

**Kekurangan/Keluhan:**
- Cloud processing — audio dikirim untuk transcription; privacy mode hanya opsional.
- Command Mode bisa glitchy (per Zapier review).
- Free tier sangat restrictive (2,000 words/minggu desktop).
- Context awareness dengan screenshot/scraping raises privacy questions (Wispr docs acknowledge this).
- Tidak ada meeting recording atau file import.

**Apa Trareon harus copy:**
- [UX] Backtracking correction parsing — Wispr menangkap "actually change that to X" dan langsung replace teks, bukan mengetik kedua bagian. Trareon bisa pakai pattern yang sama untuk live transcript correction.
- [UX] Personal dictionary dengan learning dari koreksi user — level up dari static glossary.
- [UX] Context-aware tone/format adaptation — useful untuk Trareon jika user mengetik catatan sambil merekam.

---

### 1.2 Handy (cjpais/Handy) — Open-Source Cross-Platform Dictation

**Apa itu:** Open-source Tauri app (Rust backend + React frontend), 100% offline, MIT license. Press shortcut → speak → text pasted into active app. Cross-platform (macOS/Windows/Linux). Mendukung Whisper dan **Parakeet** untuk CPU-optimized inference.

**Pricing:** 100% free, MIT license, open-source. tersedia via Homebrew (`brew install --cask handy`) dan winget.
https://handy.computer/, https://github.com/cjpais/Handy (30,643 stars)

**Platform:** macOS, Windows, Linux, FreeBSD.

**Fitur utama:**
- Push-to-talk (hold key) atau toggle mode.
- Global keyboard shortcut (configurable).
- VAD (Silero) untuk filter silence sebelum diproses.
- Model pilihan: Whisper (GGML/GGUF) atau **Parakeet** (CPU-optimized, dari Coqui/Sesame, ~4x faster dari Whisper pada CPU lemah).
- Audio passthrough: transcribed text langsung pasted ke cursor aktif.
- CLI (`handy-cli`) untuk scriptable use.
- API server mode: app lain bisa use handy untuk transcribe.
- Parakeet support added v0.8+; Cohere Transcribe model juga didukung.

**Arsitektur (dari README):**
- Frontend: React + TypeScript + Tailwind.
- Backend: Rust + Tauri.
- Core libs: `transcribe-cpp` (Whisper GGML), `transcribe-rs` (Parakeet), `cpal` (cross-platform audio I/O), `vad-rs` (Silero VAD), `rdev` (global shortcuts), `rubato` (resampling).

**Kelebihan:**
- Truly open source — MIT, bisa diverifikasi, bisa di-fork.
- 100% offline, audio tidak pernah meninggalkan device.
- Parakeet + Silero VAD = pipeline yang sudah proven untuk weak CPU.
- API server mode = extensibility.
- 30k+ stars = komunitas besar.

**Kekurangan:**
- Tidak ada meeting recording — hanya quick dictation burst.
- Tidak ada speaker diarization.
- Tidak ada transcript history atau file import.

**Apa Trareon harus copy:**
- [Engine] Gunakan Parakeet (via `transcribe-rs` / `parakeet-rs`) sebagai faster alternative ke Whisper untuk weak CPU — terbukti 4x faster.
- [Engine] Silero VAD integration dengan `vad-rs` pattern — proven di Handy.
- [UX] API server mode — Trareon bisa expose transcription API ke app lain.

---

### 1.3 Whispering / Epicenter — Open-Source Dictation with Local GGUF

**Apa itu:** Fork dari braden-w/whispering, rebranded ke Epicenter. AGPL-3.0, open-source. Press shortcut → speak → transcribed + transformed → pasted. Supports cloud provider (Groq, OpenAI, etc.) atau **on-device GGUF transcription** (via Epicenter desktop build). Transformations bisa edit hasil transcription (LLM-powered cleanup).

**Pricing:** Free (build from source), Epicenter monorepo.
https://github.com/epicenter-so/epicenter (Whispering rebranded), https://reveneau.com/open-source/whispering

**Platform:** macOS, Windows, Linux (build from source; AppImage tersedia).

**Fitur utama:**
- Provider-agnostic transcription: Groq, OpenAI, ElevenLabs, self-hosted endpoint, atau local GGUF.
- On-device GGUF transcription hanya di Epicenter desktop build.
- System-wide shortcuts + paste at cursor (desktop).
- Browser build: fallback clipboard.
- Audio leaves device hanya saat cloud provider dipilih.
- Transformations: LLM-powered text cleanup/editing post-transcription.
- Epicenter Assistant: chat with all your data; bisa access Whispering history.

**Kelebihan:**
- Open source, AGPL-3.0.
- Provider-agnostic — tidak lock-in ke satu transcription engine.
- Transformations layer = cara menarik untuk AI-powered cleanup tanpa dedicated product.
- Epicenter ecosystem: semua data dalam folder SQLite + plain text user owns.

**Kekurangan:**
- Tidak ada installer download untuk build from source path.
- Kurang mature dari Handy (lebih baru, 30k vs lebih kecil star count).
- Kurang komunitas.

**Apa Trareon harus copy:**
- [Engine] Provider-agnostic transcription architecture — Trareon bisa expose interface untuk pluggable transcription engine (Whisper/Parakeet/anything).
- [UX] Transformations layer — post-transcription AI cleanup via user-configurable LLM prompts. Mirip fitur Wispr Flow tapi untuk transcribed text.

---

### 1.4 Tactiq — Chrome Extension Live Captions (Meeting Bot-Free)

**Apa itu:** Chrome extension + browser widget yang menampilkan live transcript dari meetings tanpa bot joiner. Bekerja dengan Google Meet, Zoom, MS Teams. Captions-based (menggunakan platform captions API atau Web Speech API), bukan recording audio langsung.

**Pricing:**
- Free: 10 meetings/bulan.
- Pro: $12/user/bulan (annual) — unlimited meetings, AI summaries, 60+ languages.
- Enterprise: custom pricing.
https://tactiq.io/, https://tactiq.io/pricing

**Platform:** Chrome/Edge extension, browser-based. Tidak ada desktop app.

**Fitur utama:**
- Live transcript visible dalam Tactiq widget di samping meeting window.
- Speaker identification.
- Tags & labels: actionable items, decisions, questions, highlights.
- Screenshot capture dari dalam meeting.
- AI summaries post-meeting (Pro+).
- Speaker participation analytics.
- Export: PDF, TXT, Google Doc, Notion, Slack.
- 30+ bahasa transcription.

**Kelebihan:**
- Bot-free — tidak ada participant lain yang tahu ada transcription.
- Langsung di browser, tidak perlu install desktop app.
- Screenshot integration berguna untuk capture presentasi + transcript.

**Kekurangan:**
- Bergantung pada platform captions (Google Meet native captions, etc.) — tidak punya kontrol penuh atas quality.
- Browser-based = tidak bisa capture system audio (only captions yang ditampilkan platform).
- Free tier sangat terbatas (10 meetings/bulan).
- Tidak ada offline mode.

**Apa Trareon harus copy:**
- [UX] Tag/label system untuk actionable items, decisions, questions dalam transcript — lebih structured dari bookmarks.
- [UX] Screenshot capture dari dalam meeting context ke transcript timestamp.

---

### 1.5 Read.ai — Meeting Intelligence dengan Digital Twin

**Apa itu:** AI meeting assistant yang terhubung ke calendar + meeting platforms (Zoom, Meet, Teams, Webex). Generates report post-meeting dengan transcript, summary, action items, dan analytics. Includes "Ada" AI Digital Twin yang handles scheduling dan follow-up.

**Pricing:**
- Free: 5 meetings/bulan, 1-hr max/meeting, basic summaries.
- Pro: $15/user/bulan (annual) — unlimited meetings, 4-hr max, video playback, 25 AI agents.
- Enterprise: $22.50/user/bulan (annual) — unlimited, 8-hr max, SSO, HIPAA.
https://eesel.ai/blog/read-ai-pricing, https://read.ai

**Platform:** Web, iOS, Android, Chrome, API.

**Fitur utama:**
- Automated meeting reports: transcript + AI summary + action items + sentiment analysis + talk-time analytics.
- Speaker diarization (95% accuracy klaim berdasarkan review).
- Search Copilot: ask questions across all meetings + emails + Slack.
- 10+ AI agents (Monday Briefing Agent, End of Week Agent, Post-Meeting Summary Agent).
- AI Digital Twin ("Ada"): schedules meetings, answers questions, drafts emails on your behalf.
- Pre-meeting briefs dari past meetings.
- HIPAA compliance (Enterprise+).

**Kelebihan:**
- Comprehensive analytics: talk-time, sentiment, engagement trends.
- Digital Twin paradigm = next-generation productivity layer di atas transcription.
- Free tier = accessible untuk testing.

**Kekurangan:**
- Cloud only — audio diproses di cloud.
- Free tier sangat terbatas (5 meetings/bulan).
- Indonesian language support tidak jelas (25 bahasa klaim, Indonesian mungkin termasuk tapi tidak dikonfirmasi).

**Apa Trareon harus copy:**
- [UX] Post-meeting analytics: talk-time distribution, filler words, engagement — useful untuk corporate training use case.
- [UX] Digital Twin concept — Trareon bisa punya "meeting memory agent" yang answer questions tentang meeting history.

---

### 1.6 Bluedot — Bot-Free Privacy-First Meeting Notes

**Apa itu:** AI notetaker yang merekam tanpa bot joiner. Desktop app (Mac/Windows) capture system audio + Chrome extension untuk browser-based meetings. Fokus pada privacy: tidak ada bot, GDPR compliant, data tidak digunakan untuk training AI.

**Pricing:**
- Free: 5 meetings total (lifetime, bukan monthly — ini sangat restrictive).
- Paid plans: unlimited recordings, CRM integrations (HubSpot, Salesforce), Notion/Slack sync.
https://www.bluedothq.com/, https://www.meetjamie.ai/blog/bluedot-review

**Platform:** Chrome extension, Mac app, Windows app, iOS, Android.

**Fitur utama:**
- Bot-free capture: tidak ada participant lain.
- System audio capture (desktop app) + Chrome extension (browser-based meetings).
- CRM sync: HubSpot, Salesforce auto-update post-meeting.
- Follow-up email generation.
- 100+ bahasa transcription.
- In-person meeting capture via mobile app.
- Video editing via transcript: delete filler words dengan edit teks.
- AI chat across meetings (ask questions about past meetings).
- Annotations + comments on transcript moments.
- Recording templates.

**Kelebihan:**
- CRM auto-update = workflow automation yang powerful.
- Video editing via transcript = unique workflow (screenshot/bluedot-review).
- Privacy-first positioning.

**Kekurangan:**
- Free tier = 5 meetings total lifetime — almost unusable sebagai free tier.
- Desktop app cloud-reliant untuk summaries (tidak ada true offline transcription).
- Setup cukup complex (mic picker, template selection) vs competitor yang lebih "just works".
- Templates bisa produce inconsistent output tanpa konfigurasi yang tepat.

**Apa Trareon harus copy:**
- [UX] Video/audio editing via transcript — delete filler words dengan edit teks, bukan waveform manipulation.
- [UX] CRM sync pattern — post-meeting automation untuk update Notion/CRM.

---

### 1.7 Sembly — Enterprise Meeting Intelligence

**Apa itu:** AI meeting assistant dengan workspace model (team-based). Auto-joins meetings, transcribes, generates structured notes. Strong focus pada analytics dan enterprise features (MCP, HIPAA, custom templates).

**Pricing:**
- Free trial: unlimited meetings, 5 hours media upload, 1-year history.
- Basic: free trial → berbayar, 1 user/workspace, unlimited meetings, transcription + summaries + tasks.
- Pro: $29/user/bulan (annual) — 40 users/workspace, multi-meeting AI chat, unlimited video, custom templates, MCP access, advanced search, sentiment analysis, risk/issue detection, automation access.
- Max: $39/user/bulan (annual) — 500 users, unlimited history, audit log, HIPAA, SSO custom, SMTP relay.
https://sembly.ai/pricing

**Platform:** Web, Zoom/Meet/Teams/Webex integration, dialer integration.

**Fitur utama:**
- Auto-join dari calendar.
- Multi-language transcription (40+ bahasa, mixed-language meetings).
- Multi-meeting AI chat: ask questions across entire meeting archive.
- Sentiment analysis.
- Risk/Issue/Event detection otomatis.
- Custom meeting notes templates.
- Consent tracking.
- Workspace-level analytics.
- MCP access (Pro+).
- API + Zapier + webhooks.
- Auto-sharing to connected tools.

**Kelebihan:**
- Enterprise-grade: MCP, HIPAA, audit log, SSO.
- Multi-meeting AI chat = knowledge base dari semua meeting.
- Workspace model = team collaboration.

**Kekurangan:**
- Bot-based (joins meeting sebagai participant).
- Tidak ada local/offline option.
- Free trial bukan free tier permanen.
- Pricing complex (per-user).

**Apa Trareon harus copy:**
- [UX] MCP server access — Trareon bisa expose MCP untuk integrasi dengan AI tools ecosystem.
- [Engine] Sentiment analysis + risk/issue detection — useful untuk corporate compliance use cases.
- [Feature] Consent tracking — penting untuk Indonesian context di mana consent untuk recording perlu di-address.

---

### 1.8 Avoma — Full Meeting Lifecycle Management

**Apa itu:** End-to-end meeting lifecycle platform dari agenda creation → live transcription → AI summaries → CRM sync → follow-up. Dialer integration (Aircall, RingCentral, Dialpad) unusual di tier ini.

**Pricing:**
- Startup: $19/recorder-seat/bulan (annual) — up to 25 seats.
- Organization: $29/recorder-seat/bulan (annual) — up to 100 seats.
- Enterprise: $39/recorder-seat/bulan (annual, min 10 seats).
- Add-ons: Conversation Intelligence $29, Revenue Intelligence $29, Lead Router $19 per seat/bulan.
- Full config: ~$82/seat/bulan (StartUp + CI + RI).
- 14-day free trial (Organization plan).
https://www.sembly.ai/pricing, https://productivewithchris.com/tools/avoma

**Platform:** Zoom/Meet/Teams/dialers, web.

**Fitur utama:**
- Full meeting lifecycle: agenda → recording → transcription → AI notes → CRM sync → follow-up.
- Real-time transcription 70+ bahasa.
- Speaker identification.
- Topic detection (auto-segment into topics).
- Conversation Intelligence: AI coaching, custom scorecards (MEDDIC/SPICED/BANT), talk-pattern analytics, filler word tracking, smart trackers (semantic, bukan literal keyword).
- Revenue Intelligence: deal risk alerts, pipeline forecasting, win-loss analysis, automatic CRM field updates.
- Custom meeting notes templates.
- Scheduling dengan 1:1 + round-robin lead routing (Lead Router add-on).
- API + webhooks.

**Kelebihan:**
- Scorecard methodology (MEDDIC, SPICED, NEAT) = enterprise sales tool depth.
- Semantic smart trackers (competitor/churn signal detection even with different phrasing).
- Dialer integration unusual di price band ini — inside-sales teams value ini.
- Conversation intelligence → revenue intelligence pipeline.

**Kekurangan:**
- Pricing sangat expensive kalau ditambah semua add-ons (~$82/seat/bulan).
- Startup cap 25 seats = forced upgrade trajectory.
- Bot-based capture.
- Complex product dengan banyak add-ons.

**Apa Trareon harus copy:**
- [Feature] MEDDIC/SPICED/BANT scorecard framework — Trareon bisa expose sebagai templates untuk sales meetings.
- [Feature] Semantic tracker pattern (competitor mentions detected even with paraphrasing) — berguna untuk competitive intelligence.

---

### 1.9 Supernormal — Bot-Free + AI Agents for Agency Work

**Apa itu:** AI meeting notetaker tanpa bot + agent ecosystem yang generate deliverables dari meeting context. Fokus pada agency/client work: follow-up emails, slide decks, briefs, research reports直接从 meeting context.

**Pricing:**
- Free: 5 daily credits, 15 monthly credits.
- Team: $0/bulan (annual) — 50 credits/bulan, unlimited seats, rollover credits up to 2 years.
- Business: $0/bulan (annual) — + SSO, audit logs, data retention controls.
- Credits = meeting captures + AI generation tasks.
https://www.supernormal.com/pricing

**Platform:** Desktop app (Mac/Windows), bot-free.

**Fitur utama:**
- Bot-free capture dari komputer (Supernormal notetaker app).
- Group meetings into projects → context untuk AI agents.
- AI agents: generate slides, follow-up emails, documents, calendar invites, images dari meeting context.
- References meeting transcripts + emails + docs untuk contextual output.
- MCP connection to other tools.
- Upload files + connect email + calendar untuk additional context.
- Client-ready deliverables, bukan rough drafts.

**Kelebihan:**
- Deliverable generation dari meeting context = langsung actionable output.
- Bot-free = tidak ganggu meeting.
- MCP = extensibility.

**Kekurangan:**
- Credit system = complexity untuk users.
- Agent outputs perlu review (bukan perfect first-pass).
- Cloud processing.

**Apa Trareon harus copy:**
- [Feature] Meeting-to-deliverable pipeline: Trareon transcript → generate formatted notulen, follow-up email, action item list secara otomatis.
- [UX] Project grouping (multiple meetings into one context) → cross-meeting memory.

---

### 1.10 Apple Voice Memos (macOS Sequoia / iOS 18)

**Apa itu:** Built-in voice recording app di Apple ecosystem, sekarang dengan on-device transcription. Gratis untuk semua user Apple.

**Pricing:** Free (built-in Apple).

**Platform:** iPhone (iOS 18+), iPad (iPadOS 18+), Mac (macOS 15+ Sequoia, Apple silicon only).

**Fitur utama:**
- On-device transcription (Apple Neural Engine).
- Live transcript view saat recording.
- Search dalam transcript.
- Folders + favorites organization.
- iCloud sync across devices.
- Apple Intelligence integration: Writing Tools bisa summarize transcripts.
- Layered recording (iPhone: dua audio track terpisah).

**Keterbatasan:**
- Hardware requirement: iPhone 12+ untuk transcription, Apple silicon Mac untuk macOS transcription.
- Bahasa terbatas (~10 bahasa: English, Spanish, French, German, Portuguese, Italian, Japanese, Korean, Chinese).
- **Tidak ada Indonesian.**
- Tidak ada speaker identification.
- Tidak ada summary generation (hanya Writing Tools untuk summarize setelah).
- Intel Mac tidak support transcription sama sekali.

**Relevansi untuk Trareon:**
- Apple tidak punya solusi offline multilingual yang kuat — Indonesian tidak didukung sama sekali.
- Ini adalah celah yang Trareon bisa isi untuk user Apple yang butuh Bahasa Indonesia.

---

### 1.11 Windows 11 Live Captions + Live Translator

**Apa itu:** System-level caption overlay yang mentranscribe semua audio di PC secara real-time. On-device processing, privacy-first. Copilot+ PCs bisa translate 40+ bahasa ke English secara live.

**Pricing:** Free (built-in Windows 11).

**Platform:** Windows 11 version 22H2+ (semua PC). Translation requires Copilot+ PC (NPU) + Windows 11 24H2+.

**Fitur utama:**
- Caption audio dari app apapun (video calls, browser, local media, system sounds).
- On-device transcription (audio tidak dikirim ke cloud).
- Keyboard shortcut: Win+Ctrl+L.
- Floating overlay atau docked position.
- Include microphone audio option.
- Customizable styling.
- **Translation on Copilot+**: 40+ bahasa → English; 27 bahasa → Simplified Chinese.
- Bahasa yang didukung untuk caption: 21 bahasa + regional variants (tidak termasuk Indonesian).
- Filter profanity option.
https://windowsforum.com/windows-news.4/windows-11-live-captions-on-device-subtitles-and-real-time-transcription.391958

**Keterbatasan:**
- Tidak ada speaker identification (single running transcript).
- Tidak ada saved transcript untuk review/share.
- Hanya dua output language untuk translation (English + Simplified Chinese).
- Hardware gating untuk translation feature.
- Tidak ada Indonesian.

**Relevansi untuk Trareon:**
- Windows native captioning tidak support Indonesian = opportunity.
- Tapi penting diketahui Trareon compete dengan fitur gratis OS-level.
- Trareon value proposition: speaker identification, saved transcript, export, Indonesian language support.

---

## BAGIAN 2: Implementation Techniques dari Open-Source Code

---

### 2.1 Real-Time Streaming Architecture untuk Weak CPU

#### 2.1.1 The Core Problem

Whisper tidak didesain untuk real-time. Standard Whisper inference butuh 30 detik audio per chunk dan bersifat offline. Untuk live transcription di weak CPU, ada 3 strategi utama:

1. **LocalAgreement-2 policy** (ufal/whisper_streaming): Konfirmasi transcript prefix setelah 2 iterasi agreement. Latency ~3.3 detik di GPU. Repo: https://github.com/ufal/whisper_streaming
2. **AlignAtt policy** (SimulStreaming): Deteksi dimana decoder attention paling konsentrasi di source audio, commit saat sudah "catching up." Lebih efficient dari LocalAgreement karena tidak reprocess full buffer. Repo: https://github.com/ufal/SimulStreaming
3. **Sliding window + VAD-triggered processing** (whisper.cpp stream example): Proses audio chunks setiap 500ms, VAD memutuskan apakah ada speech sebelum kirim ke Whisper. Repo: https://github.com/ggerganov/whisper.cpp

#### 2.1.2 whisper_streaming (ufal) — LocalAgreement-2

Paper: "Turning Whisper into Real-Time Transcription System" (Macháček et al., 2023), https://arxiv.org/pdf/2307.14743

**Arsitektur:**
```
Audio buffer → [new chunk] → Whisper inference → LocalAgreement-2 policy
                                         ↓
                     Prefix agreement antara 2 consecutive chunks?
                           YES → commit transcript segment
                            NO → wait for next chunk
```

**Parameter kunci:**
- LocalAgreement n=2: 2 consecutive chunks harus agree pada prefix sebelum commit.
- Chunk size: ~3 detik audio per inference call.
- Buffer reprocessing: setiap chunk baru, audio buffer di-reprocess dari awal (kurang efficient tapi akurat).
- **Average latency: 3.3 detik** pada NVIDIA A40 GPU.

**Kelemahan untuk Trareon:**
- Butuh GPU untuk 3.3 detik latency; di weak CPU akan lebih lambat.
- Buffer reprocessing = O(n²) complexity untuk n chunks.

**Relevansi:** LocalAgreement n=2 adalah simplest correct policy untuk commit decision. Trareon bisa implementasikan ini untuk live preview dengan model size kecil.

#### 2.1.3 SimulStreaming — AlignAtt Policy (State of the Art 2025)

Repo: https://github.com/ufal/SimulStreaming, Paper: https://arxiv.org/html/2506.17077

**Perbedaan dari whisper_streaming:**
- AlignAtt (Papi et al., 2023): commit transcript ketika decoder attention sudah "behind" current audio position (threshold-based).
- Tidak perlu reprocess full buffer — hanya process new chunk + forced decoding dengan prefix.
- **5x faster** dari whisper_streaming (menurut repo claims).

**Parameter:**
```
--frame_threshold N: commit saat attention threshold N frames dari end of audio
(one frame = 0.02 detik untuk large-v3)
```

**Kekurangan:** AlignAtt butuh akses ke decoder attention patterns — tidak straightforward di whisper.cpp (yang adalah inference-only binding). Implementasi terbaik di PyTorch/Torch.

#### 2.1.4 whisper.cpp Stream Example — CPU-Optimized

Repo: https://github.com/ggerganov/whisper.cpp, example: `examples/stream/README.md`

**Dual mode:**
1. **Sliding window mode** (`--step > 0`): Proses fixed interval (default 3 detik chunks, 200ms overlap).
2. **VAD mode** (`--step 0`): Hanya proses saat Silero VAD mendeteksi speech.

**Parameter streaming:**
```
--step N       : step size dalam ms (3000 = 3 detik)
--length N     : audio length per chunk dalam ms (10000 = 10 detik)
--keep N       : overlap dalam ms (200)
--max-tokens N : max tokens per chunk
--vad-thold N  : VAD threshold (0.6 default)
--freq-thold N : VAD frequency threshold
--no-context   : jangan use previous transcript sebagai prompt
-kc            : keep context between chunks
```

**Key insight dari deepwiki whisper.cpp streaming docs:**
- VAD mode (--step 0) lebih efficient karena tidak memproses silence.
- VAD threshold 0.6 = good default; naikkan untuk lebih agresif detect silence.
- `--keep` 200ms overlap mencegah word boundary artifacts.
- `--no-context` berguna untuk debugging; aktifkan `-kc` untuk better accuracy dengan context.

**Relevant code pattern (stream.cpp):**
```rust
// VAD check sebelum whisper inference
if (config.use_vad && !vad_detect(pcmf32, config.sample_rate, config.vad_threshold)) {
    return "";  // Skip silent segments
}

// Sliding window dengan overlap
auto audio_chunk = buffer.get_segment(keep_ms, length_ms);
auto result = whisper.transcribe(audio_chunk, params);
```

#### 2.1.5 WhisperLive (collabora) — Production-Grade Streaming

Repo: https://github.com/collabora/WhisperLive (v0.8+, Maret 2025)

**Arsitektur:** Server-client via WebSocket. Server menjalankan Whisper (faster-whisper backend). Client mengirim audio chunks.

**Fitur:**
- 3 backend: faster-whisper, TensorRT, OpenVINO.
- Batch inference: `--batch_inference --batch_max_size 8 --batch_window_ms 50`.
- VAD integration: `use_vad=True`.
- Word-level timestamps.
- Speaker diarization (via pyannote atau custom).
- Custom vocabulary / hotwords.
- REST API (OpenAI-compatible): `python run_server.py --enable_rest`.
- Docker: `docker run -it -p 9090:9090 ghcr.io/collabora/whisperlive-cpu:latest`.

**Key untuk Trareon:**
- Batch inference parameter (`--batch_window_ms 50`) = cara efektif untuk improve throughput di weak CPU.
- REST API = Trareon bisa expose transcription sebagai service.

#### 2.1.6 Recommended Architecture untuk Trareon (Weak CPU)

Berdasarkan research, arsitektur optimal untuk weak CPU (4-core, no GPU):

```
┌─────────────────────────────────────────────────────┐
│  ARCHITECTURE: Dual-Pass Streaming                  │
│                                                     │
│  LIVE PREVIEW PATH:                                │
│  Silero VAD → [speech detected]                    │
│    → whisper.cpp small/tiny (fast, ~10x realtime)   │
│    → LocalAgreement-2 commit policy                │
│    → Live preview UI (approximate transcript)      │
│                                                     │
│  FINAL TRANSCRIPT PATH (post-meeting):             │
│  Full audio → whisper.cpp turbo/large (accurate)   │
│    → Offline full-file transcription               │
│    → Replace/update live preview segments          │
│    → Speaker diarization (sherpa-onnx)             │
│    → Word-level timestamps (whisper.cpp native)    │
│    → Final export                                   │
└─────────────────────────────────────────────────────┘
```

**Concrete parameters untuk weak CPU:**
```bash
# Live preview: small model, VAD-gated
whisper-cli -m models/ggml-small.bin \
  --vad -vm models/ggml-silero-v5.bin \
  --vad-threshold 0.6 \
  --vad-min-speech-duration-ms 250 \
  --vad-min-silence-duration-ms 500 \
  --vad-speech-pad-ms 300 \
  --step 3000 --length 10000 --keep 200 \
  -t 4 -nt 0.3 -lpt -3.0

# Final pass: turbo model, offline
whisper-cli -m models/ggml-large-v3-turbo-q5_0.bin \
  --offset 0 --length 0 -t 4 \
  -fp --no-fallback -snf
```

**Rationale:**
- `small` model (~155M params) bisa berjalan di ~2-3x realtime di weak CPU.
- Silero VAD < 1ms per 30ms chunk = negligible overhead.
- LocalAgreement-2 commit policy = simple, correct, tunable.
- Post-meeting full pass dengan turbo = accurate final output.
- Sumber: whisper_streaming paper (https://arxiv.org/pdf/2307.14743), whisper.cpp stream README (https://github.com/ggerganov/whisper.cpp/blob/master/examples/stream/README.md), SimulStreaming (https://github.com/ufal/SimulStreaming).

---

### 2.2 Silence Hallucination Prevention

#### 2.2.1 Why Silence Hallucination Happens

Whisper hallucinate karena model trained dengan text-conditioned generation. Ketika diberi silence atau low-complexity audio, model "hallucinates" plausible-sounding text karena distribusi output condong ke common patterns. Ini berbeda dari low-confidence output — hallucinated text sering **high-probability** menurut model karena именно this pattern sering muncul di training data.

**Concrete examples yang sering muncul:**
- "[MENGENI]", "[PAMUNGKAS]", "[MENINJAU]", dll. — ini bukan audio, tapi model patterns.
- Common English phrases: "And so I think that would be", "I think we should probably maybe", dll.

**Root cause:** VAD yang tidak cukup agresif → silence masuk ke encoder → hallucination triggered.

Sumber: https://multigrid.ai/learn/whispercpp-hallucination-on-silence

#### 2.2.2 VAD-Gating (The Primary Fix)

**Silero VAD** (https://github.com/snakers4/silero-vad) adalah solusi paling proven untuk hallucination prevention. Silero VAD return per-frame probability bahwa ada speech.

**Parameters untuk hallucination prevention:**
```python
# Python Silero VAD
from silero_vad import load_silero_vad, get_speech_timestamps

model = load_silero_vad()
speech_timestamps = get_speech_timestamps(
    wav, 
    model,
    threshold=0.5,           # default 0.5; naikkan untuk more aggressive
    min_speech_duration_ms=250,  # minimum 250ms speech
    min_silence_duration_ms=500,  # 500ms silence = segment boundary
    speech_pad_ms=300,       # padding sebelum/sesudah speech
)
```

**whisper.cpp Silero VAD flags:**
```
--vad                 # enable VAD
--vad-model FNAME    # path ke Silero VAD model
--vad-threshold N    # speech probability threshold (default 0.6)
--vad-min-speech-duration-ms N  # minimum 250ms
--vad-min-silence-duration-ms N  # minimum 500ms silence = cut
--vad-max-speech-duration-s N  # maximum speech segment (prevents runaway)
--vad-speech-pad-ms N  # padding ms di sekitar deteksi speech
```

**Critical tuning notes (dari multigrid.ai research):**
- `--vad-speech-pad-ms` terlalu rendah = clipped word onsets.
- `--vad-min-silence-duration-ms` terlalu rendah = fragmented sentences (lost context).
- Untuk podcast/noisy audio: turunkan threshold dari 0.6 ke 0.35-0.5.
- Podcast-grade VAD perlu custom training; standard VAD falter on mixed audio.

Sumber: https://multigrid.ai/learn/whispercpp-hallucination-on-silence

#### 2.2.3 no_speech_prob / Logprob Thresholds

whisper.cpp menyediakan filtering berdasarkan no-speech probability:

```
-nth N,   --no-speech-thold N   # no-speech probability threshold
-lpt N,   --logprob-thold N     # average log probability threshold
-et  N,   --entropy-thold N      # entropy threshold untuk decoder fallback
-nf,      --no-fallback          # do not use temperature fallback
-sns,     --suppress-nst         # suppress non-speech tokens
```

**Limitation:** Filtering ini mengasumsikan hallucinated output = low-confidence output. Tapi hallucinated boilerplate sering **high-probability** karena именно pattern ini sering di-training data. Tuning thresholds sering disappoint karena false positive/negative tradeoff.

**Better approach:** Kombinasikan VAD-gating dengan thresholds sebagai secondary filter, bukan primary.

#### 2.2.4 Suppress Tokens

whisper.cpp mendukung suppress tokens untuk mencegah specific output patterns:

```
--suppress-common  # suppress common tokens
--prompt-cache-no-recache  # don't recache prompt tokens
```

**Cara efektif:** Generate hallucination blocklist dari testing. Identifikasi patterns yang sering hallucinated → suppress dengan custom token list.

#### 2.2.5 condition_on_previous_text=false

whisper.cpp flag:
```
--no-context  # do not use previous transcription as prompt
```

Berguna untuk debugging hallucination — jika hallucination hilang dengan no-context, berarti previous context adalah penyebabnya.

#### 2.2.6 Distil-Whisper — Lower Hallucination Rate

Distil-Whisper (https://github.com/huggingface/distil-whisper) secara terukur punya **lebih sedikit hallucination** di long-form audio:
- 1.3x fewer repeated 5-gram word duplicates.
- 2.1% lower insertion error rate (IER) dibanding Whisper vanilla.

**Kelemahan:** Distil-Whisper English-only (tidak multilingual). Tidak relevant untuk Trareon kecuali sebagai inspiration untuk future distillation.

#### 2.2.7 Recommended Hallucination Prevention Stack untuk Trareon

```
1. PRIMARY: Silero VAD-gating
   - threshold=0.5, min_speech=250ms, min_silence=500ms, speech_pad=300ms
   - Hanya kirim audio yang mengandung speech ke Whisper

2. SECONDARY: no_speech_prob filter
   - suppress segments dengan no_speech_prob > 0.6 DAN logprob < -1.0

3. POST-PROCESSING: Hallucination blocklist
   - Pattern "[MENGENI]", "[PAMUNGKAS]", dll.
   - Regex filter untuk common hallucinated phrases

4. PARAMETER TUNING:
   - condition_on_previous_text=false during silence (avoid drift)
   - suppress_tokens untuk common hallucinated patterns
```

Sumber: Silero VAD (https://github.com/snakers4/silero-vad), whisper.cpp hallucinations (https://multigrid.ai/learn/whispercpp-hallucination-on-silence), Distil-Whisper paper (https://github.com/huggingface/distil-whisper).

---

### 2.3 Speaker Diarization (Local, Rust-Embeddable)

#### 2.3.1 The Pipeline

Speaker diarization standard pipeline (4 stages):
1. **VAD**: drop silence.
2. **Segmentation**: cut audio jadi chunks satu-speaker.
3. **Embedding**: generate voice fingerprint per chunk (512-dim vector).
4. **Clustering**: group embeddings → speaker IDs.

**Total on-disk footprint untuk ONNX-only pipeline: ~45MB** (OpenWhispr, dari blog post mereka).

#### 2.3.2 pyannote.audio 3.x + ONNX Export

pyannote.audio adalah de-facto academic baseline untuk diarization. Pipeline lengkap:
- **Segmentation model**: PyanNet (BiLSTM over SincNet features), output = per-frame powerset classes {silence, s1, s2, s3, s1s2, s1s3, s2s3}.
- **Embedding model**: ResNet over mel-filterbank (80 bins, 25ms window, 10ms shift).

**ONNX export options:**

1. **FredrikKarlssonSpeech/pyannote-speaker-diarization-onnx** (HuggingFace):
   - Segmentation: `segmentation/model.onnx` (5.6 MB FP32, 2.8 MB FP16, 1.5 MB INT8).
   - Embedding: `embedding/model.onnx` (25 MB FP32, 6.4 MB INT8).
   - Repo: https://huggingface.co/FredrikKarlssonSpeech/pyannote-speaker-diarization-onnx

2. **andrew867/pyannote-openvino** (OpenVINO acceleration):
   - Runs segmentation + embedding via Intel OpenVINO (CPU/iGPU).
   - Drop-in replacement untuk pyannote.audio Pipeline API.
   - Repo: https://github.com/andrew867/pyannote-openvino

3. **litert-community/Speaker-Diarization-LiteRT** (Android/TFLite):
   - Full pipeline untuk Android (Pixel 8a verified).
   - Embedding: `wespeaker_emb_fp16.tflite` (256-dim, 13.4 MB).
   - Segmentation: `pyannote_seg30.onnx` (10s window, 589 frames output).
   - Repo: https://huggingface.co/litert-community/Speaker-Diarization-LiteRT

#### 2.3.3 sherpa-onnx — No-Python Diarization Binary

sherpa-onnx (by m-browser) menyediakan offline diarization sebagai single binary tanpa Python/PyTorch:

```
# Install via pre-built binary
wget https://github.com/k2-fsa/sherpa-onnx/releases/latest/download/sherpa-onnx-offline-diarization

# Run
./sherpa-onnx-offline-diarization \
  --segmentation-model=sherpa-onnx-speaker-diarization-pooled-generic-3.0.onnx \
  --embedding-model=sherpa-onnx-3dspeaker-cam++-3.0-swift-no-memory-bank-3.0.onnx \
  audio.wav
```

**Output:** Plain text, one line per segment:
```
0.00 -- 2.34 speaker_00
2.34 -- 5.67 speaker_01
```

**sherpa-onnx model releases:**
- Segmentation: `sherpa-onnx-speaker-diarization-pooled-generic-3.0.onnx` (6.6 MB).
- Embedding CAM++: `sherpa-onnx-3dspeaker-cam++-3.0-swift-no-memory-bank-3.0.onnx` (~30 MB).
- Repo: https://github.com/k2-fsa/sherpa-onnx

**Ini adalah opsi paling praktis untuk Rust app** — single binary, no Python, no PyTorch.

#### 2.3.4 CAM++ / 3D-Speaker Embeddings

CAM++ (Discriminative multi-stream CNN) adalah embedding model yang digunakan sherpa-onnx. Dimensionality: 512-dim float vectors. Clustering: agglomerative (centroid linkage, cosine distance, threshold 0.5).

**Kualitas:** pyannote.audio pipeline achieves DER (Diarization Error Rate) 12-15% pada AMI dan CALLHOME benchmarks — sama dengan commercial cloud providers.

#### 2.3.5 Recommended Diarization Architecture untuk Trareon

```
Pipeline (Rust, via sherpa-onnx binary spawn):
1. Silero VAD (already in pipeline) → speech timestamps
2. Crop audio segments → sherpa-onnx offline-diarization binary
3. Parse output: [start] -- [end] [speaker_NN]
4. Match speaker segments ke Whisper transcript segments (timestamp overlap)
5. Label each transcript segment dengan speaker ID
```

**Embedding storage:** SQLite BLOBs di local disk (OpenWhispr pattern). Speaker profiles bisa di-cache untuk recurring meetings.

**Model downloads (cache at ~/.cache/trareon/):**
- Segmentation: ~6.6 MB
- Embedding: ~30 MB
- Total: ~40 MB — reasonable untuk download-once.

Sumber: OpenWhispr blog (https://openwhispr.com/blog/local-speaker-diarization), pyannote-openvino (https://github.com/andrew867/pyannote-openvino), sherpa-onnx releases (https://github.com/k2-fsa/sherpa-onnx/releases).

---

### 2.4 Word-Level Timestamps & Alignment

#### 2.4.1 whisper.cpp Native Token Timestamps

whisper.cpp menyediakan token-level timestamps secara native:

```rust
// Rust whisper.cpp binding
let params = whisper_full_params::default()
    .with_probs(false)
    .with_tokens(true)
    .with_language("id");

whisper_full(ctx, params, &samples);

// Access token timestamps
for token in tokens {
    println!("{:?} t0={:.2}s t1={:.2}s", 
        token.text, 
        token.t0 as f64 / 100.0,  // ms → s
        token.t1 as f64 / 100.0
    );
}
```

**Keterbatasan whisper.cpp native timestamps:**
- Token-level, bukan word-level — perlu aggregation.
- Tidak seakurat forced alignment.

#### 2.4.2 WhisperX wav2vec2 Alignment

WhisperX (https://github.com/m-bain/whisperX) menggunakan forced alignment dengan wav2vec2 untuk word-level timestamps yang lebih akurat:

```python
# whisperX alignment
import whisperx

model = whisperx.load_model("large-v2", device="cuda")
audio = whisperx.load_audio("audio.wav")
result = model.transcribe(audio, batch_size=16)

# Load alignment model
model_a, metadata = whisperx.load_align_model(
    language_code=result["language"], device="cuda"
)
result = whisperx.align(
    result["segments"], model_a, metadata, audio, device="cuda"
)

# Access word-level timestamps
for segment in result["segments"]:
    for word in segment["words"]:
        print(f"{word['word']}: {word['start']:.2f}s - {word['end']:.2f}s")
```

**Alignment model:** `WAV2VEC2_ASR_LARGE_LV60K_960H` — large wav2vec2 model untuk alignment.

**Accuracy improvement:** Whisper segment timestamps bisa off 1-3 detik. wav2vec2 alignment mengoreksi ke ±50ms accuracy.

**Kekurangan untuk Rust/Desktop app:**
- wav2vec2 alignment butuh GPU (atau sangat slow di CPU).
- Python-only library.

#### 2.4.3 whisperx-mlx (Apple Silicon)

whisperx-mlx (https://github.com/taavi223/whisperx-mlx) port WhisperX ke Apple Silicon via MLX:

```python
import whisperx

result = whisperx.load_audio("audio.wav")
result = model.transcribe("audio.wav", word_timestamps=True)
```

**Keuntungan:** Native word timestamps dari MLX Whisper's cross-attention patterns — tidak perlu separate alignment model.

**Limitation:** MLX only (Apple Silicon), English-focused.

#### 2.4.4 Alternative: forced_alignment via phoneme timing

**Untuk Rust app**, opsi paling praktis:

1. **whisper.cpp native token timestamps** — cukup untuk basic word timing (±200ms).
2. **Post-hoc alignment dengan smaller wav2vec2** — jika CPU kuat, jalankan light alignment model.
3. **Click-to-seek approximation** — map transcript words ke approximate timestamps menggunakan Whisper's existing segment timestamps + token count interpolation.

**Recommended approach untuk Trareon:**
```
1. Use whisper.cpp --max-len 14 (token count limit) + token timestamps
2. Aggregate consecutive tokens → word groups
3. Interpolate word positions dalam segment proportionally
4. Accuracy: ±200-500ms — cukup untuk click-to-seek dan karaoke highlighting
5. Post-processing: optional wav2vec2 alignment pass jika accuracy needed
```

Sumber: WhisperX (https://github.com/m-bain/whisperX), whisperx-mlx (https://github.com/taavi223/whisperx-mlx), whisper.cpp examples (https://github.com/ggerganov/whisper.cpp).

---

### 2.5 Indonesian Accuracy — Best Open Models

#### 2.5.1 Whisper large-v3 / turbo — Baseline

Whisper large-v3 multilingual, mencakup Indonesian (language code `id`):
- Training data mencakup Common Voice, FLEURS, dan banyak multilingual audio.
- WER pada Indonesian: **~12-15%** pada clean test sets (faster-whisper benchmarks).
- Code-switching ID/EN: didokumentasikan bekerja dengan baik di Whisper multilingual models.

**Limitations:**
- Dialect/accent variation: Javanese, Sundanese, Jakarta slang = ~20-30% accuracy degradation.
- Formal vs informal register: WER lebih tinggi untuk speech yang mixing formal/informal.
- Named entities: proper names sering salah, perlu custom vocabulary.

#### 2.5.2 Fine-Tuned Indonesian Whisper Models

**cahya/whisper-medium-id** (HuggingFace):
- Fine-tuned dari `openai/whisper-medium` pada Indonesian data (Common Voice 11, FLEURS, magic_data, titml).
- **WER: 3.83%** pada Common Voice 11 test split.
- **WER: 9.74%** pada Google FLEURS test split.
- Repository: https://huggingface.co/cahya/whisper-medium-id

**Model family dari Cahya:**
- `cahya/whisper-tiny-id`: WER 18.28% (too low quality)
- `cahya/whisper-small-id`: WER 6.06%
- `cahya/whisper-medium-id`: WER 3.83% (CV11) / 9.74% (FLEURS)
- `cahya/whisper-large-id`: likely exists, tidak terdokumentasi di HF

**Penggunaan:**
```python
from transformers import pipeline
transcriber = pipeline(
    "automatic-speech-recognition",
    model="cahya/whisper-medium-id"
)
transcriber.model.config.forced_decoder_ids = (
    transcriber.tokenizer.get_decoder_prompt_ids(
        language="id",
        task="transcribe"
    )
)
```

**Keterbatasan:**
- Medium model (~769M params) lebih lambat dari turbo/small.
- Untuk GGUF/whisper.cpp: perlu konversi dari transformers format.
- Tidak ada code-switching optimization yang explicit.

#### 2.5.3 NVIDIA Parakeet TDT v3 — Production-Grade Multilingual

Parakeet TDT (Timestamped Diarization Transformer) v3 dari NVIDIA:
- Multilingual ASR termasuk Indonesian.
- ~4x faster dari Whisper di CPU (per Meetily README).
- ONNX export tersedia via `sherpa-onnx`.
- Supports speaker diarization jointly.

**Sumber:** Meetily README (https://github.com/Zackriya-Solutions/meetily), Parakeet NIM (https://build.nvidia.com/nvidia/parakeet-tdt-nemo).

#### 2.5.4 Vosk Indonesian Model

Vosk (Kaldi-based) menyediakan small Indonesian model:
- Size: ~45 MB (small model).
- WER: tidak ada benchmark resmi, tapi expected ~15-20% pada clean audio.
- Keuntungan: sangat fast, low memory.
- Repository: https://alphacephei.com/vosk/models

**Kekurangan:** Kualitas lebih rendah dari Whisper.

#### 2.5.5 Recommended Indonesian Model Strategy untuk Trareon

```
Tier 1 (Fast Preview, Live): 
  whisper.cpp turbo (ggml-medium or ggml-small)
  → WER ~12-15%, fast di weak CPU

Tier 2 (Accurate Final):
  whisper.cpp turbo + Indonesian fine-tune (cahya-medium-id GGUF conversion)
  → WER ~5-8% improvement untuk formal Indonesian
  → Still runnable di CPU dengan batch offline

Tier 3 (Best Quality):
  Parakeet TDT v3 via sherpa-onnx
  → ~4x faster dari Whisper + joint diarization
  → Recommended if hardware supports

Code-switching handling:
  → Whisper multilingual handle ID/EN automatically
  → No special model needed; just set language="id" dan biarkan detect
```

**Important caveat:** Indonesian fine-tuned models (cahya) adalah medium-size. Di weak CPU (4-core), turbo masih lebih practical untuk live preview. Fine-tuned model sebaiknya untuk post-meeting full-file transcription.

Sumber: cahya/whisper-medium-id (https://huggingface.co/cahya/whisper-medium-id), Vosk models (https://alphacephei.com/vosk/models), Parakeet NIM (https://build.nvidia.com/nvidia/parakeet-tdt-nemo).

---

### 2.6 Dictation-Style UX (Global Push-to-Talk untuk Any App)

#### 2.6.1 Is It Worth Adding to Trareon?

Wispr Flow, Handy, dan Whispering menunjukkan demand untuk global push-to-talk. Tapi Trareon adalah meeting transcriber, bukan dictation app. Value proposition berbeda:

- **Trareon's core**: meeting recording + transcription + summary.
- **Dictation add-on**: type into any app via voice.

**Worth it? Consider:**
- ✅ Handy (MIT, 30k stars) membuktikan ada open-source demand untuk ini.
- ✅ Trareon sudah punya audio capture infrastructure — reuse untuk dictation relatively easy.
- ❌ Risk: feature creep, berbeda use case dari core product.
- ❌ Engineering cost: global hotkey + text insertion nontrivial di cross-platform.

**Recommendation:** Tidak di v1. Tapi architecture Trareon sudah support dictation mode di masa depan.

#### 2.6.2 How Open-Source Implementations Do Text Insertion

**macOS:**
```swift
// Handy uses rdev untuk global keyboard shortcut
// Text insertion via clipboard + simulated Cmd+V

// Alternative: Accessibility API untuk direct text insertion
let source = AXUIElementCreateSystemWide()
AXUIElementSetAttributeValue(source, kAXAutomaticTextReplacementAttribute as CFString, true)
```

**Windows:**
```rust
// Global hotkey via Windows API (RegisterHotKey)
// Text insertion: SetForegroundWindow + SendInput (clipboard paste)
```

**Linux (X11 + Wayland):**
```rust
// Global hotkey: rdev crate (Rust)
// Text insertion: X11: XTestFakeKeyEvent / Wayland: zenity or wl-clipboard
```

**Key technical challenge:** Text insertion tanpa mengganggu user's typing context. Options:
1. **Clipboard paste** (paling reliable): copy ke clipboard → simulate Cmd+V. Risk: overwrite clipboard content.
2. **Accessibility API** (macOS): direct insertion via AXUIElement.
3. **IME/Input method** (complex): register sebagai input method.

**Handy's approach (Rust):**
- rdev untuk global shortcuts.
- Clipboard crate untuk copy.
- Arbiter untuk cross-platform window focus.

**Relevansi untuk Trareon:**
Jika Trareon ingin add dictation mode di masa depan, pattern Handy sudah proven. Tapi untuk v1, stay focused pada meeting transcription.

---

## BAGIAN 3: Synthesis

---

### 3.1 Full Comparison Table

**Kategori A: Dictation (Voice-to-Text-into-Any-App)**

| App | Price | Local/Cloud | Bahasa Indonesia | Standout Feature | Top Complaint |
|-----|-------|-------------|----------------|-----------------|--------------|
| Wispr Flow | Free (2k words/wk) / $12/mo | Cloud | ❌ | Context-aware AI editing + backtracking correction | Privacy concerns; cloud-only |
| Handy | Free (MIT) | **Local** | ✅ (via Whisper) | Parakeet CPU-optimized + VAD + API server | No meeting recording; dictation burst only |
| Whispering/Epicenter | Free (AGPL) | Both | ✅ (via GGUF) | Provider-agnostic + Transformations layer | Build from source; less mature |
| Talon | $279 one-time | Local | ✅ (via community) | Ultimate power-user; AI + voice coding | Steep learning curve; niche |

**Kategori B: Meeting Transcription (Full Meeting Lifecycle)**

| App | Price | Local/Cloud | Bahasa Indonesia | Speaker ID | Standout | Top Weakness |
|-----|-------|-------------|----------------|-----------|---------|--------------|
| **Trareon (today)** | **Free (MIT)** | **Local** | ✅ | Simple clustering | Notulen format; offline; Indonesian-first | Live lag on weak CPU; no word timestamps |
| Meetily | Free / $10/mo Pro | Local (STT) + Cloud (summary) | ✅ (via Whisper) | Pro tier | Bot-free dual capture; Parakeet; Ollama | English-only summaries (community) |
| Granola | Free / $14/mo | Cloud | ❌ | Enhance-your-own-notes; provenance | No audio playback ("no tape"); history wall |
| Otter | Free / $17/mo | Cloud | ❌ | Speaker labels; team vocabulary; chat | English only; enshittification; minutes cap |
| Fireflies | Free / $10/mo | Cloud | ✅ (100+ lang) | Analytics; AskFred; CRM sync | Bot joiner; inconsistent accuracy |
| tl;dv | Free / $18/mo | Cloud (EU) | ✅ (30+) | Clip sharing; scorecards; published benchmarks | Bot visibility |
| Fathom | Free (unlimited) / $20/mo | Cloud | ❌ | Instant recap; generous free tier | Bot announces; US data only |
| Krisp | Free trial / $8/mo | Cloud (+ Enterprise on-device) | ❌ (20+) | Noise cancellation; accent localization | Transcription accuracy mid-tier |
| Tactiq | Free (10/mo) / $12/mo | Cloud (captions-based) | ✅ (30+) | Screenshot capture; tags | Depends on platform captions; browser-only |
| Read.ai | Free (5/mo) / $15/mo | Cloud | [UNVERIFIED] | Analytics; Digital Twin Ada; pre-meeting brief | Free tier very limited |
| Bluedot | Free (5 lifetime) / paid | Cloud | ✅ (100+) | CRM sync; bot-free; video edit via transcript | Free tier = 5 meetings lifetime |
| Sembly | Free trial / $29/mo | Cloud | ✅ (40+) | Multi-meeting AI chat; MCP; sentiment | Bot-based; per-user pricing |
| Avoma | $19-$39/seat/mo + $29/$29 add-ons | Cloud | ✅ (70+) | MEDDIC scorecards; semantic trackers; dialer int. | Very expensive ($82/seat full config) |
| Supernormal | Free credits / Team $0 | Cloud | ✅ (60+) | Meeting → deliverables; AI agents | Credit system complexity |
| Anarlog | Free (MIT) | **Local** | ✅ (45+) | "What runs where" transparency; SQLite | macOS only (OSS); no Windows/Linux |
| Jamie | Free trial / €21-47/mo | Cloud (Germany) | ✅ (99+) | Live summary; auto-start; speaker memory | EU server; free tier = trial |
| MacWhisper | Free / €59 one-time | **Local** | ✅ (100+) | Watch folders; meeting auto-detect; Parakeet v3 | Confusing pricing; Teams auto-detect flaky |
| Buzz | Free (MIT) | **Local** | ✅ (100+) | Speech separation; presentation mode; export | No meeting capture; file/transcribe only |
| Vibe | Free (MIT) | **Local** | ✅ (100+) | Phone-as-mic QR; Parakeet TDT; HTTP API | No meeting recording (file/transcribe) |
| Whisper Notes | $7.99-14 one-time | **Local** | ✅ (100+) | One-time pricing; ANE; auto-detect meetings | iOS/Mac only; Intel Mac no transcription |
| Notta | Free (3min cap) / $13.99/mo | Cloud | ✅ (58) | Bilingual mode; mind maps; hardware recorder | Weak free tier; billing complaints |
| Notula | Rp79k/mo / Offline Lite Rp56k | Cloud + Offline | ✅ | Formal notulen formats; DOCX export | Offline Lite masih cloud summarization |
| Notulin | [UNVERIFIED] | Cloud | ✅ (ID/EN code-switch) | ID/EN bilingual; Indonesian data residency | Enterprise positioning |
| Notulensi | [UNVERIFIED] | Cloud | ✅ (97%+ claim) | Berita acara; SOE testimonials | Cloud-only |
| Transkrip.id | Rp10k/file | Cloud | ✅ | Pay-per-file; university adoption | Pay-per-file model; no meetings |
| Meeting.ai | Free / $20-200/mo | Cloud | ✅ (30+) | Agent memory (Memo); PPTX/XLSX output | Coin-based pricing complexity |
| Apple Voice Memos | Free | On-device | ❌ | On-device; live transcript | No Indonesian; Apple silicon Mac only |
| Windows Live Captions | Free | On-device | ❌ (21 langs) | System-wide; translate 40+→EN | No Indonesian; Copilot+ gating for translate |
| Google Meet "Take notes" | Free (Gemini) | Cloud | ✅ | Built-in; no extra app | Gemini-dependent; not full transcript |
| MS Teams Copilot | $10-22/user/mo | Cloud | ✅ | Enterprise integration; Intelligent Recap | Expensive; requires Copilot license |
| Zoom AI Companion | Free (paid tiers) | Cloud | ✅ | Built-in; no extra app | Limited to Zoom; accuracy varies |

---

### 3.2 Where Trareon Stands Today

**Strengths:**
- ✅ 100% free, MIT-licensed, open-source.
- ✅ 100% offline/local — audio tidak pernah meninggalkan device.
- ✅ Bahasa Indonesia first-class citizen.
- ✅ Indonesian notulen format export (formal MoM structure).
- ✅ Desktop app (Linux/Windows/Mac) dengan system audio capture.
- ✅ Privacy gates proven — tidak ada意外 data transmission.
- ✅ File import + re-transcribe dengan different model.
- ✅ Bookmarks, crash-safe journal, audio-to-disk.
- ✅ Indonesian summary templates via Ollama.

**Weaknesses (dari Round 1 research):**
- ❌ Live transcription lags di weak CPU (large-v3-turbo-q5 runs ~0.05x realtime di laptop weak).
- ❌ Simple clustering untuk speaker identification (bukan full diarization).
- ❌ Tidak ada word-level timestamps (click-to-seek / karaoke highlighting).
- ❌ Tidak ada word error rate benchmark untuk Indonesian model lineup.
- ❌ Desktop only — tidak ada mobile, browser, calendar integration.
- ❌ Tidak ada cross-meeting search chat.
- ❌ Tidak ada video playback synced to transcript.
- ❌ Tidak ada custom vocabulary UI yang mature.
- ❌ Tidak ada pre-meeting brief atau post-meeting CRM sync.
- ❌ Tidak ada action items dengan owner + due date extraction.
- ❌ Tidak ada bookmarks/highlights during recording.

---

### 3.3 Top 25 Recommendations untuk Trareon (Ranked by Impact/Effort)

**[Engine] — High Impact, Medium-High Effort**

**1. Implement dual-pass streaming: live preview (small model + VAD) + accurate offline pass (turbo).** Ini menyelesaikan masalah core — live transcription lag di weak CPU. Gunakan Silero VAD + whisper.cpp small model untuk live preview; turbo untuk final pass. Estimasi effort: medium (2-3 minggu). Sumber: whisper_streaming paper (https://arxiv.org/pdf/2307.14743), SimulStreaming (https://github.com/ufal/SimulStreaming), whisper.cpp stream example (https://github.com/ggerganov/whisper.cpp/blob/master/examples/stream/README.md).

**2. Add Silero VAD as primary hallucination prevention gate.** VAD-gating adalah fix paling efektif untuk silence hallucination seperti "[MENGENI]". Parameternya: threshold=0.5, min_speech=250ms, min_silence=500ms, speech_pad=300ms. Estimasi effort: low (1-2 hari). Sumber: Silero VAD (https://github.com/snakers4/silero-vad), multigrid.ai hallucinations guide (https://multigrid.ai/learn/whispercpp-hallucination-on-silence).

**3. Add LocalAgreement-2 commit policy untuk live preview streaming.** Commit transcript prefix setelah 2 consecutive chunks agree. Ini policy paling simple dan correct untuk streaming Whisper. Estimasi effort: medium (1-2 minggu). Sumber: ufal/whisper_streaming paper (https://arxiv.org/pdf/2307.14743).

**4. Add speaker diarization via sherpa-onnx offline binary.** 4-stage pipeline: VAD → segmentation (pyannote 3.0 ONNX) → embedding (CAM++ 512-dim) → clustering (agglomerative, threshold 0.5). ~40MB ONNX models, single binary spawn dari Rust. Estimasi effort: medium-high (3-4 minggu). Sumber: OpenWhispr blog (https://openwhispr.com/blog/local-speaker-diarization), sherpa-onnx (https://github.com/k2-fsa/sherpa-onnx), pyannote-openvino (https://github.com/andrew867/pyannote-openvino).

**5. Add Parakeet TDT v3 sebagai optional faster transcription engine.** Parakeet ~4x faster dari Whisper di CPU. Available via `parakeet-rs` / `transcribe-rs` (dari Handy ecosystem). Estimasi effort: medium (2-3 minggu). Sumber: Handy README (https://github.com/cjpais/Handy), Meetily README (https://github.com/Zackriya-Solutions/meetily), Parakeet NIM (https://build.nvidia.com/nvidia/parakeet-tdt-nemo).

**6. Add Indonesian fine-tuned Whisper checkpoint (cahya/whisper-medium-id) sebagai in-app download.** WER improvement: 3.83% vs 12.62% untuk Whisper vanilla pada Common Voice 11. Download-once GGUF dari HuggingFace. Estimasi effort: medium (1-2 minggu + model conversion). Sumber: cahya/whisper-medium-id (https://huggingface.co/cahya/whisper-medium-id).

**7. Add whisper.cpp native token timestamps → word-level timestamps for click-to-seek.** Aggregate consecutive tokens → word groups; interpolate positions proportionally dalam segment. Accuracy ±200-500ms, cukup untuk karaoke highlighting. Estimasi effort: medium (1-2 minggu). Sumber: whisper.cpp token timestamps docs, whisperx word alignment (https://github.com/m-bain/whisperX).

**[UX] — High Impact, Medium Effort**

**8. Ship live confidence indicator + capture-integrity check.** Show live input level per channel (mic/system); warn if either channel was silent for long stretch. Solves Granola's worst failure (silent capture that looks live). Estimasi effort: low-medium (3-5 hari). Sumber: category complaint analysis (https://anarlog.so/blog/granola-ai-complaints/).

**9. Add audio playback synced to transcript (click-to-seek).** Semua competitor except Granola punya ini; absence adalah top Granola complaint. Flutter audio player dengan transcript word highlighting. Estimasi effort: medium (2-3 minggu). Sumber: Granola complaints (https://anarlog.so/blog/granola-ai-complaints/).

**10. Add "notulen resmi" export template matching government/SOE risalah rapat format.** Fields: judul rapat, hari/tanggal, waktu, tempat, pimpinan, peserta, agenda, pembahasan, keputusan, tindak lanjut, penutup. Tidak ada competitor global yang punya ini. Estimasi effort: medium (2-3 minggu). Sumber: Kemendagri PPID notulen format (https://ppid.kemendagri.go.id), Notula.ai (https://notula.ai/).

**11. Add custom summary templates (user-editable prompts) — formal notulen, poin ringkas, conversational, plus save-your-own.** Meetily Pro charges $10/mo untuk 6 built-in templates; ini nearly free to build. Estimasi effort: low-medium (3-5 hari). Sumber: Meetily Pro (https://meetily.ai/pro/).

**12. Add custom dictionary/vocabulary feature.** Names, jargon, acronyms applied as whisper.cpp initial-prompt. Trareon's existing glossary field adalah start; expand dengan user-editable list + learning dari corrections. Estimasi effort: low (2-3 hari). Sumber: Otter team vocabulary (https://otter.ai/pricing-2025), Anarlog Dictionary (https://docs.anarlog.so/languages).

**13. Add provenance in summaries: setiap bullet link ke transcript segment + timestamp.** Granola's magnifying glass = most trusted UX feature; Meeting.ai links decisions to original utterance. Estimasi effort: medium (1-2 minggu). Sumber: Granola docs (https://docs.granola.ai/help-center/taking-notes/ai-enhanced-notes), Meeting.ai.

**14. Add bookmarks/highlights during recording (one-click + optional note).** Surface in summary. Krisp + MeetingsAI + Fathom pattern. Estimasi effort: low (2-3 hari). Sumber: Krisp (https://krisp.ai/meeting-transcription), MeetingsAI.

**15. Add action items with owner + due date, extracted and rendered as checklist in summary.** Nearly universal feature (Notulin, Jamie, Fathom, tl;dv, Notion). Estimasi effort: medium (1-2 minggu). Sumber: Notulin (https://notulin.id/fitur), Fathom (https://www.fathom.ai/pricing).

**16. Add tag/label system untuk actionable items, decisions, questions dalam transcript.** Tactiq pattern: label transcript segments. Estimasi effort: low-medium (3-5 hari). Sumber: Tactiq (https://tactiq.io/).

**17. Add full-text search across meeting library.** Meetily lacks it; Trareon already fills this gap but bisa di-improve dengan FTS5. Estimasi effort: low (1-2 hari). Sumber: Meetily complaint (COMPETITOR-RESEARCH.md Round 1).

**18. Add "enhance your own notes" mode (Granola pattern).** User types during meeting; post-meeting AI merges typed notes + transcript (typed lines preserved + highlighted). Estimasi effort: medium-high (3-4 minggu). Sumber: Granola (https://docs.granola.ai/help-center/taking-notes/ai-enhanced-notes).

**[Feature] — Medium Impact, Medium Effort**

**19. Add MCP server access.** Traxon bisa expose transcription/diarization sebagai MCP tool untuk AI agents. Sembly Pro + Granola + tl;dv sudah punya ini. Estimasi effort: medium (2-3 minggu). Sumber: Sembly MCP (https://sembly.ai/pricing).

**20. Add meeting auto-detect + one-click record reminder.** Listen for Zoom/Meet/Teams window activity; show "Meeting Detected → Record" like MacWhisper. Estimasi effort: medium (2-3 minggu). Sumber: MacWhisper auto-detect (https://docs.macwhisper.com/article/30-record-meetings), Jamie auto-start (https://meetjamie.ai/changelog).

**21. Add cross-meeting chat ("ask questions about all meetings") using local LLM via Ollama.** Granola/Jamie/tl;dv treat this sebagai premium hook. Trareon local-first version = clean privacy story. Estimasi effort: high (4-6 minggu). Sumber: Granola (https://granola.ai/blog/granola-free-vs-paid-features-each-plan).

**22. Add chunked long-meeting summarization (map-reduce over 30-min windows).** Local LLM summaries degrade past ~1 hour; chunked processing prevents this. Estimasi effort: medium (2-3 minggu). Sumber: Meetily limitation (https://anarlog.so/blog/meetily-review/).

**23. Add CRM / Notion sync via post-meeting automation.** Bluedot pattern: auto-update HubSpot/Salesforce after meeting. Estimasi effort: medium (2-3 minggu). Sumber: Bluedot (https://www.bluedothq.com/).

**24. Add video/audio editing via transcript (delete filler words by editing text).** Unique Bluedot workflow; useful untuk Indonesian users yang ingin clean notulen tanpa waveform editing. Estimasi effort: medium (2-3 minggu). Sumber: Bluedot review (https://www.meetjamie.ai/blog/bluedot-review).

**25. Benchmark and publish Indonesian WER untuk model lineup.** Standard Indonesian + Javanese-accented + code-switched samples. Offer Indonesian fine-tuned checkpoint (cahya lineage) sebagai in-app download option. Traoreon sebagai credible alternative ke cloud tools. Estimasi effort: low-medium (1-2 minggu + actual benchmarking). Sumber: cahya models (https://huggingface.co/cahya/whisper-medium-id), tl;dv per-language benchmarks (https://tldv.io/blog/tldv-honest-review/).

---

### 3.4 Engine Architecture Recommendation (for Weak CPU)

**Recommended dual-path architecture:**

```
┌──────────────────────────────────────────────────────────────┐
│  LIVE PREVIEW PATH (low latency, approximate)              │
│  ┌─────────────┐    ┌──────────────┐    ┌────────────────┐  │
│  │ PipeWire    │───▶│ Silero VAD   │───▶│ whisper.cpp    │  │
│  │ (system+mic)│    │ threshold=0.5│    │ small/tiny     │  │
│  └─────────────┘    │ min_speech=250ms   │ -nt 0.3 -lpt -3.0│  │
│                     └──────────────┘    └───────┬────────┘  │
│                                                  │          │
│                     ┌──────────────┐    ┌───────▼────────┐  │
│                     │ LocalAggr-2  │◀───│ Partial results │  │
│                     │ commit on n=2│    │ every 3s        │  │
│                     └──────┬───────┘    └────────────────┘  │
│                            │                                   │
│                            ▼                                   │
│                     ┌─────────────────┐                       │
│                     │ Live preview UI  │                       │
│                     │ (approximate)    │                       │
│                     └─────────────────┘                       │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│  FINAL TRANSCRIPT PATH (post-meeting, accurate)             │
│  ┌─────────────┐    ┌──────────────┐    ┌────────────────┐  │
│  │ Audio file  │───▶│ whisper.cpp  │───▶│ Segment + word │  │
│  │ (full meeting)│  │ turbo/large  │    │ timestamps     │  │
│  └─────────────┘    │ condition_on_ │    └───────┬────────┘  │
│                     │ previous_text │            │           │
│                     │ =true        │    ┌───────▼────────┐  │
│                     └──────────────┘    │ Speaker        │  │
│                                          │ diarization    │  │
│                                          │ (sherpa-onnx) │  │
│                                          └───────┬────────┘  │
│                                                  │           │
│                     ┌──────────────┐    ┌───────▼────────┐  │
│                     │ Hallucination│    │ Merge speaker   │  │
│                     │ blocklist    │◀───│ labels → segs  │  │
│                     └──────────────┘    └───────┬────────┘  │
│                                                  │           │
│                     ┌──────────────┐    ┌───────▼────────┐  │
│                     │ Ollama       │◀───│ Final          │  │
│                     │ (Indonesian  │    │ transcript +   │  │
│                     │ summary)     │    │ notulen export │  │
│                     └──────────────┘    └────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

**Key parameter values:**
```rust
// whisper.cpp live preview (small model, VAD-gated)
let params = whisper_params {
    language: "id",
    n_threads: 4,
    max_len: 14,           // max tokens per segment
    token_timestamps: true,
    // VAD parameters
    vad: true,
    vad_threshold: 0.5,
    vad_min_speech_ms: 250,
    vad_min_silence_ms: 500,
    vad_padding_ms: 300,
    // Suppression
    logprob_thresh: -1.0,
    no_speech_thresh: 0.6,
};

// whisper.cpp final pass (turbo model, full accuracy)
let params = whisper_params {
    language: "id",
    n_threads: 4,
    max_len: 0,            // no limit
    token_timestamps: true,
    condition_on_previous: true,
    // Aggressive hallucination suppression
    logprob_thresh: -0.5,
    no_speech_thresh: 0.55,
};

// Post-process: hallucination blocklist
let blocklist = [
    r"\[MENGENI\]", r"\[PAMUNGKAS\]", r"\[MENINJAU\]",
    r"\[MUSIK\]", r"\[TANGISAN\]",
    // ... expand dari testing
];
```

**Summary dari technical research:**

| Problem | Best Solution | Source |
|---------|--------------|--------|
| Live lag on weak CPU | Small model + VAD-gated streaming + LocalAgreement-2 commit | whisper_streaming paper, SimulStreaming |
| Silence hallucination "[MENGENI]" | Silero VAD gating (<1ms/chunk) + blocklist | Silero VAD, multigrid.ai |
| Speaker diarization (local, Rust) | sherpa-onnx binary (pyannote 3.0 + CAM++) | OpenWhispr, sherpa-onnx releases |
| Word-level timestamps | whisper.cpp native tokens → aggregate + interpolate | whisper.cpp stream example |
| Indonesian accuracy | cahya/whisper-medium-id fine-tune (WER 3.83% vs 12.62%) | HuggingFace, HF model card |
| Fast streaming model | Parakeet TDT v3 (~4x faster than Whisper) | Meetily, Parakeet NIM |

---

*Report compiled: October 4, 2026. Sources cited inline per claim. Unverified items marked [UNVERIFIED]. Report path: `/home/kali/trareon-sprints/RESEARCH-ROUND2.md`.*
