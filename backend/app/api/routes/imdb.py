from fastapi import APIRouter, Depends, Query

from app.dependencies import get_current_active_user
from app.models.user import User
from app.schemas.imdb import (
    ImdbTitleDetailResponse,
    ImdbTitleSearchResponse,
)
from app.services.imdb_api_client import imdb_api_client, normalize_imdb_id

router = APIRouter(prefix="/imdb", tags=["imdb"])


@router.get("/search", response_model=ImdbTitleSearchResponse)
async def search_imdb_titles(
    query: str = Query(min_length=1, max_length=200),
    limit: int = Query(default=20, ge=1, le=50),
    user: User = Depends(get_current_active_user),
) -> ImdbTitleSearchResponse:
    _ = user
    items = await imdb_api_client.search_titles(query, limit=limit)
    return ImdbTitleSearchResponse(items=items)


@router.get("/titles/{imdb_id}", response_model=ImdbTitleDetailResponse)
async def get_imdb_title(
    imdb_id: str,
    user: User = Depends(get_current_active_user),
) -> ImdbTitleDetailResponse:
    _ = user
    normalized = normalize_imdb_id(imdb_id)
    return await imdb_api_client.get_title(normalized)
