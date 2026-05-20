import os

from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.config import settings


def _sqlalchemy_echo() -> bool:
    # Worker polls every few seconds; SQL echo would flood logs in dev.
    if os.environ.get("WORKER_PROCESS") == "1":
        return False
    return settings.debug


engine = create_async_engine(
    settings.database_url,
    echo=_sqlalchemy_echo(),
)

async_session_factory = async_sessionmaker(
    engine,
    expire_on_commit=False,
)


async def dispose_engine() -> None:
    await engine.dispose()


__all__ = ["engine", "async_session_factory", "dispose_engine"]
