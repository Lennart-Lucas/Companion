from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field

MessageType = Literal["prekey", "whisper", "sender_key"]


class EncryptedMessageCreate(BaseModel):
    recipient_user_id: int
    recipient_device_id: int | None = None
    sender_device_id: int
    ciphertext: str = Field(min_length=1)
    envelope_version: int = 1
    message_type: MessageType


class EncryptedMessageResponse(BaseModel):
    id: int
    sender_user_id: int
    sender_device_id: int
    recipient_user_id: int
    recipient_device_id: int | None
    ciphertext: str
    envelope_version: int
    message_type: str
    created_at: datetime

    model_config = {"from_attributes": True}
