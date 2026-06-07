# Story CV-5.3 Completion Report

## 1. Goal Summary

- Target story: CV-5.3 - Multi-Photo Candidate Merge
- Implemented outcome: Added multi-photo candidate merge logic that deduplicates overlapping same-category furniture candidates, preserves far-apart objects, resolves overlapping category conflicts by confidence, and keeps source evidence traceable in the candidate tray.
- Out of scope: Capture coverage guidance, extra-photo recommendations, server-side merge persistence changes, and visual comparison UI for evidence thumbnails.
- Current baseline assumptions: CV-5.1 and CV-5.2 are complete on `epic/cv-5-metric-placement-multi-photo-merge`.

## 2. Acceptance Criteria Verification

- AC 1: Given the same furniture appears in two adjacent wall photos, when merge runs, then one merged candidate is produced with source evidence references.
  - Status: pass
  - Evidence: `mergeSceneCandidates` merges overlapping same-category candidates from adjacent wall roles; CV-5.3 test verifies front/right bed detections produce one candidate with two `sourceEvidence` records.
- AC 2: Given two same-category objects are far apart, when merge runs, then they remain separate candidates.
  - Status: pass
  - Evidence: CV-5.3 test verifies far-apart chair candidates remain as two candidates.
- AC 3: Given conflicting categories overlap, when merge runs, then the higher-confidence category is selected and the conflict is marked for review.
  - Status: pass
  - Evidence: overlapping table/desk candidates merge into the higher-confidence desk candidate with `review_required`, `Needs review`, and conflict notes.
- AC 4: Given merge results are displayed, when users inspect a candidate, then source image roles remain traceable.
  - Status: pass
  - Evidence: `CandidateSceneObject.sourceEvidence` is parsed in `spatialModel.ts`, merge output preserves source roles, and `candidateTrayItems` displays multi-role source labels such as `front_wall, right_wall (2 sources)`.

## 3. Validation Loop

- Commands run:
  - `npm run typecheck`
  - `npm run test:cv-5.3`
  - `npm run test:cv-5.2`
  - `npm run test:cv-3.2`
  - `npm run test:cv-4.2`
  - `npm run build`
  - `bash private/scripts/check-editor-firebase-boundary.sh`
  - `git diff --check`
- Commands passed: all final listed commands.
- Commands failed: none.
- Fix/retry cycles: 0.
- Substitute checks: none.
- Environment limitations: none. Vite still reports the known non-fatal OpenCV chunk-size warning.
- Final validation result: pass.

## 4. Invariants Verified

- Candidate merge operates in editor/browser CV state, not in the API server: pass.
- Candidate geometry remains separate from placed and confirmed geometry: pass.
- Source evidence is stored on candidates and surfaced in editor tray labels without changing confirmed layout objects: pass.
- Editor remains free of Firebase SDK imports: pass via submodule boundary check.
- Multi-photo merge uses metric suggested placement and confidence, preserving room-meter coordinate semantics: pass.

## 5. Changed Files

- `editor/package.json`
- `editor/scripts/verify-cv-5.3-candidate-merge.mjs`
- `editor/src/candidateTray.ts`
- `editor/src/sceneCandidateMerge.ts`
- `editor/src/sceneUnderstandingWorker.ts`
- `editor/src/spatialModel.ts`

## 6. Story Loop Handoff

- Current story: CV-5.3
- Current story branch: `epic/cv-5-metric-placement-multi-photo-merge`
- Current story status: complete
- Suggested story commit: `feat(cv-5.3): merge candidates across guided photos`
- Epic status: CV-5 in progress
- Next story: CV-5.4 - Coverage and Extra Photo Guidance
- Next story branch: `epic/cv-5-metric-placement-multi-photo-merge`
