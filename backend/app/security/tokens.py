import hashlib
import secrets
from datetime import UTC, datetime, timedelta
import jwt
from jwt.exceptions import InvalidTokenError

from app.config import settings


def hash_refresh_token(raw_token: str) -> str:
    return hashlib.sha256(raw_token.encode()).hexdigest()


def generate_refresh_token() -> str:
    return secrets.token_urlsafe(48)


def create_access_token(user_id: int, email: str) -> tuple[str, int]:
    expires_delta = timedelta(minutes=settings.access_token_expire_minutes)
    expire = datetime.now(UTC) + expires_delta
    payload = {
        "sub": str(user_id),
        "email": email,
        "exp": expire,
        "type": "access",
    }
    token = jwt.encode(
        payload,
        settings.jwt_secret,
        algorithm=settings.jwt_algorithm,
    )
    return token, int(expires_delta.total_seconds())


def decode_access_token(token: str) -> dict:
    try:
        payload = jwt.decode(
            token,
            settings.jwt_secret,
            algorithms=[settings.jwt_algorithm],
        )
    except InvalidTokenError as exc:
        raise ValueError("Invalid or expired access token") from exc
    if payload.get("type") != "access":
        raise ValueError("Invalid token type")
    return payload


def refresh_token_expires_at() -> datetime:
    return datetime.now(UTC) + timedelta(days=settings.refresh_token_expire_days)


def parse_user_id_from_token(payload: dict) -> int:
    sub = payload.get("sub")
    if sub is None:
        raise ValueError("Token missing subject")
    return int(sub)
