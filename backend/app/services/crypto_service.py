import base64
from datetime import UTC, datetime

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.config import settings
from app.models.device import Device
from app.models.encrypted_message import EncryptedMessage
from app.models.identity_key import IdentityKey
from app.models.onetime_prekey import OneTimePreKey
from app.models.signed_prekey import SignedPreKey
from app.models.user import User
from app.schemas.keys import (
    KeyBundleResponse,
    KeyBundleUpload,
    OneTimePreKeyInput,
    PreKeyUpload,
    SignedPreKeyInput,
)
from app.schemas.messages import EncryptedMessageCreate


def _decode_base64_size(data: str, max_bytes: int, field_name: str) -> None:
    try:
        decoded = base64.b64decode(data, validate=True)
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"{field_name} must be valid base64",
        ) from exc
    if len(decoded) == 0:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"{field_name} cannot be empty",
        )
    if len(decoded) > max_bytes:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"{field_name} exceeds maximum size of {max_bytes} bytes",
        )


def validate_public_key(public_key: str) -> None:
    _decode_base64_size(public_key, settings.max_public_key_bytes, "public_key")


def validate_ciphertext(ciphertext: str) -> None:
    _decode_base64_size(
        ciphertext, settings.max_ciphertext_bytes, "ciphertext"
    )


async def register_device(
    session: AsyncSession,
    user: User,
    bundle: KeyBundleUpload,
) -> Device:
    validate_public_key(bundle.identity_key)
    validate_public_key(bundle.signed_prekey.public_key)
    for prekey in bundle.one_time_prekeys:
        validate_public_key(prekey.public_key)

    existing = await session.execute(
        select(Device).where(
            Device.user_id == user.id,
            Device.device_id == bundle.device_id,
        )
    )
    if existing.scalar_one_or_none() is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Device already registered",
        )

    device = Device(
        user_id=user.id,
        device_id=bundle.device_id,
        label=bundle.label,
        registration_id=bundle.registration_id,
    )
    session.add(device)
    await session.flush()

    session.add(
        IdentityKey(device_id=device.id, public_key=bundle.identity_key)
    )
    session.add(
        SignedPreKey(
            device_id=device.id,
            key_id=bundle.signed_prekey.key_id,
            public_key=bundle.signed_prekey.public_key,
            signature=bundle.signed_prekey.signature,
        )
    )
    for prekey in bundle.one_time_prekeys:
        session.add(
            OneTimePreKey(
                device_id=device.id,
                key_id=prekey.key_id,
                public_key=prekey.public_key,
            )
        )
    await session.flush()
    return device


async def upload_prekeys(
    session: AsyncSession,
    user: User,
    upload: PreKeyUpload,
) -> int:
    for prekey in upload.one_time_prekeys:
        validate_public_key(prekey.public_key)

    device = await _get_user_device(session, user.id, upload.device_id)
    count = 0
    for prekey in upload.one_time_prekeys:
        session.add(
            OneTimePreKey(
                device_id=device.id,
                key_id=prekey.key_id,
                public_key=prekey.public_key,
            )
        )
        count += 1
    await session.flush()
    return count


async def _get_user_device(
    session: AsyncSession, user_id: int, device_id: int
) -> Device:
    result = await session.execute(
        select(Device).where(
            Device.user_id == user_id,
            Device.device_id == device_id,
        )
    )
    device = result.scalar_one_or_none()
    if device is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Device not found",
        )
    return device


async def fetch_key_bundle(
    session: AsyncSession,
    recipient_user_id: int,
    device_id: int | None = None,
) -> KeyBundleResponse:
    query = (
        select(Device)
        .where(Device.user_id == recipient_user_id)
        .options(
            selectinload(Device.identity_key),
            selectinload(Device.signed_prekeys),
            selectinload(Device.one_time_prekeys),
        )
    )
    if device_id is not None:
        query = query.where(Device.device_id == device_id)

    result = await session.execute(query)
    devices = result.scalars().all()
    if not devices:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No devices with keys found for user",
        )

    device = devices[0]
    if device.identity_key is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Device has no identity key",
        )

    if not device.signed_prekeys:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Device has no signed prekey",
        )

    signed = max(device.signed_prekeys, key=lambda k: k.created_at)

    one_time: OneTimePreKey | None = None
    for prekey in device.one_time_prekeys:
        if prekey.consumed_at is None:
            one_time = prekey
            break

    one_time_response: OneTimePreKeyInput | None = None
    if one_time is not None:
        one_time.consumed_at = datetime.now(UTC)
        one_time_response = OneTimePreKeyInput(
            key_id=one_time.key_id,
            public_key=one_time.public_key,
        )

    return KeyBundleResponse(
        user_id=recipient_user_id,
        device_id=device.device_id,
        registration_id=device.registration_id,
        identity_key=device.identity_key.public_key,
        signed_prekey=SignedPreKeyInput(
            key_id=signed.key_id,
            public_key=signed.public_key,
            signature=signed.signature,
        ),
        one_time_prekey=one_time_response,
    )


async def store_encrypted_message(
    session: AsyncSession,
    sender: User,
    payload: EncryptedMessageCreate,
) -> EncryptedMessage:
    validate_ciphertext(payload.ciphertext)

    recipient = await session.get(User, payload.recipient_user_id)
    if recipient is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Recipient not found",
        )

    if payload.recipient_device_id is not None:
        await _get_user_device(
            session, payload.recipient_user_id, payload.recipient_device_id
        )

    message = EncryptedMessage(
        sender_user_id=sender.id,
        sender_device_id=payload.sender_device_id,
        recipient_user_id=payload.recipient_user_id,
        recipient_device_id=payload.recipient_device_id,
        ciphertext=payload.ciphertext,
        envelope_version=payload.envelope_version,
        message_type=payload.message_type,
    )
    session.add(message)
    await session.flush()
    return message


async def fetch_inbox(
    session: AsyncSession,
    user_id: int,
    mark_delivered: bool = True,
) -> list[EncryptedMessage]:
    result = await session.execute(
        select(EncryptedMessage)
        .where(
            EncryptedMessage.recipient_user_id == user_id,
            EncryptedMessage.delivered_at.is_(None),
        )
        .order_by(EncryptedMessage.created_at.asc())
    )
    messages = list(result.scalars().all())
    if mark_delivered and messages:
        now = datetime.now(UTC)
        for message in messages:
            message.delivered_at = now
    return messages
