import asyncio
import logging
import time

from sqlalchemy import text
from sqlalchemy.exc import ProgrammingError

from app.config import settings
from app.database import async_session_factory

logger = logging.getLogger(__name__)


async def wait_for_job_schema(
    timeout_seconds: int | None = None,
    poll_interval_seconds: float = 2.0,
) -> None:
    """Block until async_jobs exists (migrations applied)."""
    timeout = timeout_seconds or settings.job_schema_wait_timeout_seconds
    deadline = time.monotonic() + timeout

    while time.monotonic() < deadline:
        try:
            async with async_session_factory() as session:
                try:
                    await session.execute(text("SELECT 1 FROM async_jobs LIMIT 0"))
                except ProgrammingError:
                    await session.rollback()
                    raise
            logger.info("Job tables are ready")
            return
        except ProgrammingError:
            pass
        except Exception as exc:
            if "async_jobs" not in str(exc) and "does not exist" not in str(exc):
                raise

        remaining = deadline - time.monotonic()
        if remaining <= 0:
            break
        logger.info("Waiting for async_jobs table (migrations pending)...")
        await asyncio.sleep(min(poll_interval_seconds, remaining))

    raise TimeoutError(
        f"async_jobs table not available after {timeout}s; run migrations (alembic upgrade head)"
    )
