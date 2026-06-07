# Story CV-3.1 Completion Report

## 1. Goal Summary

- Target story: CV-3.1 - Spatial Model Candidate and Fixture Layers
- Implemented outcome: Extended the editor spatial model with separate `candidateObjects`, `placedObjects`, `confirmedObjects`, and `structuralFixtures` layers, while preserving existing editable `furniture` behavior.
- Out of scope: Candidate tray UI, candidate rejection/category editing controls, drag/drop placement, and real CV inference.
- Current baseline assumptions: CV-2.3 capture session continuation is merged into local `develop`.

## 2. Acceptance Criteria Verification

- AC 1: Given a bridge payload contains candidate objects, candidates are kept separate from furniture objects.
  - Status: pass
  - Evidence: `spatialModelFromBridgePayload` parses `candidateObjects` into a dedicated layer; `verify-cv-3.1-spatial-candidate-layers.mjs` asserts candidate furniture does not populate `model.furniture`.
- AC 2: Given a payload contains structural fixtures, fixtures are associated with walls or room shell without becoming movable furniture.
  - Status: pass
  - Evidence: `StructuralFixtureObject` stores `wallId` and `locked`; verification asserts a window fixture remains in `structuralFixtures` and is absent from `furniture`.
- AC 3: Given existing saved layouts load with no candidate layer, fallback defaults preserve current behavior.
  - Status: pass
  - Evidence: `defaultSpatialModel` initializes all new layers as empty arrays, and existing Story 4.1/5.2 spatial restoration scripts still pass.

## 3. Validation Loop

- Commands run:
  - `npm run typecheck`
  - `npm run test:cv-3.1`
  - `npm run test:story-4.3`
  - `npm run test:story-4.4`
  - `npm run test:story-4.1`
  - `npm run test:story-5.2`
  - `npm run build`
  - `bash private/scripts/check-editor-firebase-boundary.sh`
  - `git diff --check`
- Commands passed: all final listed commands.
- Commands failed: none.
- Fix/retry cycles: 0.
- Substitute checks: Editor verification scripts cover model parsing, fallback, and existing furniture behavior without browser automation.
- Environment limitations: Vite emitted the existing non-fatal large chunk warning for OpenCV assets.
- Final validation result: pass.

## 4. Invariants Verified

- Editor owns scene graph parsing and spatial validation: pass.
- Flutter/Firebase boundaries unchanged: pass.
- Editor remains free of Firebase SDK imports: pass via submodule boundary check.
- No heavy CV/GPU/deep-learning inference added: pass.
- Candidate vs confirmed geometry/object separation: pass; candidate, placed, confirmed, fixture, and furniture layers are structurally distinct.
- Existing furniture selection/editing behavior preserved: pass via Story 4.3 and 4.4 verification scripts.
- Coordinate space remains explicit for room metric geometry and candidate image-pixel metadata: pass.

## 5. Changed Files

- `editor/package.json`
- `editor/scripts/verify-cv-3.1-spatial-candidate-layers.mjs`
- `editor/src/main.ts`
- `editor/src/spatialModel.ts`

## 6. Story Loop Handoff

- Current story: CV-3.1
- Current story branch: `epic/cv-3-candidate-tray-editable-scene`
- Current story status: complete
- Suggested story commit: `feat(cv-3.1): add candidate and fixture scene layers`
- Next story: CV-3.2 - Candidate Tray Review UI
- Next story branch: `epic/cv-3-candidate-tray-editable-scene`
