"""
repository.py
-------------
Handles repository name validation, cloning, and SQL file discovery.

Responsibilities (all git/filesystem, no HTTP or grading logic):
  - Validate that a repository name matches the expected naming convention.
  - Clone the repository into a timestamped tmp directory.
  - Recursively find all .sql files and concatenate their content for display.

Single Responsibility: filesystem and git operations only.
"""

import logging
import re
import subprocess
from pathlib import Path
from typing import List

from grader.models import TeamRepo

log = logging.getLogger(__name__)

# Regex used to extract the project code segment from the repo name
# Example: "odp_C01_tim_03"  →  project_code = "C01"
_PROJECT_CODE_RE = re.compile(r"odp_(C[^_]+)_tim_", re.IGNORECASE)


def validate_repo_name(team: TeamRepo, pattern: re.Pattern) -> bool:
    """
    Check whether the team's repository name matches the naming convention.

    Side effects:
        Sets team.valid, team.score, team.score_details, and team.project_code.

    Args:
        team:    The TeamRepo whose repo_name will be validated.
        pattern: Compiled regex pattern from AppConfig.

    Returns:
        True if the name is valid, False otherwise.
    """
    if not pattern.match(team.repo_name):
        team.valid = False
        team.score = 0.0
        team.score_details = "Invalid repository name — does not match naming convention."
        log.error(
            f"INVALID NAME | {team.display_name} | "
            f"Name: {team.repo_name} | URL: {team.github_url}"
        )
        return False

    # Extract project code from the repo name (e.g. "C01")
    code_match = _PROJECT_CODE_RE.search(team.repo_name)
    if code_match:
        team.project_code = code_match.group(1).upper()

    team.valid = True
    log.info(
        f"Valid: {team.repo_name} | Project: {team.project_code} | {team.display_name}"
    )
    return True


def clone_repo(team: TeamRepo, clone_dir: Path) -> bool:
    """
    Clone the team's GitHub repository into clone_dir / repo_name.

    If the destination directory already exists, cloning is skipped (idempotent).

    Side effects:
        Sets team.clone_path, team.cloned, team.score, team.score_details,
        and team.clone_error on failure.

    Args:
        team:       The TeamRepo to clone.
        clone_dir:  Base directory where all repos are cloned during this run.

    Returns:
        True on success (or if already cloned), False on failure.
    """
    dest = clone_dir / team.repo_name

    # Skip if already cloned (e.g. a second run with the same tmp directory)
    if dest.exists():
        team.clone_path = dest
        team.cloned = True
        log.info(f"Directory already exists (skipping clone): {dest}")
        return True

    log.info(f"Cloning: {team.github_url} → {dest}")
    result = subprocess.run(
        ["git", "clone", team.github_url, str(dest)],
        capture_output=True,
        text=True,
    )

    if result.returncode != 0:
        err = result.stderr.strip()
        log.error(f"Clone failed ({team.display_name}): {err}")
        team.score = 0.0
        team.score_details = f"Clone failed: {err}"
        team.clone_error = err
        return False

    team.clone_path = dest
    team.cloned = True
    log.info(f"Successfully cloned: {dest}")
    return True


def find_sql_files(team: TeamRepo) -> List[Path]:
    """
    Recursively locate all .sql files inside the cloned repository.

    Side effects:
        Populates team.sql_files and team.sql_code_display.

    Args:
        team: A successfully cloned TeamRepo.

    Returns:
        List of Path objects pointing to the discovered .sql files.
    """
    if not team.clone_path or not team.clone_path.exists():
        return []

    team.sql_files = list(team.clone_path.rglob("*.sql"))

    if team.sql_files:
        log.info(
            f"{team.display_name}: SQL files → "
            f"{[f.name for f in team.sql_files]}"
        )
        # Build a single display string: each file separated by a header comment
        parts = [
            f"-- File: {f.name}\n{f.read_text(encoding='utf-8', errors='replace')}"
            for f in team.sql_files
        ]
        team.sql_code_display = "\n\n".join(parts)
    else:
        log.warning(f"{team.display_name}: No .sql files found")
        team.sql_code_display = "No SQL files found."

    return team.sql_files
