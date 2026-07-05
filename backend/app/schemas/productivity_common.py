import re

from pydantic import BaseModel, Field, field_validator

COLOR_PATTERN = re.compile(r"^#[0-9A-Fa-f]{6}$")


def validate_name(value: str) -> str:
    stripped = value.strip()
    if not stripped:
        raise ValueError("name must not be empty")
    return stripped


def validate_color_optional(value: str | None) -> str | None:
    if value is None:
        return None
    if not COLOR_PATTERN.match(value):
        raise ValueError("color must be a hex color in #RRGGBB format")
    return value


class ProductivityListResponse(BaseModel):
    total: int
    limit: int
    offset: int
