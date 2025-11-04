"""Lightweight CLI namespace for the demo project."""

from importlib import import_module
from types import ModuleType
from typing import Final

_MODULES: Final[tuple[str, ...]] = ("deploy", "simulate", "validate", "check")

__all__ = list(_MODULES)


def __getattr__(name: str) -> ModuleType:
    if name in _MODULES:
        return import_module(f"{__name__}.{name}")
    raise AttributeError(name)

