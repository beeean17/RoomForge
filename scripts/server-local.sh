#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVER_DIR="$ROOT_DIR/server"
PORT="${ROOMFORGE_SERVER_PORT:-8010}"

cd "$SERVER_DIR"

if [[ ! -x ".venv/bin/python" ]]; then
  echo "server/.venv not found. Creating it and installing server dev dependencies."
  python3 -m venv .venv
  .venv/bin/python -m pip install -e '.[dev]'
fi

echo "RoomForge API: http://127.0.0.1:$PORT"
echo "Mode: in-memory repositories, Firebase Auth emulator at 127.0.0.1:9099"

ROOMFORGE_USE_IN_MEMORY_REPOSITORIES=true \
ROOMFORGE_FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 \
ROOMFORGE_API_ENVIRONMENT=local \
.venv/bin/python -m uvicorn app.main:app --reload --host 127.0.0.1 --port "$PORT"
