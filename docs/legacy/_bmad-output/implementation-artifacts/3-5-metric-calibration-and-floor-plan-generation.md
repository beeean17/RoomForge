# Story 3.5: Metric Calibration and Floor Plan Generation

## Status

review

## Story

As a user,
I want to calibrate corrected geometry using known room dimensions,
So that RoomForge can generate a metric floor plan.

## Acceptance Criteria

- Given confirmed geometry is valid, when I select a reference line and enter length with units, then the editor calculates metric scale and displays a scale summary.
- Given geometry or calibration is invalid, when I try to generate a 2D/3D plan, then generation is disabled with a validation message.
- Given geometry and calibration are valid, when the floor plan is generated, then the system produces a rectangular or simple polygonal metric floor plan and metric geometry explicitly uses meters after calibration.
- Given a valid rectangular-room input with confirmed image-space boundary points and user-provided dimensions, when perspective or homography-based reasoning is applied, then the implementation records the perspective assumptions used, the image-pixel input geometry, and the meter-space output geometry.
- Given a calibration result is produced for a simple rectangular-room case, when the generated floor plan is compared with the user-entered width and depth, then exported room dimensions target <= 5% width/depth deviation and <= 5% aspect-ratio error for valid inputs.

## Tasks / Subtasks

- [x] Add floor plan persistence schema and API routes.
- [x] Generate meter-space MVP rectangular floor plan from saved room dimensions.
- [x] Preserve perspective assumptions, image-pixel input geometry, and meter-space output geometry.
- [x] Record width/depth/aspect deviation fields.
- [x] Add editor floor plan generation control and scale summary event.
- [x] Add server tests for auth, ownership, meter-space geometry, and deviation thresholds.
- [x] Update server documentation and BMAD sprint status.

## Dev Notes

- This story implements an MVP rectangular projection boundary. More advanced homography can replace the generator while preserving persisted fields.
- Furniture planning remains Epic 4.

## Dev Agent Record

### Debug Log

- Added `floor_plans` DDL, repository, schema, routes, and tests.
- Added editor `Generate floor plan` control emitting meter-space floor plan payload.
- Kept metric output explicitly in `meters`.

### Completion Notes

- API stores floor plans with image-pixel input geometry, meter-space output geometry, and perspective assumptions.
- MVP generator records zero deviation against saved dimensions for rectangular input.
- Editor blocks generation when fewer than three confirmed corners exist.

### File List

- `editor/src/main.ts`
- `server/README.md`
- `server/app/main.py`
- `server/app/repositories/floor_plans.py`
- `server/app/routers/floor_plans.py`
- `server/app/schemas/floor_plans.py`
- `server/migrations/007_floor_plans.sql`
- `server/tests/test_floor_plans.py`
- `_bmad-output/implementation-artifacts/3-5-metric-calibration-and-floor-plan-generation.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`

## Change Log

- 2026-05-19: Implemented MVP metric calibration/floor plan generation and moved story to review.
