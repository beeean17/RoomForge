---
title: 'CV-UI.5 React Structural Fixture Review'
type: 'feature'
created: '2026-06-07'
status: 'done'
baseline_commit: 'bea4726e1f2f9f623a3f2df0ab0a3fd3d026c39f'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/spec-cv-ui-4-to-8-execution-goal.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-cv-ui-4-react-placed-object-editing.md'
  - '{project-root}/architecture.md'
---

# CV-UI.5 React Structural Fixture Review

## Intent

CV-UI.4 moved placed furniture editing into React. Structural fixture candidates such as windows, doors, and built-ins still need a React-owned review path so users can place, select, and adjust wall/category/size controls without using hidden runtime DOM.

## Boundaries

The Three.js runtime remains authoritative for fixture mutation. React reads candidate and fixture payloads, then sends fixture bridge commands. This story does not confirm fixtures for persistence; confirmed object handoff is CV-UI.6.

## Tasks & Acceptance

- [x] `editor/src/fixtureModel.ts` can place a structural fixture from a CV candidate.
- [x] `editor/src/runtime.ts` exposes fixture select, place-candidate, and edit bridge commands.
- [x] `web/src/features/editor/editorStructuralFixtures.ts` parses structural fixture candidates and placed fixtures.
- [x] `web/src/features/editor/EditorPage.tsx` renders a React-owned structural fixture review panel.
- [x] `web/src/design/globals.css` styles compact fixture candidate cards and action controls.
- [x] `web/scripts/verify-editor-structural-fixtures.mjs` validates parser behavior.
- [x] Validation and browser smoke pass.

Acceptance criteria:

- Given a structural fixture candidate exists, React shows it separately from placed furniture.
- Given the user places a fixture candidate, runtime creates a structural fixture and marks the candidate as placed.
- Given a fixture is selected, React shows wall, category, size, confidence, and source metadata.
- Given wall/category/size actions are activated, React sends runtime fixture edit commands and scene events update.
- Given a fixture is deleted, candidate geometry remains traceable and returns to review-required state.

## Verification Plan

- `npm --prefix web run test:editor-fixtures`
- `npm --prefix web run typecheck`
- `npm --prefix editor run typecheck`
- `npm --prefix web run build`
- `npm --prefix editor run build`
- `git diff --check`
- Browser smoke on `/projects/demo-project/editor?candidateFixture=1&desktopFixture=1`.

## Completion Notes

- Added fixture candidate placement in `fixtureModel.ts`; structural candidates now become editable `structuralFixtures`.
- Added `roomforge.fixture.placeCandidate`, `roomforge.fixture.select`, and `roomforge.fixture.editSelected` bridge commands.
- Releasing a deleted fixture candidate now returns the source candidate to `Needs review` instead of losing traceability.
- Added `editorStructuralFixtures.ts` to normalize structural fixture candidates, placed fixtures, selected state, wall/category/size metadata, and action availability.
- Added a React-owned structural fixture review panel with separate candidate cards, placed fixture cards, selected fixture summary, wall/offset/size/category controls, and delete.
- Updated candidate review parsing so structural fixtures count as placed when they share a candidate id.

## Validation Results

- Passed: `npm --prefix web run test:editor-fixtures`
- Passed: `npm --prefix web run test:editor-candidates`
- Passed: `npm --prefix web run typecheck`
- Passed: `npm --prefix editor run typecheck`
- Passed: `npm --prefix web run build`
- Passed: `npm --prefix editor run build`
- Passed: `git diff --check`
- Passed: browser smoke on `http://127.0.0.1:9243/projects/demo-project/editor?locale=ko&candidateFixture=1&desktopFixture=1`; `iframeCount = 0`, `canvasCount = 1`, `fixtureReviewCount = 1`, placing `Fixture: window` created `fixtureCards = 1`, `Next wall` emitted `roomforge.fixture.editSelected.response` and `roomforge.fixture.updated`, selected wall changed to `front-wall`, and console error logs were empty.
- Smoke screenshot: `/private/tmp/roomforge-cv-ui-5-structural-fixture-smoke.png`

## Suggested Review Order

- Fixture placement model: `editor/src/fixtureModel.ts`
- Runtime bridge entrypoints: `editor/src/runtime.ts`
- Structural fixture parser: `web/src/features/editor/editorStructuralFixtures.ts`
- React fixture review panel: `web/src/features/editor/EditorPage.tsx`
- Inspector styling: `web/src/design/globals.css`
- Focused verification: `web/scripts/verify-editor-structural-fixtures.mjs`
