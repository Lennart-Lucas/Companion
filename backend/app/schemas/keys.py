from datetime import datetime

from pydantic import BaseModel, Field


class OneTimePreKeyInput(BaseModel):
    key_id: int
    public_key: str = Field(min_length=1)


class SignedPreKeyInput(BaseModel):
    key_id: int
    public_key: str = Field(min_length=1)
    signature: str = Field(min_length=1)


class KeyBundleUpload(BaseModel):
    device_id: int
    label: str | None = None
    registration_id: int
    identity_key: str = Field(min_length=1)
    signed_prekey: SignedPreKeyInput
    one_time_prekeys: list[OneTimePreKeyInput] = Field(min_length=1)


class PreKeyUpload(BaseModel):
    device_id: int
    one_time_prekeys: list[OneTimePreKeyInput] = Field(min_length=1)


class DeviceResponse(BaseModel):
    id: int
    user_id: int
    device_id: int
    label: str | None
    registration_id: int
    created_at: datetime

    model_config = {"from_attributes": True}


class KeyBundleResponse(BaseModel):
    user_id: int
    device_id: int
    registration_id: int
    identity_key: str
    signed_prekey: SignedPreKeyInput
    one_time_prekey: OneTimePreKeyInput | None = None
