#!/usr/bin/env bash
set -euo pipefail

pattern='firebase|cloud_firestore|firebase_storage|@firebase|Firestore|StorageReference|FirebaseAuth'
targets=(editor/src editor/package.json)

if rg -n "$pattern" "${targets[@]}"; then
  echo "Forbidden Firebase reference found in editor boundary." >&2
  exit 1
fi

echo "Editor Firebase boundary check passed."
