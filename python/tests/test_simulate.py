"""Tests for the simulate CLI wrapper."""

from python.cli import simulate


def test_simulate_wrapper_forwards_arguments(monkeypatch) -> None:
    received = {}

    def fake_main():
        received["argv"] = simulate.sys.argv[1:]

    monkeypatch.setattr(simulate.simulator, "main", fake_main)

    simulate.main(["--duration-days", "1", "--events-per-second", "50"])

    assert received["argv"] == ["--duration-days", "1", "--events-per-second", "50"]


