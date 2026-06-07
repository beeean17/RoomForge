---
title: "RoomForge Firebase Local Baseline"
status: "complete"
created: "2026-05-24"
updated: "2026-05-24"
storyId: "FES-1.1"
---

# Firebase Local Baseline

This document records the local Firebase baseline for `FES-1.1 - Configure Firebase Emulators and Project Baseline`.

## Backend Modes

The default RoomForge backend mode is:

```text
firebase
```

The legacy FastAPI/Oracle path is explicit-only:

```text
legacy_api
```

Flutter reads the intended mode from this Dart define:

```bash
--dart-define=ROOMFORGE_BACKEND_MODE=firebase
```

If the define is omitted, Flutter defaults to `firebase`. Use `legacy_api` only for intentional legacy reference or fallback work.

## Required Firebase Defines

The existing Firebase Auth bootstrap uses these Dart defines:

```bash
--dart-define=ROOMFORGE_FIREBASE_API_KEY=...
--dart-define=ROOMFORGE_FIREBASE_APP_ID=...
--dart-define=ROOMFORGE_FIREBASE_MESSAGING_SENDER_ID=...
--dart-define=ROOMFORGE_FIREBASE_PROJECT_ID=...
--dart-define=ROOMFORGE_FIREBASE_AUTH_DOMAIN=...
--dart-define=ROOMFORGE_FIREBASE_STORAGE_BUCKET=...
```

For local emulator use:

```bash
--dart-define=ROOMFORGE_USE_FIREBASE_EMULATOR=true
```

## Local Emulator Command

Run Firebase emulators from the Flutter app directory:

```bash
cd app
firebase emulators:start --only auth,firestore,storage,hosting
```

Configured local ports:

| Service | Port |
| --- | --- |
| Auth | `9099` |
| Firestore | `8080` |
| Storage | `9199` |
| Hosting | `5002` |
| Emulator UI | `4000` |

## Rules Baseline

The FES-1.1 rules baseline is deny-by-default:

- unauthenticated Firestore access is denied;
- unauthenticated Storage access is denied;
- helper functions exist for signed-in, admin, ownership, source image content type, and source image size checks;
- feature-specific allow rules are intentionally deferred to later stories.

## Rules Smoke Test

Story FES-1.2 adds the first Firebase rules smoke harness:

```bash
npm run test:firebase-rules:smoke
```

The command starts Auth, Firestore, and Storage emulators from `app/`, then runs:

```text
scripts/firebase-rules-smoke.mjs
```

Smoke test IDs:

- `fs-unauth-read-deny`
- `fs-unauth-write-deny`
- `st-unauth-read-deny`
- `st-unauth-write-deny`

These tests only verify unauthenticated denial. Owner, admin, status, coordinate-space, and file-validation tests are intentionally deferred to later stories.

## Flutter and Editor Boundary Check

Story FES-1.3 keeps Firebase initialization in the Flutter app layer and adds an editor boundary check:

```bash
npm run check:editor-firebase-boundary
```

The check fails if `editor/src` or `editor/package.json` contains direct Firebase SDK references. The editor may exchange bridge payloads with Flutter, but it must not import Firebase SDKs or call Firestore, Storage, Auth, or Firebase config directly.

## Out of Scope

FES-1.1 does not migrate project, upload, reconstruction, layout, admin, or legacy API flows. Those changes belong to later Firebase refactor stories.
