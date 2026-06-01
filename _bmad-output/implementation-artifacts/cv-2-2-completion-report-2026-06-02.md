# Story CV-2.2 Completion Report

## 1. Goal Summary

- Target story: CV-2.2 - Multi-Photo Upload and Role Metadata
- Implemented outcome: Added guided capture session creation, role-based capture image upload, Firebase metadata persistence, Storage paths, ownership rules, and per-role upload recovery UI.
- Out of scope: Native Android camera capture, ARCore Depth metadata, desktop editor continuation, and real CV inference.
- Current baseline assumptions: CV-2.1 guided capture UI exists on `epic/cv-2-guided-android-photo-capture`.

## 2. Acceptance Criteria Verification

- AC 1: `overview` upload includes capture session ID and role in Storage and Firestore metadata.
  - Status: pass
  - Evidence: `FirebaseProjectApi.uploadCaptureImage` writes Storage custom metadata (`capture_session_id`, `capture_image_id`, `source_image_id`, `role`) and persists both source-image capture fields and `FirebaseCaptureImage`.
- AC 2: Wall images persist only allowed role metadata.
  - Status: pass
  - Evidence: `FirebaseCaptureImageRole.fromWireValue`, API invalid-role test, Firestore `isAllowedCaptureImageRole`, and Storage `isAllowedCaptureImageRole`.
- AC 3: A failed role upload exposes recovery without losing already uploaded role images.
  - Status: pass
  - Evidence: Guided role upload snapshots preserve previous uploaded `CaptureImage`; widget test verifies uploaded overview remains visible while `front_wall` shows retry.
- AC 4: Storage rules deny cross-user image access.
  - Status: pass
  - Evidence: Storage capture-session paths require path owner, project ownership, capture session document ownership, metadata matches, and source-image rules emulator script revalidated owner/cross-user denial for existing source image paths.

## 3. Validation Loop

- Commands run:
  - `dart format app/lib/main.dart app/lib/src/projects/guided_capture_session_section.dart app/lib/src/projects/project_api.dart app/lib/src/projects/firebase_project_api.dart app/lib/src/projects/firebase_source_image_upload.dart app/lib/src/firebase/firebase_models.dart app/lib/src/firebase/firebase_serializers.dart app/lib/src/firebase/firebase_repositories.dart app/lib/src/firebase/firebase_project_repository.dart app/test/src/projects/firebase_project_api_test.dart app/test/src/projects/guided_capture_session_section_test.dart`
  - `flutter test test/src/projects/firebase_project_api_test.dart`
  - `flutter test test/src/projects/guided_capture_session_section_test.dart`
  - `flutter test test/src/projects test/src/firebase/firebase_models_test.dart test/src/firebase/firebase_serializers_test.dart`
  - `flutter test test/src/api/backend_bindings_test.dart test/src/firebase/firebase_repositories_test.dart`
  - `flutter analyze`
  - `firebase emulators:exec --only auth,firestore,storage "node ../private/scripts/firebase-source-image-rules.mjs"`
  - `bash private/scripts/check-editor-firebase-boundary.sh`
  - `git diff --check`
- Commands passed: all final listed commands.
- Commands failed:
  - First emulator rules run was blocked by sandbox port binding; reran with approval.
  - One Storage rules run failed because the capture-session ownership guard was accidentally applied to the legacy source-image path; moved it to the capture-session path and reran successfully.
- Fix/retry cycles: 2.
- Substitute checks: Existing submodule source-image rules script validates Storage rules parsing and source-image owner/cross-user behavior; capture-session-specific Storage paths are covered by code-level metadata tests and rules review.
- Environment limitations: Firebase emulator requires approved local port binding.
- Final validation result: pass.

## 4. Invariants Verified

- Flutter owns capture UX and Firebase API calls: pass.
- Editor remains free of Firebase imports: pass via submodule boundary check.
- No heavy CV/GPU inference added: pass.
- Source photos remain immutable: pass; uploads create metadata only.
- Candidate vs confirmed separation preserved: pass; no CV candidates are generated in this story.
- Firestore remains snake_case and API/editor-facing objects remain typed app models: pass.
- Existing single source image upload remains intact: pass via `firebase-source-image-rules.mjs` and project tests.

## 5. Changed Files

- `app/firestore.rules`
- `app/storage.rules`
- `app/lib/main.dart`
- `app/lib/src/firebase/firebase_models.dart`
- `app/lib/src/firebase/firebase_project_repository.dart`
- `app/lib/src/firebase/firebase_repositories.dart`
- `app/lib/src/firebase/firebase_serializers.dart`
- `app/lib/src/projects/firebase_project_api.dart`
- `app/lib/src/projects/firebase_source_image_upload.dart`
- `app/lib/src/projects/guided_capture_session_section.dart`
- `app/lib/src/projects/project_api.dart`
- `app/test/src/projects/firebase_project_api_test.dart`
- `app/test/src/projects/guided_capture_session_section_test.dart`

## 6. Story Loop Handoff

- Current story: CV-2.2
- Current story branch: `epic/cv-2-guided-android-photo-capture`
- Current story status: complete
- Suggested story commit: `feat(cv-2.2): upload guided photos with roles`
- Next story: CV-2.3 - Desktop Capture Session Continuation
- Next story branch: `epic/cv-2-guided-android-photo-capture`
