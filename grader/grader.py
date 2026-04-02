"""
grader.py
---------
Handles semantic SQL comparison via the LM Studio API (OpenAI-compatible).

Responsibilities:
  - Load reference solution files from disk.
  - Build prompts and call the LM Studio chat completions endpoint.
  - Parse the JSON response to extract score, summary, and part lists.
  - Assign the result back to the TeamRepo object.

Single Responsibility: LLM interaction and grading logic only.
No git, no Sheets, no HTML rendering.
"""

import json
import logging
import re
from pathlib import Path
from typing import List, Optional, Tuple

import requests

from grader.models import TeamRepo

log = logging.getLogger(__name__)

# Separator inserted between multiple SQL files when they are concatenated
# for the LLM prompt, making file boundaries visible.
_FILE_SEPARATOR = "\n\n-- === NEXT FILE ===\n\n"


def load_solution(solutions_dir: Path, project_code: str) -> Optional[str]:
    """
    Read the reference SQL solution for the given project code.

    Args:
        solutions_dir:  Directory containing *_resenje.sql files.
        project_code:   Project identifier (e.g. "C01").

    Returns:
        File content as a string, or None if the file does not exist.
    """
    path = solutions_dir / f"{project_code}_resenje.sql"
    if not path.exists():
        log.warning(f"Solution file not found: {path}")
        return None
    return path.read_text(encoding="utf-8")


def _build_prompt(
    student_sql: str,
    solution_sql: str,
    project_code: str,
    team_name: str,
) -> str:
    """
    Construct the user-facing prompt that instructs the LLM to grade the SQL.

    The prompt explicitly lists semantic equivalence rules so the model
    does not penalise students for cosmetic differences (aliases, column order, etc.).

    Returns:
        Formatted prompt string.
    """
    return f"""Semantically compare the student's SQL against the model solution.

IMPORTANT RULES:
- Different column name that means the same thing = CORRECT
- Different table alias = CORRECT
- Different column order = CORRECT
- Missing clause (JOIN, WHERE, GROUP BY...) = ERROR
- Wrong logical condition that changes the result = ERROR

Project: {project_code} | Team: {team_name}

=== MODEL SOLUTION ===
{solution_sql}

=== STUDENT SQL ===
{student_sql}

Reply ONLY in JSON format:
{{
  "score": <number 0-100>,
  "summary": "<explanation in Serbian, max 2 sentences>",
  "correct_parts": ["<correct parts>"],
  "missing_parts": ["<errors or missing parts>"]
}}"""


def _parse_llm_response(
    content: str,
) -> Tuple[float, str, List[str], List[str]]:
    """
    Extract grading data from the raw LLM response string.

    The model sometimes wraps JSON in markdown fences (```json ... ```) or
    includes leading text before the JSON object; this function handles both.

    Args:
        content: Raw text from the LLM choices[0].message.content field.

    Returns:
        Tuple of (score, score_details, correct_parts, missing_parts).
    """
    # Strip markdown code fences if present
    clean = re.sub(r"```json|```", "", content).strip()

    # Find the first {...} block that contains "score" in case there is preamble
    json_match = re.search(r'\{.*"score".*\}', clean, re.DOTALL)
    raw_json = json_match.group() if json_match else clean
    parsed = json.loads(raw_json)

    score: float = float(parsed.get("score", 0))
    summary: str = parsed.get("summary", "")
    correct: List[str] = parsed.get("correct_parts", [])
    missing: List[str] = parsed.get("missing_parts", [])

    # Build a single score_details string for logging and display
    details = summary
    if correct:
        details += "\nCorrect: " + "; ".join(correct)
    if missing:
        details += "\nMissing: " + "; ".join(missing)

    return score, details.strip(), correct, missing


def compare_sql_with_lmstudio(
    student_sql: str,
    solution_sql: str,
    project_code: str,
    team_name: str,
    endpoint: str,
    model: str,
) -> Tuple[float, str, List[str], List[str]]:
    """
    Send the student SQL and reference solution to LM Studio for semantic grading.

    Args:
        student_sql:   Concatenated content of all student SQL files.
        solution_sql:  Content of the reference solution file.
        project_code:  E.g. "C01" — included in the prompt for context.
        team_name:     Human-readable team label — included in the prompt.
        endpoint:      LM Studio chat completions URL.
        model:         Model identifier string to pass in the request body.

    Returns:
        Tuple of (score 0-100, score_details, correct_parts, missing_parts).
        On failure, returns (0.0, error message, [], []).
    """
    system_prompt = "You are an SQL expert. Always reply exclusively in JSON format."
    user_prompt = _build_prompt(student_sql, solution_sql, project_code, team_name)

    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ],
        "temperature": 0.0,   # Deterministic output for consistent grading
        "max_tokens": 1000,
    }

    try:
        resp = requests.post(endpoint, json=payload, timeout=120)
        resp.raise_for_status()
        data = resp.json()
        content = data["choices"][0]["message"]["content"].strip()
        return _parse_llm_response(content)
    except Exception as exc:
        log.error(f"LM Studio comparison failed for {team_name}: {exc}")
        return 0.0, f"Error: {exc}", [], []


def grade_team(
    team: TeamRepo,
    solutions_dir: Path,
    endpoint: str,
    model: str,
) -> None:
    """
    Grade a single team by comparing their SQL files against the reference solution.

    Side effects:
        Populates team.score, team.score_details, team.correct_parts,
        and team.missing_parts.

    Args:
        team:          TeamRepo that has already been cloned and had SQL files found.
        solutions_dir: Directory where reference solution files live.
        endpoint:      LM Studio completions URL.
        model:         Model identifier for the API request.
    """
    if not team.sql_files:
        team.score = 0.0
        team.score_details = "No SQL files found in the repository."
        return

    solution = load_solution(solutions_dir, team.project_code)
    if solution is None:
        team.score = None
        team.score_details = (
            f"Solution for project '{team.project_code}' not found "
            f"in '{solutions_dir}/'."
        )
        return

    # Concatenate all student SQL files into one block for the LLM
    student_sql = _FILE_SEPARATOR.join(
        f"-- {f.name}\n{f.read_text(encoding='utf-8', errors='replace')}"
        for f in team.sql_files
    )

    score, details, correct, missing = compare_sql_with_lmstudio(
        student_sql, solution, team.project_code, team.display_name, endpoint, model
    )

    team.score = score
    team.score_details = details
    team.correct_parts = correct
    team.missing_parts = missing
    log.info(f"{team.display_name}: Score = {score:.1f}%")
