#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

run_rules_smoke() {
  local log_file
  log_file="$(mktemp -t roomforge-firebase-smoke.XXXXXX)"
  trap 'rm -f "$log_file"' RETURN

  if npm run test:firebase-rules:smoke 2>&1 | tee "$log_file"; then
    return 0
  fi

  if grep -Eiq \
    'Could not start emulator|port taken|Port .* is not open|EADDRINUSE|listen EPERM' \
    "$log_file"; then
    echo
    echo "Firebase emulator startup failed; retrying smoke against existing local emulators."
    npm run test:firebase-rules:smoke:direct
    return
  fi

  echo
  echo "Firebase rules smoke failed after emulator startup. Not retrying direct fallback."
  return 1
}

(
  cd app
  flutter test \
    test/src/api/backend_bindings_test.dart \
    test/src/projects/firebase_project_api_test.dart \
    test/src/admin/firebase_admin_access_repository_test.dart \
    test/src/admin/firebase_admin_diagnostics_test.dart
)

npm run check:legacy-api-isolation
npm run check:editor-firebase-boundary
run_rules_smoke
