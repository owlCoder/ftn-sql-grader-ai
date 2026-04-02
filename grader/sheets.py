"""
sheets.py
---------
Responsible for fetching and parsing team submission data from Google Sheets.

Each public Google Sheet can be exported as CSV without authentication.
This module downloads those CSVs, parses team names and GitHub links,
and returns a list of TeamRepo objects ready for further processing.

Single Responsibility: only data retrieval and initial parsing — no git,
no grading, no reporting.
"""

import csv
import io
import logging
import re
from typing import List

import requests

from grader.models import TeamRepo

log = logging.getLogger(__name__)

# CSV export URL template for public Google Sheets
_SHEET_CSV_URL = (
    "https://docs.google.com/spreadsheets/d/{spreadsheet_id}"
    "/export?format=csv&gid={gid}"
)


def fetch_sheet_csv(spreadsheet_id: str, gid: str) -> List[List[str]]:
    """
    Download a single Google Sheet tab as CSV and return its rows.

    Args:
        spreadsheet_id: The spreadsheet's unique ID (from its URL).
        gid:            The sheet tab GID.

    Returns:
        A list of rows, each row being a list of cell strings.

    Raises:
        requests.HTTPError: If the HTTP request fails.
    """
    url = _SHEET_CSV_URL.format(spreadsheet_id=spreadsheet_id, gid=gid)
    log.info(f"Fetching sheet gid={gid}")
    resp = requests.get(url, timeout=30)
    resp.raise_for_status()
    rows = list(csv.reader(io.StringIO(resp.text)))
    log.info(f"  → {len(rows)} rows loaded")
    return rows


def extract_teams_from_rows(rows: List[List[str]], sheet_gid: str) -> List[TeamRepo]:
    """
    Parse a sheet's rows to find team names and their GitHub repository links.

    Scanning logic:
      - A row containing "TIM <number>" signals the start of a new team block.
      - The first cell in subsequent rows that starts with "http" and contains
        "github.com" is used as that team's repository URL.
      - Teams without any GitHub link receive score=0 immediately.

    Args:
        rows:       Raw rows returned by fetch_sheet_csv.
        sheet_gid:  GID of the sheet (stored in each TeamRepo for labelling).

    Returns:
        List of TeamRepo objects, one per team found.
    """
    teams: List[TeamRepo] = []
    current_tim: str | None = None
    current_link: str | None = None

    def flush() -> None:
        """Commit the currently buffered team to the list."""
        nonlocal current_tim, current_link
        if current_tim is None:
            return

        if current_link:
            # Normalise URL: ensure it ends with .git
            url = current_link.rstrip("/")
            if not url.endswith(".git"):
                url += ".git"
            repo_name = url.rstrip("/")[:-4].split("/")[-1]
            teams.append(
                TeamRepo(
                    tim_name=current_tim,
                    sheet_gid=sheet_gid,
                    github_url=url,
                    repo_name=repo_name,
                    has_link=True,
                )
            )
            log.info(f"  {current_tim} (gid={sheet_gid}): {url}")
        else:
            # Team with no link — give an automatic zero
            teams.append(
                TeamRepo(
                    tim_name=current_tim,
                    sheet_gid=sheet_gid,
                    github_url="",
                    has_link=False,
                    valid=False,
                    score=0.0,
                    score_details="Team has no GitHub link — score 0.",
                )
            )
            log.warning(
                f"  {current_tim} (gid={sheet_gid}): NO LINK → score 0"
            )

        current_tim = None
        current_link = None

    for row in rows:
        row_text = " ".join(str(c) for c in row)

        # Detect "TIM <number>" anywhere in the row
        tim_match = re.search(r"\bTIM\s+(\d+)\b", row_text, re.IGNORECASE)
        if tim_match:
            flush()
            current_tim = f"TIM {int(tim_match.group(1)):02d}"
            continue

        # While we have an active team and haven't found its link yet,
        # scan every cell for a GitHub URL
        if current_tim and current_link is None:
            for cell in row:
                cell_s = str(cell).strip()
                if "github.com" in cell_s.lower() and cell_s.startswith("http"):
                    current_link = cell_s
                    break

    flush()  # Commit the last team
    return teams


def fetch_all_teams(spreadsheet_id: str, sheet_gids: List[str]) -> List[TeamRepo]:
    """
    Iterate over all configured sheet GIDs and aggregate teams from each.

    Args:
        spreadsheet_id: Google Sheets document ID.
        sheet_gids:     List of tab GIDs to process.

    Returns:
        Sorted list of all TeamRepo objects found across all sheets.
    """
    all_teams: List[TeamRepo] = []

    for gid in sheet_gids:
        try:
            rows = fetch_sheet_csv(spreadsheet_id, gid)
            sheet_teams = extract_teams_from_rows(rows, gid)
            all_teams.extend(sheet_teams)
            log.info(f"Sheet gid={gid}: added {len(sheet_teams)} teams")
        except Exception as exc:
            log.error(f"Failed to load sheet gid={gid}: {exc}")

    # Sort by sheet first, then team name, for deterministic report ordering
    all_teams.sort(key=lambda t: (t.sheet_gid, t.tim_name))
    log.info(f"Total teams across all sheets: {len(all_teams)}")
    return all_teams
