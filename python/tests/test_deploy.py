"""Tests for the deployment CLI."""

from pathlib import Path

import pytest

from python.cli import deploy


def test_iter_setup_scripts_sorted() -> None:
    scripts = list(deploy.iter_setup_scripts())
    assert scripts, "No setup scripts discovered"
    names = [path.name for path in scripts]
    assert names == sorted(names)


def test_run_sql_dry_run(monkeypatch) -> None:
    calls = []

    def fake_run(cmd, check=False):  # noqa: D401 - mimic subprocess.run
        calls.append(cmd)
        class Result:
            returncode = 0
        return Result()

    monkeypatch.setattr(deploy.subprocess, "run", fake_run)

    dummy_file = Path("/tmp/01_fake.sql")
    rc = deploy.run_sql(dummy_file, dry_run=True)
    assert rc == 0
    assert not calls, "Dry run should not execute subprocess.run"


