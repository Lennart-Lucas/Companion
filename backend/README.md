# Companion API

Python backend for the Companion monorepo, built with FastAPI, async SQLAlchemy 2.x, Alembic, and PostgreSQL.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) and Docker Compose
- Optional: `make` (Git Bash / WSL / Linux / macOS) for convenience targets
- Optional (local dev without Docker): Python 3.12+

## Environments

Two isolated Docker stacks can run **concurrently** on the same machine:

| | Dev | Prod (local) |
|---|-----|--------------|
| API | http://localhost:8000 | http://localhost:8001 |
| PostgreSQL | localhost:5432 | localhost:5433 |
| Hot reload | yes | no |
| Source bind-mount | yes | no |
| Compose project | `companion-dev` | `companion-prod` |

## Quick start

### Setup

Copy environment templates (once):

```bash
make setup
```

Windows (PowerShell):

```powershell
.\scripts\setup.ps1
```

This creates `.env.dev` and `.env.prod` from the example files if they do not exist.

### Development stack

```bash
make dev-up
```

Windows:

```powershell
.\scripts\dev.ps1 up
```

The dev API container automatically runs pending migrations and creates **temporary** local revisions when models drift from the database (see [Database migrations (automatic)](#database-migrations-automatic)).

- Liveness: http://localhost:8000/health
- Database: http://localhost:8000/health/db
- OpenAPI docs: http://localhost:8000/docs

### Production-like stack (local)

```bash
make prod-up
make prod-migrate
```

Windows:

```powershell
.\scripts\prod.ps1 up
.\scripts\prod.ps1 migrate
```

- Liveness: http://localhost:8001/health
- Database: http://localhost:8001/health/db
- OpenAPI docs: http://localhost:8001/docs

### Run both at once

```bash
make setup && make dev-up && make prod-up
make dev-migrate && make prod-migrate
```

Each stack has its own database volume and network — they do not share data.

## Database migrations (automatic)

### Dev startup

When the dev API container starts, it:

1. Applies all migrations (`alembic upgrade head`)
2. Compares SQLAlchemy models to the database
3. If schema drift is detected, creates a **temporary** revision in `alembic/versions/temp/` (gitignored) and applies it

Add new models under `app/models/` and import them in `app/models/__init__.py`. Restart or recreate the dev container to autogenerate temp migrations.

### Squash on merge

Install git hooks once (from the repository root):

```bash
make install-hooks
```

Windows:

```powershell
.\scripts\install-git-hooks.ps1
```

After merging into `main` or `develop`, the **post-merge** hook:

1. Downgrades the dev database to the last permanent revision
2. Deletes local temp migration files
3. Autogenerates **one permanent** revision in `alembic/versions/`
4. Applies it

**Permanent migration naming:** `NNN_<featureSlug>.py` (e.g. `002_security.py`). The numeric id increments from existing `001`, `002`, … revisions. The slug comes from the **merged branch name** (not the GitHub merge commit title). Override manually with `-m`:

```bash
python scripts/squash_migrations.py -m my_feature
```

```powershell
.\scripts\squash-migrations.ps1 -m my_feature
```

Review and commit the new permanent migration file.

Manual squash (requires dev Postgres on `localhost:5432`):

```bash
make squash-migrations
```

```powershell
.\scripts\squash-migrations.ps1
```

**Note:** Squash collapses **`temp_*`** migrations only. Combining multiple already-committed permanent files (e.g. after a feature branch) is still a manual delete + squash flow.

If squash fails because temp migrations are irreversible, reset the dev database:

```bash
docker compose -p companion-dev -f docker-compose.dev.yml down -v
make dev-up
make squash-migrations
```

**Note:** Squash only affects the local dev database. Production uses `make prod-migrate` with committed permanent revisions only.

## Common commands

| Task | Make | PowerShell |
|------|------|------------|
| Setup env files | `make setup` | `.\scripts\setup.ps1` |
| Start dev | `make dev-up` | `.\scripts\dev.ps1 up` |
| Stop dev | `make dev-down` | `.\scripts\dev.ps1 down` |
| Dev logs | `make dev-logs` | `.\scripts\dev.ps1 logs` |
| Dev migrate (manual) | `make dev-migrate` | `.\scripts\dev.ps1 migrate` |
| Autogen temp migration | `make migration-autogen` | — |
| Squash temp → permanent | `make squash-migrations` | `.\scripts\squash-migrations.ps1` |
| Install git hooks | `make install-hooks` | `.\scripts\install-git-hooks.ps1` |
| Start prod | `make prod-up` | `.\scripts\prod.ps1 up` |
| Stop prod | `make prod-down` | `.\scripts\prod.ps1 down` |
| Prod logs | `make prod-logs` | `.\scripts\prod.ps1 logs` |
| Prod migrate | `make prod-migrate` | `.\scripts\prod.ps1 migrate` |

## Local development (without Docker)

1. Start PostgreSQL locally (or run only the `db` service from a compose file).

2. Create a virtual environment and install dependencies:

   ```bash
   python -m venv .venv
   .venv\Scripts\activate   # Windows
   pip install -r requirements.txt
   ```

3. Copy `.env.dev.example` to `.env.dev` and set `DATABASE_URL` / `DATABASE_URL_SYNC` to use `localhost` instead of `db`.

4. Run migrations:

   ```bash
   alembic upgrade head
   ```

5. Start the server:

   ```bash
   uvicorn app.main:app --reload
   ```

## Project structure

```
app/           Application code (routes, models, schemas)
alembic/       Database migrations
docs/          Architecture documentation
scripts/       PowerShell helpers (Windows)
```

See [docs/architecture.md](docs/architecture.md) for design details.

## Security & API testing

Auth and E2E endpoints are under `/api/v1`. Configure `JWT_SECRET` and related variables in `.env.dev` (see `.env.dev.example`).

| Area | Endpoints |
|------|-----------|
| Auth | `POST /api/v1/auth/register`, `login`, `refresh`, `logout`; `GET /api/v1/auth/me` |
| E2E keys | `POST /api/v1/devices`, `GET /api/v1/users/{id}/keys`, `POST /api/v1/keys/prekeys` |
| E2E messages | `POST /api/v1/messages`, `GET /api/v1/messages` |

### Postman

1. Start the dev stack (`make dev-up` or `.\scripts\dev.ps1 up`).
2. In Postman: **Import** → select:
   - [docs/companion-api.postman_collection.json](docs/companion-api.postman_collection.json)
   - [docs/companion-api.postman_environment.json](docs/companion-api.postman_environment.json) (optional)
3. Select the **Companion API (dev)** environment.
4. Run **Auth → Register** or **Login** — tokens are saved automatically to collection variables.
5. Use **E2E Keys** and **E2E Messages** folders (require a second registered user for cross-user key/message tests; set `recipientUserId` accordingly).

See [docs/architecture.md](docs/architecture.md#security) for auth flow and E2E client responsibilities.
