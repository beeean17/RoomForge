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

Story FES-1.2 adds the rules test harness and smoke tests.

## Out of Scope

FES-1.1 does not migrate project, upload, reconstruction, layout, admin, or legacy API flows. Those changes belong to later Firebase refactor stories.
