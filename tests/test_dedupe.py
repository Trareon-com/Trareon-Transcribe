from engine.dedupe import EchoDedupe
from engine.session_store import TranscriptSegment


def test_echo_dedupe_drops_speaker_copy():
    d = EchoDedupe(window_ms=8000)
    mic = TranscriptSegment(0, 1000, "hello world project", "MIC", "en", 0.9, True)
    spk = TranscriptSegment(500, 1500, "hello world project", "SPEAKER", "en", 0.9, True)
    assert d.filter_segment(spk, [mic]) is None


def test_echo_dedupe_keeps_different_text():
    d = EchoDedupe()
    mic = TranscriptSegment(0, 1000, "hello", "MIC", "en", 0.9, True)
    spk = TranscriptSegment(500, 1500, "completely different sentence here", "SPEAKER", "en", 0.9, True)
    assert d.filter_segment(spk, [mic]) is not None
