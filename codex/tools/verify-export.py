#!/usr/bin/env python3
"""Fail if this portable export contains likely live credentials or caches."""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SKIP_NAMES = {"CHECKSUMS.sha256"}
FORBIDDEN_NAMES = {"auth.json", ".env", ".env.local"}
FORBIDDEN_PARTS = {"__pycache__", ".cache"}
PATTERNS = (
    re.compile(r"\bsk-[A-Za-z0-9_-]{12,}\b"),
    re.compile(r"\b(?:ghp|github_pat)_[A-Za-z0-9_-]{12,}\b"),
    re.compile(r"\b(?:glpat|xox[baprs])-[A-Za-z0-9_-]{12,}\b"),
    re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----"),
    re.compile(
        r"(?im)^\s*(?:api[_-]?key|access[_-]?token|refresh[_-]?token|"
        r"password|secret)\s*=\s*['\"](?!__|YOUR_|REPLACE_|<)[^'\"]{12,}['\"]"
    ),
)


def main() -> int:
    failures: list[str] = []
    for path in ROOT.rglob("*"):
        relative = path.relative_to(ROOT)
        if path.is_symlink():
            failures.append(f"symlink present: {relative}")
            continue
        if set(relative.parts) & FORBIDDEN_PARTS:
            failures.append(f"excluded directory present: {relative}")
            continue
        if not path.is_file() or path.name in SKIP_NAMES:
            continue
        if path.name in FORBIDDEN_NAMES or path.suffix == ".pyc":
            failures.append(f"excluded file present: {relative}")
            continue
        try:
            content = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            failures.append(f"binary file present: {relative}")
            continue
        if any(pattern.search(content) for pattern in PATTERNS):
            failures.append(f"possible credential: {relative}")
    if failures:
        print("Portable export verification failed:", *failures, sep="\n- ")
        return 1
    print("Portable export verification passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
