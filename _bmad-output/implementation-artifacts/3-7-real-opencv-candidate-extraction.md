# Story 3.7: Real OpenCV Candidate Extraction Correction

Status: done

## Story

As a RoomForge user,
I want the reconstruction review editor to derive room-boundary candidates from my uploaded room photo using OpenCV.js,
so that the CV review flow is real, inspectable, and useful before I correct geometry and generate a metric floor plan.

## Acceptance Criteria

1. Given the editor receives source image data, when reconstruction candidate extraction runs, then the worker processes actual image pixels with OpenCV.js instead of returning the previous hard-coded candidate geometry.
2. Given extraction succeeds, when the editor emits `roomforge.opencv.candidatesExtracted`, then the payload includes `coordinateSpace: "image_pixels"`, source image dimensions, algorithm ID, OpenCV version/build metadata where available, candidate edges, candidate lines, candidate corners, boundary hints, and confidence.
3. Given extraction cannot produce enough evidence, when the worker completes, then it emits a review-required or failed payload with a machine-readable reason such as `no_source_image`, `weak_edges`, `insufficient_lines`, `insufficient_corners`, or `low_confidence`.
4. Given OpenCV candidates exist, when the user accepts/resets candidates or drags confirmed corners, then candidate geometry and confirmed geometry remain separate bridge concepts and separate visual states.
5. Given Flutter receives candidate, confirmed, or calibration events, when matching project/job/source context exists, then it attempts to persist OpenCV results, confirmed geometry, and floor-plan output through the existing API/repository boundary without moving CV work into the server.
6. Given metric floor-plan generation runs, when calibration output is emitted, then image-pixel input geometry, meter-space output geometry, reference line, reference length, and rectangular MVP perspective assumptions are included.
7. Given validation runs, then the editor typecheck/build and relevant Flutter tests pass, and the old hard-coded candidate path is not the normal extraction path.

## Tasks / Subtasks

- [x] Replace the OpenCV worker stub (AC: 1, 2, 3)
  - [x] Add real OpenCV.js dependency to `editor`.
  - [x] Decode source image data in the worker.
  - [x] Run grayscale, blur, Canny, Hough line extraction, corner/boundary selection, and confidence scoring.
  - [x] Return explicit failure/review reasons instead of silently fabricating output.
- [x] Feed uploaded image data into the editor bridge (AC: 1, 5)
  - [x] Preserve the just-uploaded source image as a browser data URL for current-session reconstruction review.
  - [x] Include source image metadata and data URL in `roomforge.scene.initialize`.
  - [x] Keep behavior graceful when an old/reopened project has metadata but no local image bytes.
- [x] Replace hard-coded candidate rendering with worker output (AC: 2, 4)
  - [x] Update dashed candidate overlay from extracted boundary points.
  - [x] Preserve confirmed geometry handles and existing manual correction controls.
  - [x] Keep demo/fixture fallback explicit, not the normal path.
- [x] Persist reconstruction artifacts at the Flutter boundary (AC: 5, 6)
  - [x] Add Project API methods for OpenCV result, confirmed geometry, and floor-plan persistence.
  - [x] Implement Legacy API calls using existing `/opencv-results`, `/confirmed-geometries`, and `/floor-plans` endpoints.
  - [x] Implement Firebase persistence using existing repositories and models.
  - [x] Avoid introducing Firebase SDK use in the editor.
- [x] Validate (AC: 7)
  - [x] Run `npm run build` or `npm run test` in `editor`.
  - [x] Run relevant Flutter tests for project API/editor bridge changes.
  - [x] Run a focused code review with a subagent before finalizing.

## Dev Notes

- Current worker stub: `editor/src/opencvWorker.ts`.
- Current hard-coded candidate path: `editor/src/main.ts` `candidatePoints`, `worker.onmessage`, and `candidateGeometry()`.
- Current Flutter bridge entry: `app/lib/main.dart` `EditorBridgeScreen`, `_sceneInitializePayload`, and `_handleEditorMessage`.
- Current source upload flow: `app/lib/main.dart` `_uploadFile`.
- Current API boundary: `app/lib/src/projects/project_api.dart` and `app/lib/src/projects/firebase_project_api.dart`.
- Legacy server already exposes candidate/confirmed/floor-plan endpoints; do not run OpenCV on the server.
- Firebase already has `FirebaseOpenCvResult`, `FirebaseConfirmedGeometry`, and `FirebaseFloorPlan` models/repositories.
- Editor bridge fields use camelCase. API JSON and Firestore payloads use snake_case. Keep coordinate spaces explicit.
- OpenCV candidate geometry is image-pixel space. Confirmed geometry before calibration is image-pixel space. Floor-plan geometry after calibration is meter space.
- Source image bytes may only be available in the current browser session. If no image data is available, return `no_source_image` and keep manual correction available.

### References

- [PRD: MVP CV feature](../../docs/product/prd.md#L211)
- [PRD: FR18-FR20](../../docs/product/prd.md#L424)
- [Architecture: browser/editor OpenCV worker](../../docs/refactor/firebase-target-architecture.md#L76)
- [Architecture: reconstruction process](../../docs/refactor/firebase-target-architecture.md#L677)
- [Correct Course proposal](../planning-artifacts/sprint-change-proposal-2026-05-28.md)

## Dev Agent Record

### Agent Model Used

GPT-5 Codex

### Debug Log References

- `npm run typecheck` in `editor`
- `npm run build` in `editor`
- `flutter analyze` in `app`
- `flutter test test/src/projects/firebase_project_api_test.dart` in `app`
- `.venv/bin/python -m pytest tests/test_opencv_results.py` in `server`

### Completion Notes List

- Replaced the worker manifest-fetch stub with an OpenCV.js browser worker using `@techstark/opencv-js`.
- The worker decodes the current-session source image data URL, downsizes to a max processing dimension of 960 px, runs grayscale/blur/Canny/Hough, samples edge evidence, returns candidate lines/corners/boundary hints, confidence, algorithm ID, OpenCV version, and explicit failure/review reasons.
- The editor now updates the dashed candidate overlay from worker output and keeps confirmed geometry separate through `roomforge.geometry.confirmedChanged`.
- Flutter passes uploaded source image data/metadata into `roomforge.scene.initialize`, persists OpenCV/confirmed/floor-plan artifacts through the Project API boundary, and keeps Firebase out of the editor.
- Legacy server defaults were renamed from the old stub algorithm to `opencv-js-canny-hough-v1`.
- Subagent review findings were addressed: floor-plan payload now captures pre-calibration image geometry, artifact persistence is serialized, `no_source_image` keeps the job in review instead of terminal failure, nested API JSON is snake_case-normalized, worker loading is delayed until source image bytes exist, and image bitmap cleanup is guarded with `finally`.
- Validation passed; Vite still reports non-fatal bundle-size and Node built-in externalization warnings from the OpenCV.js package.

### File List

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
