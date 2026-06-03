#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$APP_DIR"

rm -rf build/web

flutter build web \
  --release \
  --base-href /app/ \
  --output build/web/app \
  "$@"

mkdir -p build/web/m
cp web_landing/index.html build/web/index.html
cp web_landing/index.html build/web/m/index.html
cp -R web_landing/assets build/web/assets
cp -R web_landing/system build/web/system

printf 'Built RoomForge web shells:\n'
printf '  /      -> HTML landing\n'
printf '  /m     -> mobile HTML landing\n'
printf '  /app/  -> Flutter Web app\n'
