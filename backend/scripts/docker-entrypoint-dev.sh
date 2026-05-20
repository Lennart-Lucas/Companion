#!/bin/sh
set -e

export IN_DOCKER=1
cd /app

python scripts/migration_autogen.py

exec "$@"
