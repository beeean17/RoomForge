# Story 3.3: OpenCV Candidate Extraction and Overlay Persistence

## Status

review

## Story

As a user,
I want RoomForge to detect candidate room edges, lines, corners, and boundary hints from my source image,
So that I have a computer vision starting point instead of drawing everything manually.

## Acceptance Criteria

- Given a source image is available in the editor, when OpenCV candidate extraction runs, then the editor produces candidate edges, lines, corners, or boundary hints.
- Given candidate geometry is produced, when the result is saved, then the API stores candidate geometry separately from confirmed geometry and the payload explicitly states coordinate space as image pixels before calibration.
- Given overlays are displayed, when candidates and confirmed geometry are both visible, then candidates use thinner dashed or lower-opacity treatment and confirmed geometry uses stronger solid treatment with handles.

## Tasks / Subtasks

- [x] Add editor-side candidate geometry generation event from the browser OpenCV runtime path.
- [x] Add candidate overlay treatment distinct from confirmed geometry.
- [x] Add OpenCV result persistence schema and API routes.
- [x] Store candidate geometry with explicit `image_pixels` coordinate space.
- [x] Add tests for auth, ownership, coordinate-space validation, and retrieval.
- [x] Update server documentation and BMAD sprint status.

## Dev Notes

- This story persists candidate geometry only. Confirmed/user-corrected geometry remains separate and is handled in Story 3.4.
- The editor still uses the MVP OpenCV runtime stub from Story 3.1; replacing it with full OpenCV.js should preserve the same candidate payload contract.

## Dev Agent Record

### Debug Log

- Added dashed low-opacity candidate overlay in the Three.js editor.
- Added `roomforge.opencv.candidatesExtracted` event with image-pixel candidate geometry.
- Added `opencv_results` DDL, repository, schemas, routes, and tests.

### Completion Notes

- Candidate geometry is represented separately from confirmed geometry.
- Server rejects non-`image_pixels` coordinate spaces for OpenCV candidates.
- Cross-user job/result access returns `not_found`.

### File List

- `editor/src/main.ts`
- `server/README.md`
- `server/app/main.py`
- `server/app/repositories/opencv_results.py`
- `server/app/routers/opencv_results.py`
- `server/app/schemas/opencv_results.py`
- `server/migrations/005_opencv_results.sql`
- `server/tests/test_opencv_results.py`
- `_bmad-output/implementation-artifacts/3-3-opencv-candidate-extraction-and-overlay-persistence.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`

## Change Log

- 2026-05-19: Implemented OpenCV candidate extraction event and persistence API, then moved story to review.
