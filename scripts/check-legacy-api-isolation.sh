#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

failures=0

check_empty() {
  local label="$1"
  local output="$2"
  if [[ -n "$output" ]]; then
    printf '%s\n%s\n' "$label" "$output" >&2
    failures=$((failures + 1))
  fi
}

project_api_constructors="$(
  rg -n '(^|[^A-Za-z])ProjectApi\(' app/lib \
    --glob '!app/lib/src/api/backend_bindings.dart' \
    --glob '!app/lib/src/projects/project_api.dart' || true
)"
check_empty \
  'ProjectApi construction must stay behind RoomForgeBackendBindings legacy_api selection:' \
  "$project_api_constructors"

legacy_project_api_constructors="$(
  rg -n '(^|[^A-Za-z])LegacyProjectApi\(' app/lib \
    --glob '!app/lib/src/api/backend_bindings.dart' \
    --glob '!app/lib/src/projects/project_api.dart' || true
)"
check_empty \
  'LegacyProjectApi construction must stay behind RoomForgeBackendBindings legacy_api selection:' \
  "$legacy_project_api_constructors"

admin_api_constructors="$(
  rg -n '(^|[^A-Za-z])AdminApi\(' app/lib \
    --glob '!app/lib/src/api/backend_bindings.dart' \
    --glob '!app/lib/src/admin/admin_api.dart' || true
)"
check_empty \
  'AdminApi construction must stay behind RoomForgeBackendBindings legacy_api selection:' \
  "$admin_api_constructors"

http_dependencies="$(
  rg -n "package:http|ApiConfig" app/lib \
    --glob '!app/lib/src/admin/admin_api.dart' \
    --glob '!app/lib/src/projects/project_api.dart' \
    --glob '!app/lib/src/api/api_config.dart' || true
)"
check_empty \
  'HTTP API dependencies must remain in legacy API adapter files:' \
  "$http_dependencies"

if [[ "$failures" -gt 0 ]]; then
  exit 1
fi

printf 'Legacy API isolation check passed.\n'
