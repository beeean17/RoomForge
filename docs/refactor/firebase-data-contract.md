---
title: "RoomForge Firebase Data Contract"
status: "complete"
created: "2026-05-24"
updated: "2026-05-24"
completedAt: "2026-05-24"
workflowType: "data-contract"
stepsCompleted:
  - "step-01-source-analysis"
  - "step-02-contract-draft"
  - "step-03-parent-validation"
lastStep: 3
inputDocuments:
  - "docs/refactor/firebase-target-architecture.md"
  - "docs/refactor/firebase-ux-design-specification.md"
  - "docs/refactor/firebase-backend-refactor-plan.md"
  - "docs/product/prd.md"
project_name: "RoomForge"
user_name: "Yoon"
date: "2026-05-24"
parentWorkflow:
  - "firebase-refactor"
  - "architecture-follow-up"
---

# Firebase Data Contract - RoomForge Refactor

This document defines the field-level Firebase data contract for making Firebase the default RoomForge backend. It is a planning artifact for implementation workplans, epics, stories, repository interfaces, serializers, Security Rules, indexes, and emulator tests.

The contract follows the target architecture decision that Firebase Auth, Cloud Firestore, Cloud Storage for Firebase, Firebase Security Rules, and local IndexedDB draft/cache support replace the legacy Oracle/FastAPI default path. The legacy `server/` path may remain only behind an explicit `legacy_api` mode.

## Contract Scope

### In Scope

- Firestore collection and document paths.
- Required and optional fields for each default Firebase document.
- Ownership, timestamps, IDs, enum values, and coordinate-space rules.
- Cloud Storage object path and metadata expectations.
- IndexedDB draft/cache object stores and conflict fields.
- Admin role and admin action contract.
- Firestore index and collection group query candidates.
- Security Rules behavior requirements.
- Rules test matrix candidates for the Firebase emulator validation plan.

### Out of Scope

- Full Firestore Security Rules source code.
- Full Dart model implementations.
- Full TypeScript bridge type implementations.
- UI screen layout details.
- Oracle-to-Firebase historical data migration.
- Cloud Functions implementation. If a trusted role-management path later uses Cloud Functions, that belongs in the implementation workplan.

## Non-Negotiable Data Invariants

All implementation stories derived from this contract must preserve these invariants:

- Flutter owns Firebase Auth, Firestore, Storage, persistence, upload, save, load, export, draft recovery, and admin repository access.
- The Three.js/OpenCV editor must not import Firebase SDKs and must not call Firestore or Storage directly.
- Firestore persisted fields use `snake_case`.
- Export JSON uses `snake_case` for persisted/exported data.
- Editor bridge payload fields use `camelCase`.
- Firestore document IDs are strings.
- Candidate geometry and user-confirmed geometry remain separate document types and separate bridge concepts.
- Geometry payloads must declare `coordinate_space`.
- Image-space geometry uses `image_pixels`.
- Calibrated floor plan and layout geometry use `meters`.
- IndexedDB draft/cache state is recoverable local state only, not the system of record.
- Stored room images, artifacts, layouts, jobs, geometry, and results are private by default.
- All user-facing project, image, job, result, geometry, layout, and export operations require authenticated identity and ownership.
- Admin access requires an admin authorization check distinct from normal authenticated user access.
- Persisted reconstruction job statuses are exactly: `created`, `uploading`, `processing`, `review_required`, `succeeded`, `failed`, `timeout`, `cancelled`, `retrying`.
- Persisted `review_required` must be displayed to users as `Needs review`.
- Persisted job statuses must not include `needs_review`, `done`, `complete`, or `error`.

## Shared Type System

### Scalar Types

| Type | Meaning | Firestore representation |
| --- | --- | --- |
| `id_string` | Firestore document ID or generated local ID | `string` |
| `uid` | Firebase Auth UID | `string` |
| `timestamp` | Server-managed Firestore timestamp | `Timestamp` |
| `client_timestamp` | Client-created local timestamp, mainly IndexedDB | ISO-8601 `string` |
| `decimal` | Measurement or confidence value | `number` |
| `int` | Count, pixel, byte, or version value | `number` |
| `bool` | Boolean flag | `boolean` |
| `map` | Structured object | Firestore map |
| `array<T>` | Ordered list | Firestore array |

### Global ID Fields

Every durable Firestore document should include its document ID as an explicit field when that ID is needed by repository models, exports, admin views, or embedded snapshots.

Examples:

- `project_id`
- `source_image_id`
- `job_id`
- `result_id`
- `geometry_id`
- `floor_plan_id`
- `layout_id`
- `action_id`

### Global Timestamp Fields

Durable Firestore documents use these timestamp conventions:

- `created_at`: required on create.
- `updated_at`: required on every mutable document.
- `deleted_at`: optional soft-delete marker where soft delete is used.
- Domain-specific timestamps such as `uploaded_at`, `started_at`, `completed_at`, `status_updated_at`, and `saved_at` are added only where meaningful.

Implementation note: repository code may request server timestamps for Firestore writes. Rules and tests should focus on field presence, mutability, ownership, and allowed values rather than relying on exact client-provided timestamp equality.

### Ownership Fields

Every project document must include:

| Field | Type | Required | Rules |
| --- | --- | --- | --- |
| `owner_uid` | `uid` | Yes | Must equal `request.auth.uid` on normal user create. Immutable after create. |

Every project subcollection document must repeat:

| Field | Type | Required | Rules |
| --- | --- | --- | --- |
| `project_id` | `id_string` | Yes | Must equal parent `{project_id}`. Immutable after create. |
| `owner_uid` | `uid` | Yes | Must equal parent project `owner_uid`. Immutable after create. |

This repetition is intentional. It supports rules checks, admin collection group queries, debugging, export generation, and AI-agent consistency.

### Coordinate Types

#### `point_2d`

```json
{
  "x": 123.45,
  "y": 678.9
}
```

Rules:

- In `image_pixels`, `x` and `y` are pixel coordinates from the source image origin.
- In `meters`, `x` and `y` are metric floor-plan coordinates.

#### `point_3d`

```json
{
  "x": 1.2,
  "y": 0.0,
  "z": 2.4
}
```

Rules:

- Used only for editor scene and furniture layout state.
- Layout geometry must state `coordinate_space: "meters"` when persisted.

#### `artifact_ref`

```json
{
  "artifact_id": "artifact_123",
  "storage_path": "users/{uid}/projects/{project_id}/artifacts/{job_id}/{artifact_id}/overlay.png",
  "artifact_type": "opencv_overlay",
  "content_type": "image/png",
  "byte_size": 1048576,
  "created_at": "Timestamp"
}
```

Required fields:

- `artifact_id`
- `storage_path`
- `artifact_type`
- `content_type`

Optional fields:

- `byte_size`
- `sha256_hex`
- `width_px`
- `height_px`
- `created_at`
- `description`

Baseline decision: artifact metadata is embedded in the producing documents as `artifact_refs`. Do not introduce a standalone Firestore `artifacts` collection unless a later ADR updates the architecture.

## Enumerations

### `job_status`

Allowed persisted values:

- `created`
- `uploading`
- `processing`
- `review_required`
- `succeeded`
- `failed`
- `timeout`
- `cancelled`
- `retrying`

User-facing label:

| Persisted value | User label |
| --- | --- |
| `review_required` | `Needs review` |

Forbidden persisted values:

- `needs_review`
- `done`
- `complete`
- `error`

### `coordinate_space`

Allowed values:

- `image_pixels`
- `meters`

Rules:

- `opencv_results` and `confirmed_geometries` use `image_pixels` unless a future document explicitly stores calibrated evidence.
- `floor_plans` and saved layout spatial state use `meters`.

### `image_content_type`

Allowed source image content types:

- `image/jpeg`
- `image/png`
- `image/webp`

### `artifact_content_type`

Allowed generated artifact content types:

- `image/jpeg`
- `image/png`
- `image/webp`
- `application/json`

### `retention_status`

Allowed values:

- `active`
- `marked_for_delete`
- `deleted`

### `quality_status`

Allowed values:

- `success`
- `review_required`
- `failed`

### `actor_type`

Allowed values:

- `user`
- `system`
- `admin`
- `worker`

### `admin_role`

Allowed values:

- `admin`

Normal authenticated users are represented by the absence of `role` or by a non-privileged value handled by application code. Security Rules must treat only `role == "admin"` as admin authorization.

## Firestore Path Overview

```text
users/{uid}
projects/{project_id}
projects/{project_id}/source_images/{source_image_id}
projects/{project_id}/room_dimensions/current
projects/{project_id}/reconstruction_jobs/{job_id}
projects/{project_id}/reconstruction_jobs/{job_id}/transitions/{transition_id}
projects/{project_id}/opencv_results/{result_id}
projects/{project_id}/confirmed_geometries/{geometry_id}
projects/{project_id}/floor_plans/{floor_plan_id}
projects/{project_id}/layouts/{layout_id}
projects/{project_id}/admin_actions/{action_id}
```

## Collection Contracts

### `users/{uid}`

Purpose: Firebase Auth profile projection and admin role lookup.

Normal client profile upsert may write only non-privileged profile fields. `role` is privileged authorization state.

| Field | Type | Required | Write owner | Notes |
| --- | --- | --- | --- | --- |
| `uid` | `uid` | Yes | User on own doc | Must equal document ID. |
| `email` | `string` | Optional | User on own doc | From Firebase Auth provider; may be absent if provider does not expose it. |
| `display_name` | `string` | Optional | User on own doc | From Firebase Auth profile. |
| `photo_url` | `string` | Optional | User on own doc | Optional profile image URL from Auth provider. |
| `created_at` | `timestamp` | Yes | User on own doc | Set on first projection create. |
| `updated_at` | `timestamp` | Yes | User on own doc | Updated on profile sync. |
| `last_seen_at` | `timestamp` | Optional | User on own doc | Updated when app session is active. |
| `schema_version` | `int` | Yes | User on own doc | Start with `1`. |
| `role` | `admin_role` | Optional | Trusted/admin only | Privileged. Normal clients must not create, update, or delete it. |
| `role_updated_at` | `timestamp` | Optional | Trusted/admin only | Required when `role` is changed. |
| `role_updated_by_uid` | `uid` | Optional | Trusted/admin only | Admin or bootstrap identity that assigned the role. |

Security contract:

- Authenticated users may read their own `users/{uid}` document.
- Authenticated users may create or update their own profile fields.
- Authenticated users must not write `role`, `role_updated_at`, or `role_updated_by_uid` on their own profile.
- Authenticated profile updates must preserve any existing privileged role fields; deleting `role` through a normal profile write is also denied.
- Admins may read user profile documents needed for support/admin workflows.
- Admin role assignment must use a trusted bootstrap path, an admin-only write protected by rules, custom-claim sync, or an equivalent privileged function.
- A user must not be able to self-escalate by writing `users/{uid}.role`.

### `projects/{project_id}`

Purpose: Root room project owned by a single Firebase user.

| Field | Type | Required | Write owner | Notes |
| --- | --- | --- | --- | --- |
| `project_id` | `id_string` | Yes | Owner | Must equal document ID. |
| `owner_uid` | `uid` | Yes | Owner on create | Immutable after create. |
| `name` | `string` | Yes | Owner | Display name. |
| `description` | `string` | Optional | Owner | User-entered project notes. |
| `schema_version` | `int` | Yes | Owner | Start with `1`. |
| `created_at` | `timestamp` | Yes | Owner | Server timestamp. |
| `updated_at` | `timestamp` | Yes | Owner | Server timestamp. |
| `deleted_at` | `timestamp` | Optional | Owner | Soft delete marker if used. |
| `latest_source_image_id` | `id_string` | Optional | Owner/system | Most recent source image. |
| `latest_job_id` | `id_string` | Optional | Owner/system | Most recent reconstruction job. |
| `latest_floor_plan_id` | `id_string` | Optional | Owner/system | Most recent calibrated floor plan. |
| `latest_layout_id` | `id_string` | Optional | Owner/system | Most recently saved layout. |
| `current_reconstruction_status` | `job_status` | Optional | Owner/system | Mirrors active/latest job status for list UI. |
| `last_opened_at` | `timestamp` | Optional | Owner | Client may update to support sorting. |

Security contract:

- Normal users may create projects only with `owner_uid == request.auth.uid`.
- Normal users may read, update, and soft-delete only their own projects.
- `owner_uid` is immutable.
- Admins may read projects for support diagnostics through explicit admin queries.
- Admin writes to project data should be avoided unless covered by an auditable `admin_actions` record.

### `projects/{project_id}/source_images/{source_image_id}`

Purpose: Metadata for a source room image stored in Cloud Storage.

| Field | Type | Required | Write owner | Notes |
| --- | --- | --- | --- | --- |
| `source_image_id` | `id_string` | Yes | Owner | Must equal document ID. |
| `project_id` | `id_string` | Yes | Owner | Must equal parent project ID. |
| `owner_uid` | `uid` | Yes | Owner | Must equal project owner. |
| `storage_path` | `string` | Yes | Owner | Must match source image Storage path contract. |
| `original_filename` | `string` | Optional | Owner | Original file name, sanitized for display only. |
| `stored_filename` | `string` | Yes | Owner | Sanitized object file name. |
| `content_type` | `image_content_type` | Yes | Owner | JPEG, PNG, or WebP only. |
| `byte_size` | `int` | Yes | Owner | Must be `<= 10485760`. |
| `sha256_hex` | `string` | Yes | Owner | Hex digest for duplicate/debug checks. |
| `width_px` | `int` | Yes | Owner | Source image width in pixels. |
| `height_px` | `int` | Yes | Owner | Source image height in pixels. |
| `capture_source` | `string` | Optional | Owner | Example: `file_upload`, future `camera_capture`. |
| `retention_status` | `retention_status` | Yes | Owner/system | Default `active`. |
| `uploaded_at` | `timestamp` | Yes | Owner | Set after Storage upload completes. |
| `created_at` | `timestamp` | Yes | Owner | Metadata document create time. |
| `updated_at` | `timestamp` | Yes | Owner | Metadata document update time. |
| `schema_version` | `int` | Yes | Owner | Start with `1`. |

Security contract:

- Owner may create metadata only under an owned project.
- Metadata `storage_path` must be project-scoped and owner-scoped.
- Metadata content type and size must agree with allowed upload constraints.
- Users may not attach a source image metadata document to a project they do not own.
- Admins may read metadata for troubleshooting.

### `projects/{project_id}/room_dimensions/current`

Purpose: Current user-entered metric dimensions for a room project.

Document ID is fixed as `current`.

| Field | Type | Required | Write owner | Notes |
| --- | --- | --- | --- | --- |
| `project_id` | `id_string` | Yes | Owner | Must equal parent project ID. |
| `owner_uid` | `uid` | Yes | Owner | Must equal project owner. |
| `width_m` | `decimal` | Yes | Owner | Must be positive. |
| `depth_m` | `decimal` | Yes | Owner | Must be positive. |
| `height_m` | `decimal` | Yes | Owner | Positive; default allowed by UI. |
| `unit` | `string` | Yes | Owner | Must be `meters`. |
| `source` | `string` | Yes | Owner | Example: `user_entered`. |
| `created_at` | `timestamp` | Yes | Owner | Server timestamp. |
| `updated_at` | `timestamp` | Yes | Owner | Server timestamp. |
| `schema_version` | `int` | Yes | Owner | Start with `1`. |

Security contract:

- Owner may read/write dimensions for owned project only.
- Admins may read dimensions for troubleshooting.
- Values must remain metric in persisted Firestore state.

### `projects/{project_id}/reconstruction_jobs/{job_id}`

Purpose: Reconstruction lifecycle record for OpenCV/manual-assisted processing and future provider-compatible jobs.

| Field | Type | Required | Write owner | Notes |
| --- | --- | --- | --- | --- |
| `job_id` | `id_string` | Yes | Owner/system/admin retry | Must equal document ID. |
| `project_id` | `id_string` | Yes | Owner/system/admin retry | Must equal parent project ID. |
| `owner_uid` | `uid` | Yes | Owner/system/admin retry | Must equal project owner. |
| `source_image_id` | `id_string` | Yes | Owner/system | Source image for the job. |
| `room_dimensions_id` | `string` | Yes | Owner/system | Baseline value: `current`. |
| `status` | `job_status` | Yes | Owner/system/admin retry | Allowed vocabulary only. |
| `status_updated_at` | `timestamp` | Yes | Owner/system/admin retry | Updated with every status change. |
| `provider_type` | `string` | Yes | Owner/system | Baseline: `manual_assisted_opencv`. |
| `provider_id` | `string` | Optional | Owner/system | Provider identifier for future providers. |
| `algorithm_id` | `string` | Optional | Owner/system | Example: `opencv_lines_corners_v1`. |
| `opencv_version` | `string` | Optional | Owner/system | Browser OpenCV.js version when available. |
| `created_by_uid` | `uid` | Yes | Owner/admin retry | User/admin who created the job. |
| `retry_of_job_id` | `id_string` | Optional | Admin/owner retry | Previous job if this is a retry. |
| `root_job_id` | `id_string` | Optional | Admin/owner retry | First job in retry chain. |
| `retry_count` | `int` | Yes | Owner/system/admin retry | Default `0`; increment for retry chain metadata. |
| `latest_result_id` | `id_string` | Optional | Owner/system | Latest OpenCV result. |
| `latest_confirmed_geometry_id` | `id_string` | Optional | Owner/system | Latest confirmed geometry. |
| `latest_floor_plan_id` | `id_string` | Optional | Owner/system | Latest floor plan. |
| `failure_reason_code` | `string` | Optional | Owner/system | Machine-readable failure reason. |
| `failure_reason` | `string` | Optional | Owner/system | Human-readable reason. |
| `quality_status` | `quality_status` | Optional | Owner/system | Success/review/failed quality category. |
| `artifact_refs` | `array<artifact_ref>` | Optional | Owner/system | CV overlays, calibration output, debug JSON. |
| `started_at` | `timestamp` | Optional | Owner/system | Processing start. |
| `completed_at` | `timestamp` | Optional | Owner/system | Terminal completion time. |
| `timeout_at` | `timestamp` | Optional | Owner/system | Expected timeout deadline. |
| `created_at` | `timestamp` | Yes | Owner/system/admin retry | Server timestamp. |
| `updated_at` | `timestamp` | Yes | Owner/system/admin retry | Server timestamp. |
| `schema_version` | `int` | Yes | Owner/system/admin retry | Start with `1`. |

Security contract:

- Owner may create and read jobs for owned projects.
- Owner/system repository may update status only to allowed values.
- Rules must reject forbidden status values.
- Terminal states are `succeeded`, `failed`, `timeout`, and `cancelled`.
- `review_required` is non-terminal for user decision-making but is a persisted status and must display as `Needs review`.
- Admin retry may create a linked retry job and must also create an `admin_actions` record.
- `owner_uid`, `project_id`, and `job_id` are immutable after create.

### `projects/{project_id}/reconstruction_jobs/{job_id}/transitions/{transition_id}`

Purpose: Immutable audit trail of job status transitions.

| Field | Type | Required | Write owner | Notes |
| --- | --- | --- | --- | --- |
| `transition_id` | `id_string` | Yes | Owner/system/admin | Must equal document ID. |
| `project_id` | `id_string` | Yes | Owner/system/admin | Parent project ID. |
| `owner_uid` | `uid` | Yes | Owner/system/admin | Project owner. |
| `job_id` | `id_string` | Yes | Owner/system/admin | Parent job ID. |
| `from_status` | `job_status` | Optional | Owner/system/admin | Null/absent for first transition. |
| `to_status` | `job_status` | Yes | Owner/system/admin | Allowed vocabulary only. |
| `occurred_at` | `timestamp` | Yes | Owner/system/admin | Transition time. |
| `actor_type` | `actor_type` | Yes | Owner/system/admin | User/system/admin/worker. |
| `actor_uid` | `uid` | Optional | Owner/system/admin | Required for user/admin actors where available. |
| `reason_code` | `string` | Optional | Owner/system/admin | Machine-readable reason. |
| `reason_message` | `string` | Optional | Owner/system/admin | Human-readable reason. |
| `artifact_refs` | `array<artifact_ref>` | Optional | Owner/system/admin | Related artifacts. |
| `retry_job_id` | `id_string` | Optional | Admin/owner retry | New job if this transition creates a retry. |
| `schema_version` | `int` | Yes | Owner/system/admin | Start with `1`. |

Security contract:

- Transitions are append-only.
- Owners may read transitions for owned projects.
- Admins may read transitions for support.
- Updates and deletes should be denied in the baseline unless a later maintenance story defines a privileged correction path.

### `projects/{project_id}/opencv_results/{result_id}`

Purpose: OpenCV candidate output and processing metadata before user confirmation.

| Field | Type | Required | Write owner | Notes |
| --- | --- | --- | --- | --- |
| `result_id` | `id_string` | Yes | Owner/system | Must equal document ID. |
| `project_id` | `id_string` | Yes | Owner/system | Parent project ID. |
| `owner_uid` | `uid` | Yes | Owner/system | Project owner. |
| `job_id` | `id_string` | Yes | Owner/system | Producing job. |
| `source_image_id` | `id_string` | Yes | Owner/system | Input image. |
| `coordinate_space` | `coordinate_space` | Yes | Owner/system | Must be `image_pixels`. |
| `algorithm_id` | `string` | Yes | Owner/system | CV algorithm identifier. |
| `opencv_version` | `string` | Optional | Owner/system | Runtime version if available. |
| `candidate_edges` | `array<map>` | Optional | Owner/system | Edge segments in image pixels. |
| `candidate_lines` | `array<map>` | Optional | Owner/system | Dominant lines in image pixels. |
| `candidate_corners` | `array<point_2d>` | Optional | Owner/system | Candidate room/corner points. |
| `boundary_hints` | `array<map>` | Optional | Owner/system | Suggested boundary polygons/rectangles. |
| `confidence_score` | `decimal` | Optional | Owner/system | `0.0` to `1.0` when available. |
| `quality_status` | `quality_status` | Yes | Owner/system | Success/review/failed category. |
| `failure_reason_code` | `string` | Optional | Owner/system | Required when quality is `failed` where known. |
| `failure_reason` | `string` | Optional | Owner/system | Human-readable failure reason. |
| `artifact_refs` | `array<artifact_ref>` | Optional | Owner/system | Overlay images/debug JSON. |
| `processing_started_at` | `timestamp` | Optional | Owner/system | Processing start. |
| `processing_completed_at` | `timestamp` | Optional | Owner/system | Processing finish. |
| `created_at` | `timestamp` | Yes | Owner/system | Server timestamp. |
| `updated_at` | `timestamp` | Yes | Owner/system | Server timestamp. |
| `schema_version` | `int` | Yes | Owner/system | Start with `1`. |

Security contract:

- Owner may create/read results only for owned project.
- Admins may read results for troubleshooting.
- Candidate geometry must not be stored in `confirmed_geometries`.
- Rules should validate `coordinate_space == "image_pixels"` for this collection.

### `projects/{project_id}/confirmed_geometries/{geometry_id}`

Purpose: User-confirmed or user-corrected room boundary geometry before metric floor-plan calibration.

| Field | Type | Required | Write owner | Notes |
| --- | --- | --- | --- | --- |
| `geometry_id` | `id_string` | Yes | Owner | Must equal document ID. |
| `project_id` | `id_string` | Yes | Owner | Parent project ID. |
| `owner_uid` | `uid` | Yes | Owner | Project owner. |
| `job_id` | `id_string` | Yes | Owner | Related reconstruction job. |
| `source_image_id` | `id_string` | Yes | Owner | Input image. |
| `opencv_result_id` | `id_string` | Optional | Owner | Candidate source, if any. |
| `coordinate_space` | `coordinate_space` | Yes | Owner | Must be `image_pixels`. |
| `boundary_type` | `string` | Yes | Owner | `rectangle` or `simple_polygon`. |
| `boundary_points` | `array<point_2d>` | Yes | Owner | User-confirmed image pixel points. |
| `correction_method` | `string` | Optional | Owner | Example: `candidate_adjusted`, `manual`. |
| `confirmed_by_uid` | `uid` | Yes | Owner | Usually equals `owner_uid`. |
| `created_at` | `timestamp` | Yes | Owner | Server timestamp. |
| `updated_at` | `timestamp` | Yes | Owner | Server timestamp. |
| `schema_version` | `int` | Yes | Owner | Start with `1`. |

Security contract:

- Owner may create/read/update confirmed geometry for owned project.
- Admins may read confirmed geometry for troubleshooting.
- Confirmed geometry must remain separate from OpenCV candidate result documents.
- Rules should validate `coordinate_space == "image_pixels"` for this collection.

### `projects/{project_id}/floor_plans/{floor_plan_id}`

Purpose: Calibrated metric floor plan derived from confirmed geometry and user-entered room dimensions.

| Field | Type | Required | Write owner | Notes |
| --- | --- | --- | --- | --- |
| `floor_plan_id` | `id_string` | Yes | Owner/system | Must equal document ID. |
| `project_id` | `id_string` | Yes | Owner/system | Parent project ID. |
| `owner_uid` | `uid` | Yes | Owner/system | Project owner. |
| `job_id` | `id_string` | Yes | Owner/system | Related job. |
| `source_image_id` | `id_string` | Yes | Owner/system | Input image. |
| `confirmed_geometry_id` | `id_string` | Yes | Owner/system | Calibrated geometry source. |
| `room_dimensions_id` | `string` | Yes | Owner/system | Baseline value: `current`. |
| `coordinate_space` | `coordinate_space` | Yes | Owner/system | Must be `meters`. |
| `room_dimensions` | `map` | Yes | Owner/system | Snapshot with `width_m`, `depth_m`, `height_m`, `unit`. |
| `floor_polygon` | `array<point_2d>` | Yes | Owner/system | Metric floor polygon. |
| `walls` | `array<map>` | Optional | Owner/system | Wall segments/height in meters. |
| `calibration` | `map` | Yes | Owner/system | Scale, transform, assumptions, residual/error metadata. |
| `quality_status` | `quality_status` | Yes | Owner/system | Success/review/failed category. |
| `warnings` | `array<string>` | Optional | Owner/system | Calibration or geometry warnings. |
| `artifact_refs` | `array<artifact_ref>` | Optional | Owner/system | Calibration output/debug artifacts. |
| `created_at` | `timestamp` | Yes | Owner/system | Server timestamp. |
| `updated_at` | `timestamp` | Yes | Owner/system | Server timestamp. |
| `schema_version` | `int` | Yes | Owner/system | Start with `1`. |

Security contract:

- Owner may create/read floor plans for owned project.
- Admins may read floor plans for troubleshooting.
- Rules should validate `coordinate_space == "meters"` for this collection.
- Floor plan documents must not overwrite candidate or confirmed geometry source documents.

### `projects/{project_id}/layouts/{layout_id}`

Purpose: Cloud-saved layout state used for load, save, round-trip validation, and JSON export.

| Field | Type | Required | Write owner | Notes |
| --- | --- | --- | --- | --- |
| `layout_id` | `id_string` | Yes | Owner | Must equal document ID. |
| `project_id` | `id_string` | Yes | Owner | Parent project ID. |
| `owner_uid` | `uid` | Yes | Owner | Project owner. |
| `name` | `string` | Optional | Owner | Optional saved layout name. |
| `source_image_id` | `id_string` | Yes | Owner | Source image snapshot reference. |
| `reconstruction_job_id` | `id_string` | Yes | Owner | Job used by this layout. |
| `reconstruction_status` | `job_status` | Yes | Owner | Must use allowed vocabulary. |
| `review_required` | `bool` | Yes | Owner | True when status is `review_required` or floor plan quality requires warning. |
| `floor_plan_id` | `id_string` | Yes | Owner | Metric floor plan reference. |
| `coordinate_space` | `coordinate_space` | Yes | Owner | Must be `meters`. |
| `room_dimensions` | `map` | Yes | Owner | Snapshot of width/depth/height in meters. |
| `source_metadata` | `map` | Yes | Owner | Snapshot of source image metadata needed for export. |
| `floor_plan` | `map` | Yes | Owner | Snapshot of metric floor plan needed for round trip. |
| `editor_scene` | `map` | Yes | Owner | Editor scene state in persisted snake_case format. |
| `furniture_objects` | `array<map>` | Yes | Owner | Furniture proxy objects. |
| `base_floor_plan_updated_at` | `timestamp` | Optional | Owner | Helps detect stale layout against floor plan. |
| `saved_at` | `timestamp` | Yes | Owner | Save completion timestamp. |
| `created_at` | `timestamp` | Yes | Owner | Server timestamp. |
| `updated_at` | `timestamp` | Yes | Owner | Server timestamp. |
| `schema_version` | `int` | Yes | Owner | Start with `1`. |
| `export_version` | `int` | Yes | Owner | Start with `1`. |

Required `furniture_objects[]` fields:

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `furniture_id` | `id_string` | Yes | Stable object ID. |
| `category` | `string` | Yes | At least `bed`, `desk`, `chair`, `wardrobe`, `sofa`; optional `custom` may be added later. |
| `position_m` | `point_3d` | Yes | Metric position. |
| `size_m` | `point_3d` | Yes | Metric size. |
| `rotation_deg` | `decimal` | Yes | Rotation around vertical axis unless scene model expands. |
| `color` | `string` | Optional | Persisted display color. |
| `label` | `string` | Optional | User-visible label. |
| `locked` | `bool` | Optional | Selection/editing lock. |

Security contract:

- Owner may create/read/update/delete layouts for owned project.
- Admins may read layouts for troubleshooting.
- Layout writes must preserve required room dimensions, source metadata, floor plan data, editor scene, and furniture object fields.
- Layout export is generated from the latest saved Firestore layout, not from an unsaved IndexedDB draft unless the UI explicitly saves first.
- A layout with `reconstruction_status == "review_required"` must keep `review_required == true`.

### `projects/{project_id}/admin_actions/{action_id}`

Purpose: Auditable admin/support actions such as retry creation, support notes, artifact inspection notes, or permission diagnosis records.

| Field | Type | Required | Write owner | Notes |
| --- | --- | --- | --- | --- |
| `action_id` | `id_string` | Yes | Admin | Must equal document ID. |
| `project_id` | `id_string` | Yes | Admin | Parent project ID. |
| `owner_uid` | `uid` | Yes | Admin | Project owner, not admin UID. |
| `created_by_uid` | `uid` | Yes | Admin | Admin actor UID. |
| `created_by_role` | `admin_role` | Yes | Admin | Must be `admin`. |
| `action_type` | `string` | Yes | Admin | Example: `retry_job`, `support_note`, `artifact_check`, `permission_check`. |
| `target_type` | `string` | Yes | Admin | Example: `project`, `job`, `layout`, `source_image`, `artifact`, `user`. |
| `target_id` | `id_string` | Yes | Admin | Target document or artifact ID. |
| `reason_code` | `string` | Optional | Admin | Machine-readable reason. |
| `reason_message` | `string` | Optional | Admin | Human-readable support note. |
| `permission_outcome` | `string` | Optional | Admin | Example: `allowed`, `denied`, `artifact_missing`, `role_required`. |
| `retry_job_id` | `id_string` | Optional | Admin | New retry job if action created one. |
| `metadata` | `map` | Optional | Admin | Bounded diagnostic metadata. |
| `created_at` | `timestamp` | Yes | Admin | Server timestamp. |
| `schema_version` | `int` | Yes | Admin | Start with `1`. |

Security contract:

- Only admins may create `admin_actions`.
- Normal users may not create, update, delete, list, or read `admin_actions`.
- Admin action documents are append-only in the baseline.
- Admin retry must create both a linked retry job and an `admin_actions` record.

## Cloud Storage Contract

### Source Image Path

```text
users/{uid}/projects/{project_id}/source-images/{source_image_id}/{filename}
```

Required constraints:

- `{uid}` must match `request.auth.uid` for normal user writes.
- `{project_id}` must refer to a project owned by `{uid}`.
- `{source_image_id}` must match the Firestore source image metadata document ID.
- `{filename}` must be sanitized and must not contain path traversal characters.
- Allowed content types: `image/jpeg`, `image/png`, `image/webp`.
- Maximum size: `10 MB` (`10485760` bytes).
- Source images are private by default.
- Do not rely on public download URLs as access control.

Recommended Storage custom metadata:

| Metadata key | Required | Notes |
| --- | --- | --- |
| `owner_uid` | Yes | Must match path `{uid}`. |
| `project_id` | Yes | Must match path `{project_id}`. |
| `source_image_id` | Yes | Must match path `{source_image_id}`. |
| `sha256_hex` | Optional | Firestore metadata remains authoritative for digest. |
| `uploaded_by_uid` | Yes | Normal flow equals owner UID. |

Storage-to-Firestore handshake:

- Flutter validates file type and size before upload.
- Storage Rules validate type and size where supported.
- Storage writes should be owner-scoped by path.
- To reduce orphan uploads, the write should correspond to an existing owned `projects/{project_id}` document where practical through a Firestore rules lookup, trusted upload metadata, or an implementation-defined reservation flow.
- After Storage upload succeeds, Flutter writes `source_images/{source_image_id}` metadata.
- If metadata write fails, UX must show `metadata save failed` and offer retry or cleanup.

### Artifact Path

```text
users/{uid}/projects/{project_id}/artifacts/{job_id}/{artifact_id}/{filename}
```

Artifact examples:

- OpenCV edge/line/corner overlay image.
- Corrected boundary visualization.
- Perspective/scale calibration output.
- Debug JSON for evaluation.
- Generated preview image for admin diagnosis.

Required constraints:

- Artifacts are private by default.
- Owner may read artifacts for owned projects when surfaced by user-facing recovery/export flows.
- Admins may read artifacts for troubleshooting when `users/{request.auth.uid}.role == "admin"`.
- Normal users may not read another user's artifacts.
- Normal users may not list broad artifact prefixes outside their own path.
- Admin artifact reads must not make objects public.
- Allowed artifact content types: `image/jpeg`, `image/png`, `image/webp`, `application/json`.
- Recommended max size: `10 MB` for image artifacts and `2 MB` for JSON artifacts unless a later validation plan changes the limit.

Artifact metadata link:

- Producing Firestore documents store `artifact_refs[]`.
- `artifact_refs[].storage_path` must match the artifact path.
- Admin UI uses `artifact_refs` plus Storage read attempts to show `available`, `restricted`, `missing`, `failed_to_load`, or `not_generated`.

## IndexedDB Draft and Cache Contract

IndexedDB is local recoverable state only. It must not be treated as the cloud source of truth.

Database:

```text
roomforge_drafts
```

Version:

```text
1
```

### Object Store: `layout_drafts`

Key:

```text
{uid}/{project_id}/{layout_id_or_current}
```

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `draft_key` | `string` | Yes | Same as object-store key. |
| `uid` | `uid` | Yes | Local auth UID at draft time. |
| `project_id` | `id_string` | Yes | Project context. |
| `layout_id` | `id_string` | Optional | Cloud layout being edited; absent for current/new layout draft. |
| `base_cloud_layout_id` | `id_string` | Optional | Cloud layout used as draft base. |
| `base_cloud_updated_at` | `client_timestamp` | Optional | Last known cloud `updated_at` serialized locally. |
| `base_cloud_hash` | `string` | Optional | Optional content hash for conflict checks. |
| `schema_version` | `int` | Yes | Local draft schema version. |
| `room_dimensions_snapshot` | `map` | Yes | Snapshot used by editor. |
| `floor_plan_snapshot` | `map` | Yes | Snapshot used by editor. |
| `source_metadata_snapshot` | `map` | Yes | Snapshot used by editor/export warning. |
| `editor_scene` | `map` | Yes | Local editor scene state. |
| `furniture_objects` | `array<map>` | Yes | Local furniture state. |
| `reconstruction_status` | `job_status` | Yes | Last known related job status. |
| `review_required` | `bool` | Yes | Controls local export/save warning. |
| `dirty_fields` | `array<string>` | Yes | Fields changed since cloud base. |
| `sync_state` | `string` | Yes | `unsaved_draft`, `saving`, `sync_failed`, `conflict`, `saved`. |
| `last_error_code` | `string` | Optional | Last local/cloud sync failure category. |
| `last_error_message` | `string` | Optional | Safe user/debug message. |
| `created_at` | `client_timestamp` | Yes | Local create time. |
| `updated_at` | `client_timestamp` | Yes | Local update time. |
| `last_accessed_at` | `client_timestamp` | Optional | Cleanup/sorting. |

Conflict rule:

- If `base_cloud_updated_at` differs from the latest Firestore layout `updated_at`, Flutter must show a cloud/draft conflict choice.
- Firestore streams may refresh passive status surfaces but must not overwrite an active local draft silently.
- User-facing choices should include continuing with cloud version, restoring local draft, and discarding local draft.

### Object Store: `project_cache`

Purpose: Optional local cache for fast project-list return continuity.

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `cache_key` | `string` | Yes | `{uid}/projects`. |
| `uid` | `uid` | Yes | Auth UID. |
| `projects` | `array<map>` | Yes | Redacted project list snapshots. |
| `updated_at` | `client_timestamp` | Yes | Local cache update time. |
| `schema_version` | `int` | Yes | Local cache schema version. |

Rules:

- Cache must be cleared or ignored on sign-out.
- Cache must not grant access to cloud data after auth changes.
- Cache display must be replaced by Firestore results or a permission recovery state when available.

## Firestore Index and Query Candidates

The exact `firestore.indexes.json` will be generated during implementation, but the following query shapes must be supported.

### User Queries

| Query | Collection scope | Filters | Order | Purpose |
| --- | --- | --- | --- | --- |
| User project list | `projects` | `owner_uid == current_uid`, optional `deleted_at == null` | `updated_at desc` | Project list. |
| Project source images | `projects/{project_id}/source_images` | parent path, owner checked by rules | `uploaded_at desc` | Source image history. |
| Project jobs | `projects/{project_id}/reconstruction_jobs` | parent path, owner checked by rules | `created_at desc` | Job timeline. |
| Active/latest job | `projects/{project_id}/reconstruction_jobs` | `status in [...]` if needed | `status_updated_at desc` | Reconstruction state. |
| Project layouts | `projects/{project_id}/layouts` | parent path, owner checked by rules | `updated_at desc` | Load saved layout. |

### Admin Collection Group Queries

| Query | Collection group | Filters | Order | Purpose |
| --- | --- | --- | --- | --- |
| Jobs by status | `reconstruction_jobs` | `status == value` | `updated_at desc` | Admin dashboard. |
| Jobs by owner | `reconstruction_jobs` | `owner_uid == uid` | `created_at desc` | User support lookup. |
| Jobs by project | `reconstruction_jobs` | `project_id == project_id` | `created_at desc` | Project diagnosis. |
| Jobs by retry source | `reconstruction_jobs` | `retry_of_job_id == job_id` | `created_at desc` | Retry history. |
| Results by job | `opencv_results` | `job_id == job_id` | `created_at desc` | CV output lookup. |
| Layouts by owner | `layouts` | `owner_uid == uid` | `updated_at desc` | Support layout lookup. |
| Admin actions by target | `admin_actions` | `target_type == type`, `target_id == id` | `created_at desc` | Audit trail. |
| Transitions by job | `transitions` | `job_id == job_id` | `occurred_at asc` | Status timeline. |

Index implementation notes:

- Firestore Security Rules are not filters. Repository queries must include the constraints needed for rules to prove access.
- Owner-facing collection group queries should include `owner_uid == request.auth.uid` when used outside a parent path.
- Admin collection group queries require admin role checks and must avoid client-side filtering as the only authorization boundary.
- Any query added during implementation must be paired with a rules test and index entry if Firestore requires one.

## Security Rules Behavior Contract

This section describes required behavior, not final rules syntax.

### Global Rule Principles

- Deny by default.
- Require `request.auth != null` for every default Firebase app data path.
- Public reads are denied for Firestore and Storage data covered by this contract.
- Owner access requires project ownership.
- Admin access requires `users/{request.auth.uid}.role == "admin"`.
- Rules must prevent self-service role escalation.
- Rules must validate immutable ownership fields.
- Rules must reject forbidden job statuses.
- Rules must validate coordinate-space values where practical.
- Rules must not be relied on as query filters.

### Firestore Behavior

| Path | Owner behavior | Admin behavior | Denials |
| --- | --- | --- | --- |
| `users/{uid}` | User can read and update allowed own profile fields. | Admin can read profiles needed for support; privileged role writes only through trusted/admin path. | User cannot write own `role`; unauthenticated denied. |
| `projects/{project_id}` | Owner CRUD with immutable `owner_uid`. | Admin read for diagnostics; writes only if explicitly auditable. | Non-owner denied. |
| `source_images` | Owner read/write metadata for owned project. | Admin read. | Cross-owner metadata denied. |
| `room_dimensions/current` | Owner read/write for owned project. | Admin read. | Cross-owner denied. |
| `reconstruction_jobs` | Owner create/read/update allowed lifecycle fields for owned project. | Admin read; admin retry create with audit. | Bad status, owner change, cross-owner denied. |
| `transitions` | Owner read and append for owned project. | Admin read/append for audited actions. | Update/delete denied in baseline. |
| `opencv_results` | Owner read/write for owned project. | Admin read. | Wrong coordinate space or cross-owner denied. |
| `confirmed_geometries` | Owner read/write for owned project. | Admin read. | Wrong coordinate space or cross-owner denied. |
| `floor_plans` | Owner read/write for owned project. | Admin read. | Wrong coordinate space or cross-owner denied. |
| `layouts` | Owner CRUD for owned project. | Admin read. | Cross-owner denied; invalid status denied. |
| `admin_actions` | No normal user access. | Admin create/read; append-only baseline. | Non-admin denied. |

### Storage Behavior

| Path | Owner behavior | Admin behavior | Denials |
| --- | --- | --- | --- |
| `users/{uid}/projects/{project_id}/source-images/{source_image_id}/{filename}` | Owner read/write if authenticated, path UID matches auth UID, project ownership is valid, type/size valid. | Admin read for troubleshooting. | Non-owner read/write denied; public denied; invalid type/size denied. |
| `users/{uid}/projects/{project_id}/artifacts/{job_id}/{artifact_id}/{filename}` | Owner read for owned project; owner write for client-generated artifacts if implementation requires it. | Admin read for diagnostics. | Non-owner denied; broad public/list denied; invalid content type denied. |

## Rules Test Matrix Candidates

These test cases should be converted into Firebase emulator tests in the validation workflow.

| ID | Area | Actor | Expected result |
| --- | --- | --- | --- |
| `rules-owner-project-read` | Firestore projects | Owner reads own project | Allow |
| `rules-owner-project-write` | Firestore projects | Owner creates project with `owner_uid == uid` | Allow |
| `rules-project-owner-immutable` | Firestore projects | Owner changes `owner_uid` | Deny |
| `rules-non-owner-project-read` | Firestore projects | User B reads User A project | Deny |
| `rules-non-owner-layout-read` | Firestore layouts | User B reads User A layout | Deny |
| `rules-owner-layout-roundtrip-write` | Firestore layouts | Owner writes required layout fields | Allow |
| `rules-layout-invalid-status` | Firestore layouts | Owner writes `reconstruction_status: "done"` | Deny |
| `rules-job-valid-status` | Firestore jobs | Owner writes `status: "review_required"` | Allow |
| `rules-job-invalid-status` | Firestore jobs | Owner writes `status: "needs_review"` | Deny |
| `rules-opencv-coordinate-space` | Firestore results | Owner writes OpenCV result with `image_pixels` | Allow |
| `rules-opencv-wrong-coordinate-space` | Firestore results | Owner writes OpenCV result with `meters` | Deny |
| `rules-floor-plan-coordinate-space` | Firestore floor plans | Owner writes floor plan with `meters` | Allow |
| `rules-confirmed-geometry-separation` | Firestore geometry | Owner writes confirmed geometry under `confirmed_geometries` | Allow |
| `rules-candidate-confirmed-mix` | Firestore geometry | Owner writes candidate-only document under `confirmed_geometries` | Deny if required fields/intent invalid |
| `rules-user-profile-upsert` | Firestore users | User creates own profile without `role` | Allow |
| `rules-self-role-escalation-create` | Firestore users | User creates own profile with `role: "admin"` | Deny |
| `rules-self-role-escalation-update` | Firestore users | User updates own `role` to `admin` | Deny |
| `rules-non-admin-admin-actions-read` | Firestore admin | Normal user reads `admin_actions` | Deny |
| `rules-admin-admin-actions-create` | Firestore admin | Admin creates `admin_actions` record | Allow |
| `rules-admin-job-read` | Firestore admin | Admin collection-group reads jobs | Allow |
| `rules-non-admin-job-cg-read` | Firestore admin | Normal user collection-group reads other users' jobs | Deny |
| `rules-storage-source-owner-upload` | Storage source images | Owner uploads JPEG/PNG/WebP <= 10 MB to own path | Allow |
| `rules-storage-source-invalid-type` | Storage source images | Owner uploads disallowed content type | Deny |
| `rules-storage-source-too-large` | Storage source images | Owner uploads source image > 10 MB | Deny |
| `rules-storage-source-cross-user` | Storage source images | User B reads or writes User A image path | Deny |
| `rules-storage-artifact-owner-read` | Storage artifacts | Owner reads own project artifact | Allow |
| `rules-storage-artifact-admin-read` | Storage artifacts | Admin reads user artifact for troubleshooting | Allow |
| `rules-storage-artifact-non-admin-cross-user` | Storage artifacts | Normal user reads another user's artifact | Deny |
| `rules-storage-orphan-project` | Storage source images | User uploads under project ID not owned by path UID | Deny where project lookup/handshake is implemented |

## Repository and Serializer Implications

### Flutter Repository Boundaries

Firebase repository implementations should be domain-first and should map Firestore `snake_case` to Dart `camelCase`.

Recommended repositories:

- `UserRepository`
- `ProjectRepository`
- `SourceImageRepository`
- `RoomDimensionsRepository`
- `ReconstructionRepository`
- `GeometryRepository`
- `FloorPlanRepository`
- `LayoutRepository`
- `DraftRepository`
- `AdminRepository`

### Editor Bridge Boundary

The editor bridge receives and emits `camelCase` payloads. Flutter is responsible for converting bridge payloads to persisted Firestore `snake_case`.

Example mapping:

| Editor bridge | Firestore/export |
| --- | --- |
| `projectId` | `project_id` |
| `sourceImageId` | `source_image_id` |
| `candidateGeometry` | `opencv_results` document data |
| `confirmedGeometry` | `confirmed_geometries` document data |
| `floorPlan` | `floor_plan` or `floor_plans/{floor_plan_id}` |
| `furnitureObjects` | `furniture_objects` |
| `coordinateSpace` | `coordinate_space` |

The editor must not receive Firebase credentials, Storage URLs as authority, or direct Firestore paths as persistence instructions. It may receive IDs and state necessary for spatial context.

## Traceability to Requirements

| Requirement area | Contract coverage |
| --- | --- |
| FR1-FR4 Auth/admin | `users/{uid}`, privileged `role`, admin rules, admin actions. |
| FR5-FR9 Projects | `projects/{project_id}` and owner-scoped rules. |
| FR10-FR14 Image input | Storage source path and `source_images` metadata. |
| FR15-FR28 Reconstruction | `reconstruction_jobs`, `transitions`, `opencv_results`, `confirmed_geometries`, `floor_plans`. |
| FR29-FR36 3D/furniture editing | `layouts.editor_scene`, `layouts.furniture_objects`, editor bridge mapping. |
| FR37-FR40 Save/load/export | `layouts`, layout snapshots, export version, review warning fields. |
| FR41-FR50 Admin/support | admin role checks, admin collection group query candidates, `admin_actions`, artifact refs, transitions. |
| NFR6-NFR10 Security | Auth required, owner/admin checks, no public reads, explicit denials. |
| NFR20-NFR23 Data integrity | layout round-trip fields, job traceability, status transitions, retry linkage. |
| NFR24-NFR25 UX status | persisted `review_required` and user label `Needs review`. |

## Open Questions for Follow-Up Workflows

These are not blockers for creating the refactor workplan, but they should be resolved before feature migration stories are implemented:

- Whether role assignment is implemented by manual Firestore bootstrap, admin-only UI, custom claims sync, or a Cloud Function.
- Whether artifact writes are owner-generated only or also produced by a future trusted worker.
- Whether `admin` is the only privileged role for MVP or whether `support` should be added later with narrower access.
- Whether soft delete is required for all mutable documents or only projects/layouts.
- Whether JSON export should include a content hash for round-trip verification.
- Whether Firestore aggregate counters are needed for admin dashboard summaries.

## Completion Criteria for Parent Validation

The parent workflow can mark this data contract complete when:

- Firestore paths and fields cover the Firebase target architecture.
- Storage source image and artifact contracts are explicit.
- IndexedDB draft/cache schema is implementation-ready enough for story planning.
- Admin role escalation is explicitly denied.
- Rules behavior and test candidates cover owner, non-owner, admin, non-admin, status validation, coordinate-space validation, and Storage constraints.
- No source document outside `docs/refactor/firebase-data-contract.md` was modified by this workflow.

## Parent Validation Record

Validated on 2026-05-24.

- Result: APPROVE.
- Scope check: The contract covers Firestore paths, Storage paths, IndexedDB draft/cache, admin role/action behavior, indexes, rules behavior, and emulator test candidates.
- Security check: Owner fields, admin role checks, role self-escalation denial, immutable ownership, private Storage, and non-public artifacts are explicit.
- Product check: Candidate/confirmed geometry separation, `review_required` persistence, `Needs review` label, save/load/export layout fields, and admin troubleshooting requirements are preserved.
- Follow-up dependency: Refactor workplan can now use this document as the schema and rules source of truth.
