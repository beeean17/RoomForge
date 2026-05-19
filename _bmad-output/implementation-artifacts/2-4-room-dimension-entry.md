# Story 2.4: Room Dimension Entry

## Status

review

## Story

As a signed-in user,
I want to enter room width, depth, and height,
So that later reconstruction can be calibrated into metric space.

## Acceptance Criteria

- Given I am setting up a room project, when I enter valid width and depth, then the dimensions are saved with explicit units.
- Given I do not enter room height, when I continue, then the system applies the MVP default height and clearly marks that height as default-derived.
- Given I enter invalid dimensions, when I try to continue, then the app blocks continuation and shows a validation message.

## Tasks / Subtasks

- [x] Add room dimension repository contract and Oracle implementation.
- [x] Add room dimension upsert and retrieval endpoints.
- [x] Apply default height when the client omits height.
- [x] Add server tests for valid values, invalid values, default height, and ownership.
- [x] Add Flutter room dimension form and API client support.

## Dev Notes

- MVP units are restricted to meters.
- Default height is configurable with `ROOMFORGE_ROOM_DEFAULT_HEIGHT_METERS`.
- Dimensions are scoped by authenticated user and project ownership.

## Dev Agent Record

### Debug Log

- Added `RoomDimensionsRepository` and `OracleRoomDimensionsRepository`.
- Added `PUT /room-projects/{project_id}/dimensions`.
- Added `GET /room-projects/{project_id}/dimensions`.
- Added project detail form validation for positive numeric width, depth, and optional height.

### Completion Notes

- Valid dimensions are saved with explicit `meters` units.
- Missing height uses the configured MVP default and returns `height_source: "default"`.
- Invalid client dimensions are blocked before save and invalid API payloads return `validation_error`.

### File List

- `server/app/repositories/dimensions.py`
- `server/app/routers/dimensions.py`
- `server/app/schemas/dimensions.py`
- `server/tests/test_dimensions.py`
- `server/migrations/003_source_images_and_room_dimensions.sql`
- `app/lib/src/projects/project_api.dart`
- `app/lib/main.dart`
- `server/README.md`
- `server/.env.example`

## Change Log

- 2026-05-19: Implemented room dimension entry and moved story to review.
