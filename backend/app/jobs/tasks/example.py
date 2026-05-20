from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.jobs.registry import register_task


@register_task("example")
async def example_task(session: AsyncSession, parameters: dict[str, Any]) -> None:
    """No-op task for wiring and manual verification."""
