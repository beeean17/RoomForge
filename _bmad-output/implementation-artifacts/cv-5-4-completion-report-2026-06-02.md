# Story CV-5.4 Completion Report

## 1. Goal Summary

- Target story: CV-5.4 - Coverage and Extra Photo Guidance
- Implemented outcome: Added per-wall capture coverage computation, coverage guidance copy, worker coverage payloads, and editor tray status guidance for missing, partial, low-confidence, and sufficient coverage states.
- Out of scope: Native mobile capture UX changes, server-side coverage policy, and thumbnail-level retake UI.
- Current baseline assumptions: CV-5.1 through CV-5.3 are complete on `epic/cv-5-metric-placement-multi-photo-merge`.

## 2. Acceptance Criteria Verification

- AC 1: Given a required wall role is missing, when coverage is computed, then the wall is marked `missing`.
  - Status: pass
  - Evidence: `computeSceneCoverage` marks absent required wall roles as `missing`; CV-5.4 test verifies `left_wall`, `back_wall`, and `left_wall` missing cases.
- AC 2: Given a wall photo has low object/boundary confidence, when coverage is computed, then the wall is marked `low_confidence` or `partial`.
  - Status: pass
  - Evidence: wall roles with low max candidate confidence become `low_confidence`; wall roles with images but no candidate evidence become `partial`.
- AC 3: Given coverage is incomplete, when guidance is shown, then it suggests a specific extra photo role or angle.
  - Status: pass
  - Evidence: coverage guidance names the wall role and suggests capture, retake, or angled-photo/manual review actions; editor tray status uses the same guidance.
- AC 4: Given coverage is good enough, when guidance is shown, then users can continue to editing.
  - Status: pass
  - Evidence: complete coverage returns `canContinue: true` and `Coverage looks sufficient. Continue editing the generated layout.`

## 3. Validation Loop

- Commands run:
  - `npm run typecheck`
  - `npm run test:cv-5.4`
  - `npm run test:cv-5.3`
  - `npm run test:cv-4.2`
  - `npm run test:cv-5.2`
  - `npm run build`
  - `bash private/scripts/check-editor-firebase-boundary.sh`
  - `git diff --check`
- Commands passed: all final listed commands.
- Commands failed: initial typecheck/CV-5.4/CV-5.3/CV-4.2 failed due to a `requiredRoles` variable typo in `sceneCoverage.ts`; fixed to return `requiredWallRoles`.
- Fix/retry cycles: 1.
- Substitute checks: none.
- Environment limitations: none. Vite still reports the known non-fatal OpenCV chunk-size warning.
- Final validation result: pass.

## 4. Invariants Verified

- Coverage guidance is computed in the editor/browser CV layer, not the lightweight API server: pass.
- Coverage output stays in scene understanding metadata and does not create confirmed geometry: pass.
- Candidate tray remains an editable review surface with guidance, not a blocking workflow: pass.
- Editor remains free of Firebase SDK imports: pass via submodule boundary check.
- Required wall roles stay explicit as `front_wall`, `right_wall`, `back_wall`, and `left_wall`: pass.

## 5. Changed Files

- `editor/package.json`
- `editor/scripts/verify-cv-5.4-coverage-guidance.mjs`
- `editor/src/main.ts`
- `editor/src/sceneCoverage.ts`
- `editor/src/sceneUnderstandingWorker.ts`

## 6. Story Loop Handoff

- Current story: CV-5.4
- Current story branch: `epic/cv-5-metric-placement-multi-photo-merge`
- Current story status: complete
- Suggested story commit: `feat(cv-5.4): add capture coverage guidance`
- Epic status: CV-5 complete after this story
- Next story: CV-6.1 - Android ARCore Depth Capability Toggle
- Next story branch: `epic/cv-6-android-arcore-depth`
