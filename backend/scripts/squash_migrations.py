#!/usr/bin/env python3
"""Squash local temp migrations into one permanent revision after merge."""

from __future__ import annotations

import subprocess
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
    delete_temp_migration_files,
    get_alembic_config,
    get_permanent_head,
    get_permanent_versions_dir,
    get_script_directory,
    get_sync_database_url,
    slugify_message,
)

sys.path.insert(0, str(ROOT))

from app.models.base import Base  # noqa: E402


def get_merge_message_slug() -> str:
    try:
        result = subprocess.run(
            ["git", "log", "-1", "--pretty=%s"],
            capture_output=True,
            text=True,
            check=True,
            cwd=ROOT.parent,
        )
        return slugify_message(result.stdout)
    except (subprocess.CalledProcessError, FileNotFoundError):
        return "schema_update"


def main() -> int:
    cfg = get_alembic_config()
    script = get_script_directory(cfg)
    permanent_head = get_permanent_head(script)
    sync_url = get_sync_database_url()

    print(f"Permanent head: {permanent_head}")

    print(f"Downgrading database to permanent head ({permanent_head})...")
    try:
        command.downgrade(cfg, permanent_head)
    except Exception as exc:
        print(
            "ERROR: Could not downgrade to permanent head.\n"
            "Temporary migrations may have applied irreversible changes.\n"
            "Reset the dev database and retry:\n"
            "  docker compose -p companion-dev -f docker-compose.dev.yml down -v\n"
            "  make dev-up && make squash-migrations",
            file=sys.stderr,
        )
        print(f"Details: {exc}", file=sys.stderr)
        return 1

    removed = delete_temp_migration_files()
    print(f"Removed {removed} temporary migration file(s).")

    engine = create_engine(sync_url)
    with engine.connect() as connection:
        context = MigrationContext.configure(connection)
        diff = compare_metadata(context, Base.metadata)

    if not diff:
        print("No schema changes relative to permanent head — nothing to squash.")
        command.upgrade(cfg, "head")
        return 0

    message = get_merge_message_slug()
    permanent_dir = get_permanent_versions_dir()
    print(f"Creating permanent migration: {message}...")

    command.revision(
        cfg,
        message=message,
        autogenerate=True,
        version_path=str(permanent_dir),
    )

    print("Applying permanent migration...")
    command.upgrade(cfg, "head")

    script = get_script_directory(cfg)
    new_head = get_permanent_head(script)
    print(f"Squash complete. New permanent head: {new_head}")
    print("Review the new file in alembic/versions/ and commit it.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
