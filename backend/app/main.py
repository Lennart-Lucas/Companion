from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.api.routes import health
from app.config import settings
from app.database import dispose_engine


@asynccontextmanager
async def lifespan(app: FastAPI):
    yield
    await dispose_engine()


app = FastAPI(
    title="Companion API",
    version="0.1.0",
    lifespan=lifespan,
)

app.include_router(health.router)
