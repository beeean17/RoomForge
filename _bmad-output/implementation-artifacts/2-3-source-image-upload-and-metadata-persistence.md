# Story 2.3: Source Image Upload and Metadata Persistence

## Status

review

## Story

As a signed-in user,
I want to upload a source room image to my project,
So that RoomForge can preserve the original input for reconstruction and review.

## Acceptance Criteria

- Given I own a room project, when I upload a valid room image, then the API stores the image record and source metadata in Oracle and links it to my project and user.
- Given I upload an image that violates the MVP size, type, or retention policy, when the API validates the upload, then the upload is rejected with `validation_error` and no source image record is persisted.
- Given another user attempts to access my source image metadata, when they call the image API, then the API denies access without exposing image data.

## Tasks / Subtasks

- [x] Add source image repository contract and Oracle implementation.
- [x] Add source image upload and metadata retrieval endpoints.
- [x] Scope source image persistence and retrieval by authenticated user and owned project.
- [x] Add server tests for auth, policy rejection, successful persistence, and cross-user non-disclosure.
- [x] Add Flutter API client support for source image upload.

## Dev Notes

- Source image upload uses JSON with base64 image content to avoid adding multipart runtime dependencies in the current MVP server.
- `GET` metadata endpoints do not return image bytes.
- Cross-user project or image access returns `not_found`.

## Dev Agent Record

### Debug Log

- Added `SourceImageRepository` and `OracleSourceImageRepository`.
- Added `POST /room-projects/{project_id}/source-images`.
- Added `GET /room-projects/{project_id}/source-images/{source_image_id}`.
- Added fake repository tests for source image ownership and validation behavior.

### Completion Notes

- Valid source image uploads preserve original filename, generated stored name, content type, byte size, dimensions when available, SHA-256, upload timestamp, project ID, user ID, retention status, and original image bytes.
- Invalid uploads return standard `validation_error` envelopes.
- Cross-user metadata access returns `not_found`.

### File List

- `server/app/repositories/source_images.py`
- `server/app/routers/source_images.py`
- `server/app/schemas/source_images.py`
- `server/tests/test_source_images.py`
- `server/migrations/003_source_images_and_room_dimensions.sql`
- `app/lib/src/projects/project_api.dart`
- `app/lib/main.dart`

## Change Log

- 2026-05-19: Implemented source image upload and metadata persistence and moved story to review.
