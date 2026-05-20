#!/bin/sh
set -e

ROOT="$(git rev-parse --show-toplevel)"
HOOKS_PATH="backend/.githooks"

cd "$ROOT"
git config core.hooksPath "$HOOKS_PATH"
chmod +x backend/.githooks/post-merge 2>/dev/null || true

echo "Git hooks installed (core.hooksPath=$HOOKS_PATH)"
