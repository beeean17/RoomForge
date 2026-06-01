# Story CV-6.3 Completion Report

## 1. Goal Summary

- Target story: CV-6.3 - Depth Assisted Placement
- Implemented outcome: Editor capture-session parsing now preserves optional depth artifact refs and camera pose hints, and metric candidate placement can use valid depth metadata to adjust suggested position and size while preserving wall-role fallback behavior.
- Out of scope: Loading depth artifact files or running native ARCore depth reconstruction in browser.
- Current baseline assumptions: CV-6.1 and CV-6.2 are complete on `epic/cv-6-android-arcore-depth`.

## 2. Acceptance Criteria Verification

- AC 1: Given depth metadata is available for a candidate image, when placement is estimated, then depth-derived evidence can adjust suggested position or size.
  - Status: pass
  - Evidence: `estimateMetricPlacementForCandidate` uses valid `cameraPose.depthEstimateMeters` plus `depthArtifactRefs` to set wall-normal placement and optional `sizeScale`.
- AC 2: Given depth metadata is noisy or missing, when placement is estimated, then wall-role placement fallback is used.
  - Status: pass
  - Evidence: missing depth returns `wall_role`; out-of-room or too-low-confidence depth returns fallback placement with `noisy_depth_metadata`.
- AC 3: Given depth-assisted and non-depth estimates differ, when displayed, then confidence/review state reflects the evidence quality.
  - Status: pass
  - Evidence: high-confidence depth keeps normal candidate state; lower-confidence usable depth marks `review_required` with `depth_assisted_low_confidence`; notes state depth metadata use and confidence.
- AC 4: Given a user edits the result, when saved, then user-confirmed values override depth suggestions.
  - Status: pass
  - Evidence: candidates already marked `placed` or `rejected` are not recomputed by depth-assisted placement, so user-selected values are preserved.

## 3. Validation Loop

- Commands run:
  - `npm run test:cv-6.3`
  - `npm run typecheck`
  - `npm run test:cv-5.2`
  - `npm run test:cv-5.3`
  - `npm run build`
  - `bash private/scripts/check-editor-firebase-boundary.sh`
  - `git diff --check`
- Commands passed: all final listed commands.
- Commands failed: none.
- Fix/retry cycles: 0.
- Substitute checks: Depth artifact byte loading was not implemented; mocked metadata fixture verifies depth-assisted vs fallback behavior.
- Environment limitations: `npm run build` still reports existing Vite/OpenCV externalization and chunk-size warnings, but exits successfully.
- Final validation result: pass.

## 4. Invariants Verified

- Browser CV remains usable without depth metadata: pass.
- Depth metadata stays in the editor layer and does not introduce Firebase imports into editor code: pass.
- User-confirmed or placed values are not overwritten by automated depth suggestions: pass.
- Wall-role fallback remains compatible with CV-5.2 placement and CV-5.3 merge behavior: pass.
- Candidate review state uses `review_required` and `Needs review` without new persisted job statuses: pass.

## 5. Changed Files

- `editor/package.json`
- `editor/scripts/verify-cv-6.3-depth-placement.mjs`
- `editor/src/captureSession.ts`
- `editor/src/scenePlacement.ts`

## 6. Story Loop Handoff

- Current story: CV-6.3
- Current story branch: `epic/cv-6-android-arcore-depth`
- Current story status: complete
- Suggested story commit: `feat(cv-6.3): improve placement with depth metadata`
- Epic status: CV-6 complete after epic-level validation
- Next story: CV-7.1 - CV Evaluation Fixture Manifest
- Next story branch: `epic/cv-7-evaluation-provider-gate`
