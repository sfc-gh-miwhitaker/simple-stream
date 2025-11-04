"""Prerequisite checks for local tooling."""

from __future__ import annotations

from dataclasses import dataclass


@dataclass
class PrerequisitesChecker:
    """Track prerequisite issues and emit a summary."""

    issues_found: int = 0

    @staticmethod
    def version_compare(left: str, right: str) -> int:
        a = [int(part) for part in left.split(".")]
        b = [int(part) for part in right.split(".")]
        # Pad shorter list with zeros for fair comparison
        length = max(len(a), len(b))
        a.extend([0] * (length - len(a)))
        b.extend([0] * (length - len(b)))
        if a > b:
            return 1
        if a < b:
            return -1
        return 0

    def print_summary(self) -> bool:
        if self.issues_found:
            print(f"Found {self.issues_found} issue(s)")
            return False
        print("All prerequisites satisfied")
        return True

