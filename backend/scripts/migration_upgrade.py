#!/usr/bin/env python3
"""Apply Alembic migrations to head (with advisory lock for concurrent containers)."""

from __future__ import annotations

import sys
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPTS_DIR))

from migration_utils import upgrade_head_locked  # noqa: E402


def main() -> int:
    print("Running migrations to head...")
    upgrade_head_locked()
    return 0


if __name__ == "__main__":
    sys.exit(main())
