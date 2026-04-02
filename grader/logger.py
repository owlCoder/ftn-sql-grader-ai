"""
logger.py
---------
Sets up application-wide logging with three handlers:
  1. File handler  — writes every log line to grader.log (UTF-8, overwritten each run).
  2. Stream handler — echoes log lines to stdout for live feedback.
  3. List handler  — accumulates LogRecord objects so the HTML report can embed them.

The ListHandler is the only state kept here; all other modules call
logging.getLogger(__name__) as usual.
"""

import logging
from typing import List


class ListHandler(logging.Handler):
    """
    In-memory logging handler.

    Collects every emitted LogRecord into a list so they can be rendered
    inside the HTML report without reading grader.log from disk.
    """

    def __init__(self) -> None:
        super().__init__()
        self.records: List[logging.LogRecord] = []

    def emit(self, record: logging.LogRecord) -> None:
        """Append the record to the in-memory list (no formatting applied here)."""
        self.records.append(record)


# Module-level singleton — imported by the report renderer to access collected records
list_handler = ListHandler()
list_handler.setLevel(logging.INFO)


def configure_logging(log_file: str = "grader.log") -> None:
    """
    Attach all handlers to the root logger and set the global log level.

    Must be called once at application startup before any logger is used.

    Args:
        log_file: Path to the rotating log file. Defaults to "grader.log".
    """
    fmt = logging.Formatter("%(asctime)s [%(levelname)s] %(message)s")

    # File handler — overwrites the file on each run (mode="w")
    file_handler = logging.FileHandler(log_file, encoding="utf-8", mode="w")
    file_handler.setFormatter(fmt)

    # Console handler — mirrors output to stdout
    stream_handler = logging.StreamHandler()
    stream_handler.setFormatter(fmt)

    # In-memory handler — for HTML report
    list_handler.setFormatter(fmt)

    logging.basicConfig(
        level=logging.INFO,
        handlers=[file_handler, stream_handler, list_handler],
    )
