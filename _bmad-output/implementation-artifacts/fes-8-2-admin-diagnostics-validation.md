# Story FES-8.2: Admin Diagnostics UI Validation

Status: complete

## Story

As an admin user,
I want to inspect job details, artifacts, layout references, and permission outcomes,
so that I can identify where reconstruction failed without leaking protected data to non-admin users.

## Acceptance Criteria

1. Given an admin opens a job detail, when data exists, then the UI shows job status, transition history, failure reason, retry linkage, and artifact refs.
2. Given artifact access is allowed, when admin reads the artifact, then the UI maps it as `available`.
3. Given artifact access is denied, missing, failed, or not generated, then the UI shows the corresponding permission-aware state.
4. Given a non-admin reaches any loading, empty, or error state, then protected admin data is not leaked.
5. Given keyboard-only navigation, when admin filters, row actions, and detail panels are used, then controls remain text-readable and reachable.

## Tasks / Subtasks

- [x] Promote admin diagnostics UI metadata to a testable contract.
  - [x] Cover job status filters and exact lookup field labels.
  - [x] Cover job list row summaries and selected row semantics.
  - [x] Cover job detail required fields, artifact refs, transition/history/result/layout section labels.
- [x] Harden permission-safe error and empty-state copy.
  - [x] Ensure non-admin permission errors do not expose protected IDs or paths.
  - [x] Ensure artifact states map to `available`, `restricted`, `missing`, `failed_to_load`, and `not_generated`.
- [x] Complete focused validation.
  - [x] Add tests for admin filter metadata, detail summary requirements, artifact state labels, safe error copy, and accessibility labels.
  - [x] Run targeted admin tests.
  - [x] Run `flutter analyze` and full Flutter tests.
  - [x] Run focused review before commit.

## Dev Notes

- Main admin screen: `app/lib/main.dart` `FirebaseAdminDiagnosticsScreen` and related private widgets.
- Admin diagnostics helper: `app/lib/src/admin/firebase_admin_diagnostics.dart`.
- Admin access repository: `app/lib/src/admin/firebase_admin_access_repository.dart`.
- Existing tests: `app/test/src/admin/firebase_admin_diagnostics_test.dart` and `app/test/src/admin/firebase_admin_access_repository_test.dart`.
- Keep this story validation-focused. Retry mutation behavior belongs to FES-8.3 and should not be broadened.
- Protected admin errors must use safe copy and avoid leaking user/project/job/storage paths to non-admin states.

### References

- `docs/refactor/firebase-epics-and-stories.md` FES-8.2.
- `_bmad-output/planning-artifacts/fes-implementation-validation-2026-05-28.md`.
- `docs/refactor/firebase-validation-plan.md`.

## Dev Agent Record

### Agent Model Used

GPT-5 Codex

### Debug Log References

- `dart format app/lib/main.dart app/lib/src/admin/firebase_admin_diagnostics.dart app/lib/src/admin/firebase_admin_access_repository.dart app/lib/src/firebase/firebase_repositories.dart app/test/src/admin/firebase_admin_access_repository_test.dart app/test/src/admin/firebase_admin_diagnostics_test.dart`
- `flutter test test/src/admin/firebase_admin_diagnostics_test.dart test/src/admin/firebase_admin_access_repository_test.dart`
- `node -e "JSON.parse(require('fs').readFileSync('app/firestore.indexes.json','utf8')); console.log('firestore indexes json ok')"`
- `flutter analyze`
- `flutter test`
- `flutter build web --release`
- `git diff --check`
- Subagent review found artifact metadata re-read, broad owner-layout query, and incomplete detail metadata coverage. All were addressed; re-review reported no remaining blocking issues.

### Completion Notes List

- Added tested admin diagnostics UI metadata for status filters, exact lookup fields, job row summaries, job detail summaries, and semantic section labels.
- Added provider ID, algorithm, OpenCV version, quality status, latest transition, failure detail, and timing fields to the job-detail accessibility contract and visual UI where missing.
- Cached artifact metadata read futures inside a stateful artifact panel to avoid re-running Storage `getMetadata()` on every rebuild.
- Added `watchLayoutsForJob` backed by a `reconstruction_job_id` collection-group query and matching Firestore index, so admin layout diagnostics no longer fetch all layouts for an owner before filtering.
- Preserved safe non-admin error copy through `firebaseAdminSafeErrorMessage`.
- Updated the FES implementation validation report to mark FES-8.2 verified for automated scope.

### File List

- `app/firestore.indexes.json`
- `app/lib/main.dart`
- `app/lib/src/admin/firebase_admin_access_repository.dart`
- `app/lib/src/admin/firebase_admin_diagnostics.dart`
- `app/lib/src/firebase/firebase_repositories.dart`
- `app/test/src/admin/firebase_admin_access_repository_test.dart`
- `app/test/src/admin/firebase_admin_diagnostics_test.dart`
- `_bmad-output/planning-artifacts/fes-implementation-validation-2026-05-28.md`
- `_bmad-output/implementation-artifacts/fes-8-2-admin-diagnostics-validation.md`
