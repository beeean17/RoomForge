---
title: 'CV-UI.1 Web-Owned Editor Runtime'
type: 'refactor'
created: '2026-06-07'
status: 'in-progress'
context:
  - '{project-root}/docs/refactor/cv-final-refactor-development-plan.md'
  - '{project-root}/docs/design/specs/11-editor.md'
---

<frozen-after-approval reason="human-owned intent - do not modify unless human renegotiates">

## Intent

**Problem:** The React web editor route currently hosts the separate `editor/` Vite app in an iframe. That was useful for integration, but it keeps duplicate editor chrome alive and makes the final UI drift away from the React product shell.

**Approach:** Move the editor runtime toward web ownership by exposing a mountable runtime entry and rendering it from the React editor page without an iframe. Keep editor logic Firebase-free and let the React host continue to own auth, source-image loading, event persistence, and product UI.

## Boundaries & Constraints

**Always:** React web owns the final editor shell, project route, auth state, Firebase source reads, saving, and product-level status. The runtime owns Three.js, OpenCV workers, scene understanding, canvas interaction, and bridge-compatible event emission. Editor bridge payloads remain camelCase; persisted host payloads remain snake_case. Candidate objects remain distinct from confirmed objects.

**Ask First:** Do not delete the standalone `editor/` app, remove its package, or push remote branches without explicit user approval.

**Never:** Do not import Firebase into `editor/src`. Do not move heavy CV inference to `server/`. Do not rewrite the full editor UI in one pass or discard existing CV validation scripts.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Direct web mount | `/projects/:projectId/editor` with project data and optional source image | React renders the product editor shell and mounts the runtime in the canvas area without an iframe | Runtime load failure is shown as host status, not a route crash |
| WebGL unavailable | Browser cannot create WebGL renderer | Runtime reports failure and host keeps React shell visible | User sees a clear fallback/status message |
| Source image present | Host loads private image bytes | Runtime initialize payload includes `sourceImage` and CV extraction can run | Source load errors remain host-level source-image status |

</frozen-after-approval>

## Code Map

- `web/src/features/editor/EditorPage.tsx` -- current React editor route and host-side Firebase/event persistence owner.
- `web/src/features/editor/editorBridge.ts` -- bridge initialize payload and editor URL helpers.
- `web/src/features/editor/editorSourceImages.ts` -- private source-image data URL loader.
- `editor/src/main.ts` -- current monolithic editor app bootstrap, DOM shell, Three.js runtime, OpenCV/event handling.
- `editor/src/bridge.ts` -- runtime bridge message contract.
- `editor/src/*Worker.ts` -- OpenCV and scene-understanding workers that must stay browser/editor owned.
- `docs/design/specs/11-editor.md` -- final editor shell layout constraints.

## Tasks & Acceptance

**Execution:**
- [ ] `editor/src/main.ts` -- extract a mountable runtime entry so standalone editor boot and web direct mount share the same behavior.
- [ ] `editor/src/bridge.ts` or adjacent runtime contract -- support a direct host callback in addition to `postMessage` so React can receive runtime events without iframe messaging.
- [ ] `web/src/features/editor/EditorPage.tsx` -- replace iframe host surface with React editor shell and a direct runtime canvas/panel mount point.
- [ ] `web/src/features/editor/editorBridge.ts` -- keep initialize payload generation, but stop requiring iframe URL/origin for the direct-mount path.
- [ ] `web/src/design/globals.css` -- reuse existing editor shell classes and remove or demote iframe-specific layout where appropriate.
- [ ] `_bmad-output/implementation-artifacts/spec-cv-ui-1-web-editor-runtime.md` -- mark completed once validation passes.

**Acceptance Criteria:**
- Given the web editor route renders, when the project is available, then the runtime is mounted inside the React page without an iframe element.
- Given the runtime emits OpenCV, scene-understanding, or confirmed geometry events, when React receives them, then existing host persistence and CV summary behavior still work.
- Given source image bytes are loaded by React, when runtime initialization occurs, then the payload still includes source image and capture session data.
- Given `editor/` is built standalone, when its app boots, then existing editor validation scripts remain compatible.
- Given `editor/src` is inspected, when checking imports, then no Firebase SDK import exists.

## Design Notes

This story does not remove the `editor/` package. It turns the current standalone app into one consumer of a shared runtime entry, then lets `web` become another consumer. That keeps the change reversible and avoids mixing UI alignment, package deletion, and CV behavior changes in one step.

The expected end state for this story is:

```text
web EditorPage
  -> React topbar/tool shell
  -> direct runtime mount point
  -> host event persistence

editor runtime
  -> Three/OpenCV/scene state
  -> emits bridge-shaped messages
  -> no Firebase imports
```

## Verification

**Commands:**
- `npm --prefix web run typecheck` -- expected: TypeScript passes.
- `npm --prefix web run build` -- expected: production build succeeds, allowing existing Vite chunk warnings.
- `npm --prefix editor run typecheck` -- expected: TypeScript passes.
- `npm --prefix editor run build` -- expected: standalone editor build still succeeds.
- `npm --prefix editor run test:cv-4.2` -- expected: scene/object detector runtime validation still passes.
