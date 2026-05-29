# Story FES-4.3: Upload Recovery UX Validation

Status: complete

## Story

As a signed-in RoomForge user,
I want upload progress and recovery states to be clear,
so that I know whether my source image is usable.

## Acceptance Criteria

1. Given a valid image upload is in progress, when progress changes, then the user sees an accessible `Uploading` state.
2. Given upload and metadata persistence finish, when the UI updates, then the user sees `Uploaded`.
3. Given metadata save fails after Storage upload succeeds, then the UI does not treat the image as fully complete and offers retry or cleanup guidance.
4. Given permission denial occurs, then the UI shows a recoverable permission state without exposing other users' data.
5. Given keyboard-only navigation, when upload recovery controls are used, then choose-photo and retry-upload actions are reachable where applicable.

## Tasks / Subtasks

- [x] Promote upload recovery actions and text summaries to a testable contract.
  - [x] Cover accessible progress text.
  - [x] Cover metadata-save-failed cleanup guidance.
  - [x] Cover permission recovery copy without protected data leakage.
- [x] Add widget coverage for upload recovery controls.
  - [x] Verify choose-photo and retry-upload callbacks.
  - [x] Verify uploading state disables selection.
  - [x] Verify semantic summary text.
  - [x] Verify keyboard traversal and activation.
- [x] Wire the app upload panel to the shared recovery contract.
- [x] Run targeted project/upload tests, full Flutter validation, web build, and focused review.

## Dev Notes

- Main upload panel: `app/lib/main.dart` `PhotoIntakeSection`.
- Upload state model: `app/lib/src/projects/source_image_upload_status.dart`.
- Existing tests: `app/test/src/projects/source_image_upload_status_test.dart`.
- Keep this story validation-focused. Do not change Storage upload contracts or reconstruction processing.
- Permission and metadata-save failure copy must not expose other users' paths, IDs, or raw backend errors.

### References

- `docs/refactor/firebase-epics-and-stories.md` FES-4.3.
- `_bmad-output/planning-artifacts/fes-implementation-validation-2026-05-28.md`.
- `docs/refactor/firebase-validation-plan.md`.

## Dev Agent Record

### Agent Model Used

GPT-5 Codex

### Debug Log References

- `dart format app/lib/main.dart app/lib/src/projects/source_image_upload_status.dart app/lib/src/projects/source_image_upload_recovery_controls.dart app/test/src/projects/source_image_upload_status_test.dart app/test/src/projects/source_image_upload_recovery_controls_test.dart`
- `flutter test test/src/projects/source_image_upload_status_test.dart test/src/projects/source_image_upload_recovery_controls_test.dart`
- `flutter test test/src/projects/firebase_project_api_test.dart`
- `flutter analyze`
- `flutter test`
- `flutter build web --release`
- `git diff --check`
- Subagent review found low-severity keyboard-test and duplicate semantics issues. Keyboard activation coverage was added and the app upload panel now passes a shorter action-only semantics label to the control.
- Subagent re-review found no blocking or material findings after the keyboard and semantics fixes.

### Completion Notes List

- Added a testable source-image upload recovery contract for choose-photo and retry-upload actions, progress summaries, metadata-save-failed guidance, and safe permission recovery copy.
- Added `SourceImageUploadRecoveryControls` with widget tests for click callbacks, disabled uploading state, semantic label, and keyboard Tab/Enter activation.
- Wired `PhotoIntakeSection` to the shared recovery actions and accessibility summary.
- Updated the FES implementation validation report to mark FES-4.3 verified and empty the FES partial bucket.

### File List

- `app/lib/main.dart`
- `app/lib/src/projects/source_image_upload_status.dart`
- `app/lib/src/projects/source_image_upload_recovery_controls.dart`
- `app/test/src/projects/source_image_upload_status_test.dart`
- `app/test/src/projects/source_image_upload_recovery_controls_test.dart`
- `_bmad-output/planning-artifacts/fes-implementation-validation-2026-05-28.md`
- `_bmad-output/implementation-artifacts/fes-4-3-upload-recovery-validation.md`
