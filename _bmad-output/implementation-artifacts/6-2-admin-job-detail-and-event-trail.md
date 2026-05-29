# Story 6.2: Admin Job Detail and Event Trail

Status: complete

## Story

As an admin user,
I want to inspect reconstruction job details and status transitions,
so that I can understand what happened during reconstruction.

## Acceptance Criteria

1. Given I open a job detail page, when the job record loads, then I see project/job header, current status, timestamps, provider or algorithm identifier, retry count, and failure reason where available.
2. Given job status transitions exist, when I view the event trail, then each transition shows status, timestamp, actor/source, reason code, human-readable reason, and retry linkage where available.

## Tasks / Subtasks

- [x] Verify admin job detail API and authorization.
  - [x] Confirm `/admin/jobs/{job_id}` requires admin authorization.
  - [x] Confirm the response uses the shared `data`, `error`, and `meta.request_id` envelope.
  - [x] Confirm non-admin access is denied before detail data exposure.
- [x] Verify job header fields.
  - [x] Confirm project id, user id, source image id, current status, provider, created/updated timestamps, retry count, and failure reason are returned.
  - [x] Confirm Flutter detail UI displays created/updated timestamps and retry linkage when available.
- [x] Verify event trail fields.
  - [x] Confirm transition status, timestamp, actor/source, reason code, and human-readable reason are returned and parsed.
  - [x] Confirm retry job detail exposes `retry_of_job_id` linkage.
- [x] Run full app/server validation and focused subagent review.

## Dev Notes

- Current baseline already contained the admin detail API, Flutter API model, and admin detail panel. This story closes acceptance gaps around visible timestamps and retry linkage, then strengthens tests.
- The active branch uses a recovery branch name because `story/6.2-admin-job-detail` already exists as an older merged ancestor of current primary.
- The detail endpoint intentionally reuses existing reconstruction job response/transition mappers so status labels and snake_case API fields stay consistent.
- Event trail retry linkage is shown through the retry job's `retry_of_job_id`; listing child retry attempts from the original job remains covered by retry count and later admin retry/failure diagnosis work.

### References

- `docs/legacy/_bmad-output/planning-artifacts/epics.md` Story 6.2.
- `docs/legacy/_bmad-output/planning-artifacts/architecture.md` admin authorization, API envelope, and job transition rules.
- `docs/legacy/_bmad-output/planning-artifacts/prd.md` admin job inspection and retry history requirements.
- `docs/legacy/_bmad-output/planning-artifacts/ux-design-specification.md` admin diagnosis and event trail guidance.
- `docs/legacy/agent/STORY_QUEUE.md` Story 6.2.

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

- Added visible admin detail timestamps for job creation/update.
- Added visible retry linkage in the admin detail header and event trail when the selected job is a retry.
- Added Flutter API coverage for `loadJobDetail` parsing of header fields, retry count, failure reason, and transition event fields.
- Strengthened server admin detail tests for timestamps, project/user/source header values, failure reason, transition job id/timestamps, retry linkage, and non-admin rejection.

### File List

- `_bmad-output/implementation-artifacts/6-2-admin-job-detail-and-event-trail.md`
- `_bmad-output/implementation-artifacts/6-2-completion-report-2026-05-29.md`
- `app/lib/main.dart`
- `app/test/src/admin/admin_api_test.dart`
- `server/tests/test_admin.py`
