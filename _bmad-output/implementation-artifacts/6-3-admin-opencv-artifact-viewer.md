# Story 6.3: Admin OpenCV Artifact Viewer

Status: complete

## Story

As an admin user,
I want to inspect OpenCV artifacts and user corrections,
so that I can evaluate whether failures come from input quality, CV detection, or calibration.

## Acceptance Criteria

1. Given a job has OpenCV candidate output, when I open the artifact viewer, then I can inspect original image access, candidate preview, confidence/failure metadata, calibration summary, and user correction status.
2. Given candidate and confirmed geometry exist, when I inspect artifacts, then candidate geometry and user-confirmed geometry are visually and structurally separated.

## Tasks / Subtasks

- [x] Verify admin artifact API and authorization.
  - [x] Confirm `/admin/jobs/{job_id}/artifacts` requires admin authorization.
  - [x] Confirm non-admin access is denied before artifact data exposure.
  - [x] Confirm the route uses the shared `data`, `error`, and `meta.request_id` envelope.
- [x] Verify artifact content and separation.
  - [x] Confirm original source image access metadata is exposed as restricted admin data.
  - [x] Confirm candidate geometry includes coordinate space, geometry preview payload, confidence, and algorithm.
  - [x] Confirm failure metadata remains available through the job payload.
  - [x] Confirm confirmed geometry remains separate from candidate geometry.
  - [x] Confirm calibration summaries expose dimensions, deviation values, image geometry, and metric geometry.
- [x] Verify Flutter admin artifact viewer.
  - [x] Display original image access, failure metadata, candidate preview, confidence, algorithm, confirmed geometry status, and calibration summary.
  - [x] Use separate sections for candidate preview, user-confirmed geometry, and calibration summary.
- [x] Run full app/server validation and focused subagent review.

## Dev Notes

- Current baseline already contained the admin artifact endpoint and a basic Flutter artifact panel. This story expands the panel from count-only output into a usable diagnostic summary.
- The active branch uses a recovery branch name because `story/6.3-admin-artifact-viewer` already exists as an older merged ancestor of current primary.
- The MVP artifact viewer presents a structured text/JSON candidate preview, not a rendered source-image overlay. This is sufficient for current admin diagnosis but remains a follow-up if the term demo requires visual overlay inspection inside the admin screen.
- Candidate geometry remains separate from user-confirmed geometry in the API response, Flutter parsing tests, and visible admin sections.

### References

- `docs/legacy/_bmad-output/planning-artifacts/epics.md` Story 6.3.
- `docs/legacy/_bmad-output/planning-artifacts/architecture.md` admin authorization, OpenCV artifact, coordinate-space, and candidate/confirmed separation rules.
- `docs/legacy/_bmad-output/planning-artifacts/prd.md` admin artifact and reconstruction evaluation requirements.
- `docs/legacy/_bmad-output/planning-artifacts/ux-design-specification.md` admin CV artifact viewer guidance.
- `docs/legacy/agent/STORY_QUEUE.md` Story 6.3.

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

- Expanded the Flutter artifact viewer into separate original image access, candidate preview, user-confirmed geometry, and calibration summary sections.
- Added failure metadata display through the job payload in the artifact panel.
- Added app API coverage for `/admin/jobs/{job_id}/artifacts` and candidate/confirmed separation.
- Strengthened server admin artifact tests for source image access, failure metadata, algorithm/confidence, coordinate spaces, calibration dimensions/deviation values, and candidate/confirmed separation.

### File List

- `_bmad-output/implementation-artifacts/6-3-admin-opencv-artifact-viewer.md`
- `_bmad-output/implementation-artifacts/6-3-completion-report-2026-05-29.md`
- `app/lib/main.dart`
- `app/test/src/admin/admin_api_test.dart`
- `server/tests/test_admin.py`
