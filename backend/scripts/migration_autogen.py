#!/usr/bin/env python3
"""Create temporary Alembic revisions when models drift from the dev database."""

from __future__ import annotations

import secrets
import sys
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPTS_DIR))

from alembic import command
from alembic.autogenerate import compare_metadata
from alembic.migration import MigrationContext
from sqlalchemy import create_engine

from migration_utils import (
    ROOT,
    get_alembic_config,
    get_sync_database_url,
    get_temp_versions_dir,
    upgrade_head_locked,
)

sys.path.insert(0, str(ROOT))

from app.models.base import Base  # noqa: E402


def main() -> int:
    temp_dir = get_temp_versions_dir()
    temp_dir.mkdir(parents=True, exist_ok=True)

    cfg = get_alembic_config()
    sync_url = get_sync_database_url()

    print("Running migrations to head...")
    upgrade_head_locked(cfg)

    engine = create_engine(sync_url)
    with engine.connect() as connection:
        context = MigrationContext.configure(connection)
        diff = compare_metadata(context, Base.metadata)

    if not diff:
        print("No schema changes detected.")
        return 0

    rev_id = f"temp_{secrets.token_hex(6)}"
    print(f"Schema drift detected — creating temporary revision {rev_id}...")

    command.revision(
        cfg,
        message="auto_dev",
        autogenerate=True,
        rev_id=rev_id,
        version_path=str(temp_dir),
    )

    print("Applying temporary migration...")
    upgrade_head_locked(cfg)
    print(f"Temporary migration {rev_id} created and applied.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
