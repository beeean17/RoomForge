# Story CV-6.2 Completion Report

## 1. Goal Summary

- Target story: CV-6.2 - Depth Metadata Capture and Storage
- Implemented outcome: Added optional depth artifact references and camera pose metadata to guided capture images, persisted them through Firebase API mappings, forwarded them to the editor bridge, and protected capture-session depth artifacts with owner-scoped Storage rules.
- Out of scope: Native Android ARCore depth frame capture and upload byte generation.
- Current baseline assumptions: CV-6.1 is complete on `epic/cv-6-android-arcore-depth`; CV-6.2 continues on the same epic branch.

## 2. Acceptance Criteria Verification

- AC 1: If depth enhancement is enabled, optional camera pose and depth artifact metadata can be stored for the image role.
  - Status: pass
  - Evidence: `CaptureImage` and `FirebaseCaptureImage` now carry `depthArtifactRefs` and `cameraPose`; `FirebaseProjectApi.uploadCaptureImage` persists both with capture image role metadata.
- AC 2: If depth capture fails, image upload still succeeds and session remains valid with warning.
  - Status: pass
  - Evidence: `depthWarning` sets capture image `guidanceState` to `depth_warning` while storing the normal photo without depth refs or camera pose.
- AC 3: Depth artifacts stored are denied to another user by owner-scoped rules.
  - Status: pass
  - Evidence: `app/storage.rules` allows depth artifacts only under the owning capture session path and `private/scripts/firebase-capture-depth-rules.mjs` verifies owner upload/read and cross-user deny.
- AC 4: Editor receives capture metadata; absent depth refs do not break browser CV.
  - Status: pass
  - Evidence: `FirebaseEditorBridgeMapper.captureImageToBridgePayload` and the main editor bridge payload include `depthArtifactRefs` and camelCase `cameraPose`; empty depth refs remain valid and existing browser CV bridge tests pass.

## 3. Validation Loop

- Commands run:
  - `dart format app/lib/main.dart app/lib/src/firebase/firebase_models.dart app/test/src/firebase/firebase_models_test.dart app/test/src/editor/firebase_editor_bridge_mapper_test.dart app/test/src/projects/firebase_project_api_test.dart`
  - `flutter analyze`
  - `flutter test test/src/projects/firebase_project_api_test.dart`
  - `flutter test test/src/firebase/firebase_models_test.dart`
  - `flutter test test/src/firebase/firebase_serializers_test.dart`
  - `flutter test test/src/editor/firebase_editor_bridge_mapper_test.dart`
  - `firebase emulators:exec --only auth,firestore,storage "node ../private/scripts/firebase-capture-depth-rules.mjs"`
  - `bash private/scripts/check-editor-firebase-boundary.sh`
  - `git diff --check`
- Commands passed: all final listed commands.
- Commands failed: an initial storage-rules run passed functionally but logged a missing `capture_session_id` evaluation warning in a deny case; the rules now check required metadata keys before field access and the emulator run is clean.
- Fix/retry cycles: 1.
- Substitute checks: Android hardware capture was not run locally; metadata persistence and ownership rules were validated with model/API tests and Firebase emulators.
- Environment limitations: No physical Android ARCore device is available in this environment.
- Final validation result: pass with Android hardware capture deferred.

## 4. Invariants Verified

- Candidate/depth metadata remains separate from user-confirmed geometry: pass.
- Firebase persisted payloads remain snake_case and editor bridge payloads remain camelCase: pass.
- Depth artifacts are tied to capture sessions, not reconstruction jobs: pass.
- Normal guided capture still works when depth refs and camera pose are absent: pass.
- Editor remains free of Firebase SDK imports: pass via submodule boundary check.

## 5. Changed Files

- `app/lib/main.dart`
- `app/lib/src/firebase/firebase_models.dart`
- `app/lib/src/projects/firebase_project_api.dart`
- `app/lib/src/projects/project_api.dart`
- `app/storage.rules`
- `app/test/src/editor/firebase_editor_bridge_mapper_test.dart`
- `app/test/src/firebase/firebase_models_test.dart`
- `app/test/src/projects/firebase_project_api_test.dart`
- `private/scripts/firebase-capture-depth-rules.mjs`

## 6. Story Loop Handoff

- Current story: CV-6.2
- Current story branch: `epic/cv-6-android-arcore-depth`
- Current story status: complete
- Suggested story commit: `feat(cv-6.2): store arcore depth metadata`
- Epic status: CV-6 in progress
- Next story: CV-6.3 - Depth-Assisted Scale Hints
- Next story branch: `epic/cv-6-android-arcore-depth`
