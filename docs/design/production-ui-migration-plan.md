# RoomForge Production UI Migration Plan

This plan maps the 21 HTML design screens in `docs/design/screens/` into the
actual RoomForge app UI. The implementation rule is strict:

```text
1 screen = 1 goal = 1 validation loop = 1 local commit
```

Do not combine multiple screens in one UI commit. Do not push or open a PR unless
the user explicitly approves it.

## Source Of Truth

- Desktop HTML: `docs/design/screens/desktop/NN-name.html`
- Mobile HTML: `docs/design/screens/mobile/NN-name.html`
- Screen spec: `docs/design/specs/NN-name.md`
- Shared HTML tokens: `docs/design/system/tokens.css`
- Shared component behavior: `docs/design/system/base.css`,
  `docs/design/system/motion.js`

The production UI should match the HTML screen as closely as the real app
boundaries allow. If the production behavior must differ, document the reason in
the commit body and keep the visual language identical.

## Implementation Boundaries

- Flutter owns auth, project workspace, project workflow, upload/status surfaces,
  admin surfaces, accessible non-canvas controls, and API calls.
- Three.js/editor owns source-image overlays, CV candidates, geometry handles,
  calibration, 2D/3D canvas behavior, furniture manipulation, and spatial
  validation.
- API/backend behavior should not be changed for visual migration unless a screen
  cannot render real state without a small adapter.
- Candidate geometry and user-confirmed geometry must stay visually and
  structurally distinct.
- User-facing status text must preserve the persisted reconstruction statuses:
  `created`, `uploading`, `processing`, `review_required`, `succeeded`,
  `failed`, `timeout`, `cancelled`, `retrying`.

## Commit Policy

Use one local commit per screen with this message form:

```text
design(ui): port NN screen-name
```

Rules:

- The screen goal must be written before implementation starts.
- Each commit may include only the files needed for that screen.
- Shared tokens/helpers are allowed only when first required by that screen; put
  that shared work in the same screen commit and mention it in the commit body.
- Existing WIP for screens 01-03 must be split into screen-sized staged changes
  before committing. If a helper is shared by 01-03, stage it with the first
  screen that requires it and keep later commits focused.
- Run validation before each commit. If validation fails due to current-screen
  code, fix and rerun before committing.

## Global Validation Commands

Flutter screens:

```bash
cd app
flutter analyze
flutter test
```

Editor screens:

```bash
cd editor
npm run build
```

Editor story checks should be added when the screen touches matching behavior:

```bash
cd editor
npm run test:story-4.1
npm run test:story-4.2
npm run test:story-4.3
npm run test:story-4.4
npm run test:story-4.5
npm run test:story-4.6
```

For every screen commit, also verify the rendered UI in a browser at the relevant
desktop and mobile widths. The minimum screenshot widths are `1440`, `1024`,
`768`, and `390`.

## Screen Goals And Commits

### 01. Sign In

- Goal: Match `01-sign-in` as the premium charcoal auth entry, including brand
  panel, Google provider button, idle/signing/failed states, config notice, focus
  states, and mobile bottom-sheet treatment.
- Sources: `screens/desktop/01-sign-in.html`,
  `screens/mobile/01-sign-in.html`, `specs/01-sign-in.md`
- Targets: `app/lib/main.dart` (`SignInScreen`, auth state copy, shared visual
  primitives required by the auth screen)
- Validation: Flutter analyze/test, desktop/mobile browser render, sign-in busy
  state and config-missing state.
- Commit: `design(ui): port 01 sign in`

### 02. Project Workspace

- Goal: Match `02-project-workspace` with the project list/detail split view,
  search/filter controls, selected project preview, empty/loading/error states,
  and compact mobile workspace.
- Sources: `screens/desktop/02-project-workspace.html`,
  `screens/mobile/02-project-workspace.html`,
  `specs/02-project-workspace.md`
- Targets: `app/lib/main.dart` (`ProjectWorkspaceScreen`,
  `ProjectWorkspaceBody`, project list/detail widgets)
- Validation: Flutter analyze/test, browser render with empty project list and
  selected project state.
- Commit: `design(ui): port 02 project workspace`

### 03. Project Dialog

- Goal: Match `03-project-dialog` for create/edit/delete-confirm flows, including
  dark dialog shell, field validation, save/cancel states, danger zone, and mobile
  sheet behavior.
- Sources: `screens/desktop/03-project-dialog.html`,
  `screens/mobile/03-project-dialog.html`, `specs/03-project-dialog.md`
- Targets: `app/lib/main.dart` (`ProjectEditorDialog`)
- Validation: Flutter analyze/test, create and edit dialog render, validation
  error state, destructive-action affordance.
- Commit: `design(ui): port 03 project dialog`

### 04. Room Dimensions

- Goal: Match `04-room-dimensions` so users can enter width/depth/height in
  meters, see a proportional preview, understand save state, and recover from
  missing/invalid dimensions.
- Sources: `screens/desktop/04-room-dimensions.html`,
  `screens/mobile/04-room-dimensions.html`, `specs/04-room-dimensions.md`
- Targets: `app/lib/main.dart` (`RoomDimensionsSection`, project detail workflow)
- Validation: Flutter analyze/test, dimension save/loading/error states, mobile
  input ergonomics.
- Commit: `design(ui): port 04 room dimensions`

### 05. Source Image Upload

- Goal: Match `05-source-image-upload` with upload drop/select controls, quality
  warnings, upload progress, permission/error states, retry controls, and guided
  capture role upload cards.
- Sources: `screens/desktop/05-source-image-upload.html`,
  `screens/mobile/05-source-image-upload.html`,
  `specs/05-source-image-upload.md`
- Targets: `app/lib/main.dart`, `app/lib/src/projects/*source_image*`,
  `app/lib/src/projects/guided_capture_session_section.dart`
- Validation: Flutter analyze/test, ready/uploading/uploaded/failed states,
  keyboard and touch targets.
- Commit: `design(ui): port 05 source image upload`

### 06. Reconstruction Status

- Goal: Match `06-reconstruction-status` with job timeline, current status chip,
  retry affordance, review-required guidance, failure reasons, and polling state.
- Sources: `screens/desktop/06-reconstruction-status.html`,
  `screens/mobile/06-reconstruction-status.html`,
  `specs/06-reconstruction-status.md`
- Targets: `app/lib/main.dart` (`ReconstructionJobSection`, project detail
  workflow)
- Validation: Flutter analyze/test, all persisted statuses render with matching
  labels, retry/review-required paths.
- Commit: `design(ui): port 06 reconstruction status`

### 07. OpenCV Candidate Review

- Goal: Match `07-opencv-candidate-review` so CV candidates appear over the
  source image/canvas with confidence, candidate tray, accept/reject/edit
  affordances, and visible manual fallback.
- Sources: `screens/desktop/07-opencv-candidate-review.html`,
  `screens/mobile/07-opencv-candidate-review.html`,
  `specs/07-opencv-candidate-review.md`
- Targets: `editor/src/main.ts`, `editor/src/style.css`,
  `editor/src/candidateTray.ts`, `editor/src/opencvWorker.ts`, Flutter bridge
  status copy if needed.
- Validation: `npm run build`, relevant CV candidate checks, browser render with
  candidate/confirmed distinction, Flutter analyze if bridge changes.
- Commit: `design(ui): port 07 opencv candidate review`

### 08. Geometry Correction

- Goal: Match `08-geometry-correction` with editable room-boundary handles,
  corner labels, invalid-geometry warnings, reset-to-candidate, and clear
  confirmed-geometry state.
- Sources: `screens/desktop/08-geometry-correction.html`,
  `screens/mobile/08-geometry-correction.html`,
  `specs/08-geometry-correction.md`
- Targets: `editor/src/main.ts`, `editor/src/style.css`,
  `editor/src/spatialModel.ts`, Flutter bridge status copy if needed.
- Validation: `npm run build`, handle interaction browser check, invalid polygon
  warning, confirmed-geometry bridge event.
- Commit: `design(ui): port 08 geometry correction`

### 09. Scale Calibration

- Goal: Match `09-scale-calibration` with calibration baseline controls, pixel to
  meters conversion copy, measurement guidance, generated floor-plan state, and
  validation for impossible lengths.
- Sources: `screens/desktop/09-scale-calibration.html`,
  `screens/mobile/09-scale-calibration.html`, `specs/09-scale-calibration.md`
- Targets: `editor/src/main.ts`, `editor/src/style.css`,
  `editor/src/measurementGuidance.ts`, Flutter bridge status copy if needed.
- Validation: `npm run build`, `npm run test:story-4.5` when behavior changes,
  browser render for valid/invalid calibration.
- Commit: `design(ui): port 09 scale calibration`

### 10. Floor Plan Review

- Goal: Match `10-floor-plan-review` with metric floor plan preview, coordinate
  space labels, warnings, artifact status, and primary transition into the editor.
- Sources: `screens/desktop/10-floor-plan-review.html`,
  `screens/mobile/10-floor-plan-review.html`, `specs/10-floor-plan-review.md`
- Targets: `app/lib/main.dart` (`ProjectDetailPanel`, editor launch section),
  `editor/src/main.ts` if preview rendering changes.
- Validation: Flutter analyze/test, editor build if touched, browser render for
  succeeded and review-required floor-plan states.
- Commit: `design(ui): port 10 floor plan review`

### 11. Editor

- Goal: Match `11-editor` with full-height canvas-first shell, tool rail, 2D/3D
  view switch, floating toolbar, inspector dock/sheet, status bar, and
  non-carded canvas.
- Sources: `screens/desktop/11-editor.html`,
  `screens/mobile/11-editor.html`, `specs/11-editor.md`
- Targets: `editor/src/main.ts`, `editor/src/style.css`,
  `editor/src/cameraControls.ts`, `app/lib/main.dart` (`EditorBridgeScreen`,
  command bar)
- Validation: `npm run build`, `npm run test:story-4.1`,
  `npm run test:story-4.2`, `npm run test:story-4.6`, Flutter analyze/test if
  bridge changes, desktop/mobile canvas screenshot.
- Commit: `design(ui): port 11 editor`

### 12. Furniture Inspector

- Goal: Match `12-furniture-inspector` with furniture catalog, selected object
  inspector, move/rotate/resize/delete controls, locked state, collision/warning
  state, and mobile bottom-sheet controls.
- Sources: `screens/desktop/12-furniture-inspector.html`,
  `screens/mobile/12-furniture-inspector.html`,
  `specs/12-furniture-inspector.md`
- Targets: `editor/src/main.ts`, `editor/src/style.css`,
  `editor/src/furnitureModel.ts`, `editor/src/scenePlacement.ts`,
  `app/lib/src/layouts/layout_furniture_bridge_mapper.dart` if needed.
- Validation: `npm run build`, `npm run test:story-4.3`,
  `npm run test:story-4.4`, browser interaction check for selection and edits.
- Commit: `design(ui): port 12 furniture inspector`

### 13. Layout Save Load Export

- Goal: Match `13-layout-save-export` with save/load/export actions, autosave
  chip, JSON export state, round-trip validation, remote failure copy, and
  guarded export when layout is invalid.
- Sources: `screens/desktop/13-layout-save-export.html`,
  `screens/mobile/13-layout-save-export.html`,
  `specs/13-layout-save-export.md`
- Targets: `app/lib/main.dart` (`EditorBridgeScreen`,
  `_EditorBridgeCommandBar`), `app/lib/src/layouts/*`, editor bridge state if
  needed.
- Validation: Flutter analyze/test, editor build if touched, save/load/export
  status states, export warning state.
- Commit: `design(ui): port 13 layout save export`

### 14. Draft Recovery

- Goal: Match `14-draft-recovery` with local draft versus cloud conflict
  comparison, restore/discard/continue actions, timestamps, conflict severity,
  and clear recovery copy.
- Sources: `screens/desktop/14-draft-recovery.html`,
  `screens/mobile/14-draft-recovery.html`, `specs/14-draft-recovery.md`
- Targets: `app/lib/src/layouts/layout_draft_recovery_controls.dart`,
  `app/lib/src/layouts/layout_draft_recovery.dart`, `app/lib/main.dart`
- Validation: Flutter analyze/test, draft/no-draft/conflict states, keyboard
  reachable recovery actions.
- Commit: `design(ui): port 14 draft recovery`

### 15. Sync Failed

- Goal: Match `15-sync-failed` with differentiated network/permission/server
  failure treatment, retry/reupload paths, offline-safe copy, and persistent
  non-color-only error indicators.
- Sources: `screens/desktop/15-sync-failed.html`,
  `screens/mobile/15-sync-failed.html`, `specs/15-sync-failed.md`
- Targets: `app/lib/main.dart`, `app/lib/src/projects/source_image_upload_recovery_controls.dart`,
  `app/lib/src/layouts/layout_remote_update_guard.dart`
- Validation: Flutter analyze/test, upload retry state, save retry state,
  permission and network copy.
- Commit: `design(ui): port 15 sync failed`

### 16. Admin Route Guard

- Goal: Match `16-admin-route-guard` with admin access check, non-admin denial,
  role refresh, legacy-admin fallback messaging, and secure admin-only entry.
- Sources: `screens/desktop/16-admin-route-guard.html`,
  `screens/mobile/16-admin-route-guard.html`,
  `specs/16-admin-route-guard.md`
- Targets: `app/lib/main.dart` (`AdminRouteGuardButton`,
  `FirebaseAdminDiagnosticsScreen` entry), `app/lib/src/admin/*`
- Validation: Flutter analyze/test, admin/non-admin/loading/error states, no raw
  internal admin errors in user-facing copy.
- Commit: `design(ui): port 16 admin route guard`

### 17. Admin Dashboard

- Goal: Match `17-admin-dashboard` with status filters, exact lookup, job table,
  search result cards, selected job summary, and wide split layout.
- Sources: `screens/desktop/17-admin-dashboard.html`,
  `screens/mobile/17-admin-dashboard.html`,
  `specs/17-admin-dashboard.md`
- Targets: `app/lib/main.dart` (`FirebaseAdminDiagnosticsScreen`,
  `_FirebaseAdminJobList`, legacy `AdminShellScreen`)
- Validation: Flutter analyze/test, empty/loading/error/search states, responsive
  admin split layout.
- Commit: `design(ui): port 17 admin dashboard`

### 18. Admin Job Detail

- Goal: Match `18-admin-job-detail` with job metadata, status transitions,
  artifact references, OpenCV results, confirmed layouts, coordinate-space
  labels, and readable JSON previews.
- Sources: `screens/desktop/18-admin-job-detail.html`,
  `screens/mobile/18-admin-job-detail.html`,
  `specs/18-admin-job-detail.md`
- Targets: `app/lib/main.dart` (`_FirebaseAdminJobDetailPanel`,
  `_FirebaseAdminArtifactRefs`, `_FirebaseAdminResults`,
  `_FirebaseAdminLayouts`, legacy detail panels)
- Validation: Flutter analyze/test, artifact generated/not-generated/failed
  states, transition and result streams.
- Commit: `design(ui): port 18 admin job detail`

### 19. Admin Retry Audit

- Goal: Match `19-admin-retry-audit` with retry eligibility, confirmation
  dialog, linked retry job result, audit trail, actor/time labels, and unavailable
  retry explanation.
- Sources: `screens/desktop/19-admin-retry-audit.html`,
  `screens/mobile/19-admin-retry-audit.html`,
  `specs/19-admin-retry-audit.md`
- Targets: `app/lib/main.dart` (`_FirebaseAdminRetryAction`,
  `_FirebaseAdminTransitions`, legacy retry controls), `app/lib/src/admin/*`
- Validation: Flutter analyze/test, retry allowed/disallowed/loading/success
  states, audit trail visible after retry.
- Commit: `design(ui): port 19 admin retry audit`

### 20. Responsive Layouts

- Goal: Match `20-responsive-layouts` by making mobile, tablet, desktop, and wide
  layouts consistent across the implemented screens, including editor bottom
  sheets, collapsible inspectors, admin wide split view, and reduced-motion
  behavior.
- Sources: `screens/desktop/20-responsive-layouts.html`,
  `screens/mobile/20-responsive-layouts.html`,
  `specs/20-responsive-layouts.md`
- Targets: Cross-cutting responsive code in `app/lib/main.dart`,
  `editor/src/style.css`, and shared layout helpers touched by earlier screens.
- Validation: Flutter analyze/test, `npm run build`, `npm run test:story-4.6`,
  browser screenshots at `390`, `768`, `1024`, and `1440`.
- Commit: `design(ui): port 20 responsive layouts`

### 21. Templates A11y

- Goal: Match `21-templates-a11y` by unifying empty, loading, error, warning,
  success, focus, aria-live, keyboard, and reduced-motion treatments across all
  production screens.
- Sources: `screens/desktop/21-templates-a11y.html`,
  `screens/mobile/21-templates-a11y.html`, `specs/21-templates-a11y.md`
- Targets: Shared Flutter widgets in `app/lib/main.dart`,
  `app/lib/src/projects/*recovery*`, `app/lib/src/layouts/*recovery*`,
  `editor/src/style.css`, editor accessibility attributes.
- Validation: Flutter analyze/test, `npm run build`, keyboard traversal,
  focus-visible states, reduced-motion check, no color-only status indicators.
- Commit: `design(ui): port 21 templates a11y`

## Execution Order

1. Split and commit current WIP for screens 01, 02, and 03.
2. Continue core project workflow screens 04, 05, and 06.
3. Move into CV/editor screens 07 through 13.
4. Implement recovery screens 14 and 15.
5. Implement admin screens 16 through 19.
6. Finish with responsive and accessibility consolidation screens 20 and 21.

This order keeps the user journey usable after each commit while respecting the
screen-by-screen commit rule.

