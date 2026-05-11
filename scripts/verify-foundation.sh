#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "== Flutter app =="
(cd "$ROOT_DIR/app" && flutter analyze)

echo "== TypeScript editor =="
(cd "$ROOT_DIR/editor" && npm run typecheck && npm test)

echo "== FastAPI server scaffold =="
(cd "$ROOT_DIR/server" && python3 -m compileall app tests)

echo "Foundation verification passed."
