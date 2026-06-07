# Story 5.2: Load Saved Layout

Status: complete

## Story

As a signed-in user,
I want to load a saved room layout,
so that I can continue editing without losing prior work.

## Acceptance Criteria

1. Given I own a saved layout, when I open it from a project, then the API returns the saved room dimensions, floor plan, source metadata references, and furniture state.
2. Given the layout loads successfully, when the editor receives layout data, then the shared spatial model is restored accurately in 2D and 3D.
3. Given I try to load another user's layout, when the API checks ownership, then access is denied without exposing layout data.

## Tasks / Subtasks

- [x] Verify layout load API behavior.
  - [x] Confirm latest-layout endpoint returns saved room, floor plan, source metadata, furniture, and editor scene fields.
  - [x] Confirm legacy app API calls the latest-layout endpoint with bearer auth and parses saved state.
  - [x] Confirm server tests deny cross-user layout access without returning layout data.
- [x] Verify editor restoration behavior.
  - [x] Confirm saved layout maps to camelCase editor bridge payload.
  - [x] Confirm 2D and 3D view modes restore through the bridge payload.
  - [x] Confirm editor spatial model restores room metric geometry, selected furniture, furniture size, position, rotation, color, and saved clean state.
- [x] Run app/editor/server validation and focused review.

## Dev Notes

- Current branch uses a recovery branch name because `story/5.2-load-layout` already exists as an older merged ancestor of the current primary.
- Existing implementation already included server load routes, Flutter `loadLatestLayout`, editor scene initialization, and Firebase bridge mapping.
- This story validation branch adds focused tests rather than rewriting the load flow.
- Primary implementation/validation surfaces:
  - `server/app/routers/layouts.py`
  - `server/app/repositories/layouts.py`
  - `server/tests/test_layouts.py`
  - `app/lib/src/projects/project_api.dart`
  - `app/lib/src/editor/firebase_editor_bridge_mapper.dart`
  - `app/lib/main.dart`
  - `editor/src/spatialModel.ts`
  - `editor/scripts/verify-story-5.2-load-layout.mjs`

### References

- `docs/legacy/_bmad-output/planning-artifacts/epics.md` Story 5.2.
- `docs/legacy/_bmad-output/planning-artifacts/architecture.md` FastAPI/Oracle ownership, Flutter/editor bridge, and coordinate-space rules.
- `docs/legacy/_bmad-output/planning-artifacts/prd.md` load saved room layout requirements.
- `docs/legacy/_bmad-output/planning-artifacts/ux-design-specification.md` editor continuity and saved layout workflow guidance.
- `docs/legacy/agent/STORY_QUEUE.md` Story 5.2.

## Dev Agent Record

### Agent Model Used

GPT-5 Codex

### Debug Log References

- `dart format test/src/projects/legacy_project_api_layout_test.dart test/src/editor/firebase_editor_bridge_mapper_test.dart`
- `npm run test:story-5.2`
- `flutter test test/src/projects/legacy_project_api_layout_test.dart test/src/editor/firebase_editor_bridge_mapper_test.dart test/src/projects/firebase_project_api_test.dart`
- `.venv/bin/python -m pytest tests/test_layouts.py`
- `npm run typecheck`
- `npm run test`
- `npm run build`
- `.venv/bin/python -m compileall app`
- `flutter analyze`
- `flutter test`
- `.venv/bin/python -m pytest`
- `npm run check:editor-firebase-boundary`
- `flutter build web --release`
- `git diff --check`
- Subagent focused review completed with no blocking or material findings.

### Completion Notes List

- Added legacy API load-latest test coverage for endpoint path, bearer auth, saved room/floor/source/furniture/editor scene parsing.
- Added Firebase editor bridge mapper coverage proving saved layouts restore both 2D and 3D scene payloads with selected furniture and metric room state.
- Added editor spatial-model verification script proving loaded bridge payloads restore room geometry, furniture state, selection, view mode, and clean saved state.
- Confirmed existing server tests cover latest-layout retrieval and cross-user access denial.

### File List

- `_bmad-output/implementation-artifacts/5-2-load-saved-layout.md`
- `_bmad-output/implementation-artifacts/5-2-completion-report-2026-05-29.md`
- `app/test/src/editor/firebase_editor_bridge_mapper_test.dart`
- `app/test/src/projects/legacy_project_api_layout_test.dart`
- `editor/package.json`
- `editor/scripts/verify-story-5.2-load-layout.mjs`
