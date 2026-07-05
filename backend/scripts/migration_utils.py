"""Shared helpers for automatic Alembic migration workflows."""

from __future__ import annotations

import re
import subprocess
from pathlib import Path

from alembic import command
from alembic.config import Config
from alembic.script import Script, ScriptDirectory
from sqlalchemy import create_engine, text

# Single global lock so API and worker cannot run Alembic upgrade concurrently.
MIGRATION_ADVISORY_LOCK_KEY = 2847593021

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


def upgrade_head_locked(cfg: Config | None = None) -> None:
    """Run `alembic upgrade head` under a Postgres advisory lock."""
    config = cfg or get_alembic_config()
    engine = create_engine(get_sync_database_url())
    with engine.connect() as conn:
        conn.execute(
            text("SELECT pg_advisory_lock(:key)"),
            {"key": MIGRATION_ADVISORY_LOCK_KEY},
        )
        try:
            command.upgrade(config, "head")
        finally:
            conn.execute(
                text("SELECT pg_advisory_unlock(:key)"),
                {"key": MIGRATION_ADVISORY_LOCK_KEY},
            )


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


NUMERIC_REVISION_PATTERN = re.compile(r"^\d{3}$")
SKIP_BRANCH_NAMES = frozenset({"main", "develop", "master", "head"})


def _run_git(args: list[str], repo_root: Path) -> str | None:
    try:
        result = subprocess.run(
            ["git", *args],
            capture_output=True,
            text=True,
            check=True,
            cwd=repo_root,
        )
        return result.stdout.strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return None


def parse_branch_from_merge_subject(subject: str) -> str | None:
    subject = subject.strip()
    if not subject:
        return None

    patterns = [
        re.compile(r"^merge pull request #\d+ from [^/]+/(.+)$", re.IGNORECASE),
        re.compile(r"^merge branch '([^']+)'", re.IGNORECASE),
        re.compile(r"^merge remote-tracking branch '[^/]+/([^']+)'", re.IGNORECASE),
    ]
    for pattern in patterns:
        match = pattern.match(subject)
        if match:
            branch_part = match.group(1).split("/")[-1]
            slug = slugify_message(branch_part)
            if slug and slug != "schema_update":
                return slug
    return None


def get_merged_branch_slug(repo_root: Path) -> str | None:
    merged_sha = _run_git(["rev-parse", "HEAD^2"], repo_root)
    if not merged_sha:
        return None

    branches_output = _run_git(
        [
            "branch",
            "-a",
            "--contains",
            merged_sha,
            "--format=%(refname:short)",
        ],
        repo_root,
    )
    if not branches_output:
        return None

    candidates: list[str] = []
    for line in branches_output.splitlines():
        name = line.strip()
        if not name:
            continue
        if name.startswith("origin/"):
            name = name.removeprefix("origin/")
        base_name = name.split("/")[-1]
        if base_name.lower() in SKIP_BRANCH_NAMES:
            continue
        if name not in candidates:
            candidates.append(name)

    if not candidates:
        return None

    # Prefer local-style branch names (no slash) over remote feature paths.
    candidates.sort(key=lambda n: ("/" in n, len(n)))
    return slugify_message(candidates[0].split("/")[-1])


def resolve_revision_slug(
    repo_root: Path, cli_message: str | None = None
) -> str:
    if cli_message:
        return slugify_message(cli_message)

    branch_slug = get_merged_branch_slug(repo_root)
    if branch_slug:
        return branch_slug

    subject = _run_git(["log", "-1", "--pretty=%s"], repo_root)
    if subject:
        parsed = parse_branch_from_merge_subject(subject)
        if parsed:
            return parsed

    return "schema_update"


def get_next_permanent_revision_id(script: ScriptDirectory) -> str:
    numeric_ids: list[int] = []
    for rev in get_permanent_revisions(script):
        if NUMERIC_REVISION_PATTERN.match(rev.revision):
            numeric_ids.append(int(rev.revision))

    if not numeric_ids:
        return "001"

    return f"{max(numeric_ids) + 1:03d}"
