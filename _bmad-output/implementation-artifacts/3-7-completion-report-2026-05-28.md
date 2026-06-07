# Completion Report: Story 3.7 Real OpenCV Candidate Extraction

## 1. Goal Summary

- Target story/stories: Story 3.7 - Real OpenCV Candidate Extraction Correction
- Implemented outcome: Browser/editor OpenCV candidate extraction now processes current-session source image pixels with OpenCV.js, updates the Three.js candidate overlay from extracted evidence, and persists OpenCV result, confirmed geometry, and generated floor-plan artifacts through the Flutter Project API boundary.
- Out of scope: Custom slim OpenCV.js/WASM build, production CV accuracy tuning, remote source-image byte rehydration for reopened projects.
- Current baseline assumptions: Stories 1.1 through 3.6 remain the baseline, with Story 3.7 added as a corrective story before Epic 4 layout work.

## 2. Acceptance Criteria Verification

- AC 1:
  - Status: pass
  - Evidence: `editor/src/opencvWorker.ts` loads `@techstark/opencv-js`, decodes source image data URLs, and runs grayscale/blur/Canny/Hough extraction.
- AC 2:
  - Status: pass
  - Evidence: `roomforge.opencv.candidatesExtracted` includes `coordinateSpace`, image dimensions, algorithm, OpenCV version, candidate edges, lines, corners, boundary hints, and confidence.
- AC 3:
  - Status: pass
  - Evidence: Worker/editor emits `no_source_image`, `weak_edges`, `insufficient_lines`, `insufficient_corners`, or `low_confidence` reason codes.
- AC 4:
  - Status: pass
  - Evidence: Candidate overlay state and confirmed geometry events remain separate in `editor/src/main.ts`.
- AC 5:
  - Status: pass
  - Evidence: Flutter persists OpenCV result, confirmed geometry, and floor-plan artifacts via `ProjectApi`; editor does not use Firebase.
- AC 6:
  - Status: pass
  - Evidence: Floor-plan event captures pre-calibration `image_pixels` geometry before replacing the scene with meter-space output.
- AC 7:
  - Status: pass
  - Evidence: Editor build/typecheck, Flutter analyze/test, server OpenCV result tests, and one subagent review completed.

## 3. Validation Loop

- Commands run:
  - `npm run typecheck` in `editor`
  - `npm run build` in `editor`
  - `flutter analyze` in `app`
  - `flutter test test/src/projects/firebase_project_api_test.dart` in `app`
  - `.venv/bin/python -m pytest tests/test_opencv_results.py` in `server`
- Commands passed: all listed commands passed.
- Commands failed: initial `flutter analyze` reported style hints, then passed after fixes.
- Fix/retry cycles: one validation/fix cycle after subagent review.
- Environment limitations: Vite reports non-fatal large chunk and Node built-in externalization warnings from `@techstark/opencv-js`.
- Manual checks: Searched for remaining old stub runtime strings; only the corrective proposal references the old state.
- Final validation result: pass with non-fatal bundle-size warning.

## 4. Recovery Actions Used

- Recovery needed: yes
- Issue: Existing dirty worktree includes unrelated files and prior user changes, including changes in files touched by this story.
- Recovery playbook section: dirty worktree / mixed story-product and operational state.
- Commands/actions taken: scoped edits to story files, avoided reverting unrelated changes, did not create a mixed local story commit.
- Result: Implementation validated without overwriting user work.
- Remaining limitation: No story commit was created because the working tree was already dirty with unrelated changes.

## 5. Invariants Verified

- app/editor/server boundary: Flutter owns persistence, editor owns OpenCV/Three.js, server stores API records only.
- no heavy CV/GPU on API server: OpenCV runs in the browser worker only.
- candidate vs confirmed geometry separation: candidate geometry remains OpenCV output; confirmed geometry is a separate user-reviewed payload.
- allowed status vocabulary: uses `review_required`, `failed`, and `succeeded`; no new persisted status values added.
- `review_required` -> `Needs review` mapping: preserved in UI labels and quality warnings.
- API envelope: existing server endpoints unchanged except default algorithm string.
- coordinate space: image pixels before calibration, meters after calibration.
- auth/ownership: Project API and Firebase repositories retain existing user/project ownership checks.
- admin authorization, if applicable: not touched.
- accessibility/responsive: no new canvas-only mandatory workflow; manual controls remain available.

## 6. Story-Specific Evidence

- OpenCV extraction: real image processing in `editor/src/opencvWorker.ts`.
- Bridge handoff: source image metadata/data URL sent through `_sceneInitializePayload`.
- Persistence: `persistOpenCvResult`, `persistConfirmedGeometry`, and `persistFloorPlanResult` added to Project API implementations.
- Subagent review: one subagent reviewed correctness, efficiency, and runtime risk; actionable findings were fixed.

## 7. Branch and Story Commit Readiness

- Primary branch: not changed.
- Current branch: existing local branch/worktree state.
- Target story branch from queue: corrective Story 3.7 before Story 4.1.
- Working tree status: dirty, with pre-existing unrelated changes.
- Suggested story commit message: `Story 3.7: replace OpenCV candidate stub`
- Acceptance criteria status: pass.
- Files staged: none.
- Commit created: no.
- Reason if story was not ready to commit: existing unrelated dirty changes overlap story files, so a clean one-story commit would risk mixing user work.

## 8. Changed Files

- `editor/package.json`
- `editor/package-lock.json`
- `editor/src/opencvWorker.ts`
- `editor/src/main.ts`
- `editor/public/opencv/opencv-runtime-manifest.json`
- `editor/public/opencv/opencv.js`
- `editor/public/opencv/opencv.wasm`
- `app/lib/main.dart`
- `app/lib/src/projects/project_api.dart`
- `app/lib/src/projects/firebase_project_api.dart`
- `server/app/schemas/opencv_results.py`
- `server/app/repositories/opencv_results.py`
- `server/migrations/005_opencv_results.sql`
- `_bmad-output/planning-artifacts/sprint-change-proposal-2026-05-28.md`
- `_bmad-output/implementation-artifacts/3-7-real-opencv-candidate-extraction.md`

## 9. Assumptions and Decisions

- Current-session source image bytes are available as a data URL immediately after upload.
- Reopened projects without local image bytes remain manual/review workflows and should not become terminal failed jobs solely for `no_source_image`.
- The MVP boundary candidate is rectangular from edge evidence; precision tuning remains future work.
- API-bound nested JSON is snake_case-normalized at the Flutter Project API boundary.

## 10. Risks / Follow-Ups

- `@techstark/opencv-js` produces an 11 MB worker chunk; it is now lazy-loaded only when source image bytes exist, but a custom slim OpenCV build should be considered later.
- CV geometry quality is heuristic and should be evaluated with a small image fixture set.
- Remote source-image byte rehydration is still needed for full reopened-project CV reruns.

## 11. Story Loop Handoff

- Current story: Story 3.7
- Current story status: complete, uncommitted
- Local story commit: not created
- Local primary branch updated: no
- Next story: Story 4.1 - Shared Spatial Model and 2D/3D View Shell
- Preconditions for next story: either clean/stage current Story 3.7 changes deliberately or continue with explicit dirty-worktree handling.
- Auto-advance status: paused for user review due dirty worktree and no commit.

## 12. Recommended Next Goal

Proceed to Story 4.1 after deciding whether to create a story commit from the scoped Story 3.7 changes or keep the current working tree uncommitted.
