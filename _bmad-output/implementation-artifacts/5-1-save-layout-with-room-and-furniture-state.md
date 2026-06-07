# Story 5.1: Save Layout with Room and Furniture State

Status: complete

## Story

As a signed-in user,
I want to save my room layout,
so that I can return to the same room plan later.

## Acceptance Criteria

1. Given I own a project with a valid floor plan and furniture state, when I save the layout, then the API persists room dimensions, floor plan data, source metadata references, and furniture objects in Oracle.
2. Given furniture objects exist in the layout, when the layout is saved, then each object preserves ID, category, position, size, rotation, and color.
3. Given the save succeeds or fails, when the app receives the response, then the UI shows action-oriented status language such as `Saved` or `Save failed`.

## Tasks / Subtasks

- [x] Verify API layout save persistence.
  - [x] Confirm authenticated save route uses the shared response envelope.
  - [x] Confirm ownership is enforced before saving project layouts.
  - [x] Confirm room dimensions, floor plan, source metadata, furniture list, and editor scene persist.
- [x] Strengthen furniture state preservation coverage.
  - [x] Confirm furniture ID, category, position, size width/depth/height, rotation, and color are preserved in the server response.
  - [x] Confirm repository payload preserves the furniture object list exactly.
- [x] Verify app save integration and status language.
  - [x] Confirm legacy API client posts snake_case layout payloads to the save endpoint and parses saved layout IDs/state.
  - [x] Confirm existing editor shell exposes `Saving...`, `Saved`, and `Save failed` status language.
- [x] Run server/app validation and focused review.

## Dev Notes

- Current branch uses a recovery branch name because `story/5.1-save-layout` already exists as an older merged ancestor of the current primary.
- Existing implementation already included the layout router, Oracle repository, migration, in-memory repository, Flutter project API save method, and editor save UI.
- This story validation branch tightens test coverage rather than reimplementing the persistence path.
- Primary implementation/validation surfaces:
  - `server/app/routers/layouts.py`
  - `server/app/repositories/layouts.py`
  - `server/migrations/008_layouts.sql`
  - `server/tests/test_layouts.py`
  - `app/lib/src/projects/project_api.dart`
  - `app/lib/main.dart`
  - `app/test/src/projects/legacy_project_api_layout_test.dart`

### References

- `docs/legacy/_bmad-output/planning-artifacts/epics.md` Story 5.1.
- `docs/legacy/_bmad-output/planning-artifacts/architecture.md` FastAPI/Oracle ownership and layout persistence rules.
- `docs/legacy/_bmad-output/planning-artifacts/prd.md` layout persistence and Oracle API requirements.
- `docs/legacy/_bmad-output/planning-artifacts/ux-design-specification.md` save layout action/status language guidance.
- `docs/legacy/agent/STORY_QUEUE.md` Story 5.1.

## Dev Agent Record

### Agent Model Used

GPT-5 Codex

### Debug Log References

- `dart format test/src/projects/legacy_project_api_layout_test.dart`
- `flutter test test/src/projects/legacy_project_api_layout_test.dart test/src/projects/firebase_project_api_test.dart`
- `.venv/bin/python -m pytest tests/test_layouts.py`
- `.venv/bin/python -m compileall app`
- `flutter analyze`
- `flutter test`
- `.venv/bin/python -m pytest`
- `flutter build web --release`
- `npm run check:editor-firebase-boundary`
- `git diff --check`
- Subagent focused review completed with no blocking or material findings.

### Completion Notes List

- Added Flutter legacy API layout-save test coverage for endpoint path, auth header, snake_case payload, room/floor/source/furniture/editor state, and saved layout parsing.
- Strengthened server layout-save test coverage for furniture depth/height and exact persisted furniture payload.
- Verified existing save UI exposes action-oriented `Saving...`, `Saved`, and `Save failed` status language in the editor shell.
- Confirmed the Oracle layout migration stores room, floor plan, source metadata, furniture objects, and editor scene in JSON CLOB columns.

### File List

- `_bmad-output/implementation-artifacts/5-1-save-layout-with-room-and-furniture-state.md`
- `_bmad-output/implementation-artifacts/5-1-completion-report-2026-05-29.md`
- `app/test/src/projects/legacy_project_api_layout_test.dart`
- `server/tests/test_layouts.py`
