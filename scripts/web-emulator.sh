#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/app"
DEFINE_FILE=".env"
API_BASE_URL="${ROOMFORGE_API_BASE_URL:-http://127.0.0.1:8010}"
EDITOR_URL="${ROOMFORGE_EDITOR_URL:-http://127.0.0.1:9239}"

if [[ ! -f "$APP_DIR/$DEFINE_FILE" ]]; then
  echo "app/.env not found. Using app/.env.example; Firebase app config values may be empty."
  DEFINE_FILE=".env.example"
fi

cd "$APP_DIR"
flutter run \
  -d chrome \
  --dart-define-from-file="$DEFINE_FILE" \
  --dart-define=ROOMFORGE_USE_FIREBASE_EMULATOR=true \
  --dart-define=ROOMFORGE_API_BASE_URL="$API_BASE_URL" \
  --dart-define=ROOMFORGE_EDITOR_URL="$EDITOR_URL"
