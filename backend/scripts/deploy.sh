#!/usr/bin/env bash
# Deploy the backend to a remote server over SSH.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SSH_USER="${SSH_USER:-root}"
REMOTE_PATH="${REMOTE_PATH:-~/Companion/backend}"
BRANCH="${BRANCH:-main}"

cd "$BACKEND_ROOT"

read -r -p "Remote server IP or hostname: " SERVER_IP
if [[ -z "${SERVER_IP// }" ]]; then
  echo "Server IP or hostname is required." >&2
  exit 1
fi

read -r -p "SSH user [${SSH_USER}]: " SSH_USER_INPUT
if [[ -n "${SSH_USER_INPUT// }" ]]; then
  SSH_USER="$SSH_USER_INPUT"
fi

read -r -p "Remote backend path [${REMOTE_PATH}]: " REMOTE_PATH_INPUT
if [[ -n "${REMOTE_PATH_INPUT// }" ]]; then
  REMOTE_PATH="$REMOTE_PATH_INPUT"
fi

read -r -p "Git branch to deploy [${BRANCH}]: " BRANCH_INPUT
if [[ -n "${BRANCH_INPUT// }" ]]; then
  BRANCH="$BRANCH_INPUT"
fi

TARGET="${SSH_USER}@${SERVER_IP}"

echo ""
echo "Deploying Companion backend"
echo "  Target : ${TARGET}"
echo "  Path   : ${REMOTE_PATH}"
echo "  Branch : ${BRANCH}"
echo ""

ssh "$TARGET" "bash -s -- '$REMOTE_PATH' '$BRANCH'" < "$SCRIPT_DIR/deploy-remote.sh"

echo ""
echo "Remote deploy finished successfully."
