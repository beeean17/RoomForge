---
title: "FES-9.3 Default Smoke Hardening"
status: "complete"
created: "2026-05-29"
storyId: "FES-9.3"
sourceStory: "docs/refactor/firebase-epics-and-stories.md#story-93-validate-end-to-end-firebase-default-flow"
---

# FES-9.3 Default Smoke Hardening

## Story

As a developer agent, I want a default-path Firebase smoke flow, so that the
cutover proves user value rather than only configuration changes.

## Acceptance Criteria

1. Given local Firebase emulators are not already running, when
   `npm run check:firebase-default-smoke` executes, then the normal
   `firebase emulators:exec` smoke gate can start emulators and pass.
2. Given local Firebase emulators are already running on the configured ports,
   when `npm run check:firebase-default-smoke` executes, then the script
   recovers by running the rules smoke directly against the existing emulator
   endpoints.
3. Given the default smoke flow runs, then targeted Flutter default-path,
   admin diagnostics, editor boundary, and legacy API isolation checks remain
   part of the gate.
4. Given a limitation remains, then it is documented as a follow-up rather than
   hidden.

## Tasks / Subtasks

- [x] Add a direct Firebase rules smoke command for already-running emulators.
  - [x] Resolve the default Firebase project id from `GCLOUD_PROJECT` or
        `app/.firebaserc`.
  - [x] Set default Auth, Firestore, and Storage emulator endpoints.
  - [x] Reuse `scripts/firebase-rules-smoke.mjs`.
- [x] Harden `scripts/check-firebase-default-smoke.sh`.
  - [x] Keep targeted Flutter tests, legacy isolation, and editor boundary.
  - [x] Run `npm run test:firebase-rules:smoke` first.
  - [x] If emulator startup fails because ports are occupied or unavailable,
        retry via the direct rules smoke command.
  - [x] Do not hide real rules failures behind fallback.
- [x] Update runbook/default smoke documentation with the recovery path.
- [x] Run validation for default smoke, direct smoke, legacy isolation, editor
      boundary, and targeted Flutter checks.

## Dev Notes

- FES-9.3 is a validation/story-gate hardening story. It should not introduce
  product features.
- The default path must remain Firebase. Legacy FastAPI/Oracle paths must stay
  behind explicit `legacy_api`.
- The direct fallback is only valid when an existing emulator process is already
  serving the configured local endpoints. If no emulator is running, it should
  fail loudly.
- The default smoke command should remain a single root-level command.

## Expected Files

- `package.json`
- `scripts/check-firebase-default-smoke.sh`
- `scripts/firebase-rules-smoke-direct.sh`
- `docs/refactor/firebase-validation-runbook.md`
- `docs/refactor/firebase-default-smoke-flow.md`
- `_bmad-output/implementation-artifacts/fes-9-3-default-smoke-hardening.md`
- Optional completion report under `_bmad-output/implementation-artifacts/`

## Validation Plan

- `bash -n scripts/check-firebase-default-smoke.sh scripts/firebase-rules-smoke-direct.sh`
- `npm run check:legacy-api-isolation`
- `npm run check:editor-firebase-boundary`
- `flutter test test/src/api/backend_bindings_test.dart test/src/projects/firebase_project_api_test.dart test/src/admin/firebase_admin_access_repository_test.dart test/src/admin/firebase_admin_diagnostics_test.dart` from `app/`
- `npm run test:firebase-rules:smoke`
- `npm run test:firebase-rules:smoke:direct` against already-running emulators
- `npm run check:firebase-default-smoke`

## Dev Agent Record

### Debug Log

- 2026-05-29: Created story from the next partial-bucket promotion after
  completing FES-5.3.
- 2026-05-29: Added `test:firebase-rules:smoke:direct` and direct smoke helper
  for already-running local emulators.
- 2026-05-29: Hardened `check:firebase-default-smoke` to retry only emulator
  startup/port-binding failures through direct smoke.
- 2026-05-29: Verified normal default smoke and already-running-emulator
  fallback paths with Firebase emulators.
- 2026-05-29: Subagent review found the direct smoke script must be committed,
  Auth readiness should be verified, and `STORAGE_EMULATOR_HOST` should remain
  respected. Fixed and revalidated all three points.

### Completion Notes

- `npm run check:firebase-default-smoke` remains the single default smoke gate.
- The gate still runs targeted Flutter default-path/admin tests, legacy API
  isolation, editor Firebase boundary, and Firebase unauthenticated rules
  smoke.
- If `firebase emulators:exec` cannot start because configured ports are
  already occupied, the script retries rules smoke directly against the
  existing local emulator endpoints.
- The direct fallback is intentionally limited to emulator startup/port-binding
  failures, verifies Auth emulator readiness, and then runs Firestore/Storage
  rules smoke so real rules failures are not hidden.
- The validation matrix now marks FES-5.3 and FES-9.3 verified and leaves the
  remaining partial bucket at FES-7.2/FES-7.3, FES-8.2, and FES-4.3.

### File List

- `package.json`
- `scripts/check-firebase-default-smoke.sh`
- `scripts/firebase-rules-smoke-direct.sh`
- `docs/refactor/firebase-validation-runbook.md`
- `docs/refactor/firebase-default-smoke-flow.md`
- `_bmad-output/planning-artifacts/fes-implementation-validation-2026-05-28.md`
- `_bmad-output/implementation-artifacts/fes-9-3-default-smoke-hardening.md`
- `_bmad-output/implementation-artifacts/fes-9-3-completion-report-2026-05-29.md`

### Change Log

- Added a direct rules smoke npm script for existing local emulators.
- Added port/startup failure recovery to the default Firebase smoke gate.
- Documented the recovery path and updated the FES implementation validation
  status matrix.
