#!/bin/sh
set -e

export IN_DOCKER=1
export WORKER_PROCESS=1
cd /app

echo "Applying database migrations..."
if [ "${APP_ENV:-development}" = "development" ]; then
  python scripts/migration_autogen.py
else
  alembic upgrade head
fi

exec "$@"
