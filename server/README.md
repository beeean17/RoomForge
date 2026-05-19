# RoomForge Server

Lightweight FastAPI service for Firebase token verification, authorization, Oracle DB access, job metadata, layout persistence, and admin operations.

The Oracle Cloud 1GB API server must not run heavy OpenCV, deep-learning, or GPU inference workloads. MVP OpenCV candidate extraction runs in the browser/editor layer.

## Local Verification

```bash
python3 -m compileall app tests
```

After installing development dependencies:

```bash
python3 -m pytest
```

## Auth Session Mapping

Protected API routes use `Authorization: Bearer <firebase_id_token>`.

`GET /auth/session` verifies the Firebase ID token and maps the Firebase user to an Oracle `users` record. The initial schema is in `migrations/001_user_session_mapping.sql`.

Configuration:

```env
ROOMFORGE_FIREBASE_PROJECT_ID=roomforge-dev
ROOMFORGE_FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099
ROOMFORGE_FIREBASE_ADMIN_CREDENTIALS_PATH=
ROOMFORGE_ORACLE_DSN=localhost/freepdb1
ROOMFORGE_ORACLE_USER=roomforge
ROOMFORGE_ORACLE_PASSWORD=change-me
```

If `ROOMFORGE_FIREBASE_AUTH_EMULATOR_HOST` is set, Firebase Admin verifies tokens against the local Auth emulator.

## Room Project APIs

Room project endpoints require `Authorization: Bearer <firebase_id_token>`.

- `GET /room-projects`: lists active projects owned by the authenticated user.
- `POST /room-projects`: creates a project owned by the authenticated user.
- `GET /room-projects/{project_id}`: returns an owned active project.
- `PUT /room-projects/{project_id}`: updates owned project metadata.
- `DELETE /room-projects/{project_id}`: soft deletes an owned project.

Cross-user access returns `not_found` so the API does not disclose whether another user's project exists.

Initial project persistence schema:

- `migrations/001_user_session_mapping.sql`
- `migrations/002_room_projects.sql`
- `migrations/003_source_images_and_room_dimensions.sql`
- `migrations/004_reconstruction_jobs.sql`

## Source Image Intake APIs

Source image endpoints require `Authorization: Bearer <firebase_id_token>` and
only operate on projects owned by the authenticated user.

- `POST /room-projects/{project_id}/source-images`: accepts a JSON payload with
  base64 image content and stores source image metadata plus the MVP Oracle BLOB.
- `GET /room-projects/{project_id}/source-images/{source_image_id}`: returns
  owned source image metadata without returning the image bytes.

MVP upload policy:

- Allowed content types: `image/jpeg`, `image/png`, `image/webp`.
- Default max size: `10485760` bytes, configurable with
  `ROOMFORGE_SOURCE_IMAGE_MAX_BYTES`.
- Metadata preserves original filename, generated stored name, content type,
  byte size, dimensions when supplied by the browser, SHA-256, upload timestamp,
  project linkage, user linkage, and retention status.

The MVP stores the original image in Oracle so authorization remains centralized.
Future object storage migration should keep the API metadata contract and move
`image_blob` behind an internal storage reference.

## Room Dimension APIs

Room dimension endpoints require `Authorization: Bearer <firebase_id_token>` and
only operate on projects owned by the authenticated user.

- `PUT /room-projects/{project_id}/dimensions`: saves width, depth, optional
  height, and explicit `meters` units.
- `GET /room-projects/{project_id}/dimensions`: returns saved owned dimensions.

If height is omitted, the API applies the MVP default height from
`ROOMFORGE_ROOM_DEFAULT_HEIGHT_METERS` and returns `height_source: "default"`.
Client-supplied height returns `height_source: "user"`.

## Reconstruction Job APIs

Reconstruction job endpoints require `Authorization: Bearer <firebase_id_token>`
and only operate on projects owned by the authenticated user.

- `POST /room-projects/{project_id}/reconstruction-jobs`: creates a job for an
  owned project that already has a source image and saved dimensions.
- `GET /room-projects/{project_id}/reconstruction-jobs/{job_id}`: returns the
  current job status and transition trail for client polling.

Allowed persisted statuses are `created`, `uploading`, `processing`,
`review_required`, `succeeded`, `failed`, `timeout`, `cancelled`, and `retrying`.
The persisted `review_required` status is exposed to users as "Needs review";
the API does not create a separate `needs_review` status.

## Admin Access Boundary

Admin endpoints require the same Firebase bearer token plus an Oracle-side `users.role`
value of `admin`.

- `GET /admin/session`: verifies that the authenticated user has admin access.

Normal authenticated users receive the standard `unauthorized` envelope with no
application data:

```json
{
  "data": null,
  "error": {
    "code": "unauthorized",
    "message": "Admin access is required."
  },
  "meta": {
    "request_id": "..."
  }
}
```
