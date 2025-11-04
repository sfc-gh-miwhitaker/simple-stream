"""Simple pipeline validation helper."""

from __future__ import annotations

import subprocess
from pathlib import Path

_ROOT: Path = Path(__file__).resolve().parents[2]
_VALIDATION_DIR: Path = _ROOT / "sql" / "02_validation"
_MODE_TO_SCRIPT = {
    "quick": _VALIDATION_DIR / "quick_check.sql",
    "full": _VALIDATION_DIR / "check_pipeline.sql",
}


class PipelineValidator:
    """Execute canned validation SQL via the Snow CLI."""

    def __init__(self, mode: str = "quick") -> None:
        self.mode = mode

    def run(self) -> bool:
        script = _MODE_TO_SCRIPT.get(self.mode)
        if not script:
            return False

        result = subprocess.run(
            ["snow", "sql", "-f", str(script)],
            capture_output=True,
            text=True,
            timeout=120,
        )
        return result.returncode == 0

