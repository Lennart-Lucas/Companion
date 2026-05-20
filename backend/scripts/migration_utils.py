"""Shared helpers for automatic Alembic migration workflows."""

from __future__ import annotations

import os
import re
from pathlib import Path

from alembic.config import Config
from alembic.script import Script, ScriptDirectory

ROOT = Path(__file__).resolve().parent.parent
TEMP_PREFIX = "temp_"

from dotenv import load_dotenv

for _env_name in (".env.dev", ".env"):
    _env_path = ROOT / _env_name
    if _env_path.exists():
        load_dotenv(_env_path)
        break


def is_temp_revision(revision_id: str) -> bool:
    return revision_id.startswith(TEMP_PREFIX)


def get_alembic_config() -> Config:
    cfg = Config(str(ROOT / "alembic.ini"))
    cfg.set_main_option("sqlalchemy.url", get_sync_database_url())
    return cfg


def get_sync_database_url() -> str:
    from app.config import get_database_url_sync

    return get_database_url_sync()


def get_script_directory(config: Config | None = None) -> ScriptDirectory:
    return ScriptDirectory.from_config(config or get_alembic_config())


def get_permanent_revisions(script: ScriptDirectory) -> list[Script]:
    return [rev for rev in script.walk_revisions() if not is_temp_revision(rev.revision)]


def get_permanent_head(script: ScriptDirectory | None = None) -> str:
    script = script or get_script_directory()
    permanent = get_permanent_revisions(script)
    if not permanent:
        raise RuntimeError("No permanent Alembic revisions found.")

    rev_ids = {rev.revision for rev in permanent}
    down_ids = {rev.down_revision for rev in permanent if rev.down_revision}
    heads = rev_ids - down_ids

    if len(heads) != 1:
        raise RuntimeError(f"Expected exactly one permanent head, found: {heads}")

    return heads.pop()


def get_current_heads(script: ScriptDirectory | None = None) -> set[str]:
    script = script or get_script_directory()
    return set(script.get_heads())


def get_temp_versions_dir() -> Path:
    return ROOT / "alembic" / "versions" / "temp"


def get_permanent_versions_dir() -> Path:
    return ROOT / "alembic" / "versions"


def delete_temp_migration_files() -> int:
    temp_dir = get_temp_versions_dir()
    if not temp_dir.exists():
        return 0

    count = 0
    for path in temp_dir.glob("*.py"):
        path.unlink()
        count += 1
    return count


def slugify_message(text: str, max_length: int = 60) -> str:
    slug = re.sub(r"[^a-zA-Z0-9]+", "_", text.strip().lower()).strip("_")
    return slug[:max_length] or "schema_update"
