import logging

from util.logging import RedactingFormatter


def test_redact_hf_token():
    fmt = RedactingFormatter("%(message)s")
    record = logging.LogRecord("t", logging.INFO, "", 0, "token=hf_ABC123XYZ", (), None)
    assert "[REDACTED]" in fmt.format(record)
