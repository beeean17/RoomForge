---
title: "RoomForge CV Scene Understanding Epics and Stories"
status: "draft"
created: "2026-06-02"
updated: "2026-06-02"
workflowType: "epics-and-stories"
stepsCompleted:
  - "step-01-validate-prerequisites-adapted"
  - "step-02-design-epics-adapted"
  - "step-03-create-stories-adapted"
inputDocuments:
  - "User milestone discussion in Codex thread on 2026-06-01 and 2026-06-02"
  - "docs/refactor/firebase-target-architecture.md"
  - "docs/refactor/firebase-epics-and-stories.md"
  - "docs/legacy/agent/GOAL_TEMPLATE.md"
  - "docs/legacy/agent/STORY_QUEUE.md"
project_name: "RoomForge"
user_name: "Yoon"
date: "2026-06-02"
---

# CV Scene Understanding Epics and Stories - RoomForge

This artifact adds a CV-centered backlog for RoomForge. It does not replace the Firebase refactor backlog or the existing layout editor backlog. It decomposes the new direction:

```text
guided room photos + user-provided room dimensions
-> browser-first CV scene understanding
-> furniture and fixture candidates
-> editable 2D/3D room scene
-> user correction as the natural fallback
```

The goal is not photo inpainting or photorealistic empty-room generation. The goal is to transform room photos into an editable metric scene graph: room shell, movable furniture objects, structural fixtures, confidence, coverage, and review state.

## Backlog Invariants

- Flutter owns routing, auth state, Android capture UX, project screens, upload UI, Firebase API calls, save/load/export, and accessible non-canvas controls.
- Three.js/editor owns browser CV workers, OpenCV/WebGPU/ONNX integration, 2D/3D rendering, spatial object manipulation, visual candidate overlays, and object placement validation.
- The editor package must not import Firebase SDKs or call Firestore/Storage/Auth directly.
- Firebase/Firestore remains the default system of record.
- Source photos are not edited or inpainted. CV outputs structured candidates only.
- Browser-first CV is the default path. SAM 3 or Cloud GPU is a later provider decision, not the default MVP path.
- Heavy GPU/deep-learning workloads must not run on the lightweight legacy API server.
- Candidate CV outputs remain separate from user-confirmed scene objects.
- Image-space outputs use `coordinate_space: image_pixels`.
- Metric scene outputs use `coordinate_space: meters`.
- Persisted reconstruction statuses remain exactly `created`, `uploading`, `processing`, `review_required`, `succeeded`, `failed`, `timeout`, `cancelled`, `retrying`.
- Persisted `review_required` displays to users as `Needs review`.
- User-facing project, image, capture, result, layout, export, and artifact data requires authentication and ownership.
- Every CV-derived object must be editable, deletable, and replaceable by a manual object.

## Requirements Inventory

### Functional Requirements

CV-FR1: Users can create a capture session for a room project with room width, depth, and height in meters.

CV-FR2: Users can capture or upload guided room photos with explicit roles: `overview`, `front_wall`, `right_wall`, `back_wall`, `left_wall`, and `extra`.

CV-FR3: Android users can see an accuracy-enhancement toggle for ARCore Depth where supported, with automatic fallback to normal guided photos.

CV-FR4: The system stores capture photos, role metadata, capture method, optional depth metadata references, and room dimensions in Firebase-owned project data.

CV-FR5: The editor can run a browser-first scene understanding worker against one or more capture images.

CV-FR6: The scene understanding worker produces candidate objects for movable furniture: bed, desk, chair, wardrobe, sofa, table, shelf/cabinet/custom where supported.

CV-FR7: The scene understanding worker produces candidate objects for structural fixtures: door, window, built-in/closet where supported.

CV-FR8: Candidate objects include source image reference, image role, category, confidence, bounding box, optional mask reference, review state, and coordinate space.

CV-FR9: The system maps CV candidates into approximate metric room placement using user-provided room dimensions, image role, object category priors, and placement heuristics.

CV-FR10: The editor displays detected furniture candidates in a candidate tray separate from placed objects.

CV-FR11: The editor can auto-place CV candidates into the 2D/3D room view using suggested metric position, size, and rotation.

CV-FR12: Users can drag candidate furniture from the candidate tray into the room view.

CV-FR13: Users can edit, delete, resize, rotate, recategorize, accept, or reject every CV-derived object.

CV-FR14: Door/window/fixture candidates are attached to room walls by default but remain user editable.

CV-FR15: The system can merge candidates from multiple photos into one scene graph and reduce duplicate objects.

CV-FR16: The system reports capture coverage per wall and suggests extra photos when a wall or object confidence is low.

CV-FR17: CV results can be persisted and reloaded without silently converting candidates into confirmed user objects.

CV-FR18: Users can save confirmed scene objects, structural fixtures, room shell, and furniture layout after review.

CV-FR19: The project includes an evaluation harness for CV detection, classification, placement, size estimation, and correction count.

CV-FR20: The project includes a decision gate for whether browser CV is sufficient or whether SAM 3/Cloud GPU should be added later.

### Non-Functional Requirements

CV-NFR1: Browser CV work must run off the main UI thread where practical.

CV-NFR2: WebGPU acceleration must gracefully fallback to WASM/manual flows when unsupported.

CV-NFR3: CV failure must not block manual room editing or layout saving.

CV-NFR4: Capture and CV states must be understandable without exposing Firebase or model-provider implementation details to normal users.

CV-NFR5: Candidate and confirmed object contracts must preserve `snake_case` in Firestore and `camelCase` on the editor bridge.

CV-NFR6: Mobile capture controls and desktop review controls must target WCAG 2.2 AA where they are non-canvas UI.

CV-NFR7: CV artifacts and photos must remain private to the owning user unless admin authorization applies.

CV-NFR8: Evaluation should be reproducible from a small checked-in manifest or documented local fixture set without requiring cloud GPU.

### Architecture Requirements

- Add capture-session and scene-understanding contracts without moving persistence into the editor package.
- Add a new scene understanding worker instead of overloading `editor/src/opencvWorker.ts` with unrelated object-detection responsibilities.
- Keep existing OpenCV room-boundary extraction available as a supporting signal.
- Represent CV-derived furniture and fixtures as candidate scene objects before user confirmation.
- Treat source photos as evidence; do not attempt to generate an edited or empty-room source image.
- Leave Cloud GPU/SAM 3 as provider-extension architecture only until evaluation shows browser CV is insufficient.

### UX Requirements

UX-CV1: Mobile capture must guide users through photo roles and explain that partially occluded walls are acceptable.

UX-CV2: Android accuracy-enhancement copy must describe ARCore Depth as optional distance information, not as a requirement.

UX-CV3: The desktop review UI must clearly separate candidate tray objects, auto-placed objects, and confirmed saved objects.

UX-CV4: Candidate confidence and `Needs review` states must be visible without relying on color alone.

UX-CV5: Users must be able to recover from false positives, missed objects, and bad placements without leaving the editor.

UX-CV6: The room view must support direct manipulation for CV-derived objects with existing accessible edit controls as fallback.

## Epic List

1. Epic CV-1: Capture and Scene Contract Foundation
2. Epic CV-2: Guided Android Photo Capture
3. Epic CV-3: Candidate Tray and Editable Scene Graph
4. Epic CV-4: Browser Scene Understanding Worker
5. Epic CV-5: Metric Placement and Multi-Photo Merge
6. Epic CV-6: Android ARCore Depth Enhancement
7. Epic CV-7: Evaluation and Provider Decision Gate

## Execution Queue

CV execution uses one branch per epic and one local commit per completed story. Do not create story branches for CV stories unless a recovery branch is explicitly required.

| Order | Story | Epic branch | Commit message |
|---:|---|---|---|
| 1 | CV-1.1 - Capture Session and Scene Understanding Contracts | `epic/cv-1-capture-scene-contract-foundation` | `feat(cv-1.1): add capture session and scene understanding contracts` |
| 2 | CV-1.2 - Provider Boundary and Status Mapping | `epic/cv-1-capture-scene-contract-foundation` | `feat(cv-1.2): define scene understanding provider boundary` |
| 3 | CV-2.1 - Guided Capture Session Creation UI | `epic/cv-2-guided-android-photo-capture` | `feat(cv-2.1): add guided capture session creation` |
| 4 | CV-2.2 - Multi-Photo Upload and Role Metadata | `epic/cv-2-guided-android-photo-capture` | `feat(cv-2.2): upload guided photos with roles` |
| 5 | CV-2.3 - Desktop Capture Session Continuation | `epic/cv-2-guided-android-photo-capture` | `feat(cv-2.3): continue capture sessions in editor` |
| 6 | CV-3.1 - Spatial Model Candidate and Fixture Layers | `epic/cv-3-candidate-tray-editable-scene` | `feat(cv-3.1): add candidate and fixture scene layers` |
| 7 | CV-3.2 - Candidate Tray Review UI | `epic/cv-3-candidate-tray-editable-scene` | `feat(cv-3.2): add candidate tray review UI` |
| 8 | CV-3.3 - Candidate Drag Drop and Placement Editing | `epic/cv-3-candidate-tray-editable-scene` | `feat(cv-3.3): place and edit cv candidates` |
| 9 | CV-3.4 - Structural Fixture Editing | `epic/cv-3-candidate-tray-editable-scene` | `feat(cv-3.4): edit structural fixture candidates` |
| 10 | CV-4.1 - Scene Understanding Worker Scaffold | `epic/cv-4-browser-scene-understanding` | `feat(cv-4.1): scaffold scene understanding worker` |
| 11 | CV-4.2 - Browser Object Detector Runtime | `epic/cv-4-browser-scene-understanding` | `feat(cv-4.2): add browser object detector runtime` |
| 12 | CV-4.3 - Scene Understanding Persistence | `epic/cv-4-browser-scene-understanding` | `feat(cv-4.3): persist scene understanding results` |
| 13 | CV-5.1 - Category Size Priors | `epic/cv-5-metric-placement-multi-photo-merge` | `feat(cv-5.1): add furniture size priors` |
| 14 | CV-5.2 - Wall Role Metric Placement | `epic/cv-5-metric-placement-multi-photo-merge` | `feat(cv-5.2): estimate metric placement from wall roles` |
| 15 | CV-5.3 - Multi-Photo Candidate Merge | `epic/cv-5-metric-placement-multi-photo-merge` | `feat(cv-5.3): merge candidates across guided photos` |
| 16 | CV-5.4 - Coverage and Extra Photo Guidance | `epic/cv-5-metric-placement-multi-photo-merge` | `feat(cv-5.4): add capture coverage guidance` |
| 17 | CV-6.1 - Android ARCore Depth Capability Toggle | `epic/cv-6-android-arcore-depth` | `feat(cv-6.1): add arcore depth capability toggle` |
| 18 | CV-6.2 - Depth Metadata Capture and Storage | `epic/cv-6-android-arcore-depth` | `feat(cv-6.2): store arcore depth metadata` |
| 19 | CV-6.3 - Depth Assisted Placement | `epic/cv-6-android-arcore-depth` | `feat(cv-6.3): improve placement with depth metadata` |
| 20 | CV-7.1 - CV Evaluation Fixture Manifest | `epic/cv-7-evaluation-provider-gate` | `test(cv-7.1): add cv evaluation fixtures manifest` |
| 21 | CV-7.2 - CV Metrics Harness and Report | `epic/cv-7-evaluation-provider-gate` | `test(cv-7.2): add cv metrics harness` |
| 22 | CV-7.3 - SAM 3 and Cloud GPU Decision Gate | `epic/cv-7-evaluation-provider-gate` | `docs(cv-7.3): document cv provider decision gate` |

## Common Goal Rules

Use this common preface for every CV story goal:

```text
Current baseline:
- Treat the existing Firebase default backend, editor bridge, spatial editor, save/load/export, and admin diagnostics as baseline unless repository evidence contradicts this.
- Do not reimplement completed layout-editor or Firebase stories unless the current story explicitly requires a small integration change.

Before implementing:
- Read _bmad-output/planning-artifacts/cv-scene-understanding-epics-and-stories.md for the target story.
- Read docs/refactor/firebase-target-architecture.md for boundaries.
- Read docs/refactor/firebase-epics-and-stories.md when touching Firebase data contracts or repositories.
- Read docs/legacy/agent/GOAL_TEMPLATE.md and docs/legacy/agent/STORY_QUEUE.md for local branch/commit conventions until non-legacy agent docs are restored.
- Produce a short story preflight: scope, expected files, validation, invariants, and commit message.

Branch setup:
- Use the target epic branch listed in this artifact.
- Keep one epic per branch and one completed local commit per story.
- Continue subsequent stories in the same epic on the same epic branch.
- Do not create story branches for CV stories unless a focused recovery branch is required.
- Do not push or create a PR without explicit user permission.

Scope:
- Keep changes limited to the target CV story.
- Keep source photos immutable.
- Preserve candidate-vs-confirmed separation.
- Do not add SAM 3, Cloud GPU, or heavy server inference unless the story explicitly asks for provider decision documentation only.

Validation:
- Run affected Flutter tests/analyze when app code is touched.
- Run affected editor tests/build/scripts when editor code is touched.
- Add the smallest meaningful test or verification script for new contracts and CV logic.
- If a local tool is unavailable, use documented substitutes and report the limitation.

Complete when:
- Acceptance criteria pass or documented partials have evidence.
- Relevant checks pass, are substituted, or are unavailable with documented environment reason.
- A completion report is produced if story-queue execution mode is active.
- One local story commit is created if autonomous/queue mode is active.
```

## Epic CV-1: Capture and Scene Contract Foundation

**Goal:** Establish the Firestore, bridge, and editor contracts for guided capture sessions and scene understanding outputs before UI and CV implementation begin.

**Value:** Developer agents can add capture, CV, and editor review stories without inventing schema fields story by story.

### Story CV-1.1: Capture Session and Scene Understanding Contracts

As a developer agent, I want capture session and scene understanding model contracts, so that multi-photo CV inputs and outputs have stable typed boundaries.

**Goal Prompt:**

```text
/goal Implement Story CV-1.1 - Capture Session and Scene Understanding Contracts.

Use epic branch epic/cv-1-capture-scene-contract-foundation.
Commit message: feat(cv-1.1): add capture session and scene understanding contracts

Story outcome:
- Add typed contracts for capture sessions, capture images, scene understanding results, candidate scene objects, placed scene objects, confirmed scene objects, and structural fixtures.
- Preserve Firestore snake_case, editor bridge camelCase, and candidate-vs-confirmed separation.
- Do not implement capture UI or real CV inference in this story.
```

**Acceptance Criteria:**

- Given a project has room dimensions, when a capture session is created in the model layer, then it can represent capture method, image roles, owner/project IDs, and schema version.
- Given scene understanding results are persisted, when candidate objects are serialized, then each candidate includes category, source image reference, role, confidence, coordinate space, review state, and suggested metric placement fields.
- Given confirmed scene objects are persisted, when they are serialized, then they do not overwrite or remove candidate objects.
- Given bridge payloads are generated, when validation runs, then Firestore fields remain `snake_case` and bridge fields remain `camelCase`.

**Validation:**

- Dart model/serializer tests for new contracts.
- Bridge mapper tests for camelCase/snake_case conversion.
- Existing Firebase contract tests still pass.

**Likely Files:**

- `app/lib/src/firebase/firebase_models.dart`
- `app/lib/src/firebase/firebase_serializers.dart`
- `app/lib/src/editor/firebase_editor_bridge_mapper.dart`
- `app/test/src/firebase/*`
- `app/test/src/editor/*`

### Story CV-1.2: Provider Boundary and Status Mapping

As a developer agent, I want a scene understanding provider boundary, so that browser CV, ARCore Depth, and future Cloud GPU providers can share one result contract.

**Goal Prompt:**

```text
/goal Implement Story CV-1.2 - Provider Boundary and Status Mapping.

Use epic branch epic/cv-1-capture-scene-contract-foundation.
Commit message: feat(cv-1.2): define scene understanding provider boundary

Story outcome:
- Define provider types, quality status mapping, failure reasons, and result lifecycle for scene understanding.
- Keep persisted reconstruction statuses within the existing allowed vocabulary.
- Do not add SAM 3, Cloud GPU execution, or real detector code.
```

**Acceptance Criteria:**

- Given browser CV is the default provider, when a scene understanding job/result is represented, then provider type and algorithm/model identifiers are explicit.
- Given scene understanding confidence is low, when status is persisted or displayed, then `review_required` is stored and `Needs review` is user-facing.
- Given a provider fails, when failure metadata is stored, then it uses structured reason codes without adding unsupported job statuses.
- Given future Cloud GPU support is added later, when provider boundaries are reviewed, then no editor-to-Firebase or API-server GPU dependency is required.

**Validation:**

- Unit tests for provider type/status/failure mappings.
- Static review that no heavy inference dependency is introduced.

**Likely Files:**

- `app/lib/src/firebase/firebase_models.dart`
- `app/lib/src/projects/project_api.dart`
- `app/lib/src/projects/firebase_project_api.dart`
- `editor/src/bridge.ts`

## Epic CV-2: Guided Android Photo Capture

**Goal:** Let users create a room capture session from Android/Flutter with role-based photos and optional ARCore Depth enhancement.

**Value:** CV receives structured multi-photo input instead of a single ambiguous image.

### Story CV-2.1: Guided Capture Session Creation UI

As a RoomForge user, I want a guided capture flow with room dimensions and photo roles, so that I can collect photos useful for CV reconstruction.

**Goal Prompt:**

```text
/goal Implement Story CV-2.1 - Guided Capture Session Creation UI.

Use epic branch epic/cv-2-guided-android-photo-capture.
Commit message: feat(cv-2.1): add guided capture session creation

Story outcome:
- Add Flutter UI/state for starting a guided capture session with room dimensions and required/optional photo roles.
- Explain that walls may be partially occluded and can be fixed later.
- Do not implement actual object detection in this story.
```

**Acceptance Criteria:**

- Given a user owns a project, when they start guided capture, then they can enter or confirm room width, depth, and height in meters.
- Given capture guidance is shown, when the user reviews steps, then `overview`, `front_wall`, `right_wall`, `back_wall`, and `left_wall` roles are explained.
- Given a wall is blocked by furniture, when guidance is shown, then the user is told that visible wall/floor evidence is enough and manual correction remains available.
- Given non-canvas controls are used, when accessibility is checked, then labels and states are available to assistive technology.

**Validation:**

- Flutter widget tests for capture session start state and guidance copy.
- Existing project and room dimension flows remain intact.

**Likely Files:**

- `app/lib/main.dart`
- `app/lib/src/projects/*`
- `app/test/src/projects/*`

### Story CV-2.2: Multi-Photo Upload and Role Metadata

As a RoomForge user, I want to upload multiple guided photos with roles, so that CV can analyze each wall separately.

**Goal Prompt:**

```text
/goal Implement Story CV-2.2 - Multi-Photo Upload and Role Metadata.

Use epic branch epic/cv-2-guided-android-photo-capture.
Commit message: feat(cv-2.2): upload guided photos with roles

Story outcome:
- Extend source image upload flow to support capture-session image roles.
- Persist capture image metadata and Storage paths under the owning project.
- Preserve existing single source image behavior where still used.
```

**Acceptance Criteria:**

- Given a capture session exists, when the user uploads an `overview` image, then Storage and Firestore metadata include the capture session ID and role.
- Given the user uploads wall images, when metadata is persisted, then roles are one of the allowed values.
- Given upload fails for one role, when recovery UI appears, then already uploaded role images remain recoverable.
- Given Storage rules are enforced, when another user requests the image, then access is denied.

**Validation:**

- Repository tests for capture image metadata.
- Upload recovery widget tests where applicable.
- Storage path/rules validation remains passing.

**Likely Files:**

- `app/lib/src/projects/firebase_project_api.dart`
- `app/lib/src/projects/firebase_source_image_upload.dart`
- `app/lib/src/firebase/firebase_project_repository.dart`
- `app/storage.rules`

### Story CV-2.3: Desktop Capture Session Continuation

As a RoomForge user, I want to continue a mobile capture session on desktop, so that I can review CV results in the richer editor.

**Goal Prompt:**

```text
/goal Implement Story CV-2.3 - Desktop Capture Session Continuation.

Use epic branch epic/cv-2-guided-android-photo-capture.
Commit message: feat(cv-2.3): continue capture sessions in editor

Story outcome:
- Load capture sessions and role images into the editor bridge context.
- Let the desktop editor know which images are available for scene understanding.
- Do not run real CV inference yet.
```

**Acceptance Criteria:**

- Given a capture session has uploaded images, when the project opens on desktop, then available image roles are visible to the reconstruction/editor flow.
- Given the editor initializes, when bridge payloads are sent, then capture session metadata and source image references are available without Firebase SDK imports in the editor.
- Given no capture session exists, when the editor opens, then existing manual/layout behavior still works.

**Validation:**

- Bridge mapper tests for capture session payloads.
- Editor initialization test or verification script for capture metadata fallback.

**Likely Files:**

- `app/lib/src/editor/firebase_editor_bridge_mapper.dart`
- `editor/src/bridge.ts`
- `editor/src/main.ts`
- `app/test/src/editor/*`

## Epic CV-3: Candidate Tray and Editable Scene Graph

**Goal:** Make CV outputs useful and recoverable by separating candidate objects from placed and confirmed objects.

**Value:** CV errors become normal editable state, not product failure.

### Story CV-3.1: Spatial Model Candidate and Fixture Layers

As a developer agent, I want the editor spatial model to include candidate and fixture layers, so that CV-derived objects can be represented before confirmation.

**Goal Prompt:**

```text
/goal Implement Story CV-3.1 - Spatial Model Candidate and Fixture Layers.

Use epic branch epic/cv-3-candidate-tray-editable-scene.
Commit message: feat(cv-3.1): add candidate and fixture scene layers

Story outcome:
- Extend the editor spatial model with candidateObjects, structuralFixtures, placedObjects, and confirmed object mapping.
- Preserve existing furniture editing behavior.
```

**Acceptance Criteria:**

- Given a bridge payload contains candidate objects, when the editor model is parsed, then candidates are kept separate from furniture objects.
- Given a payload contains structural fixtures, when the model is parsed, then fixtures are associated with walls or room shell without becoming movable furniture.
- Given existing saved layouts load, when no candidate layer exists, then fallback defaults preserve current behavior.

**Validation:**

- Editor unit tests for spatial model parsing and fallback.
- Existing furniture model tests still pass.

**Likely Files:**

- `editor/src/spatialModel.ts`
- `editor/src/furnitureModel.ts`
- `editor/src/measurementGuidance.ts`

### Story CV-3.2: Candidate Tray Review UI

As a RoomForge user, I want detected objects in a candidate tray, so that I can review what CV found before or after placement.

**Goal Prompt:**

```text
/goal Implement Story CV-3.2 - Candidate Tray Review UI.

Use epic branch epic/cv-3-candidate-tray-editable-scene.
Commit message: feat(cv-3.2): add candidate tray review UI

Story outcome:
- Add an editor candidate tray listing CV furniture and fixture candidates with category, confidence, source role, and review state.
- Allow reject/delete and category adjustment in UI state.
```

**Acceptance Criteria:**

- Given candidate objects exist, when the editor renders, then they appear in a candidate tray separate from placed furniture.
- Given a candidate has low confidence, when displayed, then `Needs review` is visible without relying only on color.
- Given a user rejects a candidate, when state updates, then it is no longer auto-placed but remains traceable until save/discard.
- Given a user changes candidate category, when state updates, then suggested asset and size prior can be recalculated later.

**Validation:**

- Editor DOM/unit tests or verification script for candidate tray states.
- Accessibility check for candidate controls where feasible.

**Likely Files:**

- `editor/src/main.ts`
- `editor/src/style.css`
- `editor/scripts/*`

### Story CV-3.3: Candidate Drag Drop and Placement Editing

As a RoomForge user, I want to drag detected candidates into the room and edit them, so that CV becomes a fast starting point instead of a fixed answer.

**Goal Prompt:**

```text
/goal Implement Story CV-3.3 - Candidate Drag Drop and Placement Editing.

Use epic branch epic/cv-3-candidate-tray-editable-scene.
Commit message: feat(cv-3.3): place and edit cv candidates

Story outcome:
- Convert candidate furniture into placed furniture objects through auto-place, click-place, or drag/drop.
- Reuse existing move, rotate, resize, delete, and selection behavior.
```

**Acceptance Criteria:**

- Given a furniture candidate has suggested placement, when scene understanding results load, then it can be auto-placed in the room view.
- Given a candidate is not placed, when the user drags or activates placement, then it becomes a placed editable object linked to the source candidate.
- Given a placed CV object is selected, when existing edit controls are used, then move/rotate/resize/delete updates the placed object.
- Given a user deletes a placed object, when state updates, then the original candidate can be marked rejected or available for re-placement.

**Validation:**

- Editor verification script for candidate-to-furniture conversion.
- Existing furniture edit tests still pass.

**Likely Files:**

- `editor/src/main.ts`
- `editor/src/furnitureModel.ts`
- `editor/src/spatialModel.ts`

### Story CV-3.4: Structural Fixture Editing

As a RoomForge user, I want CV-detected doors and windows to appear as editable fixtures, so that fixed room elements are represented without becoming movable furniture.

**Goal Prompt:**

```text
/goal Implement Story CV-3.4 - Structural Fixture Editing.

Use epic branch epic/cv-3-candidate-tray-editable-scene.
Commit message: feat(cv-3.4): edit structural fixture candidates

Story outcome:
- Add structural fixture rendering and editing for doors/windows/built-ins.
- Fixtures attach to room walls by default and remain editable.
```

**Acceptance Criteria:**

- Given a door/window candidate exists, when the editor applies it, then it appears on an associated wall in 2D/3D.
- Given a fixture is selected, when inspector controls are used, then wall, offset, width, height, and category can be adjusted.
- Given a fixture is incorrect, when the user deletes or recategorizes it, then saved confirmed fixtures reflect the correction.
- Given fixture confidence is low, when displayed, then `Needs review` is visible.

**Validation:**

- Editor tests or verification script for fixture parse/render/edit state.
- Save/load bridge tests for fixture payloads.

**Likely Files:**

- `editor/src/spatialModel.ts`
- `editor/src/main.ts`
- `editor/src/style.css`
- `app/lib/src/editor/firebase_editor_bridge_mapper.dart`

## Epic CV-4: Browser Scene Understanding Worker

**Goal:** Add browser-first CV inference that can produce object candidates without relying on Cloud GPU.

**Value:** The project demonstrates meaningful CV while keeping deployment and cost realistic.

### Story CV-4.1: Scene Understanding Worker Scaffold

As a developer agent, I want a scene understanding worker with mock provider output, so that UI and persistence can integrate before real detector runtime is selected.

**Goal Prompt:**

```text
/goal Implement Story CV-4.1 - Scene Understanding Worker Scaffold.

Use epic branch epic/cv-4-browser-scene-understanding.
Commit message: feat(cv-4.1): scaffold scene understanding worker

Story outcome:
- Add editor/src/sceneUnderstandingWorker.ts with bridge messages, mock provider mode, error handling, and typed output.
- Keep editor main thread responsive.
```

**Acceptance Criteria:**

- Given capture images are available, when `roomforge.sceneUnderstanding.extractCandidates` is sent, then the worker returns typed mock candidate results.
- Given no image is available, when extraction is requested, then the worker returns a structured failure without blocking manual editing.
- Given the worker emits results, when main editor receives them, then candidate tray and scene layers can apply them.

**Validation:**

- Editor tests or verification script for worker message contract.
- `npm` build/test command for editor where available.

**Likely Files:**

- `editor/src/sceneUnderstandingWorker.ts`
- `editor/src/main.ts`
- `editor/src/bridge.ts`

### Story CV-4.2: Browser Object Detector Runtime

As a RoomForge user, I want browser CV to detect furniture and fixtures from guided photos, so that the editor can suggest a starting layout.

**Goal Prompt:**

```text
/goal Implement Story CV-4.2 - Browser Object Detector Runtime.

Use epic branch epic/cv-4-browser-scene-understanding.
Commit message: feat(cv-4.2): add browser object detector runtime

Story outcome:
- Add a browser object detector runtime behind the scene understanding worker.
- Prefer WebGPU where available and fallback to WASM/manual behavior where unavailable.
- Do not require SAM 3 or Cloud GPU.
```

**Acceptance Criteria:**

- Given WebGPU is available and model assets are present, when scene understanding runs, then object candidates are produced from at least one source image.
- Given WebGPU is unavailable, when scene understanding runs, then the worker uses fallback or reports unsupported runtime without breaking the editor.
- Given detector output includes boxes/classes/scores, when mapped to candidates, then categories, confidence, source image, bbox, and coordinate space are populated.
- Given unsupported detector classes appear, when mapped, then they become `custom` or are filtered according to configured thresholds.

**Validation:**

- Editor runtime tests with mocked detector output.
- Manual or scripted browser check with a fixture image if model assets are available.
- Bundle/build check for editor.

**Likely Files:**

- `editor/package.json`
- `editor/src/sceneUnderstandingWorker.ts`
- `editor/public/models/*` or documented model asset path
- `editor/scripts/*`

### Story CV-4.3: Scene Understanding Persistence

As a RoomForge user, I want CV scene understanding results persisted, so that I can resume review later without rerunning analysis.

**Goal Prompt:**

```text
/goal Implement Story CV-4.3 - Scene Understanding Persistence.

Use epic branch epic/cv-4-browser-scene-understanding.
Commit message: feat(cv-4.3): persist scene understanding results

Story outcome:
- Persist scene understanding results in Firebase under the owning project.
- Reload persisted candidate objects into the editor bridge.
- Do not convert candidates into confirmed objects until user action.
```

**Acceptance Criteria:**

- Given scene understanding completes, when Flutter receives the result, then candidate result metadata is stored under the project owner.
- Given a user reopens the project, when a result exists, then candidates are loaded into the editor without rerunning detection by default.
- Given another user attempts access, when Firestore/Storage rules apply, then candidate result data is denied.
- Given a candidate is later confirmed, when saved, then the original candidate result remains available for traceability.

**Validation:**

- Firebase repository tests for scene result save/load.
- Bridge mapper tests for persisted candidate result payloads.
- Rules tests where feasible.

**Likely Files:**

- `app/lib/src/projects/firebase_project_api.dart`
- `app/lib/src/firebase/firebase_project_repository.dart`
- `app/firestore.rules`
- `app/test/src/firebase/*`

## Epic CV-5: Metric Placement and Multi-Photo Merge

**Goal:** Convert detection boxes from one or more guided photos into approximate room-meter placement and merged scene objects.

**Value:** CV output becomes useful layout state, not just a list of labels.

### Story CV-5.1: Category Size Priors

As a developer agent, I want category size priors for room objects, so that detected candidates can become plausible 2D/3D assets.

**Goal Prompt:**

```text
/goal Implement Story CV-5.1 - Category Size Priors.

Use epic branch epic/cv-5-metric-placement-multi-photo-merge.
Commit message: feat(cv-5.1): add furniture size priors

Story outcome:
- Add configurable size priors and representative asset mapping for furniture and fixtures.
- Use priors for suggested object size when direct metric evidence is weak.
```

**Acceptance Criteria:**

- Given a candidate category is `bed`, `desk`, `chair`, `wardrobe`, `sofa`, or `table`, when placement is estimated, then a plausible default metric size is available.
- Given a candidate category changes, when size is recalculated, then the prior changes without losing user edits after confirmation.
- Given a category is unknown, when placement is estimated, then a custom fallback size and asset are used.

**Validation:**

- Editor unit tests for size-prior lookup and fallback.
- Bridge tests preserve selected size after user confirmation.

**Likely Files:**

- `editor/src/furnitureModel.ts`
- `editor/src/spatialModel.ts`
- `app/lib/src/editor/firebase_editor_bridge_mapper.dart`

### Story CV-5.2: Wall Role Metric Placement

As a RoomForge user, I want detected objects to appear near their likely real location, so that the generated room layout starts close enough to edit.

**Goal Prompt:**

```text
/goal Implement Story CV-5.2 - Wall Role Metric Placement.

Use epic branch epic/cv-5-metric-placement-multi-photo-merge.
Commit message: feat(cv-5.2): estimate metric placement from wall roles

Story outcome:
- Estimate candidate object position and rotation from image role, bbox bottom center, room dimensions, and category priors.
- Store the result as suggested placement, not as confirmed truth.
```

**Acceptance Criteria:**

- Given a `front_wall` image candidate, when metric placement is estimated, then the object is placed relative to the front wall in room coordinates.
- Given a `right_wall`, `back_wall`, or `left_wall` image candidate, when placement is estimated, then wall association and rotation are adjusted accordingly.
- Given bbox or role confidence is weak, when suggested placement is generated, then the object is marked `review_required`.
- Given room dimensions change before confirmation, when placement recalculates, then candidate suggestions update in meters.

**Validation:**

- Unit tests for wall-role projection and bounds clamping.
- Editor verification script for suggested placement rendering.

**Likely Files:**

- `editor/src/scenePlacement.ts`
- `editor/src/spatialModel.ts`
- `editor/src/measurementGuidance.ts`

### Story CV-5.3: Multi-Photo Candidate Merge

As a RoomForge user, I want candidates from multiple photos merged, so that the same bed or desk does not appear multiple times.

**Goal Prompt:**

```text
/goal Implement Story CV-5.3 - Multi-Photo Candidate Merge.

Use epic branch epic/cv-5-metric-placement-multi-photo-merge.
Commit message: feat(cv-5.3): merge candidates across guided photos

Story outcome:
- Merge candidates from multiple photo roles into a single scene candidate list.
- Reduce duplicates using category, wall role, suggested metric footprint overlap, and confidence.
```

**Acceptance Criteria:**

- Given the same furniture appears in two adjacent wall photos, when merge runs, then one merged candidate is produced with source evidence references.
- Given two same-category objects are far apart, when merge runs, then they remain separate candidates.
- Given conflicting categories overlap, when merge runs, then the higher-confidence category is selected and the conflict is marked for review.
- Given merge results are displayed, when users inspect a candidate, then source image roles remain traceable.

**Validation:**

- Unit tests for duplicate merge and conflict behavior.
- Fixture-based test with multiple mocked photo results.

**Likely Files:**

- `editor/src/sceneUnderstandingWorker.ts`
- `editor/src/sceneCandidateMerge.ts`
- `editor/scripts/*`

### Story CV-5.4: Coverage and Extra Photo Guidance

As a RoomForge user, I want the app to tell me when photos are missing or weak, so that I can add useful extra photos instead of guessing.

**Goal Prompt:**

```text
/goal Implement Story CV-5.4 - Coverage and Extra Photo Guidance.

Use epic branch epic/cv-5-metric-placement-multi-photo-merge.
Commit message: feat(cv-5.4): add capture coverage guidance

Story outcome:
- Compute per-wall coverage and confidence summaries from capture roles and CV results.
- Surface extra-photo suggestions to the user.
```

**Acceptance Criteria:**

- Given a required wall role is missing, when coverage is computed, then the wall is marked `missing`.
- Given a wall photo has low object/boundary confidence, when coverage is computed, then the wall is marked `low_confidence` or `partial`.
- Given coverage is incomplete, when guidance is shown, then it suggests a specific extra photo role or angle.
- Given coverage is good enough, when guidance is shown, then users can continue to editing.

**Validation:**

- Unit tests for coverage states.
- Flutter/editor UI tests for guidance copy where applicable.

**Likely Files:**

- `app/lib/src/projects/*`
- `editor/src/sceneCoverage.ts`
- `editor/src/main.ts`

## Epic CV-6: Android ARCore Depth Enhancement

**Goal:** Add optional Android ARCore Depth metadata to improve placement when supported.

**Value:** Supported Android devices can improve metric placement without making AR mandatory.

### Story CV-6.1: Android ARCore Depth Capability Toggle

As an Android user, I want to turn accuracy enhancement on or off, so that I can choose whether distance metadata is captured.

**Goal Prompt:**

```text
/goal Implement Story CV-6.1 - Android ARCore Depth Capability Toggle.

Use epic branch epic/cv-6-android-arcore-depth.
Commit message: feat(cv-6.1): add arcore depth capability toggle

Story outcome:
- Add Android capability detection and a Flutter toggle for ARCore Depth enhancement.
- Fall back to guided photos when unsupported or disabled.
```

**Acceptance Criteria:**

- Given an Android device supports ARCore Depth, when capture starts, then the user can enable accuracy enhancement.
- Given the device does not support ARCore Depth, when capture starts, then normal guided photo capture remains available.
- Given the user disables enhancement, when photos are captured, then no depth metadata is required.
- Given the toggle is shown, when copy is read, then it describes distance metadata without promising perfect accuracy.

**Validation:**

- Flutter platform-state tests with mocked support states.
- Android build check where local tooling allows.

**Likely Files:**

- `app/android/*`
- `app/lib/src/projects/*`
- `app/test/src/projects/*`

### Story CV-6.2: Depth Metadata Capture and Storage

As a developer agent, I want optional depth metadata stored with capture images, so that placement algorithms can use it later.

**Goal Prompt:**

```text
/goal Implement Story CV-6.2 - Depth Metadata Capture and Storage.

Use epic branch epic/cv-6-android-arcore-depth.
Commit message: feat(cv-6.2): store arcore depth metadata

Story outcome:
- Capture and persist optional ARCore depth/camera pose artifact references.
- Keep the main photo capture flow working without depth metadata.
```

**Acceptance Criteria:**

- Given depth enhancement is enabled, when an image role is captured, then optional camera pose and depth artifact metadata can be stored.
- Given depth capture fails, when image upload succeeds, then the capture session remains valid with a warning.
- Given depth artifacts are stored, when another user requests them, then access is denied by owner-scoped rules.
- Given the editor receives capture metadata, when depth references are absent, then browser CV still runs normally.

**Validation:**

- Repository tests for optional depth metadata.
- Storage rules/path tests where feasible.
- Android capture path documented if hardware cannot be tested locally.

**Likely Files:**

- `app/android/*`
- `app/lib/src/firebase/firebase_models.dart`
- `app/lib/src/projects/firebase_project_api.dart`
- `app/storage.rules`

### Story CV-6.3: Depth Assisted Placement

As a RoomForge user with a supported Android device, I want depth metadata to improve object placement, so that detected furniture starts closer to the real room layout.

**Goal Prompt:**

```text
/goal Implement Story CV-6.3 - Depth Assisted Placement.

Use epic branch epic/cv-6-android-arcore-depth.
Commit message: feat(cv-6.3): improve placement with depth metadata

Story outcome:
- Use optional depth/camera pose metadata to refine candidate placement and size estimates.
- Preserve the non-depth placement path.
```

**Acceptance Criteria:**

- Given depth metadata is available for a candidate image, when placement is estimated, then depth-derived evidence can adjust suggested position or size.
- Given depth metadata is noisy or missing, when placement is estimated, then wall-role placement fallback is used.
- Given depth-assisted and non-depth estimates differ, when displayed, then confidence/review state reflects the evidence quality.
- Given a user edits the result, when saved, then user-confirmed values override depth suggestions.

**Validation:**

- Unit tests with mocked depth metadata.
- Comparison fixture showing depth-assisted vs fallback estimate behavior.

**Likely Files:**

- `editor/src/scenePlacement.ts`
- `editor/src/sceneUnderstandingWorker.ts`
- `editor/scripts/*`

## Epic CV-7: Evaluation and Provider Decision Gate

**Goal:** Make the CV project measurable and decide based on evidence whether browser CV is enough.

**Value:** The term project can explain accuracy, limitations, and why user editing is the correct fallback.

### Story CV-7.1: CV Evaluation Fixture Manifest

As a developer agent, I want a small evaluation fixture manifest, so that CV behavior can be tested and reported consistently.

**Goal Prompt:**

```text
/goal Implement Story CV-7.1 - CV Evaluation Fixture Manifest.

Use epic branch epic/cv-7-evaluation-provider-gate.
Commit message: test(cv-7.1): add cv evaluation fixtures manifest

Story outcome:
- Add a manifest format for local CV evaluation fixtures without committing private room photos by default.
- Document how to add local image sets and ground truth.
```

**Acceptance Criteria:**

- Given a developer has local room photo sets, when they create a manifest, then image roles, expected objects, approximate positions, and dimensions can be represented.
- Given private images are used, when repository status is checked, then actual private photos are not required to be committed.
- Given fixture docs are read, when a new room set is added, then expected labels and metrics are clear.

**Validation:**

- Schema or script validation for fixture manifest.
- Documentation review for privacy-safe local usage.

**Likely Files:**

- `editor/scripts/*`
- `docs/refactor/*` or `_bmad-output/implementation-artifacts/*`
- `.gitignore` if needed for local fixture photos

### Story CV-7.2: CV Metrics Harness and Report

As a CV project evaluator, I want metrics for detection, category, placement, and correction cost, so that the project can prove what the CV pipeline accomplishes.

**Goal Prompt:**

```text
/goal Implement Story CV-7.2 - CV Metrics Harness and Report.

Use epic branch epic/cv-7-evaluation-provider-gate.
Commit message: test(cv-7.2): add cv metrics harness

Story outcome:
- Add a reproducible metrics script/report for browser CV outputs against fixture manifests.
- Report detection recall, category accuracy, false positives, placement error, size error, processing time, and user correction count where data exists.
```

**Acceptance Criteria:**

- Given fixture ground truth exists, when metrics run, then object detection and category metrics are computed.
- Given metric placement ground truth exists, when metrics run, then position and size error are reported in meters.
- Given no ground truth exists for a metric, when the report runs, then it marks the metric unavailable instead of failing unclearly.
- Given metrics are generated, when the report is reviewed, then it explains why user-edit fallback remains necessary.

**Validation:**

- Metrics script test with mock fixtures.
- Generated report committed or documented as a local output path.

**Likely Files:**

- `editor/scripts/*`
- `package.json` or `editor/package.json`
- `_bmad-output/implementation-artifacts/*`

### Story CV-7.3: SAM 3 and Cloud GPU Decision Gate

As a project owner, I want a documented provider decision gate, so that SAM 3 or Cloud GPU is added only if browser CV evidence shows it is necessary.

**Goal Prompt:**

```text
/goal Implement Story CV-7.3 - SAM 3 and Cloud GPU Decision Gate.

Use epic branch epic/cv-7-evaluation-provider-gate.
Commit message: docs(cv-7.3): document cv provider decision gate

Story outcome:
- Document measurable criteria for staying browser-first versus adding SAM 3/Cloud Run GPU.
- Keep this story documentation/provider-interface only; do not deploy Cloud GPU.
```

**Acceptance Criteria:**

- Given CV metrics are available, when decision criteria are applied, then the project can decide whether browser CV is sufficient.
- Given browser CV misses or misclassifies key fixtures/furniture, when thresholds are exceeded, then SAM 3/Cloud GPU is recommended as an optional provider.
- Given Cloud GPU is not yet selected, when implementation is reviewed, then no cloud inference deployment or SAM 3 runtime is required.
- Given the provider gate is documented, when future work starts, then Firestore/bridge contracts remain reusable.

**Validation:**

- Documentation review against metrics report.
- Static review that no Cloud GPU or SAM 3 runtime dependency was added.

**Likely Files:**

- `_bmad-output/planning-artifacts/cv-provider-decision-gate.md`
- `docs/refactor/*`
