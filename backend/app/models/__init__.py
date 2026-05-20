"""Import all model modules here so Alembic autogenerate discovers them."""

from app.models.base import Base
from app.models.user import User

__all__ = ["Base", "User"]
