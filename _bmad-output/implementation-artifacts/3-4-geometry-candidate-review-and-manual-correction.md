# Story 3.4: Geometry Candidate Review and Manual Correction

## Status

review

## Story

As a user,
I want to accept, choose, or correct detected room boundary points,
So that the final room outline reflects the real room rather than raw CV guesses.

## Acceptance Criteria

- Given OpenCV candidates exist, when I review geometry, then I can accept a candidate, choose another candidate, drag corners, add corners, delete corners, reset to the candidate, or switch to manual outline.
- Given there are no candidates or low-confidence candidates, when I enter review mode, then the UI offers manual outline or rectangular room start without discarding useful context.
- Given I create invalid geometry, when the app validates the outline, then saving is blocked for fewer than three corners, open boundaries, or self-intersecting polygons.

## Tasks / Subtasks

- [x] Add confirmed geometry persistence separately from OpenCV candidates.
- [x] Add server validation for fewer than three corners and self-intersecting polygons.
- [x] Add editor controls for accepting/resetting candidates, manual rectangle, adding corners, and deleting corners.
- [x] Add draggable confirmed geometry handles in the editor viewport.
- [x] Add typed editor event for confirmed geometry changes.
- [x] Add tests for auth, ownership, valid geometry, too-few points, self-intersection, and retrieval.
- [x] Update server documentation and BMAD sprint status.

## Dev Notes

- Confirmed geometry remains in `image_pixels` before metric calibration.
- Metric calibration and meter-space floor plan generation are Story 3.5.

## Dev Agent Record

### Debug Log

- Added `confirmed_geometries` DDL, repository, schema, routes, and tests.
- Added polygon self-intersection validation to the schema layer.
- Added editor geometry correction controls and pointer-based corner dragging.

### Completion Notes

- Confirmed geometry is stored separately from `opencv_results`.
- Confirmed geometry requires at least three points and rejects self-intersection.
- Editor emits `roomforge.geometry.confirmedChanged` with explicit `image_pixels` coordinate space.

### File List

- `editor/src/main.ts`
- `editor/src/style.css`
- `server/README.md`
- `server/app/main.py`
- `server/app/repositories/confirmed_geometries.py`
- `server/app/routers/confirmed_geometries.py`
- `server/app/schemas/confirmed_geometries.py`
- `server/migrations/006_confirmed_geometries.sql`
- `server/tests/test_confirmed_geometries.py`
- `_bmad-output/implementation-artifacts/3-4-geometry-candidate-review-and-manual-correction.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`

## Change Log

- 2026-05-19: Implemented geometry review/manual correction boundary and moved story to review.
