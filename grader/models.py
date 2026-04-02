"""
models.py
---------
Data classes that represent the core domain objects used throughout the grader.
Following the Single Responsibility Principle — this module only defines data shapes.
"""

from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional, List


@dataclass
class TeamRepo:
    """
    Represents a single team's repository submission.

    Attributes:
        tim_name:       Human-readable team name (e.g. "TIM 01").
        sheet_gid:      Google Sheets GID the team was read from.
        github_url:     Full GitHub clone URL (ending in .git).
        repo_name:      Extracted repository name from the URL.
        valid:          Whether the repository name matches the expected pattern.
        has_link:       Whether the team provided a GitHub link at all.
        cloned:         Whether the repository was successfully cloned.
        clone_path:     Local filesystem path to the cloned repository.
        sql_files:      List of .sql file paths found inside the repository.
        sql_code_display: Concatenated SQL content used for display in the report.
        project_code:   Project identifier extracted from the repo name (e.g. "C01").
        score:          Numeric grade 0–100 assigned by the LLM, or None if unavailable.
        score_details:  Human-readable grading summary (summary + correct + missing).
        correct_parts:  List of correct elements identified by the LLM.
        missing_parts:  List of missing or incorrect elements identified by the LLM.
        clone_error:    stderr output captured when cloning fails.
        ai_generated:   True if the LLM detected the SQL was likely AI-generated;
                        False if it looks like genuine student work; None if unknown.
    """

    tim_name: str
    sheet_gid: str
    github_url: str
    repo_name: str = ""
    valid: bool = True
    has_link: bool = True
    cloned: bool = False
    clone_path: Optional[Path] = None
    sql_files: List[Path] = field(default_factory=list)
    sql_code_display: str = ""
    project_code: str = ""
    score: Optional[float] = None
    score_details: str = ""
    correct_parts: List[str] = field(default_factory=list)
    missing_parts: List[str] = field(default_factory=list)
    clone_error: str = ""
    ai_generated: Optional[bool] = None   # True/False = LLM decision; None = unknown

    @property
    def display_name(self) -> str:
        """Returns a short label combining team name and sheet GID."""
        return f"{self.tim_name} (gid={self.sheet_gid})"
