"""Unit tests for python.cli.check module."""

from python.cli.check import PrerequisitesChecker


def test_version_compare() -> None:
    checker = PrerequisitesChecker()
    assert checker.version_compare("3.1.0", "3.0.0") == 1
    assert checker.version_compare("3.0.0", "3.1.0") == -1
    assert checker.version_compare("3.0.0", "3.0.0") == 0


def test_print_summary_success(capsys) -> None:
    checker = PrerequisitesChecker()
    checker.issues_found = 0
    assert checker.print_summary() is True
    captured = capsys.readouterr()
    assert "All prerequisites satisfied" in captured.out


def test_print_summary_failure(capsys) -> None:
    checker = PrerequisitesChecker()
    checker.issues_found = 2
    assert checker.print_summary() is False
    captured = capsys.readouterr()
    assert "Found 2 issue" in captured.out


