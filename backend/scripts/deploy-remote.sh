#!/usr/bin/env bash
# Runs on the remote server (piped via SSH from deploy.ps1 / deploy.sh).
set -euo pipefail

REMOTE_DIR="${1:?Remote backend directory is required}"
BRANCH="${2:-main}"

cd "$(eval echo "$REMOTE_DIR")"

echo "==> Working directory: $(pwd)"
echo "==> Fetching latest code (branch: ${BRANCH})..."
git fetch origin
git checkout "$BRANCH"
git pull --ff-only origin "$BRANCH"

echo "==> Rebuilding and starting production containers..."
docker compose -p companion-prod -f docker-compose.prod.yml up --build -d

echo "==> Running database migrations..."
docker compose -p companion-prod -f docker-compose.prod.yml exec -T api alembic upgrade head

echo "==> Deploy complete ($(git rev-parse --short HEAD))."
