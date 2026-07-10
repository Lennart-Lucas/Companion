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

The dev stack also starts a **worker** container that processes background jobs from PostgreSQL (see [Async jobs](#async-jobs)).

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

## Server deployment (production)

Deploy on a Linux host with Docker using `docker-compose.prod.yml` (compose project `companion-prod`). The API listens on host port **8001**; Postgres on **5433**.

### First-time setup

```bash
cd ~/Companion/backend
cp .env.prod.example .env.prod
docker compose -p companion-prod -f docker-compose.prod.yml up --build -d
docker compose -p companion-prod -f docker-compose.prod.yml exec api alembic upgrade head
```

The **worker** service should set `PYTHONPATH=/app` so startup migrations can import the `app` package (see `docker-compose.prod.yml`).

### Update after `git pull`

Production servers should track **`origin/main` exactly** (no local commits). Use fetch + reset instead of `git pull` so divergent history on the host does not block deploys:

From the repository root:

```bash
cd ~/Companion
git fetch origin
git reset --hard origin/main
cd backend
docker compose -p companion-prod -f docker-compose.prod.yml up --build -d
docker compose -p companion-prod -f docker-compose.prod.yml exec api alembic upgrade head
```

**One-liner** (from `~`):

```bash
cd ~/Companion && git fetch origin && git reset --hard origin/main && cd backend && docker compose -p companion-prod -f docker-compose.prod.yml up --build -d && docker compose -p companion-prod -f docker-compose.prod.yml exec api alembic upgrade head
```

If you are already in `~/Companion/backend`:

```bash
cd ~/Companion && git fetch origin && git reset --hard origin/main && cd backend && docker compose -p companion-prod -f docker-compose.prod.yml up --build -d && docker compose -p companion-prod -f docker-compose.prod.yml exec api alembic upgrade head
```

To see what would be discarded before resetting: `git log --oneline origin/main..HEAD` (commits only on the server).

### Verify

```bash
curl -s http://localhost:8001/health
curl -s http://localhost:8001/health/db
docker compose -p companion-prod -f docker-compose.prod.yml ps
docker compose -p companion-prod -f docker-compose.prod.yml logs --tail=30 api
docker compose -p companion-prod -f docker-compose.prod.yml logs --tail=30 worker
```

### Server troubleshooting

**Worker: `ModuleNotFoundError: No module named 'app'`** — Add to the worker service in `docker-compose.prod.yml`:

```yaml
environment:
  PYTHONPATH: /app
```

Then rebuild the worker: `docker compose -p companion-prod -f docker-compose.prod.yml up -d --build worker`.

**API: `Child process died` on a small VPS** — Use one Uvicorn worker in `docker-compose.prod.yml`:

```yaml
command: uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 1
```

**Do not wipe production data** — Avoid `docker compose ... down -v` unless you intend to delete the database volume.

**Alembic / API startup: `SettingsError: error parsing value for field "cors_origins"`** — `.env.prod` has `CORS_ORIGINS=` with no value. Docker injects an empty string; older images treat that field as JSON and fail before migrations run.

Fix on the server (either is enough):

```bash
# Option A: remove the empty line (recommended)
nano ~/Companion/backend/.env.prod   # delete the CORS_ORIGINS= line, or comment it out

# Option B: set a valid value (comma-separated on current main)
CORS_ORIGINS=https://your-frontend.example.com
```

Then rebuild and migrate:

```bash
cd ~/Companion/backend
docker compose -p companion-prod -f docker-compose.prod.yml up --build -d
docker compose -p companion-prod -f docker-compose.prod.yml exec api alembic upgrade head
```

On `main`, `CORS_ORIGINS` is a comma-separated string (not JSON). An empty value is allowed after rebuild; leaving the variable unset uses the default dev origins.

**Alembic: `connection to server at "localhost" … Connection refused`** — Alembic is connecting to `localhost` inside a container. Check `.env.prod`:

```env
DATABASE_URL_SYNC=postgresql+psycopg2://companion:companion@db:5432/companion
```

Use host `db`, not `localhost`. Pull latest `main`, rebuild (`docker compose … up --build -d`), then migrate. Recent images auto-detect Docker and rewrite mistaken `localhost:5432` to `db:5432` for in-container commands.

**Alembic: `Can't locate revision identified by '018_quota_check_in'`** — The database was migrated from the old `productivity` branch, but `main` only has migrations through `017_tracker_timer_started`. Point Alembic at `main`'s head, then verify:

```bash
cd ~/Companion/backend
docker compose -p companion-prod -f docker-compose.prod.yml exec api alembic stamp 017_tracker_timer_started
docker compose -p companion-prod -f docker-compose.prod.yml exec api alembic upgrade head
```

If `stamp` fails, set the version directly in Postgres:

```bash
docker compose -p companion-prod -f docker-compose.prod.yml exec db \
  psql -U companion -d companion \
  -c "UPDATE alembic_version SET version_num = '017_tracker_timer_started';"
```

Then run `alembic upgrade head` again. Extra columns from the old `018` migration (if applied) are harmless on `main`; the app does not use them.

**Goal save returns 500 / Internal server error** — Check the API error body (after redeploy it includes the real message) and logs:

```bash
docker compose -p companion-prod -f docker-compose.prod.yml logs --tail=80 api
```

Verify goal schema exists:

```bash
docker compose -p companion-prod -f docker-compose.prod.yml exec db \
  psql -U companion -d companion -c "\d goal_milestones"
docker compose -p companion-prod -f docker-compose.prod.yml exec db \
  psql -U companion -d companion -c "\d goals"
```

If `goal_milestones` is missing, pull latest `main` and run `alembic upgrade head` (migration `018_goal_schema_repair` creates it when absent).

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

## Async jobs

Background tasks are stored in PostgreSQL (`async_jobs`, `async_job_errors`) and executed by a separate **worker** process. The API enqueues work via `job_service.enqueue()`; handlers are registered with `@register_task` in `app/jobs/tasks/`.

| Component | Location |
|-----------|----------|
| Enqueue | `app/services/job_service.py` |
| Worker loop | `app/jobs/worker.py` |
| Run worker (local) | `python scripts/run_worker.py` |
| Example task | `app/jobs/tasks/example.py` (`task_name`: `example`) |

### Verify the worker (dev)

With the dev stack running (`make dev-up`):

```bash
docker compose -p companion-dev -f docker-compose.dev.yml exec api python scripts/enqueue_example_job.py
docker compose -p companion-dev -f docker-compose.dev.yml logs -f worker
```

You should see the worker log job completion. Completed rows are deleted after `JOB_SUCCESS_RETENTION_SECONDS` (default 1 hour). For a quicker cleanup test, set `JOB_SUCCESS_RETENTION_SECONDS=10` in `.env.dev` and restart the worker.

Without Docker (API + Postgres + worker on the host):

```bash
alembic upgrade head
python scripts/enqueue_example_job.py
python scripts/run_worker.py
```

See [docs/architecture.md](docs/architecture.md#async-jobs) for lifecycle, retries, and adding new tasks.

### Troubleshooting

**`relation "async_jobs" does not exist`** — The worker starts before migrations have been applied. Rebuild and restart (`docker compose ... up --build`). The worker entrypoint runs migrations on startup; if the API failed to migrate, fix the API logs first.

**`duplicate key value violates unique constraint "pg_class_relname_nsp_index"` (e.g. `schedules_id_seq`)** — The API and worker both ran `alembic upgrade` at the same time. The worker often finishes first; restarting the stack is usually enough (`docker compose ... up --build`). Migrations now use a Postgres advisory lock so this should not recur. If the API container still exits on startup, check `SELECT version_num FROM alembic_version` and that `schedules` exists — you may already be on `004` with a healthy schema.

**`Can't locate revision identified by 'temp_…'`** — The dev database still points at a **temporary** autogenerated revision that was removed from disk (e.g. after squash or deleting `alembic/versions/temp/`). Either reset the dev database:

```bash
docker compose -p companion-dev -f docker-compose.dev.yml down -v
make dev-up
```

Or realign the version and apply permanent migrations (when `async_jobs` does not exist yet):

```bash
docker compose -p companion-dev -f docker-compose.dev.yml exec db psql -U companion -d companion -c "UPDATE alembic_version SET version_num = '002';"
docker compose -p companion-dev -f docker-compose.dev.yml run --rm --entrypoint "" api sh -c "alembic upgrade head"
docker compose -p companion-dev -f docker-compose.dev.yml restart worker
```

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

5. Start the server and worker (separate terminals):

   ```bash
   uvicorn app.main:app --reload
   python scripts/run_worker.py
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
| Schedules | `POST/GET/PATCH/DELETE /api/v1/schedules`, `POST .../preview`, `PUT .../specific-dates`, `PUT .../exclusions`, `POST/DELETE .../overrides` |
| Goals | `POST/GET/PATCH/DELETE /api/v1/goals`; `GET/PATCH .../goals/{id}/check-ins`; milestone CRUD under `.../milestones` |
| Projects | `POST/GET/PATCH/DELETE /api/v1/projects` |
| Tasks | `POST/GET/PATCH/DELETE /api/v1/tasks`; `GET .../occurrences`; `PATCH .../occurrences/{id}`; `PUT .../subtasks`; `PATCH .../subtasks/{id}` |
| Trackers | `POST/GET/PATCH/DELETE /api/v1/trackers`; `GET/PATCH .../trackers/{id}/check-ins` |

### Schedules (preview example)

After login, create a schedule and preview occurrences:

```bash
curl -X POST http://localhost:8000/api/v1/schedules \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"repeat_type":"every_n_days","interval":1,"anchor_at":"2026-05-21T09:00:00+02:00","timezone":"Europe/Amsterdam"}'

curl -X POST http://localhost:8000/api/v1/schedules/1/preview \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"from":"2026-05-21T00:00:00Z","to":"2026-06-21T00:00:00Z","max_count":10}'
```

See [docs/architecture.md](docs/architecture.md#scheduling) for repeat types, exclusions, and overrides.

### Productivity (example)

```bash
curl -X POST http://localhost:8000/api/v1/goals \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"Ship v1","color":"#3366FF","icon":"target"}'

curl -X POST http://localhost:8000/api/v1/tasks \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"Daily standup","schedule":{"repeat_type":"every_n_days","interval":1,"anchor_at":"2026-05-21T09:00:00Z","timezone":"UTC"},"subtasks":[{"title":"Prep agenda","sort_order":0}],"priority":"high"}'

curl "http://localhost:8000/api/v1/tasks/1/occurrences?from=2026-05-21T00:00:00Z&to=2026-05-28T00:00:00Z" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

See [docs/architecture.md](docs/architecture.md#productivity-entities) for parent rules, status/priority, and per-occurrence subtasks.

### Unit tests

```bash
pip install -r requirements.txt
python -m pytest tests/ -v
```

### Postman

1. Start the dev stack (`make dev-up` or `.\scripts\dev.ps1 up`).
2. In Postman: **Import** → select:
   - [docs/companion-api.postman_collection.json](docs/companion-api.postman_collection.json)
   - [docs/companion-api.postman_environment.json](docs/companion-api.postman_environment.json) (optional)
3. Select the **Companion API (dev)** environment.
4. Run **Auth → Register** or **Login** — tokens are saved automatically to collection variables.
5. Use **E2E Keys** and **E2E Messages** folders (require a second registered user for cross-user key/message tests; set `recipientUserId` accordingly).

See [docs/architecture.md](docs/architecture.md#security) for auth flow and E2E client responsibilities.
