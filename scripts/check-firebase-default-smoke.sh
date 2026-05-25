#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

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
npm run test:firebase-rules:smoke
