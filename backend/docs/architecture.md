# Companion API — Architecture

## Overview

The Companion backend is the API layer of the Companion monorepo. It exposes HTTP endpoints for the frontend and other clients, persists data in PostgreSQL, and manages schema changes through Alembic migrations.

The stack is intentionally small and conventional: **FastAPI** for HTTP, **async SQLAlchemy 2.x** for database access at runtime, **Alembic** for schema migrations, and **PostgreSQL** as the primary datastore.

## Layered design

```
┌─────────────────────────────────────────┐
│  HTTP (FastAPI routes)                  │  app/api/routes/
├─────────────────────────────────────────┤
│  Schemas (Pydantic request/response)    │  app/schemas/
├─────────────────────────────────────────┤
│  Services (business logic, future)      │  app/services/  (not yet)
├─────────────────────────────────────────┤
│  Models (SQLAlchemy ORM)                │  app/models/
├─────────────────────────────────────────┤
│  Database (async engine + sessions)     │  app/database.py
└─────────────────────────────────────────┘
                    │
                    ▼
              PostgreSQL
```

New features should flow **downward**: define or extend models, add service functions if logic grows beyond a thin route, expose via schemas and routes.

## Request flow

```mermaid
sequenceDiagram
    participant Client
    participant FastAPI
    participant Route
    participant Depends as get_db
    participant Session as AsyncSession
    participant DB as PostgreSQL

    Client->>FastAPI: HTTP request
    FastAPI->>Route: dispatch handler
    Route->>Depends: inject session
    Depends->>Session: open async session
    Route->>Session: query / execute
    Session->>DB: async SQL via asyncpg
    DB-->>Session: result
    Session-->>Route: data
    Route-->>FastAPI: Pydantic response
    FastAPI-->>Client: JSON
    Depends->>Session: commit or rollback
```

Health endpoints illustrate two patterns:

- **`GET /health`** — no database; confirms the process is running.
- **`GET /health/db`** — uses `get_db` to run `SELECT 1`, confirming connectivity to PostgreSQL.

## Configuration

Settings live in `app/config.py` and load from environment variables (and optionally `.env` via `python-dotenv`).

| Variable | Purpose |
|----------|---------|
| `APP_ENV` | Environment name (`development`, `production`, …) |
| `DEBUG` | Enables SQL echo and verbose behavior when true |
| `DATABASE_URL` | Async connection string (`postgresql+asyncpg://…`) |
| `DATABASE_URL_SYNC` | Sync connection string for Alembic (`postgresql+psycopg2://…`) |
| `JWT_SECRET` | Secret for signing access tokens (required in production) |
| `JWT_ALGORITHM` | JWT algorithm (default `HS256`) |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | Access token lifetime (default 15) |
| `REFRESH_TOKEN_EXPIRE_DAYS` | Refresh token lifetime (default 30) |
| `PASSWORD_MIN_LENGTH` | Minimum password length (default 8) |
| `CORS_ORIGINS` | Comma-separated allowed origins for CORS |
| `JOB_POLL_INTERVAL_SECONDS` | Worker sleep between poll iterations (default 5) |
| `JOB_BATCH_SIZE` | Max jobs claimed per iteration (default 10) |
| `JOB_MAX_RETRIES` | Default max retries per job (default 3) |
| `JOB_RETRY_BASE_SECONDS` | Linear backoff multiplier after failure (default 60) |
| `JOB_SUCCESS_RETENTION_SECONDS` | Delete completed jobs after this TTL (default 3600) |
| `JOB_LOCK_TIMEOUT_SECONDS` | Reclaim stale `running` jobs after this age (default 300) |

### Docker networking

Inside Docker Compose, the API service reaches PostgreSQL at hostname **`db`** (the service name). Connection strings in `.env.dev` / `.env.prod` use `db` as the host. When running the API on the host machine against a containerized database, use `localhost` and the published port (`5432` for dev, `5433` for prod).

## Local environments

Two Docker Compose stacks support parallel local development and production-like testing:

| Stack | Compose file | Project name | API port | DB port (host) |
|-------|--------------|--------------|----------|----------------|
| Dev | `docker-compose.dev.yml` | `companion-dev` | 8000 | 5432 |
| Prod (local) | `docker-compose.prod.yml` | `companion-prod` | 8001 | 5433 |

```mermaid
flowchart TB
  subgraph devStack [companion-dev]
    devApi[api :8000]
    devWorker[worker]
    devDb[(db :5432)]
    devApi --> devDb
    devWorker --> devDb
  end
  subgraph prodStack [companion-prod]
    prodApi[api :8001]
    prodWorker[worker]
    prodDb[(db :5433)]
    prodApi --> prodDb
    prodWorker --> prodDb
  end
```

**Dev** — hot reload (`--reload`), source bind-mounts for `app/` and `alembic/`, `DEBUG=true`. Use for day-to-day feature work.

**Prod (local)** — no bind-mounts, multiple Uvicorn workers, `DEBUG=false`. Use to verify production-like behavior before deployment.

Each stack is fully isolated: separate Compose project, Docker network, and Postgres volume (`postgres_data_dev` vs `postgres_data_prod`). They can run simultaneously without port or data conflicts.

Start/stop via `make dev-up` / `make prod-up` or `scripts/dev.ps1` / `scripts/prod.ps1` on Windows.

## Async runtime vs sync migrations

| Concern | Driver | URL prefix | Used by |
|---------|--------|------------|---------|
| Application runtime | `asyncpg` | `postgresql+asyncpg://` | FastAPI, `app/database.py` |
| Migrations | `psycopg2` | `postgresql+psycopg2://` | Alembic CLI, `alembic/env.py` |

FastAPI is async-first; blocking the event loop on database I/O would hurt throughput. **Async SQLAlchemy** with `asyncpg` keeps request handlers non-blocking.

Alembic’s CLI and migration scripts are traditionally **synchronous**. Using a sync engine and `psycopg2` for migrations avoids extra async boilerplate in `env.py` while sharing the same PostgreSQL database and schema as the app.

Both URLs point at the same database; only the driver differs.

## Migrations workflow

### Permanent vs temporary revisions

| Type | Location | Git | When created |
|------|----------|-----|--------------|
| Permanent | `alembic/versions/*.py` | Committed | After merge to `main`/`develop` (squash) |
| Temporary | `alembic/versions/temp/*.py` | Gitignored (local only) | Dev container startup when models drift |

```mermaid
flowchart LR
  models[Model change] --> devStart[dev container start]
  devStart --> compare{Schema drift?}
  compare -->|yes| tempRev[temp revision in versions/temp]
  compare -->|no| uvicorn[uvicorn --reload]
  tempRev --> uvicorn
  merge[Merge to main] --> squash[post-merge hook]
  squash --> permRev[permanent revision in versions/]
```

### Day-to-day (feature branch)

1. **Change models** — add or edit SQLAlchemy models under `app/models/` and import them in `app/models/__init__.py`.
2. **Restart dev** — `make dev-up` (or recreate the API container). The entrypoint runs `scripts/migration_autogen.py`, which applies migrations and creates a temp revision if needed.
3. **Iterate** — each model change on restart adds another local temp revision (linear chain under `temp_` prefix).

### Merge (main / develop)

1. **Install hooks** — `make install-hooks` or `.\backend\scripts\install-git-hooks.ps1` from repo root (one-time).
2. **Merge branch** — post-merge hook runs `scripts/squash_migrations.py`:
   - Downgrades dev DB to the last permanent head
   - Deletes `alembic/versions/temp/*`
   - Autogenerates one permanent revision from model diff
   - Names it `NNN_<branchSlug>.py` (next 3-digit id + slug from merged branch, e.g. `003_security.py`)
   - Upgrades to head
3. **Review and commit** the new file in `alembic/versions/`.

Slug resolution order: CLI `-m` flag → merged branch name (`HEAD^2`) → parsed merge commit subject → `schema_update`.

Manual squash: `make squash-migrations` or `python scripts/squash_migrations.py -m feature_name` (dev DB must be reachable on `localhost:5432`).

Squash only replaces **`temp_*`** revisions. Multiple committed permanent files on a branch must be consolidated manually (delete old files, downgrade DB, run squash).

### Production

Run `make prod-migrate` — applies only **committed** permanent revisions. No autogenerate on prod startup.

The initial revision (`001_initial`) is an empty baseline so `alembic_version` is tracked from the first deploy.

## Application lifecycle

`app/main.py` registers a **lifespan** context manager that disposes the async engine on shutdown, closing pooled connections cleanly.

## Extension points

| Need | Where to add |
|------|----------------|
| New endpoint | `app/api/routes/<resource>.py`, include router in `main.py` |
| Request/response types | `app/schemas/` |
| Tables / relationships | `app/models/`, then autogenerate migration |
| Shared DB access in routes | `Depends(get_db)` from `app/dependencies.py` |
| Cross-route business logic | `app/services/` (recommended as the app grows) |
| Background work | `job_service.enqueue()` + task in `app/jobs/tasks/` |
| Auth / middleware | FastAPI middleware or dependencies in `app/dependencies.py` |

## Async jobs

Background work uses a **PostgreSQL-backed job queue** and a dedicated **worker** process (not in-process FastAPI background tasks). This avoids duplicate polling when the API runs multiple Uvicorn workers.

```mermaid
flowchart TB
  subgraph api [api]
    Svc[services]
    Enq[job_service.enqueue]
    Svc --> Enq
  end
  subgraph db [PostgreSQL]
    Jobs[(async_jobs)]
    Errors[(async_job_errors)]
  end
  subgraph worker [worker]
    Poll[claim batch SKIP LOCKED]
    Reg[task registry]
    Exec[execute handler]
    Clean[delete completed past retention]
    Poll --> Reg --> Exec
    Poll --> Clean
  end
  Enq --> Jobs
  Poll --> Jobs
  Exec -->|failure| Errors
  Clean --> Jobs
```

### Tables

- **`async_jobs`** — `task_name`, JSON `parameters`, `status` (`pending` / `running` / `completed` / `failed`), retry counters, scheduling and lock metadata.
- **`async_job_errors`** — one row per failed attempt (`message`, optional `detail` traceback).

### Lifecycle

1. **Enqueue** — `job_service.enqueue(session, task_name, parameters)` inserts a `pending` row with `scheduled_at = now()`.
2. **Claim** — worker selects eligible `pending` rows (`scheduled_at <= now`, `retry_count < max_retries`) with `FOR UPDATE SKIP LOCKED`, marks them `running`.
3. **Execute** — handler from `@register_task("name")` in `app/jobs/tasks/` runs with the job parameters and a DB session.
4. **Success** — status `completed`; row deleted after `JOB_SUCCESS_RETENTION_SECONDS`.
5. **Failure** — append `async_job_errors`, increment `retry_count`, reschedule with linear backoff (`retry_count * JOB_RETRY_BASE_SECONDS`) or mark `failed` when max retries exceeded.
6. **Stale locks** — `running` jobs older than `JOB_LOCK_TIMEOUT_SECONDS` are reset to `pending` (crashed worker recovery).
7. **Unknown task** — permanent `failed` (no retry loop).

There is no public REST API for jobs in v1; enqueue from services only.

### Adding a task

1. Create `app/jobs/tasks/my_task.py` with `@register_task("my_task")`.
2. Import the module in `app/jobs/tasks/__init__.py`.
3. Call `await job_service.enqueue(session, "my_task", {...})` from a service or route.

The bundled **`example`** task is a no-op for wiring checks.

## Infrastructure (local)

Each environment runs API, worker, and database containers:

```mermaid
flowchart LR
  subgraph devEnv [companion-dev]
    devClient[Client] --> devApi[api :8000]
    devApi --> devDb[(postgres :5432)]
    devWorker[worker] --> devDb
  end
  subgraph prodEnv [companion-prod]
    prodClient[Client] --> prodApi[api :8001]
    prodApi --> prodDb[(postgres :5433)]
    prodWorker[worker] --> prodDb
  end
```

- **`api`** — builds from `Dockerfile`, runs Uvicorn (reload in dev, workers in prod).
- **`worker`** — same image; entrypoint runs `alembic upgrade head`, then `python scripts/run_worker.py`. Polls `async_jobs` after schema is ready.
- **`db`** — `postgres:16-alpine` with a per-environment named volume.
- **`api`** and **`worker`** both wait for **`db`** healthcheck; each applies migrations on startup (dev API also autogenerates temp revisions when models drift).

Production deployments will likely mirror this split (stateless API service + managed PostgreSQL) with environment-specific secrets and networking.

## Security

### Authentication

Auth endpoints live under `/api/v1/auth`. The API uses **JWT access tokens** (short-lived) and **opaque refresh tokens** (stored hashed in PostgreSQL, revocable on logout).

```mermaid
sequenceDiagram
    participant Client
    participant API
    participant DB
    Client->>API: POST /auth/register or /login
    API->>DB: Create user / verify password
    API->>DB: Store refresh token hash
    API-->>Client: access_token + refresh_token
    Client->>API: GET /auth/me (Authorization Bearer)
    API-->>Client: User profile
    Client->>API: POST /auth/refresh
    API->>DB: Revoke old refresh, issue new pair
    Client->>API: POST /auth/logout
    API->>DB: Set revoked_at on refresh token
```

| Endpoint | Auth | Purpose |
|----------|------|---------|
| `POST /api/v1/auth/register` | Public | Create account |
| `POST /api/v1/auth/login` | Public | Obtain tokens |
| `POST /api/v1/auth/refresh` | Public | Rotate refresh token |
| `POST /api/v1/auth/logout` | Bearer | Revoke refresh token(s) |
| `GET /api/v1/auth/me` | Bearer | Auth check + profile |

Passwords are hashed with **Argon2id** (argon2-cffi). Login errors are generic (`Invalid email or password`) to avoid account enumeration.

`get_current_user` and `get_current_active_user` in `app/dependencies.py` protect E2E and other private routes.

### End-to-end encryption (server role)

The server **never stores plaintext message content or private keys**. Clients encrypt locally; the API relays **public key bundles** and **ciphertext blobs**.

| Endpoint | Purpose |
|----------|---------|
| `POST /api/v1/devices` | Register device + upload identity/signed/one-time prekeys |
| `GET /api/v1/users/{user_id}/keys` | Fetch recipient public key bundle (consumes one one-time prekey) |
| `POST /api/v1/keys/prekeys` | Upload additional one-time prekeys |
| `POST /api/v1/messages` | Store encrypted payload for a recipient |
| `GET /api/v1/messages` | Fetch undelivered inbox (marks delivered on read) |

Public keys and ciphertext must be **base64** with size limits (`MAX_PUBLIC_KEY_BYTES`, `MAX_CIPHERTEXT_BYTES` in config). Future clients should implement the cryptographic protocol (e.g. Double Ratchet); the backend only provides storage and discovery.

### Hardening

- **CORS** — configurable via `CORS_ORIGINS`
- **Rate limiting** — auth register/login limited (slowapi)
- **Security headers** — `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`
- **OpenAPI docs** — disabled when `APP_ENV=production`

Health checks remain at `/health` (no auth) for load balancers.

### API testing

Import [`companion-api.postman_collection.json`](companion-api.postman_collection.json) and optionally [`companion-api.postman_environment.json`](companion-api.postman_environment.json) into Postman. Register/Login requests auto-save `accessToken` and `refreshToken` to collection variables.
