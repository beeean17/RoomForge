# Story 5.3: Export Layout as JSON

Status: complete

## Story

As a signed-in user,
I want to export my room layout as JSON,
so that I can submit, inspect, or reuse the layout data outside the app.

## Acceptance Criteria

1. Given I own a saved or current valid layout, when I choose JSON export, then the system produces a JSON file or response containing room dimensions, floor plan data, source metadata references, and furniture state.
2. Given the current reconstruction result is marked needs review, when I try to export, then the UI shows a visible warning before export is allowed.
3. Given export fails, when the error is returned, then the app shows `Export failed` with a retry path where feasible.

## Tasks / Subtasks

- [x] Verify JSON export payload.
  - [x] Confirm server latest-layout export returns `roomforge_layout_json` with versioned layout payload.
  - [x] Confirm room dimensions, floor plan, source metadata references, and furniture state are preserved.
  - [x] Confirm legacy app API calls the export endpoint with bearer auth and parses the export payload.
- [x] Verify review-required warning behavior.
  - [x] Confirm top-level `review_required` export payload warns.
  - [x] Confirm top-level `reconstruction_status: review_required` warns.
  - [x] Confirm source metadata `reconstruction_status: review_required` warns.
  - [x] Confirm warning copy requires a second explicit Export JSON action.
- [x] Verify export failure/status behavior.
  - [x] Confirm existing editor shell displays `Export failed: ...` on API or generic export errors.
  - [x] Confirm existing command bar keeps the Export JSON action available as the retry path when not exporting.
- [x] Run app/server validation and focused review.

## Dev Notes

- Current branch uses a recovery branch name because `story/5.3-export-layout-json` already exists as an older merged ancestor of the current primary.
- Existing implementation already included FastAPI export routes, Flutter export API methods, Firebase export repository behavior, and editor export UI.
- This story validation branch tightens export payload and warning coverage rather than reimplementing the export path.
- Primary implementation/validation surfaces:
  - `server/app/routers/exports.py`
  - `server/tests/test_layouts.py`
  - `app/lib/src/projects/project_api.dart`
  - `app/lib/src/layouts/layout_export_warning.dart`
  - `app/lib/main.dart`
  - `app/test/src/projects/legacy_project_api_layout_test.dart`
  - `app/test/src/layouts/layout_export_warning_test.dart`

### References

- `docs/legacy/_bmad-output/planning-artifacts/epics.md` Story 5.3.
- `docs/legacy/_bmad-output/planning-artifacts/architecture.md` FastAPI export response, ownership, and data preservation rules.
- `docs/legacy/_bmad-output/planning-artifacts/prd.md` layout JSON export requirements.
- `docs/legacy/_bmad-output/planning-artifacts/ux-design-specification.md` export action and warning status guidance.
- `docs/legacy/agent/STORY_QUEUE.md` Story 5.3.

## Dev Agent Record

### Agent Model Used

GPT-5 Codex

### Debug Log References

- `dart format test/src/projects/legacy_project_api_layout_test.dart test/src/layouts/layout_export_warning_test.dart`
- `flutter test test/src/projects/legacy_project_api_layout_test.dart test/src/layouts/layout_export_warning_test.dart test/src/projects/firebase_project_api_test.dart`
- `.venv/bin/python -m pytest tests/test_layouts.py`
- `.venv/bin/python -m compileall app`
- `flutter analyze`
- `flutter test`
- `.venv/bin/python -m pytest`
- `npm run check:editor-firebase-boundary`
- `flutter build web --release`
- `git diff --check`
- Subagent focused review completed with no blocking or material findings.

### Completion Notes List

- Strengthened server export test coverage for source metadata job refs and complete furniture ID/position/size/rotation/color fields.
- Added legacy API export test coverage for endpoint path, bearer auth, shared envelope parsing, format/version, room/floor/source/furniture payloads.
- Added export-warning coverage for top-level `reconstruction_status: review_required` and second-click warning copy.
- Verified existing editor export flow uses `Exported JSON`, review warning, and `Export failed: ...` status language.

### File List

- `_bmad-output/implementation-artifacts/5-3-export-layout-as-json.md`
- `_bmad-output/implementation-artifacts/5-3-completion-report-2026-05-29.md`
- `app/test/src/layouts/layout_export_warning_test.dart`
- `app/test/src/projects/legacy_project_api_layout_test.dart`
- `server/tests/test_layouts.py`
