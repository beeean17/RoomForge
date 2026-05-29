---
title: "Firebase Epics and Stories Implementation Validation"
status: "complete"
created: "2026-05-28"
updated: "2026-05-29"
workflowType: "fes-implementation-validation"
sourceDocument: "docs/refactor/firebase-epics-and-stories.md"
validationDate: "2026-05-28"
decision: "PARTIAL_READY_FOR_DEV_STORY_PROMOTION"
---

# Firebase Epics and Stories Implementation Validation

## Purpose

This validation checks whether the planning backlog in
`docs/refactor/firebase-epics-and-stories.md` has corresponding implementation
evidence in the current repository. The FES document is a planning artifact, not
an implementation record, so this report separates:

- stories with code, rules, tests, and docs evidence;
- stories with core implementation but remaining manual or product-flow gates;
- stories that should be promoted into focused BMAD dev stories.

## Validation Run

Commands run from the repository on 2026-05-28:

| Command | Result | Notes |
| --- | --- | --- |
| `npm run check:firebase-default-smoke` | Partial pass, then recovered | Targeted Flutter tests, legacy isolation, and editor boundary passed. `firebase emulators:exec` could not start because ports `9099`, `8080`, and `9199` were already occupied. |
| Direct `scripts/firebase-rules-smoke.mjs` against running emulators | Pass | Verified unauthenticated Firestore and Storage read/write denial against `127.0.0.1:8080` and `127.0.0.1:9199`. |
| Direct full Firebase rules matrix against running emulators | Pass | Ran profile, project, source image, reconstruction, geometry, floor plan, layout, admin, and admin storage rules scripts. |
| `flutter analyze` in `app/` | Pass | No issues found. |
| `flutter test` in `app/` | Pass | 76 tests passed. |
| `npm run typecheck` in `editor/` | Pass | TypeScript check passed. |
| `npm run build` in `editor/` | Pass with warnings | Vite reported OpenCV.js browser externalization and large chunk warnings; build exited 0. |
| `flutter test test/src/layouts/layout_draft_recovery_test.dart test/src/layouts/layout_draft_recovery_controls_test.dart test/src/layouts/layout_remote_update_guard_test.dart test/src/layouts/layout_draft_repository_test.dart` in `app/` | Pass | FES-7.2/FES-7.3 focused validation passed. |
| `flutter test` in `app/` after FES-7.2/FES-7.3 | Pass | 86 tests passed. |
| `flutter build web --release` in `app/` after FES-7.2/FES-7.3 | Pass with warnings | JS web build succeeded; Wasm dry-run warned about existing `dart:html` usage in the web shell and IndexedDB draft store. |

Recovery used:

- Issue: Firebase emulator default ports were already occupied.
- Recovery playbook section: validation failure / emulator port conflict recovery.
- Commands/actions taken: did not stop or kill the running emulator processes; connected rules smoke and full rules scripts directly to the already-running local emulators.
- Result: rules smoke and full rules matrix passed.
- Remaining limitation: `npm run check:firebase-default-smoke` is not robust when emulators are already running on the configured ports; the validation runbook should document the direct-run recovery path or alternate port workflow.

## Status Legend

| Status | Meaning |
| --- | --- |
| Verified | Current code, docs, tests, and rules evidence satisfy the story's implementation intent at automated validation level. |
| Partial | Core evidence exists, but a story acceptance area remains incomplete, unproven, or manual-only. |
| Docs verified | The story is documentation/readiness oriented and the expected document evidence exists. |

## Story Evidence Matrix

| Story | Status | Evidence | Remaining gap or note |
| --- | --- | --- | --- |
| FES-1.1 Configure Firebase Emulators and Project Baseline | Verified | `app/firebase.json`, `.firebaserc`, `firestore.rules`, `storage.rules`, `firestore.indexes.json`, `docs/refactor/firebase-local-baseline.md`. | None for automated baseline. |
| FES-1.2 Add Rules Test Harness Smoke Coverage | Verified | Root `package.json` rules scripts; smoke and full rules matrix passed against emulators. | Default smoke script needs a documented recovery path for already-running emulators. |
| FES-1.3 Wire Flutter Firebase Baseline Without Editor Firebase Access | Verified | `app/lib/src/firebase/firebase_app_bootstrap.dart`; `npm run check:editor-firebase-boundary` passed; editor typecheck/build passed. | None. |
| FES-2.1 Encode Firebase Data Contract Models and Enumerations | Verified | `firebase_models_test.dart`; allowed/forbidden statuses and coordinate-space validation passed in `flutter test`. | None. |
| FES-2.2 Implement Serializers for Firestore, Export, and Dart Boundaries | Verified | `firebase_serializers_test.dart`; snake_case persistence/export and camelCase model API tests passed. | None. |
| FES-2.3 Define Repository Boundaries and Editor Bridge Mapping | Verified | `firebase_repositories_test.dart`; `firebase_editor_bridge_mapper_test.dart`; editor boundary check passed. | None. |
| FES-3.1 Project Firebase Auth Into Safe User Profiles | Verified | `firebase_user_repository_test.dart`; profile rules script passed; profile sync error handling exists in app shell. | Manual Google sign-in emulator flow was not run in browser. |
| FES-3.2 Protect Privileged Admin Role Fields | Verified | `firebase-profile-rules.mjs`; `firebase-admin-role-bootstrap.md`; admin role guard tests passed. | Production role-assignment mechanism remains documented as bootstrap/admin-scoped rather than productized. |
| FES-3.3 Add Admin Route Guard Baseline | Verified | `AdminRouteGuardButton`, `FirebaseAdminRoleGuard`, admin repository tests, non-admin rules denial. | Manual route access with real accounts was not run. |
| FES-4.1 Migrate Owned Project and Room Dimension Persistence | Verified | `FirebaseProjectApi` project/dimensions tests; project rules script passed; soft delete method exists. | None for automated scope. |
| FES-4.2 Upload Source Images to Contracted Storage Paths | Verified | `firebase_source_image_upload.dart`; upload metadata tests; source image storage rules script passed. | Browser upload flow was not manually exercised. |
| FES-4.3 Surface Upload Progress, Failure, and Recovery States | Partial | Upload state model tests cover validation, permission, metadata-save failure, and accessible progress copy; app UI has progress and retry states. | Needs widget/manual accessibility pass for keyboard reachability and metadata-save-failed recovery panel behavior. |
| FES-5.1 Persist Reconstruction Jobs and Transitions | Verified | Reconstruction repository/API tests; reconstruction rules script passed; allowed status vocabulary enforced. | None for automated scope. |
| FES-5.2 Persist OpenCV Candidates and Confirmed Geometry Separately | Verified | Story 3.7 implementation; geometry rules script passed; serializer and bridge distinction tests passed. | None for automated scope. |
| FES-5.3 Persist Metric Floor Plans and Artifact References | Verified | Floor plan repository/API tests; floor plan rules and admin storage rules passed; app persists metric floor plans in meters with generated calibration/debug JSON artifact refs and best-effort artifact cleanup on save failure. | Browser/manual artifact inspection was not run, but automated contract and rules evidence now covers the persistence gap. |
| FES-6.1 Save and Load Layouts from Firestore | Verified | Layout save/load tests; layout rules script passed; owner-only access checks passed. | None for automated scope. |
| FES-6.2 Preserve Editor Bridge and Furniture State | Verified | Furniture bridge mapper tests; editor bridge mapper tests; editor Firebase boundary check passed. | None. |
| FES-6.3 Export Latest Saved Layout JSON with Review Warning | Verified | Export warning tests; Firebase serializers export JSON with snake_case; Project API rejects export without saved cloud layout. | Manual export download flow was not run in browser. |
| FES-7.1 Implement IndexedDB Draft and Project Cache Stores | Verified | `IndexedDbLayoutDraftStore`, `LayoutDraftRepository`, and draft/cache tests passed. | Browser refresh recovery was not manually exercised. |
| FES-7.2 Add Draft Recovery and Conflict Resolver UX | Verified | Draft recovery actions are typed and tested for restore, discard, conflict continue, retry, destructive confirmation, and text-readable accessibility summary; app project-open detection now checks latest cloud layout metadata before labeling a draft; app UI renders localized restore/discard/continue/retry controls through a widget-tested recovery action bar. | None for automated scope. |
| FES-7.3 Prevent Firestore Streams from Silently Overwriting Active Drafts | Verified | `layout_remote_update_guard_test.dart` covers no silent remote overwrite while a recoverable draft exists, explicit forced cloud apply, saved-draft application, held-update copy, withheld remote payloads, and sync failed/retry labels; app load path now uses the guarded remote layout decision before applying cloud state, and sync-failed draft state persists across reopen. | Real-time collaborative merge remains out of scope; current implementation is conservative and requires explicit user choice. |
| FES-8.1 Implement Admin Repository, Indexes, and Rules-Backed Query Access | Verified | `FirebaseAdminAccessRepository`; collection group index definitions; admin rules script passed; missing-index diagnostics tests passed. | None for automated scope. |
| FES-8.2 Build Admin Diagnostics for Jobs, Artifacts, Layouts, and Permissions | Partial | Admin diagnostics screen exists; artifact state mapper tests passed; admin storage rules passed; admin streams cover jobs, transitions, results, and layouts. | Needs manual/admin UI pass for filters, detail panel, artifact state display, and accessibility. |
| FES-8.3 Add Audited Admin Retry with Append-Only Admin Actions | Verified | Admin retry repository tests passed; admin rules script passed for append-only actions and non-admin denial; app retry action is wired in diagnostics UI. | Manual admin retry flow was not run against emulators. |
| FES-9.1 Select Firebase Repositories by Default | Verified | `backend_bindings_test.dart`; `docs/refactor/README.md`; default Firebase repository selection tests passed. | None. |
| FES-9.2 Isolate Legacy ProjectApi and AdminApi Usage | Verified | `npm run check:legacy-api-isolation` passed; docs mark FastAPI/Oracle as legacy-only explicit `legacy_api`. | Legacy files remain by design. |
| FES-9.3 Validate End-to-End Firebase Default Flow | Verified | `npm run check:firebase-default-smoke` passed in normal emulators-start mode and in already-running-emulator fallback mode; targeted Flutter tests, editor boundary, legacy isolation, and direct rules smoke all passed. | Browser provider UI and full visual editor inspection remain documented limitations, not hidden completion claims. |
| FES-10.1 Finalize Firebase Validation Commands and Runbook | Docs verified | `docs/refactor/firebase-validation-runbook.md` maps commands, layers, test IDs, direct smoke recovery, and fallback rules. | None for docs scope. |
| FES-10.2 Link Refactor Docs and Preserve Source-of-Truth Order | Docs verified | `docs/refactor/README.md` defines source-of-truth order and legacy docs boundaries. | None. |
| FES-10.3 Prepare Implementation Readiness Review Inputs | Docs verified | `firebase-readiness-review-inputs.md` and `firebase-implementation-readiness-report.md` exist. | This report now adds post-implementation validation evidence. |

## Summary

| Bucket | Count | Stories |
| --- | ---: | --- |
| Verified | 25 | FES-1.1, 1.2, 1.3, 2.1, 2.2, 2.3, 3.1, 3.2, 3.3, 4.1, 4.2, 5.1, 5.2, 5.3, 6.1, 6.2, 6.3, 7.1, 7.2, 7.3, 8.1, 8.3, 9.1, 9.2, 9.3 |
| Partial | 2 | FES-4.3, 8.2 |
| Docs verified | 3 | FES-10.1, 10.2, 10.3 |

## Dev Story Promotion Candidates

The next BMAD dev stories should come from the partial bucket, in this order:

1. FES-8.2 admin diagnostics UI validation.
   - Goal: verify admin filters, job detail, artifact state mapping, related layout/result panes, and permission-safe empty/error states.
   - Acceptance focus: non-admin leakage prevention and accessible admin table/detail controls.

2. FES-4.3 upload recovery UX validation.
   - Goal: add widget/manual coverage for upload progress, invalid image, permission failure, metadata-save failure, retry, and cleanup guidance.
   - Acceptance focus: accessible state text and recoverable action paths.

## Decision

The Firebase FES backlog is no longer only planning-level in the repository:
most stories have implementation evidence and automated validation. It is not
honest to mark the entire FES backlog fully complete, because two stories still
have manual or UI/accessibility validation gaps.

The natural next BMAD workflow is to create focused dev story files for the
partial bucket rather than restarting from FES-1.1.
