# Story CV-4.3 Completion Report

## 1. Goal Summary

- Target story: CV-4.3 - Scene Understanding Persistence
- Implemented outcome: Persisted browser scene understanding results to Firestore, replayed the latest saved result into the editor bridge, and kept candidate results separate from confirmed layout state.
- Out of scope: Cloud GPU inference, SAM 3, real model asset management, and automatic conversion of candidates into confirmed furniture.
- Current baseline assumptions: CV-4.1 and CV-4.2 worker/runtime contracts are complete on `epic/cv-4-browser-scene-understanding`.

## 2. Acceptance Criteria Verification

- AC 1: Given scene understanding completes, Flutter stores candidate result metadata under the project owner.
  - Status: pass
  - Evidence: `EditorBridgeScreen` listens for `roomforge.sceneUnderstanding.candidatesExtracted` and `candidatesFailed`, then calls `ProjectApi.persistSceneUnderstandingResult`; FirebaseProjectApi stores a `FirebaseSceneUnderstandingResult` with owner UID and project ID.
- AC 2: Given a user reopens the project, existing candidates load into the editor without rerunning detection by default.
  - Status: pass
  - Evidence: `loadLatestSceneUnderstandingResult` returns a bridge payload and `_sceneInitializePayload` includes `sceneUnderstandingResult`, so editor candidate/fixture layers initialize from persisted data.
- AC 3: Given another user attempts access, Firestore rules deny candidate result data.
  - Status: pass
  - Evidence: `scene_understanding_results` rules gate read/write through `ownsProject(projectId)` or admin authorization and require `owner_uid == request.auth.uid` on writes.
- AC 4: Given a candidate is later confirmed, the original candidate result remains available for traceability.
  - Status: pass
  - Evidence: scene understanding results are stored in `projects/{project_id}/scene_understanding_results/{result_id}` independently from layout save/update paths; layout save does not mutate the stored candidate result.

## 3. Validation Loop

- Commands run:
  - `dart format ...`
  - `flutter analyze`
  - `flutter test test/src/projects/firebase_project_api_test.dart test/src/editor/firebase_editor_bridge_mapper_test.dart test/src/api/backend_bindings_test.dart test/src/firebase/firebase_repositories_test.dart`
  - `npm run typecheck`
  - `npm run test:cv-4.1`
  - `npm run test:cv-4.2`
  - `npm run build`
  - `bash private/scripts/check-editor-firebase-boundary.sh`
  - `firebase emulators:exec --only firestore "node -e \"console.log('firestore rules loaded')\""`
  - `flutter test`
  - `git diff --check`
- Commands passed: all final listed commands.
- Commands failed: initial `flutter analyze` found missing test fixture constructor arguments after adding the repository dependency; fixed by making the FirebaseProjectApi dependency optional for tests and adding a fake scene repository test.
- Fix/retry cycles: 1.
- Substitute checks: Firestore rules were validated by emulator startup/compile; dedicated scene rules emulator assertions were not added in this story.
- Environment limitations: Firebase CLI needed escalated execution to access its local config/update state.
- Final validation result: pass.

## 4. Invariants Verified

- Scene understanding remains browser/editor-originated; no heavy CV/GPU work was added to the API server: pass.
- Persisted candidate objects remain separate from confirmed objects and saved layouts: pass.
- Firestore data uses snake_case and bridge payloads use camelCase: pass via serializer/bridge tests.
- User-facing project data is protected by owner UID rules: pass via Firestore rules path and emulator compile.
- Editor remains free of Firebase SDK imports: pass via submodule boundary check.

## 5. Changed Files

- `app/firestore.rules`
- `app/lib/main.dart`
- `app/lib/src/api/backend_bindings.dart`
- `app/lib/src/editor/firebase_editor_bridge_mapper.dart`
- `app/lib/src/firebase/firebase_app_bootstrap.dart`
- `app/lib/src/firebase/firebase_project_repository.dart`
- `app/lib/src/firebase/firebase_repositories.dart`
- `app/lib/src/projects/firebase_project_api.dart`
- `app/lib/src/projects/project_api.dart`
- `app/test/src/api/backend_bindings_test.dart`
- `app/test/src/editor/firebase_editor_bridge_mapper_test.dart`
- `app/test/src/firebase/firebase_repositories_test.dart`
- `app/test/src/projects/firebase_project_api_test.dart`

## 6. Story Loop Handoff

- Current story: CV-4.3
- Current story branch: `epic/cv-4-browser-scene-understanding`
- Current story status: complete
- Suggested story commit: `feat(cv-4.3): persist scene understanding results`
- Epic status: CV-4 complete after this story
- Next story: CV-5.1 - Category Size Priors
- Next story branch: `epic/cv-5-metric-placement-multi-photo-merge`
