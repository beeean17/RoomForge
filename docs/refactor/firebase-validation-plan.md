---
title: "RoomForge Firebase Validation Plan"
status: "complete"
created: "2026-05-24"
updated: "2026-05-24"
completedAt: "2026-05-24"
workflowType: "validation-plan"
stepsCompleted:
  - "step-01-source-analysis"
  - "step-02-validation-strategy"
  - "step-03-coverage-map"
  - "step-04-parent-validation"
lastStep: 4
inputDocuments:
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
  - "architecture-follow-up"
---

# Firebase Validation Plan - RoomForge Refactor

This document defines validation coverage for the RoomForge Firebase refactor before epics and stories are generated. It converts the Firebase data contract, target architecture, UX specification, backend refactor plan, and FB-1 through FB-10 work packages into testable gates.

This plan does not generate epics or stories. Its purpose is to make future stories consistent about validation expectations, especially for Firestore schema, Security Rules, Storage Rules, editor boundaries, layout round trips, admin authorization, and legacy API isolation.

## Validation Goals

- Prove Firebase can become the default backend path without weakening authentication, ownership, admin authorization, or private image/layout storage.
- Prevent schema drift between Firestore `snake_case`, Dart `camelCase`, editor bridge `camelCase`, and export JSON `snake_case`.
- Validate that the editor remains a spatial computation and rendering layer, not a Firebase persistence layer.
- Convert the data contract rules test matrix into concrete emulator test IDs that future stories can implement.
- Ensure every FB work package has validation coverage before `bmad-create-epics-and-stories`.
- Preserve user-facing continuity states from the UX specification: `Uploading`, `Uploaded`, `Saving`, `Saved`, `Unsaved draft`, `Sync failed`, `Retry available`, `Permission required`, and `Needs review`.

## Scope

### In Scope

- Static checks and source-boundary checks.
- Flutter unit, widget, repository, model, serializer, and export tests.
- Firebase emulator tests for Auth, Firestore Rules, Storage Rules, and index/query assumptions.
- Manual emulator flows for user, admin, upload, reconstruction, layout, draft recovery, and cutover behavior.
- Editor build and import-boundary validation.
- Accessibility checks for non-canvas controls and admin tables.
- Documentation traceability from PRD, UX, architecture, data contract, workplan, and validation plan to future stories.

### Out of Scope

- Final epics and stories.
- Production deployment certification.
- Oracle-to-Firebase historical data migration.
- Cloud Functions implementation details unless a later story chooses Cloud Functions for privileged role management.
- Full offline-first synchronization or collaborative editing.
- Deleting the legacy `server/` path.

## Validation Principles

1. Contract first: every test should trace to the data contract or a Firebase work package.
2. Emulator first: Firestore and Storage authorization must be proven with local emulator tests before manual UI confidence is accepted.
3. Negative tests are mandatory: every allowed owner/admin path needs corresponding unauthenticated, non-owner, or non-admin denial coverage.
4. UI checks do not replace rules: Flutter route guards and admin UI checks are helpful, but Security Rules must enforce access.
5. The editor boundary is a validation gate: any Firebase SDK import or direct Firestore/Storage access in `editor/` is a failure.
6. Legacy is explicit only: default validation must not require FastAPI, Oracle, or the legacy HTTP API.
7. Accessibility is part of Firebase UX: save, upload, draft, permission, and admin states must remain accessible in Flutter UI.

## Validation Layers

| Layer | Name | Purpose | Primary packages |
| --- | --- | --- | --- |
| L0 | Document and traceability review | Confirm source artifacts agree before story generation. | FB-10 |
| L1 | Static and boundary checks | Analyze app/editor code, forbidden imports, and default backend wiring. | FB-1, FB-2, FB-6, FB-9 |
| L2 | Model, serializer, and repository tests | Prove `snake_case` persistence/export, `camelCase` bridge mapping, validation helpers, and repository behavior. | FB-2 through FB-8 |
| L3 | Firebase emulator rules tests | Prove Firestore and Storage auth, owner, admin, status, coordinate, and file constraints. | FB-1, FB-3 through FB-8 |
| L4 | Integration and manual emulator flows | Exercise the product path through Firebase locally. | FB-3 through FB-9 |
| L5 | Accessibility and usability checks | Verify persistence, permission, recovery, and admin controls are usable without relying on canvas-only states. | FB-4, FB-6, FB-7, FB-8 |
| L6 | Readiness gate | Decide if epics/stories can be generated without unresolved validation contradictions. | FB-10 |

## Expected Local Tools

| Tool | Used for | Required by | Fallback if missing |
| --- | --- | --- | --- |
| Flutter SDK | `flutter analyze`, `flutter test`, app widget/unit tests. | FB-1 through FB-9 | Record environment gap; run document/static checks that do not require Flutter. Implementation stories cannot be marked complete without a Flutter-capable validation path. |
| Dart SDK | Pure Dart model, serializer, and repository tests where separated from Flutter. | FB-2 through FB-8 | Use Flutter test runner when available. |
| Node.js/npm | Editor build/tests and possible Firebase rules test harness. | FB-1, FB-5, FB-6 | Use documented alternate harness if the repo chooses one; otherwise record environment gap. |
| Firebase CLI | Emulators, rules test execution, rules deployment dry run where applicable. | FB-1, FB-3 through FB-8 | Without CLI, rules behavior remains unverified and FB-1 cannot pass. |
| Firebase Emulator Suite | Auth, Firestore, Storage, Emulator UI. | FB-1 through FB-8 | No substitute for rules authorization. Manual review is not enough. |
| ripgrep | Forbidden import checks and documentation traceability. | FB-2, FB-6, FB-9, FB-10 | Use another search tool if unavailable. |
| Browser/devtools or in-app browser | Manual emulator flows, layout round trip, accessibility smoke checks. | FB-4 through FB-8 | Record limitation; keep automated checks as the minimum. |

## Command Candidates

These are command candidates. Implementation stories may refine paths after the actual test harness is added.

```bash
firebase --version
firebase emulators:start --only auth,firestore,storage
firebase emulators:exec --only auth,firestore,storage "<rules-test-command>"
```

```bash
cd app
flutter analyze
flutter test
```

```bash
cd editor
npm install
npm run build
npm test
```

```bash
rg -n "firebase|cloud_firestore|firebase_storage|@firebase|firestore|storage\\(" editor/src editor/package.json
rg -n "ProjectApi|AdminApi|legacy_api" app/lib app/test docs/refactor
rg -n "needs_review|done|complete|error" app/lib app/test editor/src docs/refactor
```

Expected behavior:

- Missing local tools are environment limitations, not product validation passes.
- If a required tool is missing, the story report must state which validation layer was not executed and why.
- For story completion, a missing tool can be acceptable only when the story did not modify that boundary and another validation layer still proves the acceptance criteria.
- FB-1 cannot be considered complete without a working Firebase emulator validation path.

## Rules Test Categories and IDs

The following IDs convert the data contract rules matrix into concrete validation categories. Future implementation stories should add emulator tests using these IDs or equivalent names.

### Firestore Owner and Project Access

| Test ID | Source matrix ID | Actor | Expected | Packages |
| --- | --- | --- | --- | --- |
| `fs-project-owner-read-allow` | `rules-owner-project-read` | Owner reads own project. | Allow | FB-4 |
| `fs-project-owner-create-allow` | `rules-owner-project-write` | Owner creates project with `owner_uid == uid`. | Allow | FB-4 |
| `fs-project-owner-immutable-deny` | `rules-project-owner-immutable` | Owner attempts to change `owner_uid`. | Deny | FB-4 |
| `fs-project-non-owner-read-deny` | `rules-non-owner-project-read` | User B reads User A project. | Deny | FB-4 |
| `fs-layout-non-owner-read-deny` | `rules-non-owner-layout-read` | User B reads User A layout. | Deny | FB-6 |

### Firestore Layout, Status, and Round Trip

| Test ID | Source matrix ID | Actor | Expected | Packages |
| --- | --- | --- | --- | --- |
| `fs-layout-owner-roundtrip-write-allow` | `rules-owner-layout-roundtrip-write` | Owner writes required layout fields. | Allow | FB-6 |
| `fs-layout-invalid-status-deny` | `rules-layout-invalid-status` | Owner writes `reconstruction_status: "done"`. | Deny | FB-6 |
| `model-layout-save-load-export-roundtrip` | Added from workplan | Save, load, and export preserve required room, source, floor plan, scene, and furniture fields. | Pass | FB-6 |
| `model-layout-export-snake-case` | Added from architecture | Export JSON uses `snake_case`, not bridge `camelCase`. | Pass | FB-6 |
| `ui-layout-review-required-warning` | Added from UX/PRD | `review_required` exports show `Needs review` warning before save/export. | Pass | FB-6 |

### Firestore Job Status and Coordinate Space

| Test ID | Source matrix ID | Actor | Expected | Packages |
| --- | --- | --- | --- | --- |
| `fs-job-valid-status-review-required-allow` | `rules-job-valid-status` | Owner writes `status: "review_required"`. | Allow | FB-5 |
| `fs-job-invalid-status-needs-review-deny` | `rules-job-invalid-status` | Owner writes `status: "needs_review"`. | Deny | FB-5 |
| `model-job-forbidden-statuses-deny` | Added from data invariant | Model validation rejects `needs_review`, `done`, `complete`, and `error`. | Pass | FB-2, FB-5 |
| `fs-opencv-image-pixels-allow` | `rules-opencv-coordinate-space` | Owner writes OpenCV result with `image_pixels`. | Allow | FB-5 |
| `fs-opencv-meters-deny` | `rules-opencv-wrong-coordinate-space` | Owner writes OpenCV result with `meters`. | Deny | FB-5 |
| `fs-floor-plan-meters-allow` | `rules-floor-plan-coordinate-space` | Owner writes floor plan with `meters`. | Allow | FB-5 |
| `fs-confirmed-geometry-image-pixels-allow` | Added from contract | Owner writes confirmed geometry with `image_pixels`. | Allow | FB-5 |
| `fs-confirmed-geometry-meters-deny` | Added from contract | Owner writes confirmed geometry with `meters`. | Deny | FB-5 |

### Candidate and Confirmed Geometry Separation

| Test ID | Source matrix ID | Actor | Expected | Packages |
| --- | --- | --- | --- | --- |
| `fs-confirmed-geometry-shape-allow` | `rules-confirmed-geometry-separation` | Owner writes confirmed geometry under `confirmed_geometries`. | Allow | FB-5 |
| `fs-candidate-confirmed-mix-deny` | `rules-candidate-confirmed-mix` | Owner writes candidate-only result shape under `confirmed_geometries`. | Deny where required fields/intent validation is implemented | FB-5 |
| `serializer-candidate-confirmed-distinct` | Added from architecture | Serializers cannot encode candidate geometry as confirmed geometry or the reverse. | Pass | FB-2, FB-5 |
| `bridge-candidate-confirmed-distinct` | Added from editor boundary | Bridge payloads keep `candidateGeometry` and `confirmedGeometry` separate. | Pass | FB-5 |

### User Profile and Admin Role

| Test ID | Source matrix ID | Actor | Expected | Packages |
| --- | --- | --- | --- | --- |
| `fs-user-profile-upsert-allow` | `rules-user-profile-upsert` | User creates own profile without `role`. | Allow | FB-3 |
| `fs-user-role-self-create-deny` | `rules-self-role-escalation-create` | User creates own profile with `role: "admin"`. | Deny | FB-3 |
| `fs-user-role-self-update-deny` | `rules-self-role-escalation-update` | User updates own `role` to `admin`. | Deny | FB-3 |
| `repo-user-profile-update-preserves-role` | Added from architecture review | Normal profile update preserves existing `role`, `role_updated_at`, and `role_updated_by_uid`. | Pass | FB-3 |
| `fs-admin-non-admin-actions-read-deny` | `rules-non-admin-admin-actions-read` | Normal user reads `admin_actions`. | Deny | FB-8 |
| `fs-admin-actions-create-allow` | `rules-admin-admin-actions-create` | Admin creates `admin_actions` record. | Allow | FB-8 |
| `fs-admin-actions-update-deny` | Added from contract | Admin or non-admin attempts to update existing `admin_actions`. | Deny | FB-8 |
| `fs-admin-actions-delete-deny` | Added from contract | Admin or non-admin attempts to delete existing `admin_actions`. | Deny | FB-8 |
| `fs-admin-job-cg-read-allow` | `rules-admin-job-read` | Admin collection-group reads jobs. | Allow | FB-8 |
| `fs-admin-non-admin-job-cg-read-deny` | `rules-non-admin-job-cg-read` | Normal user collection-group reads other users' jobs. | Deny | FB-8 |

### Storage Source Images

| Test ID | Source matrix ID | Actor | Expected | Packages |
| --- | --- | --- | --- | --- |
| `st-source-owner-upload-allow` | `rules-storage-source-owner-upload` | Owner uploads JPEG, PNG, or WebP <= 10 MB to own path. | Allow | FB-4 |
| `st-source-invalid-type-deny` | `rules-storage-source-invalid-type` | Owner uploads disallowed content type. | Deny | FB-4 |
| `st-source-too-large-deny` | `rules-storage-source-too-large` | Owner uploads source image > 10 MB. | Deny | FB-4 |
| `st-source-cross-user-deny` | `rules-storage-source-cross-user` | User B reads or writes User A source image path. | Deny | FB-4 |
| `st-source-path-uid-mismatch-deny` | Added from storage contract | Auth UID does not match `users/{uid}` path segment. | Deny | FB-4 |
| `st-source-orphan-project-deny` | `rules-storage-orphan-project` | User uploads under a project ID not owned by path UID. | Deny where project lookup, metadata handshake, or reservation is implemented | FB-4 |
| `repo-source-metadata-after-upload` | Added from upload process | Storage upload success is followed by source image metadata write with matching `storage_path`. | Pass | FB-4 |
| `ui-source-metadata-save-failed-recovery` | Added from UX | Metadata write failure shows retry/cleanup recovery instead of treating upload as complete. | Pass | FB-4 |

### Storage Artifacts

| Test ID | Source matrix ID | Actor | Expected | Packages |
| --- | --- | --- | --- | --- |
| `st-artifact-owner-read-allow` | `rules-storage-artifact-owner-read` | Owner reads own project artifact. | Allow | FB-5, FB-8 |
| `st-artifact-admin-read-allow` | `rules-storage-artifact-admin-read` | Admin reads user artifact for troubleshooting. | Allow | FB-8 |
| `st-artifact-non-admin-cross-user-deny` | `rules-storage-artifact-non-admin-cross-user` | Normal user reads another user's artifact. | Deny | FB-8 |
| `st-artifact-invalid-type-deny` | Added from storage contract | Artifact write uses content type outside image/JSON allowlist. | Deny | FB-5 |
| `st-artifact-public-list-deny` | Added from storage contract | Unauthenticated or broad prefix list attempt. | Deny | FB-5, FB-8 |
| `admin-artifact-state-mapping` | Added from UX | Admin UI maps artifact read attempts to `available`, `restricted`, `missing`, `failed_to_load`, or `not_generated`. | Pass | FB-8 |

## Model, Serializer, and Repository Validation

### Required Model Tests

- Firestore document IDs are strings and round-trip through app models.
- Durable Firestore payloads use `snake_case`.
- Dart models expose `camelCase`.
- Export JSON uses `snake_case`.
- Editor bridge payloads use `camelCase`.
- `job_status` accepts only `created`, `uploading`, `processing`, `review_required`, `succeeded`, `failed`, `timeout`, `cancelled`, and `retrying`.
- `job_status` rejects `needs_review`, `done`, `complete`, and `error`.
- `coordinate_space` accepts only `image_pixels` and `meters`.
- `opencv_results` and `confirmed_geometries` require `image_pixels`.
- `floor_plans` and `layouts` require `meters`.
- Candidate geometry and confirmed geometry use separate model types and serializers.
- `artifact_refs[].storage_path` matches contracted artifact paths.
- `source_images.storage_path` matches contracted source image paths.
- `users/{uid}.role` is not overwritten by normal profile projection.

### Required Repository Tests

- `UserRepository` profile sync writes only non-privileged profile fields and preserves existing role fields.
- `ProjectRepository` queries include `owner_uid` constraints where required.
- `SourceImageRepository` writes metadata only after Storage upload success or marks metadata-save failure distinctly.
- `ReconstructionRepository` records jobs and transitions with allowed statuses and retry linkage.
- `GeometryRepository` persists candidate and confirmed geometry to separate collections.
- `FloorPlanRepository` persists calibrated floor plans in meters.
- `LayoutRepository` save/load/export preserves required fields except server-managed timestamps.
- `DraftRepository` treats IndexedDB as local draft/cache only and never as cloud source of truth.
- `AdminRepository` uses admin-gated collection group query shapes and handles missing-index failures explicitly.

## Editor Boundary Validation

Editor validation is required whenever FB-2, FB-5, FB-6, FB-7, or FB-9 touches bridge, editor, or persistence wiring.

Required checks:

- No Firebase SDK imports in `editor/`.
- No direct Firestore, Storage, Auth, or Firebase config references in `editor/`.
- Editor bridge payloads use `camelCase`.
- Flutter is responsible for mapping editor `camelCase` to Firestore/export `snake_case`.
- Editor receives IDs and spatial context only, not Firebase credentials or Storage URLs as authorization authority.
- Editor build succeeds after bridge/model changes.
- Active editor state is not silently overwritten by Firestore streams when a local draft exists.

Suggested forbidden import search:

```bash
rg -n "firebase|cloud_firestore|firebase_storage|@firebase|Firestore|StorageReference|FirebaseAuth" editor/src editor/package.json
```

## Layout Round-Trip Validation

Layout round-trip validation is mandatory for FB-6 and remains a regression suite for FB-7 through FB-9.

The canonical round trip:

1. Create an owned project.
2. Attach source image metadata.
3. Persist room dimensions in meters.
4. Persist a `review_required` or `succeeded` reconstruction job.
5. Persist confirmed geometry in `image_pixels`.
6. Persist floor plan in `meters`.
7. Save a layout with room dimensions, source metadata, floor plan snapshot, editor scene, and furniture objects.
8. Load the layout.
9. Export JSON from the latest saved layout.
10. Compare required fields, ignoring server-managed timestamps.

Assertions:

- Saved layout includes `layout_id`, `project_id`, `owner_uid`, `source_image_id`, `reconstruction_job_id`, `reconstruction_status`, `review_required`, `floor_plan_id`, `coordinate_space`, `room_dimensions`, `source_metadata`, `floor_plan`, `editor_scene`, `furniture_objects`, `schema_version`, and `export_version`.
- `furniture_objects[]` preserves `furniture_id`, `category`, `position_m`, `size_m`, `rotation_deg`, and optional `color`, `label`, and `locked`.
- Firestore and export JSON use `snake_case`.
- Editor bridge input/output remains `camelCase`.
- Export uses the latest saved Firestore layout, not an unsaved IndexedDB draft.
- If `reconstruction_status == "review_required"`, persisted status remains `review_required`, export warns, and user-facing text says `Needs review`.

## Manual Emulator Flows

Manual flows are not substitutes for rules tests, but they validate product integration and UX state continuity.

### MEF-1 Auth and Profile

- Start Auth, Firestore, and Storage emulators.
- Sign in as User A.
- Create or sync `users/{uid}` without `role`.
- Confirm app treats the user as non-admin.
- Seed or bootstrap an admin user through the selected trusted path.
- Confirm admin route access only after role is present.

### MEF-2 Project, Dimensions, and Upload

- User A creates a project.
- User A enters metric room dimensions.
- User A uploads a valid JPEG, PNG, or WebP <= 10 MB.
- Source image metadata appears after upload.
- Invalid type and oversized file show recoverable upload validation states.
- User B cannot open or read User A project or Storage path.

### MEF-3 Reconstruction and Geometry

- User A creates a reconstruction job.
- Job status moves through allowed states only.
- OpenCV candidate results persist in `opencv_results` with `image_pixels`.
- User confirmation persists in `confirmed_geometries` with `image_pixels`.
- Floor plan persists in `floor_plans` with `meters`.
- `review_required` displays as `Needs review`.

### MEF-4 Layout Save, Load, and Export

- User A saves a layout with furniture objects.
- User A reloads the project and sees the saved layout.
- Export JSON is generated from the saved Firestore layout.
- Export preserves required fields and uses `snake_case`.
- A `review_required` layout shows a visible `Needs review` warning.

### MEF-5 Draft and Conflict Recovery

- User A edits a layout and creates an `Unsaved draft`.
- Refresh or navigate away and return.
- App offers restore/discard/continue saved version where appropriate.
- Firestore remote updates do not silently overwrite the active local draft.
- Discarding a draft requires confirmation.

### MEF-6 Admin Diagnostics and Retry

- Non-admin user is denied admin route/data without protected data leakage.
- Admin user searches jobs by status, owner, project, and job ID.
- Admin can inspect job detail, transitions, artifact refs, retry history, and permission outcome.
- Admin artifact read shows `available`, `restricted`, `missing`, `failed_to_load`, or `not_generated`.
- Admin retry creates a linked retry job and an append-only `admin_actions` document.

### MEF-7 Legacy Isolation

- Default app mode is `firebase`.
- Default sign-in, project, upload, reconstruction, layout, export, and admin flows do not require FastAPI or Oracle.
- `legacy_api` is available only through explicit configuration.
- Documentation and UI do not claim Oracle/FastAPI is the default backend.

## Accessibility Validation

Accessibility checks apply to Flutter-controlled UI, not raw Three.js canvas internals. Canvas/editor controls still need best-effort visible selection, non-color-only states, reset/preset controls, textual summaries where feasible, and recovery paths.

Minimum checks:

- Save, draft, sync, upload, permission, and `Needs review` states are text-readable.
- State changes are announced or reachable by assistive technology where feasible.
- Keyboard users can sign in, create project, retry upload, save again, restore/discard draft, export, refresh role, and navigate admin tables.
- Admin filters, tables, row actions, detail panels, and retry dialogs maintain visible focus.
- Destructive actions such as discard draft, delete project, or admin retry require explicit confirmation.
- Persistence and permission states are also available in Flutter UI, not only inside the Three.js canvas.

Suggested checks:

- Widget tests for labels, buttons, and semantic text on persistence components.
- Keyboard-only manual pass for upload, save/export, draft recovery, and admin table flows.
- Visual review at desktop and tablet breakpoints for stable placement of save/draft/sync indicators.

## FB Work Package Coverage Map

| Work package | Required validation coverage | Minimum go criteria |
| --- | --- | --- |
| FB-1 Firebase Baseline | Firebase CLI/emulator startup, deny-by-default rules smoke tests, unauthenticated Firestore/Storage denial, Flutter config build/analyze. | Auth, Firestore, Storage emulators run locally; at least one Firestore and one Storage denial test pass. |
| FB-2 Data Contract Models | Model/serializer tests, status/coordinate validators, `snake_case`/`camelCase` mapping, editor forbidden import check. | Every data contract path has model or explicit deferment; invalid statuses and coordinate spaces are rejected. |
| FB-3 Auth and Role | Profile upsert, role preservation, role self-write denial, non-admin denied, admin allowed, admin bootstrap documentation. | Normal users cannot create/update/delete `role`; admin checks are rules-backed. |
| FB-4 Projects and Upload | Owner/non-owner Firestore tests, Storage type/size/path/ownership tests, orphan mitigation test where implemented, manual upload flow. | User can create/list/open own project and upload valid source image; cross-user access is denied. |
| FB-5 Reconstruction | Status tests, transition append tests, candidate/confirmed separation, coordinate-space tests, artifact metadata tests, editor build. | Jobs/results/geometry/floor plans persist with allowed statuses and correct coordinate spaces; editor has no Firebase imports. |
| FB-6 Layout Save/Load/Export | Layout rules tests, serializer round trip, export `snake_case`, `Needs review` warning, editor bridge compatibility. | Save/load/export preserves required fields and does not use an unsaved draft as export source. |
| FB-7 Draft Recovery | IndexedDB unit tests, conflict detection, restore/discard flows, no silent stream overwrite, accessibility checks. | Local draft is clearly separate from cloud save and conflict choice is shown when cloud/draft diverge. |
| FB-8 Admin Diagnostics | Admin/non-admin rules tests, collection group query/index checks, admin artifact read, admin_actions append-only, retry linkage. | Non-admin denied; admin can inspect jobs/artifacts and create audited retry action without broadening user access. |
| FB-9 Legacy Cutover | Default backend selection tests, search for legacy default-path usage, documentation search, optional legacy tests only if touched. | Firebase is default; `legacy_api` is explicit; default validation does not require FastAPI/Oracle. |
| FB-10 Readiness | Document traceability, validation matrix completeness, PRD FR/NFR coverage review, invariant review. | Parent workflow can run `bmad-create-epics-and-stories` without unresolved schema/rules/order contradictions. |

## PRD and UX Traceability

| Requirement area | Validation coverage |
| --- | --- |
| FR1-FR4 Auth/admin | MEF-1, FB-3 role tests, FB-8 admin rules tests. |
| FR5-FR9 Projects | FB-4 project owner/non-owner rules and repository tests. |
| FR10-FR14 Image input | FB-4 Storage source image tests, upload UX states, metadata persistence. |
| FR15-FR28 Reconstruction | FB-5 job/status/result/geometry/floor-plan tests and manual reconstruction flow. |
| FR29-FR36 3D/furniture editing | FB-6 layout round trip and editor bridge validation for persisted furniture state. |
| FR37-FR40 Save/load/export | FB-6 layout save/load/export round trip and `Needs review` warning. |
| FR41-FR50 Admin/support | FB-8 admin collection group queries, admin_actions, retry linkage, artifact diagnosis. |
| NFR6-NFR10 Security | Firestore/Storage emulator denial tests for unauthenticated, non-owner, non-admin, and public access. |
| NFR11-NFR15 Jobs/retry | Status vocabulary, transitions, timeout/failure metadata, retry job linkage, admin_actions. |
| NFR16-NFR19 Processing boundaries | Editor/browser OpenCV path, no heavy default server dependency, legacy API isolation. |
| NFR20-NFR23 Data integrity | Serializer tests, layout round trip, source/job/result traceability, transition fields. |
| NFR24-NFR26 UX/review/usability | Upload/save/draft/accessibility checks, `Needs review`, manual end-to-end emulator flows. |

## Documentation Traceability Checks

Before epics/stories are generated:

- Refactor overview or docs index should point to all Firebase planning artifacts.
- Story-generation guidance must reference FB-1 through FB-10.
- Architecture, data contract, workplan, and validation plan must agree that Firebase is default and `legacy_api` is explicit only.
- Old API envelope guidance must be marked legacy-only where Firebase direct SDK repositories are documented.
- Admin role bootstrap remains an explicit open decision if not implemented before stories.
- Every new Firebase story must reference at least one validation layer and at least one source document.

Suggested documentation search:

```bash
rg -n "Oracle|FastAPI|ProjectApi|AdminApi|legacy_api|Firebase|Firestore|Storage|Security Rules" docs app/lib
```

## Stop and Go Criteria

### Stop Criteria

Stop before story generation if any of these remain unresolved:

- Firebase data contract and architecture disagree on Firestore paths, Storage paths, status values, or ownership fields.
- `users/{uid}.role` can be self-written, overwritten, or deleted by normal authenticated users in the intended rules behavior.
- No feasible Firebase emulator/rules validation path exists for FB-1.
- The editor is expected to import Firebase SDKs or call Firestore/Storage directly.
- Layout export is allowed to use unsaved IndexedDB draft state without saving to Firestore first.
- `legacy_api` remains the default backend path in the refactor plan.
- Admin reads are described as client-side filtering without rules-backed admin authorization.

### Go Criteria

Proceed to `bmad-create-epics-and-stories` when:

- This validation plan exists and maps every FB package to checks.
- The rules test categories cover owner, non-owner, unauthenticated, admin, non-admin, status, coordinate-space, Storage path/type/size, orphan mitigation, and artifact access behavior.
- Layout round-trip validation is defined for save, load, and export.
- Admin role validation includes role self-write denial, role preservation, non-admin denial, admin allow, append-only `admin_actions`, and admin artifact read constraints.
- Editor invariant validation covers no Firebase imports, bridge `camelCase`, and Flutter-to-Firestore `snake_case` mapping.
- Missing tools or unresolved choices are explicit and can be turned into implementation story acceptance criteria.
- No generated story will need to invent schema, rules behavior, or validation order from scratch.

## Readiness for Epics and Stories

`bmad-create-epics-and-stories` may run after parent validation confirms this document is internally consistent with:

- `docs/refactor/firebase-data-contract.md`
- `docs/refactor/firebase-refactor-workplan.md`
- `docs/refactor/firebase-target-architecture.md`
- `docs/refactor/firebase-ux-design-specification.md`
- `docs/refactor/firebase-backend-refactor-plan.md`
- `docs/product/prd.md`

Story generation should preserve FB package order, include validation acceptance criteria in each story, and avoid generating any story that makes `server/`, Oracle, FastAPI, `ProjectApi`, or `AdminApi` the default path.

## Open Validation Decisions for Implementation Stories

- Select the exact Firebase rules test harness path and language.
- Decide whether admin role assignment uses manual bootstrap, admin-only write, custom claim sync, or Cloud Functions.
- Decide the concrete orphan source image mitigation approach: Firestore rules lookup, upload reservation, or metadata handshake.
- Decide how missing Firestore index errors are surfaced in tests and admin repository handling.
- Decide whether artifact writes are user-generated only for MVP or also produced by a future trusted worker.
- Decide whether layout export includes a content hash for regression comparison.

These decisions do not block epics/stories if each is assigned to the relevant FB package and validation acceptance criteria.

## Parent Validation Record

Validated on 2026-05-24.

- Result: APPROVE.
- Coverage check: FB-1 through FB-10 each have validation layers, minimum go criteria, and traceability to PRD/UX/architecture/data-contract requirements.
- Rules check: Owner, non-owner, unauthenticated, admin, non-admin, role escalation, status, coordinate-space, Storage type/size/path, orphan mitigation, artifact access, and append-only admin action cases are covered.
- Product check: Layout round trip, `Needs review`, draft recovery, admin diagnostics, editor boundary, and legacy cutover validation are explicit.
- Follow-up dependency: Epics/stories can now be generated with validation acceptance criteria attached to every Firebase refactor story.
