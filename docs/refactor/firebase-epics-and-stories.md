---
title: "RoomForge Firebase Epics and Stories"
status: "complete"
created: "2026-05-24"
updated: "2026-05-24"
completedAt: "2026-05-24"
workflowType: "epics-and-stories"
stepsCompleted:
  - "step-01-validate-prerequisites"
  - "step-02-design-epics"
  - "step-03-create-stories"
  - "step-04-parent-validation"
lastStep: 4
inputDocuments:
  - "docs/refactor/firebase-validation-plan.md"
  - "docs/refactor/firebase-refactor-workplan.md"
  - "docs/refactor/firebase-data-contract.md"
  - "docs/refactor/firebase-target-architecture.md"
  - "docs/refactor/firebase-ux-design-specification.md"
  - "docs/refactor/firebase-backend-refactor-plan.md"
  - "docs/product/prd.md"
project_name: "RoomForge"
user_name: "Yoon"
date: "2026-05-24"
parentWorkflow:
  - "firebase-refactor"
  - "bmad-create-epics-and-stories"
reviewState: "parent-validation-complete"
---

# Firebase Epics and Stories - RoomForge Refactor

This artifact decomposes the Firebase refactor into implementation epics and actionable planning-level stories. It is not the stale product story queue and does not replace existing product requirements. It translates the Firebase validation plan, workplan, data contract, architecture, UX specification, backend refactor plan, and PRD into a dependency-ordered backlog for developer agents.

The backlog preserves the required order:

1. Firebase baseline.
2. Data contract models.
3. Auth and role handling.
4. Project and upload migration.
5. Reconstruction persistence.
6. Layout save/load/export.
7. Draft/cache recovery.
8. Admin diagnostics.
9. Legacy cutover and isolation.
10. Readiness and documentation gate.

## Backlog Invariants

Every implementation story derived from this artifact must preserve these invariants:

- Flutter owns Firebase Auth, Firestore, Storage, repository access, upload, save, load, export, draft recovery, and admin repository access.
- The Three.js/OpenCV editor must not import Firebase SDKs or call Firestore, Storage, Auth, or Firebase config directly.
- The legacy FastAPI/Oracle server remains only behind explicit `legacy_api` mode.
- Firestore persisted fields and export JSON use `snake_case`.
- Dart model fields and editor bridge payloads use `camelCase`.
- Candidate geometry and user-confirmed geometry remain separate.
- Geometry payloads state coordinate space: `image_pixels` before calibration and `meters` after calibration.
- Persisted reconstruction statuses are exactly `created`, `uploading`, `processing`, `review_required`, `succeeded`, `failed`, `timeout`, `cancelled`, and `retrying`.
- Persisted `review_required` displays to users as `Needs review`.
- Persisted statuses must not include `needs_review`, `done`, `complete`, or `error`.
- `users/{uid}.role` is privileged authorization state; normal authenticated clients must not create, update, overwrite, or delete it.
- All user-facing project, image, job, result, geometry, layout, export, and artifact access requires authenticated identity and ownership.
- Admin access requires a distinct admin authorization check and rules-backed enforcement.

## Epic List

### Epic 1: Firebase Local Safety Baseline

**Goal:** Developers can run RoomForge against a local Firebase baseline with deny-by-default rules and an explicit default backend mode.

**Business/User Value:** The team can migrate features without weakening privacy, breaking local development, or accidentally keeping the legacy API as the default path.

**Source FB packages:** FB-1.

**Prerequisites:** Completed Firebase architecture, data contract, workplan, and validation plan.

**Validation Theme:** Firebase emulators, deny-by-default Firestore and Storage rules, smoke rules tests, explicit `firebase` default and `legacy_api` fallback.

### Epic 2: Contracted Models, Serializers, and Repository Boundaries

**Goal:** Developers can encode Firestore, export, Dart, and editor bridge contracts before feature writes begin.

**Business/User Value:** Later feature stories can save and load data consistently without inventing schemas story by story.

**Source FB packages:** FB-2.

**Prerequisites:** Epic 1.

**Validation Theme:** Model and serializer tests, `snake_case` and `camelCase` mapping, status and coordinate validators, editor forbidden import checks.

### Epic 3: Secure Auth, Profile Projection, and Admin Role Guard

**Goal:** Users can sign in with Google while admin role state remains privileged and protected from self-service escalation.

**Business/User Value:** Normal users get secure access to their own data, and future admin diagnostics can rely on rules-backed role handling.

**Source FB packages:** FB-3.

**Prerequisites:** Epics 1 and 2.

**Validation Theme:** Firebase Auth profile projection, role preservation, self-role write denial, non-admin denial, admin route guard baseline.

### Epic 4: Project, Room Dimensions, and Source Image Upload

**Goal:** Users can create owned projects, enter metric room dimensions, and upload source images through Firebase.

**Business/User Value:** The first user-visible default Firebase flow replaces legacy project and upload dependencies.

**Source FB packages:** FB-4.

**Prerequisites:** Epics 1 through 3.

**Validation Theme:** Owner-only project access, immutable ownership, Storage type/size/path rules, source image metadata persistence, upload recovery UX.

### Epic 5: Reconstruction State, Geometry, and Floor Plan Persistence

**Goal:** Users can persist reconstruction jobs, OpenCV candidates, confirmed geometry, and metric floor plans in Firebase.

**Business/User Value:** Reconstruction continuity works without the legacy backend while preserving quality, retry, and review behavior.

**Source FB packages:** FB-5.

**Prerequisites:** Epic 4.

**Validation Theme:** Exact job statuses, transition records, candidate/confirmed separation, coordinate-space rules, editor boundary checks, `Needs review` behavior.

### Epic 6: Cloud Layout Save, Load, and JSON Export

**Goal:** Users can save, reload, and export room layouts from Firestore using the contracted layout schema.

**Business/User Value:** The core room-planning workflow becomes durable through Firebase and exportable without legacy API dependency.

**Source FB packages:** FB-6.

**Prerequisites:** Epic 5.

**Validation Theme:** Layout round trip, export `snake_case`, bridge `camelCase`, latest saved layout export source, `Needs review` warning.

### Epic 7: Local Draft Recovery and Cloud Conflict Handling

**Goal:** Users can recover unsaved local work and resolve cloud/local layout conflicts after Firebase layout save/load exists.

**Business/User Value:** The refactor protects user work without claiming full offline-first collaboration.

**Source FB packages:** FB-7.

**Prerequisites:** Epic 6.

**Validation Theme:** IndexedDB draft/cache behavior, conflict detection, restore/discard flows, no silent overwrite, accessibility.

### Epic 8: Firebase-Backed Admin Diagnostics and Retry

**Goal:** Admin/support users can diagnose Firebase jobs, artifacts, layouts, and retry history after user data exists.

**Business/User Value:** Operational support remains possible after the legacy admin API is no longer the default path.

**Source FB packages:** FB-8.

**Prerequisites:** Epics 3, 5, and 6.

**Validation Theme:** Admin/non-admin rules tests, collection group indexes, artifact access states, append-only `admin_actions`, audited retry.

### Epic 9: Firebase Default Cutover and Legacy API Isolation

**Goal:** Firebase becomes the default application path while legacy FastAPI/Oracle remains explicit and non-default.

**Business/User Value:** The product can operate through Firebase without deleting useful legacy reference code prematurely.

**Source FB packages:** FB-9.

**Prerequisites:** Epics 3 through 8 enough to support default feature flows.

**Validation Theme:** Default backend selection, no hidden `ProjectApi` or `AdminApi` default use, documentation language, legacy-only mode.

### Epic 10: Validation, Documentation, and Readiness Gate

**Goal:** The Firebase refactor backlog, tests, documentation, and readiness inputs are traceable before implementation begins.

**Business/User Value:** Developer agents can execute stories in order with clear validation gates and without re-opening schema, rules, or UX fundamentals.

**Source FB packages:** FB-10.

**Prerequisites:** Epics 1 through 9 planning coverage.

**Validation Theme:** Traceability review, command/runbook validation, invariant checks, readiness input preparation. This epic does not create the implementation readiness report; that remains the next workflow.

## Stories

## Epic 1: Firebase Local Safety Baseline

### Story 1.1: Configure Firebase Emulators and Project Baseline

**Story ID:** FES-1.1

As a developer agent, I want local Firebase configuration for Auth, Firestore, Storage, Hosting, and Emulator UI, so that Firebase can become the default backend path safely.

**Scope:**

- Add or verify `firebase.json`, `.firebaserc`, Firestore rules, Storage rules, Firestore indexes, and emulator ports.
- Document required local environment variables and the explicit default backend mode name `firebase`.
- Keep the existing app, editor, and server directories intact.

**Acceptance Criteria:**

- Given a clean local workspace, when the documented emulator command runs, then Auth, Firestore, Storage, and Emulator UI are configured for local use.
- Given default backend configuration, when the app starts in development, then the intended default backend mode is `firebase`.
- Given legacy backend configuration, when `legacy_api` is selected explicitly, then it is documented as legacy-only and optional.
- Given this story is complete, when source files are reviewed, then no feature migration or legacy server deletion has been introduced.

**Validation Criteria:**

- FB-1 minimum go criteria from `firebase-validation-plan.md`.
- Smoke equivalent of unauthenticated Firestore denial and Storage denial.
- Firebase emulator startup command is documented.
- Flutter config still builds or analyzes after Firebase config changes where app config is touched.

**Source Documents:** `firebase-refactor-workplan.md`, `firebase-validation-plan.md`, `firebase-target-architecture.md`, `firebase-backend-refactor-plan.md`.

**Dependencies:** None.

**Out of Scope:** Full repository migration, full rules coverage, admin UI, legacy server deletion.

**Implementation Notes:** Rules may start as deny-by-default with helper placeholders, but must not be permissive while waiting for later stories.

### Story 1.2: Add Rules Test Harness Smoke Coverage

**Story ID:** FES-1.2

As a developer agent, I want a local Firebase rules test harness with smoke tests, so that future stories can add emulator tests consistently.

**Scope:**

- Choose and document the rules test harness path and language.
- Add smoke tests for unauthenticated Firestore and Storage denial.
- Name tests consistently with the validation plan where possible.

**Acceptance Criteria:**

- Given unauthenticated Firestore access, when a smoke read or write is attempted, then access is denied.
- Given unauthenticated Storage access, when a smoke read or write is attempted, then access is denied.
- Given a developer runs the documented test command, then the smoke rules tests execute locally.
- Given future stories add rules tests, then the harness structure supports Firestore and Storage coverage.

**Validation Criteria:**

- L3 Firebase emulator rules tests.
- FB-1 "at least one Firestore and one Storage denial test pass" go criterion.
- Rules test command candidate is captured in developer documentation.

**Source Documents:** `firebase-validation-plan.md`, `firebase-data-contract.md`, `firebase-refactor-workplan.md`.

**Dependencies:** Story 1.1.

**Out of Scope:** Full owner/admin/status/coordinate test matrix.

**Implementation Notes:** This story resolves the validation plan open decision about the exact rules test harness path.

### Story 1.3: Wire Flutter Firebase Baseline Without Editor Firebase Access

**Story ID:** FES-1.3

As a developer agent, I want Flutter to own Firebase initialization while the editor remains SDK-free, so that future persistence stories respect architecture boundaries.

**Scope:**

- Add Flutter Firebase initialization/config wiring under `app/` only.
- Add a boundary check that searches `editor/` for Firebase SDK imports.
- Keep editor communication limited to bridge payloads.

**Acceptance Criteria:**

- Given Flutter starts in Firebase mode, when Firebase configuration is loaded, then initialization is owned by the Flutter app layer.
- Given the editor package is inspected, when forbidden Firebase import patterns are searched, then no Firebase SDK, Firestore, Storage, Auth, or Firebase config imports exist.
- Given bridge payloads exist, when this story completes, then no direct editor persistence path has been added.

**Validation Criteria:**

- L1 static and boundary checks.
- Editor forbidden import search from the validation plan.
- Flutter config build/analyze where applicable.

**Source Documents:** `firebase-target-architecture.md`, `firebase-validation-plan.md`, `firebase-data-contract.md`.

**Dependencies:** Stories 1.1 and 1.2.

**Out of Scope:** Feature repositories and Firestore writes.

**Implementation Notes:** This is a boundary story, not a feature migration story.

## Epic 2: Contracted Models, Serializers, and Repository Boundaries

### Story 2.1: Encode Firebase Data Contract Models and Enumerations

**Story ID:** FES-2.1

As a developer agent, I want app models for the Firebase data contract, so that feature stories can persist consistent documents.

**Scope:**

- Create or update models for user profile, project, source image, room dimensions, reconstruction job, transition, OpenCV result, confirmed geometry, floor plan, layout, admin action, and artifact reference.
- Encode enumerations for job status, coordinate space, content type, retention, quality, actor type, and admin role where needed.
- Preserve Firestore document IDs as strings.

**Acceptance Criteria:**

- Given each Firestore path in the data contract, when models are reviewed, then the path has a model or an explicit deferred note.
- Given job status validation, when invalid statuses `needs_review`, `done`, `complete`, or `error` are provided, then model validation rejects them.
- Given coordinate-space validation, when `opencv_results` or `confirmed_geometries` use `meters`, then validation rejects the payload.
- Given floor plan or layout geometry, when `coordinate_space` is absent or not `meters`, then validation rejects the payload.

**Validation Criteria:**

- Required model tests from `firebase-validation-plan.md`.
- `model-job-forbidden-statuses-deny`.
- Coordinate-space model validation.

**Source Documents:** `firebase-data-contract.md`, `firebase-validation-plan.md`, `firebase-target-architecture.md`.

**Dependencies:** Epic 1.

**Out of Scope:** UI migration, Firestore feature writes, admin dashboard.

**Implementation Notes:** Keep model scope contract-driven and avoid introducing post-MVP schema fields unless marked optional by the contract.

### Story 2.2: Implement Serializers for Firestore, Export, and Dart Boundaries

**Story ID:** FES-2.2

As a developer agent, I want serializer mappings for Firestore/export `snake_case` and Dart `camelCase`, so that schema drift is caught before feature migration.

**Scope:**

- Add serializers for Firestore documents and export JSON.
- Ensure Dart model fields remain `camelCase`.
- Ensure Firestore and export payloads remain `snake_case`.
- Keep candidate and confirmed geometry serializers distinct.

**Acceptance Criteria:**

- Given a model serializes to Firestore, when fields are inspected, then persisted keys use `snake_case`.
- Given a layout export is generated by serializer tests, when keys are inspected, then export JSON uses `snake_case`.
- Given Dart model APIs are used in app code, when fields are inspected, then they remain `camelCase`.
- Given candidate and confirmed geometry are serialized, when their payloads are compared, then they cannot be encoded as the same document type.

**Validation Criteria:**

- Serializer tests for `snake_case` Firestore/export payloads.
- `serializer-candidate-confirmed-distinct`.
- `model-layout-export-snake-case`.

**Source Documents:** `firebase-data-contract.md`, `firebase-validation-plan.md`, `firebase-target-architecture.md`.

**Dependencies:** Story 2.1.

**Out of Scope:** Firestore repository writes, editor UI changes.

**Implementation Notes:** Prefer shared serializer helpers only where they reduce drift without hiding collection-specific rules.

### Story 2.3: Define Repository Boundaries and Editor Bridge Mapping

**Story ID:** FES-2.3

As a developer agent, I want repository boundaries and editor bridge mapping helpers, so that Flutter persists Firebase data while the editor exchanges only spatial payloads.

**Scope:**

- Define repository interfaces or concrete Firebase repository boundaries for user, project, image, reconstruction, geometry, floor plan, layout, draft, and admin areas.
- Add bridge mapping helpers for editor `camelCase` payloads.
- Add static checks or tests that the editor has no Firebase access.

**Acceptance Criteria:**

- Given repository boundaries are reviewed, when Firebase access is needed, then it is owned by Flutter-side repositories.
- Given editor bridge payloads are mapped, when data crosses the boundary, then bridge fields use `camelCase`.
- Given Firestore/export payloads are generated after bridge mapping, then persisted/exported fields use `snake_case`.
- Given the editor source is searched, then no Firebase SDK imports are present.

**Validation Criteria:**

- Editor boundary validation from `firebase-validation-plan.md`.
- `bridge-candidate-confirmed-distinct`.
- Static forbidden import search for `editor/`.

**Source Documents:** `firebase-target-architecture.md`, `firebase-data-contract.md`, `firebase-validation-plan.md`.

**Dependencies:** Stories 2.1 and 2.2.

**Out of Scope:** Feature UI, live Firestore streams, admin collection group queries.

**Implementation Notes:** Do not move Firebase config, credentials, or Storage URL authorization into the editor.

## Epic 3: Secure Auth, Profile Projection, and Admin Role Guard

### Story 3.1: Project Firebase Auth Into Safe User Profiles

**Story ID:** FES-3.1

As a signed-in user, I want Google sign-in to create or update my application profile, so that RoomForge can associate my Firebase identity with owned data.

**Scope:**

- Preserve Google sign-in as the user entry point.
- Create or update allowed non-privileged fields under `users/{uid}`.
- Add profile sync behavior that does not modify role fields.

**Acceptance Criteria:**

- Given a user signs in with Google, when profile sync runs, then `users/{uid}` is created or updated with allowed non-privileged profile fields.
- Given a user is signed out, when project or profile data is requested, then authenticated access is required.
- Given an existing profile has role fields, when normal profile sync runs, then `role`, `role_updated_at`, and `role_updated_by_uid` are preserved.

**Validation Criteria:**

- `fs-user-profile-upsert-allow`.
- `repo-user-profile-update-preserves-role`.
- MEF-1 Auth and Profile.

**Source Documents:** `firebase-data-contract.md`, `firebase-validation-plan.md`, `firebase-refactor-workplan.md`, `docs/product/prd.md`.

**Dependencies:** Epic 2.

**Out of Scope:** Full admin dashboard, Cloud Functions role management.

**Implementation Notes:** Normal profile sync must never be implemented as a blind overwrite of `users/{uid}`.

### Story 3.2: Protect Privileged Admin Role Fields

**Story ID:** FES-3.2

As an admin operator, I want admin role state to be protected from normal user writes, so that admin capabilities cannot be self-granted.

**Scope:**

- Protect `users/{uid}.role`, `role_updated_at`, and `role_updated_by_uid` in rules and repository logic.
- Document and implement or stub the selected local/dev admin bootstrap path.
- Ensure role assignment is auditable enough for implementation.

**Acceptance Criteria:**

- Given a normal user creates a profile with `role: "admin"`, when rules evaluate the write, then it is denied.
- Given a normal user updates their profile to set or remove `role`, when rules evaluate the write, then it is denied.
- Given normal profile sync runs, when privileged role fields already exist, then they remain unchanged.
- Given the admin bootstrap path is reviewed, then it does not depend on normal client self-write.

**Validation Criteria:**

- `fs-user-role-self-create-deny`.
- `fs-user-role-self-update-deny`.
- `repo-user-profile-update-preserves-role`.
- Admin role bootstrap documentation check.

**Source Documents:** `firebase-data-contract.md`, `firebase-target-architecture.md`, `firebase-validation-plan.md`.

**Dependencies:** Story 3.1.

**Out of Scope:** Production-grade admin role management UI, broad admin diagnostics.

**Implementation Notes:** Role may be bootstrapped by trusted seed, admin-only write, custom claim sync, or Cloud Functions, but the selected path must be explicit.

### Story 3.3: Add Admin Route Guard Baseline

**Story ID:** FES-3.3

As a non-admin user, I want admin-only areas to be inaccessible, so that protected operational data is not exposed through the UI or repositories.

**Scope:**

- Add an admin route guard or placeholder admin entry point.
- Ensure guard behavior is backed by repository/rules authorization rather than client UI checks alone.
- Preserve accessible denied and loading states.

**Acceptance Criteria:**

- Given a non-admin signed-in user opens an admin route, when the guard resolves, then admin access is denied without protected data leakage.
- Given an admin signed-in user has a valid privileged role, when the guard resolves, then admin entry can be shown.
- Given role state is stale or missing, when admin access is requested, then the UI provides a recoverable denied or refresh state.

**Validation Criteria:**

- `fs-admin-non-admin-actions-read-deny`.
- MEF-1 admin route access after role is present.
- Accessibility validation for permission states.

**Source Documents:** `firebase-ux-design-specification.md`, `firebase-validation-plan.md`, `firebase-data-contract.md`.

**Dependencies:** Story 3.2.

**Out of Scope:** Admin tables, job search, artifact diagnostics, retry actions.

**Implementation Notes:** Keep detailed admin UI after job, artifact, and layout data exists in Epic 8.

## Epic 4: Project, Room Dimensions, and Source Image Upload

### Story 4.1: Migrate Owned Project and Room Dimension Persistence

**Story ID:** FES-4.1

As a signed-in user, I want to create, list, open, update, and delete my room projects with metric dimensions, so that project work begins in Firebase.

**Scope:**

- Implement Firebase-backed project create/list/open/update and supported delete or soft-delete behavior.
- Persist `room_dimensions/current` with metric units.
- Enforce `owner_uid` on create and immutability after create.

**Acceptance Criteria:**

- Given User A creates a project, when the project document is written, then `owner_uid` is User A and cannot be changed later.
- Given User A lists projects, when the query runs, then only User A projects are returned.
- Given User B attempts to read or write User A project or dimensions, then access is denied.
- Given room dimensions are saved, when the project is reopened, then width, depth, and height/default height are available in meters.

**Validation Criteria:**

- `fs-project-owner-read-allow`.
- `fs-project-owner-create-allow`.
- `fs-project-owner-immutable-deny`.
- `fs-project-non-owner-read-deny`.
- MEF-2 project and dimensions.

**Source Documents:** `firebase-data-contract.md`, `firebase-validation-plan.md`, `firebase-refactor-workplan.md`, `docs/product/prd.md`.

**Dependencies:** Epic 3.

**Out of Scope:** Image upload, reconstruction, layout save/export.

**Implementation Notes:** Queries must include owner constraints; Firestore rules are not filters.

### Story 4.2: Upload Source Images to Contracted Storage Paths

**Story ID:** FES-4.2

As a signed-in user, I want to upload a valid room image to my project, so that reconstruction has private source input in Firebase Storage.

**Scope:**

- Upload JPEG, PNG, and WebP files up to the contracted 10 MB limit.
- Use `users/{uid}/projects/{project_id}/source-images/{source_image_id}/{filename}`.
- Persist source image metadata only after upload completes or surface a recoverable metadata-save failure.

**Acceptance Criteria:**

- Given User A uploads a valid image to an owned project, when Storage and metadata writes complete, then the source image document stores matching `storage_path`, content type, byte size, dimensions, SHA-256, owner, project, and timestamps.
- Given an invalid content type is uploaded, when validation runs, then the upload is denied or blocked before success.
- Given a file exceeds the size limit, when validation runs, then the upload is denied or blocked before success.
- Given User B attempts to access User A source image path, then access is denied.

**Validation Criteria:**

- `st-source-owner-upload-allow`.
- `st-source-invalid-type-deny`.
- `st-source-too-large-deny`.
- `st-source-cross-user-deny`.
- `st-source-path-uid-mismatch-deny`.
- `repo-source-metadata-after-upload`.

**Source Documents:** `firebase-data-contract.md`, `firebase-validation-plan.md`, `firebase-ux-design-specification.md`.

**Dependencies:** Story 4.1.

**Out of Scope:** Reconstruction processing, artifact writes, layout export.

**Implementation Notes:** Resolve orphan mitigation through project lookup, upload reservation, or metadata handshake as selected during implementation.

### Story 4.3: Surface Upload Progress, Failure, and Recovery States

**Story ID:** FES-4.3

As a signed-in user, I want upload progress and recovery states to be clear, so that I know whether my source image is usable.

**Scope:**

- Implement UX states `Uploading`, `Uploaded`, retry, validation error, permission failure, and metadata-save failure recovery.
- Display photo suitability guidance before upload where the existing product flow requires it.
- Keep non-canvas controls accessible.

**Acceptance Criteria:**

- Given a valid image upload is in progress, when progress changes, then the user sees an accessible `Uploading` state.
- Given upload and metadata persistence finish, when the UI updates, then the user sees `Uploaded`.
- Given metadata save fails after Storage upload succeeds, then the UI does not treat the image as fully complete and offers retry or cleanup guidance.
- Given permission denial occurs, then the UI shows a recoverable permission state without exposing other users' data.

**Validation Criteria:**

- `ui-source-metadata-save-failed-recovery`.
- MEF-2 invalid image and upload recovery checks.
- Accessibility validation for upload state text, retry controls, and keyboard access.

**Source Documents:** `firebase-ux-design-specification.md`, `firebase-validation-plan.md`, `docs/product/prd.md`.

**Dependencies:** Story 4.2.

**Out of Scope:** Advanced image quality scoring beyond existing PRD guidance.

**Implementation Notes:** Use UX spec Upload Progress Panel and Permission Recovery Notice patterns.

## Epic 5: Reconstruction State, Geometry, and Floor Plan Persistence

### Story 5.1: Persist Reconstruction Jobs and Transitions

**Story ID:** FES-5.1

As a signed-in user, I want reconstruction job status to persist in Firebase, so that I can leave and return without losing processing state.

**Scope:**

- Create and update `reconstruction_jobs` under owned projects.
- Append transition records for status changes.
- Preserve status, timestamp, actor/source, reason code, human-readable reason, and retry linkage where available.

**Acceptance Criteria:**

- Given a reconstruction job is created, when the job document is written, then status uses only the allowed vocabulary.
- Given status changes, when transitions are written, then transition history is append-oriented and includes required troubleshooting fields.
- Given an invalid persisted status such as `needs_review` or `done`, when model or rules validation runs, then the write is rejected.
- Given `review_required` is persisted, when displayed to the user, then it appears as `Needs review`.

**Validation Criteria:**

- `fs-job-valid-status-review-required-allow`.
- `fs-job-invalid-status-needs-review-deny`.
- `model-job-forbidden-statuses-deny`.
- Repository tests for transitions, failure reasons, and retry linkage.
- MEF-3 job status flow.

**Source Documents:** `firebase-data-contract.md`, `firebase-validation-plan.md`, `firebase-ux-design-specification.md`, `docs/product/prd.md`.

**Dependencies:** Epic 4.

**Out of Scope:** Candidate geometry, floor plan persistence, admin retry UI.

**Implementation Notes:** Firestore streams may replace legacy polling where practical, but must not overwrite active local edits.

### Story 5.2: Persist OpenCV Candidates and Confirmed Geometry Separately

**Story ID:** FES-5.2

As a signed-in user, I want OpenCV candidate geometry and my confirmed geometry to persist separately, so that reconstruction review remains traceable.

**Scope:**

- Persist `opencv_results` candidate geometry with `coordinate_space: "image_pixels"`.
- Persist `confirmed_geometries` user-corrected geometry separately with `coordinate_space: "image_pixels"`.
- Maintain bridge payload separation between `candidateGeometry` and `confirmedGeometry`.

**Acceptance Criteria:**

- Given OpenCV candidate geometry is emitted, when Flutter persists it, then it is stored under `opencv_results` and not `confirmed_geometries`.
- Given the user confirms or corrects geometry, when Flutter persists it, then it is stored under `confirmed_geometries` and not merged into candidate results.
- Given a candidate payload is written to confirmed geometry without required confirmed fields, then validation denies it where rules enforce the shape.
- Given bridge payloads are inspected, then candidate and confirmed concepts remain distinct.

**Validation Criteria:**

- `fs-opencv-image-pixels-allow`.
- `fs-opencv-meters-deny`.
- `fs-confirmed-geometry-image-pixels-allow`.
- `fs-confirmed-geometry-meters-deny`.
- `fs-confirmed-geometry-shape-allow`.
- `fs-candidate-confirmed-mix-deny`.
- `serializer-candidate-confirmed-distinct`.
- `bridge-candidate-confirmed-distinct`.

**Source Documents:** `firebase-data-contract.md`, `firebase-validation-plan.md`, `firebase-target-architecture.md`.

**Dependencies:** Story 5.1.

**Out of Scope:** Layout save/export, admin diagnostics.

**Implementation Notes:** The editor may compute or display geometry but Flutter owns persistence.

### Story 5.3: Persist Metric Floor Plans and Artifact References

**Story ID:** FES-5.3

As a signed-in user, I want a calibrated metric floor plan and reconstruction artifacts to be stored, so that room editing and troubleshooting can use reliable reconstruction outputs.

**Scope:**

- Persist `floor_plans` with `coordinate_space: "meters"`.
- Store artifact references for overlays, calibration output, debug JSON, or generated artifacts as metadata.
- Preserve review and failure states for user-facing recovery.

**Acceptance Criteria:**

- Given confirmed image-space geometry and room dimensions are available, when calibration succeeds, then a floor plan is stored in meters.
- Given a floor plan write uses `image_pixels`, when validation runs, then it is denied.
- Given artifact refs are stored, when metadata is inspected, then `storage_path`, content type, owner/project/job linkage, and availability state follow the contract.
- Given a reconstruction requires review, when the floor plan or job state is shown, then the user sees `Needs review`.

**Validation Criteria:**

- `fs-floor-plan-meters-allow`.
- `st-artifact-owner-read-allow`.
- `st-artifact-invalid-type-deny`.
- `st-artifact-public-list-deny`.
- MEF-3 reconstruction and geometry.
- Editor forbidden import check if bridge integration is touched.

**Source Documents:** `firebase-data-contract.md`, `firebase-validation-plan.md`, `firebase-ux-design-specification.md`.

**Dependencies:** Story 5.2.

**Out of Scope:** Layout JSON export, admin artifact troubleshooting UI.

**Implementation Notes:** Artifact metadata must not imply public Storage access; Storage Rules remain authoritative.

## Epic 6: Cloud Layout Save, Load, and JSON Export

### Story 6.1: Save and Load Layouts from Firestore

**Story ID:** FES-6.1

As a signed-in user, I want to save and reload my room layout from Firebase, so that my room plan is durable across sessions.

**Scope:**

- Implement Firebase-backed layout save and load.
- Persist required layout fields: room dimensions, source metadata, floor plan snapshot/reference, editor scene, furniture objects, schema version, export version, ownership, and timestamps.
- Enforce owner-only layout access.

**Acceptance Criteria:**

- Given User A saves a layout for an owned project, when the document is written, then required layout fields are present.
- Given User A reloads the project, when the layout is loaded, then room, source, floor plan, editor scene, and furniture fields are restored.
- Given User B attempts to read User A layout, then access is denied.
- Given save/load round trip completes, then required fields are preserved except server-managed timestamps.

**Validation Criteria:**

- `fs-layout-owner-roundtrip-write-allow`.
- `fs-layout-non-owner-read-deny`.
- `model-layout-save-load-export-roundtrip`.
- Layout round-trip validation steps 1 through 8.

**Source Documents:** `firebase-data-contract.md`, `firebase-validation-plan.md`, `firebase-refactor-workplan.md`, `docs/product/prd.md`.

**Dependencies:** Epic 5.

**Out of Scope:** IndexedDB draft conflicts, admin layout diagnostics.

**Implementation Notes:** Export must later use the latest saved Firestore layout, not an unsaved draft.

### Story 6.2: Preserve Editor Bridge and Furniture State

**Story ID:** FES-6.2

As a signed-in user, I want furniture edits to survive save/load without changing the editor contract, so that the 2D/3D editor remains stable during Firebase migration.

**Scope:**

- Map editor `camelCase` scene and furniture bridge payloads to Firestore/export `snake_case`.
- Preserve furniture IDs, categories, positions, sizes, rotations, colors, labels, and lock state where available.
- Keep editor SDK-free.

**Acceptance Criteria:**

- Given furniture objects are saved, when the layout reloads, then object IDs, categories, `position_m`, `size_m`, `rotation_deg`, and optional fields are preserved.
- Given editor bridge payloads are inspected, then they remain `camelCase`.
- Given persisted Firestore layout data is inspected, then it is `snake_case`.
- Given the editor package is searched, then Firebase imports are absent.

**Validation Criteria:**

- Layout round-trip furniture assertions.
- Editor boundary validation.
- `model-layout-export-snake-case` where layout serialization is touched.

**Source Documents:** `firebase-validation-plan.md`, `firebase-data-contract.md`, `firebase-target-architecture.md`.

**Dependencies:** Story 6.1.

**Out of Scope:** New furniture manipulation capabilities beyond preserving existing editor state.

**Implementation Notes:** Do not use this story to expand editor product scope.

### Story 6.3: Export Latest Saved Layout JSON with Review Warning

**Story ID:** FES-6.3

As a signed-in user, I want to export the latest saved layout as JSON with clear review warnings, so that exported data is accurate and trustworthy.

**Scope:**

- Generate export JSON from the latest saved Firestore layout.
- Preserve `snake_case` export fields.
- Show visible warning before save/export when associated reconstruction status is `review_required`.

**Acceptance Criteria:**

- Given a saved layout exists, when export is requested, then export JSON is generated from the saved Firestore layout.
- Given only an unsaved local draft exists, when export is requested, then the app does not silently export it as the cloud source of truth.
- Given layout reconstruction status is `review_required`, when export is requested, then the user sees a visible `Needs review` warning.
- Given export JSON is inspected, then persisted/exported fields use `snake_case`.

**Validation Criteria:**

- `model-layout-save-load-export-roundtrip`.
- `model-layout-export-snake-case`.
- `ui-layout-review-required-warning`.
- Layout round-trip validation steps 9 and 10.
- MEF-4 Layout Save, Load, and Export.

**Source Documents:** `firebase-validation-plan.md`, `firebase-ux-design-specification.md`, `firebase-data-contract.md`, `docs/product/prd.md`.

**Dependencies:** Story 6.2.

**Out of Scope:** Local draft conflict resolution beyond blocking ambiguous export.

**Implementation Notes:** The warning copy must use `Needs review` for users while persisted status remains `review_required`.

## Epic 7: Local Draft Recovery and Cloud Conflict Handling

### Story 7.1: Implement IndexedDB Draft and Project Cache Stores

**Story ID:** FES-7.1

As a signed-in user, I want local drafts to be recoverable after refresh, so that accidental navigation does not destroy unsaved layout work.

**Scope:**

- Implement `roomforge_drafts` IndexedDB database.
- Add `layout_drafts` and `project_cache` object stores.
- Track project/layout IDs, local revision, base cloud revision, dirty state, conflict state, and timestamps.

**Acceptance Criteria:**

- Given a user edits a layout without cloud save, when draft persistence runs, then an `Unsaved draft` is stored locally.
- Given the user refreshes or navigates back, when the project reopens, then the draft can be detected.
- Given draft/cache state is inspected, then it is labeled as local recoverable state and not the cloud source of truth.

**Validation Criteria:**

- DraftRepository tests for draft save, restore metadata, dirty state, and cache invalidation.
- FB-7 minimum go criteria.
- MEF-5 first two steps.

**Source Documents:** `firebase-data-contract.md`, `firebase-validation-plan.md`, `firebase-ux-design-specification.md`.

**Dependencies:** Epic 6.

**Out of Scope:** Full offline-first sync, collaboration, background sync.

**Implementation Notes:** IndexedDB schema changes should be versioned enough to avoid breaking old local drafts silently.

### Story 7.2: Add Draft Recovery and Conflict Resolver UX

**Story ID:** FES-7.2

As a signed-in user, I want clear choices when a local draft and cloud layout diverge, so that I decide whether to restore, discard, or continue saved cloud state.

**Scope:**

- Implement Draft Recovery Banner and Cloud Draft Conflict Resolver patterns.
- Provide restore draft, discard draft, continue saved cloud state, and retry save choices where applicable.
- Require confirmation for destructive discard.

**Acceptance Criteria:**

- Given a local draft exists and no cloud conflict exists, when the project opens, then the user can restore or discard it.
- Given local draft and cloud layout revisions diverge, when the project opens, then the user sees an explicit conflict choice.
- Given the user discards a draft, when the action is confirmed, then local draft state is removed without changing the saved cloud layout.
- Given the user restores a draft, then the UI labels it as `Unsaved draft` until it is saved to Firestore.

**Validation Criteria:**

- Draft conflict detection tests.
- MEF-5 restore, discard, continue saved version behavior.
- Accessibility checks for recovery actions and text readability.

**Source Documents:** `firebase-ux-design-specification.md`, `firebase-validation-plan.md`, `firebase-data-contract.md`.

**Dependencies:** Story 7.1.

**Out of Scope:** Multi-device collaborative merge.

**Implementation Notes:** Do not imply cloud save when only local draft state exists.

### Story 7.3: Prevent Firestore Streams from Silently Overwriting Active Drafts

**Story ID:** FES-7.3

As a signed-in user, I want active local edits to be protected from remote updates, so that real-time Firebase updates do not erase work without consent.

**Scope:**

- Gate Firestore layout/project stream application when an active local draft exists.
- Surface sync states `Saving`, `Saved`, `Unsaved draft`, `Sync failed`, and `Retry available`.
- Add keyboard and text-readable accessibility coverage for persistence states.

**Acceptance Criteria:**

- Given a local draft is dirty, when a Firestore update arrives, then active editor state is not silently overwritten.
- Given sync fails, when the user reviews persistence state, then `Sync failed` and `Retry available` are visible and actionable.
- Given save succeeds, when local draft state clears, then the UI reflects `Saved`.
- Given keyboard-only navigation, when recovery controls are used, then restore/discard/retry actions are reachable.

**Validation Criteria:**

- Unit tests for no silent stream overwrite.
- Accessibility validation for save, draft, sync, and recovery states.
- MEF-5 full flow.

**Source Documents:** `firebase-validation-plan.md`, `firebase-ux-design-specification.md`, `firebase-target-architecture.md`.

**Dependencies:** Story 7.2.

**Out of Scope:** Full offline conflict merge.

**Implementation Notes:** Remote stream handling must be conservative around dirty editor state.

## Epic 8: Firebase-Backed Admin Diagnostics and Retry

### Story 8.1: Implement Admin Repository, Indexes, and Rules-Backed Query Access

**Story ID:** FES-8.1

As an admin user, I want Firebase-backed admin queries for jobs and related records, so that operational diagnostics can run without the legacy admin API.

**Scope:**

- Implement `AdminRepository` collection group query shapes for jobs, transitions, results, layouts, and admin actions where contracted.
- Add or update Firestore index definitions for admin query candidates.
- Enforce admin-only reads through Security Rules.

**Acceptance Criteria:**

- Given a non-admin user attempts admin collection group reads, then access is denied.
- Given an admin user queries jobs by status, owner, project, or job ID, then allowed query shapes work when indexes exist.
- Given an index is missing, when the repository encounters the failure, then it surfaces a clear implementation/admin diagnostic rather than a silent empty state.
- Given admin queries are reviewed, then normal user access is not broadened.

**Validation Criteria:**

- `fs-admin-job-cg-read-allow`.
- `fs-admin-non-admin-job-cg-read-deny`.
- Repository tests for collection group query shapes and missing-index handling.
- MEF-6 admin and non-admin accounts.

**Source Documents:** `firebase-data-contract.md`, `firebase-validation-plan.md`, `firebase-refactor-workplan.md`, `docs/product/prd.md`.

**Dependencies:** Stories 3.3, 5.3, and 6.3.

**Out of Scope:** Admin retry action, bulk mutation tools.

**Implementation Notes:** Admin reads must be rules-backed, not client-side filtering over broad user data.

### Story 8.2: Build Admin Diagnostics for Jobs, Artifacts, Layouts, and Permissions

**Story ID:** FES-8.2

As an admin user, I want to inspect job details, artifacts, layout references, and permission outcomes, so that I can identify where reconstruction failed.

**Scope:**

- Show job status, owner/project/job references, provider state, artifact availability, failure reason, retry count, and transition history.
- Map artifact read outcomes to `available`, `restricted`, `missing`, `failed_to_load`, or `not_generated`.
- Include layout, OpenCV result, confirmed geometry, and floor plan references where available.

**Acceptance Criteria:**

- Given an admin opens a job detail, when data exists, then the UI shows job status, transition history, failure reason, retry linkage, and artifact refs.
- Given artifact access is allowed, when admin reads the artifact, then the UI maps it as `available`.
- Given artifact access is denied, missing, failed, or not generated, then the UI shows the corresponding permission-aware state.
- Given a non-admin reaches any loading, empty, or error state, then protected admin data is not leaked.

**Validation Criteria:**

- `st-artifact-admin-read-allow`.
- `st-artifact-non-admin-cross-user-deny`.
- `admin-artifact-state-mapping`.
- MEF-6 artifact and detail diagnostics.
- Accessibility check for admin filters, tables, row actions, and detail panels.

**Source Documents:** `firebase-ux-design-specification.md`, `firebase-validation-plan.md`, `firebase-data-contract.md`, `docs/product/prd.md`.

**Dependencies:** Story 8.1.

**Out of Scope:** Retry mutation and provider lifecycle control.

**Implementation Notes:** Detailed admin UI belongs here because role, job, artifact, and layout data now exist.

### Story 8.3: Add Audited Admin Retry with Append-Only Admin Actions

**Story ID:** FES-8.3

As an admin user, I want retry actions to create linked jobs and audit records, so that troubleshooting actions are traceable.

**Scope:**

- Allow admin retry for failed or retryable reconstruction jobs.
- Create a linked retry job with root/original retry metadata.
- Create append-only `admin_actions` records for retry actions.
- Deny update/delete of existing admin action records.

**Acceptance Criteria:**

- Given an admin retries a failed job, when the action is confirmed, then a new linked retry job is created.
- Given retry succeeds in creating a linked job, then an `admin_actions` document records actor, target, action, reason, and timestamps.
- Given anyone attempts to update or delete an existing `admin_actions` document, then rules deny the operation.
- Given a non-admin attempts retry, then the action is denied without creating a job or audit record.

**Validation Criteria:**

- `fs-admin-actions-create-allow`.
- `fs-admin-actions-update-deny`.
- `fs-admin-actions-delete-deny`.
- `fs-admin-non-admin-actions-read-deny`.
- MEF-6 admin retry.
- Repository tests for retry linkage.

**Source Documents:** `firebase-data-contract.md`, `firebase-validation-plan.md`, `firebase-refactor-workplan.md`, `docs/product/prd.md`.

**Dependencies:** Story 8.2.

**Out of Scope:** Bulk retries, production provider orchestration, public support portal.

**Implementation Notes:** Admin writes to user/project data should be avoided unless covered by explicit auditable action records.

## Epic 9: Firebase Default Cutover and Legacy API Isolation

### Story 9.1: Select Firebase Repositories by Default

**Story ID:** FES-9.1

As a developer agent, I want Firebase repositories selected by default, so that normal RoomForge flows no longer require FastAPI or Oracle.

**Scope:**

- Finalize backend mode selection with default `firebase`.
- Ensure default sign-in, project, upload, reconstruction, layout, export, and admin flows use Firebase repositories.
- Keep legacy mode available only through explicit configuration.

**Acceptance Criteria:**

- Given app configuration is absent or defaulted, when repositories are resolved, then Firebase implementations are selected.
- Given `legacy_api` is explicitly configured, when legacy mode is requested, then legacy adapters are used intentionally.
- Given default user flows run, then they do not require FastAPI or Oracle.

**Validation Criteria:**

- FB-9 minimum go criteria.
- Default backend selection tests.
- MEF-7 Legacy Isolation.

**Source Documents:** `firebase-target-architecture.md`, `firebase-refactor-workplan.md`, `firebase-backend-refactor-plan.md`, `firebase-validation-plan.md`.

**Dependencies:** Epics 3 through 8.

**Out of Scope:** Deleting `server/`, Oracle-to-Firebase historical migration.

**Implementation Notes:** Preserve legacy reference code but remove it from default service wiring.

### Story 9.2: Isolate Legacy ProjectApi and AdminApi Usage

**Story ID:** FES-9.2

As a developer agent, I want legacy API clients isolated behind `legacy_api`, so that hidden default-path HTTP calls do not survive the cutover.

**Scope:**

- Move or guard legacy `ProjectApi`, `AdminApi`, and old HTTP-first assumptions behind explicit legacy adapters.
- Mark shared API envelope guidance as legacy-only where Firebase direct SDK repositories are documented.
- Add searches or tests for default-path legacy usage.

**Acceptance Criteria:**

- Given the default app path is inspected, when `ProjectApi` and `AdminApi` references exist, then they are not used by default Firebase flows.
- Given documentation is searched, then Oracle/FastAPI language does not describe the default backend.
- Given `legacy_api` is configured, then legacy code remains reachable only intentionally.

**Validation Criteria:**

- Documentation search for Oracle/FastAPI/ProjectApi/AdminApi/default language.
- Default-path tests or static checks.
- MEF-7 default path does not require FastAPI or Oracle.

**Source Documents:** `firebase-backend-refactor-plan.md`, `firebase-target-architecture.md`, `firebase-validation-plan.md`.

**Dependencies:** Story 9.1.

**Out of Scope:** Server deletion, production decommissioning.

**Implementation Notes:** Do not remove useful server tests unless this story directly changes server code.

### Story 9.3: Validate End-to-End Firebase Default Flow

**Story ID:** FES-9.3

As a developer agent, I want a default-path Firebase smoke flow, so that the cutover proves user value rather than only configuration changes.

**Scope:**

- Run or document a smoke path covering sign-in, project create/open, image upload, reconstruction state persistence, layout save/load/export, and admin diagnostics.
- Confirm no default flow requires legacy FastAPI/Oracle.
- Record known limitations without treating them as completed features.

**Acceptance Criteria:**

- Given local emulators are running, when the default smoke flow executes, then core Firebase flows can be exercised in order.
- Given the smoke flow reaches admin diagnostics, then non-admin denial and admin access are both verified at a minimal level.
- Given a limitation remains, then it is documented as a follow-up rather than hidden.

**Validation Criteria:**

- MEF-1 through MEF-7 as applicable.
- FB-9 go criteria.
- Invariant review: `legacy_api` explicit only.

**Source Documents:** `firebase-validation-plan.md`, `firebase-refactor-workplan.md`, `firebase-target-architecture.md`.

**Dependencies:** Story 9.2.

**Out of Scope:** Full production deployment certification.

**Implementation Notes:** This story can be a validation/story gate after feature parity exists, not an early implementation story.

## Epic 10: Validation, Documentation, and Readiness Gate

### Story 10.1: Finalize Firebase Validation Commands and Runbook

**Story ID:** FES-10.1

As a developer agent, I want validation commands and fallback guidance to be explicit, so that future story implementation uses the same evidence standard.

**Scope:**

- Finalize commands for Flutter analysis/tests, editor build/boundary checks, Firebase emulator rules tests, and manual emulator flows.
- Document fallbacks for missing local tools.
- Ensure validation IDs from the validation plan are mapped to story-level checks.

**Acceptance Criteria:**

- Given a future story references a validation ID, when the runbook is reviewed, then the command or manual check path is discoverable.
- Given Firebase emulator tests are required, then the runbook identifies how to start emulators and run tests.
- Given Flutter or editor checks are required, then command candidates and fallback notes are documented.

**Validation Criteria:**

- L0 documentation and traceability review.
- L1 through L6 validation layer coverage review.
- FB-10 work package coverage.

**Source Documents:** `firebase-validation-plan.md`, `firebase-refactor-workplan.md`.

**Dependencies:** Epics 1 through 9 planning coverage.

**Out of Scope:** Generating the implementation readiness report.

**Implementation Notes:** This can update docs/indexes later, but this current artifact does not edit source documents.

### Story 10.2: Link Refactor Docs and Preserve Source-of-Truth Order

**Story ID:** FES-10.2

As a developer agent, I want refactor documentation to point to the correct Firebase artifacts, so that future agents do not resume from stale legacy planning outputs.

**Scope:**

- Update any refactor overview or docs index to link Firebase plan, UX, architecture, data contract, workplan, validation plan, and epics/stories.
- Mark old API envelope guidance as legacy-only where applicable.
- Preserve PRD and UX as product-level sources while Firebase docs define backend refactor specifics.

**Acceptance Criteria:**

- Given docs are searched, when Firebase refactor guidance is needed, then the generated Firebase artifacts are discoverable.
- Given old backend guidance is encountered, then it does not claim Oracle/FastAPI is the default path.
- Given a future story starts, then source document order is clear enough to avoid schema/rules drift.

**Validation Criteria:**

- Documentation traceability checks from `firebase-validation-plan.md`.
- Search for Oracle/FastAPI/default backend language.
- Invariant review for Firebase default and `legacy_api` explicit only.

**Source Documents:** `firebase-validation-plan.md`, `firebase-refactor-workplan.md`, `firebase-target-architecture.md`.

**Dependencies:** Story 10.1.

**Out of Scope:** Rewriting PRD, UX, architecture, or product scope.

**Implementation Notes:** Keep documentation updates separate from feature implementation stories when possible.

### Story 10.3: Prepare Implementation Readiness Review Inputs

**Story ID:** FES-10.3

As a parent planning workflow, I want PRD, UX, architecture, data contract, workplan, validation plan, and epics/stories aligned, so that the next implementation readiness workflow can approve or block implementation honestly.

**Scope:**

- Review coverage across source docs and this backlog.
- Identify unresolved open decisions that must become implementation-story acceptance criteria.
- Prepare inputs for the next implementation readiness workflow without generating the readiness report in this artifact.

**Acceptance Criteria:**

- Given FR1 through FR50 are reviewed, when traceability is checked, then each FR group maps to one or more Firebase refactor stories.
- Given FB-1 through FB-10 are reviewed, then each work package maps to one or more stories.
- Given open decisions remain, then they are assigned to relevant stories or called out as readiness questions.
- Given the next workflow starts, then it can validate without inventing schema, rules, or story order from scratch.

**Validation Criteria:**

- L6 readiness gate.
- PRD and UX traceability checks.
- Stop criteria review confirms no generated story violates editor, role, layout export, admin, or legacy isolation invariants.

**Source Documents:** All input documents for this artifact.

**Dependencies:** Story 10.2.

**Out of Scope:** Creating `implementation-readiness-report` or changing code.

**Implementation Notes:** This is the handoff point to BMAD implementation readiness validation.

## Traceability Matrix

### FB Work Package to Story Mapping

| FB package | Stories | Coverage |
| --- | --- | --- |
| FB-1 Firebase Baseline | FES-1.1, FES-1.2, FES-1.3 | Firebase config, emulators, rules skeleton, smoke rules tests, Flutter Firebase baseline, editor no-Firebase boundary. |
| FB-2 Data Contract Models | FES-2.1, FES-2.2, FES-2.3 | Models, serializers, repository boundaries, bridge mapping, status/coordinate validators. |
| FB-3 Auth and Role | FES-3.1, FES-3.2, FES-3.3 | Google sign-in profile projection, privileged role protection, admin guard baseline. |
| FB-4 Projects and Upload | FES-4.1, FES-4.2, FES-4.3 | Project CRUD, dimensions, source image upload, metadata, upload UX and recovery. |
| FB-5 Reconstruction | FES-5.1, FES-5.2, FES-5.3 | Jobs, transitions, OpenCV results, confirmed geometry, floor plans, artifacts, review state. |
| FB-6 Layout Save/Load/Export | FES-6.1, FES-6.2, FES-6.3 | Layout persistence, furniture/editor state, export JSON, `Needs review` warning. |
| FB-7 Draft Recovery | FES-7.1, FES-7.2, FES-7.3 | IndexedDB draft/cache, conflict resolver, no silent stream overwrite, accessibility. |
| FB-8 Admin Diagnostics | FES-8.1, FES-8.2, FES-8.3 | Admin repository, indexes, job/artifact/layout diagnostics, append-only admin actions, retry. |
| FB-9 Legacy Cutover | FES-9.1, FES-9.2, FES-9.3 | Firebase default selection, legacy API isolation, end-to-end default smoke. |
| FB-10 Readiness | FES-10.1, FES-10.2, FES-10.3 | Validation runbook, doc traceability, readiness input preparation. |

### PRD Functional Requirement Group Mapping

| PRD group | Requirements | Stories |
| --- | --- | --- |
| User Accounts and Access | FR1-FR4 | FES-1.3, FES-3.1, FES-3.2, FES-3.3, FES-8.1 |
| Room Project Management | FR5-FR9 | FES-4.1, FES-9.3 |
| Room Input and Capture Guidance | FR10-FR14 | FES-4.2, FES-4.3 |
| OpenCV-Assisted Reconstruction Workflow | FR15-FR21 | FES-5.1, FES-5.2, FES-5.3 |
| Reconstruction Result and Quality Handling | FR22-FR28 | FES-5.1, FES-5.2, FES-5.3, FES-8.2, FES-8.3 |
| 3D Room and Furniture Editing | FR29-FR36 | FES-6.1, FES-6.2, FES-7.3 |
| Layout Persistence and Export | FR37-FR40 | FES-6.1, FES-6.2, FES-6.3, FES-7.1, FES-7.2 |
| Admin Operations | FR41-FR47 | FES-3.2, FES-3.3, FES-8.1, FES-8.2, FES-8.3 |
| Support and Troubleshooting | FR48-FR50 | FES-5.1, FES-8.1, FES-8.2, FES-8.3 |

### PRD Non-Functional Requirement Group Mapping

| NFR group | Requirements | Stories |
| --- | --- | --- |
| Performance | NFR1-NFR5 | FES-5.1, FES-6.1, FES-6.2, FES-9.3 |
| Security | NFR6-NFR10 | FES-1.1, FES-1.2, FES-3.1, FES-3.2, FES-3.3, FES-4.1, FES-4.2, FES-8.1 |
| Reliability and Recoverability | NFR11-NFR15 | FES-5.1, FES-5.3, FES-7.1, FES-7.2, FES-8.2, FES-8.3 |
| Cost and Resource Efficiency | NFR16-NFR19 | FES-1.3, FES-5.2, FES-8.2, FES-9.1, FES-9.2 |
| Data Integrity | NFR20-NFR23 | FES-2.1, FES-2.2, FES-5.1, FES-5.2, FES-6.1, FES-6.2, FES-6.3 |
| Accessibility and Usability | NFR24-NFR26 | FES-4.3, FES-5.3, FES-6.3, FES-7.2, FES-7.3, FES-8.2 |

## Validation Coverage Summary

| Validation area | Primary stories |
| --- | --- |
| Firebase emulator baseline and deny-by-default smoke | FES-1.1, FES-1.2 |
| Editor Firebase boundary | FES-1.3, FES-2.3, FES-5.2, FES-6.2, FES-7.3 |
| Data contract model and serializer tests | FES-2.1, FES-2.2, FES-2.3 |
| Auth profile and role escalation denial | FES-3.1, FES-3.2 |
| Project ownership and source upload rules | FES-4.1, FES-4.2 |
| Reconstruction status and coordinate rules | FES-5.1, FES-5.2, FES-5.3 |
| Layout round-trip and export | FES-6.1, FES-6.2, FES-6.3 |
| IndexedDB draft and conflict recovery | FES-7.1, FES-7.2, FES-7.3 |
| Admin role, query, artifact, and retry rules | FES-8.1, FES-8.2, FES-8.3 |
| Legacy cutover and documentation checks | FES-9.1, FES-9.2, FES-9.3, FES-10.2 |

## Open Decisions Assigned to Stories

| Open decision | Assigned story |
| --- | --- |
| Exact Firebase rules test harness path and language | FES-1.2 |
| Admin role bootstrap method | FES-3.2 |
| Source image orphan mitigation approach | FES-4.2 |
| Missing Firestore index error handling | FES-8.1 |
| Artifact write authority for MVP vs future trusted worker | FES-5.3 |
| Optional layout export content hash | FES-6.3 or FES-10.1 |

## Parent Validation Checklist

- [x] Every FB package FB-1 through FB-10 maps to one or more stories.
- [x] Every PRD FR group maps to one or more stories.
- [x] Stories preserve dependency order from Firebase baseline through readiness.
- [x] Admin UI detail stories occur after role, job, artifact, and layout data exists.
- [x] Legacy cutover stories occur after Firebase feature parity stories.
- [x] No story asks the editor to import Firebase SDKs.
- [x] No story makes `legacy_api` the default path.
- [x] No story allows normal clients to self-write `users/{uid}.role`.
- [x] No story allows export from an unsaved IndexedDB draft as the cloud source of truth.
- [x] The next workflow remains implementation readiness validation, not code implementation.

**Parent validation result:** PASS for backlog structure, dependency order, traceability coverage, and invariant preservation. This artifact is complete as a backlog source; implementation approval still requires the separate implementation readiness workflow.
