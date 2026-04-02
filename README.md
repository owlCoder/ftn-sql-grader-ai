# ODP SQL Grader

Automated grading tool for SQL assignments submitted via GitHub.  
Fetches team repository links from a Google Sheet, clones each repo, and uses a locally running **LM Studio** model to semantically compare student SQL files against reference solutions.  
Results are written to a self-contained **HTML report**.

---

## Features

- Pulls team names and GitHub links from one or more Google Sheets tabs (no API key required — public sheets only).
- Validates repository names against a configurable regex pattern.
- Clones repositories with `git` into a timestamped `tmp/` subdirectory.
- Recursively finds all `.sql` files in each repository.
- Sends student SQL + reference solution to a local LM Studio model (OpenAI-compatible API) for semantic grading.
- Produces a tabbed HTML report with:
  - Per-team score badge, clone status, and SQL viewer modal.
  - Separate **Correct** / **Missing** columns populated by the LLM.
  - Configuration snapshot and full run log.

---

## Requirements

| Requirement | Version |
|---|---|
| Python | 3.11+ |
| git | any recent version |
| LM Studio | running locally with a loaded model |

Python packages:

```
pip install -r requirements.txt
```

Only one external package is needed: `requests`.

---

## Project Structure

```
grader/
├── grader/
│   ├── __init__.py      # Package declaration
│   ├── config.py        # Config loading and AppConfig wrapper
│   ├── logger.py        # Logging setup + in-memory ListHandler
│   ├── models.py        # TeamRepo dataclass
│   ├── sheets.py        # Google Sheets CSV fetching and parsing
│   ├── repository.py    # Repo name validation, git clone, SQL discovery
│   ├── grader.py        # LM Studio API calls and grading logic
│   └── report.py        # HTML report generation
├── solutions/           # Reference SQL solution files (see below)
├── tmp/                 # Cloned repositories (auto-created, auto-cleared)
├── main.py              # Entry point — wires all modules together
├── config.json          # Runtime configuration (not committed to git)
├── requirements.txt
└── README.md
```

---

## Configuration

Create a `config.json` file in the project root (same directory as `main.py`):

```json
{
  "spreadsheet_id": "YOUR_GOOGLE_SHEET_ID",
  "sheet_gids": ["427514693", "387992360"],
  "solutions_dir": "./solutions",
  "tmp_base_dir": "./tmp",
  "lm_studio_endpoint": "http://localhost:1234/v1/chat/completions",
  "lm_studio_model": "qwen2.5-coder-7b-instruct",
  "repo_name_pattern": "^odp_C(\\d{2}|[1-9]S)_tim_(\\d{2}|[1-9]S)$"
}
```

| Key | Required | Description |
|---|---|---|
| `spreadsheet_id` | ✅ | ID from the Google Sheets URL (`/d/<ID>/edit`). The sheet must be publicly readable. |
| `sheet_gids` | ✅ | List of tab GIDs. The first is labelled "current gen.", the rest "returning student". |
| `lm_studio_endpoint` | ✅ | Full URL to the LM Studio chat completions endpoint. |
| `solutions_dir` | ➖ | Path to the folder containing reference `.sql` files. Default: `./solutions`. |
| `tmp_base_dir` | ➖ | Path for temporary clone directories. Default: `./tmp`. |
| `lm_studio_model` | ➖ | Model identifier passed in the API request body. |
| `repo_name_pattern` | ➖ | Regex that repository names must match. |

---

## Reference Solutions

Place one `.sql` file per project in the `solutions/` directory.  
Files must be named `<PROJECT_CODE>_resenje.sql`, matching the code extracted from the repository name.

**Examples:**

| Repository name | Project code | Expected solution file |
|---|---|---|
| `odp_C01_tim_03` | `C01` | `solutions/C01_resenje.sql` |
| `odp_C2S_tim_1S` | `C2S` | `solutions/C2S_resenje.sql` |

---

## Google Sheet Format

The grader scans each sheet for rows containing **TIM &lt;number&gt;** and then looks for a GitHub URL in the following rows.

Example layout (columns can be in any order):

| | A | B |
|---|---|---|
| 1 | TIM 1 | |
| 2 | GitHub link: | https://github.com/org/odp_C01_tim_01 |
| 3 | TIM 2 | |
| 4 | GitHub link: | https://github.com/org/odp_C01_tim_02 |

Teams with no GitHub link receive an automatic score of **0**.

---

## Running

```bash
# From the project root (same directory as main.py)
python main.py
```

The report is saved to `grader_report.html` in the working directory.  
Log messages are also written to `grader.log`.

---

## Repository Naming Convention

Repository names must follow this pattern (case-insensitive):

```
odp_C<XX>_tim_<YY>
```

Where `<XX>` and `<YY>` are either two digits (`01`–`99`) or a digit followed by `S` (e.g. `1S`).

Valid examples: `odp_C01_tim_03`, `odp_C2S_tim_1S`  
Invalid examples: `odp_project_team1`, `odp_c01_team_03`

Repositories with invalid names receive an automatic score of **0**.

---

## Grading Logic

For each team the LLM is asked to compare the student SQL against the reference solution according to these rules:

- Different column name that conveys the same meaning → **CORRECT**
- Different table alias → **CORRECT**
- Different column order → **CORRECT**
- Missing clause (`JOIN`, `WHERE`, `GROUP BY`, …) → **ERROR**
- Wrong logical condition that changes the query result → **ERROR**

The model returns a JSON object with:
- `score` (0–100)
- `summary` (short explanation)
- `correct_parts` (list)
- `missing_parts` (list)

---

## SOLID Design

| Principle | How it is applied |
|---|---|
| **S**ingle Responsibility | Each module has one job: `sheets.py` fetches data, `repository.py` clones repos, `grader.py` calls the LLM, `report.py` renders HTML. |
| **O**pen/Closed | New sheet formats or grading backends can be added without modifying existing modules. |
| **L**iskov Substitution | `ListHandler` extends `logging.Handler` and is a true drop-in replacement. |
| **I**nterface Segregation | Modules depend only on the types they actually use (`TeamRepo`, `AppConfig`). |
| **D**ependency Inversion | `main.py` wires concrete implementations; individual modules accept parameters rather than importing globals. |

---

## License

Internal academic tool — not for redistribution.
