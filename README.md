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

## LM Studio — Installation and Setup

LM Studio is a local application that allows you to run open-source LLM models on your own computer without an internet connection and without sending data to the cloud.

### 1. Download and Installation

1. Visit the official website: [https://lmstudio.ai](https://lmstudio.ai)
2. Download the version for your operating system (Windows, macOS, or Linux).
3. Run the installer and follow the steps until the installation is complete.

> **System requirements:** CPU with AVX2 support; 16 GB RAM recommended for models up to 7B parameters. A GPU (NVIDIA/AMD/Apple Silicon) significantly speeds up inference.

---

### 2. Downloading a Model

1. Open LM Studio and go to the **Discover** tab (left sidebar, magnifying glass icon).
2. In the search bar, type `qwen2.5-coder-7b-instruct` (recommended model for SQL grading).
3. Click **Download** next to the desired quantization — we recommend `Q4_K_M` as a balance between speed and accuracy.
4. Wait for the download to complete (the model is approximately ~5 GB).

Alternative models that perform well for SQL tasks:

| Model                          | Size (Q4_K_M) | Notes                            |
| ------------------------------ | ------------- | -------------------------------- |
| `qwen2.5-coder-7b-instruct`    | ~5 GB         | Recommended — optimized for code |
| `deepseek-coder-6.7b-instruct` | ~4 GB         | Good alternative                 |
| `codellama-7b-instruct`        | ~4 GB         | Meta model, proven for SQL       |

### 3. Running the Local Server

1. In LM Studio, open the **Local Server** tab (icon `<->` in the left sidebar).
2. From the dropdown menu, select the model you downloaded.
3. Click **Start Server**.
4. Verify that the server is listening on `http://localhost:1234` — this is shown in the status bar.

The default API endpoint used by the grader:

```
http://localhost:1234/v1/chat/completions
```

---

### 4. Configuring `config.json`

Make sure the following values in `config.json` match your LM Studio server:

```json
{
  "lm_studio_endpoint": "http://localhost:1234/v1/chat/completions",
  "lm_studio_model": "qwen2.5-coder-7b-instruct"
}
```

> The `lm_studio_model` value must exactly match the name of the model loaded in LM Studio (visible in the header of the Local Server tab).

---

### 5. Testing the Server

Before running the grader, you can manually test the server:

```bash
curl http://localhost:1234/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen2.5-coder-7b-instruct",
    "messages": [{"role": "user", "content": "Say hello."}],
    "max_tokens": 50
  }'
```

If you receive a JSON response with a `choices` field, the server is working correctly.


## License

Internal academic tool — not for redistribution.
