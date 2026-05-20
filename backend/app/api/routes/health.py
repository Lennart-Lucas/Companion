from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_db
from app.schemas.health import DbHealthResponse, HealthResponse

router = APIRouter(tags=["health"])


@router.get("/health", response_model=HealthResponse)
async def health_check() -> HealthResponse:
    return HealthResponse(status="ok")


@router.get("/health/db", response_model=DbHealthResponse)
async def health_check_db(session: AsyncSession = Depends(get_db)) -> DbHealthResponse:
    await session.execute(text("SELECT 1"))
    return DbHealthResponse(status="ok", database="connected")
