---
title: "RoomForge Firebase Refactor Workplan"
status: "complete"
created: "2026-05-24"
updated: "2026-05-24"
completedAt: "2026-05-24"
workflowType: "refactor-workplan"
stepsCompleted:
  - "step-01-source-analysis"
  - "step-02-work-package-plan"
  - "step-03-parent-validation"
lastStep: 3
inputDocuments:
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
  - "architecture-follow-up"
---

# Firebase Refactor Workplan - RoomForge

This workplan converts the RoomForge Firebase refactor planning artifacts into ordered implementation work packages. It is a planning artifact for story generation, not the final epic/story backlog.

The source of truth for schema, rules behavior, storage paths, indexes, role handling, and IndexedDB draft/cache contracts is `docs/refactor/firebase-data-contract.md`. The source of truth for system boundaries is `docs/refactor/firebase-target-architecture.md`. The source of truth for user-facing Firebase state language and recovery UX is `docs/refactor/firebase-ux-design-specification.md`.

## Workplan Goals

- Make Firebase the default backend path for RoomForge without deleting the legacy FastAPI/Oracle code.
- Preserve the existing product promise: Google sign-in, project creation, image upload, OpenCV-assisted reconstruction, user correction, metric floor plan, 2D/3D editing, layout save/load/export, and admin troubleshooting.
- Implement Firebase in a sequence that prevents contract drift: config and rules baseline first, models and repositories second, feature migrations after the data contract is represented in code.
- Keep Flutter as the only Firebase access owner.
- Keep the Three.js/OpenCV editor free of Firebase SDK imports and direct Firestore/Storage calls.
- Keep `server/` available only behind an explicit `legacy_api` mode.
- Use emulator-backed validation before feature stories are considered implementation-ready.

## Non-Negotiable Implementation Invariants

- Flutter owns Firebase Auth, Firestore, Storage, repository access, upload/save/load/export, draft recovery, and admin repository access.
- The editor receives and emits bridge payloads only; it must not import Firebase SDKs.
- Legacy FastAPI/Oracle is not deleted in this refactor and is not the default path.
- Firestore persisted fields use `snake_case`.
- Export JSON uses `snake_case`.
- Editor bridge payloads use `camelCase`.
- Candidate geometry and user-confirmed geometry remain separate.
- Geometry payloads always state coordinate space: `image_pixels` before calibration and `meters` after calibration.
- Persisted reconstruction job statuses are exactly `created`, `uploading`, `processing`, `review_required`, `succeeded`, `failed`, `timeout`, `cancelled`, and `retrying`.
- Persisted `review_required` displays as `Needs review`.
- Persisted job statuses must not include `needs_review`, `done`, `complete`, or `error`.
- Admin role is privileged authorization state. Normal users must not create, update, or delete `users/{uid}.role`.
- All user-facing Firebase data and Storage access requires authenticated identity and ownership.
- Admin access requires a distinct admin authorization check.

## Phase Overview

| Phase | Work packages | Purpose | Gate |
| --- | --- | --- | --- |
| Phase 0 - Firebase baseline | FB-1 | Add config, emulator, initial rules, and local validation harness. | Firebase local baseline runs before repository work. |
| Phase 1 - Contract foundation | FB-2, FB-3 | Represent the data contract in app models, repositories, auth profile, and role handling. | Role escalation is blocked before admin work. |
| Phase 2 - User data migration | FB-4 | Migrate project, dimensions, and source image upload paths to Firebase. | Project/image data exists before reconstruction. |
| Phase 3 - Reconstruction migration | FB-5 | Migrate job, transition, result, confirmed geometry, floor plan, and artifact metadata persistence. | Job/artifact data exists before layout and admin. |
| Phase 4 - Layout continuity | FB-6, FB-7 | Migrate layout save/load/export, then add IndexedDB draft/cache recovery. | Cloud layout basics exist before draft conflict UX. |
| Phase 5 - Operations and cutover | FB-8, FB-9 | Add Firebase-backed admin diagnostics and isolate the legacy API. | Admin depends on role plus job/artifact data. |
| Phase 6 - Readiness | FB-10 | Validate, document, and prepare for final epic/story generation. | Validation readiness must precede epics/stories. |

## Dependency Rules

- FB-1 must finish before any Firebase repository implementation.
- FB-2 must finish before feature migrations write production Firestore documents.
- FB-3 must finish before FB-8 admin features.
- FB-4 must finish before FB-5 reconstruction persistence.
- FB-5 must finish before FB-6 layout save/export and FB-8 admin diagnostics.
- FB-6 must finish before FB-7 draft/cache recovery.
- FB-8 must not start until role handling, job documents, artifact refs, and admin indexes are available.
- FB-10 must complete before `bmad-create-epics-and-stories`.

## Work Packages

### FB-1 - Firebase Baseline, Emulators, Rules Skeleton

**Goal:** Establish the Firebase default-backend baseline before any feature migration.

**Scope:**

- Add or verify Firebase CLI project configuration for Auth, Firestore, Storage, Hosting, and emulators.
- Add Firestore and Storage rules files with deny-by-default structure.
- Add local emulator configuration for Auth, Firestore, Storage, and Emulator UI.
- Add initial rules test harness structure.
- Document local startup commands and required environment variables.
- Keep existing app and editor projects in place; do not scaffold a new frontend.

**Inputs:**

- `docs/refactor/firebase-data-contract.md`
- `docs/refactor/firebase-target-architecture.md`
- `docs/refactor/firebase-backend-refactor-plan.md`

**Expected touched areas:**

- Firebase root configuration such as `firebase.json`, `.firebaserc`, `firestore.rules`, `storage.rules`, `firestore.indexes.json`.
- App Firebase config wiring under `app/`.
- Local documentation under `docs/`.
- Optional rules-test folder if the implementation chooses one.

**Acceptance criteria:**

- Firebase emulator configuration includes Auth, Firestore, Storage, and Emulator UI.
- Firestore and Storage rules deny unauthenticated access by default.
- Storage source image constraints include JPEG, PNG, WebP, and max 10 MB behavior in the planned rules/tests.
- Rules files include placeholders or implemented helper structure for ownership and admin role checks.
- The default backend mode is named or documented as `firebase`.
- `legacy_api` is documented as optional and explicit.

**Validation checks:**

- Firebase emulator startup command is documented and can be run locally.
- Rules test harness can execute at least a smoke test.
- A smoke test verifies unauthenticated Firestore and Storage reads are denied.
- Flutter config still builds or analyzes after Firebase package/config changes.

**Risks:**

- Firebase CLI setup can accidentally bind to the wrong project.
- Rules skeleton may become too permissive if smoke tests are skipped.
- Storage emulator behavior can differ from deployed Storage if content-type checks are not tested.

**Dependencies:**

- None.

**Out of scope:**

- Full repository migration.
- Full rules coverage for every collection.
- Admin UI implementation.
- Legacy server deletion.

### FB-2 - Data Contract Models, Serializers, and Repository Boundaries

**Goal:** Encode the Firebase data contract into app-level model, serializer, and repository boundaries before feature writes begin.

**Scope:**

- Create or update Dart domain models for user profile, project, source image, room dimensions, job, transition, OpenCV result, confirmed geometry, floor plan, layout, admin action, and artifact ref.
- Map Firestore/export `snake_case` fields to Dart `camelCase` fields.
- Define repository interfaces or concrete Firebase repository boundaries matching the data contract.
- Define bridge mapping helpers for editor `camelCase` payloads.
- Preserve Firestore string IDs across app models, bridge references, and exports.
- Add validation helpers for job statuses, coordinate spaces, content types, and schema versions.

**Inputs:**

- `docs/refactor/firebase-data-contract.md`
- `docs/refactor/firebase-target-architecture.md`
- Existing app/editor model and bridge code.

**Expected touched areas:**

- `app/lib/src/...` domain, data, repository, Firebase, and serialization folders.
- `app/test/...` model and serializer tests.
- Shared schema package under `packages/` only if the repo already uses or needs that boundary.
- Editor bridge types only when needed for contract alignment; no Firebase imports.

**Acceptance criteria:**

- Every Firestore path in the data contract has a corresponding app model or explicit deferred note.
- Persisted/exported field names are `snake_case`.
- Dart fields and editor bridge fields remain `camelCase`.
- Candidate geometry and confirmed geometry cannot be serialized as the same document type.
- `review_required` round-trips as a persisted status and maps to user label `Needs review`.
- Forbidden statuses such as `needs_review`, `done`, `complete`, and `error` are rejected by model-level validation before write.

**Validation checks:**

- Serializer tests verify `snake_case` Firestore/export payloads.
- Bridge mapping tests verify `camelCase` editor payloads.
- Model validation tests reject invalid status and coordinate-space values.
- Static analysis verifies editor code does not import Firebase SDKs.

**Risks:**

- Divergent model copies can create drift between Firestore, export JSON, and bridge payloads.
- Over-abstracted repositories can slow the refactor without reducing risk.
- Partial field coverage can cause later rules tests to fail.

**Dependencies:**

- FB-1 for Firebase package/config availability.
- Completed Firebase data contract.

**Out of scope:**

- Feature UI migration.
- Firestore write flows beyond focused serializer/repository tests.
- Final epic/story generation.

### FB-3 - Auth, User Profile Projection, and Privileged Role Handling

**Goal:** Make Firebase Auth and `users/{uid}` profile projection safe before project and admin migrations.

**Scope:**

- Ensure Google sign-in remains the user entry point.
- On sign-in, create or update allowed profile fields under `users/{uid}`.
- Preserve privileged role fields during normal profile updates.
- Block normal clients from writing `role`, `role_updated_at`, and `role_updated_by_uid`.
- Define the initial admin role bootstrap approach for local/dev and production.
- Add role-aware routing or guards for admin entry points, without building the admin diagnostic feature yet.

**Inputs:**

- `users/{uid}` contract in `docs/refactor/firebase-data-contract.md`
- Security rules behavior contract.
- PRD FR1-FR4 and NFR6-NFR10.

**Expected touched areas:**

- Flutter auth/session state under `app/lib/src/...`.
- User repository and auth repository.
- Firestore rules for `users/{uid}`.
- Rules tests for profile upsert and role escalation.
- Admin route guard or placeholder entry point.

**Acceptance criteria:**

- Signed-in users can create/update only their own non-privileged profile fields.
- Users cannot self-write, overwrite, or delete `role`.
- Existing role fields survive normal profile sync.
- Non-admin users are blocked from admin-only routes and data access.
- Admin bootstrap is documented and auditable enough for local implementation.

**Validation checks:**

- Rules tests pass for profile upsert, self-role escalation create, self-role escalation update, and non-admin admin access denial.
- Flutter auth tests cover signed-in, signed-out, and admin-required states where feasible.
- Manual emulator flow can sign in, create a user profile, and verify role behavior.

**Risks:**

- A naive merge/upsert can delete privileged role fields.
- Relying only on client route guards would not protect data.
- Admin bootstrap can become an undocumented manual step.

**Dependencies:**

- FB-1.
- FB-2 model and repository boundaries.

**Out of scope:**

- Full admin dashboard.
- Cloud Functions implementation unless selected as the explicit role-management bootstrap.
- Cross-user project reads beyond admin role smoke checks.

### FB-4 - Project, Room Dimensions, Source Image, and Storage Upload Migration

**Goal:** Move user-owned project, room dimension, and source image upload metadata flows to Firebase.

**Scope:**

- Implement Firebase-backed project create, list, open, update, and soft-delete where supported.
- Persist `room_dimensions/current` with metric units.
- Upload source images to the contracted Cloud Storage path.
- Persist source image metadata after Storage upload completes.
- Validate content type and size in Flutter before upload and in Storage rules where supported.
- Surface upload UX states from the UX spec: `Uploading`, `Uploaded`, retry, validation error, and permission failure.

**Inputs:**

- `projects`, `room_dimensions`, `source_images`, and source image Storage contracts.
- UX upload journey and Upload Progress Panel guidance.
- PRD FR5-FR14 and NFR6-NFR10.

**Expected touched areas:**

- `ProjectRepository`, `RoomDimensionsRepository`, `SourceImageRepository`, and upload/storage services.
- Project list/detail screens and room input/upload screens.
- Firestore and Storage rules for projects, dimensions, and source images.
- Firestore indexes for user project list.
- Emulator tests for owner/cross-owner project and Storage access.

**Acceptance criteria:**

- Users can create and list only their own projects.
- `owner_uid` is set on create and immutable after create.
- Room dimensions persist in meters.
- Source image uploads use `users/{uid}/projects/{project_id}/source-images/{source_image_id}/{filename}`.
- Source image metadata stores `storage_path`, content type, byte size, dimensions, SHA-256, owner, project, and timestamps per contract.
- User B cannot read or write User A project data or Storage objects.

**Validation checks:**

- Rules tests pass for owner project read/write, immutable owner, non-owner denial, source image upload allowed, invalid type denied, too large denied, cross-user Storage denied, and orphan project denial where implemented.
- Flutter tests cover project repository serialization and upload metadata persistence.
- Manual emulator flow creates a project, uploads a valid image, rejects invalid images, and reopens the project.

**Risks:**

- Upload can succeed while metadata write fails, creating orphan objects.
- Firestore rules cannot be treated as filters; queries must include owner constraints.
- Client-side SHA-256 and image dimension extraction may require async UX handling.

**Dependencies:**

- FB-1.
- FB-2.
- FB-3 for authenticated identity and ownership.

**Out of scope:**

- Reconstruction job processing.
- Layout save/load/export.
- Admin artifact diagnosis.

### FB-5 - Reconstruction Job, OpenCV Result, Geometry, and Floor Plan Migration

**Goal:** Persist the OpenCV-assisted reconstruction lifecycle and outputs in Firebase while preserving editor boundaries.

**Scope:**

- Create and update `reconstruction_jobs` documents with allowed statuses only.
- Append immutable `transitions` records for status changes.
- Persist `opencv_results` candidate geometry in `image_pixels`.
- Persist `confirmed_geometries` user-corrected geometry separately from candidates.
- Persist `floor_plans` in `meters`.
- Store artifact refs for overlays, calibration output, debug JSON, or generated artifacts as metadata.
- Replace default 5-second API polling with Firestore document streams where practical.
- Maintain OpenCV/manual-assisted processing in the editor/browser layer; Flutter persists results.

**Inputs:**

- Reconstruction, transition, OpenCV result, confirmed geometry, floor plan, and artifact contracts.
- UX reconstruction continuity states and `Needs review` language.
- PRD FR15-FR28 and NFR11-NFR17, NFR21-NFR25.

**Expected touched areas:**

- `ReconstructionRepository`, `GeometryRepository`, `FloorPlanRepository`, and artifact metadata helpers.
- Reconstruction workflow screens, status surfaces, and editor bridge integration.
- Firestore rules for jobs, transitions, results, confirmed geometry, and floor plans.
- Firestore indexes for project job timeline and admin-ready collection group queries.
- Editor bridge mapping, but not Firebase SDK usage.

**Acceptance criteria:**

- Jobs can be created and updated only under owned projects.
- Job statuses are restricted to the exact allowed vocabulary.
- `review_required` persists exactly and displays as `Needs review`.
- Transitions preserve status, timestamp, actor/source, reason code, human-readable reason, and retry linkage where available.
- Candidate geometry remains in `opencv_results`; user-confirmed geometry remains in `confirmed_geometries`.
- OpenCV result geometry uses `image_pixels`; floor plan geometry uses `meters`.
- Flutter persists outputs emitted by the editor without giving the editor Firebase access.

**Validation checks:**

- Rules tests pass for valid/invalid job statuses, OpenCV coordinate space, floor plan coordinate space, confirmed geometry separation, and cross-owner denial.
- Repository tests cover job lifecycle, transitions, failure reasons, retry linkage metadata, and result/floor-plan serialization.
- Editor build verifies no Firebase imports.
- Manual emulator flow runs a reconstruction path through candidate result, confirmation, calibration, and floor plan persistence.

**Risks:**

- Status vocabulary drift can break UX, admin, and export behavior.
- Realtime streams can overwrite active user edits if not gated by draft/conflict logic.
- Artifact metadata can point to Storage objects that rules do not allow the user/admin to read.

**Dependencies:**

- FB-4 project, image, and dimensions persistence.
- FB-2 model/serializer boundaries.

**Out of scope:**

- Layout save/load/export.
- Local draft conflict resolution.
- Full admin dashboard, except ensuring job data is queryable later.

### FB-6 - Layout Save, Load, Export, and Editor Bridge Persistence

**Goal:** Move layout persistence and JSON export to Firestore using the contracted layout schema.

**Scope:**

- Implement Firebase-backed layout save and load.
- Persist room dimensions, source metadata snapshot, floor plan snapshot/reference, editor scene state, and furniture objects.
- Generate JSON export from the latest saved layout.
- Preserve `snake_case` in Firestore and export JSON.
- Preserve `camelCase` in editor bridge payloads.
- Display save/export warnings when associated reconstruction status is `review_required`.
- Add visible persistence UX states: `Saving`, `Saved`, `Unsaved draft`, `Sync failed`, and `Retry available`.

**Inputs:**

- `layouts` contract.
- Editor bridge boundary contract.
- UX layout save/export journey and persistence status components.
- PRD FR29-FR40 and NFR1-NFR3, NFR20-NFR26.

**Expected touched areas:**

- `LayoutRepository` and export generation logic.
- Editor initialization/save bridge payload handling.
- Project editor shell, save controls, load flow, export flow, persistence status badge.
- Firestore rules for layouts.
- Layout serializer and round-trip tests.

**Acceptance criteria:**

- Users can save and load layouts only for owned projects.
- Saved layout preserves required room, source, floor plan, editor scene, and furniture fields.
- Export JSON uses the latest saved layout and `snake_case`.
- Editor bridge continues to use `camelCase`.
- Layout save/load round trip preserves required data except server-managed timestamps.
- Export warns visibly when reconstruction status is `review_required` and labels it as `Needs review`.

**Validation checks:**

- Rules tests pass for owner layout read/write, non-owner layout denial, layout invalid status denial, and valid round-trip write.
- Flutter tests cover layout save/load/export serialization.
- Editor build verifies bridge compatibility.
- Manual emulator flow saves a layout, reloads it, exports JSON, and compares core fields.

**Risks:**

- Export may accidentally mix bridge `camelCase` with persisted/export `snake_case`.
- Layout snapshots can become stale if floor plan or source metadata changes without clear version handling.
- Save UX can imply cloud save even when only local state exists.

**Dependencies:**

- FB-5 reconstruction/floor-plan data.
- FB-2 serializers and bridge mappings.

**Out of scope:**

- IndexedDB draft/cache conflict resolution beyond minimal unsaved-state signaling.
- Admin layout diagnostics.
- New furniture feature scope beyond preserving existing editor state.

### FB-7 - IndexedDB Draft/Cache Recovery and Cloud Conflict UX

**Goal:** Add local draft/cache recovery after cloud layout save/load works.

**Scope:**

- Implement `roomforge_drafts` IndexedDB database with `layout_drafts` and `project_cache` object stores.
- Store local drafts as recoverable state only, not as the system of record.
- Track draft project/layout IDs, local revision, base cloud revision, dirty state, conflict state, and timestamps.
- Present draft recovery and conflict choices: restore draft, discard draft, continue saved cloud state, or retry save.
- Ensure Firestore streams do not silently overwrite active local edits.

**Inputs:**

- IndexedDB draft/cache contract.
- UX Draft Recovery Banner and Cloud Draft Conflict Resolver guidance.
- Layout persistence from FB-6.

**Expected touched areas:**

- `DraftRepository` and local persistence service.
- Editor shell state, project reopen flow, conflict resolver UI, recovery banners.
- Project cache read path for recently opened projects.
- Tests for draft detection, restore, discard, and conflict state.

**Acceptance criteria:**

- Local drafts are clearly labeled as `Unsaved draft`, not cloud-saved layouts.
- A diverged cloud layout and local draft produce a user choice, not silent overwrite.
- Discarding a draft requires confirmation.
- Draft/cache state never becomes the source of truth for export unless it is saved to Firestore first.
- Recovery states work after refresh or navigation where feasible.

**Validation checks:**

- Unit tests cover draft save, restore, discard, dirty state, conflict detection, and cache invalidation.
- Manual browser flow verifies refresh recovery and conflict resolver behavior.
- Accessibility checks verify recovery actions are keyboard reachable and text-readable.

**Risks:**

- Draft conflict UX can confuse users if cloud and local states are not labeled consistently.
- IndexedDB schema changes can break old local drafts without migration handling.
- Overpromising offline behavior can create false product expectations.

**Dependencies:**

- FB-6 cloud layout save/load basics.

**Out of scope:**

- Full offline-first operation.
- Multi-device collaborative editing.
- Background sync beyond explicit retry/recovery behavior.

### FB-8 - Firebase-Backed Admin Diagnostics and Retry

**Goal:** Rebuild admin/support diagnostics on Firebase data after role, job, artifact, and layout data exist.

**Scope:**

- Implement admin route guard and Firebase-backed `AdminRepository`.
- Support admin collection group queries for jobs by status, owner, project, retry source, results by job, layouts by owner, transitions by job, and admin actions by target.
- Show job status, owner/project/job references, provider state, artifact availability, failure reason, retry count, transition history, and permission outcome.
- Allow admin retry by creating a linked retry job and an auditable `admin_actions` record.
- Allow admin artifact read for troubleshooting where Storage rules permit it.
- Distinguish non-admin denied, stale role, missing artifact, restricted artifact, and missing data states.

**Inputs:**

- Admin role and action contracts.
- Admin collection group index candidates.
- UX admin troubleshooting and admin pattern guidance.
- PRD FR4, FR41-FR50 and NFR8, NFR13, NFR15, NFR19.

**Expected touched areas:**

- `AdminRepository`, admin screens, admin route guards, admin tables/detail pages.
- Firestore rules for admin reads and `admin_actions`.
- Storage rules for admin artifact reads.
- Firestore index definitions for admin query shapes.
- Rules and repository tests for admin/non-admin behavior.

**Acceptance criteria:**

- Non-admin users cannot access admin data or admin actions.
- Admin users can inspect job details, transitions, result metadata, layout references, artifact refs, and retry history.
- Admin retry creates a new job linked to the previous job and records an `admin_actions` entry.
- Admin writes to user/project data are avoided unless explicitly covered by auditable action records.
- Admin UI does not expose protected data to unauthorized users through loading, empty, or error states.

**Validation checks:**

- Rules tests pass for non-admin denied, admin job read, admin action create, non-admin collection-group denial, artifact admin read, and cross-user denial.
- Repository tests cover collection group query shapes and missing-index failure handling where feasible.
- Manual emulator flow verifies admin and non-admin accounts.
- Accessibility check covers keyboard navigation in admin filters/tables.

**Risks:**

- Admin collection group queries can fail if indexes are missing.
- Rules that allow admin reads can accidentally broaden normal user access.
- Retry actions can create inconsistent job chains if root/retry fields are not handled atomically enough.

**Dependencies:**

- FB-3 role handling.
- FB-5 job/result/artifact data.
- FB-6 layout data.

**Out of scope:**

- Rich provider operations for future GPU providers beyond placeholder/status compatibility.
- Bulk admin mutation tools.
- Public support portal.

### FB-9 - Legacy API Isolation and Firebase Cutover

**Goal:** Make Firebase the default application path while preserving legacy FastAPI/Oracle as explicit reference or fallback code.

**Scope:**

- Introduce or finalize backend mode selection with default `firebase`.
- Move legacy API clients behind explicit `legacy_api` configuration.
- Remove HTTP-first `ProjectApi` and `AdminApi` usage from the default app path.
- Mark legacy API envelope rules as legacy-only.
- Keep server code, migrations, and old tests in place unless a later cleanup story explicitly removes them.
- Update runtime documentation so developers know which path is default.

**Inputs:**

- Firebase backend refactor plan.
- Target architecture legacy isolation decisions.
- Completed Firebase repositories from FB-3 through FB-8.

**Expected touched areas:**

- App configuration and service wiring.
- Legacy API adapter or compatibility layer.
- Documentation for environment variables, local run modes, and validation commands.
- Tests that assert default mode does not call legacy API clients.

**Acceptance criteria:**

- New development and validation use Firebase by default.
- Legacy API code remains reachable only through explicit `legacy_api` mode.
- Default user, project, upload, reconstruction, layout, export, and admin flows no longer depend on FastAPI/Oracle.
- No source document or app UI claims Oracle/FastAPI is still the default backend.
- Legacy server deletion is not part of this work package.

**Validation checks:**

- App tests or integration smoke tests verify Firebase repositories are selected by default.
- Legacy API mode can be toggled only explicitly.
- Documentation search confirms default-path language points to Firebase.
- Legacy server tests are run only if this package changes server code.

**Risks:**

- Hidden default-path calls can continue to hit legacy API clients.
- Removing legacy assumptions too aggressively can break useful reference tests.
- Documentation may diverge from runtime configuration.

**Dependencies:**

- FB-3 through FB-8 enough to support default feature flows.

**Out of scope:**

- Oracle-to-Firebase historical data migration.
- Deleting `server/`.
- Production decommissioning procedures.

### FB-10 - Validation, Documentation, and Implementation Readiness Gate

**Goal:** Prove the Firebase refactor plan is ready for epic/story generation and implementation sequencing.

**Scope:**

- Create or finalize `docs/refactor/firebase-validation-plan.md`.
- Convert rules test matrix candidates into concrete emulator test coverage expectations.
- Confirm validation commands for Flutter, editor, Firebase emulators, and legacy server conditional checks.
- Update documentation indexes or refactor overview docs so future agents find the correct source artifacts.
- Run or document readiness validation against PRD, UX, architecture, data contract, and this workplan.
- Prepare story-generation guidance for `bmad-create-epics-and-stories`.

**Inputs:**

- `docs/refactor/firebase-data-contract.md`
- `docs/refactor/firebase-target-architecture.md`
- `docs/refactor/firebase-ux-design-specification.md`
- This workplan
- Existing agent and validation docs where applicable.

**Expected touched areas:**

- `docs/refactor/firebase-validation-plan.md`
- Documentation indexes or README files.
- Optional readiness report under `docs/refactor/`.
- No production code unless a validation script already exists and needs minimal documentation wiring.

**Acceptance criteria:**

- Validation plan covers emulator rules tests, repository/model tests, editor boundary checks, layout round trip, admin role checks, and manual Firebase flows.
- Story-generation guidance maps FB packages into story candidates without generating final stories yet.
- Open gaps are explicit and do not contradict the data contract or architecture.
- Parent readiness review can decide whether to proceed to epics/stories.

**Validation checks:**

- Document review confirms every work package has validation coverage.
- Traceability review confirms PRD FR1-FR50 and relevant NFRs are covered or explicitly out of scope for Firebase refactor.
- Invariant review confirms no package asks the editor to import Firebase or the legacy API to remain default.

**Risks:**

- Skipping this gate can produce stories that fight over schema, rules, or ordering.
- Validation plan can become too broad if it includes post-MVP features.
- Documentation updates can accidentally overwrite older product docs instead of marking Firebase-specific refactor docs.

**Dependencies:**

- This workplan.
- Completed data contract, target architecture, and UX specification.

**Out of scope:**

- Final epics and stories.
- Code implementation.
- PR creation or remote push.

## Migration and Cutover Strategy

The Firebase refactor is a default-path cutover, not a destructive legacy deletion.

1. Start with local Firebase baseline and emulator validation.
2. Implement Firebase models and repositories alongside existing legacy API clients.
3. Migrate feature flows in dependency order: auth/users, projects/images, reconstruction, layouts/drafts, admin.
4. Keep legacy API clients behind `legacy_api` mode while Firebase becomes the default.
5. Stop using legacy FastAPI/Oracle in default app routing, repositories, and validation.
6. Keep `server/` as inactive reference code until a later cleanup decision.
7. Do not attempt Oracle-to-Firebase historical data migration for demo data in this workplan.

Cutover is complete when the default app path can support sign-in, project list/create/open, image upload, reconstruction state/result persistence, layout save/load/export, and admin diagnostics through Firebase without requiring the legacy server.

## Documentation Update Tasks

- Add `docs/refactor/firebase-validation-plan.md` after this workplan.
- Update any refactor overview or docs index to point to:
  - `docs/refactor/firebase-backend-refactor-plan.md`
  - `docs/refactor/firebase-ux-design-specification.md`
  - `docs/refactor/firebase-target-architecture.md`
  - `docs/refactor/firebase-data-contract.md`
  - `docs/refactor/firebase-refactor-workplan.md`
  - `docs/refactor/firebase-validation-plan.md`
- Mark old API envelope guidance as legacy-only where Firebase direct SDK access is documented.
- Document `firebase` as the default backend mode and `legacy_api` as explicit legacy mode.
- Add local emulator setup and validation commands to the relevant developer docs.
- After epics/stories are generated, link each story back to its FB package and source requirements.

## Story-Generation Guidance

Do not generate final epics/stories from this document alone until the validation plan exists.

When `bmad-create-epics-and-stories` runs, use these rules:

- Preserve FB package order unless a story is documentation-only and has no implementation dependency.
- Split FB-1 through FB-3 into baseline stories before any feature migration.
- Split FB-4, FB-5, and FB-6 by user-visible flow and repository boundary.
- Keep FB-7 after layout save/load basics.
- Keep FB-8 after job, artifact, and layout data exist.
- Keep FB-9 as cutover/isolation stories after Firebase feature parity is proven.
- Keep FB-10 as validation/readiness stories before implementation starts or as the final planning gate, depending on how the backlog is organized.
- Each story must include acceptance criteria, emulator/rules validation, and invariant checks.
- No story should ask the editor to import Firebase SDKs.
- No story should make `legacy_api` the default path.

## Work Package to Requirement Mapping

| Work package | Primary PRD features | Primary NFRs | Firebase refactor features |
| --- | --- | --- | --- |
| FB-1 | Deployment/auth foundation | NFR6-NFR10 | Firebase config, emulator, rules baseline. |
| FB-2 | Cross-cutting data integrity | NFR20-NFR23 | Data contract models, serializers, repository boundaries. |
| FB-3 | FR1-FR4 | NFR6-NFR10 | Auth profile projection, role protection, admin guard baseline. |
| FB-4 | FR5-FR14 | NFR1, NFR6-NFR10, NFR24 | Project CRUD, room dimensions, Storage upload, source image metadata. |
| FB-5 | FR15-FR28 | NFR4-NFR5, NFR11-NFR17, NFR21-NFR25 | Jobs, transitions, OpenCV results, confirmed geometry, floor plans, artifacts. |
| FB-6 | FR29-FR40 | NFR1-NFR3, NFR20-NFR26 | Layout save/load/export, editor bridge mapping, persistence status. |
| FB-7 | FR37-FR40 | NFR20-NFR26 | IndexedDB draft/cache, recovery, conflict resolver. |
| FB-8 | FR4, FR41-FR50 | NFR8, NFR13, NFR15, NFR19 | Admin repository, collection group queries, retry, admin actions, artifact diagnosis. |
| FB-9 | Default-path product continuity | NFR6-NFR10, NFR16-NFR18 | Firebase default cutover, legacy API isolation. |
| FB-10 | Planning readiness | All relevant Firebase validation NFRs | Validation plan, readiness report, story-generation gate. |

## Package Readiness Checklist

Before implementation stories are generated:

- [ ] `firebase-validation-plan.md` exists and covers all FB packages.
- [ ] Firestore rules behavior and Storage rules behavior have emulator test candidates mapped to packages.
- [ ] Repository boundaries are agreed for Flutter.
- [ ] Editor bridge mapping rules are agreed for `camelCase` payloads.
- [ ] Admin role bootstrap approach is documented.
- [ ] Legacy API isolation strategy is documented.
- [ ] Documentation updates are assigned to explicit stories or work packages.

## Follow-Up Workflow

The next workflow artifact should be `docs/refactor/firebase-validation-plan.md`. After that, run the epics/stories workflow and implementation readiness validation using PRD, UX, architecture, data contract, workplan, and validation plan together.

## Parent Validation Record

Validated on 2026-05-24.

- Result: APPROVE.
- Sequence check: The work packages preserve the required dependency order from Firebase baseline through data models, auth/role, project/image, reconstruction, layout/draft, admin, cutover, and validation.
- Scope check: Each package includes goal, scope, inputs, expected touched areas, acceptance criteria, validation checks, risks, dependencies, and out-of-scope boundaries.
- Invariant check: Flutter remains the Firebase owner, the editor remains Firebase-free, `legacy_api` is explicit only, field casing boundaries are preserved, candidate/confirmed geometry stays separated, and the exact job status vocabulary is maintained.
- Follow-up dependency: The validation plan can now use FB-1 through FB-10 as the coverage map.
