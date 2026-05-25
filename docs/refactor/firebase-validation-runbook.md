# Firebase Validation Runbook

## Purpose

This runbook is the operational companion to
`docs/refactor/firebase-validation-plan.md`. It turns the validation layers,
test IDs, manual emulator flows, and FB work packages into concrete commands and
fallback rules for implementation stories.

## Default Smoke Gate

Run from the repository root:

```bash
npm run check:firebase-default-smoke
```

This is the default quick gate after Firebase story work. It runs targeted
Flutter tests for backend selection, project flow, admin access, and admin
diagnostics; then runs legacy API isolation, editor boundary checks, and the
Firebase emulator smoke rules test.

## Core Commands

### Flutter App

Run from `app/`:

```bash
flutter analyze
flutter test
flutter build web --release
```

Use targeted tests when the story touches a narrow boundary:

```bash
flutter test test/src/api/backend_bindings_test.dart
flutter test test/src/firebase/firebase_models_test.dart test/src/firebase/firebase_serializers_test.dart
flutter test test/src/projects/firebase_project_api_test.dart
flutter test test/src/admin/firebase_admin_access_repository_test.dart test/src/admin/firebase_admin_diagnostics_test.dart
flutter test test/src/editor/firebase_editor_bridge_mapper_test.dart
flutter test test/src/layouts/layout_draft_repository_test.dart test/src/layouts/layout_remote_update_guard_test.dart
```

### Editor

Run from `editor/`:

```bash
npm run typecheck
npm run test
npm run build
```

Run from the repository root for the boundary check:

```bash
npm run check:editor-firebase-boundary
```

### Firebase Rules and Emulators

Run rules tests from the repository root:

```bash
npm run test:firebase-rules:smoke
npm run test:firebase-rules:projects
npm run test:firebase-rules:profile
npm run test:firebase-rules:source-images
npm run test:firebase-rules:reconstruction
npm run test:firebase-rules:geometry
npm run test:firebase-rules:floor-plans
npm run test:firebase-rules:layouts
npm run test:firebase-rules:admin
npm run test:firebase-rules:admin-storage
```

For manual flows, start emulators from `app/`:

```bash
firebase emulators:start --only auth,firestore,storage
```

For one-shot manual scripts or rules tests, prefer:

```bash
firebase emulators:exec --only auth,firestore,storage "<command>"
```

### Legacy Isolation

Run from the repository root:

```bash
npm run check:legacy-api-isolation
rg -n "legacy_api|LegacyProjectApi|AdminApi|FastAPI|Oracle" README.md docs app/lib scripts
```

The expected result is that Firebase is the default path and legacy adapters are
reachable only through explicit `legacy_api` mode.

## Validation Layer Checklist

| Layer | Required evidence | Command or check |
| --- | --- | --- |
| L0 Document traceability | Source docs agree on Firebase default, editor boundary, role rules, and status vocabulary. | Review `firebase-data-contract.md`, `firebase-target-architecture.md`, `firebase-refactor-workplan.md`, `firebase-validation-plan.md`, and this runbook. |
| L1 Static and boundary | Flutter analysis, editor no-Firebase boundary, legacy explicit-only wiring. | `flutter analyze`, `npm run check:editor-firebase-boundary`, `npm run check:legacy-api-isolation`. |
| L2 Models and repositories | Model, serializer, repository, bridge, layout, draft, and admin tests pass. | `flutter test` or targeted Flutter tests from this runbook. |
| L3 Rules emulator | Firestore and Storage allow/deny behavior is rules-backed. | Relevant `npm run test:firebase-rules:*` script. |
| L4 Integration/manual | Product path works through local Firebase emulators. | MEF manual flows below plus `npm run check:firebase-default-smoke` where applicable. |
| L5 Accessibility/usability | Flutter-controlled states are visible, keyboard-reachable, and not canvas-only. | Widget tests where present plus manual keyboard/semantic review for touched screens. |
| L6 Readiness | Story/source coverage has no unresolved schema, rules, ordering, or legacy-default contradictions. | FES-10.3 readiness input review. |

## Test ID to Story Mapping

| Validation IDs or flow | Primary command/check | Story coverage |
| --- | --- | --- |
| `fs-project-*`, `repo-source-metadata-after-upload`, MEF-2 | `npm run test:firebase-rules:projects`, `npm run test:firebase-rules:source-images`, `flutter test test/src/projects/firebase_project_api_test.dart` | FES-4.1, FES-4.2, FES-4.3 |
| `fs-user-*`, `repo-user-profile-update-preserves-role`, MEF-1 | `npm run test:firebase-rules:profile`, user/profile Flutter tests | FES-3.1, FES-3.2, FES-3.3 |
| `model-job-*`, `fs-job-*`, reconstruction status flows, MEF-3 | `npm run test:firebase-rules:reconstruction`, `flutter test test/src/firebase/firebase_models_test.dart` | FES-5.1 |
| `fs-opencv-*`, `fs-confirmed-*`, `serializer-candidate-confirmed-distinct`, `bridge-candidate-confirmed-distinct` | `npm run test:firebase-rules:geometry`, Firebase serializer tests, editor bridge tests | FES-5.2 |
| `fs-floor-plan-*`, artifact metadata/storage checks | `npm run test:firebase-rules:floor-plans`, `npm run test:firebase-rules:admin-storage` where admin artifact read is touched | FES-5.3, FES-8.2 |
| `fs-layout-*`, `model-layout-*`, `ui-layout-review-required-warning`, MEF-4 | `npm run test:firebase-rules:layouts`, layout/export Flutter tests | FES-6.1, FES-6.2, FES-6.3 |
| Draft/cache recovery and no silent overwrite | Layout draft and remote update Flutter tests plus manual recovery pass | FES-7.1, FES-7.2, FES-7.3 |
| `fs-admin-*`, admin query/index diagnostics, retry audit, MEF-6 | `npm run test:firebase-rules:admin`, admin repository/diagnostics Flutter tests | FES-8.1, FES-8.2, FES-8.3 |
| FB-9 legacy cutover and MEF-7 | `npm run check:legacy-api-isolation`, backend binding tests, default smoke gate | FES-9.1, FES-9.2, FES-9.3 |
| FB-10 readiness and traceability | This runbook, docs index/source order review, readiness inputs | FES-10.1, FES-10.2, FES-10.3 |

## Manual Emulator Flows

Manual flows are additive evidence and do not replace rules tests.

| Flow | Minimum pass condition |
| --- | --- |
| MEF-1 Auth and Profile | User profile sync works without role escalation; admin route opens only for an admin role. |
| MEF-2 Project, Dimensions, and Upload | User creates/opens a project, saves room dimensions, uploads a valid source image, and cross-user access is denied. |
| MEF-3 Reconstruction and Geometry | Job uses only allowed statuses; candidate and confirmed geometry persist in `image_pixels`; floor plan persists in `meters`; `review_required` displays as `Needs review`. |
| MEF-4 Layout Save, Load, and Export | Layout saves, reloads, exports from Firestore, keeps required fields, and shows `Needs review` warnings when applicable. |
| MEF-5 Draft and Conflict Recovery | Local draft restore/discard/continue choices are explicit and remote updates do not silently overwrite active draft edits. |
| MEF-6 Admin Diagnostics and Retry | Non-admin is denied; admin can inspect jobs/artifacts/layouts and create a linked audited retry. |
| MEF-7 Legacy Isolation | Default mode uses Firebase; `legacy_api` is explicit; default smoke does not require FastAPI or Oracle. |

## Fallback Rules

| Missing or failing tool | Fallback | Completion rule |
| --- | --- | --- |
| Flutter unavailable | Run documentation, `rg`, npm boundary, and Firebase rules checks that do not require Flutter. | A story that touched `app/` cannot be complete until Flutter validation runs locally or in a documented equivalent environment. |
| Firebase CLI or Java unavailable | Run Flutter/model/serializer checks and document the environment gap. | Rules-related stories cannot be complete without emulator evidence. |
| Node/npm unavailable | Run Flutter checks and direct `rg` boundary searches. | Editor or root-script stories cannot be complete until npm validation runs. |
| `rg` unavailable | Use another recursive search tool and record the substitute command. | Acceptable when the searched paths and patterns are documented. |
| Browser/manual UI unavailable | Run automated tests and record skipped MEF/L5 evidence. | Acceptable only when the story does not change UI behavior, accessibility, or integration flow. |
| Firebase emulator port conflict | Stop the conflicting local emulator/process or choose a documented alternate port. | Rerun the relevant `npm run test:firebase-rules:*` command before completion. |

## Story Completion Evidence

Each Firebase story completion report should include:

- Story ID and branch.
- Validation layers exercised.
- Commands run and pass/fail result.
- Emulator/manual flows skipped, with reason.
- Known warnings, such as current Flutter web wasm dry-run `dart:html` warnings.
- Confirmation that `legacy_api` remains explicit only when the story touches cutover, docs, app wiring, or validation.
