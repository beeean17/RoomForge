# Story 6.6: Provider State and Failure Source Diagnosis

Status: complete

## Story

As an admin user,
I want to see provider state and failure source classification,
so that I can distinguish OpenCV, input, calibration, API, database, and future provider failures.

## Acceptance Criteria

1. Given I open admin operations, when provider state is available, then I can see OpenCV/manual-assisted provider details, active job count, recent failure state, and optional future GPU lifecycle fields when enabled.
2. Given a reconstruction failure has a known source, when I inspect the job, then the system identifies whether the failure came from input quality, OpenCV candidate detection, user calibration, API handling, database state, or optional provider processing.

## Tasks / Subtasks

- [x] Verify admin diagnosis API authorization and envelope behavior.
  - [x] Confirm `/admin/jobs/{job_id}/diagnosis` requires admin authorization.
  - [x] Confirm non-admin access returns `unauthorized`.
  - [x] Confirm success and error responses use the shared `data`, `error`, and `meta.request_id` envelope.
- [x] Verify provider state.
  - [x] Include provider identifier and current job status.
  - [x] Include active job count for the provider.
  - [x] Include recent failure state for the provider.
  - [x] Include optional GPU lifecycle placeholder fields.
- [x] Verify failure-source classification.
  - [x] Classify input-quality failures.
  - [x] Classify real OpenCV worker failures such as `weak_edges`, `insufficient_lines`, and `insufficient_corners`.
  - [x] Classify calibration, API, database, and provider failures.
  - [x] Classify missing/unknown reason codes as `unknown` rather than provider failure.
- [x] Verify Flutter admin diagnosis display and API parsing.
- [x] Run full app/server validation and focused subagent review.

## Dev Notes

- Current baseline already contained a basic diagnosis endpoint and panel. This story expands provider state depth and corrects failure-source classification for actual OpenCV worker reason codes.
- The active branch uses a recovery branch name because `story/6.6-provider-failure-diagnosis` already exists as an older merged ancestor of current primary.
- The diagnosis endpoint reads persisted metadata only. It does not run OpenCV, GPU inference, or provider processing on the API server.
- Active job count and recent failure state are computed from admin job metadata for MVP scale. A repository aggregate query can replace this if operational data grows.

### References

- `docs/legacy/_bmad-output/planning-artifacts/epics.md` Story 6.6.
- `docs/legacy/_bmad-output/planning-artifacts/architecture.md` admin provider state, failure diagnosis, and no-heavy-CV API server rules.
- `docs/legacy/_bmad-output/planning-artifacts/prd.md` admin reconstruction/provider diagnosis requirements.
- `docs/legacy/_bmad-output/planning-artifacts/ux-design-specification.md` admin troubleshooting and failure-source guidance.
- `docs/legacy/agent/STORY_QUEUE.md` Story 6.6.

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
- Subagent focused review completed, found real OpenCV code classification blocker, then rechecked after fix with no blockers.

### Completion Notes List

- Expanded provider diagnosis payload with active job count, recent failure state, and GPU lifecycle placeholder.
- Updated Flutter diagnosis panel to show active jobs, GPU lifecycle state, and recent failure state.
- Added Flutter API coverage for diagnosis payload parsing.
- Fixed failure-source classification for real OpenCV worker reason codes: `weak_edges`, `insufficient_lines`, and `insufficient_corners`.
- Added `unknown` classification for missing reason codes to avoid mislabeling unknown failures as provider-processing failures.

### File List

- `_bmad-output/implementation-artifacts/6-6-provider-state-and-failure-diagnosis.md`
- `_bmad-output/implementation-artifacts/6-6-completion-report-2026-05-29.md`
- `app/lib/main.dart`
- `app/test/src/admin/admin_api_test.dart`
- `server/app/routers/admin.py`
- `server/tests/test_admin.py`
