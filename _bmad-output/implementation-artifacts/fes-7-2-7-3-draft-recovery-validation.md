# Story FES-7.2/FES-7.3: Draft Recovery and Remote Update Guard Validation

Status: complete

## Story

As a signed-in RoomForge user,
I want local layout drafts and remote layout updates to be handled with explicit recovery choices,
so that refreshes, save failures, and cloud updates do not silently destroy unsaved editor work.

## Acceptance Criteria

1. Given a local draft exists and no cloud conflict exists, when the project opens, then the user can restore or discard it.
2. Given local draft and cloud layout revisions diverge, when the project opens, then the user sees an explicit conflict choice.
3. Given the user discards a draft, when the action is confirmed, then local draft state is removed without changing the saved cloud layout.
4. Given the user restores a draft, then the UI labels it as `Unsaved draft` until it is saved to Firestore.
5. Given a local draft is dirty, when a Firestore or cloud layout update arrives, then active editor state is not silently overwritten.
6. Given sync fails, when the user reviews persistence state, then `Sync failed` and `Retry available` are visible and actionable.
7. Given save succeeds, when local draft state clears, then the UI reflects `Saved`.
8. Given keyboard-only navigation, when recovery controls are used, then restore, discard, continue saved version, and retry actions are reachable.

## Tasks / Subtasks

- [x] Promote draft recovery choices to typed, testable UI metadata.
  - [x] Expose restore, discard, continue saved version, and retry labels.
  - [x] Include discard confirmation copy in the recovery contract.
  - [x] Include text-readable accessibility summaries for recovery controls.
- [x] Promote remote update guard behavior to a testable decision object.
  - [x] Preserve the existing no-silent-overwrite guard for recoverable drafts.
  - [x] Make forced cloud application explicit for continue saved version.
  - [x] Surface held-update copy and required user actions.
- [x] Complete focused validation.
  - [x] Add unit coverage for non-conflict recovery, conflict recovery, discard confirmation, sync failure retry, saved state labels, and no silent remote overwrite.
  - [x] Run targeted Flutter tests.
  - [x] Run `flutter analyze`.
  - [x] Run focused review before commit.

## Dev Notes

- Primary app shell: `app/lib/main.dart`.
- Draft model/repository: `app/lib/src/layouts/layout_draft_models.dart` and `app/lib/src/layouts/layout_draft_repository.dart`.
- Draft recovery helper: `app/lib/src/layouts/layout_draft_recovery.dart`.
- Remote update guard helper: `app/lib/src/layouts/layout_remote_update_guard.dart`.
- Existing tests: `app/test/src/layouts/layout_draft_recovery_test.dart`, `app/test/src/layouts/layout_remote_update_guard_test.dart`, and `app/test/src/layouts/layout_draft_repository_test.dart`.
- Keep this story focused on validation and small contract gaps. Do not introduce offline merge, collaboration, or background sync.
- Do not imply a cloud save when a local draft is only restored locally.
- Firestore stream application must be conservative around dirty local state. If a recoverable draft exists, cloud layout application must require an explicit user choice.

### References

- `docs/refactor/firebase-epics-and-stories.md` FES-7.2 and FES-7.3.
- `_bmad-output/planning-artifacts/fes-implementation-validation-2026-05-28.md`.
- `docs/refactor/firebase-target-architecture.md`.

## Dev Agent Record

### Agent Model Used

GPT-5 Codex

### Debug Log References

- `dart format app/lib/src/layouts/layout_draft_models.dart app/lib/src/layouts/layout_draft_recovery.dart app/lib/src/layouts/layout_draft_recovery_controls.dart app/lib/src/layouts/layout_draft_repository.dart app/lib/src/layouts/layout_remote_update_guard.dart app/lib/main.dart app/test/src/layouts/layout_draft_recovery_test.dart app/test/src/layouts/layout_draft_recovery_controls_test.dart app/test/src/layouts/layout_remote_update_guard_test.dart app/test/src/layouts/layout_draft_repository_test.dart`
- `flutter test test/src/layouts/layout_draft_recovery_test.dart test/src/layouts/layout_draft_recovery_controls_test.dart test/src/layouts/layout_remote_update_guard_test.dart test/src/layouts/layout_draft_repository_test.dart`
- `flutter analyze`
- `flutter test`
- `flutter build web --release`
- `git diff --check`
- Subagent review found initial project-open conflict detection, stream-payload guard validation, persisted `sync_failed` state, and widget accessibility coverage gaps. All four were addressed; re-review reported no remaining blocking issues.

### Completion Notes List

- Added typed draft recovery actions for restore, discard, continue saved version, and retry save.
- Added discard confirmation copy and recovery accessibility summary helpers.
- Mapped draft sync states to user-visible labels: `Unsaved draft`, `Saving`, `Sync failed`, `Conflict`, and `Saved`.
- Added a remote update decision object and guarded remote-layout wrapper so cloud layout payloads are withheld while a recoverable local draft exists, and forced cloud apply remains explicit.
- Updated project-open draft detection to fetch the latest cloud layout metadata before labeling draft conflict state.
- Persisted `sync_failed` draft state and error metadata so failed saves remain recoverable across reopen.
- Updated the web app command bar to show localized retry save state, semantic recovery summary text, and recovery actions through a widget-tested shared control.
- Updated the FES implementation validation report to mark FES-7.2 and FES-7.3 verified for automated scope.

### File List

- `app/lib/main.dart`
- `app/lib/src/layouts/layout_draft_models.dart`
- `app/lib/src/layouts/layout_draft_recovery.dart`
- `app/lib/src/layouts/layout_draft_recovery_controls.dart`
- `app/lib/src/layouts/layout_draft_repository.dart`
- `app/lib/src/layouts/layout_remote_update_guard.dart`
- `app/test/src/layouts/layout_draft_recovery_controls_test.dart`
- `app/test/src/layouts/layout_draft_recovery_test.dart`
- `app/test/src/layouts/layout_draft_repository_test.dart`
- `app/test/src/layouts/layout_remote_update_guard_test.dart`
- `_bmad-output/planning-artifacts/fes-implementation-validation-2026-05-28.md`
- `_bmad-output/implementation-artifacts/fes-7-2-7-3-draft-recovery-validation.md`
