---
stepsCompleted:
  - step-01-init
  - step-02-context
  - step-03-starter
  - step-04-decisions
  - step-05-patterns
  - step-06-structure
  - step-07-validation
  - step-08-complete
inputDocuments:
  - _bmad-output/planning-artifacts/prd.md
  - _bmad-output/planning-artifacts/prd-validation-report.md
  - _bmad-output/planning-artifacts/product-brief-RoomForge.md
  - _bmad-output/planning-artifacts/ux-design-specification.md
workflowType: "architecture"
lastStep: 8
status: "complete"
completedAt: "2026-05-07"
project_name: "RoomForge"
user_name: "Yoon"
date: "2026-05-07"
---

# Architecture Decision Document

_This document builds collaboratively through step-by-step discovery. Sections are appended as we work through each architectural decision together._

## Project Context Analysis

### Requirements Overview

**Functional Requirements:**
RoomForge has 50 functional requirements across user accounts, project management, room input, OpenCV-assisted reconstruction, reconstruction quality handling, 2D/3D furniture editing, persistence/export, admin operations, and support troubleshooting.

Architecturally, the system must support two major product surfaces:

- User-facing photo-to-room planning flow.
- Admin/support flow for CV job observability, artifact inspection, retry, and diagnosis.

The core domain flow is:
`Authenticated user -> room project -> source image -> OpenCV candidate geometry -> user-confirmed geometry -> metric calibration -> floor plan -> 3D scene -> furniture layout -> saved/exported layout`.

**Non-Functional Requirements:**
The strongest architecture drivers are:

- Oracle Cloud 1GB API server must stay lightweight.
- Heavy OpenCV, deep-learning, and GPU inference must not run on the lightweight API server.
- Firebase Google Auth is required for authentication.
- Oracle DB is the MVP application data store.
- Non-CV API p95 target is 1 second for core project/layout operations.
- 3D editor should sustain at least 30 FPS for MVP-scale scenes.
- Layout editing should update local state within 100 ms.
- Reconstruction job state must be observable and recoverable.
- User data and room images require authenticated and authorized API access.
- Core app shell/admin UI should target WCAG 2.2 AA, with best-effort accessible spatial canvas controls.

**Scale & Complexity:**
RoomForge is medium complexity. It is not enterprise-scale or regulated, but it combines several high-risk areas: Flutter web, Three.js spatial editing, OpenCV/manual-assisted reconstruction, Firebase Auth, Oracle DB persistence, admin observability, and optional future provider orchestration.

- Primary domain: Web-first full-stack application with applied computer vision and interactive 2D/3D editor.
- Complexity level: Medium.
- Estimated architectural components: Flutter web shell, Three.js editor, Firebase Hosting/Auth integration, lightweight Oracle API, Oracle DB schema, OpenCV/manual-assisted CV module, job/status model, admin console, export/persistence layer, optional future provider adapter.

### Technical Constraints & Dependencies

- Client deployment should use Firebase Hosting.
- Authentication should use Firebase Google Auth.
- Application data should be persisted in Oracle DB, not Firestore as the primary store.
- The Oracle Cloud 1GB server should handle API routing, auth verification, DB access, metadata, and result retrieval only.
- MVP should not require an external GPU server.
- OpenCV is mandatory as the visible computer vision term-project feature.
- The MVP provider should be OpenCV-assisted/manual-correction reconstruction.
- Optional GPU/deep-learning providers should be post-MVP and plug into the same job/result contract.
- The room model should be rectangular or simple polygonal for Phase 1.
- Three.js should own the spatial editor/canvas; Flutter should own app shell, forms, navigation, admin UI, and accessibility-heavy controls.
- Candidate geometry and user-confirmed geometry must remain separate in the data model.

### Cross-Cutting Concerns Identified

- Authentication and authorization across user projects, layouts, images, jobs, and admin operations.
- Data ownership and privacy for room images and layout records.
- Job lifecycle observability: created, processing, review_required, succeeded, failed, timeout, cancelled, retrying.
- Separation of lightweight API responsibilities from CV/GPU workloads.
- Traceability from source image to OpenCV result, corrected boundary, calibration, floor plan, layout, and admin event trail.
- Shared spatial state between Flutter controls and Three.js rendering.
- Recovery-first UX for bad photos, weak OpenCV candidates, invalid geometry, and calibration failure.
- Performance boundaries for local editor responsiveness and browser 3D rendering.
- Accessibility boundaries between standard Flutter UI and custom Three.js canvas interactions.
- Future extensibility for smartphone capture and optional provider-backed inference.

## Starter Template Evaluation

### Primary Technology Domain

RoomForge is a composite web-first full-stack application:

- Flutter web app shell.
- Embedded/custom Three.js spatial editor.
- Firebase Hosting and Firebase Google Auth.
- Lightweight Oracle API server.
- Oracle DB persistence.
- OpenCV-assisted/manual-correction CV workflow.
- Optional future provider adapter for GPU/deep-learning jobs.

Because the architecture combines Flutter, Three.js, Firebase Auth, Oracle DB, and OpenCV, no single mainstream full-stack starter fits the MVP cleanly.

### Starter Options Considered

#### Option 1: Official Flutter App Starter

Use the official Flutter CLI starter as the client foundation.

```bash
flutter create --empty app
```

This fits the MVP because Flutter is already the preferred app shell for web-first and future mobile support. Firebase Hosting can deploy Flutter web, and Firebase's Flutter web hosting docs support framework-aware hosting through the Firebase CLI.

**Pros:**

- Aligns with Flutter web-first and future mobile path.
- Minimal starting point avoids fighting a prebuilt app structure.
- Works naturally with Material 3 and Firebase Auth packages.

**Cons:**

- Does not solve Three.js integration by itself.
- Does not provide backend/API/database structure.

#### Option 2: Three.js + Vite Editor Package

Use a separate TypeScript/Vite package for the Three.js editor, embedded or integrated into the Flutter shell.

```bash
npm create vite@latest editor -- --template vanilla-ts
cd editor
npm install three
```

This fits because Three.js official docs recommend npm plus a build tool such as Vite for non-trivial projects.

**Pros:**

- Keeps spatial rendering code separate from Flutter UI concerns.
- Supports TypeScript, npm dependencies, and modern Three.js tooling.
- Good boundary for editor state, canvas rendering, and geometry interaction.

**Cons:**

- Requires a clear Flutter-to-editor integration contract.
- Adds a second frontend toolchain.

#### Option 3: Full Stack FastAPI Template

FastAPI's official full-stack template includes FastAPI, SQLModel, PostgreSQL, React, TypeScript, Vite, Tailwind, Docker Compose, Traefik, JWT auth, tests, and CI.

**Rejected for RoomForge MVP.**

It is too much and mismatched:

- Frontend is React, but RoomForge selected Flutter.
- Database is PostgreSQL, but MVP storage decision is Oracle DB.
- Auth is JWT/password based, but RoomForge requires Firebase Google Auth.
- Docker/Traefik/full-stack deployment is likely heavy for the Oracle 1GB app server goal.

#### Option 4: Custom Lightweight API Scaffold

Use a custom lightweight API scaffold instead of a full-stack template.

Recommended direction:

```bash
mkdir -p server/app/routers server/app/services server/app/repositories server/app/schemas
```

Use FastAPI-style modular routing or an equivalent lightweight framework, with Oracle DB access through a thin Oracle driver mode where possible.

**Pros:**

- Keeps Oracle 1GB server small.
- Lets the API focus only on auth verification, DB access, job metadata, layout persistence, and admin operations.
- Avoids React/PostgreSQL/JWT assumptions from full-stack templates.

**Cons:**

- Requires more architecture decisions in this document.
- Less prebuilt infrastructure than a full-stack template.

### Selected Starter: Custom Monorepo with Official Minimal Starters

**Rationale for Selection:**

RoomForge should use official minimal starters rather than a large opinionated full-stack starter.

Recommended repository foundation:

```text
roomforge/
  app/              # Flutter web/mobile shell
  editor/           # Three.js TypeScript spatial editor package
  server/           # Lightweight Oracle API
  packages/         # Shared schemas/tokens if needed
  docs/
```

**Initialization Commands:**

```bash
flutter create --empty app
npm create vite@latest editor -- --template vanilla-ts
cd editor
npm install three
mkdir -p ../server/app/routers ../server/app/services ../server/app/repositories ../server/app/schemas
```

Backend dependency/bootstrap command should be finalized in the architecture decisions step after choosing Python/FastAPI vs Node/Fastify/Express. Current preference is a lightweight API structure, not a full-stack backend template.

### Architectural Decisions Provided by Starter

**Language & Runtime:**

- Flutter/Dart for app shell.
- TypeScript for Three.js editor.
- Backend language still to be decided, with Python/FastAPI and Node/Fastify as likely candidates.

**Styling Solution:**

- Flutter Material 3 for app shell.
- Custom Three.js materials/overlay tokens for canvas.
- Shared visual token mapping between Flutter and editor.

**Build Tooling:**

- Flutter build for web/mobile shell.
- Vite build for Three.js editor package.
- Firebase Hosting for deployed web client.

**Testing Framework:**

- Flutter test for app shell.
- Vitest or Playwright can be added for editor behavior later.
- Backend tests depend on selected API framework.

**Code Organization:**

- Separate app, editor, and server boundaries.
- Candidate geometry and confirmed geometry remain separate in shared schemas.
- API server owns persistence and auth verification, not heavy CV/GPU execution.

**Development Experience:**

- Flutter hot reload for shell UI.
- Vite dev server for editor iteration.
- Lightweight server dev runner for API.
- First implementation story should initialize this monorepo structure.

### Verification Sources

- Flutter CLI supports creating apps with `flutter create`: https://docs.flutter.dev/reference/flutter-cli
- Flutter web supports Firebase Hosting deployment: https://docs.flutter.dev/deployment/web
- Firebase documents Flutter web integration through Firebase Hosting: https://firebase.google.com/docs/hosting/frameworks/flutter
- Three.js recommends npm plus a build tool such as Vite for non-trivial projects: https://threejs.org/manual/en/installation.html
- FastAPI full-stack template is React/PostgreSQL/JWT/Docker oriented and therefore mismatched for RoomForge's chosen stack: https://fastapi.tiangolo.com/project-generation/
- FastAPI supports modular API structure with `APIRouter`: https://fastapi.tiangolo.com/tutorial/bigger-applications/

## Core Architectural Decisions

### Decision Priority Analysis

**Critical Decisions:**

- Use a custom monorepo: `app/`, `editor/`, `server/`, optional `packages/`.
- Use Flutter web as app shell and Three.js as spatial editor.
- Run MVP OpenCV candidate extraction in the browser/editor layer with OpenCV.js/Web Worker, not on Oracle 1GB API server.
- Use Oracle DB as primary app data store.
- Use a lightweight Python FastAPI server for auth verification, API routing, Oracle DB access, metadata, layout persistence, and admin operations.
- Use Firebase Google Auth for user identity and Firebase Hosting for web deploy.
- Use REST + OpenAPI for client-server APIs.

**Important Decisions:**

- Store candidate geometry separately from user-confirmed geometry.
- Store layout/scene state as structured JSON plus relational metadata.
- Persist job/status transitions even when CV runs client-side, so admin/debug flows remain observable.
- Use a provider-adapter shape for future GPU/deep-learning workers, but do not require it for MVP.

**Deferred Decisions:**

- External GPU provider selection.
- Realtime job updates beyond polling.
- Object storage migration for large original images.
- Native smartphone capture implementation details.

### Data Architecture

Oracle DB is the system of record. Use relational tables for identity, ownership, jobs, statuses, and searchable admin fields. Use JSON columns for geometry, OpenCV candidate sets, calibration data, floor plans, editor scene, and furniture state.

Core entities:
`User`, `RoomProject`, `SourceImage`, `ReconstructionJob`, `JobStatusTransition`, `OpenCvResult`, `CorrectedBoundary`, `MetricCalibration`, `FloorPlan`, `Layout`, `FurnitureObject`, `AdminAction`, `RetryAttempt`.

For MVP image storage, use Oracle DB BLOB with strict upload size and downscaled processing limits. Store image metadata separately. If image volume grows, move binary assets to object storage later while preserving DB metadata references.

### Authentication & Security

Firebase Google Auth is the identity provider. Flutter obtains Firebase ID tokens and sends them to the Oracle API. The API verifies tokens using Firebase Admin SDK, maps Firebase UID to an Oracle `User`, and enforces ownership on every project, image, job, layout, and artifact request.

Admin access should require authenticated Firebase identity plus an Oracle-side role or allowlist. Admin actions should create `AdminAction` records.

### API & Communication Patterns

Use REST APIs with OpenAPI generated from FastAPI. API groups:

- `/auth/session`
- `/projects`
- `/source-images`
- `/reconstruction-jobs`
- `/opencv-results`
- `/geometry`
- `/layouts`
- `/exports`
- `/admin/jobs`
- `/admin/projects`
- `/admin/artifacts`

Use a consistent error envelope with categories:
`unauthenticated`, `unauthorized`, `validation_error`, `not_found`, `conflict`, `rate_limited`, `provider_unavailable`, `reconstruction_failed`, `calibration_failed`, `timeout`, `internal_error`.

### Frontend Architecture

Flutter owns app shell, routing, auth UI, project screens, upload forms, admin UI, status timelines, inspectors, dialogs, and accessibility-heavy controls.

Use Riverpod for app state and async API state. Use `go_router` for route/deep-link structure. Use Firebase Flutter packages for Auth/Core.

Three.js editor owns source-image canvas alignment, OpenCV overlays, geometry handles, 2D/3D rendering, camera behavior, furniture manipulation, and visual spatial state. The editor should expose a typed message boundary to Flutter:
`candidateGeometry`, `confirmedGeometry`, `calibration`, `floorPlan`, `scene`, `selection`, `viewMode`, `cameraPose`, `validation`.

### OpenCV / CV Execution

MVP OpenCV runs in the browser editor package, preferably inside a Web Worker to avoid freezing UI. Use OpenCV.js for Canny/edge detection, Hough/dominant line extraction, corner candidates, boundary suggestions, and visual overlays.

The server stores CV metadata/results but does not run heavy OpenCV. Client-generated candidate sets and overlay artifacts are persisted through the API so admin and evaluation flows can inspect them.

Future GPU/deep-learning providers must use the same `ReconstructionJob` and result contract.

### Infrastructure & Deployment

Firebase Hosting deploys the Flutter web client and bundled editor assets.

Oracle Cloud 1GB hosts the lightweight API process with a small worker count. The API should be stateless except for Oracle DB. Long-running provider work must use job status records, not blocking HTTP requests.

Use environment-based config:

- Firebase project/client config.
- API base URL.
- Oracle DB connection config.
- Admin allowlist/role config.
- Optional provider config.

### Decision Impact Analysis

Implementation sequence:

1. Initialize monorepo.
2. Build Firebase Auth + Oracle API token verification.
3. Create Oracle schema and migrations.
4. Implement project/layout CRUD.
5. Implement Three.js editor shell and Flutter bridge.
6. Implement OpenCV.js candidate extraction and correction flow.
7. Persist job/result/geometry/calibration/layout records.
8. Add admin job/artifact viewer.

Cross-component dependency:
The shared schema is the spine. Flutter, Three.js, FastAPI, and Oracle DB must agree on candidate geometry, confirmed geometry, calibration, floor plan, layout, and job status shapes.

### Verification Sources

- FastAPI latest package information: https://pypi.org/project/fastapi/
- Python Oracle driver package information: https://pypi.org/project/oracledb/
- OpenCV.js usage documentation: https://docs.opencv.org/4.x/d0/d84/tutorial_js_usage.html
- OpenCV.js build and WebAssembly documentation: https://docs.opencv.org/4.x/d4/da1/tutorial_js_setup.html
- Flutter SDK archive and stable-channel release guidance: https://docs.flutter.dev/install/archive
- Flutter package ecosystem references for Riverpod, go_router, and Firebase Flutter packages: https://pub.dev

## Implementation Patterns & Consistency Rules

### Pattern Categories Defined

**Critical Conflict Points Identified:**
The highest-risk conflict points are schema naming, API response shape, job status naming, geometry JSON shape, Flutter/Three.js message payloads, server layering, and error handling.

### Naming Patterns

**Database Naming Conventions:**

- Tables: `snake_case` plural nouns, e.g. `users`, `room_projects`, `source_images`, `reconstruction_jobs`.
- Columns: `snake_case`, e.g. `firebase_uid`, `project_id`, `created_at`.
- Primary keys: `id`.
- Foreign keys: `{entity_singular}_id`, e.g. `user_id`, `project_id`, `job_id`.
- Indexes: `idx_{table}_{columns}`, e.g. `idx_room_projects_user_id`.

**API Naming Conventions:**

- REST endpoints use plural kebab-case nouns: `/room-projects`, `/source-images`, `/reconstruction-jobs`.
- Path params use `{id}` and specific identifiers when ambiguous: `/room-projects/{project_id}`.
- Query params use `snake_case`: `status`, `created_after`, `user_id`.
- Headers use standard `Authorization: Bearer <firebase_id_token>`.

**Code Naming Conventions:**

- Dart files: `snake_case.dart`.
- Dart classes/providers/widgets: `PascalCase`.
- Dart variables/functions: `camelCase`.
- TypeScript files: `kebab-case.ts`.
- TypeScript types/classes: `PascalCase`.
- TypeScript variables/functions: `camelCase`.
- Python files/modules: `snake_case.py`.
- Python classes: `PascalCase`.
- Python functions/variables: `snake_case`.

### Structure Patterns

**Project Organization:**

- `app/` contains Flutter shell only.
- `editor/` contains Three.js/OpenCV.js spatial editor only.
- `server/` contains FastAPI server only.
- `packages/` contains shared schemas/tokens if needed.
- Do not put API calls inside Three.js rendering modules.
- Do not put canvas manipulation logic inside Flutter page widgets.

**Server Structure:**

- `routers/`: HTTP route definitions only.
- `schemas/`: Pydantic request/response models.
- `services/`: business logic and orchestration.
- `repositories/`: Oracle DB access.
- `auth/`: Firebase token verification and authorization helpers.
- `core/`: config, logging, errors.

**Frontend Structure:**

- Flutter feature folders should group screens, providers, models, and widgets by domain: auth, projects, upload, reconstruction, editor, layouts, admin.
- Three.js editor should separate rendering, geometry model, OpenCV worker, interaction tools, camera controls, and bridge messaging.

### Format Patterns

**API Response Formats:**
Use a consistent wrapper:

```json
{
  "data": {},
  "error": null,
  "meta": {
    "request_id": "req_..."
  }
}
```

For errors:

```json
{
  "data": null,
  "error": {
    "code": "validation_error",
    "message": "Geometry must have at least 3 corners.",
    "details": {}
  },
  "meta": {
    "request_id": "req_..."
  }
}
```

**Data Exchange Formats:**

- API JSON fields use `snake_case`.
- Flutter internal models may use `camelCase`, but serialization must map to API `snake_case`.
- TypeScript editor bridge messages use `camelCase`.
- Dates use ISO 8601 UTC strings.
- Geometry coordinates use meters after calibration and image pixels before calibration; fields must state coordinate space explicitly.

### Communication Patterns

**Flutter to Three.js Bridge:**
All bridge messages use:

```json
{
  "type": "geometry.updated",
  "version": 1,
  "payload": {},
  "requestId": "optional"
}
```

Message type format: `{domain}.{action}`, e.g. `candidate.selected`, `geometry.updated`, `calibration.validated`, `scene.updated`, `camera.changed`.

**Job Status Patterns:**
Allowed statuses:
`created`, `uploading`, `processing`, `review_required`, `succeeded`, `failed`, `timeout`, `cancelled`, `retrying`.

Do not invent parallel names like `needs_review`, `complete`, `error`, or `done` in persisted records.

### Process Patterns

**Error Handling Patterns:**

- Server raises typed application errors and maps them to the shared error envelope.
- Client shows user-facing recovery text, not raw stack traces.
- Admin views can expose technical code, provider, request ID, and metadata.
- OpenCV errors should preserve failure source: `input_quality`, `opencv_detection`, `geometry_validation`, `calibration`, `api`, `database`, `provider`.

**Loading State Patterns:**
Use explicit async states:
`idle`, `loading`, `success`, `empty`, `error`, `refreshing`.

For reconstruction jobs, use persisted job statuses instead of generic loading state.

**Validation Patterns:**

- Validate geometry before calibration.
- Validate calibration before 2D/3D generation.
- Validate layout before save/export.
- Do not silently coerce invalid geometry; return visible correction requirements.

### Enforcement Guidelines

**All AI Agents MUST:**

- Preserve candidate geometry and confirmed geometry as separate concepts.
- Use the shared job status vocabulary exactly.
- Use API `snake_case`, editor bridge `camelCase`, and database `snake_case`.
- Keep Oracle API server free of heavy CV/GPU processing.
- Put ownership checks in server service/repository paths before returning user data.
- Use the shared error envelope for all API errors.
- Include `request_id` or equivalent trace identifier in API responses/logs.

**Pattern Enforcement:**

- Shared schemas should be treated as contract files and changed deliberately.
- API route tests should verify response envelope and error envelope shape.
- Editor bridge tests should verify message type/version/payload shape.
- Database migrations should preserve naming conventions and foreign-key patterns.
- New job statuses require architecture/documentation updates before implementation.

### Pattern Examples

**Good Examples:**

- Database table: `reconstruction_jobs`.
- API endpoint: `GET /reconstruction-jobs/{job_id}`.
- API field: `confirmed_geometry`.
- Editor bridge field: `confirmedGeometry`.
- Job status: `review_required`.
- Error code: `calibration_failed`.

**Anti-Patterns:**

- Storing OpenCV candidates directly as final room geometry.
- Creating a second job status enum in Flutter or editor code.
- Returning raw DB rows directly from API routes.
- Running OpenCV processing inside the Oracle API server.
- Mixing Flutter widgets with Three.js rendering logic.
- Saving layouts without room dimensions, coordinate space, and furniture IDs.

## Project Structure & Boundaries

### Complete Project Directory Structure

```text
roomforge/
├── README.md
├── .gitignore
├── .env.example
├── firebase.json
├── .firebaserc
├── docs/
│   ├── architecture.md
│   └── api.md
├── app/
│   ├── pubspec.yaml
│   ├── lib/
│   │   ├── main.dart
│   │   ├── app.dart
│   │   ├── core/
│   │   │   ├── config/
│   │   │   ├── routing/
│   │   │   ├── theme/
│   │   │   ├── api/
│   │   │   └── errors/
│   │   ├── features/
│   │   │   ├── auth/
│   │   │   ├── projects/
│   │   │   ├── upload/
│   │   │   ├── reconstruction/
│   │   │   ├── editor/
│   │   │   ├── layouts/
│   │   │   └── admin/
│   │   └── shared/
│   │       ├── models/
│   │       ├── widgets/
│   │       └── providers/
│   ├── assets/
│   ├── web/
│   │   └── editor/
│   └── test/
├── editor/
│   ├── package.json
│   ├── vite.config.ts
│   ├── src/
│   │   ├── main.ts
│   │   ├── bridge/
│   │   ├── geometry/
│   │   ├── opencv/
│   │   │   ├── cv-worker.ts
│   │   │   └── detectors/
│   │   ├── rendering/
│   │   │   ├── scene/
│   │   │   ├── overlays/
│   │   │   └── materials/
│   │   ├── interaction/
│   │   ├── camera/
│   │   ├── furniture/
│   │   ├── state/
│   │   └── types/
│   └── tests/
├── server/
│   ├── pyproject.toml
│   ├── app/
│   │   ├── main.py
│   │   ├── core/
│   │   │   ├── config.py
│   │   │   ├── errors.py
│   │   │   └── logging.py
│   │   ├── auth/
│   │   │   ├── firebase.py
│   │   │   └── authorization.py
│   │   ├── routers/
│   │   │   ├── auth.py
│   │   │   ├── projects.py
│   │   │   ├── source_images.py
│   │   │   ├── reconstruction_jobs.py
│   │   │   ├── opencv_results.py
│   │   │   ├── geometry.py
│   │   │   ├── layouts.py
│   │   │   ├── exports.py
│   │   │   └── admin.py
│   │   ├── schemas/
│   │   ├── services/
│   │   ├── repositories/
│   │   └── db/
│   │       ├── oracle.py
│   │       └── migrations/
│   └── tests/
│       ├── unit/
│       └── integration/
└── packages/
    ├── schemas/
    └── design_tokens/
```

### Architectural Boundaries

**Flutter app boundary:**
Flutter owns routes, auth state, project screens, upload UI, reconstruction workflow UI, inspector panels, admin UI, and accessible controls. It must not implement low-level Three.js rendering or OpenCV detector internals.

**Three.js editor boundary:**
The editor owns canvas rendering, OpenCV overlays, geometry handles, 2D/3D scene rendering, furniture manipulation, camera controls, and Flutter bridge messages. It must not call Oracle API directly.

**Server boundary:**
FastAPI owns token verification, authorization, REST endpoints, Oracle DB access, status records, layout persistence, admin lookup, and export responses. It must not run heavy OpenCV or GPU inference.

**Database boundary:**
Oracle DB stores durable application state: users, projects, source image metadata/blob, reconstruction jobs, status transitions, OpenCV result JSON, confirmed geometry, calibration, floor plans, layouts, furniture objects, admin actions, and retry attempts.

### Requirements to Structure Mapping

- FR1-FR4 Auth/Admin Access: `app/lib/features/auth`, `server/app/auth`, `server/app/routers/auth.py`, `server/app/routers/admin.py`.
- FR5-FR9 Project Management: `app/lib/features/projects`, `server/app/routers/projects.py`.
- FR10-FR14 Room Input: `app/lib/features/upload`, `server/app/routers/source_images.py`.
- FR15-FR28 Reconstruction/OpenCV: `app/lib/features/reconstruction`, `editor/src/opencv`, `editor/src/geometry`, `server/app/routers/reconstruction_jobs.py`, `server/app/routers/opencv_results.py`.
- FR29-FR36 3D/Furniture Editing: `app/lib/features/editor`, `editor/src/rendering`, `editor/src/furniture`, `editor/src/interaction`.
- FR37-FR40 Persistence/Export: `app/lib/features/layouts`, `server/app/routers/layouts.py`, `server/app/routers/exports.py`.
- FR41-FR50 Admin/Support: `app/lib/features/admin`, `server/app/routers/admin.py`, `server/app/services/admin_service.py`.

### Integration Points

**Internal Communication:**

- Flutter to server: REST over HTTPS with Firebase ID token.
- Flutter to editor: typed browser message bridge.
- Editor to Flutter: typed event bridge with `type`, `version`, `payload`, `requestId`.
- Server to Oracle DB: repository layer only.

**External Integrations:**

- Firebase Hosting for client deploy.
- Firebase Auth for Google sign-in.
- Firebase Admin SDK for token verification.
- Oracle DB through `python-oracledb`.
- Optional future provider through reconstruction job contract.

**Data Flow:**
`Upload photo -> SourceImage record -> Editor/OpenCV candidate extraction -> OpenCvResult persisted -> CorrectedBoundary persisted -> MetricCalibration persisted -> FloorPlan generated -> Layout saved -> Admin/event trail available`.

### File Organization Patterns

**Configuration Files:**

- Root `.env.example` documents shared env names.
- `app/` owns Flutter and Firebase client config.
- `editor/` owns Vite and editor build config.
- `server/` owns Oracle/Firebase Admin/API env config.

**Source Organization:**

- Keep user-facing Flutter features under `app/lib/features`.
- Keep Flutter cross-cutting code under `app/lib/core` and reusable widgets/models under `app/lib/shared`.
- Keep editor rendering and CV code in `editor/src`, separated by rendering, geometry, OpenCV, interaction, camera, furniture, bridge, and state.
- Keep server HTTP, schema, service, repository, auth, and DB responsibilities separated.

**Test Organization:**

- Flutter widget/provider tests in `app/test`.
- Editor unit/interaction tests in `editor/tests`.
- Server unit and integration tests in `server/tests`.

**Asset Organization:**

- Flutter assets live in `app/assets`.
- Built editor assets are copied or published into `app/web/editor`.
- User-uploaded images are not committed; they live in Oracle DB for MVP.

### Development Workflow Integration

Development should allow three independent loops:

- Flutter shell loop: `app/`.
- Editor loop: `editor/`.
- API loop: `server/`.

The integration story should later add scripts for building editor assets and making them available to Flutter web. Deployment should build Flutter web with editor assets included, then deploy through Firebase Hosting. Server deployment remains separate on Oracle Cloud.

## Architecture Validation Results

### Coherence Validation

**Decision Compatibility:**
The major decisions are coherent: Flutter owns app UX, Three.js owns spatial rendering, OpenCV.js runs client-side for MVP, FastAPI/Oracle stores and serves durable data, Firebase handles auth/hosting, and optional GPU providers remain post-MVP through the job/result contract.

There is no direct contradiction with the Oracle 1GB constraint because heavy OpenCV/GPU work is excluded from the API server.

**Pattern Consistency:**
Naming, API response wrappers, job status vocabulary, bridge message format, and server layering support the chosen architecture. The most important consistency rule, separating `candidateGeometry` from `confirmedGeometry`, is documented across UX, architecture decisions, and implementation patterns.

**Structure Alignment:**
The proposed `app/`, `editor/`, and `server/` split matches the architectural boundaries. Requirement categories are mapped to concrete directories.

### Requirements Coverage Validation

**Functional Requirements Coverage:**
All FR categories have architectural support:

- Auth/project/admin: Flutter features + FastAPI auth/admin routers.
- Upload/source metadata: Flutter upload + source image router/repository.
- OpenCV reconstruction: Three.js/OpenCV.js editor + persisted job/result metadata.
- Geometry correction/calibration: editor geometry modules + server persistence.
- 2D/3D/furniture editing: editor rendering/furniture modules + Flutter inspector.
- Save/load/export: layout/export routers + Oracle DB.
- Admin/support: admin feature + job/artifact/status records.

**Non-Functional Requirements Coverage:**

- Performance: local editor state and Three.js rendering are client-side; API avoids CV workload.
- Security: Firebase token verification and Oracle-side ownership checks are required.
- Reliability: job statuses and transitions are persisted.
- Cost/resource efficiency: Oracle 1GB server avoids heavy CV/GPU.
- Data integrity: schema rules preserve source image, geometry, calibration, floor plan, layout, and furniture state.
- Accessibility: Flutter owns WCAG 2.2 AA non-canvas controls; canvas has best-effort accessible controls and non-color-only state.

### Implementation Readiness Validation

**Decision Completeness:**
The architecture is ready to drive epics/stories. The backend framework, client/editor split, auth model, DB strategy, API style, job model, and deployment split are documented.

**Structure Completeness:**
The directory structure is specific enough for agents to create the initial monorepo and place features consistently.

**Pattern Completeness:**
Naming, API format, bridge messages, job statuses, error handling, loading states, validation order, and anti-patterns are documented.

### Gap Analysis Results

**Critical Gaps:**
None.

**Important Gaps:**

- Exact Oracle DDL/schema is not yet defined. This should be handled in epics/stories or a database design artifact.
- Exact Flutter-to-Three.js embedding technique is not fully specified. Options include iframe/webview-like embedding or JS interop/web element integration; this should be decided during implementation spike/story.
- OpenCV.js packaging/build strategy needs a technical spike because WebAssembly loading and worker bundling can be fiddly.
- Image size limits and BLOB retention policy should be made explicit before deployment.

**Nice-to-Have Gaps:**

- CI/CD workflow details.
- API endpoint request/response examples.
- Shared schema package code generation strategy.
- Admin analytics/provider cost UI for post-MVP providers.

### Validation Issues Addressed

No critical validation issues were found. Minor gaps are explicitly carried forward as implementation-planning items rather than blockers.

### Architecture Completeness Checklist

**Requirements Analysis**

- [x] Project context thoroughly analyzed
- [x] Scale and complexity assessed
- [x] Technical constraints identified
- [x] Cross-cutting concerns mapped

**Architectural Decisions**

- [x] Critical decisions documented with versions/sources where relevant
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

**Overall Status:** READY WITH MINOR GAPS

Reason: no critical blockers remain, but the Oracle schema, Flutter/Three.js embedding detail, OpenCV.js worker packaging, and image retention limits should be clarified during implementation planning.

**Confidence Level:** Medium-high

**Key Strengths:**

- Strong separation between lightweight API and CV/editor workload.
- Clear OpenCV term-project path without GPU dependency.
- Explicit candidate vs confirmed geometry boundary.
- Good admin observability model.
- Practical monorepo structure for multiple agents.

**Areas for Future Enhancement:**

- Optional GPU provider architecture.
- Object storage for images.
- Realtime updates.
- Smartphone capture.
- CI/CD and deployment hardening.

### Implementation Handoff

**AI Agent Guidelines:**

- Follow the documented `app/`, `editor/`, `server/` boundaries.
- Do not run heavy CV/GPU workloads on the Oracle API server.
- Preserve shared job status vocabulary.
- Keep candidate geometry and confirmed geometry separate.
- Use REST/OpenAPI and the shared API envelope.
- Enforce Firebase-authenticated ownership checks before returning user data.

**First Implementation Priority:**
Initialize the monorepo with minimal official starters: `flutter create --empty app`, `npm create vite@latest editor -- --template vanilla-ts`, and `server/` FastAPI scaffold.
