import asyncio
import logging
import traceback
import uuid
from datetime import UTC, datetime, timedelta
from typing import Any

from sqlalchemy import delete, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import async_session_factory, dispose_engine
from app.jobs import tasks as _tasks  # noqa: F401
from app.jobs.startup import wait_for_job_schema
from app.jobs.registry import get_task
from app.models.async_job import AsyncJob, JobStatus
from app.models.async_job_error import AsyncJobError

logger = logging.getLogger(__name__)

_ERROR_MESSAGE_MAX = 512


def _utcnow() -> datetime:
    return datetime.now(UTC)


async def release_stale_locks(session: AsyncSession) -> int:
    cutoff = _utcnow() - timedelta(seconds=settings.job_lock_timeout_seconds)
    result = await session.execute(
        update(AsyncJob)
        .where(
            AsyncJob.status == JobStatus.running.value,
            AsyncJob.locked_at.is_not(None),
            AsyncJob.locked_at < cutoff,
        )
        .values(
            status=JobStatus.pending.value,
            locked_at=None,
            locked_by=None,
        )
    )
    return result.rowcount or 0


async def cleanup_completed(session: AsyncSession) -> int:
    cutoff = _utcnow() - timedelta(seconds=settings.job_success_retention_seconds)
    result = await session.execute(
        delete(AsyncJob).where(
            AsyncJob.status == JobStatus.completed.value,
            AsyncJob.completed_at.is_not(None),
            AsyncJob.completed_at < cutoff,
        )
    )
    return result.rowcount or 0


async def claim_batch(session: AsyncSession, worker_id: str) -> list[int]:
    now = _utcnow()
    stmt = (
        select(AsyncJob)
        .where(
            AsyncJob.status == JobStatus.pending.value,
            AsyncJob.scheduled_at <= now,
            AsyncJob.retry_count < AsyncJob.max_retries,
        )
        .order_by(AsyncJob.scheduled_at)
        .limit(settings.job_batch_size)
        .with_for_update(skip_locked=True)
    )
    result = await session.execute(stmt)
    jobs = list(result.scalars().all())
    job_ids: list[int] = []
    for job in jobs:
        job.status = JobStatus.running.value
        job.locked_at = now
        job.locked_by = worker_id
        job.started_at = now
        job_ids.append(job.id)
    return job_ids


async def _mark_completed(session: AsyncSession, job: AsyncJob) -> None:
    now = _utcnow()
    job.status = JobStatus.completed.value
    job.completed_at = now
    job.locked_at = None
    job.locked_by = None
    job.last_error = None


async def _mark_failed(
    session: AsyncSession,
    job: AsyncJob,
    message: str,
    detail: str | None,
    *,
    permanent: bool = False,
) -> None:
    now = _utcnow()
    attempt = job.retry_count + 1
    session.add(
        AsyncJobError(
            job_id=job.id,
            attempt=attempt,
            message=message[:_ERROR_MESSAGE_MAX],
            detail=detail,
        )
    )
    job.retry_count = attempt
    job.last_error = message[:_ERROR_MESSAGE_MAX]
    job.locked_at = None
    job.locked_by = None

    if permanent or job.retry_count >= job.max_retries:
        job.status = JobStatus.failed.value
        job.completed_at = now
        return

    backoff = timedelta(seconds=job.retry_count * settings.job_retry_base_seconds)
    job.status = JobStatus.pending.value
    job.scheduled_at = now + backoff


async def process_job(job_id: int, worker_id: str) -> None:
    async with async_session_factory() as session:
        job = await session.get(AsyncJob, job_id)
        if job is None:
            return
        if job.status != JobStatus.running.value or job.locked_by != worker_id:
            return

        handler = get_task(job.task_name)
        if handler is None:
            await _mark_failed(
                session,
                job,
                f"Unknown task: {job.task_name}",
                None,
                permanent=True,
            )
            await session.commit()
            return

        params: dict[str, Any] = job.parameters if job.parameters is not None else {}
        try:
            await handler(session, params)
            await _mark_completed(session, job)
            await session.commit()
            logger.info("Job %s (%s) completed", job.id, job.task_name)
        except Exception as exc:
            await session.rollback()
            async with async_session_factory() as fail_session:
                fail_job = await fail_session.get(AsyncJob, job_id)
                if fail_job is None:
                    return
                if fail_job.status != JobStatus.running.value:
                    return
                detail = traceback.format_exc()
                message = str(exc) or type(exc).__name__
                await _mark_failed(fail_session, fail_job, message, detail)
                await fail_session.commit()
                logger.warning(
                    "Job %s (%s) failed (retry %s/%s): %s",
                    fail_job.id,
                    fail_job.task_name,
                    fail_job.retry_count,
                    fail_job.max_retries,
                    message,
                )


async def run_once(worker_id: str) -> None:
    async with async_session_factory() as session:
        released = await release_stale_locks(session)
        if released:
            logger.info("Released %s stale job lock(s)", released)
        deleted = await cleanup_completed(session)
        if deleted:
            logger.info("Deleted %s completed job(s)", deleted)
        job_ids = await claim_batch(session, worker_id)
        await session.commit()

    for job_id in job_ids:
        await process_job(job_id, worker_id)


async def run_worker_loop() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )
    logging.getLogger("sqlalchemy.engine").setLevel(logging.WARNING)
    worker_id = str(uuid.uuid4())
    logger.info("Worker started (id=%s)", worker_id)
    await wait_for_job_schema()
    try:
        while True:
            try:
                await run_once(worker_id)
            except Exception:
                logger.exception("Worker iteration failed")
            await asyncio.sleep(settings.job_poll_interval_seconds)
    finally:
        await dispose_engine()
