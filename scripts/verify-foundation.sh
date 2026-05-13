#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "== Flutter app =="
(cd "$ROOT_DIR/app" && flutter analyze)

echo "== TypeScript editor =="
(cd "$ROOT_DIR/editor" && npm run typecheck && npm test)

echo "== FastAPI server scaffold =="
(cd "$ROOT_DIR/server" && python3 -m compileall app tests)
if [[ -x "$ROOT_DIR/server/.venv/bin/python" ]]; then
  (cd "$ROOT_DIR/server" && .venv/bin/python -m pytest)
else
  echo "server/.venv not found; skipped server pytest. Run: cd server && python3 -m venv .venv && .venv/bin/python -m pip install -e '.[dev]'"
fi

echo "Foundation verification passed."
