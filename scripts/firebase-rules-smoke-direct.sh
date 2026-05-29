#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

resolve_project_id() {
  if [[ -n "${GCLOUD_PROJECT:-}" ]]; then
    printf '%s\n' "$GCLOUD_PROJECT"
    return
  fi
  if [[ -n "${FIREBASE_PROJECT_ID:-}" ]]; then
    printf '%s\n' "$FIREBASE_PROJECT_ID"
    return
  fi
  if [[ -f app/.firebaserc ]]; then
    node -e "const fs=require('fs'); const rc=JSON.parse(fs.readFileSync('app/.firebaserc','utf8')); console.log(rc.projects.default);"
    return
  fi
  printf '%s\n' "roomforge-dev"
}

project_id="$(resolve_project_id)"

export GCLOUD_PROJECT="$project_id"
export FIREBASE_AUTH_EMULATOR_HOST="${FIREBASE_AUTH_EMULATOR_HOST:-127.0.0.1:9099}"
export FIRESTORE_EMULATOR_HOST="${FIRESTORE_EMULATOR_HOST:-127.0.0.1:8080}"
if [[ -z "${FIREBASE_STORAGE_EMULATOR_HOST:-}" && -z "${STORAGE_EMULATOR_HOST:-}" ]]; then
  export FIREBASE_STORAGE_EMULATOR_HOST="127.0.0.1:9199"
fi
export FIREBASE_STORAGE_BUCKET="${FIREBASE_STORAGE_BUCKET:-${project_id}.appspot.com}"

auth_origin="$FIREBASE_AUTH_EMULATOR_HOST"
if [[ "$auth_origin" != http* ]]; then
  auth_origin="http://$auth_origin"
fi
storage_endpoint="${FIREBASE_STORAGE_EMULATOR_HOST:-${STORAGE_EMULATOR_HOST:-}}"

echo "Running Firebase rules smoke directly against existing emulators:"
echo "  project: $GCLOUD_PROJECT"
echo "  auth: $FIREBASE_AUTH_EMULATOR_HOST"
echo "  firestore: $FIRESTORE_EMULATOR_HOST"
echo "  storage: $storage_endpoint"

node -e "
const url = process.argv[1];
fetch(url)
  .then(async (response) => {
    if (!response.ok) {
      console.error('FAIL auth-emulator-ready: expected HTTP 2xx, got HTTP ' + response.status);
      const body = await response.text();
      if (body.length > 0) console.error(body);
      process.exit(1);
    }
    console.log('PASS auth-emulator-ready: reachable with HTTP ' + response.status);
  })
  .catch((error) => {
    console.error('FAIL auth-emulator-ready: request failed');
    console.error(error);
    process.exit(1);
  });
" "$auth_origin/emulator/v1/projects/$GCLOUD_PROJECT/config"

node scripts/firebase-rules-smoke.mjs
