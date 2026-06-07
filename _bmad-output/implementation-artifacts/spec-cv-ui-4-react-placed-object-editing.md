---
title: 'CV-UI.4 React Placed Object Editing'
type: 'feature'
created: '2026-06-07'
status: 'done'
baseline_commit: '98162a7039ded0f0cf2725d7203977c3fcd6493b'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/spec-cv-ui-4-to-8-execution-goal.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-cv-ui-3-react-candidate-review-tray.md'
  - '{project-root}/architecture.md'
---

# CV-UI.4 React Placed Object Editing

## Intent

React already owns the editor shell and candidate review tray. Users now need to manage placed furniture without relying on the hidden runtime inspector: list placed objects, select an object, inspect its metric transform, and edit position, rotation, size, lock, and deletion from the React inspector.

## Boundaries

React interprets runtime spatial payloads and sends bridge commands. The Three.js runtime remains the scene mutation authority. This story only covers placed furniture objects; structural fixture editing is CV-UI.5 and confirmation handoff is CV-UI.6.

## Tasks & Acceptance

- [x] `editor/src/runtime.ts` exposes furniture select and transform update bridge commands.
- [x] `web/src/features/editor/editorPlacedObjects.ts` parses placed furniture state from runtime payloads.
- [x] `web/src/features/editor/EditorPage.tsx` renders a React-owned placed object editor and dispatches select/edit commands.
- [x] `web/src/design/globals.css` styles dense object list and numeric transform controls without layout shifts.
- [x] `web/scripts/verify-editor-placed-objects.mjs` validates parser behavior and action availability.
- [x] Validation and browser smoke pass.

Acceptance criteria:

- Given furniture exists in runtime payloads, React shows it in a placed object list separate from candidate review.
- Given a placed object is selected, React shows position, rotation, size, source, and lock state.
- Given a user changes a transform value, React sends `roomforge.furniture.updateTransform` and runtime scene payloads update.
- Given a user selects a different placed object, React sends `roomforge.furniture.select` and the selected summary updates.
- Given an object is locked or deleted, React reflects the runtime result and keeps the candidate review state separate.

## Verification Plan

- `npm --prefix web run test:editor-placed`
- `npm --prefix web run typecheck`
- `npm --prefix editor run typecheck`
- `npm --prefix web run build`
- `npm --prefix editor run build`
- `git diff --check`
- Browser smoke on `/projects/demo-project/editor?candidateFixture=1`.

## Completion Notes

- Added `roomforge.furniture.select` and `roomforge.furniture.updateTransform` bridge commands so React can control placed furniture without using hidden runtime DOM controls.
- Added `editorPlacedObjects.ts` to normalize furniture payloads, selected state, source labels, lock state, room bounds, and outside-room warnings.
- Added a React-owned placed object editor with counts, selectable object cards, selected object summary, numeric transform fields, and lock/rotate/delete actions.
- Added a dev-only `?desktopFixture=1` surface override to make in-app browser smoke deterministic when the browser reports a mobile pointer.
- Added focused Node verification for placed object parsing and transform value behavior.

## Validation Results

- Passed: `npm --prefix web run test:editor-placed`
- Passed: `npm --prefix web run typecheck`
- Passed: `npm --prefix editor run typecheck`
- Passed: `npm --prefix web run build`
- Passed: `npm --prefix editor run build`
- Passed: `git diff --check`
- Passed: browser smoke on `http://127.0.0.1:9243/projects/demo-project/editor?locale=ko&candidateFixture=1&desktopFixture=1`; `iframeCount = 0`, `canvasCount = 1`, `candidateCards = 3`, `placedEditorCount = 1`, placing `Detected bed` created `placedCards = 1`, width transform updated to `2.05`, runtime events included `roomforge.furniture.updateTransform.response` and `roomforge.scene.updated`, and console error logs were empty.
- Smoke screenshot: `/private/tmp/roomforge-cv-ui-4-placed-object-smoke.png`

## Suggested Review Order

- Runtime bridge entrypoints: `editor/src/runtime.ts`
- Placed object payload model: `web/src/features/editor/editorPlacedObjects.ts`
- React placed object editor: `web/src/features/editor/EditorPage.tsx`
- Inspector styling: `web/src/design/globals.css`
- Focused verification: `web/scripts/verify-editor-placed-objects.mjs`
