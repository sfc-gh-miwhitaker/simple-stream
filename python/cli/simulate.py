"""Thin wrapper around the simulator entry point."""

from __future__ import annotations

import sys
from typing import Sequence

from python.simulator import simulator


def main(argv: Sequence[str] | None = None) -> int:
    args = list(argv or sys.argv[1:])
    original = sys.argv.copy()
    try:
        sys.argv = [original[0], *args]
        simulator.main()
    finally:
        sys.argv = original
    return 0

