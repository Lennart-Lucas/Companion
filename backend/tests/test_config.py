import os

from app.config import Settings


def test_cors_origins_empty_env_parses_to_empty_list(monkeypatch):
    monkeypatch.setenv("CORS_ORIGINS", "")
    settings = Settings()
    assert settings.cors_origin_list == []


def test_cors_origins_csv_parses_to_list(monkeypatch):
    monkeypatch.setenv(
        "CORS_ORIGINS",
        "http://localhost:3000, http://localhost:8080",
    )
    settings = Settings()
    assert settings.cors_origin_list == [
        "http://localhost:3000",
        "http://localhost:8080",
    ]


def test_cors_origins_default_when_unset(monkeypatch):
    monkeypatch.delenv("CORS_ORIGINS", raising=False)
    settings = Settings()
    assert "http://localhost:3000" in settings.cors_origin_list
