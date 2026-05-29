# Story 6.4: Admin Retry Failed Jobs

Status: complete

## Story

As an admin user,
I want to retry failed reconstruction jobs where supported,
so that recoverable processing failures can be rerun without losing history.

## Acceptance Criteria

1. Given a failed or timed-out job is retryable, when I trigger retry, then the system creates a new retry attempt linked to the original job and the previous failure history remains preserved.
2. Given retry is not supported for the failure source, when I view the job, then the UI explains why retry is unavailable.

## Tasks / Subtasks

- [x] Verify admin retry API authorization and envelope behavior.
  - [x] Confirm retry requires admin authorization before repository access.
  - [x] Confirm non-admin retry attempts return `unauthorized`.
  - [x] Confirm retry success and failure responses use the shared `data`, `error`, and `meta.request_id` envelope.
- [x] Verify retry semantics.
  - [x] Confirm failed jobs create linked retry attempts.
  - [x] Confirm timed-out jobs create linked retry attempts.
  - [x] Confirm retry jobs include `retry_of_job_id`.
  - [x] Confirm original failed/timed-out job records and failure transitions remain preserved.
- [x] Verify retry unavailable UX.
  - [x] Confirm non-failed/non-timeout retry returns `retry_unavailable`.
  - [x] Confirm Flutter admin detail explains that only failed or timed-out jobs can be retried.
  - [x] Confirm Flutter API surfaces `retry_unavailable` with explanation text.
- [x] Run full app/server validation and focused subagent review.

## Dev Notes

- Current baseline already contained the retry endpoint, repository method, and retry button. This story strengthens support for timeout retry, original history preservation, non-admin denial, and visible retry-unavailable explanation.
- The active branch uses a recovery branch name because `story/6.4-admin-retry` already exists as an older merged ancestor of current primary.
- Retry availability is enforced at the API route: `failed` and `timeout` are retryable; other statuses return `retry_unavailable`.
- The repository creates a new retry record linked through `retry_of_job_id` and preserves the original job and its transitions.

### References

- `docs/legacy/_bmad-output/planning-artifacts/epics.md` Story 6.4.
- `docs/legacy/_bmad-output/planning-artifacts/architecture.md` admin authorization, retry attempt, API envelope, and error-code rules.
- `docs/legacy/_bmad-output/planning-artifacts/prd.md` failed job recovery and retry-history requirements.
- `docs/legacy/_bmad-output/planning-artifacts/ux-design-specification.md` admin retry action and safe intervention guidance.
- `docs/legacy/agent/STORY_QUEUE.md` Story 6.4.

## Dev Agent Record

### Agent Model Used

GPT-5 Codex

### Debug Log References

- `dart format lib/main.dart test/src/admin/admin_api_test.dart`
- `flutter test test/src/admin/admin_api_test.dart test/src/admin/firebase_admin_access_repository_test.dart test/src/admin/firebase_admin_diagnostics_test.dart`
- `.venv/bin/python -m pytest tests/test_admin.py`
- `flutter analyze`
- `flutter test`
- `.venv/bin/python -m pytest`
- `.venv/bin/python -m compileall app`
- `npm run check:editor-firebase-boundary`
- `npm run build`
- `flutter build web --release`
- `git diff --check`
- Subagent focused review completed with no blockers.

### Completion Notes List

- Added visible retry-unavailable explanation in the Flutter admin detail panel.
- Added Flutter API coverage for linked retry creation and retry-unavailable error surfacing.
- Strengthened server retry tests for failed jobs, timed-out jobs, preserved original failure history, non-admin denial, and unsupported status responses.
- Confirmed retry success creates a new linked retry attempt without mutating the original failed/timed-out job.

### File List

- `_bmad-output/implementation-artifacts/6-4-admin-retry-failed-jobs.md`
- `_bmad-output/implementation-artifacts/6-4-completion-report-2026-05-29.md`
- `app/lib/main.dart`
- `app/test/src/admin/admin_api_test.dart`
- `server/tests/test_admin.py`
