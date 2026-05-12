#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/app"
EMULATOR_DATA_DIR=".firebase-emulator-data"

if [[ ! -f "$APP_DIR/firebase.json" ]]; then
  echo "app/firebase.json not found. Create Firebase emulator config before running emulator mode." >&2
  exit 1
fi

cd "$APP_DIR"
mkdir -p "$EMULATOR_DATA_DIR"

echo "Firebase Auth emulator: http://127.0.0.1:9099"
echo "Firebase Emulator UI: http://127.0.0.1:4000"
echo "Firebase emulator data directory: app/$EMULATOR_DATA_DIR"

firebase emulators:start \
  --only auth \
  --import "$EMULATOR_DATA_DIR" \
  --export-on-exit "$EMULATOR_DATA_DIR"
