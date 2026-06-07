# Story 6.1: Admin Job List and Status Filters

Status: complete

## Story

As an admin user,
I want to view reconstruction jobs by status,
so that I can monitor MVP processing health and spot failures.

## Acceptance Criteria

1. Given I am an authenticated admin, when I open the admin jobs screen, then I can view jobs grouped or filtered by `created`, `uploading`, `processing`, `review_required`, `succeeded`, `failed`, `timeout`, `cancelled`, and `retrying`.
2. Given I am not an admin, when I call admin job APIs, then access is denied with `unauthorized`.

## Tasks / Subtasks

- [x] Verify admin job list API authorization and envelope behavior.
  - [x] Confirm `/admin/jobs` requires admin authorization before repository access.
  - [x] Confirm non-admin access returns an `unauthorized` error envelope with no data payload.
  - [x] Confirm response shape preserves `data`, `error`, and `meta.request_id`.
- [x] Verify persisted reconstruction status filtering.
  - [x] Confirm allowed statuses include `created`, `uploading`, `processing`, `review_required`, `succeeded`, `failed`, `timeout`, `cancelled`, and `retrying`.
  - [x] Confirm each persisted status can be used as an admin job list filter.
  - [x] Confirm `review_required` is displayed as `Needs review`.
- [x] Verify Flutter admin API client behavior.
  - [x] Confirm `AdminApi.loadJobs(status:)` sends the status query parameter and bearer token.
  - [x] Confirm allowed statuses and job rows parse from the shared envelope.
  - [x] Confirm unauthorized admin responses surface as `AdminApiException`.
- [x] Run full app/server validation and focused subagent review.

## Dev Notes

- Current baseline already contained the admin job list route, Flutter admin API client, and admin screen filter wiring. This story branch adds focused validation coverage and story artifacts.
- The active branch uses a recovery branch name because `story/6.1-admin-job-list` already exists as an older merged ancestor of current primary.
- Admin job filtering remains server-owned. Flutter consumes `allowed_statuses` from the API and sends selected status values back to `/admin/jobs`.
- `review_required` remains the persisted status value and is displayed to users/admins as `Needs review`.

### References

- `docs/legacy/_bmad-output/planning-artifacts/epics.md` Story 6.1.
- `docs/legacy/_bmad-output/planning-artifacts/architecture.md` admin authorization, API envelope, and boundary rules.
- `docs/legacy/_bmad-output/planning-artifacts/prd.md` admin operations requirements.
- `docs/legacy/_bmad-output/planning-artifacts/ux-design-specification.md` admin table/filter/status badge guidance.
- `docs/legacy/agent/STORY_QUEUE.md` Story 6.1.

## Dev Agent Record

### Agent Model Used

GPT-5 Codex

### Debug Log References

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

- Added Flutter admin API coverage for status-filter request construction, bearer auth, shared-envelope parsing, allowed status parsing, `Needs review` labels, and unauthorized error surfacing.
- Strengthened server admin tests so every persisted reconstruction status is directly exercised as a `/admin/jobs?status=...` filter.
- Reconfirmed admin authorization denies normal users before exposing job data.
- Verified existing admin route and mapper reuse the canonical status vocabulary and `review_required` display mapping.

### File List

- `_bmad-output/implementation-artifacts/6-1-admin-job-list-and-status-filters.md`
- `_bmad-output/implementation-artifacts/6-1-completion-report-2026-05-29.md`
- `app/test/src/admin/admin_api_test.dart`
- `server/tests/test_admin.py`
