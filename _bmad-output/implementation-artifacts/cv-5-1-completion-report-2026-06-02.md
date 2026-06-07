# Story CV-5.1 Completion Report

## 1. Goal Summary

- Target story: CV-5.1 - Category Size Priors
- Implemented outcome: Added shared furniture and structural fixture size priors, representative asset IDs, and fallback mapping so browser CV candidates can become plausible editable 2D/3D proxy objects.
- Out of scope: Wall-role metric projection, multi-photo merge, real model asset loading, and confirmed layout persistence changes.
- Current baseline assumptions: CV-4.1 through CV-4.3 are complete and merged into local `develop`; CV-5 work is running on `epic/cv-5-metric-placement-multi-photo-merge`.

## 2. Acceptance Criteria Verification

- AC 1: Given a candidate category is `bed`, `desk`, `chair`, `wardrobe`, `sofa`, or `table`, when placement is estimated, then a plausible default metric size is available.
  - Status: pass
  - Evidence: `editor/src/sizePriors.ts` defines shared priors for those categories; `candidateTray` uses the same priors when candidates lack direct `suggestedSize`; `sceneUnderstandingWorker` emits the prior size and representative asset on detector output.
- AC 2: Given a candidate category changes, when size is recalculated, then the prior changes without losing user edits after confirmation.
  - Status: pass
  - Evidence: `updateCandidateCategoryInModel` recalculates only candidate `suggestedSize` and `suggestedAssetId`; CV-5.1 editor test verifies existing `furniture`, `placedObjects`, and `confirmedObjects` sizes remain unchanged.
- AC 3: Given a category is unknown, when placement is estimated, then a custom fallback size and asset are used.
  - Status: pass
  - Evidence: `furnitureSizePriorForCategory` normalizes unknown furniture categories to `custom` with `custom.proxy`; CV-5.1 test verifies unknown detector classes emit custom candidate size and asset.

## 3. Validation Loop

- Commands run:
  - `dart format app/test/src/editor/firebase_editor_bridge_mapper_test.dart`
  - `npm run typecheck`
  - `npm run test:cv-5.1`
  - `npm run test:cv-3.2`
  - `npm run test:cv-3.3`
  - `npm run test:cv-4.1`
  - `npm run test:cv-4.2`
  - `npm run build`
  - `bash private/scripts/check-editor-firebase-boundary.sh`
  - `flutter analyze`
  - `flutter test test/src/editor/firebase_editor_bridge_mapper_test.dart`
  - `git diff --check`
- Commands passed: all final listed commands.
- Commands failed: initial typecheck and CV-5.1/CV-3.2 tests failed because a `prior` declaration was inserted outside `updateCandidateCategoryInModel`; fixed by moving it to the correct function scope.
- Fix/retry cycles: 1.
- Substitute checks: none.
- Environment limitations: none. Vite still reports the known non-fatal OpenCV chunk-size warning.
- Final validation result: pass.

## 4. Invariants Verified

- Browser/editor layer owns MVP CV candidate extraction and prior-based candidate metadata: pass.
- Candidate geometry remains separate from user-confirmed geometry: pass via editor and bridge tests.
- Bridge payloads remain camelCase and Firestore-facing models preserve confirmed sizes: pass via `firebase_editor_bridge_mapper_test.dart`.
- Editor remains free of Firebase SDK imports: pass via submodule boundary check.
- No heavy OpenCV, deep-learning, or GPU inference was added to the API server: pass.

## 5. Changed Files

- `app/test/src/editor/firebase_editor_bridge_mapper_test.dart`
- `editor/package.json`
- `editor/scripts/verify-cv-3.2-candidate-tray.mjs`
- `editor/scripts/verify-cv-5.1-size-priors.mjs`
- `editor/src/candidateTray.ts`
- `editor/src/furnitureModel.ts`
- `editor/src/main.ts`
- `editor/src/sceneUnderstandingWorker.ts`
- `editor/src/sizePriors.ts`

## 6. Story Loop Handoff

- Current story: CV-5.1
- Current story branch: `epic/cv-5-metric-placement-multi-photo-merge`
- Current story status: complete
- Suggested story commit: `feat(cv-5.1): add furniture size priors`
- Epic status: CV-5 in progress
- Next story: CV-5.2 - Wall Role Metric Placement
- Next story branch: `epic/cv-5-metric-placement-multi-photo-merge`
