#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/app"
DEFINE_FILE=".env"

if [[ ! -f "$APP_DIR/$DEFINE_FILE" ]]; then
  echo "app/.env not found. Using app/.env.example; Firebase app config values may be empty."
  DEFINE_FILE=".env.example"
fi

cd "$APP_DIR"
flutter run \
  -d chrome \
  --dart-define-from-file="$DEFINE_FILE" \
  --dart-define=ROOMFORGE_USE_FIREBASE_EMULATOR=true
