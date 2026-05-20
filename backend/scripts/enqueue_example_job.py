"""Enqueue a single example job for manual worker verification."""

import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.database import async_session_factory, dispose_engine
from app.services import job_service


async def main() -> None:
    try:
        async with async_session_factory() as session:
            job = await job_service.enqueue(
                session, "example", {"source": "enqueue_example_job"}
            )
            await session.commit()
            print(f"Enqueued job id={job.id} task={job.task_name!r}")
    finally:
        await dispose_engine()


if __name__ == "__main__":
    asyncio.run(main())
