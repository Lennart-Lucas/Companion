import os
from functools import lru_cache

from pydantic import field_validator
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

    jwt_secret: str = "dev-only-change-in-production"
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 15
    refresh_token_expire_days: int = 30
    password_min_length: int = 8

    cors_origins: list[str] = ["http://localhost:3000", "http://localhost:8000"]
    # In development, allow any localhost port (Flutter web uses random ports).
    cors_allow_origin_regex: str | None = None

    max_public_key_bytes: int = 1024
    max_ciphertext_bytes: int = 65536

    job_poll_interval_seconds: int = 5
    job_batch_size: int = 10
    job_max_retries: int = 3
    job_retry_base_seconds: int = 60
    job_success_retention_seconds: int = 3600
    job_lock_timeout_seconds: int = 300
    job_schema_wait_timeout_seconds: int = 120

    @field_validator("cors_origins", mode="before")
    @classmethod
    def parse_cors_origins(cls, value: str | list[str]) -> list[str]:
        if isinstance(value, str):
            return [origin.strip() for origin in value.split(",") if origin.strip()]
        return value

    @property
    def is_production(self) -> bool:
        return self.app_env == "production"

    @property
    def effective_cors_origin_regex(self) -> str | None:
        if self.cors_allow_origin_regex:
            return self.cors_allow_origin_regex
        if not self.is_production:
            return r"http://(localhost|127\.0\.0\.1)(:\d+)?"
        return None


def _database_url_for_host(url: str) -> str:
    if os.environ.get("IN_DOCKER") != "1" and "@db:" in url:
        return url.replace("@db:", "@localhost:")
    return url


def get_database_url_sync() -> str:
    return _database_url_for_host(settings.database_url_sync)


def get_database_url_async() -> str:
    return _database_url_for_host(settings.database_url)


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
