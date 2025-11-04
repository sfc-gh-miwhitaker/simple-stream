"""Minimal helpers for executing setup SQL scripts."""

from __future__ import annotations

import subprocess
from pathlib import Path
from typing import Iterable

_ROOT: Path = Path(__file__).resolve().parents[2]
_SETUP_DIR: Path = _ROOT / "sql" / "01_setup"


def iter_setup_scripts() -> Iterable[Path]:
    """Yield setup scripts in deterministic order."""

    return (path for path in sorted(_SETUP_DIR.glob("*.sql")))


def run_sql(path: Path, *, dry_run: bool = False, timeout: int = 600) -> int:
    """Execute the provided SQL script via Snowflake CLI."""

    if dry_run:
        return 0

    result = subprocess.run(
        ["snow", "sql", "-f", str(path)],
        check=False,
        text=True,
        timeout=timeout,
    )
    return int(result.returncode)

