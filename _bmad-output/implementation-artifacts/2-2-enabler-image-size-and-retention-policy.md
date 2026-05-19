# Story 2.2: Enabler - Image Size and Retention Policy

## Status

review

## Story

As a developer,
I want a defined MVP image size and retention policy,
So that upload behavior stays realistic for the Oracle-backed MVP server before upload persistence is implemented.

## Acceptance Criteria

- Given the MVP storage policy is configured, when an image exceeds the allowed size or type, then the API returns `validation_error` with a human-readable reason.
- Given a source image is accepted, when metadata is stored, then the record preserves filename or generated name, content type, size, dimensions when available, upload timestamp, project linkage, and retention status.
- Given the policy is documented, when future object storage migration is considered, then the MVP Oracle storage decision and migration boundary are clear.

## Tasks / Subtasks

- [x] Add server configuration for allowed source image content types.
- [x] Add server configuration for maximum source image byte size.
- [x] Add source image retention status to the persistence schema.
- [x] Return standard `validation_error` envelopes for invalid image payloads.
- [x] Document the MVP Oracle storage decision and object storage migration boundary.

## Dev Notes

- MVP source images are stored in Oracle BLOBs to keep auth and ownership centralized.
- The migration boundary is explicit: future object storage can replace `image_blob` with an internal storage reference while preserving API metadata.

## Dev Agent Record

### Debug Log

- Added source image policy settings to `Settings`.
- Added a global FastAPI request validation handler for standard `validation_error` envelopes.
- Added source image schema and migration fields for metadata, retention, SHA-256, and Oracle BLOB storage.

### Completion Notes

- Default accepted content types are JPEG, PNG, and WebP.
- Default maximum upload size is 10 MB.
- Server docs now describe upload policy, retained metadata, and future object storage migration.

### File List

- `server/app/core/config.py`
- `server/app/main.py`
- `server/app/schemas/source_images.py`
- `server/migrations/003_source_images_and_room_dimensions.sql`
- `server/README.md`
- `server/.env.example`

## Change Log

- 2026-05-19: Implemented MVP image policy and moved story to review.
