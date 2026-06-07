---
title: 'CV-UI.6 React Confirmed Object Handoff'
type: 'feature'
created: '2026-06-07'
status: 'done'
baseline_commit: '32e7b49091a2744bb33f3276dcb222b11e6549cc'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/spec-cv-ui-4-to-8-execution-goal.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-cv-ui-5-structural-fixture-review.md'
  - '{project-root}/architecture.md'
---

# CV-UI.6 React Confirmed Object Handoff

## Intent

React now owns candidate review, placed furniture editing, and structural fixture review. Users need an explicit handoff that separates CV candidates, editable placed objects, and user-confirmed objects before save/export work uses the scene state.

## Boundaries

This story adds client-side confirmation state and bridge commands only. It does not change API persistence schemas or introduce new persisted reconstruction statuses.

## Tasks & Acceptance

- [x] `editor/src/confirmationModel.ts` converts placed furniture and structural fixtures into confirmed scene objects.
- [x] `editor/src/runtime.ts` exposes selected and all-placed confirmation bridge commands.
- [x] `web/src/features/editor/editorConfirmationHandoff.ts` parses placed vs confirmed handoff state.
- [x] `web/src/features/editor/EditorPage.tsx` renders a React-owned confirmation handoff panel.
- [x] `web/src/design/globals.css` styles confirmation counts, selected handoff state, and confirmed list.
- [x] `web/scripts/verify-editor-confirmation-handoff.mjs` validates parser behavior.
- [x] Validation and browser smoke pass.

Acceptance criteria:

- Given placed furniture or fixtures exist, React shows them as unconfirmed until confirmation.
- Given selected placed object exists, React can confirm only that selected object.
- Given multiple placed objects exist, React can confirm all placed objects.
- Given confirmed objects exist, React lists them separately from candidates and editable placed controls.
- Given confirmation occurs, runtime emits confirmation events and `confirmedObjects` updates without deleting candidates or placed editable objects.

## Verification Plan

- `npm --prefix web run test:editor-confirmation`
- `npm --prefix web run typecheck`
- `npm --prefix editor run typecheck`
- `npm --prefix web run build`
- `npm --prefix editor run build`
- `git diff --check`
- Browser smoke on `/projects/demo-project/editor?candidateFixture=1&desktopFixture=1`.

## Completion Notes

- Added `confirmationModel.ts` to convert editable furniture and structural fixtures into `confirmedObjects` while preserving candidate and placed editable layers.
- Added `roomforge.confirmation.confirmSelected` and `roomforge.confirmation.confirmAllPlaced` bridge commands.
- Added `editorConfirmationHandoff.ts` to compute placed, unconfirmed, confirmed, and selected-confirmed state from runtime payloads.
- Added a React-owned confirmation handoff panel with selected confirmation, all-placed confirmation, placed object state rows, and confirmed object list.
- The story does not change persistence schemas or reconstruction statuses.

## Validation Results

- Passed: `npm --prefix web run test:editor-confirmation`
- Passed: `npm --prefix web run typecheck`
- Passed: `npm --prefix editor run typecheck`
- Passed: `npm --prefix web run build`
- Passed: `npm --prefix editor run build`
- Passed: `git diff --check`
- Passed: browser smoke on `http://127.0.0.1:9243/projects/demo-project/editor?locale=ko&candidateFixture=1&desktopFixture=1`; `iframeCount = 0`, `canvasCount = 1`, handoff panel rendered, placing `Detected bed` and `Fixture: window` created two placed rows, `Confirm all placed` created two confirmed rows (`Detected bed`, `Window`), events included `roomforge.confirmation.confirmAllPlaced.response` and `roomforge.confirmation.confirmed`, and console error logs were empty.
- Smoke screenshot: `/private/tmp/roomforge-cv-ui-6-confirmation-handoff-smoke.png`

## Suggested Review Order

- Confirmation conversion model: `editor/src/confirmationModel.ts`
- Runtime bridge entrypoints: `editor/src/runtime.ts`
- Confirmation parser: `web/src/features/editor/editorConfirmationHandoff.ts`
- React handoff panel: `web/src/features/editor/EditorPage.tsx`
- Inspector styling: `web/src/design/globals.css`
- Focused verification: `web/scripts/verify-editor-confirmation-handoff.mjs`
