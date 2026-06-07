# CV-UI.2 - React-Owned Editor Controls

Status: Completed

## Goal

`web` React editor page owns the visible editor controls while `editor/` remains the Three.js/OpenCV runtime module. The runtime should not require a separate product entrypoint to expose controls; React sends bridge commands and the runtime mutates scene state.

## Architecture Decision

- Keep `editor/` source code and runtime boundaries.
- Keep `editor/src/runtime.ts` as the reusable mountable runtime.
- Keep `editor/src/devStandalone.ts` only as a local standalone harness.
- Use `web/src/features/editor/EditorPage.tsx` for product-facing controls.
- Use bridge messages for runtime actions so UI ownership stays in React and canvas/scene ownership stays in Three.js.

## Scope

- Add runtime bridge commands for view mode, split view, camera presets, layers, canvas toggles, furniture add/edit, selection clear, and candidate actions.
- Render React-owned tool rail, canvas toolbar, layer toggles, and inspector around the embedded runtime.
- Keep runtime state synchronized through scene payloads.
- Reuse existing `web` editor styling patterns.

## Acceptance Criteria

- The product editor route renders no iframe.
- The visible editor controls are React components in `web`.
- The embedded runtime accepts React bridge commands for core editor operations.
- Layer/canvas/view/selection state can round-trip from runtime payload to React UI.
- The standalone editor still works through `editor/src/devStandalone.ts`.
- Typecheck/build and focused editor validation commands pass.

## Validation Plan

- `npm --prefix editor run typecheck`
- `npm --prefix web run typecheck`
- `npm --prefix editor run build`
- `npm --prefix web run build`
- `npm --prefix editor run test:story-4.6`
- `npm --prefix editor run test:cv-4.2`
- Browser smoke on the product editor route.

## Completion Notes

- Added bridge commands for React-owned view, camera, layer, canvas, furniture, selection, and candidate operations.
- Replaced the product editor host body with a React workbench layout: tool rail, canvas toolbar, embedded runtime surface, and inspector.
- Runtime payloads now expose `splitViewActive`, `layerVisibility`, and `canvasToggleState` so React controls can stay synchronized with scene state.
- Browser smoke was run against `http://127.0.0.1:9242/projects/demo-project/editor` in demo mode with a desktop viewport.
- Smoke screenshot: `/private/tmp/roomforge-cv-ui-2-editor-smoke.png`.
- Interaction smoke confirmed the React 3D view button and furniture layer toggle emit runtime bridge events without console errors.

## Validation Results

- Passed: `npm --prefix editor run typecheck`
- Passed: `npm --prefix web run typecheck`
- Passed: `npm --prefix editor run build`
- Passed: `npm --prefix web run build`
- Passed: `npm --prefix editor run test:story-4.6`
- Passed: `npm --prefix editor run test:cv-4.2`
- Passed: browser smoke; `iframeCount = 0`, `canvasCount = 1`, `workbenchCount = 1`, `inspectorCount = 1`.
- Passed: interaction smoke; active view changed to `3D`, furniture layer `aria-pressed` changed to `false`, and browser console error logs were empty.
