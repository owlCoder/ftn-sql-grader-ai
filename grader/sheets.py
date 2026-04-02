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
from typing import List, Tuple

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

    Handles both vertical (one team per row group) and horizontal (multiple
    teams per row group) layouts. Teams are detected by scanning for cells
    containing "TIM <number>" anywhere in the sheet. For each team we then
    locate the row that contains "GitHub" in the same column and take the
    URL from the immediate next column.

    Args:
        rows:       Raw rows returned by fetch_sheet_csv.
        sheet_gid:  GID of the sheet (stored in each TeamRepo for labelling).

    Returns:
        List of TeamRepo objects, one per team found.
    """
    teams: List[TeamRepo] = []
    # We'll collect all (row_idx, start_col, tim_number) from TIM header rows
    tim_headers: List[Tuple[int, int, int]] = []  # (row, col, number)

    # First pass: find all TIM headers and their column positions
    for row_idx, row in enumerate(rows):
        for col_idx, cell in enumerate(row):
            cell_str = str(cell).strip()
            # Match "TIM 01", "TIM 02 - Nemanja", "TIM 04", etc.
            m = re.search(r"\bTIM\s+(\d+)\b", cell_str, re.IGNORECASE)
            if m:
                tim_num = int(m.group(1))
                tim_headers.append((row_idx, col_idx, tim_num))

    if not tim_headers:
        log.warning(f"No TIM headers found in sheet gid={sheet_gid}")
        return teams

    # Process each team header independently
    for header_row, start_col, tim_num in tim_headers:
        tim_name = f"TIM {tim_num:02d}"
        github_url = None

        # Search downwards from header_row+1 for a row where cell at start_col
        # contains "GitHub" (case-insensitive)
        for row_idx in range(header_row + 1, len(rows)):
            if row_idx >= len(rows):
                break
            cell_val = str(rows[row_idx][start_col]).strip()
            if "github" in cell_val.lower():
                # The URL should be in the next column (start_col + 1)
                if start_col + 1 < len(rows[row_idx]):
                    potential_url = rows[row_idx][start_col + 1].strip()
                    if potential_url.startswith("http") and "github.com" in potential_url:
                        github_url = potential_url
                break  # Stop searching once we found the GitHub row for this team

        if github_url:
            # Normalise URL: ensure it ends with .git
            url = github_url.rstrip("/")
            if not url.endswith(".git"):
                url += ".git"
            repo_name = url.rstrip("/")[:-4].split("/")[-1]
            teams.append(
                TeamRepo(
                    tim_name=tim_name,
                    sheet_gid=sheet_gid,
                    github_url=url,
                    repo_name=repo_name,
                    has_link=True,
                )
            )
            log.info(f"  {tim_name} (gid={sheet_gid}): {url}")
        else:
            # No GitHub link found for this team → automatic zero
            teams.append(
                TeamRepo(
                    tim_name=tim_name,
                    sheet_gid=sheet_gid,
                    github_url="",
                    has_link=False,
                    valid=False,
                    score=0.0,
                    score_details="Team has no GitHub link — score 0.",
                )
            )
            log.warning(f"  {tim_name} (gid={sheet_gid}): NO LINK → score 0")

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
        except Exception as exc:
            log.error(f"Failed to load sheet gid={gid}: {exc}")

    # Sort by sheet first, then team name, for deterministic report ordering
    all_teams.sort(key=lambda t: (t.sheet_gid, t.tim_name))
    log.info(f"Total teams across all sheets: {len(all_teams)}")
    return all_teams
