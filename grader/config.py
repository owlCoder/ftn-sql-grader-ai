"""
config.py
---------
Responsible for loading and validating the application configuration from
config.json. Follows the Single Responsibility Principle — nothing here
performs IO beyond reading the config file.
"""

import json
import re
from pathlib import Path
from typing import Any, Dict, List


# Default path to the configuration file (relative to the working directory)
CONFIG_FILE = Path("config.json")

# Keys that must be present in config.json for the application to start
REQUIRED_KEYS: List[str] = ["spreadsheet_id", "sheet_gids", "lm_studio_endpoint"]


def load_config(path: Path = CONFIG_FILE) -> Dict[str, Any]:
    """
    Load and validate the JSON configuration file.

    Args:
        path: Path to config.json. Defaults to CONFIG_FILE constant.

    Returns:
        Parsed configuration dictionary.

    Raises:
        FileNotFoundError: If the config file does not exist.
        ValueError: If any required key is missing from the config.
    """
    if not path.exists():
        raise FileNotFoundError(
            f"Configuration file '{path}' not found. "
            "Please create it based on the README instructions."
        )

    with open(path, "r", encoding="utf-8") as fh:
        cfg: Dict[str, Any] = json.load(fh)

    for key in REQUIRED_KEYS:
        if key not in cfg:
            raise ValueError(
                f"config.json is missing required key: '{key}'"
            )

    return cfg


class AppConfig:
    """
    Thin wrapper around the raw config dictionary that exposes typed attributes
    and pre-compiles expensive values (e.g. regex patterns).

    All modules import an instance of this class instead of touching the raw dict
    directly, which keeps concerns isolated and makes testing easier.
    """

    def __init__(self, raw: Dict[str, Any]) -> None:
        self.spreadsheet_id: str = raw["spreadsheet_id"]
        self.sheet_gids: List[str] = raw["sheet_gids"]
        self.solutions_dir: Path = Path(raw.get("solutions_dir", "./solutions"))
        self.tmp_base_dir: Path = Path(raw.get("tmp_base_dir", "./tmp"))
        self.lm_studio_endpoint: str = raw["lm_studio_endpoint"]
        self.lm_studio_model: str = raw.get(
            "lm_studio_model", "qwen2.5-coder-7b-instruct"
        )

        # Pre-compile the repository name validation regex
        pattern_str: str = raw.get(
            "repo_name_pattern",
            r"^odp_C(\d{2}|[1-9]S)_tim_(\d{2}|[1-9]S)$",
        )
        self.repo_name_pattern: re.Pattern = re.compile(
            pattern_str, re.IGNORECASE
        )

        # Keep the raw dict available for report rendering (config tab)
        self._raw: Dict[str, Any] = raw

    def as_dict(self) -> Dict[str, Any]:
        """Return the original raw config dict (used by the report renderer)."""
        return self._raw

    @property
    def lm_studio_models_url(self) -> str:
        """Derive the /v1/models health-check URL from the completions endpoint."""
        return self.lm_studio_endpoint.replace("/v1/chat/completions", "/v1/models")
