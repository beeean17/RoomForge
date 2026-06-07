# Story CV-5.2 Completion Report

## 1. Goal Summary

- Target story: CV-5.2 - Wall Role Metric Placement
- Implemented outcome: Added wall-role projection from image bbox bottom-center into room-meter candidate suggestions, including wall association, rotation, bounds clamping, and review-required handling for weak evidence.
- Out of scope: Multi-photo duplicate merge, fixture metric placement refinement, camera calibration beyond guided wall-role heuristics, and confirmed object mutation.
- Current baseline assumptions: CV-5.1 size priors are complete on `epic/cv-5-metric-placement-multi-photo-merge`.

## 2. Acceptance Criteria Verification

- AC 1: Given a `front_wall` image candidate, when metric placement is estimated, then the object is placed relative to the front wall in room coordinates.
  - Status: pass
  - Evidence: `scenePlacement.ts` maps bbox bottom-center to `suggestedPosition` near `front-wall`; CV-5.2 test verifies a centered front-wall table lands at `{x: 2, z: 0.48}` in a 4 m x 3 m room.
- AC 2: Given a `right_wall`, `back_wall`, or `left_wall` image candidate, when placement is estimated, then wall association and rotation are adjusted accordingly.
  - Status: pass
  - Evidence: role mapping emits `suggestedWallId` and rotations of 90, 180, and 270 degrees for right/back/left roles; CV-5.2 test verifies all three roles.
- AC 3: Given bbox or role confidence is weak, when suggested placement is generated, then the object is marked `review_required`.
  - Status: pass
  - Evidence: missing/invalid bbox, missing dimensions, non-wall roles, and low confidence add review reasons; CV-5.2 test verifies weak role and missing bbox force `review_required`.
- AC 4: Given room dimensions change before confirmation, when placement recalculates, then candidate suggestions update in meters.
  - Status: pass
  - Evidence: `main.ts` recalculates candidate placements on scene initialize, scene understanding result application, category change, generated floor plan updates, and confirmed geometry updates; CV-5.2 test verifies x-position changes from 2 m to 3 m when room width changes from 4 m to 6 m.

## 3. Validation Loop

- Commands run:
  - `npm run typecheck`
  - `npm run test:cv-5.2`
  - `npm run test:cv-5.1`
  - `npm run test:cv-4.2`
  - `npm run test:cv-3.3`
  - `npm run test:cv-4.1`
  - `npm run build`
  - `bash private/scripts/check-editor-firebase-boundary.sh`
  - `git diff --check`
- Commands passed: all final listed commands.
- Commands failed: initial `npm run test:cv-5.2` expected an unclamped right-wall x-position; fixed the test to match the room-bounds clamp contract.
- Fix/retry cycles: 1.
- Substitute checks: none.
- Environment limitations: none. Vite still reports the known non-fatal OpenCV chunk-size warning.
- Final validation result: pass.

## 4. Invariants Verified

- Suggested candidate placement remains candidate state, not confirmed layout truth: pass.
- User-confirmed and placed objects are not recalculated by wall-role projection: pass by implementation scope and CV-5.1 regression coverage.
- Geometry payloads remain meter-space for suggested placement: pass via `suggestedPosition` in `{x,y,z}` meters.
- Editor remains free of Firebase SDK imports: pass via submodule boundary check.
- Browser/editor owns MVP CV placement logic; no API-server CV/GPU inference was added: pass.

## 5. Changed Files

- `editor/package.json`
- `editor/scripts/verify-cv-5.2-wall-role-placement.mjs`
- `editor/src/main.ts`
- `editor/src/scenePlacement.ts`
- `editor/src/sceneUnderstandingWorker.ts`
- `editor/src/spatialModel.ts`

## 6. Story Loop Handoff

- Current story: CV-5.2
- Current story branch: `epic/cv-5-metric-placement-multi-photo-merge`
- Current story status: complete
- Suggested story commit: `feat(cv-5.2): estimate metric placement from wall roles`
- Epic status: CV-5 in progress
- Next story: CV-5.3 - Multi-Photo Candidate Merge
- Next story branch: `epic/cv-5-metric-placement-multi-photo-merge`
