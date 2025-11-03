"""Tests for the validation CLI."""

from python.cli.validate import PipelineValidator


class DummyRun:
    def __init__(self):
        self.commands = []

    def __call__(self, cmd, capture_output=True, text=True, timeout=120):
        self.commands.append(cmd)

        class Result:
            returncode = 0
            stdout = ""
            stderr = ""

        return Result()


def test_pipeline_validator_quick(monkeypatch) -> None:
    dummy = DummyRun()
    monkeypatch.setattr("python.cli.validate.subprocess.run", dummy)

    validator = PipelineValidator(mode="quick")
    assert validator.run() is True
    assert dummy.commands, "Expected snow CLI commands"
    assert "quick_check.sql" in dummy.commands[0][-1]


def test_pipeline_validator_invalid_mode() -> None:
    validator = PipelineValidator(mode="invalid")
    assert validator.run() is False
