# Bukti WER head-to-head: Trareon vs Google AI Edge Foresight (12-13 Okt 2026)

Video uji: https://www.youtube.com/watch?v=kZeDpnoQieI (eSIM explainer, ~9 menit, Bahasa Indonesia)

- `youtube_reference_caption.srt` — auto-caption YouTube (referensi independen, bukan ground truth manusia)
- `foresight_raw_transcript.txt` — transkrip mentah Foresight (user capture langsung dari app, 2 channel: Remote+Microphone)
- `trareon_transcript.txt` — transkrip Trareon pakai model large-v3-turbo ggml (transcribe_cli --language id)

WER (jiwer, lowercased+punctuation-stripped):
- Trareon: 12.14%
- Foresight Remote: 28.96%
- Foresight Microphone: 30.59%

Lihat docs/COMPETITOR-RESEARCH.md §1.18 untuk analisis lengkap + reverse-engineering model (TinyGemmaAsr, Gemini-Nano-v2+USM 700M).
