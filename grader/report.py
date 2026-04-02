"""
report.py
---------
Generates the self-contained HTML grading report.

The report contains three tabs:
  1. Teams & Scores — a table with score badge, clone status, SQL viewer button,
     and separate "Correct" / "Missing" columns populated by the LLM.
  2. Configuration — the raw config.json values displayed as a table.
  3. Log — all INFO/WARNING/ERROR messages captured during the run.

Single Responsibility: HTML rendering only. No network calls, no filesystem writes
(the caller is responsible for writing the returned string to disk).
"""

import logging
from datetime import datetime
from typing import Dict, List

from grader.logger import list_handler
from grader.models import TeamRepo

log = logging.getLogger(__name__)


# ── Score thresholds for colour-coding ────────────────────────────────────────
_SCORE_HIGH = 70   # green
_SCORE_MID = 40    # yellow


def _score_class(score: float | None) -> tuple[str, str]:
    """Return the CSS class and display text for a numeric score."""
    if score is None or score < 0:
        return "score-low", "N/A"
    if score >= _SCORE_HIGH:
        return "score-high", f"{score:.1f}%"
    if score >= _SCORE_MID:
        return "score-mid", f"{score:.1f}%"
    return "score-low", f"{score:.1f}%"


def _render_config(cfg_dict: Dict) -> str:
    """Build a simple key-value HTML table from the config dictionary."""
    rows = []
    for key, value in cfg_dict.items():
        if isinstance(value, list):
            value = ", ".join(str(v) for v in value)
        rows.append(
            f"<tr>"
            f"<td style='font-weight:bold; width:30%;'>{key}</td>"
            f"<td>{value}</td>"
            f"</tr>"
        )
    return (
        "<table style='width:100%; border-collapse:collapse; "
        "background:#ffffff; border:1px solid #dee2e6;'>"
        + "".join(rows)
        + "</table>"
    )


def _render_logs() -> str:
    """Render all captured log records as an HTML table."""
    rows = []
    for rec in list_handler.records:
        ts = datetime.fromtimestamp(rec.created).strftime("%H:%M:%S")
        level_class = f"log-{rec.levelname.lower()}"
        rows.append(
            f"<tr>"
            f"<td style='color:#6c757d;'>{ts}</td>"
            f"<td class='{level_class}' style='font-weight:bold;'>{rec.levelname}</td>"
            f"<td style='color:#212529;'>{rec.getMessage()}</td>"
            f"</tr>"
        )
    return (
        "<table style='width:100%; border-collapse:collapse; background:#ffffff;'>"
        "<thead><tr><th>Time</th><th>Level</th><th>Message</th></tr></thead>"
        "<tbody>" + "".join(rows) + "</tbody>"
        "</table>"
    )


def _build_sheet_labels(sheet_gids: List[str]) -> Dict[str, str]:
    """
    Map each GID to a human label.
    The first GID is the current generation; subsequent ones are returning students.
    """
    labels: Dict[str, str] = {}
    for i, gid in enumerate(sheet_gids):
        labels[gid] = "current gen." if i == 0 else "returning student"
    return labels


def _render_teams_table(
    teams: List[TeamRepo],
    sheet_gids: List[str],
) -> tuple[str, str]:
    """
    Build the teams table rows and any modal dialogs for SQL code display.

    Returns:
        (teams_rows_html, modals_html)
    """
    labels = _build_sheet_labels(sheet_gids)
    rows: List[str] = []
    modals: List[str] = []

    for idx, team in enumerate(teams):
        score_cls, score_text = _score_class(team.score)
        repo_display = team.repo_name or "—"

        # Clone status badge
        if team.cloned:
            clone_label, badge_cls = "Cloned", "badge-success"
        elif not team.has_link:
            clone_label, badge_cls = "No link", "badge-danger"
        else:
            clone_label, badge_cls = "Failed", "badge-warning"

        # Correct / missing columns
        correct_html = "<br>".join(team.correct_parts) if team.correct_parts else "—"
        missing_html = "<br>".join(team.missing_parts) if team.missing_parts else "—"

        # SQL modal button (only if there is actual SQL content)
        sql_button = ""
        if team.sql_code_display and team.sql_code_display != "No SQL files found.":
            modal_id = f"modal-{idx}"
            sql_button = (
                f'<button class="sql-button" onclick="openModal(\'{modal_id}\')">'
                f'<i class="fas fa-code"></i> SQL&nbsp;Code</button>'
            )
            modals.append(
                f'<div id="{modal_id}" class="modal">'
                f'<div class="modal-content">'
                f'<span class="close" onclick="closeModal(\'{modal_id}\')">&times;</span>'
                f"<h3>SQL code for {team.display_name}</h3>"
                f'<pre class="modal-sql">{team.sql_code_display}</pre>'
                f"</div></div>"
            )

        team_label = f"{team.tim_name} ({labels.get(team.sheet_gid, team.sheet_gid)})"

        rows.append(
            f"<tr>"
            f"<td><b>{team_label}</b></td>"
            f"<td><code>{repo_display}</code></td>"
            f"<td><div class='score-badge {score_cls}'>{score_text}</div></td>"
            f"<td><span class='badge {badge_cls}'>{clone_label}</span></td>"
            f"<td>{sql_button}</td>"
            f"<td class='correct-col'>{correct_html}</td>"
            f"<td class='missing-col'>{missing_html}</td>"
            f"</tr>"
        )

    return "\n".join(rows), "\n".join(modals)


# ── CSS bundled into the report (single self-contained file) ──────────────────
_CSS = """
* { font-family: 'Segoe UI', Roboto, system-ui, sans-serif; }
body { background: #f8f9fa; margin: 2rem; }
.container { max-width: 100%; margin: auto; background: white; border-radius: 20px;
             box-shadow: 0 10px 25px -5px rgba(0,0,0,0.05); overflow: hidden; }
header { background: linear-gradient(135deg, #1e3c72, #2a5298); color: white;
         padding: 1.8rem 2rem; }
header h1 { margin: 0; font-weight: 600; font-size: 1.8rem; }
header p  { margin: 0.5rem 0 0; opacity: 0.85; }
.tabs { display: flex; border-bottom: 2px solid #dee2e6;
        background: #ffffff; padding: 0 2rem; }
.tab-link { padding: 1rem 1.5rem; cursor: pointer; font-weight: 600; border: none;
            background: none; font-size: 1rem; transition: 0.2s; color: #495057; }
.tab-link:hover  { color: #1e3c72; background: #f1f3f5; }
.tab-link.active { color: #1e3c72; border-bottom: 3px solid #1e3c72; margin-bottom: -2px; }
.tab-content        { display: none; padding: 2rem; }
.tab-content.active { display: block; }
table { width: 100%; border-collapse: collapse; }
th, td { text-align: left; padding: 12px 10px; border-bottom: 1px solid #e2e8f0;
          vertical-align: top; }
th { background: #eef2ff; color: #1e3c72; font-weight: 600; }
tr:hover { background: #f8fafc; }
.score-badge { display: inline-block; padding: 5px 14px; border-radius: 40px;
               font-weight: bold; text-align: center; min-width: 70px; font-size: 0.9rem; }
.score-high { background: #dcfce7; color: #15803d; }
.score-mid  { background: #fef9c3; color: #854d0e; }
.score-low  { background: #fee2e2; color: #b91c1c; }
.badge { display: inline-block; padding: 2px 8px; border-radius: 20px;
         font-size: 0.7rem; font-weight: normal; }
.badge-success { background: #dcfce7; color: #15803d; }
.badge-danger  { background: #fee2e2; color: #b91c1c; }
.badge-warning { background: #fef9c3; color: #854d0e; }
.log-info    { color: #0c6dfd; }
.log-warning { color: #e67e22; }
.log-error   { color: #dc3545; }
i { margin-right: 6px; }
.sql-button { background: #eef2ff; border: none; border-radius: 20px;
              padding: 4px 12px; cursor: pointer; font-size: 0.75rem;
              color: #1e3c72; transition: 0.2s; }
.sql-button:hover { background: #d1d9f0; }
.correct-col { background-color: #f0fdf4; }
.missing-col { background-color: #fef2f2; }
/* Modal */
.modal { display: none; position: fixed; z-index: 1000; left: 0; top: 0;
         width: 100%; height: 100%; overflow: auto;
         background-color: rgba(0,0,0,0.5); }
.modal-content { background-color: #fefefe; margin: 5% auto; padding: 20px;
                 border-radius: 20px; width: 80%; max-width: 1000px;
                 box-shadow: 0 5px 15px rgba(0,0,0,0.3); }
.close { color: #aaa; float: right; font-size: 28px; font-weight: bold; cursor: pointer; }
.close:hover { color: black; }
.modal-sql { background: #f1f3f5; padding: 1rem; border-radius: 12px;
             overflow-x: auto; font-family: 'Courier New', monospace;
             font-size: 0.85rem; white-space: pre-wrap; word-wrap: break-word;
             max-height: 70vh; overflow-y: auto; }
"""

# ── Inline JavaScript ─────────────────────────────────────────────────────────
_JS = """
function openTab(evt, tabName) {
    document.querySelectorAll('.tab-content').forEach(el => el.classList.remove('active'));
    document.querySelectorAll('.tab-link').forEach(el => el.classList.remove('active'));
    document.getElementById(tabName).classList.add('active');
    evt.currentTarget.classList.add('active');
}
function openModal(id)  { document.getElementById(id).style.display = 'block'; }
function closeModal(id) { document.getElementById(id).style.display = 'none'; }
window.onclick = function(event) {
    document.querySelectorAll('.modal').forEach(m => {
        if (event.target === m) m.style.display = 'none';
    });
};
"""


def generate_html_report(
    teams: List[TeamRepo],
    cfg_dict: Dict,
    sheet_gids: List[str],
) -> str:
    """
    Produce the complete self-contained HTML grading report.

    Args:
        teams:      All TeamRepo objects (processed or not).
        cfg_dict:   Raw config dictionary, used for the Configuration tab.
        sheet_gids: List of sheet GIDs for generating human-readable labels.

    Returns:
        Full HTML document as a string (UTF-8 safe).
    """
    teams_rows, modals = _render_teams_table(teams, sheet_gids)
    generated_at = datetime.now().strftime("%d.%m.%Y %H:%M:%S")

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>ODP SQL Grader — Report</title>
    <link rel="stylesheet"
          href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0-beta3/css/all.min.css">
    <style>{_CSS}</style>
</head>
<body>
<div class="container">
    <header>
        <h1><i class="fas fa-database"></i> ODP SQL Grader — Report</h1>
        <p>Generated: {generated_at} | LM Studio evaluation</p>
    </header>

    <div class="tabs">
        <button class="tab-link active" onclick="openTab(event,'teams')">
            <i class="fas fa-users"></i> Teams &amp; Scores</button>
        <button class="tab-link" onclick="openTab(event,'config')">
            <i class="fas fa-cog"></i> Configuration</button>
        <button class="tab-link" onclick="openTab(event,'log')">
            <i class="fas fa-terminal"></i> Log</button>
    </div>

    <div id="teams" class="tab-content active">
        <h2><i class="fas fa-users"></i> Team Overview</h2>
        <table>
            <thead>
                <tr>
                    <th>Team (sheet)</th>
                    <th>Repo name</th>
                    <th>Score</th>
                    <th>Status</th>
                    <th>SQL files</th>
                    <th>Correct</th>
                    <th>Missing / Incorrect</th>
                </tr>
            </thead>
            <tbody>{teams_rows}</tbody>
        </table>
    </div>

    <div id="config" class="tab-content">
        <h2><i class="fas fa-sliders-h"></i> System Configuration</h2>
        {_render_config(cfg_dict)}
    </div>

    <div id="log" class="tab-content">
        <h2><i class="fas fa-list-alt"></i> Log messages</h2>
        {_render_logs()}
    </div>
</div>

{modals}

<script>{_JS}</script>
</body>
</html>"""
