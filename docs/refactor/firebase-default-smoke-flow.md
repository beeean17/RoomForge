# Firebase Default Smoke Flow

## Purpose

This document records the Story FES-9.3 smoke gate for the Firebase default
cutover. The smoke gate proves that the default application path can exercise
Firebase-backed project, reconstruction, layout, export, and admin diagnostic
coverage without requiring the legacy FastAPI or Oracle path.

## Automated Smoke Command

Run this from the repository root:

```bash
npm run check:firebase-default-smoke
```

The command executes:

- Flutter tests for backend binding selection, Firebase project flow,
  Firebase admin access, and Firebase admin diagnostics.
- Legacy API isolation checks to confirm legacy adapters stay behind explicit
  `legacy_api` mode.
- Editor/Firebase boundary checks.
- Firebase emulator smoke checks for unauthenticated Firestore and Storage
  denial.

When the local emulator ports are already occupied by a running emulator set,
the command retries the rules-smoke layer directly against those endpoints:

```bash
npm run test:firebase-rules:smoke:direct
```

The direct path resolves the Firebase project id from `GCLOUD_PROJECT`,
`FIREBASE_PROJECT_ID`, or `app/.firebaserc`, then targets the default local
Auth, Firestore, and Storage emulator ports unless endpoint environment
variables override them. It first verifies the Auth emulator is reachable, then
reuses the Firestore and Storage unauthenticated-denial smoke checks.

## Covered Default Flow

The Firebase project smoke test covers the signed-in default path in order:

1. A Firebase `AuthSession` owns project creation.
2. The project is reopened by the signed-in owner.
3. Metric room dimensions are saved.
4. A source image upload records Storage metadata and Firestore source metadata.
5. A reconstruction job is created, transitioned to `review_required`, and
   reloaded.
6. Candidate OpenCV geometry and user-confirmed geometry are persisted
   separately in image-pixel coordinate space.
7. A metric floor plan is persisted in meters with review-required quality
   metadata.
8. A layout is saved, loaded, and exported with snake_case JSON and
   review-required reconstruction state.

## Admin Diagnostic Smoke

The admin smoke coverage verifies the minimum access split:

- Profiles with `role: admin` are treated as admin.
- Normal, missing, or empty profile data is denied.
- Firestore `permission-denied` failures map to an explicit admin diagnostic
  error instead of an empty successful state.
- Admin action query specs remain discoverable for retry and diagnostic flows.

## Legacy Isolation

The default smoke command includes `npm run check:legacy-api-isolation`.
The expected result is that:

- `BackendModeConfig.current` defaults to `firebase`.
- `legacy_api` must be selected explicitly before legacy project/admin adapters
  are constructed.
- FastAPI and Oracle remain legacy/reference paths and are not required by the
  default smoke flow.

## Known Limitations

- The smoke gate validates repository-level flow and rules-emulator denial; it
  does not certify a production Firebase deployment.
- Direct rules smoke requires already-running local emulators; if no emulator
  is listening, it fails rather than starting new processes.
- Browser provider UI for Google sign-in is not automated here; the signed-in
  path is represented by an authenticated `AuthSession`.
- Full manual visual inspection of the Three.js editor is outside this story.
- The legacy FastAPI/Oracle code is retained for explicit `legacy_api` mode and
  reference only.
