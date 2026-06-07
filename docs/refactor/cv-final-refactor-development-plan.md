# RoomForge CV Final Refactor Development Plan

Status: active implementation plan
Created: 2026-06-07
Owner: Codex story execution

## Purpose

This document is the execution plan for making RoomForge's CV workflow work as
the final refactoring baseline.

The target product flow is:

```text
guided room photos + user room dimensions
-> browser-first CV
-> editable room shell, furniture candidates, fixture candidates
-> user correction inside the editor
-> Firebase persistence owned by the web/native host
```

The goal is not image editing, inpainting, or a photorealistic empty-room
render. The goal is an editable metric scene graph produced from room photos:
room boundary, furniture candidates, structural fixtures, confidence/review
state, and user-confirmed objects.

## Source Of Truth

Use these documents in this order when a conflict appears:

1. `docs/refactor/routing-page-definition.md`
2. `docs/refactor/current-workspace-workflow.md`
3. `docs/refactor/firebase-target-architecture.md`
4. `docs/refactor/firebase-data-contract.md`
5. `_bmad-output/planning-artifacts/cv-scene-understanding-epics-and-stories.md`
6. `_bmad-output/planning-artifacts/cv-provider-decision-gate.md`
7. `docs/refactor/cv-evaluation-fixtures.md`

Older Flutter-web ownership assumptions are historical. Desktop workspace,
editor route hosting, and admin are React web. Flutter native owns camera-first
guided capture. The editor package owns rendering, OpenCV/browser CV, and object
manipulation only; it must not import Firebase.

## Non-Negotiable Implementation Rules

- Firebase is the default persistence path.
- Legacy FastAPI/server behavior remains explicit `legacy_api` only.
- The editor package must not import Firebase SDKs or call Firestore, Storage,
  or Auth.
- React web host owns desktop auth, project loading, private Storage reads,
  bridge initialization, saving, and permission handling.
- Flutter native owns guided capture and upload.
- Browser/editor workers own OpenCV and scene-understanding execution.
- Heavy CV/GPU/deep-learning inference must not run on the lightweight legacy
  API server.
- Firestore and export payloads use `snake_case`.
- Editor bridge payloads use `camelCase`.
- Candidate CV objects remain separate from confirmed user objects.
- Geometry payloads must state coordinate space.
- Image-space outputs use `image_pixels`.
- Metric scene outputs use `meters`.
- Persisted statuses are exactly `created`, `uploading`, `processing`,
  `review_required`, `succeeded`, `failed`, `timeout`, `cancelled`, `retrying`.
- User-facing `review_required` copy is `Needs review`.
- Source photos remain immutable evidence. Do not edit or inpaint them.

## Current Implementation Baseline

Repository evidence shows these pieces already exist:

- `editor/src/opencvWorker.ts` processes real `sourceImage.dataUrl` pixels for
  boundary/candidate geometry using OpenCV.js.
- `editor/src/sceneUnderstandingWorker.ts` maps detector output into furniture
  and fixture candidates, but its default provider is still mock/rule based.
- `editor/src/captureSession.ts`, `scenePlacement.ts`,
  `sceneCandidateMerge.ts`, `sceneCoverage.ts`, `candidateTray.ts`, and related
  scripts provide the editor-side CV scene graph foundation.
- `app/lib/src/editor/firebase_editor_bridge_mapper.dart` maps Firebase scene
  understanding and capture-session contracts to bridge `camelCase`.
- `app/lib/src/projects/firebase_project_api.dart` supports Firebase source
  image upload and scene-understanding repository boundaries.
- `web/src/features/editor/EditorPage.tsx` is currently a React editor mockup.
  It does not yet host the real `editor/` Vite/Three/OpenCV app through a
  bridge.
- `web/src/features/projects/projectRepository.ts` reads projects from
  Firestore but does not yet provide source-image/capture-session bytes to the
  editor bridge.

The major gap is not that CV files are missing. The gap is that the current
React web editor route is not yet connected to the real editor/CV runtime and
the web host does not yet provide private source image bytes or persist editor
bridge events.

## Target Architecture

```text
React web route /projects/:projectId/editor
  - owns Firebase Auth
  - reads Firestore project/source/capture metadata
  - reads private Cloud Storage image blobs
  - converts selected image blobs to object URL or data URL
  - initializes the editor via postMessage bridge
  - listens for editor CV, geometry, fixture, and scene events
  - persists snake_case documents through Firebase repositories

editor/ Vite app
  - receives only camelCase bridge payloads
  - runs OpenCV worker for room boundary extraction
  - runs scene understanding worker for object/fixture candidates
  - maintains candidate vs confirmed editor state
  - emits bridge events with candidate, confirmed, and save/export payloads
  - never imports Firebase

Flutter native
  - guided capture
  - upload progress and retry
  - mobile preview/status

server/
  - legacy/reference only unless explicit legacy_api is selected
```

## Story Queue

This final queue is intentionally narrower than the earlier 22-story CV backlog.
The older backlog built the editor-side foundation. This queue finishes the
current refactor by connecting that foundation to the React/Firebase desktop
path and making the runtime behavior testable.

| Order | Story | Branch | Commit |
|---:|---|---|---|
| 0 | CV-R0.1 - Final CV Refactor Development Plan | `story/cv-final-development-plan` | `docs(cv-r0.1): add final cv refactor development plan` |
| 1 | CV-R1.1 - React Editor Bridge Host | `story/cv-r1.1-react-editor-bridge-host` | `feat(cv-r1.1): host editor bridge in react editor route` |
| 2 | CV-R1.2 - Source Image Byte Handoff | `story/cv-r1.2-source-image-byte-handoff` | `feat(cv-r1.2): pass private source image bytes to editor` |
| 3 | CV-R1.3 - Editor CV Event Persistence | `story/cv-r1.3-editor-cv-event-persistence` | `feat(cv-r1.3): persist editor cv bridge events` |
| 4 | CV-R2.1 - Image-Driven Scene Candidate Provider | `story/cv-r2.1-image-driven-scene-provider` | `feat(cv-r2.1): derive scene candidates from source images` |
| 5 | CV-R2.2 - Candidate Review Integration | `story/cv-r2.2-candidate-review-integration` | `feat(cv-r2.2): surface cv candidates in hosted editor flow` |
| 6 | CV-R3.1 - CV Runtime Evaluation Gate | `story/cv-r3.1-cv-runtime-evaluation-gate` | `test(cv-r3.1): validate hosted cv runtime and metrics` |

## Story Details

### CV-R0.1 - Final CV Refactor Development Plan

Scope:

- Add this document.
- Reconcile the older CV backlog with the newer React web/native mobile routing
  decision.
- Define story branches, commits, acceptance criteria, and validation commands.

Acceptance:

- A single Markdown plan exists under `docs/refactor/`.
- The plan identifies current code that exists and current integration gaps.
- The plan states editor/Firebase/server boundaries.
- The plan defines the story queue used for implementation.

Validation:

```bash
git diff --check docs/refactor/cv-final-refactor-development-plan.md
```

### CV-R1.1 - React Editor Bridge Host

Scope:

- Replace the React editor mockup route with a host shell for the real `editor/`
  app.
- Use an iframe bridge boundary first. Do not rewrite the editor in React in
  this story.
- Create typed bridge message helpers in `web/`.
- Send `roomforge.scene.initialize` after the iframe is ready.
- Receive editor messages and render host-side status/debug state.

Acceptance:

- `/projects/:projectId/editor` loads the real editor runtime in desktop mode.
- The editor receives an initialize bridge payload.
- The editor route still handles loading/error/project ownership states.
- Mobile-web editor access remains locked or guided to desktop according to the
  route definition.
- `editor/` still has no Firebase imports.

Validation:

```bash
npm --prefix web run typecheck
npm --prefix web run build
npm --prefix editor run typecheck
```

### CV-R1.2 - Source Image Byte Handoff

Scope:

- Add React web Firebase helpers for source image/capture metadata needed by the
  editor route.
- Read owner-scoped source image Storage blobs through Firebase SDK in `web/`.
- Convert selected private image blob to a data URL for the editor bridge.
- Include `sourceImage` and `captureSession` in the initialize payload.

Acceptance:

- The editor receives `sourceImage.dataUrl` when a project has an owned source
  image.
- `opencvWorker` can run without returning `no_source_image` for that payload.
- No public image URL is used as authority.
- The editor package remains Firebase-free.

Validation:

```bash
npm --prefix web run typecheck
npm --prefix web run build
npm --prefix editor run test:cv-4.1
npm --prefix editor run test:cv-4.2
```

### CV-R1.3 - Editor CV Event Persistence

Scope:

- Listen for editor bridge events from OpenCV and scene understanding.
- Convert bridge `camelCase` payloads to Firestore `snake_case`.
- Persist OpenCV results, scene-understanding results, and confirmed geometry
  through React web Firebase repository functions.
- Keep candidate objects separate from confirmed objects.

Acceptance:

- Host receives candidate extraction and confirmation events.
- Firestore write payloads use `snake_case`.
- Persisted status uses allowed values only.
- `review_required` is displayed as `Needs review`.
- Permission failures remain host-level errors, not editor errors.

Validation:

```bash
npm --prefix web run typecheck
npm --prefix web run build
npm --prefix editor run typecheck
```

### CV-R2.1 - Image-Driven Scene Candidate Provider

Scope:

- Upgrade the default scene-understanding worker path so it is image driven when
  image bytes are available.
- Keep configured `detectorOutput` as the deterministic test seam.
- Add a browser-safe image-proposal path that decodes source images off the main
  thread and produces object/fixture candidate boxes.
- Keep provider metadata explicit so future WebGPU/ONNX/SAM/Cloud providers can
  replace the implementation without changing contracts.

Acceptance:

- With capture images and no configured detector output, scene understanding is
  derived from image dimensions/pixels instead of returning the same hard-coded
  chair every time.
- Candidate outputs include source image id, image role, bounding box,
  confidence, review state, and coordinate space.
- Low-confidence or heuristic outputs are `review_required`.
- Manual editing remains the fallback.

Validation:

```bash
npm --prefix editor run test:cv-4.2
npm --prefix editor run test:cv-5.2
npm --prefix editor run test:cv-5.3
npm --prefix editor run typecheck
```

### CV-R2.2 - Candidate Review Integration

Scope:

- Ensure hosted editor initialization triggers OpenCV and scene-understanding
  candidate extraction when source images are available.
- Surface candidate tray counts, fixture counts, coverage, and review-needed
  status in the hosted route.
- Preserve all existing user correction paths.

Acceptance:

- Source image input leads to visible CV candidates in the editor candidate
  tray.
- Furniture and fixtures are editable, rejectable, and confirmable.
- The web host can show extraction status without exposing Firebase internals to
  the editor.

Validation:

```bash
npm --prefix web run build
npm --prefix editor run build
npm --prefix editor run test:cv-3.2
npm --prefix editor run test:cv-3.3
npm --prefix editor run test:cv-3.4
```

### CV-R3.1 - CV Runtime Evaluation Gate

Scope:

- Add hosted-runtime smoke validation for the bridge/source-image/CV flow.
- Run existing fixture manifest and metrics harness.
- Document whether browser-first CV remains sufficient for MVP or whether a
  model/cloud provider story should be opened next.

Acceptance:

- Evaluation fixtures validate.
- Metrics harness runs.
- Final report identifies tested commands, runtime limitations, and any
  remaining provider gap.
- No SAM/Cloud GPU dependency is added unless a future story explicitly changes
  the provider decision.

Validation:

```bash
npm --prefix editor run test:cv-7.1
npm --prefix editor run test:cv-7.2
npm --prefix editor run test:cv-7.3
npm --prefix web run build
```

## Branch And Commit Policy

Use this local flow:

```text
epic/cv-final-refactor
  <- story/cv-final-development-plan
  <- story/cv-r1.1-react-editor-bridge-host
  <- story/cv-r1.2-source-image-byte-handoff
  <- story/cv-r1.3-editor-cv-event-persistence
  <- story/cv-r2.1-image-driven-scene-provider
  <- story/cv-r2.2-candidate-review-integration
  <- story/cv-r3.1-cv-runtime-evaluation-gate
```

Each story gets one local commit. After validation, fast-forward merge the story
branch into `epic/cv-final-refactor`. Do not push or create a PR without
explicit approval.

## Open Engineering Notes

- A real semantic furniture detector cannot be produced by OpenCV alone with
  high reliability. The MVP provider should be honest: browser-first,
  image-driven candidate proposals plus user correction. WebGPU/ONNX or a cloud
  provider can be added after evaluation justifies it.
- React web may use Firebase SDKs because it is the desktop host. The editor
  iframe/app may not.
- The first implementation should prefer an iframe bridge over a full
  react-three-fiber rewrite. This preserves existing tested editor code and
  reduces merge conflict risk with current web design work.
- If Storage reads cannot be fully exercised locally, add deterministic unit
  tests around payload mapping and report the environment limitation.
