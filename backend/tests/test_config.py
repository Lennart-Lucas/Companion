from app.config import Settings, _database_url_for_host, _running_in_docker


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


def test_running_in_docker_from_env(monkeypatch):
    monkeypatch.setenv("IN_DOCKER", "1")
    assert _running_in_docker() is True


def test_database_url_keeps_db_host_in_docker(monkeypatch):
    monkeypatch.setenv("IN_DOCKER", "1")
    url = "postgresql+psycopg2://companion:companion@db:5432/companion"
    assert "@db:5432" in _database_url_for_host(url)


def test_database_url_rewrites_localhost_in_docker(monkeypatch):
    monkeypatch.setenv("IN_DOCKER", "1")
    url = "postgresql+psycopg2://companion:companion@localhost:5432/companion"
    assert "@db:5432" in _database_url_for_host(url)


def test_database_url_rewrites_db_host_on_host(monkeypatch):
    monkeypatch.delenv("IN_DOCKER", raising=False)
    url = "postgresql+psycopg2://companion:companion@db:5432/companion"
    assert "@localhost:5432" in _database_url_for_host(url)
