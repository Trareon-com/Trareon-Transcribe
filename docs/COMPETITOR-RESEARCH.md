# Competitive Research: AI Meeting Transcription / Note-Taker Apps (2025–2026)
### For Trareon Transcribe — open-source, local-first, Indonesian-first desktop transcriber (Flutter + Rust, whisper.cpp)

Research date: September 30, 2026. Sources: official sites, docs, pricing pages, GitHub READMEs, changelogs, Hacker News, Reddit threads, third-party reviews. Unverified items are explicitly marked. Note: product names change fast in this space (hyprnote → Char → Anarlog; transkrip.xyz → transkrip.com by Meeting.ai); claims below reflect the sources listed.

---

## 1. Per-competitor profiles

### 1.1 Meetily (Zackriya-Solutions/meetily) — closest direct competitor
- **Pricing:** Community edition free, MIT-licensed, no account required. Pro at $10/user/month billed annually (regular $25/mo; launch coupon LAUNCH20 = 20% off). Enterprise custom, self-hosted, with SSO/SAML, RBAC, audit logging. Sources: https://github.com/Zackriya-Solutions/meetily (README, 25.7k stars), https://meetily.ai/pro/, https://anarlog.so/blog/meetily-review/
- **Local vs cloud:** 100% local transcription (whisper.cpp and NVIDIA Parakeet ONNX, GPU via Metal/CUDA/Vulkan). Summaries via Ollama (local) by default, or BYOK cloud (Claude, OpenAI-compatible, Gemini, Mistral, Groq, OpenRouter, Azure) — "only transcript text is ever sent off-device." Built as Tauri app: Rust backend + Next.js frontend; local SQLite storage. Sources: https://github.com/Zackriya-Solutions/meetily, https://meetily.ai/pro/, https://everydev.ai/tools/meetily
- **Key features:** live transcription (Parakeet ~4x faster than Whisper per README), system audio + mic capture (bot-free, works with Zoom/Meet/Teams/Discord/anything), audio file import (10 formats) + re-transcribe with another model (v0.3.0), Ollama/BYOK summaries, Markdown export in community; Pro adds speaker identification/diarization (on-device), auto-meeting detection, custom summary templates (6 built-in), PDF/DOCX/MD exports, Windows GPU acceleration. Sources: README above, https://meetily.ai/pro/, https://everydev.ai/tools/meetily, https://genztech.blog/p/meetily-local-ai-meeting-notes-setup
- **Standout UI/UX:** one-click installers (v0.4.0, June 2026); provider-configuration UI that lets users consciously choose where data flows (local vs hosted vs BYOK — a "privacy posture" picker); no account needed on community edition. Sources: https://genztech.blog/p/meetily-local-ai-meeting-notes-setup, https://meetily.ai/docs/features/provider-configuration
- **Top complaints:** messy transcripts with wrong speaker labels in multi-person crosstalk meetings (https://www.reddit.com/r/LocalLLM/comments/1uot74o/meetily_review_2026_privacyfirst_ai_meeting/); summary quality drops on hour-long/multi-topic meetings with local LLMs; no calendar integration on free tier; no search across meetings; no mobile app; AI summaries were English-only on community edition (unverified if still true in v0.4/Pro); Linux requires building from source. Sources: https://anarlog.so/blog/meetily-review/

### 1.2 Granola (granola.ai) — category design leader
- **Pricing:** Basic free (AI notes, limited meeting history — notes older than 30 days are stored but not viewable), Business $14/user/mo, Enterprise $35/user/mo. Sources: https://www.granola.ai/pricing, https://granola.ai/blog/granola-free-vs-paid-features-each-plan
- **Local vs cloud:** cloud. Records device audio (no bot), transcribes with managed providers, audio deleted after transcription, never stored. Data residency US AWS; not HIPAA; anonymized data may be used for model training unless opted out. Sources: https://docs.granola.ai/help-center/taking-notes/transcription, https://anarlog.so/blog/granola-ai-complaints/
- **Key features:** the "enhance your own notes" model — you jot rough notes during the meeting, Granola combines them with the transcript and calendar context into structured notes; magnifying-glass provenance on every enhanced bullet (trace which transcript line it came from); Granola Chat (Ctrl/Cmd+J) across one or all meetings; 29+ "Recipes" (saved post-meeting prompts: follow-up emails, PRDs, coaching feedback); pre-meeting "Brief" prep from past meetings + calendar; People & Companies view; shared folders; custom templates; MCP server; multi-language mode (31 desktop languages — but **Indonesian is NOT among them**). Sources: https://docs.granola.ai/help-center/taking-notes/ai-enhanced-notes, https://granola.ai/blog/granola-free-vs-paid-features-each-plan, https://docs.granola.ai/help-center/customising-granola/multi-language, https://www.granola.ai/
- **Standout UI/UX:** notepad-first (your own typing is the primary artifact, transcript is the raw material); raw notes shown highlighted in black within enhanced notes; provenance drill-down per bullet; template picker with regenerate; calendar-synced Brief before each meeting. Windows app shipped June 2025. Sources: https://docs.granola.ai/help-center/taking-notes/ai-enhanced-notes, https://www.granola.ai/updates
- **Top complaints:** names mangled; sessions that look live but capture nothing (no audio stored → nothing to re-transcribe, no file import); no audio playback/verification ("no tape"); free-plan 30-day history wall ("hostage window"); consent concerns (participants don't see it recording; class-action *Chamberlain v. Granola* — https://storage.courtlistener.com/recap/gov.uscourts.cand.475308/gov.uscourts.cand.475308.1.0.pdf); Indonesian not supported at all. Sources: https://anarlog.so/blog/granola-ai-complaints/, https://saasflags.com/products/granola-ai

### 1.3 Otter.ai
- **Pricing:** Basic free (300 monthly transcription minutes, 3 lifetime file imports, 25-conversation history, 20 AI Chat queries/mo); Pro $16.99/mo ($8.33 annual); Business $30/mo ($19.99 annual); Enterprise custom. Sources: https://otter.ai/pricing, https://otter.ai/pricing-2025
- **Local vs cloud:** cloud, with a visible meeting bot for Zoom/Meet/Teams auto-join.
- **Key features:** live transcription + collaborative notes, speaker identification (taggable speakers), team vocabulary (custom terms per team), AI Chat across meetings, meeting templates, Zapier/Salesforce/HubSpot integrations, video replay, Otter API/webhooks, MCP server, bulk export (mp3/txt/pdf/docx/srt). Sources: https://otter.ai/pricing-2025, https://otter.ai/pricing
- **Standout UI/UX:** collaborative live transcript with comments/highlights; playback synced to text; advanced search & export.
- **Top complaints:** language support is only English, Spanish, French, German, Japanese, Chinese — no Indonesian (https://help.otter.ai/hc/en-us/articles/360047247414-Supported-languages); accuracy issues with accents/overlapping speech; "enshittification" complaints — free-plan cuts, price hikes, unreliable capture (https://www.reddit.com/r/ArtificialInteligence/comments/1e5l79j/the_enshittification_of_otter/, https://www.reddit.com/r/WFH/comments/1ipelbb/any_good_alternatives_to_otterai_for_meeting/, https://www.reddit.com/r/OtterAI/comments/lke8js/rotterai_lounge/); minutes-based limits.

### 1.4 Fireflies.ai
- **Pricing:** Free (unlimited transcription*, limited AI summaries, 400 min storage/team, 20 AI credits); Pro $18/mo ($10 annual); Business $29/mo ($19 annual); Enterprise $39/mo. Sources: https://fireflies.ai/pricing
- **Local vs cloud:** cloud, bot joins meetings ("Fireflies Notetaker has joined").
- **Key features:** auto-join calendar meetings, 100+ transcription languages, searchable transcript, AskFred AI assistant across workspace, conversation intelligence (talk-time, keyword tracking, sentiment on higher tiers), CRM sync (Salesforce/HubSpot), Zapier, API, soundbites/clips, mobile apps + desktop app + Chrome extension. Sources: https://fireflies.ai/pricing, https://www.lindy.ai/blog/fireflies-ai-review
- **Standout UI/UX:** knowledge-base approach to meetings; searchable across everything; meeting analytics dashboards.
- **Top complaints:** inconsistent accuracy (accents, jargon, crosstalk); cluttered UI; generic templates; pricing opacity — hidden fees, unwanted auto-enrollments in AI credits, buried payment settings (https://meetgeek.ai/blog/fireflies-ai-pricing); bot visibility on client calls.

### 1.5 tl;dv
- **Pricing:** free plan (real, not trial; hard caps on AI use, 3-month data retention); Pro ~$18/user/mo annual; Business ~$29/mo. Sources: https://topalternatives.to/tools/tldv, https://itechguides.com/best/ai-meeting-assistants/tl-dv, https://versusref.com/notetakers/tools/tldv
- **Local vs cloud:** cloud, EU data centers, SOC 2 Type II + GDPR + EU AI Act; visible bot + desktop recording option (bot-free). Sources: https://tldv.io/blog/tldv-honest-review/
- **Key features:** auto-join Zoom/Meet/Teams; video recording with speaker-labeled transcripts; **clip sharing — timestamped clips** you can share instead of full recordings; playlists of highlights; Ask tl;dv across meetings; playbooks + AI sales coaching (MEDDIC/BANT scorecards); custom vocabulary; 30+ transcription languages with automatic detection incl. mid-call switching; MCP server; published per-language accuracy benchmarks. Sources: https://tldv.io/blog/tldv-honest-review/, https://topalternatives.to/tools/tldv
- **Standout UI/UX:** "meeting library" mental model; clip-based sharing workflow; timestamped transcript tied to video.
- **Top complaints:** free-plan caps on cross-meeting AI queries (5); sticker price creep; bot on calls. Sources: https://tldv.io/blog/tldv-honest-review/

### 1.6 Fathom
- **Pricing:** Free individual plan is the most generous in category — unlimited recordings/transcriptions/storage, instant summaries, clips, search (but advanced summaries cap at ~5 calls/month after trial); Premium $16-20/user/mo; Team $15-19; Business $25-34; Enterprise custom. Sources: https://www.fathom.ai/pricing, https://www.therundown.ai/tools/fathom, https://prospeo.io/s/fathom-pricing-reviews-pros-and-cons
- **Local vs cloud:** cloud; visible bot OR bot-free capture — but bot-free (Fathom 3.0) is Mac + English only (unverified whether still true late 2026). Sources: https://anarlog.so/blog/fathom-ai-complaints, https://help.fathom.video/en/articles/11577345
- **Key features:** 30-second summaries after calls, AI action items, playlists of highlight clips, keyword alerts, "Deal View" for CRM, AI scorecards/coaching on Business, CRM field sync, bot-free beta. Sources: https://www.fathom.ai/pricing, https://www.therundown.ai/tools/fathom
- **Standout UI/UX:** instant-recap workflow ("walk out with notes already done"); clip/highlight workflow integrated into the live meeting (mark moments live).
- **Top complaints:** bot announces itself on client calls; free AI cap after 5 calls; bot no-shows/drops on long calls with no local fallback; US data residency. Sources: https://anarlog.so/blog/fathom-ai-complaints

### 1.7 Krisp (AI Meeting Notes)
- **Pricing:** Free trial 7 days; Core $8/user/mo annual ($16 monthly); Advanced $15/mo annual ($30 monthly); Enterprise adds **on-device private transcription**. Sources: https://krisp.ai/pricing/
- **Local vs cloud:** noise cancellation runs 100% on-device; transcription/summaries cloud by default, on-device on Enterprise. Sources: https://krisp.ai/pricing/, https://meetingpick.com/reviews/krisp-review-2026
- **Key features:** best-in-class bi-directional noise cancellation (system-wide virtual mic/speaker), bot-free real-time transcription with speaker diarization, one-click highlight during meeting, structured summaries (decisions/action items), accent localization (unique), in-person meeting notes, 17+ languages for transcription. Sources: https://krisp.ai/meeting-transcription, https://meetingpick.com/reviews/krisp-review-2026
- **Standout UI/UX:** live sidebar transcript beside the call; one-click highlight; audio-quality-first positioning (notes are better because audio is clean).
- **Top complaints:** transcription accuracy behind Otter/Fireflies (accents, jargon, crosstalk); 60 min/day free cap; no video; CRM sync slower (post-meeting upload). Sources: https://meetingpick.com/reviews/krisp-review-2026

### 1.8 Notion AI Meeting Notes
- **Pricing:** not standalone — needs Notion Business ($20/user/mo annual) or Enterprise. Sources: https://www.eesel.ai/blog/notion-ai-meeting-notes, https://www.notion.com/help/ai-meeting-notes
- **Local vs cloud:** cloud. `/meet` block inside any Notion page; desktop app captures system audio + mic.
- **Key features:** live transcript inside a Notion page, summary formats (Auto/Sales Call/Team Meeting), key takeaways + action items, drag action items into Notion task databases with assignees/due dates, @mentions, calendar integration, also transcribes arbitrary system audio (YouTube, podcasts). Sources: https://www.notion.com/help/ai-meeting-notes, https://www.eesel.ai/blog/notion-ai-meeting-notes
- **Standout UI/UX:** notes live where work lives — transcript → action item → task database in one motion.
- **Top complaints:** **no speaker identification** — one continuous text block, who-said-what missing (per eesel review; unverified whether fixed by 2026); desktop-only; mobile can't capture other participants through headphones; requires Business plan. Sources: https://www.eesel.ai/blog/notion-ai-meeting-notes, https://www.notion.com/help/ai-meeting-notes

### 1.9 Jamie (meetjamie.ai)
- **Pricing:** Free trial-grade (10 notes/mo, 30-min cap); Plus ~€21-24/mo (20 AI notes/mo); Pro ~€39-47/mo (unlimited notes, 5-hr meetings, CRM sync, API/webhooks/MCP); Executive ~€99/mo; Team €33/seat. Sources: https://rightaichoice.com/tools/jamie, https://tomba.io/blog/jamie-pricing-reviews-pros-and-cons, https://itechguides.com/best/ai-meeting-assistants/jamie
- **Local vs cloud:** desktop capture, no bot; audio processed on servers in Germany then permanently deleted; EU data residency; ISO 27001, GDPR, DORA-aligned. Sources: https://www.meetjamie.ai/security, https://www.meetjamie.ai/blog/llm-info
- **Key features:** bot-free capture across Zoom/Teams/Meet + in-person; 99+ note languages; Executive Assistant sidebar (Ctrl+J) that remembers everything from past meetings; context-enriched pre-meeting briefings; custom + shared team templates; live summary streaming during the meeting; auto-start recording with cancellable countdown + AutoStop when silence; speaker recognition with **memory across recurring meetings**; workflows pushing notes/tasks into Salesforce/HubSpot/Pipedrive/Asana/Notion; MCP server. Sources: https://www.meetjamie.ai/, https://rightaichoice.com/tools/jamie, https://meetjamie.ai/changelog
- **Standout UI/UX:** meeting "memory" chat; auto-start/countdown recording UX; live streaming summaries.
- **Top complaints:** free tier is a trial; metered meetings push users to Pro; consent is entirely the user's problem (nothing announces capture); needs your own device present and awake. Sources: https://rightaichoice.com/tools/jamie, https://tomba.io/blog/jamie-pricing-reviews-pros-and-cons

### 1.10 Hyprnote → Char → Anarlog (fastrepl) — open-source local lineage
- **Naming note:** hyprnote (YC S25, HN launch July 2025) was renamed Char, then the meeting-notetaker product was relicensed **GPL → MIT and renamed Anarlog** (May 2026) — free forever, no paid tier planned; the team's new product is "Char" (agentic todo notepad). Sources: https://news.ycombinator.com/item?id=44725306, https://anarlog.so/blog/char-is-now-anarlog, https://github.com/fastrepl/anarlog (9.2k stars)
- **Pricing:** Anarlog free (BYOK, on-device transcription, all core features); legacy Pro $15/mo for hosted transcription/cloud sync/calendar integrations. Community edition MIT. Source: https://anarlog.so/blog/char-is-now-anarlog, https://anarlog.so/blog/local-ai-meeting-notes
- **Local vs cloud:** local-first by design — sessions, notes, transcripts in **local SQLite**; recordings/attachments plain files; on-device transcription on supported Macs; local Intelligence providers for summaries/chat (Ollama, LM Studio); cloud sync/sharing strictly opt-in; Markdown export. macOS only (no Linux/Windows planned for the OSS app). Sources: https://github.com/fastrepl/anarlog, https://anarlog.so/blog/char-is-now-anarlog
- **Key features:** bot-free system audio capture (no calendar permissions), "Granola rearranged" note flow (type during meeting, AI merges your notes + transcript after), BYOK/local models, 45+ languages via swappable STT provider, Settings → Dictionary for names/jargon, separate summary-language vs spoken-languages settings. Sources: https://github.com/fastrepl/anarlog, https://docs.anarlog.so/languages, https://anarlog.so/blog/local-ai-meeting-notes
- **Standout UI/UX:** "VSCode for meeting notes" positioning; explicit "What runs where" table in README showing which components are local vs cloud — best-in-class transparency pattern.
- **Known issues:** hyprnote's HN launch exposed that its speaker diarization was advertised before it worked (entire 30-min/20-person meeting landed under one speaker) — a cautionary tale about overpromising diarization. Sources: https://news.ycombinator.com/item?id=44725306

### 1.11 Superwhisper
- **Pricing:** Free (unlimited dictation, local Whisper, custom vocabulary, 2 modes) / Pro $8.49/mo, $84.99/yr, $249.99 lifetime. Source: https://superwhisper.com/docs/billing/plans
- **Positioning:** system-wide AI dictation (voice-to-text anywhere), not a meeting tool — but Pro adds system audio recording, speaker separation, realtime transcription, context awareness, BYOK. Local Whisper models free.
- **Relevance:** the hold-hotkey-speak-anywhere pattern, custom vocabulary, and text replacements are UX patterns a transcriber can borrow.

### 1.12 MacWhisper
- **Pricing:** Gumroad MacWhisper Pro €59-64 one-time (or $29.99/yr, $99.99 lifetime via App Store under the name "Whisper Transcription"); free tier is surprisingly rich (batch, YouTube URL, speaker diarization, SRT/VTT, system audio, watch folders, meeting detection, BYOK). Sources: https://medium.com/ai-tools-tips-and-news/macwhispers-pricing-is-confusing-on-purpose-here-s-what-i-actually-paid-51c39d1a18fe, https://makerstack.co/reviews/macwhisper-review
- **Local vs cloud:** 100% on-device (OpenAI Whisper + NVIDIA Parakeet); BYOK for AI cleanup only.
- **Key features:** 30x realtime transcription, **automatic meeting start/end detection** (beta — detects Zoom/Teams/Meet/etc. and reminds you to record), 50+ export formats, batch + watch folders, video sync, speaker recognition added v12 (March 2025, Parakeet v3). Sources: https://docs.macwhisper.com/article/30-record-meetings, https://makerstack.co/reviews/macwhisper-review, https://www.macwhisper.com/
- **Top complaints:** dual-storefront pricing confusion; auto-detection flaky for Teams (https://www.reddit.com/r/MacWhisper/comments/1sqsc0k/macwhisper_not_detecting_teams_meetings_correctly/).

### 1.13 Buzz (chidiwilliams/buzz, 21k+ stars)
- **Pricing:** free, MIT open-source (Buzz Classic Win/Linux/macOS-Intel); Buzz on macOS App Store paid, native.
- **Local vs cloud:** fully offline; multi-backend (Whisper, whisper.cpp, Faster-Whisper, HF models, optional OpenAI API).
- **Key features:** file + live mic transcription, translation, speaker identification, **speech separation preprocessing for noisy audio**, presentation window for live events, search + playback + inline transcript editing, watch folder, CLI, plugin system (incl. AI summary). Exports TXT/SRT/VTT/CSV. Sources: https://github.com/chidiwilliams/buzz, https://buzzcaptions.com/
- **Standout UI/UX:** transcript viewer with search/playback/speed control; keyboard shortcuts; presentation mode.

### 1.14 Vibe (thewh1teagle/vibe, 7.7k stars)
- **Pricing:** free open-source.
- **Local vs cloud:** fully offline, on-device.
- **Key features:** ~100 languages, audio/video + YouTube/Vimeo/Twitter links, batch, exports SRT/VTT/TXT/HTML/PDF/JSON/DOCX, realtime preview, Whisper + Nemotron 3.5 + Parakeet TDT v3, summaries via Claude API or **local Ollama batch summaries**, translate-to-English, print, GPU optimization (Vulkan/CoreML), CLI, HTTP API with Swagger, **speaker diarization**, stable-timestamps mode (VAD-backed), **record-from-phone via QR code (computer does the transcribing)**, custom model loading via `vibe://download/?url=`, caption-length presets. Sources: https://github.com/thewh1teagle/vibe/blob/main/README.md, https://thewh1teagle.github.io/vibe/
- **Standout UI/UX:** phone-as-mic QR pairing; realtime preview during file transcription; model freedom in settings.

### 1.15 Whisper Notes
- **Pricing:** $7.99 one-time (iPhone/iPad/Mac App Store); Mac DMG $14 one-time with 5,000 words/week free. No subscription. Source: https://whispernotes.app/
- **Local vs cloud:** 100% offline (Apple Neural Engine; Parakeet V3 default, Whisper Large V3 Turbo for 100+ languages incl. Indonesian, SenseVoice for CJK, Qwen3-ASR beta). 35-min file in ~18s (M4 Pro).
- **Key features:** on-device speaker diarization (rename once updates everywhere; manual speaker count 2-6), **auto meeting detection** on Mac (Zoom/Teams/Meet; requires screen-recording permission), system-wide hold-Fn dictation, streaming transcription output on import, lock-screen recording widget, Voice Memos share-sheet integration, 32 interface languages, on-device filler-word removal (Gemma). Sources: https://whispernotes.app/, FAQ sections of same page
- **Relevance:** proves demand for cheap one-time offline apps; excellent onboarding (no account, no cloud) and speaker-naming UX.

### 1.16 Notta
- **Pricing:** Free 120 min/mo but **3-min per recording cap**; Pro $13.99/mo ($8.17 annual, 1,800 min); Business $27.99/seat; Enterprise custom. Translation/bilingual transcription is a **paid add-on from ~$6/mo**. Sources: https://litmustools.com/review/notta, https://www.plaud.ai/blogs/articles/notta-review
- **Local vs cloud:** cloud; bot + real-time; also hardware recorder "Notta Memo" ($149).
- **Key features:** 58 transcription languages, **bilingual mode producing one transcript when two languages are spoken in the same meeting**, real-time translation 42+ languages, mind maps, built-in meeting scheduler, Notta Brain AI chat, speaker labeling, DOCX/PDF/SRT/TXT export, strong mobile apps (iOS+Android). Sources: https://www.plaud.ai/blogs/articles/notta-review, https://litmustools.com/review/notta, https://www.notta.ai/id
- **Top complaints:** generic summaries; weak free tier; billing complaints (charges after trial cancellation, slow refunds).

### 1.17 Indonesian local players
- **Notula.ai** — web platform, record/transcribe/summarize in Bahasa Indonesia, formal MoM/notulen formats, meeting bot for Zoom/Meet/Teams, Word/PDF export + shareable links. Free tier (10-min trial, 2-day retention); Lite Rp79.200/mo (1,000 min); Pro Rp144.000/mo (2,500 min, ID/EN/CN, audio upload); **Offline Lite Rp56.000/mo** (500 min, offline meetings only, full-language, DOCX); Business Rp228.000/mo (6,000 min, 1-yr retention). 20k+ active users claimed. Sources: https://notula.ai/
- **Notulensi (Widya Wicara, Yogyakarta)** — bot recorder + file upload transcription, speaker identification, summary/keypoints, PDF/DOCX export, meeting quality scoring; claims 97.2-97.4% Indonesian accuracy (Common Voice + internal benchmarks); SOC 2 Type II/GDPR/CCPA badges; used by SOE-adjacent companies (ASABRI, Jasa Raharja testimonials) for berita acara/risalah rapat. Sources: https://notulensi.id/, https://dev-notulensi.widyawicara.com/
- **Transkrip.id** — pay-per-file Rp10.000/file (unlimited duration within session), claims 95% Indonesian accuracy, 40+ languages, txt/csv/srt export; used by universities (UGM, ITB, BRIN). Sources: https://www.transkrip.id/
- **Transkrip.xyz / transkrip.com (by Meeting.ai)** — pay-per-file Rp19.900, no subscription, QRIS/e-wallet/bank payment, 2GB/6-hr files, speaker diarization shown on demo, >90% Indonesian claim. Sources: https://www.transkrip.xyz/id
- **Transkripsi.id (Widya Wicara)** — subscription ($9.99/120 min), claims 98% Indonesian accuracy from local-dataset training; publishes Indonesian-market comparisons. Source: https://transkripsi.id/blogs/5-software-transkrip-otomatis-bahasa-indonesia-paling-akurat
- **Notulin.id** — claims 96%+ accuracy for "corporate Bahasa Indonesia" retrained on Indonesian meeting corpora; **automatic ID/EN code-switching**, realtime <600ms delay, per-workspace custom vocabulary, decisions separated from discussion, action items with owner/due date, custom notulen templates, **data residency in Indonesia**, AES-256/TLS 1.3, SSO/SAML, retention control. Sources: https://notulin.id/fitur
- **Prosa.ai (Bandung)** — B2B ASR/TTS/NLU API platform, best-in-class Bahasa Indonesia ASR incl. Javanese/Sundanese accent coverage, on-premise deployment for banks/government, from ~$100/mo. Source: https://software-listing.com/tools/prosa-ai
- **Kata.ai / KataVenn** — Indonesian conversational-AI platform; KataVenn Speech-to-Text: streaming, noise handling, crosstalk detection, custom vocabulary, speaker diarization, telephony-optimized. Sources: https://kataven.ai/platform/speech-to-text, https://archive.kata.ai/products/kata-voice
- **Meeting.ai** (maker of transkrip.com) — Indonesian-market AI meeting agent (700k+ users claimed, 4.8/15k reviews): bot + browser/mobile recording + uploads/YouTube, 30+ languages, speaker ID, decisions linked to original utterance, PPTX/XLSX/PDF outputs, podcast-style audio recaps, Visual Notes (mind maps/timelines), "Memo" cross-meeting agent memory, coin-based pricing (Starter $20/mo, Pro $100/mo, Max $200/mo; regional pricing), UI in 14 languages incl. Indonesian. Sources: https://meeting.ai/id, https://meeting.ai/id/p

---

## 2. Feature matrix

Format: bulleted rows; competitor abbreviations in brackets. "—" means not found/verified.

**Capture**
- Bot joins meeting: Otter, Fireflies, tl;dv, Fathom (default), Notta, Notula, Notulensi, Meeting.ai
- Bot-free system-audio capture: Granola, Jamie, Krisp, Meetily, Anarlog, Notion, MacWhisper, Vibe, Whisper Notes
- System audio + mic dual capture: Meetily, Anarlog, Notion, Whisper Notes, Krisp, MacWhisper, Jamie
- In-person meetings: Jamie, Krisp, MeetingsAI, Notta (phone), Granola (mobile), Whisper Notes
- Meeting auto-detect / auto-start recording: Jamie (auto-start + countdown + AutoStop), MacWhisper (beta), Whisper Notes (Mac), Meetily (Pro), Krisp (calendar auto-join), Meetily Pro — Granola/Otter/Fireflies via calendar scheduling instead
- File import + re-transcribe with different model: Meetily, Vibe, Buzz, MacWhisper, Notta, Trareon (already has)
- Phone-as-recorder for desktop transcription: Vibe (QR), Jamie (iOS), MeetingsAI (watch)

**Transcription quality & language**
- Indonesian (Bahasa Indonesia) support: Meetily (via Whisper, quality varies), Vibe, Buzz, Whisper Notes, Notta, MacWhisper (Whisper models), Transkrip.id, Transkrip.com, Transkripsi.id, Notula, Notulensi, Notulin, Meeting.ai, Prosa.ai, KataVenn — **NOT**: Granola, Otter, tl;dv (unverified for tl;dv's 30+ list), Fathom bot path (38 langs, unverified if ID included), Krisp (20+ langs, unverified if ID included), Jamie (99+ langs, unverified if ID included)
- Regional dialect/accent handling (Javanese, Sundanese, Jakarta slang): Prosa.ai (the moat), Notulin (corporate ID retraining), Whisper fine-tunes (cahya/whisper-large-id on HF); global tools degrade ~30% on regional accents per https://transkripsi.id/blogs/5-software-transkrip-otomatis-bahasa-indonesia-paling-akurat
- Code-switching ID/EN in one meeting: Notulin (automatic), Notta (bilingual mode), Granola (desktop multi-language), tl;dv (mid-call switching), Anarlog (additional spoken languages setting)
- Custom vocabulary / dictionary (names, jargon): Otter (team vocabulary), Anarlog (Settings → Dictionary), Notulin (per-workspace), MacWhisper/Superwhisper (custom vocabulary), Jamie, Krisp (unverified)
- Speaker diarization, on-device: Meetily Pro, MacWhisper v12, Vibe, Buzz, Whisper Notes, Krisp, KataVenn
- Speaker naming with memory across recurring meetings: Jamie; rename-once-updates-everywhere: Whisper Notes, Meetily Pro
- Noise cancellation preprocessing: Krisp (best-in-class, on-device); Buzz (speech separation before transcription)
- Audio playback with transcript sync: Otter, Buzz, MacWhisper, Notta, tl;dv, Transkrip.id — **Granola notably lacks it** (no tape)

**Notes & summaries**
- Enhance-your-own-notes (user notes + transcript merge): Granola (invented it), Anarlog, Jamie (briefings + templates)
- Live streaming summary during meeting: Jamie (live summary streaming), Notion (live transcript)
- Summary provenance (click a bullet → see transcript source): Granola (magnifying glass); Meeting.ai (decisions linked to original utterance)
- Structured outputs (decisions vs action items with owner/due date): Notulin, Jamie, tl;dv, Fathom, Meeting.ai, Notion, Meetily templates
- Notulen format templates (formal Indonesian MoM): Notula (formal/poin/conversational), Notulin (custom notulen templates), Meeting.ai (notulen outputs), Notulensi (berita acara/risalah)
- Templates + regenerate with different template: Granola, Jamie, Notion (format picker), Meetily Pro
- Post-meeting "recipes"/saved prompts: Granola (29+ Recipes), Jamie (workflows)
- Mind maps / visual notes: Notta, Meeting.ai (Visual Notes)
- Chat with one meeting / all meetings: Granola, Otter (AI Chat), Fireflies (AskFred), Jamie (EA sidebar), tl;dv (Ask), Notta (Notta Brain), Vibe (Ollama), MeetingsAI (Cheat Mode = live cited answers during meeting)
- Cross-meeting memory that improves over time: Meeting.ai (Memo), Jamie

**Organization & retrieval**
- Full-text search across all meetings: Otter, Fireflies, tl;dv, Fathom, Jamie, Notta, Krisp, Notion — **Meetily lacks it** (gap Trareon already fills)
- Clips / highlights / soundbites: tl;dv, Fathom, Fireflies, MeetingsAI (important moments)
- Bookmarks / one-click highlight during recording: Krisp, MeetingsAI, Fathom
- Folders & calendar sync: MeetingsAI, Notion, Notta, Granola (Brief), Jamie
- Shareable links/webpages: Notula, MeetingsAI (meeting webpage), Granola (share-by-default risk), tl;dv
- Local-first storage (SQLite/files): Meetily, Anarlog, Whisper Notes, Vibe, Buzz, MacWhisper, Superwhisper
- MCP server / AI-assistant integration: Granola, tl;dv, Jamie, Otter, Fireflies; Vibe exposes HTTP API + Swagger; Buzz has CLI + plugins

**Exports & pricing model patterns**
- DOCX/PDF export: Meetily (Pro), MacWhisper (50+ formats), Notta, Notula, Notulensi, Meeting.ai; Trareon already exports 8 formats
- One-time purchase: Whisper Notes ($7.99/$14), MacWhisper (~€59), Superwhisper ($249.99), Talat ($49-99) — strong user preference vs subscriptions (see complaints sections)
- Pay-per-file (no subscription): Transkrip.id (Rp10k), Transkrip.com (Rp19.9k) — the dominant Indonesian pricing model
- Free tier as hostage (history walls, minutes, credits): Granola (30-day), Otter (25 convos), Fathom (5 AI calls), Notta (3-min cap), Fireflies (AI credits) — universally resented

---

## 3. Table stakes in 2026 (every serious app has these)
1. Bot-free system-audio + mic dual capture (Granola/Jamie/Krisp/Meetily made this the default expectation; bots now a liability).
2. Live transcript while recording (streaming, low latency).
3. AI summary within seconds of meeting end, structured into decisions / action items / questions.
4. Action items with owner + due date, extracted automatically (Notulin, Jamie, Fathom, tl;dv).
5. Speaker labels with easy renaming that propagates through the transcript (Whisper Notes pattern).
6. Audio playback synced to transcript (the ability to verify — Granola's missing "tape" is its biggest structural complaint).
7. Full-text search across the whole meeting library.
8. Rich exports: TXT, MD, DOCX, PDF, SRT/VTT at minimum (MacWhisper's 50+ formats is the ceiling).
9. Custom vocabulary / dictionary for names and jargon.
10. Multi-language transcription incl. Indonesian and code-switching; language detection per meeting.
11. Calendar awareness (at minimum: named meetings from calendar events; best: pre-meeting brief).
12. Explicit, honest data-flow disclosure — what runs locally, what goes to cloud, where things are stored (Anarlog's "What runs where" table; Meetily's provider picker).
13. Crash-safe recording and recovery of at least the audio (silent capture failure is the worst failure mode in the category — Granola complaint thread).
14. Meetings organized as a searchable library with folders/sessions, not a file dump.

## 4. Differentiating / innovative features
- **Granola: enhance-your-own-notes** — user's rough typing is the primary artifact, transcript fills context; provenance magnifying glass; regenerate with templates. (https://docs.granola.ai/help-center/taking-notes/ai-enhanced-notes)
- **Jamie: live summary streaming**, auto-start recording with cancellable countdown + AutoStop on silence, speaker memory across recurring meetings, Executive-Assistant chat over all history, MCP. (https://rightaichoice.com/tools/jamie, https://meetjamie.ai/changelog)
- **tl;dv: clip + playlist sharing**, playbooks/AI coaching scorecards (MEDDIC/BANT), published per-language accuracy benchmarks. (https://tldv.io/blog/tldv-honest-review/)
- **Krisp: on-device noise cancellation** as upstream quality multiplier; accent conversion. (https://meetingpick.com/reviews/krisp-review-2026)
- **Notion: transcript→task-database in one motion** (action items become assigned tasks natively). (https://www.eesel.ai/blog/notion-ai-meeting-notes)
- **Fathom: Deal View / CRM-centric views**; generous free tier as growth engine. (https://www.fathom.ai/pricing)
- **Notta: bilingual transcript mode** (two languages, one transcript) + mind maps + hardware recorder. (https://www.plaud.ai/blogs/articles/notta-review)
- **Meeting.ai: agent memory (Memo)** across meetings; podcast-style audio recaps; Visual Notes; PPTX/XLSX generation from meetings. (https://meeting.ai/id)
- **MeetingsAI: Cheat Mode** — detects questions asked live in the meeting and shows cited AI answers in real time. (https://www.meetingsai.app/)
- **Vibe: phone-as-mic via QR code** (computer transcribes); custom model loading via URL scheme; HTTP API with Swagger; stable-timestamps VAD mode. (https://github.com/thewh1teagle/vibe/blob/main/README.md)
- **Buzz: speech-separation preprocessing** for noisy audio; presentation window for live captioning at events. (https://github.com/chidiwilliams/buzz)
- **Anarlog: "What runs where" transparency table**; provider-swappable STT so language coverage follows the model, not the vendor's roadmap. (https://github.com/fastrepl/anarlog, https://docs.anarlog.so/languages)
- **MacWhisper: watch folders + batch** automation; meeting auto-detect reminders. (https://docs.macwhisper.com/article/30-record-meetings)
- **Whisper Notes: lock-screen recording, Voice Memos share-sheet integration, one-time pricing** as positioning. (https://whispernotes.app/)
- **Notulin: ID/EN code-switching trained on Indonesian meeting corpora; Indonesian data residency** as enterprise selling point. (https://notulin.id/fitur)

## 5. Most common pain points across the category
1. **Non-English accuracy.** Every global leader is English-first; Indonesian users get either no support (Granola, Otter) or degraded accuracy. Regional accents (Javanese/Sundanese/Jakarta slang) cut accuracy up to ~30% on generic models; Whisper large-v3 ~91% on standard Indonesian, ~75% on local varieties per IEEE-cited research (https://transkripsi.id/blogs/5-software-transkrip-otomatis-bahasa-indonesia-paling-akurat). Fine-tuned Indonesian Whisper models exist publicly (https://huggingface.co/cahya/whisper-large-id).
2. **Speaker ID errors.** Diarization under crosstalk is unsolved everywhere (Meetily Reddit review; hyprnote's failed HN launch; Krisp "struggles with overlapping speakers"; Granola collapses 3-person calls into "Them"). Overpromising it destroys trust — ship it only when it works.
3. **Bots joining meetings.** The single most-cited social friction (Fathom "announces itself," Fireflies/Tl;dv bots on client calls). Bot-free capture is now table stakes.
4. **Silent capture failure.** Sessions that look live but record nothing (Granola). Worst case when no audio is stored. Users want a live confidence indicator + audio recovery.
5. **Pricing resentment.** Subscriptions + hidden caps + history walls (Granola 30-day, Fathom 5-call AI cap, Otter minutes, Fireflies AI credits, Notta billing complaints). One-time purchase and pay-per-file models are loved, especially in Indonesia.
6. **Privacy & consent.** Hidden capture (Granola class action), training opt-outs buried in settings, US/EU data residency vs local law. In Indonesia, UU PDP 27/2022 creates real exposure for cloud processing of meeting data (https://fh.untar.ac.id/2025/09/11/perlindungan-data-pribadi-implementasi-uu-no-27-tahun-2022-dan-tantangan-penegakannya/); Indonesian vendors now advertise data residency in Indonesia (Notulin) and on-prem deployment (Prosa.ai).
7. **Long meetings.** Local LLM summaries degrade past ~1 hour (Meetily's own docs acknowledge); 3-5 hour meeting caps on paid tiers (Otter 4h, Jamie 5h, Notta 5h). Chunked summarization is needed.
8. **Verification.** No playback/no tape (Granola) means wrong numbers/names can't be checked; users want transcript-linked audio.

## 6. Indonesian market specifics
- **Notulen format matters.** Government and SOE documentation requires formal risalah rapat / notulen structures (judul rapat, hari/tanggal, waktu, pimpinan, peserta, pembahasan, keputusan) — see official templates e.g. Kemendagri PPID notulen format (https://ppid.kemendagri.go.id/storage/dokumen/1zym0RR438jjQHM7Zqc9nIiIpsWvdGkwzqmW5K52.pdf) and ANRI Peraturan No. 5/2025 on tata naskah dinas (https://peraturan.bpk.go.id/Download/378093/peraturan-anri-no-5-tahun-2025.pdf). Indonesian apps compete on MoM formats: Notula (formal/poin/conversational), Notulin (notulen templates, decisions separated from discussion, action items with owner), Notulensi (berita acara/risalah — testimonial from PT ASABRI). Trareon's Indonesian summary templates should target this exact structure.
- **UU PDP 27/2022** (Law 27/2022 on Personal Data Protection) makes cloud upload of meeting audio a compliance question for government, banks, and companies; on-prem/local processing is an explicit selling point for Prosa.ai (banks/government) and Notulin (Indonesian data residency). Trareon's 100% offline posture is a genuine compliance asset — market it in those terms.
- **Offline for sensitive meetings** is a real segment: Notula sells a dedicated "Offline Lite" plan (Rp56.000/mo); Jamie wins finance/law clients on bot-free + EU residency; Whisper Notes markets "no account, nothing uploaded" for NDA-covered recordings.
- **What local apps offer:** Indonesian-first accuracy claims (95-98%), bot joining for Zoom/Meet/Teams, MoM templates, DOCX/PDF export, shareable links, pay-per-file or low Rupiah subscriptions (Rp56k-228k/mo range at Notula; Rp10k-19.9k per file at Transkrip.id/.com). Gaps: none are truly offline/local-first desktop apps; most are web platforms uploading audio to cloud. Trareon is the only free, open-source, offline, Indonesian-first desktop option in this set.
- **Payment habits:** pay-per-file with QRIS/e-wallet (Transkrip.com) fits Indonesian users without credit cards — relevant if Trareon ever adds paid support/hosting.
- **Code-switching ID/EN** is common in Indonesian corporate meetings (Notulin explicitly markets it; Notta's bilingual mode addresses the same need).
- **Unverified:** exact market share numbers for Indonesian players; whether Notula/Notulensi guarantee Indonesian data residency (Notulin claims it; Notula's docs don't state it).

## 7. Top 20 recommendations for Trareon (ranked by impact)

1. **Ship a live confidence indicator + post-meeting capture-integrity check.** The worst failure in the category is silent capture failure (Granola users losing meetings with zero error; https://anarlog.so/blog/granola-ai-complaints/). Show live input level per channel (mic/system), a "recording confirmed" state, and warn at stop if either channel was silent for a long stretch. Cheap to build, directly addresses the category's most damaging complaint.
2. **Add audio playback synced to the transcript.** Everyone except Granola has it; its absence is Granola's most structural complaint ("no tape means you cannot check the transcript"). For verbatim notulen/berita acara use cases, click-to-verify is essential. (Sources: https://anarlog.so/blog/granola-ai-complaints/, https://buzzcaptions.com/, https://github.com/chidiwilliams/buzz)
3. **Build "notulen resmi" export template(s)** matching government/SOE risalah rapat format: judul rapat, hari/tanggal, waktu, tempat, pimpinan, peserta, agenda, pembahasan, keputusan, tindak lanjut, penutup. No global competitor has this; Notula/Notulin charge for it. Sources: https://ppid.kemendagri.go.id/storage/dokumen/1zym0RR438jjQHM7Zqc9nIiIpsWvdGkwzqmW5K52.pdf, https://notula.ai/, https://notulin.id/fitur
4. **Ship custom summary templates (user-editable prompts)** — formal notulen, poin ringkas, conversational, plus save-your-own. Meetily Pro charges $10/mo for this (6 built-ins); Granola made templates core. This is a paid-tier feature that is nearly free to build. Sources: https://meetily.ai/pro/, https://docs.granola.ai/help-center/taking-notes/ai-enhanced-notes
5. **Implement ID/EN code-switching handling explicitly** (auto language detect per segment, both languages in one transcript, summary in Indonesian by default). Whisper handles ID+EN; make it a first-class, documented behavior like Notulin and Notta's bilingual mode. Sources: https://notulin.id/fitur, https://www.plaud.ai/blogs/articles/notta-review
6. **Add a custom dictionary/vocabulary feature** (names, agency terms, acronyms) applied as whisper.cpp initial-prompt or post-processing correction. Table stakes at Otter (team vocabulary), Anarlog (Settings → Dictionary), Notulin (per-workspace). Also handles the #1 Granola complaint (names mangled). Sources: https://otter.ai/pricing-2025, https://docs.anarlog.so/languages
7. **Provenance in summaries: every summary bullet links to the transcript segment (and audio timestamp) it came from.** Granola's magnifying glass is its most-trusted UX feature; Meeting.ai links decisions to original utterances. For official minutes, traceability is a compliance feature. Sources: https://docs.granola.ai/help-center/taking-notes/ai-enhanced-notes, https://meeting.ai/id
8. **Adopt Anarlog's "What runs where" transparency table** in the UI/README: a single screen showing transcription engine, storage path, and exactly when anything leaves the device. Privacy posture made visible is a differentiator no cloud competitor can match. Sources: https://github.com/fastrepl/anarlog, https://meetily.ai/docs/features/provider-configuration
9. **Rename speaker once → updates everywhere** (Whisper Notes pattern) + speaker merge tooling + manual speaker count setting. Speaker ID errors are a top-3 category complaint. Sources: https://whispernotes.app/, https://github.com/chidiwilliams/buzz
10. **Improve diarization honestly before advertising it:** learn from hyprnote, which listed Speaker Identification on its landing page before it worked and got publicly called out at launch (https://news.ycombinator.com/item?id=44725306). Ship with crosstalk caveats and a quick speaker-count picker.
11. **Add full cross-meeting chat ("chat with all meetings")** using local retrieval (SQLite FTS + local LLM via Ollama, or BYOK). Granola/Jamie/tl;dv/Otter all treat this as the premium hook; Trareon's local-first version is a clean privacy story. Sources: https://granola.ai/blog/granola-free-vs-paid-features-each-plan, https://rightaichoice.com/tools/jamie
12. **Add Granola-style "enhance your own notes":** let users type rough notes during the meeting; post-meeting AI merges their notes with the transcript (their lines preserved and highlighted). This converts non-power users who distrust full transcription and is Granola's core moat. Source: https://docs.granola.ai/help-center/taking-notes/ai-enhanced-notes
13. **Meeting auto-detect + one-click record reminder** (listen for Zoom/Meet/Teams window activity; show "Meeting Detected → Record" like MacWhisper; auto-start with cancellable countdown like Jamie). Sources: https://docs.macwhisper.com/article/30-record-meetings, https://meetjamie.ai/changelog
14. **Chunked long-meeting summarization** (map-reduce over 30-60 min windows) so hour+ meetings don't degrade like Meetily's do with local LLMs. Meetily's own docs admit summary quality drops on long calls. Source: https://anarlog.so/blog/meetily-review/
15. **One-time purchase or free-core positioning; never history-wall the free tier.** One-time pricing is loved (Whisper Notes $7.99, MacWhisper €59; subscriptions resented across Reddit/G2 threads). Trareon is already free/open-source — the recommendation is to keep every feature free and monetize support/hosting (Meetily Community vs Pro split created resentment; Anarlog went fully free and won goodwill). Sources: https://whispernotes.app/, https://medium.com/ai-tools-tips-and-news/macwhispers-pricing-is-confusing-on-purpose-here-s-what-i-actually-paid-51c39d1a18fe, https://meetgeek.ai/blog/fireflies-ai-pricing
16. **Export expansion: PDF (formatted notulen with letterhead option), plus keep SRT/VTT; add CSV (Transkrip.id sells CSV).** DOCX/PDF are what Indonesian secretariats ask for first (Notula, Notulensi testimonials). Sources: https://www.transkrip.id/, https://notula.ai/, https://notulensi.id/
17. **Noise-reduction preprocessing toggle** (RNNoise/DNS-style local denoise before ASR). Krisp's whole brand is audio quality upstream of notes; Buzz ships speech separation for noisy audio. For warungs/home-office Indonesian meetings with fan/traffic noise this measurably improves WER. Sources: https://meetingpick.com/reviews/krisp-review-2026, https://github.com/chidiwilliams/buzz
18. **Bookmarks/highlights during recording** (one-click mark + optional note) that surface in the summary — Krisp and MeetingsAI's "important moments," tl;dv clips. Sources: https://meetingpick.com/reviews/krisp-review-2026, https://www.meetingsai.app/
19. **Action items with owner + due date, extracted and rendered as a checklist** in the summary and exportable to a task list — the near-universal "after the meeting" feature (Notulin, Jamie, Fathom, tl;dv, Notion). Sources: https://notulin.id/fitur, https://www.fathom.ai/pricing, https://www.eesel.ai/blog/notion-ai-meeting-notes
20. **Benchmark and publish Indonesian WER for your model lineup** (standard Indonesian + Javanese-accented + code-switched samples), and offer a fine-tuned Indonesian Whisper checkpoint as an in-app download option (e.g., cahya/whisper-large-id lineage) — mirroring tl;dv's published per-language benchmarks and Whisper Notes' model-per-use-case picker. Local vendors claim 96-98%; show your numbers. Sources: https://tldv.io/blog/tldv-honest-review/, https://whispernotes.app/, https://huggingface.co/cahya/whisper-large-id, https://transkripsi.id/blogs/5-software-transkrip-otomatis-bahasa-indonesia-paling-akurat

### Honorable mentions (not in top 20)
- Pre-meeting Brief from calendar + past meetings (Granola, Jamie) — needs calendar integration, a bigger lift for a local app.
- Phone-as-mic QR pairing (Vibe) — great for in-person rapat luar ruangan; https://github.com/thewh1teagle/vibe/blob/main/README.md
- MCP server / HTTP API for agent integration (Vibe has Swagger HTTP API; tl;dv/Jamie/Granola ship MCP servers).
- Presentasi mode for live captioning at events (Buzz).
- Mind-map/Visual Notes output (Notta, Meeting.ai).

---

## Verification notes / unverified items
- tl;dv Indonesian support: its 30+ language list wasn't fully enumerated in sources reviewed — unverified.
- Fathom bot-path language list (38) may include Indonesian — unverified; its bot-free mode is Mac/English (as of April 2026 upgrade note).
- Krisp's 20+ language list — Indonesian inclusion unverified.
- Jamie's 99+ languages — Indonesian inclusion unverified.
- Notion AI Meeting Notes speaker-ID absence is from a Nov 2025 third-party review; may have changed by late 2026 — unverified.
- Meetily community-edition English-only summaries (per Anarlog review, 2025) may have changed in v0.4.0 — unverified.
- Notula/Notulensi data-residency specifics (beyond Notulin's claim) unverified.
- Pricing figures change frequently; each was captured from the cited page but should be re-checked before use in external marketing material.
