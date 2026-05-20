from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.config import settings

engine = create_async_engine(
    settings.database_url,
    echo=settings.debug,
)

async_session_factory = async_sessionmaker(
    engine,
    expire_on_commit=False,
)


async def dispose_engine() -> None:
    await engine.dispose()


__all__ = ["engine", "async_session_factory", "dispose_engine"]
