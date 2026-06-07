# Firebase Screen Design Inventory

This document lists the RoomForge screens and UI states that need design coverage for the Firebase refactor. It is based on the product UX specification, Firebase UX specification, and current Flutter implementation surface.

## P0 User Core Flow

| Screen | Required states and design coverage |
| --- | --- |
| Sign in | Firebase config missing, signing in, sign-in failed. |
| Project list / workspace | Empty list, loading, error, project selected. |
| Project create / edit dialog | Name and description input, validation, save failure. |
| Project detail | Project metadata, edit, delete, delete confirmation. |
| Room dimension input | Width, depth, height, default height, meters unit. |
| Source image upload | Empty, dragging, uploading, uploaded, invalid type, too large, metadata save failed, permission denied. |
| Reconstruction submit / status | `created`, `uploading`, `processing`, `review_required` shown as `Needs review`, `succeeded`, `failed`, `timeout`, `retrying`. |
| OpenCV candidate review | Candidate preview, candidate selection, reset, manual outline, low confidence. |
| Geometry correction | Corner drag, invalid polygon, correction tools. |
| Scale / calibration | Known wall length, invalid calibration, recalculation needed. |
| Metric floor plan review | Meter-space floor plan, warnings, artifact references. |
| 2D / 3D editor shell | View switch, camera reset, fit-to-room, selection preservation. |
| Furniture add / select | Furniture catalog or presets, empty catalog. |
| Furniture inspector | Move, rotate, resize, delete, locked state, placement warning. |
| Layout save / load / export | Unsaved, saving, saved, save failed, load failed, export warning, export failed. |

## P1 Recovery And Continuity

| Screen | Required states and design coverage |
| --- | --- |
| Unsaved draft recovery | Restore, discard, continue saved version. |
| Cloud / local conflict resolver | Cloud newer, local draft exists, explicit choice. |
| Sync failed state | Retry, keep draft, permission failure. |
| Reupload / reconstruction recovery | Preserve useful prior input, mark recalculation needed. |
| Project reopen with saved layout | Latest cloud layout, draft detected, missing layout. |

## P1 Admin And Support

| Screen | Required states and design coverage |
| --- | --- |
| Admin route guard | Checking role, non-admin denied, stale role, refresh role. |
| Admin dashboard / job list | Status filter, empty, loading, permission denied. |
| Admin search | User, project, job, and status search; no results. |
| Admin job detail | Job metadata, owner, project, provider, status. |
| Status transition timeline | Created, processing, review, failed, retry history. |
| Artifact inspection | Available, restricted, missing, failed to load, not generated. |
| OpenCV result inspection | Candidate count, confidence, runtime, failure reason. |
| Layout references panel | Saved layouts by owner or job, `review_required` state. |
| Admin retry dialog / action | Confirm retry, retry unavailable, audited action created. |
| Admin permission / error states | No protected data leakage in denied or failed states. |

## P2 Responsive And Quality Coverage

| Screen | Required states and design coverage |
| --- | --- |
| Mobile upload / review flow | Capture, upload, status, lightweight review. |
| Tablet review / editor flow | Collapsed inspector, larger touch targets. |
| Desktop precision editor | Large canvas, right inspector, bottom status. |
| Accessibility states | Keyboard focus, screen-reader labels, non-color-only warnings. |
| Empty / loading / error templates | Project empty, admin empty, editor empty, network and permission errors. |

## Current Implementation Anchors

The current Flutter implementation already has these screen-level anchors:

- `SignInScreen`
- `ProjectWorkspaceScreen`
- `ProjectDetailPanel`
- `EditorBridgeScreen`
- `FirebaseAdminDiagnosticsScreen`

Use these as implementation anchors when revising visual design, but do not limit the design inventory to the current widget structure. The UX-critical gaps that still need explicit screen design are:

- OpenCV review and correction.
- Scale and calibration.
- Furniture inspector.
- Draft conflict recovery.
- Admin search and detailed diagnosis.

## Design Invariants

- Flutter owns navigation, auth state, project screens, upload UI, reconstruction workflow UI, inspectors, admin UI, accessible controls, and Firebase calls.
- Three.js owns source-image alignment, OpenCV overlays, geometry handles, 2D / 3D rendering, camera behavior, furniture manipulation, and spatial validation.
- The editor must not import Firebase SDKs or call Firestore, Storage, Auth, or Firebase config directly.
- Persisted Firestore fields and export JSON use `snake_case`.
- Dart fields and editor bridge payloads use `camelCase`.
- Persisted `review_required` displays to users as `Needs review`.
- Admin surfaces must show permission states without leaking protected data.
