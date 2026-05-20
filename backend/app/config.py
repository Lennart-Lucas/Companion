import os

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=(".env", ".env.dev"),
        env_file_encoding="utf-8",
        extra="ignore",
    )

    app_env: str = "development"
    debug: bool = False
    api_prefix: str = "/api/v1"

    database_url: str = (
        "postgresql+asyncpg://companion:companion@localhost:5432/companion"
    )
    database_url_sync: str = (
        "postgresql+psycopg2://companion:companion@localhost:5432/companion"
    )


def get_database_url_sync() -> str:
    url = settings.database_url_sync
    if os.environ.get("IN_DOCKER") != "1" and "@db:" in url:
        return url.replace("@db:", "@localhost:")
    return url


settings = Settings()
