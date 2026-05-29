# Story 5.4: Save, Load, and Export Round-Trip Validation

Status: complete

## Story

As a developer,
I want automated validation for layout save/load/export round trips,
so that MVP layout data remains trustworthy.

## Acceptance Criteria

1. Given a layout contains room dimensions, floor plan data, source metadata references, and furniture objects, when it is saved, loaded, and exported, then all required layout and furniture fields are preserved exactly except server-managed metadata.
2. Given the API handles layout persistence, when project list, project detail, layout save, and layout load are exercised under MVP expected load, then non-CV API responses stay within the p95 target where measurable.

## Tasks / Subtasks

- [x] Verify server save/load/export round trip.
  - [x] Confirm required layout fields are identical across save response, latest-load response, and export payload.
  - [x] Confirm server-managed metadata is excluded from exact field comparison.
  - [x] Confirm non-CV project/list/detail/save/load p95 check remains under target in measurable local test.
- [x] Verify Flutter API round trip.
  - [x] Confirm legacy API save/load/export sequence preserves room dimensions.
  - [x] Confirm floor plan data and source metadata refs are preserved.
  - [x] Confirm furniture ID, category, position, size, rotation, and color are preserved.
  - [x] Confirm editor scene is preserved across the round trip.
- [x] Run app/server validation and focused review.

## Dev Notes

- Current branch uses a recovery branch name because `story/5.4-layout-round-trip-validation` already exists as an older merged ancestor of the current primary.
- Existing server round-trip and p95 tests already covered most Story 5.4 behavior.
- This story validation branch adds a Flutter API-level round-trip test using a stateful mock backend so app request/response parsing is validated as well.
- Primary implementation/validation surfaces:
  - `server/tests/test_layouts.py`
  - `app/test/src/projects/legacy_project_api_layout_test.dart`

### References

- `docs/legacy/_bmad-output/planning-artifacts/epics.md` Story 5.4.
- `docs/legacy/_bmad-output/planning-artifacts/architecture.md` data preservation, auth/ownership, and API boundary rules.
- `docs/legacy/agent/STORY_QUEUE.md` Story 5.4.

## Dev Agent Record

### Agent Model Used

GPT-5 Codex

### Debug Log References

- `dart format test/src/projects/legacy_project_api_layout_test.dart`
- `flutter test test/src/projects/legacy_project_api_layout_test.dart test/src/projects/firebase_project_api_test.dart`
- `.venv/bin/python -m pytest tests/test_layouts.py`
- `flutter analyze`
- `flutter test`
- `.venv/bin/python -m pytest`
- `.venv/bin/python -m compileall app`
- `npm run check:editor-firebase-boundary`
- `flutter build web --release`
- `git diff --check`
- Subagent focused review completed with no blocking or material findings.

### Completion Notes List

- Added a stateful Flutter legacy API round-trip test that saves a layout, reloads it, exports it, and compares only required domain fields.
- Reused existing server round-trip validation for save/load/export field preservation and local non-CV p95 smoke performance.
- Verified field preservation excludes server-managed IDs/timestamps while keeping room, floor plan, source metadata, furniture objects, and editor scene exact.

### File List

- `_bmad-output/implementation-artifacts/5-4-save-load-export-round-trip-validation.md`
- `_bmad-output/implementation-artifacts/5-4-completion-report-2026-05-29.md`
- `app/test/src/projects/legacy_project_api_layout_test.dart`
