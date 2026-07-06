DEV_COMPOSE = docker compose -p companion-dev -f docker-compose.dev.yml
PROD_COMPOSE = docker compose -p companion-prod -f docker-compose.prod.yml

.PHONY: setup install-hooks dev-up dev-down dev-logs dev-migrate migration-autogen squash-migrations prod-up prod-down prod-logs prod-migrate deploy

setup:
	@test -f .env.dev || cp .env.dev.example .env.dev
	@test -f .env.prod || cp .env.prod.example .env.prod

dev-up:
	$(DEV_COMPOSE) up --build -d

dev-down:
	$(DEV_COMPOSE) down

dev-logs:
	$(DEV_COMPOSE) logs -f api

dev-migrate:
	$(DEV_COMPOSE) exec api alembic upgrade head

migration-autogen:
	$(DEV_COMPOSE) exec api python scripts/migration_autogen.py

squash-migrations:
	python scripts/squash_migrations.py

install-hooks:
	powershell -NoProfile -ExecutionPolicy Bypass -File scripts/install-git-hooks.ps1

prod-up:
	$(PROD_COMPOSE) up --build -d

prod-down:
	$(PROD_COMPOSE) down

prod-logs:
	$(PROD_COMPOSE) logs -f api

prod-migrate:
	$(PROD_COMPOSE) exec api alembic upgrade head

deploy:
	powershell -NoProfile -ExecutionPolicy Bypass -File scripts/deploy.ps1
