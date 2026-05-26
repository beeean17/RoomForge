---
title: "RoomForge Firebase Target Architecture"
status: "complete"
created: "2026-05-24"
updated: "2026-05-24"
completedAt: "2026-05-24"
workflowType: "architecture"
stepsCompleted:
  - "step-01-init"
  - "step-02-context"
  - "step-03-starter"
  - "step-04-decisions"
  - "step-05-patterns"
  - "step-06-structure"
  - "step-07-validation"
  - "step-08-complete"
lastStep: 8
inputDocuments:
  - "docs/refactor/firebase-backend-refactor-plan.md"
  - "docs/refactor/firebase-ux-design-specification.md"
  - "docs/product/product-brief-RoomForge.md"
  - "docs/product/prd.md"
  - "docs/product/ux-design-specification.md"
  - "docs/legacy/_bmad-output/planning-artifacts/architecture.md"
project_name: "RoomForge"
user_name: "Yoon"
date: "2026-05-24"
supersedesDefaultBackend:
  - "Legacy Oracle/FastAPI default application path"
reviewMode:
  reviewers:
    - "Architecture Reviewer A: data/security/operations consistency"
    - "Architecture Reviewer B: UX/handoff/AI-agent consistency"
  result: "APPROVE"
---

# Architecture Decision Document - RoomForge Firebase Refactor

This document is the target architecture for making Firebase the default RoomForge backend while preserving the product promise, UX behavior, and editor boundaries defined in the product and refactor artifacts.

The architecture replaces the legacy Oracle/FastAPI default path with Firebase Auth, Cloud Firestore, Cloud Storage for Firebase, Firebase Security Rules, and local IndexedDB draft/cache support. The existing `server/` code remains as legacy/reference code and may be used only behind an explicit `legacy_api` mode.

## Project Context Analysis

### Requirements Overview

**Functional Requirements:**

RoomForge has 50 functional requirements across user accounts, room project management, room input, OpenCV-assisted reconstruction, reconstruction quality handling, 2D/3D furniture editing, layout persistence/export, admin operations, and support troubleshooting.

The core domain flow remains:

```text
Authenticated user
-> room project
-> source image
-> OpenCV candidate geometry
-> user-confirmed geometry
-> metric calibration
-> floor plan
-> 2D/3D room editor
-> furniture layout
-> saved/exported layout
```

The Firebase refactor changes the persistence and authorization path, not the product scope. Users still create a room plan from a photo, dimensions, OpenCV candidate review, correction, calibration, furniture editing, save, load, and JSON export.

**Non-Functional Requirements:**

The strongest architecture drivers are:

- Every user-facing project, layout, image, job, geometry, result, and export operation must require authenticated identity and ownership.
- Admin capabilities require a role check distinct from normal user access.
- Room images and layout data must not be publicly readable.
- Heavy OpenCV, deep-learning, and GPU inference must not run on the lightweight legacy API server.
- MVP OpenCV candidate extraction runs in the browser/editor layer, preferably in a Web Worker.
- Candidate geometry and user-confirmed geometry must remain separate.
- Layout editing remains responsive in browser state while cloud persistence is explicit and recoverable.
- Reconstruction statuses must use the existing vocabulary exactly: `created`, `uploading`, `processing`, `review_required`, `succeeded`, `failed`, `timeout`, `cancelled`, `retrying`.
- User-facing copy must display `review_required` as `Needs review`.
- Save/load/export must preserve room dimensions, source metadata, floor plan, editor scene, and furniture state.
- Admin users must be able to inspect status, artifact availability, retry linkage, failure reason, and permission outcome.

**Scale & Complexity:**

RoomForge remains a medium-complexity web-first full-stack application with a rich spatial editor. The refactor removes the default custom backend from the critical path but adds Firestore document modeling, Storage object access, rules-enforced authorization, realtime streams, local draft recovery, and Firebase-backed admin diagnostics.

- Primary domain: Flutter web application with embedded Three.js/OpenCV.js editor and Firebase persistence.
- Complexity level: Medium.
- Estimated architectural components: Flutter app shell, Firebase Auth integration, Firestore repositories, Storage upload/artifact services, Security Rules, local IndexedDB draft/cache, Three.js editor bridge, OpenCV worker, admin console, export generator, legacy API adapter.

### Technical Constraints & Dependencies

- Flutter owns app routing, auth state, project screens, upload UI, reconstruction workflow UI, inspectors, admin UI, accessible controls, and Firebase API calls.
- Three.js owns source-image alignment, OpenCV overlays, geometry handles, 2D/3D rendering, camera behavior, furniture manipulation, and spatial validation.
- The editor package must not import Firebase SDKs or call Firestore/Storage directly.
- Firebase Auth is the identity provider.
- Firestore is the default system of record for MVP app data after this refactor.
- Cloud Storage stores source images and optional generated artifacts.
- Firebase Security Rules enforce ownership and admin authorization for default Firebase data access.
- IndexedDB stores local draft/cache state only; it is not the system of record.
- `server/` and Oracle migrations remain legacy/reference. They are not required for default validation unless `legacy_api` mode is intentionally touched.
- Firestore persisted fields use `snake_case`.
- Editor bridge fields use `camelCase`.
- Firestore document IDs are strings and replace legacy Oracle integer IDs in default app models.
- API envelope rules (`data`, `error`, `meta.request_id`) are legacy API rules only; direct Firebase SDK calls do not use that envelope.

### UX Delta Implications

The Firebase UX document adds architectural requirements that did not exist in the original Oracle/FastAPI architecture:

- Cloud save state must be visible as product language: `Saving`, `Saved`, `Unsaved draft`, `Sync failed`, `Retry available`.
- Firestore streams may update passive status surfaces, but must not overwrite active editor edits silently.
- If a local draft and cloud saved layout diverge, Flutter must present a restore/discard/continue choice.
- Cloud Storage upload requires validation, progress, metadata-save, failure, and retry states.
- Permission failures must be separated into signed out, project access removed, admin role required, artifact restricted, and data missing.
- Admin UX may expose IDs, artifact paths, role state, retry linkage, and permission outcomes; user UX must avoid Firebase implementation language.

### Cross-Cutting Concerns Identified

- Auth and ownership across Firestore documents and Storage objects.
- Admin role reads without creating data leaks or broad public rules.
- Rules-compatible Firestore queries, because Security Rules are not filters.
- Traceability from source image to OpenCV result, confirmed geometry, floor plan, layout, status transition, artifact, and admin action.
- Cloud-vs-draft conflict handling.
- Shared spatial state between Flutter and the editor bridge.
- Status vocabulary consistency across Firestore, Flutter, editor bridge, export JSON, and admin UI.
- Validation of uploaded file type/size both in Flutter UX and Storage Rules.
- Offline/refresh recovery without promising full offline-first operation.
- Migration from integer IDs to Firestore string IDs.

## Starter Template Evaluation

### Primary Technology Domain

RoomForge is an existing custom monorepo. The target foundation remains:

```text
RoomForge/
  app/       Flutter web/mobile app shell
  editor/    TypeScript + Vite + Three.js/OpenCV.js spatial editor
  server/    legacy FastAPI/Oracle reference path
  packages/  optional shared schemas/tokens
  docs/      product, refactor, architecture, workflow docs
```

No new React, Next.js, or server-side full-stack starter should be introduced.

### Current Foundation Verification

Current official references checked for this architecture:

- Flutter docs reflect Flutter 3.44.0 as of 2026-05-20.
- Vite official guide shows Vite v8 docs and `npm create vite@latest` with the `vanilla-ts` template.
- Firebase Flutter setup uses `firebase_core`, `flutterfire configure`, and product-specific FlutterFire plugins.
- Firebase Emulator Suite supports Auth, Firestore, Storage, and the Emulator UI for local development.
- Firestore and Storage Security Rules support authenticated, owner-scoped, role-aware, and file validation conditions.
- Three.js official docs recommend npm plus a build tool such as Vite for non-trivial projects.

### Starter Options Considered

#### Option 1: Continue Existing Flutter App

Use the existing `app/` Flutter project as the application shell.

**Keep.** The app already uses Flutter, Material 3, Firebase Auth, and environment-driven Firebase configuration. The refactor should add Firebase repository/services rather than scaffold a new app.

#### Option 2: Continue Existing Vite/Three.js Editor

Use the existing `editor/` TypeScript/Vite/Three.js package.

**Keep.** The editor already has `vite`, `three`, TypeScript, a bridge module, a spatial model module, and an OpenCV worker. The architecture should preserve this boundary and add bridge payloads rather than move persistence into the editor.

#### Option 3: Add Firebase Backend Starter

Use Firebase CLI initialization for Firestore, Storage, Hosting, and emulators.

**Adopt as configuration baseline, not as a new app starter.** Firebase config/rules/emulators should be added to the existing repo. The first implementation story should configure missing Firestore/Storage emulator and rules files.

Recommended command pattern:

```bash
firebase init firestore storage emulators hosting
```

Use non-interactive or manual config editing where it better preserves the existing repo.

#### Option 4: Keep FastAPI/Oracle Starter

Continue using `server/` FastAPI and Oracle migrations as the default path.

**Rejected for default path.** It contradicts the Firebase refactor plan. Keep as `legacy_api` only.

### Selected Foundation

Selected foundation:

```text
Existing Flutter app + existing Vite/Three.js editor + Firebase config/rules/emulators + legacy server isolation.
```

**Rationale for Selection:**

- It preserves the existing product implementation instead of forcing a rewrite.
- It aligns with the UX decision that Flutter owns persistence and accessible state.
- It keeps the editor focused on spatial rendering and OpenCV.
- It allows local Firebase validation with Auth, Firestore, Storage, and rules.
- It removes FastAPI/Oracle from the default app path without deleting recoverable reference code.

**Initialization and Setup Commands:**

```bash
cd app
flutter pub add cloud_firestore firebase_storage
flutterfire configure
firebase init firestore storage emulators hosting
```

Editor setup remains:

```bash
cd editor
npm install
npm run build
```

**Architectural Decisions Provided by Foundation:**

**Language & Runtime:**

- Flutter/Dart for app shell and Firebase client access.
- TypeScript for editor package.
- Python/FastAPI remains only in legacy server.

**Build Tooling:**

- Flutter web build for app shell.
- Vite build for editor package.
- Firebase CLI for Hosting, Firestore, Storage, rules, and emulators.

**Testing Foundation:**

- `flutter analyze` and `flutter test` for app.
- `npm run build` or `npm run test` for editor.
- Firebase emulator/rules tests for Auth/Firestore/Storage authorization.
- Legacy server tests only when `legacy_api` is touched.

## Core Architectural Decisions

### Decision Priority Analysis

**Critical Decisions (Block Implementation):**

- Firebase is the default backend for app data and artifacts.
- Flutter is the only Firebase persistence owner.
- Editor never imports Firebase SDKs.
- Firestore document IDs are strings.
- Persisted Firebase fields use `snake_case`.
- Editor bridge fields use `camelCase`.
- Candidate and confirmed geometry are separate collections and separate bridge concepts.
- Storage paths are owner-scoped under the authenticated UID.
- Admin role is stored in `users/{uid}.role` and enforced by Security Rules.
- `server/` is legacy-only unless `legacy_api` mode is explicitly enabled.

**Important Decisions (Shape Architecture):**

- Firestore streams replace 5-second API polling where practical.
- IndexedDB stores drafts/cache only.
- Upload writes Storage first, then Firestore metadata.
- Layout export is generated client-side from the latest saved Firestore layout.
- Admin retry creates a linked retry job document and an auditable admin action.
- Firestore rules must support every query shape used by app/admin repositories.

**Deferred Decisions (Post-MVP or Later Refactor):**

- Full offline-first collaboration and conflict merging.
- Cloud Functions or server-side CV processing.
- GPU/deep-learning provider orchestration.
- Public sharing or collaborator access.
- Automated Oracle-to-Firebase data migration.

### Data Architecture

Firestore is the system of record for default RoomForge data. Cloud Storage stores image/object bytes. IndexedDB stores local draft/cache state.

Recommended top-level and subcollection model:

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

Required ownership fields:

- Every `projects/{project_id}` document has `owner_uid`.
- Every subcollection document repeats `project_id` and `owner_uid` for query/rules/admin convenience.
- Admin-readable collection group queries must include fields needed for indexing, filtering, and redaction.

Required status vocabulary:

```text
created
uploading
processing
review_required
succeeded
failed
timeout
cancelled
retrying
```

The product label for `review_required` is `Needs review`.

Local draft/cache:

```text
IndexedDB database: roomforge_drafts
draft key: uid/project_id/layout_id_or_current
contains: editor_scene, furniture_objects, room_dimensions snapshot,
          floor_plan snapshot, source_metadata snapshot, updated_at,
          base_cloud_layout_id, base_cloud_updated_at, dirty_fields
```

IndexedDB data is recoverable local state, not authoritative cloud state.

### Storage Architecture

Cloud Storage path pattern:

```text
users/{uid}/projects/{project_id}/source-images/{source_image_id}/{filename}
users/{uid}/projects/{project_id}/artifacts/{job_id}/{artifact_id}/{filename}
```

Upload limits:

- Allowed content types: JPEG, PNG, WebP.
- Maximum source image size: 10 MB.
- Flutter validates type and size before upload.
- Storage Rules validate type and size where supported.
- Project-scoped Storage writes should correspond to an owned `projects/{project_id}` document where practical, using Firestore rule lookups, trusted upload metadata, or a data-contract-defined metadata handshake to reduce orphan uploads.
- Firestore metadata persists `storage_path`, `content_type`, `byte_size`, `sha256_hex`, `width_px`, `height_px`, `retention_status`, and upload timestamps.

Artifacts are private by default. Admin artifact access must be permission-scoped and must not make user images public.

### Authentication & Security

Firebase Auth is the identity provider. On sign-in, Flutter upserts:

```text
users/{uid}
  uid
  email
  display_name
  created_at
  updated_at
  last_seen_at
```

`users/{uid}.role` is privileged authorization state, not normal profile metadata. Authenticated clients must not create, update, or delete their own `role`; role assignment must happen only through a trusted bootstrap path, admin-only write, custom-claim sync, or an equivalent privileged function. Firestore Rules must explicitly protect the `role` field from self-service privilege escalation.

Security model:

- Auth is required for all user project data.
- Normal users can read/write only projects where `owner_uid == request.auth.uid`.
- Users cannot write their own `role`.
- Admin checks use `users/{request.auth.uid}.role == "admin"`.
- Admin reads are explicit and collection-group-compatible.
- Admin writes are limited to auditable actions such as retry job creation or support notes.
- Rules must validate allowed job statuses and immutable owner fields.
- Rules are not filters; Flutter repository queries must include owner/admin constraints that satisfy rules.

### API & Communication Patterns

Default app path uses Firebase SDK repositories, not HTTP APIs:

```text
Flutter repository -> Firebase Auth/Firestore/Storage SDK -> Security Rules -> Firebase services
```

Legacy path:

```text
Flutter legacy_api adapter -> FastAPI -> Oracle DB
```

The legacy adapter must be isolated behind an explicit config flag and must not be used by default validation.

Flutter/editor communication:

```text
Flutter -> editor iframe/custom element: initialization payload, room/project state, persistence state
editor -> Flutter: candidate geometry, confirmed geometry, calibration, scene updates, furniture changes, validation, status events
```

The editor emits spatial state; Flutter decides what to persist to Firebase.

### Frontend Architecture

Flutter app layers:

```text
lib/src/auth
lib/src/firebase
lib/src/projects
lib/src/upload
lib/src/reconstruction
lib/src/layouts
lib/src/editor
lib/src/admin
lib/src/drafts
lib/src/shared
lib/src/legacy_api
```

Repository interfaces should be domain-first:

- `AuthRepository`
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

Firebase implementations are default. Legacy HTTP implementations may live under `legacy_api`.

Editor package layers:

```text
editor/src/bridge.ts
editor/src/spatialModel.ts
editor/src/opencvWorker.ts
editor/src/rendering/
editor/src/geometry/
editor/src/furniture/
editor/src/validation/
editor/src/state/
```

The editor must not own cloud save, upload, auth, or admin logic.

### Infrastructure & Deployment

Default development:

- Firebase emulators for Auth, Firestore, Storage, and Emulator UI.
- Flutter app configured to use emulators in local mode.
- Editor built with Vite and served/included in Flutter web.
- Legacy server optional and off by default.

Default deployment:

- Firebase Hosting for Flutter web app and bundled editor assets.
- Firebase Auth, Firestore, Storage, and Security Rules for default backend.
- No default Oracle/FastAPI dependency.

Required config files:

```text
app/firebase.json
app/firestore.rules
app/storage.rules
app/firestore.indexes.json
app/lib/firebase_options.dart or env-driven equivalent
app/.env.example
```

### Decision Impact Analysis

**Implementation Sequence:**

1. Configure Firebase Firestore/Storage/emulators/rules baseline.
2. Add Flutter Firebase packages and Firebase repository abstractions.
3. Migrate auth user profile and admin role model.
4. Replace project CRUD HTTP repository with Firestore repository.
5. Replace image upload path with Storage plus Firestore metadata.
6. Persist reconstruction jobs, transitions, OpenCV results, confirmed geometry, and floor plans in Firestore.
7. Persist layouts and export from Firestore layout docs.
8. Add IndexedDB draft/cache and cloud/draft conflict handling.
9. Replace admin API with Firebase-backed admin repository and rules-compatible queries.
10. Isolate legacy API and update validation/docs.

**Cross-Component Dependencies:**

- Layout persistence depends on floor plan and confirmed geometry contracts.
- Export depends on latest saved layout plus reconstruction status.
- Admin diagnosis depends on jobs, transitions, artifacts, and permission outcomes.
- Draft recovery depends on layout document IDs and `updated_at` comparisons.
- Editor bridge stability depends on shared spatial model and ID/string migration.

## Implementation Patterns & Consistency Rules

### Pattern Categories Defined

Critical conflict points:

- ID types and field naming.
- Firestore collection paths.
- Storage path generation.
- Status vocabulary.
- Geometry coordinate spaces.
- Firebase repository boundaries.
- Draft-vs-cloud state handling.
- Admin role/rules patterns.
- Editor bridge payload shape.
- Legacy API isolation.

### Naming Patterns

**Firestore Naming Conventions:**

- Collection names use `snake_case` plurals: `source_images`, `reconstruction_jobs`, `confirmed_geometries`, `floor_plans`, `admin_actions`.
- Document fields use `snake_case`.
- Document IDs are strings and are referenced as `{entity}_id`.
- Timestamps use `created_at`, `updated_at`, `uploaded_at`, `completed_at`, `deleted_at`.
- Owner field is always `owner_uid`.

**Storage Naming Conventions:**

- Storage object paths are lowercase directory segments.
- Path must start with `users/{uid}/projects/{project_id}/`.
- Filenames should be sanitized and prefixed or nested by generated document ID.

**Code Naming Conventions:**

- Dart classes use `PascalCase`.
- Dart fields use `camelCase`.
- Firestore serializer/deserializer maps Dart `camelCase` to persisted `snake_case`.
- TypeScript bridge payloads use `camelCase`.
- Editor message types use `{domain}.{action}`, for example `geometry.updated`, `scene.changed`, `draft.stateRequested`.

### Structure Patterns

**Flutter Project Organization:**

- Domain repositories live with the domain feature.
- Shared Firebase helpers live under `app/lib/src/firebase/`.
- Legacy HTTP adapters live under `app/lib/src/legacy_api/`.
- UX components for persistence/recovery live under `app/lib/src/shared/persistence/`.
- Admin Firebase query helpers live under `app/lib/src/admin/`.

**Editor Project Organization:**

- Bridge type definitions are centralized in `editor/src/bridge.ts`.
- Spatial model types are centralized in `editor/src/spatialModel.ts` or split into `editor/src/state/` only when needed.
- OpenCV worker code remains in worker modules and never imports Firebase SDKs.
- Rendering modules consume spatial state only.

**Rules Organization:**

- Firestore rules and helper functions live in `app/firestore.rules`.
- Storage rules and helper functions live in `app/storage.rules`.
- Indexes live in `app/firestore.indexes.json`.
- Rules tests live in `app/test/firebase_rules/` or a clearly named equivalent.

### Format Patterns

**Firestore Document Format:**

All durable documents include:

```json
{
  "owner_uid": "firebase_uid",
  "created_at": "server_timestamp",
  "updated_at": "server_timestamp"
}
```

Domain documents include explicit IDs when needed by queries/export:

```json
{
  "project_id": "firestore_document_id",
  "layout_id": "firestore_document_id"
}
```

**Geometry Format:**

Every geometry payload declares coordinate space:

```json
{
  "coordinate_space": "image_pixels",
  "points": []
}
```

Allowed coordinate spaces:

- `image_pixels` before calibration.
- `meters` after calibration.

OpenCV candidate geometry and user-confirmed geometry must not be stored in the same document type.

**Layout Format:**

Saved layouts contain:

- `room_dimensions`
- `floor_plan`
- `source_metadata`
- `editor_scene`
- `furniture_objects`
- `reconstruction_status`
- `review_required`
- `schema_version`

**Legacy API Format:**

The `data` / `error` / `meta.request_id` envelope applies only to `legacy_api`. Do not wrap direct Firebase repository results in API envelopes.

### Communication Patterns

**Firestore Streams:**

- Use streams for project list, project detail, active reconstruction job, and admin status surfaces where practical.
- Do not use streams to replace active editor state without explicit draft/conflict handling.
- Repository streams should emit domain models, not raw Firestore maps.

**Editor Bridge:**

Bridge payloads use `camelCase` and string IDs.

Required high-level payload groups:

- `projectContext`
- `sourceImage`
- `candidateGeometry`
- `confirmedGeometry`
- `roomDimensions`
- `floorPlan`
- `layout`
- `furnitureObjects`
- `editorScene`
- `persistenceState`
- `selection`
- `validation`

Flutter may send persistence state to the editor for display placement, but Flutter owns save/load actions.

### Process Patterns

**Upload Process:**

1. Validate file type and size in Flutter.
2. Create or reserve source image ID.
3. Upload bytes to Storage path.
4. Write Firestore source image metadata.
5. Surface upload or metadata-save failures separately.

**Save Process:**

1. Editor emits scene/furniture change.
2. Flutter marks `Unsaved draft`.
3. DraftRepository persists local draft snapshot.
4. User saves or autosave logic triggers a Firestore layout write if implemented.
5. On success, Flutter shows `Saved` and clears matching draft.
6. On failure, Flutter shows `Sync failed` and preserves draft.

**Reconstruction Process:**

1. Flutter creates a `reconstruction_jobs` document.
2. Editor worker computes OpenCV candidates.
3. Flutter persists `opencv_results`.
4. User confirms/corrects geometry.
5. Flutter persists `confirmed_geometries` and `floor_plans`.
6. Flutter updates job status to `succeeded`, `review_required`, `failed`, `timeout`, `cancelled`, or `retrying`.
7. Transitions are recorded in the job `transitions` subcollection.

**Admin Retry Process:**

1. Admin verifies role through repository/rules.
2. Admin selects retry.
3. Flutter creates a new job with `retry_of_job_id`.
4. Flutter writes an `admin_actions` document.
5. Original job history remains unchanged.

### Enforcement Guidelines

All AI agents MUST:

- Keep Flutter as the only Firebase persistence owner.
- Keep editor free of Firebase SDK imports.
- Use Firestore string IDs in default models.
- Use `snake_case` for persisted Firebase/export fields.
- Use `camelCase` for editor bridge fields.
- Preserve candidate/confirmed geometry separation.
- Use the exact reconstruction status vocabulary.
- Preserve `review_required` as the persisted status and `Needs review` as the user-facing label.
- Place legacy HTTP/API code under `legacy_api` or clearly mark it as legacy.
- Add or update rules/tests when changing Firestore/Storage access patterns.

Anti-patterns:

- Importing Firebase SDKs in `editor/`.
- Storing Storage download URLs as public access guarantees.
- Relying on Firestore rules as query filters.
- Creating a persisted `needs_review`, `done`, `complete`, or `error` job status.
- Mixing local drafts with cloud-saved layouts without a visible state.
- Writing admin access as a normal user query with client-side filtering.
- Reintroducing FastAPI/Oracle as a default dependency.

## Project Structure & Boundaries

### Complete Project Directory Structure

```text
RoomForge/
├── app/
│   ├── firebase.json
│   ├── firestore.rules
│   ├── storage.rules
│   ├── firestore.indexes.json
│   ├── pubspec.yaml
│   ├── lib/
│   │   ├── main.dart
│   │   └── src/
│   │       ├── auth/
│   │       │   ├── auth_repository.dart
│   │       │   └── firebase_options_from_env.dart
│   │       ├── firebase/
│   │       │   ├── firebase_app_config.dart
│   │       │   ├── firestore_paths.dart
│   │       │   ├── firestore_serializers.dart
│   │       │   └── storage_paths.dart
│   │       ├── users/
│   │       │   ├── user_profile.dart
│   │       │   └── user_repository.dart
│   │       ├── projects/
│   │       │   ├── project_repository.dart
│   │       │   ├── firebase_project_repository.dart
│   │       │   └── models.dart
│   │       ├── upload/
│   │       │   ├── source_image_repository.dart
│   │       │   ├── firebase_source_image_repository.dart
│   │       │   └── upload_state.dart
│   │       ├── reconstruction/
│   │       │   ├── reconstruction_repository.dart
│   │       │   ├── firebase_reconstruction_repository.dart
│   │       │   ├── reconstruction_status.dart
│   │       │   └── job_transition.dart
│   │       ├── geometry/
│   │       │   ├── geometry_repository.dart
│   │       │   ├── candidate_geometry.dart
│   │       │   ├── confirmed_geometry.dart
│   │       │   └── floor_plan.dart
│   │       ├── layouts/
│   │       │   ├── layout_repository.dart
│   │       │   ├── firebase_layout_repository.dart
│   │       │   ├── layout_exporter.dart
│   │       │   └── saved_layout.dart
│   │       ├── drafts/
│   │       │   ├── draft_repository.dart
│   │       │   ├── indexed_db_draft_repository.dart
│   │       │   └── draft_conflict.dart
│   │       ├── editor/
│   │       │   ├── editor_bridge.dart
│   │       │   ├── editor_config.dart
│   │       │   └── editor_payloads.dart
│   │       ├── admin/
│   │       │   ├── admin_repository.dart
│   │       │   ├── firebase_admin_repository.dart
│   │       │   ├── admin_models.dart
│   │       │   └── admin_screens.dart
│   │       ├── legacy_api/
│   │       │   ├── legacy_project_api.dart
│   │       │   └── legacy_admin_api.dart
│   │       └── shared/
│   │           ├── persistence/
│   │           ├── errors/
│   │           ├── widgets/
│   │           └── validation/
│   └── test/
│       ├── repositories/
│       ├── firebase_rules/
│       └── widget/
├── editor/
│   ├── package.json
│   ├── vite.config.ts
│   ├── src/
│   │   ├── main.ts
│   │   ├── bridge.ts
│   │   ├── spatialModel.ts
│   │   ├── opencvWorker.ts
│   │   ├── rendering/
│   │   ├── geometry/
│   │   ├── furniture/
│   │   ├── state/
│   │   └── validation/
│   └── public/
│       └── opencv/
├── server/
│   ├── README.md
│   ├── app/
│   ├── migrations/
│   └── tests/
├── packages/
│   └── shared_schema/
├── docs/
│   ├── product/
│   ├── refactor/
│   │   ├── firebase-backend-refactor-plan.md
│   │   ├── firebase-ux-design-specification.md
│   │   ├── firebase-target-architecture.md
│   │   ├── firebase-data-contract.md
│   │   ├── firebase-refactor-workplan.md
│   │   ├── firebase-validation-plan.md
│   │   └── decisions/
│   └── legacy/
└── scripts/
```

### Architectural Boundaries

**Flutter Boundary:**

Flutter owns user interaction, Firebase access, upload/save/load/export orchestration, admin screens, draft recovery, route state, and accessible status surfaces.

Flutter must not implement low-level Three.js rendering or OpenCV detector internals.

**Editor Boundary:**

The editor owns spatial rendering, OpenCV overlays, geometry handles, furniture manipulation, camera controls, and bridge message emission.

The editor must not call Firebase, legacy APIs, or Storage directly.

**Firebase Boundary:**

Firebase services own durable default persistence and authorization:

- Auth: identity.
- Firestore: metadata, jobs, geometry, floor plans, layouts, admin actions.
- Storage: source images and artifacts.
- Security Rules: owner/admin authorization and basic validation.

**Legacy Server Boundary:**

`server/` is inactive by default. If used, it must be behind `legacy_api` configuration and preserve the old envelope and Oracle schema rules.

### Requirements to Structure Mapping

**FR1-FR4 User Accounts & Access:**

- `app/lib/src/auth`
- `app/lib/src/users`
- `app/lib/src/admin`
- `app/firestore.rules`

**FR5-FR9 Room Project Management:**

- `app/lib/src/projects`
- `projects/{project_id}`
- `app/test/repositories/project_repository_test.dart`

**FR10-FR14 Room Input & Capture Guidance:**

- `app/lib/src/upload`
- `projects/{project_id}/source_images`
- `users/{uid}/projects/{project_id}/source-images/...`
- `app/storage.rules`

**FR15-FR28 Reconstruction Workflow & Quality:**

- `app/lib/src/reconstruction`
- `app/lib/src/geometry`
- `editor/src/opencvWorker.ts`
- `editor/src/geometry`
- Firestore `reconstruction_jobs`, `transitions`, `opencv_results`, `confirmed_geometries`, `floor_plans`

**FR29-FR36 3D Room & Furniture Editing:**

- `editor/src/rendering`
- `editor/src/furniture`
- `editor/src/state`
- `app/lib/src/editor`

**FR37-FR40 Layout Persistence & Export:**

- `app/lib/src/layouts`
- `app/lib/src/drafts`
- Firestore `layouts`
- IndexedDB `roomforge_drafts`

**FR41-FR50 Admin Operations & Troubleshooting:**

- `app/lib/src/admin`
- Firestore collection group queries over jobs/results/layouts.
- `admin_actions` and job `transitions`.
- Storage artifact availability checks.

### Integration Points

**Internal Communication:**

- Flutter domain repositories expose typed Future/Stream APIs to screens and state controllers.
- Flutter/editor bridge uses structured `postMessage` or equivalent host bridge payloads.
- Editor emits events; Flutter persists only after validation and domain mapping.

**External Integrations:**

- Firebase Auth for Google sign-in.
- Firestore for durable documents and streams.
- Cloud Storage for source images and artifacts.
- Firebase Hosting for deployed app/editor assets.
- IndexedDB for local drafts.

**Data Flow:**

```text
Sign in
-> upsert users/{uid}
-> create/open projects/{project_id}
-> upload source image to Storage
-> write source_images metadata
-> create reconstruction job
-> editor worker emits candidates
-> persist opencv_results
-> persist confirmed_geometries
-> persist floor_plans
-> edit scene/furniture
-> save layout to Firestore
-> export JSON from saved layout
```

## Architecture Validation Results

### Coherence Validation

**Decision Compatibility:**

The decisions are compatible: Flutter owns Firebase persistence, the editor owns spatial computation/rendering, Firebase owns default data and authorization, and the legacy API is isolated. This removes the Oracle/FastAPI default dependency while preserving the existing app/editor split.

**Pattern Consistency:**

Naming and format patterns support the decision set. Firestore uses `snake_case`; Dart and TypeScript use idiomatic `camelCase`; editor bridge payloads use `camelCase`; export JSON can preserve existing `snake_case` product contracts.

**Structure Alignment:**

The project structure maps every product area to a clear module. It also separates Firebase repositories from legacy adapters, which is necessary for story-by-story refactor implementation.

### Requirements Coverage Validation

**Functional Requirements Coverage:**

- FR1-FR4 are covered by Firebase Auth, `users/{uid}`, role fields, and admin rules.
- FR5-FR9 are covered by Firestore projects.
- FR10-FR14 are covered by Storage uploads and source image metadata.
- FR15-FR28 are covered by jobs, transitions, OpenCV results, confirmed geometry, and floor plans.
- FR29-FR36 remain editor-owned.
- FR37-FR40 are covered by Firestore layouts and client export.
- FR41-FR50 are covered by admin repositories, collection group queries, transitions, artifacts, and admin actions.

**Non-Functional Requirements Coverage:**

- Security NFRs are covered by Auth, owner fields, Security Rules, and admin role checks.
- Reliability and recoverability are covered by persisted statuses, transitions, retry linkage, local drafts, and explicit failure states.
- Performance is supported by local editor state, browser OpenCV worker, Firebase streams, and avoiding blocking API calls.
- Data integrity is supported by schema versioning, ID/string migration, coordinate-space declarations, and save/load/export contracts.
- Accessibility/UX is supported by Flutter-owned status controls, recovery surfaces, and non-color-only state requirements.

### Implementation Readiness Validation

**Decision Completeness:**

All critical implementation-blocking decisions are documented. The next document should define the precise Firebase data contract, including field-level schemas, indexes, and rules examples.

**Structure Completeness:**

The directory tree is complete enough for story generation. Existing files may be incrementally moved or wrapped rather than renamed all at once.

**Pattern Completeness:**

The most likely AI-agent conflict points are addressed: Firebase ownership, editor no-SDK rule, ID strings, naming, status vocabulary, geometry separation, draft/cloud state, and legacy isolation.

### Gap Analysis Results

**Critical Gaps: None.**

**Important Gaps:**

- Field-level Firestore schema and indexes need a dedicated data contract.
- Security Rules examples need to be specified and tested in validation planning.
- IndexedDB draft schema needs implementation-level detail before feature migration beyond the Firebase baseline.
- Admin Storage artifact access needs exact rule/query pattern.

**Minor Gaps:**

- The exact Flutter state management library is not fixed. Existing simple state can continue; a later story may introduce Riverpod or another pattern only if the app complexity demands it.
- The exact editor embedding mechanism should be documented from current implementation before large changes.

### Architecture Completeness Checklist

**Requirements Analysis**

- [x] Project context thoroughly analyzed
- [x] Scale and complexity assessed
- [x] Technical constraints identified
- [x] Cross-cutting concerns mapped

**Architectural Decisions**

- [x] Critical decisions documented with versions or current official reference points
- [x] Technology stack fully specified
- [x] Integration patterns defined
- [x] Performance considerations addressed

**Implementation Patterns**

- [x] Naming conventions established
- [x] Structure patterns defined
- [x] Communication patterns specified
- [x] Process patterns documented

**Project Structure**

- [x] Complete directory structure defined
- [x] Component boundaries established
- [x] Integration points mapped
- [x] Requirements to structure mapping complete

### Architecture Readiness Assessment

**Overall Status:** READY FOR FIREBASE BASELINE; DATA CONTRACT REQUIRED BEFORE FEATURE MIGRATION

**Confidence Level:** High for Firebase baseline planning and epic/story generation. Medium for feature migration until field-level schemas, Storage admin access, indexes, and draft conflict schema are resolved in follow-up documents.

**Key Strengths:**

- Clear Firebase default backend decision.
- Clear Flutter/editor/Firebase/legacy boundaries.
- UX delta requirements are reflected in persistence, draft, permission, and admin decisions.
- AI-agent consistency rules address likely implementation drift.
- Requirements map cleanly to modules and Firebase data areas.

**Areas for Future Enhancement:**

- Add complete field-level schemas in `firebase-data-contract.md`.
- Add rules test cases in `firebase-validation-plan.md`.
- Add ADR for Firebase as default backend.
- Add refactor workplan with FB-1 through FB-n story order.

### Implementation Handoff

AI agents implementing this architecture should:

- Start with Firebase config, emulators, rules, and repository boundaries.
- Do not implement feature work directly against legacy FastAPI/Oracle.
- Keep the editor Firebase-free.
- Use local drafts to protect work before cloud save.
- Validate every Firestore/Storage access pattern against ownership/admin rules.
- Generate stories from this document plus the Firebase UX spec and the upcoming data contract.

Recommended next planning documents:

1. `docs/refactor/firebase-data-contract.md`
2. `docs/refactor/firebase-refactor-workplan.md`
3. `docs/refactor/firebase-validation-plan.md`
4. `docs/refactor/decisions/0001-firebase-default-backend.md`

## Review Record

### Step 2 - Project Context Analysis

- Reviewer A: APPROVE. No blocker or major issue. Context captures backend shift, security, ownership, and data integrity.
- Reviewer B: APPROVE. No blocker or major issue. UX delta is reflected through cloud state, draft recovery, permission states, and admin diagnosis.

### Step 3 - Starter Template Evaluation

- Reviewer A: APPROVE. No blocker or major issue. Existing app/editor foundation plus Firebase config is the least disruptive path.
- Reviewer B: APPROVE. No blocker or major issue. Avoiding a new app starter protects implementation handoff consistency.

### Step 4 - Core Architectural Decisions

- Reviewer A: APPROVE. No blocker or major issue. Critical decisions are sufficient for security and data modeling direction.
- Reviewer B: APPROVE. No blocker or major issue. Decisions preserve UX language and prevent editor/Firebase coupling.

### Step 5 - Implementation Patterns

- Reviewer A: APPROVE. No blocker or major issue. Naming, status, rules, Storage, and geometry patterns are explicit.
- Reviewer B: APPROVE. No blocker or major issue. AI-agent consistency risks are called out with enforceable rules.

### Step 6 - Project Structure & Boundaries

- Reviewer A: APPROVE. No blocker or major issue. Structure cleanly separates Firebase repositories, drafts, admin, editor, and legacy API.
- Reviewer B: APPROVE. No blocker or major issue. Structure is adequate for implementation story generation.

### Step 7 - Architecture Validation

- Reviewer A: APPROVE. No blocker or major issue. Remaining gaps belong in data contract and validation plan, not this architecture.
- Reviewer B: APPROVE. No blocker or major issue. Architecture is ready for Firebase refactor epic/story creation after data contract.

### Final Peer Debate Round

- Reviewer A initially requested changes for `users/{uid}.role` privilege boundaries, Storage orphan mitigation, and readiness wording.
- Reviewer B agreed the UX/handoff direction was acceptable if the data contract followed next.
- After revision, Reviewer A: APPROVE. No blocker or major issue remains.
- After revision, Reviewer B: APPROVE. Volta's security concerns are resolved and UX/handoff is ready for the data contract/workplan stage.

## References

- Flutter SDK archive: https://docs.flutter.dev/install/archive
- Firebase Flutter setup: https://firebase.google.com/docs/flutter/setup
- Firebase Local Emulator Suite: https://firebase.google.com/docs/emulator-suite/install_and_configure
- Firestore Security Rules conditions: https://firebase.google.com/docs/firestore/security/rules-conditions
- Firestore Security Rules query behavior: https://firebase.google.com/docs/firestore/security/rules-query
- Cloud Storage Security Rules conditions: https://firebase.google.com/docs/storage/security/rules-conditions
- Vite getting started guide: https://vite.dev/guide/
- Three.js installation guide: https://threejs.org/manual/en/installation.html
