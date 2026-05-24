---
stepsCompleted:
  - step-01-validate-prerequisites
  - step-02-design-epics
  - step-03-create-stories
  - step-04-final-validation
inputDocuments:
  - _bmad-output/planning-artifacts/prd.md
  - _bmad-output/planning-artifacts/prd-validation-report.md
  - _bmad-output/planning-artifacts/architecture.md
  - _bmad-output/planning-artifacts/ux-design-specification.md
---

# RoomForge - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for RoomForge, decomposing the requirements from the PRD, UX Design, and Architecture requirements into implementable stories.

## Requirements Inventory

### Functional Requirements

FR1: Users can sign in with Google.
FR2: Users can sign out.
FR3: The system can associate authenticated Firebase users with application user records.
FR4: Admin users can access admin-only operational capabilities.
FR5: Users can create room projects.
FR6: Users can view their saved room projects.
FR7: Users can open an existing room project.
FR8: Users can update room project metadata.
FR9: Users can delete room projects.
FR10: Users can upload a room image for reconstruction.
FR11: Users can enter room width and depth.
FR12: Users can enter room height or use a default height.
FR13: The system can provide guidance for suitable room photos.
FR14: The system can preserve source image metadata for reconstruction and review.
FR15: Users can submit a reconstruction job for a room project.
FR16: The system can track reconstruction job status.
FR17: Users can view reconstruction progress or current job state.
FR18: The system can produce OpenCV candidate edges, lines, corners, or room boundary hints from a source image.
FR19: Users can select or correct room boundary/corner points using the source image and OpenCV candidates.
FR20: The system can apply perspective reasoning and metric scale calibration from user-provided dimensions to produce a floor plan.
FR21: The system can mark reconstruction jobs as succeeded, failed, timed out, or cancelled where supported.
FR22: The system can store reconstruction result metadata.
FR23: The system can store OpenCV edge/line/corner overlay outputs or references.
FR24: The system can store user-corrected boundary/corner points.
FR25: The system can produce a rectangular or simple polygonal metric floor plan from valid inputs.
FR26: The system can report reconstruction quality or confidence states.
FR27: Users can see failure reasons when reconstruction cannot produce a trustworthy result.
FR28: Users can retry reconstruction after correcting input or uploading a new image.
FR29: Users can view a generated 3D room layout.
FR30: Users can add furniture proxy objects.
FR31: Users can select furniture proxy objects.
FR32: Users can move furniture proxy objects.
FR33: Users can rotate furniture proxy objects.
FR34: Users can resize furniture proxy objects.
FR35: Users can delete furniture proxy objects.
FR36: Users can view room scale or dimension guidance while editing.
FR37: Users can save room layouts.
FR38: Users can load saved room layouts.
FR39: Users can export layout data as JSON.
FR40: The system can preserve room dimensions, floor plan data, source metadata, and furniture state in saved layouts.
FR41: Admin users can view reconstruction jobs by status.
FR42: Admin users can inspect reconstruction job details.
FR43: Admin users can view reconstruction provider/status state, including OpenCV/manual-assisted provider details and optional future provider state.
FR44: Admin users can retry failed reconstruction jobs.
FR45: Admin users can retry provider-backed processing when supported.
FR46: Admin users can inspect user, project, layout, OpenCV result, and optional inference result records.
FR47: Admin users can view failure reasons and retry history.
FR48: Support/admin users can search for jobs by user, project, or job identifier.
FR49: Support/admin users can determine whether a failure came from input quality, OpenCV candidate detection, user calibration, API handling, database state, or optional provider processing.
FR50: The system can preserve job status transitions, timestamps, actor/source, reason code, human-readable reason, and failure/retry history for troubleshooting.

### NonFunctional Requirements

NFR1: Non-CV API requests for project list, project detail, layout save, and layout load should return within 1 second at p95 under MVP expected load, measured from client request to API response.
NFR2: Layout editing actions should update local editor state within 100 ms for MVP-scale scenes, measured in browser developer performance tooling.
NFR3: The 3D editor should sustain at least 30 FPS on a recent laptop browser for a rectangular room with up to 20 furniture proxy objects.
NFR4: Reconstruction job status should be retrievable by the client at least every 5 seconds while a provider-backed job is created, processing, review_required, succeeded, failed, or timed out.
NFR5: Long-running reconstruction or optional provider requests must not rely on a single blocking HTTP request longer than 30 seconds; long-running reconstruction must use job status retrieval.
NFR6: Every user-facing API request for project, layout, job, image, or result data must require a valid authenticated user identity.
NFR7: Authorization checks must prevent users from reading or modifying projects, layouts, images, jobs, or results owned by other users.
NFR8: Admin capabilities must require an admin authorization check distinct from normal authenticated user access.
NFR9: Stored room images, layout data, OpenCV result metadata, corrected geometry, and optional inference metadata must not be publicly accessible without authenticated and authorized API access.
NFR10: Authentication and authorization failures must return explicit unauthenticated or unauthorized error categories without exposing another user's data.
NFR11: Reconstruction jobs must reach a terminal state of succeeded, failed, timeout, or cancelled within 30 minutes of creation unless explicitly retried.
NFR12: Failed reconstruction jobs must preserve a machine-readable reason code and human-readable reason whenever the failure source is known.
NFR13: Admin users must be able to inspect the current job status, status transition history, provider state, retry count, and failure reason for any reconstruction job.
NFR14: Provider-backed jobs must be marked timeout or failed if processing does not start within 10 minutes.
NFR15: Admin retry actions must create a new retry attempt record linked to the original job and preserve the previous failure history.
NFR16: Heavy OpenCV processing, deep-learning model inference, and GPU model inference must not execute on the lightweight application/API server.
NFR17: The system should allow optional reconstruction providers, including future on-demand GPU providers, without making them required for the MVP user flow.
NFR18: The lightweight API server should keep responsibilities limited to authentication verification, API routing, database access, job orchestration, and result retrieval.
NFR19: Admin users must be able to see reconstruction provider state, current active job count, recent failure state, and optional GPU provider lifecycle data when GPU providers are enabled.
NFR20: Saved layouts must preserve room dimensions, floor plan data, source metadata, and all furniture object IDs, categories, positions, sizes, rotations, and colors.
NFR21: Reconstruction results must be traceable to source image ID, input dimensions, job ID, provider/algorithm identifier, OpenCV version where available, processing timestamps, corrected boundary points, and result artifact references.
NFR22: Job status transitions must persist status, timestamp, actor/source, reason code, human-readable reason, and retry linkage where available.
NFR23: A save/load round trip for a layout must preserve all required layout and furniture fields exactly, except for server-managed metadata such as updated timestamps.
NFR24: The web client should display photo suitability guidance before upload and display reconstruction failure guidance within the job result view when a job fails or returns persisted status `review_required`.
NFR25: Reconstruction results with persisted status `review_required` must show the user-facing label "Needs review" and display a visible warning before users can save or export the resulting layout.
NFR26: In a lightweight usability review with at least three test users or reviewers, users should be able to complete login, project creation, image upload, dimension entry, job submission, 3D layout review, and layout save/export without developer assistance.

### Additional Requirements

AR1: Initialize a custom monorepo with `app/`, `editor/`, `server/`, and optional `packages/` boundaries.
AR2: Use Flutter/Dart for the app shell, TypeScript/Vite/Three.js for the spatial editor, and Python/FastAPI for the lightweight API server.
AR3: Deploy the Flutter web client and bundled editor assets through Firebase Hosting.
AR4: Use Firebase Google Auth for identity and verify Firebase ID tokens on the FastAPI server.
AR5: Use Oracle DB as the primary system of record for users, projects, source images, reconstruction jobs, status transitions, OpenCV results, confirmed geometry, calibration, floor plans, layouts, furniture objects, admin actions, and retry attempts.
AR6: Use `python-oracledb` for Oracle DB access and keep DB access inside repository modules.
AR7: Keep the Oracle 1GB API server stateless except for Oracle DB and exclude heavy OpenCV, deep-learning, and GPU inference from that server.
AR8: Run MVP OpenCV candidate extraction in the browser/editor layer with OpenCV.js, preferably inside a Web Worker.
AR9: Persist client-generated OpenCV candidate sets, overlay metadata, and CV artifact references through the API for admin/evaluation visibility.
AR10: Store candidate geometry separately from user-confirmed geometry throughout API, editor, DB, and layout schemas.
AR11: Use REST APIs with OpenAPI generated from FastAPI.
AR12: Implement API groups for auth/session, projects, source images, reconstruction jobs, OpenCV results, geometry, layouts, exports, and admin job/project/artifact operations.
AR13: Use a consistent API response envelope containing `data`, `error`, and `meta.request_id`.
AR14: Use a consistent error code set: unauthenticated, unauthorized, validation_error, not_found, conflict, rate_limited, provider_unavailable, reconstruction_failed, calibration_failed, timeout, and internal_error.
AR15: Use allowed persisted reconstruction statuses exactly: created, uploading, processing, review_required, succeeded, failed, timeout, cancelled, retrying.
AR15a: Map persisted status `review_required` to the user-facing label "Needs review"; do not create a separate persisted `needs_review` status.
AR16: Use Riverpod for Flutter state and async API state.
AR17: Use `go_router` for Flutter routing and deep-link structure.
AR18: Expose a typed Flutter-to-Three.js bridge with message `type`, `version`, `payload`, and optional `requestId`.
AR19: Keep Three.js editor modules responsible for source-image alignment, OpenCV overlays, geometry handles, 2D/3D rendering, camera behavior, furniture manipulation, and spatial validation.
AR20: Keep Flutter modules responsible for app routing, auth state, project screens, upload UI, reconstruction workflow UI, inspector panels, admin UI, accessible controls, and API calls.
AR21: Keep FastAPI modules separated into routers, schemas, services, repositories, auth, core, and db packages.
AR22: Apply database naming conventions: plural `snake_case` tables, `snake_case` columns, `id` primary keys, `{entity}_id` foreign keys, and `idx_{table}_{columns}` indexes.
AR23: API JSON fields use `snake_case`; editor bridge fields use `camelCase`; dates use ISO 8601 UTC strings.
AR24: Geometry payloads must explicitly state coordinate space, distinguishing image pixels before calibration from meters after calibration.
AR25: Add technical stories for Oracle schema/DDL, Flutter-to-Three.js embedding, OpenCV.js worker/WebAssembly packaging, and image size/retention policy because architecture validation identified these as important gaps.
AR26: Defer external GPU provider selection, realtime updates beyond polling, object storage migration, native smartphone capture, and provider cost analytics to post-MVP unless needed for a course demo.

### UX Design Requirements

UX-DR1: Implement Material 3 as the baseline Flutter UI system for app shell, forms, navigation, dialogs, tables, sheets, and admin controls.
UX-DR2: Implement shared visual tokens for neutral surfaces, primary actions, OpenCV candidates, user-confirmed geometry, selected states, measurement guides, warning, error, success, save, and admin/provider statuses.
UX-DR3: Implement OpenCV candidate overlays with thin dashed/lower-opacity treatment and non-color-only distinctions.
UX-DR4: Implement user-confirmed geometry overlays with stronger solid treatment, visible handles, and non-color-only distinctions.
UX-DR5: Implement selected geometry/furniture states with clear outline, halo, handle, or vertex marker treatment.
UX-DR6: Implement measurement labels and dimension displays with units and stable numeric formatting.
UX-DR7: Implement a Photo Suitability Uploader with empty, dragging, uploading, uploaded, rejected, and low-quality warning states.
UX-DR8: Implement an OpenCV Overlay Canvas with source photo, candidate overlay, confirmed geometry, selected handles, labels, layer toggles, and zoom/pan controls.
UX-DR9: Implement a Geometry Candidate Reviewer supporting no candidates, one candidate, multiple candidates, low confidence, correcting, valid geometry, and invalid geometry states.
UX-DR10: Geometry correction must support accepting a candidate, choosing another candidate, dragging corners, adding corners, deleting corners, resetting to the candidate, and switching to manual outline.
UX-DR11: Geometry validation must prevent saving fewer than three corners, open boundaries, and self-intersecting polygons.
UX-DR12: Implement a Metric Calibration Control with reference-line selection, unit selector, length input, scale summary, validation message, and recalculation notice.
UX-DR13: Disable 2D/3D generation until geometry and metric calibration are valid.
UX-DR14: Implement a 2D/3D View Switcher that preserves selection, object identity, metric coordinates, scale, and unsaved state.
UX-DR15: Implement camera controls for 3D inspection, including orbit, pan, zoom, reset, fit-to-room, and preset views such as Top, Front, Corner, and Eye-level.
UX-DR16: Implement a Furniture Inspector with object name, width/depth/height fields, rotation control, position values, delete action, and placement warning.
UX-DR17: Ensure 2D and 3D views derive from one shared spatial model and stay synchronized after object movement, resizing, rotation, deletion, and selection.
UX-DR18: Implement a CV Job Status Timeline for created/uploading/processing/needs review/failed/retrying/completed states in user and admin contexts.
UX-DR19: Implement an Admin CV Artifact Viewer with project/job header, original image access, candidate preview, confidence/failure metadata, calibration summary, user correction status, event trail, and support notes.
UX-DR20: Implement recovery states for blur, low light, hidden boundaries, occlusion, distortion, unsupported image, OpenCV failure, invalid geometry, and calibration failure.
UX-DR21: Recovery flows must offer reupload, manual outline, corner correction, reference-line correction, or rectangular room start without discarding useful context where feasible.
UX-DR22: Implement action-oriented status language such as Ready, Needs review, Manual input needed, Processing, Saved, Save failed, Retry available, and Recalculation needed.
UX-DR23: Use dialogs only for confirmation, permission, destructive actions, or focused short tasks; use panels/sheets for inspectors, layer toggles, camera presets, calibration controls, and correction tools.
UX-DR24: Implement layer toggles for source photo, OpenCV candidates, confirmed geometry, measurements, grid, and furniture bounds where relevant.
UX-DR25: Implement responsive ranges: mobile 320-767px, tablet 768-1023px, desktop 1024-1439px, wide desktop 1440px+.
UX-DR26: Desktop editor layout must include a large central canvas, compact tool controls, persistent 2D/3D switcher, right inspector, bottom status/next-action area, and dense admin views.
UX-DR27: Tablet layouts must support project review, photo upload, geometry review, light correction, and basic 2D/3D inspection with larger touch targets and collapsible panels.
UX-DR28: Mobile layouts must prioritize sign-in, photo capture/upload, project status, weak-detection recovery, lightweight outline review, and saved-layout viewing rather than precision furniture editing.
UX-DR29: Target WCAG 2.2 AA for app shell, forms, navigation, project screens, admin screens, dialogs, tables, status messages, and non-canvas controls.
UX-DR30: Canvas/editor controls must provide best-effort accessibility: visible selection states, camera reset/presets, keyboard-accessible key actions where feasible, textual summaries of selection/status, and non-color-only overlay states.
UX-DR31: Respect reduced-motion preferences; 150-220ms transitions should clarify navigation, selection, candidate confirmation, 2D/3D switching, save completion, and recovery without hiding latency or failure.
UX-DR32: Touch targets for upload actions, panel controls, camera presets, 2D/3D switching, correction tools, and mobile review interactions should be at least 44x44px where feasible.

### FR Coverage Map

FR1: Epic 1 - Google sign-in.
FR2: Epic 1 - Sign-out.
FR3: Epic 1 - Firebase user to application user mapping.
FR4: Epic 1 - Admin-only access boundary.
FR5: Epic 1 - Create room projects.
FR6: Epic 1 - View saved room projects.
FR7: Epic 1 - Open existing room projects.
FR8: Epic 1 - Update room project metadata.
FR9: Epic 1 - Delete room projects.
FR10: Epic 2 - Upload room image for reconstruction.
FR11: Epic 2 - Enter room width and depth.
FR12: Epic 2 - Enter room height or use default height.
FR13: Epic 2 - Photo suitability guidance.
FR14: Epic 2 - Source image metadata preservation.
FR15: Epic 3 - Submit reconstruction job.
FR16: Epic 3 - Track reconstruction job status.
FR17: Epic 3 - View reconstruction progress or current state.
FR18: Epic 3 - Produce OpenCV candidate edges, lines, corners, or boundary hints.
FR19: Epic 3 - Select or correct boundary/corner points.
FR20: Epic 3 - Apply perspective reasoning and metric calibration.
FR21: Epic 3 - Mark reconstruction jobs succeeded, failed, timed out, or cancelled where supported.
FR22: Epic 3 - Store reconstruction result metadata.
FR23: Epic 3 - Store OpenCV overlay outputs or references.
FR24: Epic 3 - Store user-corrected boundary/corner points.
FR25: Epic 3 - Produce rectangular or simple polygonal metric floor plan.
FR26: Epic 3 - Report reconstruction quality/confidence states.
FR27: Epic 3 - Show reconstruction failure reasons.
FR28: Epic 3 - Retry reconstruction after correction or new image.
FR29: Epic 4 - View generated 3D room layout.
FR30: Epic 4 - Add furniture proxy objects.
FR31: Epic 4 - Select furniture proxy objects.
FR32: Epic 4 - Move furniture proxy objects.
FR33: Epic 4 - Rotate furniture proxy objects.
FR34: Epic 4 - Resize furniture proxy objects.
FR35: Epic 4 - Delete furniture proxy objects.
FR36: Epic 4 - View room scale or dimension guidance while editing.
FR37: Epic 5 - Save room layouts.
FR38: Epic 5 - Load saved room layouts.
FR39: Epic 5 - Export layout data as JSON.
FR40: Epic 5 - Preserve room dimensions, floor plan data, source metadata, and furniture state.
FR41: Epic 6 - Admin job list by status.
FR42: Epic 6 - Admin job detail inspection.
FR43: Epic 6 - Admin provider/status visibility.
FR44: Epic 6 - Retry failed reconstruction jobs.
FR45: Epic 6 - Retry provider-backed processing when supported.
FR46: Epic 6 - Inspect user, project, layout, OpenCV result, and optional inference result records.
FR47: Epic 6 - View failure reasons and retry history.
FR48: Epic 6 - Search jobs by user, project, or job identifier.
FR49: Epic 6 - Determine failure source across input quality, OpenCV, calibration, API, database, or provider.
FR50: Epic 6 - Preserve job status transitions, reason codes, human-readable reasons, and failure/retry history.

## Epic List

### Epic 1: Authenticated Project Workspace
Users can sign in, enter the RoomForge workspace, and manage their own room projects with secure ownership boundaries.
**FRs covered:** FR1, FR2, FR3, FR4, FR5, FR6, FR7, FR8, FR9

### Epic 2: Room Photo Intake and Dimension Setup
Users can start a room project by uploading a room image, receiving photo suitability guidance, and entering room dimensions.
**FRs covered:** FR10, FR11, FR12, FR13, FR14

### Epic 3: OpenCV-Assisted Geometry Review and Metric Reconstruction
Users can run the OpenCV-assisted reconstruction flow, inspect candidate geometry, correct room boundaries, calibrate scale, and recover from weak detection.
**FRs covered:** FR15, FR16, FR17, FR18, FR19, FR20, FR21, FR22, FR23, FR24, FR25, FR26, FR27, FR28

### Epic 4: Interactive 2D/3D Furniture Planning Editor
Users can inspect the generated room in synchronized 2D/3D views and manipulate proxy furniture for layout decisions.
**FRs covered:** FR29, FR30, FR31, FR32, FR33, FR34, FR35, FR36

### Epic 5: Layout Persistence and Export
Users can save, reload, and export room layouts while preserving room geometry, source metadata, and furniture state.
**FRs covered:** FR37, FR38, FR39, FR40

### Epic 6: Admin Operations and CV Troubleshooting
Admins can inspect reconstruction jobs, OpenCV artifacts, failures, retry history, provider state, user/project/layout records, and support reported issues.
**FRs covered:** FR41, FR42, FR43, FR44, FR45, FR46, FR47, FR48, FR49, FR50

## Epic 1: Authenticated Project Workspace

Users can sign in, enter the RoomForge workspace, and manage their own room projects with secure ownership boundaries.

### Story 1.1: Enabler - Set Up Initial Project from Minimal Official Starters

As a developer,
I want the RoomForge MVP workspace initialized from minimal official starters with app, editor, and server boundaries,
So that user-facing auth and project features can be implemented consistently.

**Requirements Covered:** AR1, AR2, AR3, AR7, AR16, AR17, AR21, UX-DR2

**Acceptance Criteria:**

**Given** a fresh local checkout
**When** the workspace is initialized
**Then** the repository contains `app/`, `editor/`, `server/`, and optional `packages/` boundaries
**And** Flutter, FastAPI, and TypeScript editor responsibilities are documented in the project structure.

**Given** the MVP workspace
**When** a developer reviews configuration
**Then** Firebase Hosting, Firebase Auth, Oracle DB, and API environment settings have clear placeholder configuration
**And** no heavy OpenCV, deep-learning, or GPU process is configured to run on the 1GB API server.

**Given** the architecture specifies minimal official starters
**When** the initial project is created
**Then** the app uses a Flutter starter, the editor uses a Vite vanilla TypeScript starter, and the server uses a lightweight FastAPI scaffold.

**Given** shared UI and editor state tokens are needed
**When** the initial workspace conventions are documented
**Then** the repository defines a shared token source or JSON export location for Flutter and Three.js to consume
**And** candidate, confirmed, selected, warning, error, measurement, save, and admin status tokens are represented.

### Story 1.2: Enabler - Baseline Verification and CI Checks

As a developer,
I want baseline verification commands for the Flutter app, Three.js editor, and FastAPI server,
So that the greenfield monorepo can catch integration regressions before feature work accelerates.

**Requirements Covered:** AR1, AR2, AR3, AR16, AR17, AR21

**Acceptance Criteria:**

**Given** the initial workspace is created
**When** a developer reviews project documentation
**Then** there is a documented local verification command or command list covering app, editor, and server checks.

**Given** placeholder implementations exist for each workspace
**When** verification is run
**Then** Flutter has at least an analyze or test placeholder, the editor has at least a typecheck/build/test placeholder, and the server has at least an import or test placeholder.

**Given** CI is configured or documented for setup
**When** a change is proposed
**Then** the expected checks for Flutter, editor, and server are explicit enough to reproduce locally.

### Story 1.3: Google Sign-In and Sign-Out

As a user,
I want to sign in and sign out with Google,
So that I can securely access my RoomForge projects.

**Requirements Covered:** FR1, FR2, AR4, AR16, AR17, AR20, UX-DR1, UX-DR22, UX-DR29, UX-DR31

**Acceptance Criteria:**

**Given** I am not authenticated
**When** I open RoomForge
**Then** I see a Google sign-in entry point.

**Given** I complete Google sign-in successfully
**When** Firebase returns an authenticated user
**Then** the app routes me to the project workspace
**And** the UI uses clear signed-in status language.

**Given** I am signed in
**When** I choose sign out
**Then** my session is cleared and I return to the signed-out state.

### Story 1.4: Authenticated API Session Mapping

As a signed-in user,
I want the server to recognize my Firebase identity,
So that my data can be linked to a RoomForge user record.

**Requirements Covered:** FR3, NFR6, NFR10, AR4, AR5, AR6, AR11, AR13, AR14, AR21, AR22, AR23, AR25

**Acceptance Criteria:**

**Given** the client has a Firebase ID token
**When** it calls a protected API endpoint
**Then** FastAPI verifies the token and maps it to an Oracle `users` record.

**Given** authenticated user mapping is implemented
**When** Oracle schema changes are added
**Then** the story creates or modifies only user/session mapping tables and fields required for this capability.

**Given** the token is missing, expired, or invalid
**When** a protected endpoint is called
**Then** the API returns the standard envelope with `unauthenticated`
**And** no user, project, layout, image, job, or result data is returned.

### Story 1.5: User Project List and Creation

As a signed-in user,
I want to create and view my room projects,
So that I can start organizing room reconstruction work.

**Requirements Covered:** FR5, FR6, NFR1, NFR6, NFR7, AR5, AR6, AR12, AR13, AR14, AR20, AR21, AR22, AR23

**Acceptance Criteria:**

**Given** I am signed in
**When** I create a room project with valid metadata
**Then** the API stores the project in Oracle linked to my user
**And** the project appears in my project list.

**Given** I am signed in
**When** I view my project list
**Then** I only see projects owned by my user account
**And** the list loads through an authenticated API request.

### Story 1.6: Open, Update, and Delete Own Projects

As a signed-in user,
I want to open, rename, update, and delete my own room projects,
So that I can manage my workspace over time.

**Requirements Covered:** FR7, FR8, FR9, NFR1, NFR6, NFR7, NFR9, AR5, AR6, AR12, AR13, AR14, AR20, AR21, AR22, AR23, UX-DR23

**Acceptance Criteria:**

**Given** I own a project
**When** I open the project detail view
**Then** the app displays its current metadata and next available workflow action.

**Given** I own a project
**When** I update valid project metadata
**Then** the API persists the change and returns the updated project.

**Given** I own a project
**When** I confirm deletion
**Then** the project is deleted or marked deleted according to the persistence policy
**And** it no longer appears in my active project list.

**Given** I try to access a project owned by another user
**When** I call view, update, or delete APIs
**Then** the API returns `unauthorized` or `not_found` without exposing that project's data.

### Story 1.7: Admin Access Boundary

As an admin user,
I want admin-only routes and APIs to require an admin role,
So that operational tools are protected from normal users.

**Requirements Covered:** FR4, NFR8, AR5, AR12, AR13, AR14, AR20, AR21, AR22, AR23, UX-DR29

**Acceptance Criteria:**

**Given** I am a normal signed-in user
**When** I try to access admin UI or admin APIs
**Then** access is denied with the standard `unauthorized` error category.

**Given** I am an admin user
**When** I access the admin route
**Then** the app allows entry to the admin shell
**And** admin capabilities remain separate from normal project workspace capabilities.

## Epic 2: Room Photo Intake and Dimension Setup

Users can start a room project by uploading a room image, receiving photo suitability guidance, and entering room dimensions.

### Story 2.1: Photo Suitability Upload Entry

As a signed-in user,
I want guidance before uploading a room photo,
So that I can choose an image likely to work with OpenCV reconstruction.

**Requirements Covered:** FR13, NFR24, AR20, UX-DR7, UX-DR20, UX-DR21, UX-DR22, UX-DR25, UX-DR27, UX-DR28, UX-DR29, UX-DR31, UX-DR32

**Acceptance Criteria:**

**Given** I open a room project
**When** I reach the photo intake step
**Then** I see upload guidance for blur, lighting, visible boundaries, occlusion, distortion, and supported image types
**And** the uploader supports empty, dragging, uploading, uploaded, rejected, and low-quality warning states.

**Given** I select an unsupported or invalid image
**When** the client validates it
**Then** the upload is rejected with action-oriented guidance
**And** no reconstruction job is created.

### Story 2.2: Enabler - Image Size and Retention Policy

As a developer,
I want a defined MVP image size and retention policy,
So that upload behavior stays realistic for the Oracle-backed MVP server before upload persistence is implemented.

**Requirements Covered:** FR10, FR14, NFR9, AR5, AR6, AR22, AR25, AR26

**Acceptance Criteria:**

**Given** the MVP storage policy is configured
**When** an image exceeds the allowed size or type
**Then** the API returns `validation_error` with a human-readable reason.

**Given** a source image is accepted
**When** metadata is stored
**Then** the record preserves filename or generated name, content type, size, dimensions when available, upload timestamp, project linkage, and retention status.

**Given** the policy is documented
**When** future object storage migration is considered
**Then** the MVP Oracle storage decision and migration boundary are clear.

### Story 2.3: Source Image Upload and Metadata Persistence

As a signed-in user,
I want to upload a source room image to my project,
So that RoomForge can preserve the original input for reconstruction and review.

**Requirements Covered:** FR10, FR14, NFR6, NFR7, NFR9, AR5, AR6, AR12, AR13, AR14, AR20, AR21, AR22, AR23, AR25

**Acceptance Criteria:**

**Given** I own a room project
**When** I upload a valid room image
**Then** the API stores the image record and source metadata in Oracle
**And** the stored record is linked to my project and user.

**Given** I upload an image that violates the MVP size, type, or retention policy
**When** the API validates the upload
**Then** the upload is rejected with `validation_error`
**And** no source image record is persisted.

**Given** another user attempts to access my source image metadata
**When** they call the image API
**Then** the API denies access without exposing image data.

### Story 2.4: Room Dimension Entry

As a signed-in user,
I want to enter room width, depth, and height,
So that later reconstruction can be calibrated into metric space.

**Requirements Covered:** FR11, FR12, NFR6, NFR7, AR5, AR12, AR13, AR14, AR20, AR21, AR22, AR23, UX-DR6, UX-DR22, UX-DR29, UX-DR32

**Acceptance Criteria:**

**Given** I am setting up a room project
**When** I enter valid width and depth
**Then** the dimensions are saved with explicit units.

**Given** I do not enter room height
**When** I continue
**Then** the system applies the MVP default height
**And** clearly marks that height as default-derived.

**Given** I enter invalid dimensions
**When** I try to continue
**Then** the app blocks continuation and shows a validation message.

## Epic 3: OpenCV-Assisted Geometry Review and Metric Reconstruction

Users can run the OpenCV-assisted reconstruction flow, inspect candidate geometry, correct room boundaries, calibrate scale, and recover from weak detection.

### Story 3.1: Spike/Enabler - Editor Bridge and OpenCV Runtime Packaging

As a developer,
I want the Flutter shell to load the Three.js editor with a typed bridge and packaged OpenCV.js worker runtime,
So that client-side CV processing can run outside the lightweight API server.

**Requirements Covered:** AR2, AR7, AR8, AR18, AR19, AR20, AR23, AR25, NFR16, NFR17, NFR18

**Acceptance Criteria:**

**Given** a room project with a source image
**When** the Flutter app opens the reconstruction step
**Then** the Three.js editor loads through the chosen embedding approach
**And** Flutter and editor messages use `type`, `version`, `payload`, and optional `requestId`.

**Given** OpenCV processing is requested
**When** the editor runtime starts
**Then** OpenCV.js and WASM assets load in the browser/editor layer, preferably inside a Web Worker
**And** no heavy CV processing executes on the 1GB FastAPI server.

**Given** the Flutter shell and editor are integrated
**When** a minimal bridge round trip is exercised
**Then** Flutter sends a message with `type`, `version`, `payload`, and `requestId`
**And** the editor returns a matching response or event that proves asset loading, layout sizing, focus behavior, and bridge messaging work together.

### Story 3.2: Reconstruction Job Creation and Status Tracking

As a signed-in user,
I want to submit and track a reconstruction job,
So that I can see whether my room image is being processed, needs review, failed, or completed.

**Requirements Covered:** FR15, FR16, FR17, FR21, FR22, NFR4, NFR5, NFR11, NFR12, NFR21, NFR22, AR5, AR6, AR12, AR13, AR14, AR15, AR15a, UX-DR18, UX-DR22

**Acceptance Criteria:**

**Given** I have a valid source image and room dimensions
**When** I submit reconstruction
**Then** the API creates a reconstruction job with allowed status values only.

**Given** a reconstruction job exists
**When** the client polls job status at least every 5 seconds
**Then** the UI displays the current state using action-oriented language.

**Given** the persisted job status is `review_required`
**When** the client displays the state
**Then** the user-facing label is "Needs review"
**And** the system does not introduce a separate persisted `needs_review` status.

**Given** a job reaches a terminal state
**When** the state is persisted
**Then** the job is marked `succeeded`, `failed`, `timeout`, or `cancelled`
**And** status transitions include timestamp, actor/source, reason code where available, and human-readable reason where available.

### Story 3.3: OpenCV Candidate Extraction and Overlay Persistence

As a user,
I want RoomForge to detect candidate room edges, lines, corners, and boundary hints from my source image,
So that I have a computer vision starting point instead of drawing everything manually.

**Requirements Covered:** FR18, FR23, FR26, NFR16, NFR21, AR8, AR9, AR10, AR19, AR23, AR24, UX-DR2, UX-DR3, UX-DR4, UX-DR8, UX-DR24, UX-DR30

**Acceptance Criteria:**

**Given** a source image is available in the editor
**When** OpenCV candidate extraction runs
**Then** the editor produces candidate edges, lines, corners, or boundary hints.

**Given** candidate geometry is produced
**When** the result is saved
**Then** the API stores candidate geometry separately from confirmed geometry
**And** the payload explicitly states coordinate space as image pixels before calibration.

**Given** overlays are displayed
**When** candidates and confirmed geometry are both visible
**Then** candidates use thinner dashed or lower-opacity treatment
**And** confirmed geometry uses stronger solid treatment with handles.

### Story 3.4: Geometry Candidate Review and Manual Correction

As a user,
I want to accept, choose, or correct detected room boundary points,
So that the final room outline reflects the real room rather than raw CV guesses.

**Requirements Covered:** FR19, FR24, FR26, NFR21, AR9, AR10, AR19, AR24, UX-DR4, UX-DR8, UX-DR9, UX-DR10, UX-DR11, UX-DR20, UX-DR21, UX-DR24, UX-DR30, UX-DR32

**Acceptance Criteria:**

**Given** OpenCV candidates exist
**When** I review geometry
**Then** I can accept a candidate, choose another candidate, drag corners, add corners, delete corners, reset to candidate, or switch to manual outline.

**Given** there are no candidates or low-confidence candidates
**When** I enter review mode
**Then** the UI offers manual outline or rectangular room start without discarding useful context.

**Given** I create invalid geometry
**When** the app validates the outline
**Then** saving is blocked for fewer than three corners, open boundaries, or self-intersecting polygons.

### Story 3.5: Metric Calibration and Floor Plan Generation

As a user,
I want to calibrate corrected geometry using known room dimensions,
So that RoomForge can generate a metric floor plan.

**Requirements Covered:** FR20, FR25, NFR21, AR10, AR19, AR24, UX-DR6, UX-DR12, UX-DR13, UX-DR22, UX-DR30

**Acceptance Criteria:**

**Given** confirmed geometry is valid
**When** I select a reference line and enter length with units
**Then** the editor calculates metric scale and displays a scale summary.

**Given** geometry or calibration is invalid
**When** I try to generate a 2D/3D plan
**Then** generation is disabled with a validation message.

**Given** geometry and calibration are valid
**When** the floor plan is generated
**Then** the system produces a rectangular or simple polygonal metric floor plan
**And** metric geometry explicitly uses meters after calibration.

**Given** a valid rectangular-room input with confirmed image-space boundary points and user-provided dimensions
**When** perspective or homography-based reasoning is applied
**Then** the implementation records the perspective assumptions used, the image-pixel input geometry, and the meter-space output geometry.

**Given** a calibration result is produced for a simple rectangular-room case
**When** the generated floor plan is compared with the user-entered width and depth
**Then** exported room dimensions target <= 5% width/depth deviation and <= 5% aspect-ratio error for valid inputs.

### Story 3.6: Reconstruction Quality, Failure Guidance, and Retry

As a user,
I want reconstruction quality states, failure reasons, and retry options,
So that I can recover when OpenCV cannot produce a trustworthy result.

**Requirements Covered:** FR26, FR27, FR28, NFR12, NFR15, NFR24, NFR25, AR12, AR14, AR15, UX-DR18, UX-DR20, UX-DR21, UX-DR22, UX-DR31

**Acceptance Criteria:**

**Given** reconstruction confidence is weak or needs review
**When** the result is shown
**Then** the UI displays a visible warning before save or export is allowed.

**Given** reconstruction fails
**When** I view the result
**Then** I see a failure reason for blur, low light, hidden boundaries, occlusion, distortion, unsupported image, OpenCV failure, invalid geometry, or calibration failure where known.

**Given** I correct input or upload a new image
**When** I retry reconstruction
**Then** a retry attempt is linked to the original job
**And** prior failure history is preserved.

## Epic 4: Interactive 2D/3D Furniture Planning Editor

Users can inspect the generated room in synchronized 2D/3D views and manipulate proxy furniture for layout decisions.

### Story 4.1: Shared Spatial Model and 2D/3D View Shell

As a user,
I want the 2D and 3D room views to represent the same generated room,
So that switching views does not change or lose my layout state.

**Requirements Covered:** FR29, AR18, AR19, AR23, AR24, UX-DR14, UX-DR17, UX-DR24, UX-DR31

**Acceptance Criteria:**

**Given** a valid metric floor plan exists
**When** I open the planning editor
**Then** the editor renders a room view from one shared spatial model.

**Given** I switch between 2D and 3D views
**When** the view changes
**Then** selection, object identity, metric coordinates, scale, and unsaved state are preserved.

**Given** I open the planning editor at desktop, tablet, or mobile-review widths
**When** the 2D/3D shell lays out
**Then** the canvas, view switcher, inspector entry point, and status area remain usable without overlapping critical content.

### Story 4.2: 3D Room Inspection Controls

As a user,
I want to orbit, pan, zoom, reset, and use preset camera views,
So that I can freely inspect the reconstructed room like a floor planning tool.

**Requirements Covered:** FR29, NFR3, AR19, UX-DR15, UX-DR23, UX-DR30, UX-DR31, UX-DR32

**Acceptance Criteria:**

**Given** I am in the 3D room view
**When** I use orbit, pan, zoom, reset, fit-to-room, Top, Front, Corner, or Eye-level controls
**Then** the camera updates smoothly without changing room or furniture data.

**Given** I prefer reduced motion
**When** I switch views or use camera presets
**Then** the app respects reduced-motion preferences while keeping state changes understandable.

**Given** I use keyboard or non-canvas controls for camera actions
**When** I choose reset, fit-to-room, or a preset view
**Then** the controls are reachable through accessible UI with visible focus and clear labels.

### Story 4.3: Add and Select Furniture Proxy Objects

As a user,
I want to add and select furniture proxy objects,
So that I can begin planning a room layout.

**Requirements Covered:** FR30, FR31, AR19, UX-DR5, UX-DR16, UX-DR17, UX-DR30

**Acceptance Criteria:**

**Given** I am in the planning editor
**When** I add a furniture proxy object
**Then** it appears in the shared spatial model with ID, category, size, position, rotation, and color.

**Given** furniture exists
**When** I select an object in 2D or 3D
**Then** the selected state is visible with outline, halo, handle, or marker treatment
**And** the inspector shows that object's editable properties.

**Given** a furniture object is selected
**When** selection is represented visually
**Then** the selected state does not rely on color alone
**And** a textual selection summary is available in the Flutter-controlled inspector or status area where feasible.

### Story 4.4: Move, Rotate, Resize, and Delete Furniture

As a user,
I want to move, rotate, resize, and delete furniture proxy objects,
So that I can test different layout arrangements.

**Requirements Covered:** FR32, FR33, FR34, FR35, NFR2, NFR3, AR19, UX-DR16, UX-DR17, UX-DR23, UX-DR31

**Acceptance Criteria:**

**Given** a furniture object is selected
**When** I move, rotate, or resize it
**Then** the shared spatial model updates within 100 ms for MVP-scale scenes
**And** both 2D and 3D views stay synchronized.

**Given** a furniture object is selected
**When** I delete it and confirm if needed
**Then** the object is removed from the layout state
**And** selection and inspector state update cleanly.

**Given** I edit furniture with pointer, keyboard-accessible controls, or inspector fields
**When** I move, rotate, resize, or delete an object
**Then** the interaction preserves visible focus or selected state
**And** compact controls use feasible 44x44px targets on touch-oriented layouts.

### Story 4.5: Scale, Measurement, and Placement Guidance

As a user,
I want measurement labels, dimension guidance, and placement warnings,
So that I can understand whether the layout is realistic.

**Requirements Covered:** FR36, AR19, AR24, UX-DR2, UX-DR5, UX-DR6, UX-DR16, UX-DR24, UX-DR30

**Acceptance Criteria:**

**Given** I am editing a room layout
**When** dimensions, measurement guides, grid, or furniture bounds are enabled
**Then** labels display stable numeric formatting with units.

**Given** a furniture placement is outside the valid room area or conflicts with spatial constraints
**When** the object is selected or moved
**Then** the editor shows a placement warning without relying on color alone.

**Given** measurement, grid, or placement guidance is visible at different responsive widths
**When** labels or warnings render near geometry
**Then** text remains readable, does not overlap primary controls, and provides units or action-oriented guidance.

### Story 4.6: Responsive and Accessible Editor Controls

As a user,
I want editor controls that work across desktop, tablet, and mobile review contexts,
So that I can inspect layouts comfortably on different screens.

**Requirements Covered:** NFR26, AR20, UX-DR23, UX-DR25, UX-DR26, UX-DR27, UX-DR28, UX-DR29, UX-DR30, UX-DR31, UX-DR32

**Acceptance Criteria:**

**Given** I use a desktop viewport
**When** I open the editor
**Then** I see a large central canvas, compact tool controls, persistent 2D/3D switcher, right inspector, and bottom status or next-action area.

**Given** I use tablet or mobile widths
**When** I review the layout
**Then** controls use feasible 44x44px touch targets and panels collapse appropriately.

**Given** I use keyboard or assistive navigation for non-canvas controls
**When** I interact with editor controls
**Then** controls meet WCAG 2.2 AA targets where feasible and provide textual summaries for selection/status.

## Epic 5: Layout Persistence and Export

Users can save, reload, and export room layouts while preserving room geometry, source metadata, and furniture state.

### Story 5.1: Save Layout with Room and Furniture State

As a signed-in user,
I want to save my room layout,
So that I can return to the same room plan later.

**Requirements Covered:** FR37, FR40, NFR1, NFR6, NFR7, NFR9, NFR20, AR5, AR6, AR12, AR13, AR14, AR21, AR22, AR23, UX-DR22, UX-DR31

**Acceptance Criteria:**

**Given** I own a project with a valid floor plan and furniture state
**When** I save the layout
**Then** the API persists room dimensions, floor plan data, source metadata references, and furniture objects in Oracle.

**Given** furniture objects exist in the layout
**When** the layout is saved
**Then** each object preserves ID, category, position, size, rotation, and color.

**Given** the save succeeds or fails
**When** the app receives the response
**Then** the UI shows action-oriented status language such as `Saved` or `Save failed`.

### Story 5.2: Load Saved Layout

As a signed-in user,
I want to load a saved room layout,
So that I can continue editing without losing prior work.

**Requirements Covered:** FR38, FR40, NFR1, NFR6, NFR7, NFR9, NFR20, AR5, AR6, AR12, AR13, AR14, AR21, AR22, AR23

**Acceptance Criteria:**

**Given** I own a saved layout
**When** I open it from a project
**Then** the API returns the saved room dimensions, floor plan, source metadata references, and furniture state.

**Given** the layout loads successfully
**When** the editor receives layout data
**Then** the shared spatial model is restored accurately in 2D and 3D.

**Given** I try to load another user's layout
**When** the API checks ownership
**Then** access is denied without exposing layout data.

### Story 5.3: Export Layout as JSON

As a signed-in user,
I want to export my room layout as JSON,
So that I can submit, inspect, or reuse the layout data outside the app.

**Requirements Covered:** FR39, FR40, NFR6, NFR7, NFR9, NFR20, AR12, AR13, AR14, AR20, AR23, UX-DR22, UX-DR23

**Acceptance Criteria:**

**Given** I own a saved or current valid layout
**When** I choose JSON export
**Then** the system produces a JSON file or response containing room dimensions, floor plan data, source metadata references, and furniture state.

**Given** the current reconstruction result is marked needs review
**When** I try to export
**Then** the UI shows a visible warning before export is allowed.

**Given** export fails
**When** the error is returned
**Then** the app shows `Export failed` with a retry path where feasible.

### Story 5.4: Validation - Save, Load, and Export Round-Trip Validation

As a developer,
I want automated validation for layout save/load/export round trips,
So that MVP layout data remains trustworthy.

**Requirements Covered:** FR37, FR38, FR39, FR40, NFR1, NFR20, NFR23

**Acceptance Criteria:**

**Given** a layout contains room dimensions, floor plan data, source metadata references, and furniture objects
**When** it is saved, loaded, and exported
**Then** all required layout and furniture fields are preserved exactly except server-managed metadata.

**Given** the API handles layout persistence
**When** project list, project detail, layout save, and layout load are exercised under MVP expected load
**Then** non-CV API responses stay within the p95 target where measurable.

## Epic 6: Admin Operations and CV Troubleshooting

Admins can inspect reconstruction jobs, OpenCV artifacts, failures, retry history, provider state, user/project/layout records, and support reported issues.

### Story 6.1: Admin Job List and Status Filters

As an admin user,
I want to view reconstruction jobs by status,
So that I can monitor MVP processing health and spot failures.

**Requirements Covered:** FR41, NFR8, NFR13, AR12, AR13, AR14, AR15, AR20, UX-DR18, UX-DR22, UX-DR26, UX-DR29

**Acceptance Criteria:**

**Given** I am an authenticated admin
**When** I open the admin jobs screen
**Then** I can view jobs grouped or filtered by `created`, `uploading`, `processing`, `review_required`, `succeeded`, `failed`, `timeout`, `cancelled`, and `retrying`.

**Given** I am not an admin
**When** I call admin job APIs
**Then** access is denied with `unauthorized`.

### Story 6.2: Admin Job Detail and Event Trail

As an admin user,
I want to inspect reconstruction job details and status transitions,
So that I can understand what happened during reconstruction.

**Requirements Covered:** FR42, FR47, FR50, NFR12, NFR13, NFR21, NFR22, AR5, AR12, AR13, AR14, AR15, UX-DR18, UX-DR19, UX-DR22, UX-DR29

**Acceptance Criteria:**

**Given** I open a job detail page
**When** the job record loads
**Then** I see project/job header, current status, timestamps, provider or algorithm identifier, retry count, and failure reason where available.

**Given** job status transitions exist
**When** I view the event trail
**Then** each transition shows status, timestamp, actor/source, reason code, human-readable reason, and retry linkage where available.

### Story 6.3: Admin OpenCV Artifact Viewer

As an admin user,
I want to inspect OpenCV artifacts and user corrections,
So that I can evaluate whether failures come from input quality, CV detection, or calibration.

**Requirements Covered:** FR46, FR49, NFR13, NFR21, AR5, AR9, AR10, AR12, AR13, AR20, AR24, UX-DR19, UX-DR29, UX-DR30

**Acceptance Criteria:**

**Given** a job has OpenCV candidate output
**When** I open the artifact viewer
**Then** I can inspect original image access, candidate preview, confidence/failure metadata, calibration summary, and user correction status.

**Given** candidate and confirmed geometry exist
**When** I inspect artifacts
**Then** candidate geometry and user-confirmed geometry are visually and structurally separated.

### Story 6.4: Admin Retry Failed Jobs

As an admin user,
I want to retry failed reconstruction jobs where supported,
So that recoverable processing failures can be rerun without losing history.

**Requirements Covered:** FR44, FR45, FR47, FR50, NFR14, NFR15, AR12, AR14, AR15, UX-DR22, UX-DR23

**Acceptance Criteria:**

**Given** a failed or timed-out job is retryable
**When** I trigger retry
**Then** the system creates a new retry attempt linked to the original job
**And** the previous failure history remains preserved.

**Given** retry is not supported for the failure source
**When** I view the job
**Then** the UI explains why retry is unavailable.

### Story 6.5: Admin Search Across Users, Projects, Layouts, and Jobs

As a support/admin user,
I want to search by user, project, layout, or job identifier,
So that I can quickly find records related to a reported issue.

**Requirements Covered:** FR46, FR48, NFR8, AR5, AR12, AR13, AR14, AR20, UX-DR26, UX-DR29

**Acceptance Criteria:**

**Given** I have admin access
**When** I search using a user, project, layout, or job identifier
**Then** matching records are returned with enough context to navigate to details.

**Given** no matching records exist
**When** I search
**Then** the UI shows an empty state without exposing unauthorized data.

### Story 6.6: Provider State and Failure Source Diagnosis

As an admin user,
I want to see provider state and failure source classification,
So that I can distinguish OpenCV, input, calibration, API, database, and future provider failures.

**Requirements Covered:** FR43, FR49, NFR19, AR12, AR15, AR26, UX-DR19, UX-DR22

**Acceptance Criteria:**

**Given** I open admin operations
**When** provider state is available
**Then** I can see OpenCV/manual-assisted provider details, active job count, recent failure state, and optional future GPU lifecycle fields when enabled.

**Given** a reconstruction failure has a known source
**When** I inspect the job
**Then** the system identifies whether the failure came from input quality, OpenCV candidate detection, user calibration, API handling, database state, or optional provider processing.
