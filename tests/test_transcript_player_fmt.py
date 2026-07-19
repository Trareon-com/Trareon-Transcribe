from ui.transcript_player import _fmt_ms, _speaker_color


def test_fmt_ms():
    assert _fmt_ms(0) == "00:00"
    assert _fmt_ms(65_000) == "01:05"
    assert _fmt_ms(3_661_000) == "01:01:01"


def test_speaker_color_stable():
    assert _speaker_color("MIC") == _speaker_color("mic")
    assert _speaker_color("Speaker 1") == _speaker_color("Speaker 1")
