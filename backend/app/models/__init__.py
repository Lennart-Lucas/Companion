"""Import all model modules here so Alembic autogenerate discovers them."""

from app.models.async_job import AsyncJob
from app.models.async_job_error import AsyncJobError
from app.models.base import Base
from app.models.device import Device
from app.models.encrypted_message import EncryptedMessage
from app.models.identity_key import IdentityKey
from app.models.onetime_prekey import OneTimePreKey
from app.models.refresh_token import RefreshToken
from app.models.signed_prekey import SignedPreKey
from app.models.user import User

__all__ = [
    "AsyncJob",
    "AsyncJobError",
    "Base",
    "Device",
    "EncryptedMessage",
    "IdentityKey",
    "OneTimePreKey",
    "RefreshToken",
    "SignedPreKey",
    "User",
]
