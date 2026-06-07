# Story CV-4.2 Completion Report

## 1. Goal Summary

- Target story: CV-4.2 - Browser Object Detector Runtime
- Implemented outcome: Added a browser detector runtime boundary inside the scene understanding worker with WebGPU, WASM, mock, and unsupported runtime paths.
- Out of scope: Real model download/loading, SAM 3, Cloud GPU inference, and persisted scene understanding records.
- Current baseline assumptions: CV-4.1 worker scaffold and CV-3 candidate/fixture editing are merged into the local epic branch.

## 2. Acceptance Criteria Verification

- AC 1: Given WebGPU is available and model assets are present, object candidates are produced from at least one source image.
  - Status: pass
  - Evidence: `detectorRuntimeFromPayload` selects `browser_cv_webgpu_mock`; `npm run test:cv-4.2` verifies a WebGPU-configured run produces mapped bed/custom candidates and a window fixture.
- AC 2: Given WebGPU is unavailable, worker uses fallback or reports unsupported without breaking editor.
  - Status: pass
  - Evidence: `npm run test:cv-4.2` verifies the WASM fallback path when model assets exist and the structured `unsupported_runtime` failure path when forced.
- AC 3: Given detector output includes boxes/classes/scores, mapped candidates include categories, confidence, source image, bbox, and coordinate space.
  - Status: pass
  - Evidence: detector output parsing maps class, score, image reference, and bounding box into `candidateObjects` with `coordinateSpace = image_pixels`.
- AC 4: Unsupported detector classes become `custom` or are filtered according to thresholds.
  - Status: pass
  - Evidence: `floor_lamp` maps to `custom`; low-confidence `chair` output is filtered below the configured score threshold in `npm run test:cv-4.2`.

## 3. Validation Loop

- Commands run:
  - `npm run typecheck`
  - `npm run test:cv-4.2`
  - `npm run test:cv-4.1`
  - `npm run build`
  - `npm run test:cv-3.2`
  - `npm run test:cv-3.3`
  - `npm run test:cv-3.4`
  - `bash private/scripts/check-editor-firebase-boundary.sh`
  - `git diff --check`
- Commands passed: all final listed commands.
- Commands failed: none.
- Fix/retry cycles: 0.
- Substitute checks: model assets are not present, so runtime behavior is verified with mocked detector output and explicit WebGPU/WASM runtime flags.
- Environment limitations: Vite emitted the existing non-fatal OpenCV large chunk warning during `npm run build`.
- Final validation result: pass.

## 4. Invariants Verified

- Detector runtime remains in the browser/editor worker, not the API server: pass.
- SAM 3 and Cloud GPU are not required for this MVP path: pass.
- WebGPU unavailable behavior remains non-blocking: pass.
- Candidate geometry remains separate from confirmed geometry: pass.
- Editor Firebase boundary remains clean: pass via submodule boundary check.
- API/server boundaries are unchanged: pass.

## 5. Changed Files

- `editor/package.json`
- `editor/scripts/verify-cv-4.2-detector-runtime.mjs`
- `editor/src/main.ts`
- `editor/src/sceneUnderstandingWorker.ts`

## 6. Story Loop Handoff

- Current story: CV-4.2
- Current story branch: `epic/cv-4-browser-scene-understanding`
- Current story status: complete
- Suggested story commit: `feat(cv-4.2): add browser object detector runtime`
- Next story: CV-4.3 - Scene Understanding Persistence
- Next story branch: `epic/cv-4-browser-scene-understanding`
