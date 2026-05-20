from datetime import UTC, datetime
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models.async_job import AsyncJob, JobStatus


async def enqueue(
    session: AsyncSession,
    task_name: str,
    parameters: dict[str, Any] | None = None,
    *,
    max_retries: int | None = None,
    scheduled_at: datetime | None = None,
) -> AsyncJob:
    job = AsyncJob(
        task_name=task_name,
        parameters=parameters or {},
        status=JobStatus.pending.value,
        max_retries=max_retries if max_retries is not None else settings.job_max_retries,
        scheduled_at=scheduled_at or datetime.now(UTC),
    )
    session.add(job)
    await session.flush()
    await session.refresh(job)
    return job


async def get_job(session: AsyncSession, job_id: int) -> AsyncJob | None:
    result = await session.execute(select(AsyncJob).where(AsyncJob.id == job_id))
    return result.scalar_one_or_none()
