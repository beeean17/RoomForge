# Story 4.1: Shared Spatial Model and 2D/3D View Shell

Status: complete

## Story

As a user,
I want the 2D and 3D room views to represent the same generated room,
so that switching views does not change or lose my layout state.

## Acceptance Criteria

1. Given a valid metric floor plan exists, when I open the planning editor, then the editor renders a room view from one shared spatial model.
2. Given I switch between 2D and 3D views, when the view changes, then selection, object identity, metric coordinates, scale, and unsaved state are preserved.
3. Given I open the planning editor at desktop, tablet, or mobile-review widths, when the 2D/3D shell lays out, then the canvas, view switcher, inspector entry point, and status area remain usable without overlapping critical content.

## Tasks / Subtasks

- [x] Verify Story 3.5/3.6 handoff before Epic 4.
  - [x] Confirm metric floor plan payloads use meters after calibration.
  - [x] Confirm image-pixel geometry remains separately traceable.
  - [x] Confirm `review_required` displays as `Needs review`.
  - [x] Confirm retry attempts link to the original reconstruction job.
- [x] Lock the shared spatial model contract with automated validation.
  - [x] Cover bridge initialization from metric floor plan payloads.
  - [x] Cover 2D/3D mode changes preserving selection, object identity, metric coordinates, scale, and unsaved state.
  - [x] Cover invalid non-meter floor plan fallback behavior.
- [x] Verify app/editor shell integration.
  - [x] Confirm Flutter can send a planning scene initialize payload.
  - [x] Confirm editor can emit scene state with shared spatial model payload.
  - [x] Confirm responsive shell controls exist for view switcher, inspector/status, and canvas.
- [x] Run affected validation and focused review.

## Dev Notes

- Current branch uses a recovery branch name because the queue branch `story/4.1-shared-spatial-model` already exists as a stale pre-Firebase branch and diverges heavily from the current primary. Do not rewrite that branch.
- Primary implementation surfaces:
  - `editor/src/spatialModel.ts`
  - `editor/src/main.ts`
  - `editor/src/style.css`
  - `app/lib/main.dart`
- Keep 2D/3D state in one editor spatial model. Do not introduce separate 2D and 3D state stores.
- Metric floor plan geometry must state `coordinateSpace: 'meters'`.
- Flutter owns app shell controls and bridge messages. Three.js/editor owns spatial rendering and canvas behavior.
- Furniture editing beyond existing placeholder/shared-state evidence is out of scope for this story.

### References

- `docs/legacy/_bmad-output/planning-artifacts/epics.md` Story 4.1.
- `docs/legacy/_bmad-output/planning-artifacts/architecture.md` frontend/editor boundary and bridge format.
- `docs/legacy/_bmad-output/planning-artifacts/ux-design-specification.md` 2D/3D switcher and responsive editor guidance.
- `docs/legacy/agent/STORY_QUEUE.md` Story 4.1.

## Dev Agent Record

### Agent Model Used

GPT-5 Codex

### Debug Log References

- Red phase: `npm run test:story-4.1` failed because `scale.metersPerSceneUnit` reset to `1` instead of preserving `0.25`.
- `npm run test:story-4.1`
- `npm run typecheck`
- `npm run build`
- `npm run test`
- `npm run check:editor-firebase-boundary`
- `flutter test test/src/editor/firebase_editor_bridge_mapper_test.dart test/src/projects/firebase_project_api_test.dart`
- `flutter analyze`
- `flutter test`
- `flutter build web --release`
- `git diff --check`
- Subagent focused review found no blocking or material code findings.

### Completion Notes List

- Handoff gate passed from current code evidence: floor plan persistence uses meter-space `metricGeometry`, image-space geometry remains separately persisted as confirmed/source geometry, `review_required` maps to `Needs review`, and retry jobs preserve `retry_of_job_id`.
- Added a Story 4.1 editor contract check that exercises metric bridge initialization, view-mode switch payloads, selected object identity, unsaved state, scale preservation, and non-meter fallback behavior.
- Fixed `spatialModelFromBridgePayload` to preserve `scale.metersPerSceneUnit` from the bridge scene payload instead of silently resetting it to the default.
- Verified the existing shell exposes a persistent 2D/3D switcher, canvas, inspector/status surfaces, and responsive CSS breakpoints for mobile-review widths.
- Subagent focused review verified the scale fix and Story 4.1 contract coverage.
- The queue branch name was unavailable because `story/4.1-shared-spatial-model` is a stale divergent branch. This story used `story/4.1-shared-spatial-model-validation` to avoid rewriting local history.

### File List

- `_bmad-output/implementation-artifacts/4-1-shared-spatial-model-and-2d-3d-view-shell.md`
- `editor/package.json`
- `editor/scripts/verify-story-4.1-spatial-model.mjs`
- `editor/src/spatialModel.ts`
