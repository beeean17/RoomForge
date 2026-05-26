# RoomForge Initial Design Concept Brief

## Purpose

This document defines the first design concept direction for RoomForge. It is intended to guide early visual exploration, wireframes, screen concepts, and implementation handoff before detailed UI production begins.

RoomForge should feel like a practical spatial planning workspace: calm enough for everyday users, precise enough for room and furniture decisions, and transparent enough to make OpenCV-assisted reconstruction trustworthy.

## Product Design Thesis

RoomForge turns a real room photo into an editable, dimension-calibrated planning space. The interface should not sell "AI magic." It should help users understand, confirm, correct, and trust the transformation from photo to room model.

The primary design concept is:

> A calm technical workspace for turning uncertain room photos into confident layout decisions.

This means:

- User-facing screens should feel guided, simple, and recoverable.
- Editor screens should feel precise, spatial, and tool-oriented.
- Admin screens should feel dense, diagnostic, and permission-aware.
- OpenCV evidence should be visible when useful, but not presented as raw algorithm debugging in the main user flow.
- Persistence state should always be clear: uploaded, processing, saved, unsaved draft, sync failed, or needs review.

## Experience Keywords

| Keyword | Meaning for RoomForge |
| --- | --- |
| Calm | Avoid alarmist errors. Use clear next actions for failure, weak detection, and permission states. |
| Spatial | Canvas, overlays, dimensions, handles, and furniture placement are the center of the product. |
| Trustworthy | Show what is candidate, what is confirmed, what is saved, and what needs review. |
| Precise | Use metric units, stable controls, clear selection, and predictable 2D / 3D switching. |
| Recoverable | Reupload, correct corners, restore draft, retry upload, refresh role, or save again should be visible actions. |
| Diagnostic | Admin views expose technical detail without leaking protected user data. |

## Target Users

### Primary User

A person planning a room layout from a real photo. They want to know whether furniture fits and do not want to manually draw a floor plan from scratch.

Design implications:

- The first-use path should move quickly toward photo upload and room reconstruction.
- Copy should explain actions in everyday language: "Adjust the room outline," "Confirm the known wall length," "Save layout."
- Weak reconstruction should feel normal and recoverable, not like the app failed.

### Admin / Support User

A technical or support user who needs to inspect jobs, artifacts, retries, and permission outcomes.

Design implications:

- Admin screens can expose job IDs, owner IDs, candidate count, failure codes, artifact state, and retry history.
- Admin views should use dense tables, timelines, filters, and diagnostic panels.
- Permission and artifact access states must be explicit.

## Design Principles

1. Lead with the room, not the backend.
   Users should experience Firebase, Firestore, Storage, and local draft state as product states, not implementation details.

2. Make uncertainty visible.
   Candidate geometry, confirmed geometry, low confidence, invalid calibration, and `Needs review` must be distinguishable through labels, stroke styles, handles, icons, and status text.

3. Preserve work across transitions.
   View switches, reconstruction recovery, reupload, draft restore, and cloud conflict decisions should preserve useful context wherever possible.

4. Keep precision controls stable.
   2D / 3D switchers, camera presets, inspectors, save/export controls, and measurement labels should not jump or resize unpredictably.

5. Separate user planning from admin diagnosis.
   The main product should stay calm and guided. Admin views should be information-dense and operational.

6. Prefer explicit recovery over generic errors.
   Failed upload, permission denial, missing artifact, sync failure, and invalid geometry should each provide a specific next action.

## Visual Direction

### Overall Shell

Use a light neutral application shell with restrained contrast, stable panels, and Material 3 interaction patterns. The app should feel like a professional planning tool rather than a marketing site or a decorative dashboard.

Recommended structure:

- Large central canvas or content surface.
- Compact top app bar for account, project context, and admin access.
- Left or side navigation only when it improves project scanning.
- Right-side inspector for selected project, geometry, or furniture detail on desktop.
- Bottom status / next-action area for save, upload, reconstruction, and export states.

### Canvas And Spatial Language

The spatial editor should be the strongest visual signal in the product.

Use:

- High-contrast but non-harsh overlays.
- Distinct candidate and confirmed geometry styles.
- Visible corner handles with larger hit areas.
- Measurement labels attached to walls or furniture.
- Stable 2D / 3D segmented control.
- Camera reset, fit-to-room, and preset controls as icon buttons with tooltips.

Avoid:

- Decorative gradients or abstract hero art as the primary product surface.
- Floating cards over geometry when they hide the object being edited.
- Color-only state distinctions.
- Treating the 3D view as a passive preview detached from the 2D model.

### Status Language

Use direct status labels:

- Ready
- Uploading
- Uploaded
- Processing
- Needs review
- Manual input needed
- Saving
- Saved
- Unsaved draft
- Sync failed
- Retry available
- Permission required
- Export warning

Avoid raw user-facing labels such as:

- Firestore denied
- Storage rules failed
- `review_required`
- `permission-denied`
- OpenCV exception

Technical labels may appear in admin screens.

## Core Screen Concepts

### 1. Sign In And Return

Purpose: Let users enter saved RoomForge work through Google sign-in.

Design direction:

- Simple app entry with RoomForge name, short value copy, and Google sign-in action.
- Firebase configuration or auth failure should show a clear developer/user message.
- Returning signed-in users should move directly to projects or last active project.

### 2. Project Workspace

Purpose: Let users see, create, and reopen room projects.

Design direction:

- Project list should prioritize name, recent activity, saved status, and optional room thumbnail.
- Empty state should offer a concrete next action: start from photo.
- Project detail should expose dimensions, source image state, reconstruction status, and layout status without overwhelming the list.

### 3. Photo Upload And Suitability

Purpose: Bring a source room photo into the workflow with confidence.

Design direction:

- Upload target with accepted file types and size expectations.
- Preview and suitability guidance.
- Progress state with accessible text.
- Rejected, low-quality, permission, and metadata-save failure states with retry or replacement actions.

### 4. Reconstruction Review

Purpose: Make OpenCV assistance understandable and correctable.

Design direction:

- Source photo is primary.
- Candidate overlays are visible but clearly marked as suggestions.
- Confirmed geometry is visually stronger than candidates.
- Weak detection copy should frame correction as normal collaboration.
- Main action should be "Confirm outline" or "Continue with corrected outline," not algorithm language.

### 5. Scale And Floor Plan

Purpose: Anchor the room in real dimensions and produce a metric floor plan.

Design direction:

- Show known length input and clear unit labels.
- Attach measurement labels to geometry, not detached form-only summaries.
- Disable metric generation until geometry and scale are valid.
- Mark recalculation needed if geometry or calibration changes after plan generation.

### 6. 2D / 3D Planning Editor

Purpose: Let users inspect the room and place furniture at usable scale.

Design direction:

- Desktop-first precision layout.
- Persistent 2D / 3D switcher.
- Large central canvas.
- Right inspector for selected object or room.
- Compact toolbar for add, select, move, rotate, resize, delete, reset, and camera controls.
- Bottom save/export state.
- Furniture edits update the same spatial model across both views.

### 7. Draft Recovery And Conflict

Purpose: Preserve user trust when cloud and local state diverge.

Design direction:

- Use explicit choices: restore draft, discard draft, continue saved version.
- Show timestamps and concise difference indicators where possible.
- Do not make local draft and cloud-saved layout look identical.
- Avoid destructive defaults.

### 8. Admin Diagnostics

Purpose: Let admin users diagnose reconstruction and data issues.

Design direction:

- Dense dashboard with filters for status, user, project, job, date, and failure reason.
- Job detail panel with status timeline, artifacts, OpenCV metadata, layout references, retry history, and permission state.
- Artifact states: available, restricted, missing, failed to load, not generated.
- Retry actions require confirmation and show audit result.

## Priority Design Deliverables

### First Pass

- Sign in screen.
- Project workspace.
- Photo upload state component.
- Reconstruction review screen.
- 2D / 3D editor shell.
- Layout save/export control strip.
- Admin diagnostics list and detail split view.

### Second Pass

- Geometry correction tools.
- Scale/calibration panel.
- Furniture inspector.
- Draft recovery and cloud conflict screens.
- Mobile upload/review layout.
- Admin artifact inspection panel.

## Responsive Direction

| Breakpoint | Design direction |
| --- | --- |
| Mobile | Sign-in, upload, status, lightweight review, saved-layout viewing. Avoid precision furniture editing as the primary mobile task. |
| Tablet | Review and light correction with collapsed inspector and larger touch targets. |
| Desktop | Primary editing experience with large canvas, persistent inspector, compact controls, and save/export state. |
| Wide desktop | Improve canvas visibility, side-by-side 2D / 3D inspection, or admin table density. Do not simply stretch controls. |

## Accessibility Baseline

- App shell, forms, buttons, dialogs, tables, status messages, and non-canvas controls should target WCAG 2.2 AA.
- Every critical state must be readable as text, not only color.
- Keyboard users should be able to sign in, upload, retry, save, export, restore or discard draft, refresh admin role, and navigate admin tables.
- Canvas interactions should provide visible selection, reset/preset controls, textual summaries, and non-color-only overlay distinctions where feasible.

## Initial Concept Risks

| Risk | Design response |
| --- | --- |
| The product feels too technical for normal users. | Keep technical metadata in admin/evaluation surfaces and use action-oriented copy in the main flow. |
| OpenCV uncertainty feels like failure. | Present correction as part of the normal workflow and always offer a next action. |
| Users cannot tell whether work is saved. | Standardize save, draft, sync, and export states across the shell and editor. |
| Admin views leak protected context. | Use explicit permission states and avoid rendering protected data before authorization resolves. |
| 2D and 3D feel disconnected. | Anchor both views to one spatial model and preserve selection, scale, camera, and object identity. |

## Design Acceptance Questions

Before moving from concept to detailed screen design, answer:

- Can a first-time user understand the flow from photo to editable room within one screen sequence?
- Can users tell the difference between candidate geometry, confirmed geometry, and saved layout?
- Is the primary action clear at each phase: upload, confirm, calibrate, generate, edit, save, export?
- Are failed states paired with useful recovery actions?
- Does the editor feel precise without overwhelming upload/review users?
- Do admin screens expose enough diagnostic detail without becoming the default user experience?
- Are mobile, tablet, desktop, and wide desktop responsibilities intentionally different?
