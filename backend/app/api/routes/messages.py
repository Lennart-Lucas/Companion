from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_active_user, get_db
from app.models.user import User
from app.schemas.messages import EncryptedMessageCreate, EncryptedMessageResponse
from app.services import crypto_service

router = APIRouter(prefix="/messages", tags=["e2e-messages"])


@router.post("", response_model=EncryptedMessageResponse, status_code=201)
async def send_message(
    payload: EncryptedMessageCreate,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> EncryptedMessageResponse:
    message = await crypto_service.store_encrypted_message(session, user, payload)
    return message


@router.get("", response_model=list[EncryptedMessageResponse])
async def list_messages(
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> list[EncryptedMessageResponse]:
    messages = await crypto_service.fetch_inbox(session, user.id)
    return messages
