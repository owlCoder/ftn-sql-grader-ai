#!/usr/bin/env python3
"""
main.py
-------
Entry point for the ODP SQL Grader.

Orchestrates the full grading pipeline:
  1. Load configuration.
  2. Set up logging.
  3. Fetch team data from Google Sheets.
  4. For each team: validate → clone → find SQL → grade.
  5. Generate and save the HTML report.

This module contains no business logic — it only wires the other modules together,
following the Dependency Inversion Principle (high-level policy, no low-level detail).
"""

import logging
import os
import shutil
import stat
from datetime import datetime
from pathlib import Path

import requests

from grader.config import AppConfig, load_config
from grader.grader import grade_team
from grader.logger import configure_logging
from grader.models import TeamRepo
from grader.report import generate_html_report
from grader.repository import clone_repo, find_sql_files, validate_repo_name
from grader.sheets import fetch_all_teams

log = logging.getLogger(__name__)

# Path to the temporary directory that holds cloned repositories
_TMP_PATH = Path("tmp")

# Output file for the HTML report
_REPORT_PATH = Path("grader_report.html")


# ── Utility helpers ────────────────────────────────────────────────────────────

def _remove_readonly(func, path, exc) -> None:
    """Error handler for shutil.rmtree on Windows read-only files."""
    os.chmod(path, stat.S_IWRITE)
    func(path)


def _clear_tmp(tmp_path: Path) -> None:
    """Remove all subdirectories inside the tmp folder before each run."""
    if not tmp_path.exists():
        return
    for item in tmp_path.iterdir():
        shutil.rmtree(item, onexc=_remove_readonly)


def _create_clone_dir(tmp_base: Path) -> Path:
    """
    Create a timestamped directory inside tmp_base for this run's clones.

    Using a timestamp avoids collisions when the grader is run multiple times
    in the same minute, and makes it easy to trace which clone belongs to which run.
    """
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    clone_dir = tmp_base / f"repos-{timestamp}"
    clone_dir.mkdir(parents=True, exist_ok=True)
    log.info(f"Clone directory: {clone_dir}")
    return clone_dir


def _check_lm_studio(cfg: AppConfig) -> None:
    """Log whether the LM Studio API is reachable. Non-fatal if it is not."""
    try:
        resp = requests.get(cfg.lm_studio_models_url, timeout=5)
        if resp.status_code == 200:
            log.info(f"LM Studio API available at {cfg.lm_studio_endpoint}")
        else:
            log.warning(
                f"LM Studio API returned status {resp.status_code} "
                f"at {cfg.lm_studio_models_url}"
            )
    except Exception:
        log.warning(
            f"Cannot connect to LM Studio API. "
            f"Check that the server is running at {cfg.lm_studio_endpoint}"
        )


# ── Main pipeline ──────────────────────────────────────────────────────────────

def main() -> None:
    """Run the full grading pipeline."""

    # ── 1. Logging ──────────────────────────────────────────────────────────
    configure_logging()

    # ── 2. Configuration ────────────────────────────────────────────────────
    raw_cfg = load_config()
    cfg = AppConfig(raw_cfg)

    log.info("=" * 60)
    log.info("ODP SQL Grader (LM Studio) — Correct / Missing columns")
    log.info("=" * 60)

    # ── 3. Pre-run checks ───────────────────────────────────────────────────
    _clear_tmp(_TMP_PATH)
    cfg.solutions_dir.mkdir(parents=True, exist_ok=True)
    clone_dir = _create_clone_dir(cfg.tmp_base_dir)
    _check_lm_studio(cfg)

    solutions_available = (
        cfg.solutions_dir.exists() and any(cfg.solutions_dir.iterdir())
    )
    if not solutions_available:
        log.warning(
            f"Folder '{cfg.solutions_dir}/' is empty — "
            "grading will be skipped."
        )

    # ── 4. Fetch teams ──────────────────────────────────────────────────────
    teams = fetch_all_teams(cfg.spreadsheet_id, cfg.sheet_gids)
    if not teams:
        log.error("No teams found — aborting.")
        return

    # ── 5. Per-team pipeline ─────────────────────────────────────────────────
    for team in teams:
        if not team.has_link:
            continue  # Already marked with score=0 in sheets.py

        if not validate_repo_name(team, cfg.repo_name_pattern):
            continue  # Invalid name — score set to 0 inside the function

        if not clone_repo(team, clone_dir):
            continue  # Clone failed — score set to 0 inside the function

        find_sql_files(team)

        if solutions_available:
            grade_team(
                team,
                solutions_dir=cfg.solutions_dir,
                endpoint=cfg.lm_studio_endpoint,
                model=cfg.lm_studio_model,
            )
        else:
            team.score_details = "Grading skipped — no solution files available."

    # ── 6. HTML report ───────────────────────────────────────────────────────
    html = generate_html_report(teams, cfg.as_dict(), cfg.sheet_gids)
    _REPORT_PATH.write_text(html, encoding="utf-8")
    log.info(f"HTML report saved: {_REPORT_PATH}")
    log.info(f"Clones located in: {clone_dir}")
    log.info("Done.")


if __name__ == "__main__":
    main()
