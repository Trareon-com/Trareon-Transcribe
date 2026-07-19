"""Local-only rotating logs with secret redaction."""

from __future__ import annotations

import logging
import re
from logging.handlers import RotatingFileHandler

from config.paths import logs_dir

_REDACT = re.compile(
    r"(hf_[A-Za-z0-9]+)|((token|password|secret|api[_-]?key)\s*[:=]\s*\S+)",
    re.IGNORECASE,
)


class RedactingFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        msg = super().format(record)
        return _REDACT.sub("[REDACTED]", msg)


def setup_logging(level: int = logging.INFO) -> logging.Logger:
    logger = logging.getLogger("trareon")
    if logger.handlers:
        return logger
    logger.setLevel(level)
    log_path = logs_dir() / "app.log"
    handler = RotatingFileHandler(
        log_path, maxBytes=2 * 1024 * 1024, backupCount=5, encoding="utf-8"
    )
    handler.setFormatter(
        RedactingFormatter("%(asctime)s %(levelname)s %(name)s: %(message)s")
    )
    logger.addHandler(handler)
    # Console for dev
    sh = logging.StreamHandler()
    sh.setFormatter(RedactingFormatter("%(levelname)s: %(message)s"))
    logger.addHandler(sh)
    return logger
