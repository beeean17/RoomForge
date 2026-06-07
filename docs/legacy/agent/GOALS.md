# RoomForge Goals

## Story loop rule

Before running any Goal in this file, read `docs/agent/STORY_QUEUE.md`, `docs/agent/STORY_EXECUTION_LOOP.md`, `docs/agent/AUTO_RUN.md`, `docs/agent/RECOVERY_PLAYBOOK.md`, `docs/agent/BRANCH_STRATEGY.md`, and `docs/agent/COMMIT_POLICY.md` and identify the target story.

The default execution unit is:

```text
1 story = 1 branch = 1 goal = 1 validation loop = 1 completion report = 1 local story commit
```

When the user asks to run the queue or continue automatically:

- create or repair the story branch;
- execute one story Goal;
- run validation, fix failures, and rerun;
- create one local story commit;
- fast-forward merge locally into the primary branch;
- create the next story branch and continue.

Do not push or create a PR/MR unless the user explicitly approves.

These Goals are written for the current project state: **implementation is assumed complete through Story 3.6**.

Use one Goal at a time. Do not implement the full list as one code change. The active queue is controlled by `docs/agent/STORY_EXECUTION_LOOP.md` and `docs/agent/STORY_QUEUE.md`.

---

## Pre-Goal Gate - Verify Story 3.5/3.6 Handoff Before Epic 4

```text
/goal Verify the reconstruction-to-planning-editor handoff before starting Story 4.1.

Current baseline:
- Treat Stories 1.1 through 3.6 as implemented unless repository evidence contradicts this.

Before implementing or changing code, read:
- _bmad-output/planning-artifacts/epics.md Stories 3.5, 3.6, and 4.1
- _bmad-output/planning-artifacts/architecture.md frontend architecture, geometry coordinate-space rules, and Flutter-to-Three.js bridge patterns
- _bmad-output/planning-artifacts/ux-design-specification.md 2D/3D view switcher and editor accessibility expectations

Objective:
Verify that the completed reconstruction flow can hand a valid metric floor plan and status context into the planning editor.

Scope:
- Inspect existing implementation and tests.
- Confirm metric floor plan payload is in meters after calibration.
- Confirm image-pixel geometry remains traceable separately.
- Confirm Story 3.6 warning/failure/retry behavior exists or identify exact gaps.
- Confirm editor bridge or editor initialization can receive floor plan/scene data.
- Do not rebuild the reconstruction flow unless a minimal prerequisite fix is required.

Validation:
- Run relevant app/editor/server checks if available.
- Produce a short handoff checklist with pass/fail/partial evidence.

Completion criteria:
- Handoff readiness is documented.
- Any missing prerequisite is listed with the smallest required fix.
- Next recommended Goal is Story 4.1 if handoff is sufficient.
```

---

## Goal 4.1 - Shared Spatial Model and 2D/3D View Shell

```text
/goal Implement Story 4.1: shared spatial model and 2D/3D view shell.

Before implementing, read:
- _bmad-output/planning-artifacts/epics.md Story 4.1
- _bmad-output/planning-artifacts/architecture.md frontend architecture, editor boundary, bridge format, and coordinate-space rules
- _bmad-output/planning-artifacts/ux-design-specification.md 2D/3D View Switcher, responsive strategy, and accessibility strategy

Objective:
Create a planning editor shell where one shared spatial model drives both 2D and 3D room views, preserving selection, object identity, metric coordinates, scale, and unsaved state across view switches.

Preconditions:
- Story 3.5/3.6 handoff is verified or the missing prerequisite is explicitly fixed.
- A valid metric floor plan exists or a fixture/demo floor plan can initialize the editor.

Scope:
- Define or verify shared spatial model shape for room/floor plan data.
- Add 2D/3D view shell in editor.
- Add Flutter route/control surface needed to open the planning editor.
- Add view switch message/event flow if bridge integration is needed.
- Preserve selection, object identity, metric coordinates, scale, and unsaved state across view switches.
- Make desktop/tablet/mobile-review shell usable without overlapping canvas, view switcher, inspector entry point, or status area.

Non-negotiable constraints:
- 2D and 3D must not maintain divergent layout state.
- Coordinate space must be explicit and metric room data must use meters.
- Editor owns spatial rendering; Flutter owns app shell, controls, inspector/status surfaces, and API calls.
- Do not add furniture editing yet beyond minimal placeholder state required to prove selection persistence.

Validation:
- Open planning editor from app route or documented dev entry point.
- Load valid metric floor plan or fixture.
- Switch 2D/3D and verify selection/object identity/coordinates/scale/unsaved state persist.
- Verify desktop/tablet/mobile-review shell does not overlap critical controls.
- Run editor typecheck/build/test where available.
- Run Flutter analyze/test where affected.

Completion criteria:
- Story 4.1 acceptance criteria are satisfied.
- Shared spatial model contract is documented.
- Checks and manual verification results are reported.
- Next recommended Goal is Story 4.2.
```

---

## Goal 4.2 - 3D Room Inspection Controls

```text
/goal Implement Story 4.2: 3D room inspection controls.

Before implementing, read:
- _bmad-output/planning-artifacts/epics.md Story 4.2
- _bmad-output/planning-artifacts/architecture.md editor camera responsibility and performance targets
- _bmad-output/planning-artifacts/ux-design-specification.md camera controls, motion, and accessibility expectations

Objective:
Add orbit, pan, zoom, reset, fit-to-room, and preset camera views for 3D inspection without changing room or furniture data.

Scope:
- Implement 3D camera controls in editor.
- Add accessible Flutter or editor-adjacent controls for reset, fit-to-room, Top, Front, Corner, and Eye-level.
- Respect reduced-motion preferences.
- Preserve room and furniture data when camera changes.

Validation:
- Camera controls update view without mutating scene data.
- Reset and presets are reachable through non-canvas controls with visible focus and labels where feasible.
- Reduced-motion preference avoids unnecessary easing while preserving understandable state changes.
- 3D view remains usable with valid floor plan fixture.
- Check 30 FPS target where feasible for MVP-scale scene.

Completion criteria:
- Story 4.2 acceptance criteria are satisfied.
- Camera state behavior is documented.
- Next recommended Goal is Story 4.3.
```

---

## Goal 4.3 - Add and Select Furniture Proxy Objects

```text
/goal Implement Story 4.3: add and select furniture proxy objects.

Before implementing, read:
- _bmad-output/planning-artifacts/epics.md Story 4.3
- _bmad-output/planning-artifacts/architecture.md editor furniture and shared scene boundaries
- _bmad-output/planning-artifacts/ux-design-specification.md Furniture Inspector, visual token matrix, and accessibility expectations

Objective:
Let users add and select furniture proxy objects in the shared spatial model with visible non-color-only selection and an inspector/status summary.

Scope:
- Add furniture object model fields: id, category, size, position, rotation, color.
- Add at least MVP proxy categories needed by current implementation or fixtures.
- Render furniture in 2D and 3D from the same shared model.
- Support selecting furniture in 2D or 3D.
- Show inspector properties for selected object.
- Provide textual selection summary where feasible.

Validation:
- Add a furniture proxy object and verify required fields exist.
- Select object in 2D and 3D.
- Verify selected state uses outline/halo/handle/marker and not color alone.
- Verify inspector shows editable or read-only properties according to scope.
- Switch views and verify selected object identity persists.

Completion criteria:
- Story 4.3 acceptance criteria are satisfied.
- Furniture model contract is documented.
- Next recommended Goal is Story 4.4.
```

---

## Goal 4.4 - Move, Rotate, Resize, and Delete Furniture

```text
/goal Implement Story 4.4: move, rotate, resize, and delete furniture proxy objects.

Before implementing, read:
- _bmad-output/planning-artifacts/epics.md Story 4.4
- _bmad-output/planning-artifacts/architecture.md editor interaction and performance targets
- _bmad-output/planning-artifacts/ux-design-specification.md Furniture Inspector, direct manipulation, touch target, and motion guidance

Objective:
Allow selected furniture objects to be moved, rotated, resized, and deleted while keeping 2D and 3D views synchronized from one shared spatial model.

Scope:
- Implement move, rotate, resize, and delete actions.
- Support pointer interactions and/or inspector field controls where feasible.
- Confirm destructive delete if needed.
- Preserve selected/focus state after edits.
- Keep interactions responsive for MVP-scale scenes.

Validation:
- Move, rotate, resize, delete selected object.
- Verify shared spatial model updates within 100 ms where measurable.
- Verify 2D and 3D stay synchronized after each action.
- Verify delete updates selection and inspector state cleanly.
- Verify touch-oriented controls use feasible 44x44px targets.

Completion criteria:
- Story 4.4 acceptance criteria are satisfied.
- Changed files and performance evidence are reported.
- Next recommended Goal is Story 4.5.
```

---

## Goal 4.5 - Scale, Measurement, and Placement Guidance

```text
/goal Implement Story 4.5: scale, measurement, and placement guidance.

Before implementing, read:
- _bmad-output/planning-artifacts/epics.md Story 4.5
- _bmad-output/planning-artifacts/architecture.md coordinate-space and validation patterns
- _bmad-output/planning-artifacts/ux-design-specification.md measurement labels, layer toggles, placement warnings, and non-color-only states

Objective:
Show measurement labels, dimension guidance, and placement warnings that help users understand scale and layout validity.

Scope:
- Display stable numeric measurement labels with units.
- Add dimension/grid/furniture-bound guidance where relevant.
- Detect or surface outside-room or spatial placement warnings.
- Show warnings without relying on color alone.
- Keep labels readable across responsive widths.

Validation:
- Measurement labels include units and stable numeric formatting.
- Placement warning appears for invalid/outside-room placement.
- Warning uses text/icon/shape/pattern in addition to color.
- Labels and warnings remain readable and do not overlap primary controls at desktop/tablet/mobile-review widths.

Completion criteria:
- Story 4.5 acceptance criteria are satisfied.
- Next recommended Goal is Story 4.6.
```

---

## Goal 4.6 - Responsive and Accessible Editor Controls

```text
/goal Implement Story 4.6: responsive and accessible editor controls hardening.

Before implementing, read:
- _bmad-output/planning-artifacts/epics.md Story 4.6
- _bmad-output/planning-artifacts/ux-design-specification.md responsive design and accessibility sections
- _bmad-output/planning-artifacts/architecture.md app/editor responsibility boundary

Objective:
Harden the planning editor so controls work across desktop, tablet, and mobile-review contexts with WCAG 2.2 AA non-canvas targets and best-effort canvas accessibility.

Scope:
- Validate desktop layout: central canvas, compact controls, persistent 2D/3D switcher, right inspector, bottom status/next-action area.
- Validate tablet/mobile-review layout: larger touch targets and collapsible panels.
- Improve keyboard/focus/labels for non-canvas controls.
- Add textual summaries for selection/status where feasible.
- Respect reduced motion.

Validation:
- Desktop layout verification.
- Tablet and mobile-review layout verification.
- Keyboard navigation and visible focus for non-canvas controls.
- Touch targets feasible at 44x44px where applicable.
- Non-color-only selected/warning states verified.
- Reduced-motion behavior verified.

Completion criteria:
- Story 4.6 acceptance criteria are satisfied.
- Epic 4 is ready for persistence/export work.
- Next recommended Goal is Story 5.1.
```

---

## Goal 5.1 - Save Layout with Room and Furniture State

```text
/goal Implement Story 5.1: save layout with room and furniture state.

Before implementing, read:
- _bmad-output/planning-artifacts/epics.md Story 5.1
- _bmad-output/planning-artifacts/architecture.md layout persistence, API envelope, Oracle repository patterns, and ownership rules
- _bmad-output/planning-artifacts/prd.md Layout Persistence & Export and Data Integrity NFRs

Objective:
Allow a signed-in user to save a valid room layout containing room dimensions, floor plan data, source metadata references, and furniture objects.

Scope:
- Add or update save layout API/UI.
- Persist room dimensions, floor plan data, source metadata references, and furniture objects.
- Preserve furniture ID, category, position, size, rotation, and color.
- Show `Saved` or `Save failed` status language.
- Enforce authentication and ownership.

Validation:
- Save valid layout.
- Verify persisted payload contains required domain fields.
- Verify furniture fields are preserved.
- Verify unauthenticated or cross-user save fails safely.
- Verify response envelope includes data/error/meta.request_id.

Completion criteria:
- Story 5.1 acceptance criteria are satisfied.
- Next recommended Goal is Story 5.2.
```

---

## Goal 5.2 - Load Saved Layout

```text
/goal Implement Story 5.2: load saved layout.

Before implementing, read:
- _bmad-output/planning-artifacts/epics.md Story 5.2
- _bmad-output/planning-artifacts/architecture.md layout APIs, repository patterns, and ownership rules

Objective:
Allow a signed-in user to load their own saved layout and restore the shared spatial model accurately in 2D and 3D.

Scope:
- Add or update load layout API/UI.
- Return saved room dimensions, floor plan, source metadata references, and furniture state.
- Restore editor shared spatial model from loaded layout.
- Deny cross-user layout access without exposing data.

Validation:
- Load owned saved layout.
- Verify shared spatial model restores accurately in 2D and 3D.
- Verify cross-user access is denied.
- Verify API envelope and ownership behavior.

Completion criteria:
- Story 5.2 acceptance criteria are satisfied.
- Next recommended Goal is Story 5.3.
```

---

## Goal 5.3 - Export Layout as JSON

```text
/goal Implement Story 5.3: export layout as JSON.

Before implementing, read:
- _bmad-output/planning-artifacts/epics.md Story 5.3
- _bmad-output/planning-artifacts/architecture.md export response patterns and API envelope
- _bmad-output/planning-artifacts/prd.md Layout Persistence & Export and review_required warning requirements

Objective:
Allow a signed-in user to export their own saved or current valid layout as JSON.

Scope:
- Produce JSON file or response containing room dimensions, floor plan data, source metadata references, and furniture state.
- Show visible warning before export if current reconstruction status is `review_required` / displayed as `Needs review`.
- Use `Export failed` for export errors.
- Enforce authentication and ownership.

Validation:
- Export owned valid layout.
- Verify JSON includes required fields.
- Verify review-required warning appears before export is allowed.
- Verify export failure displays `Export failed` with retry path where feasible.
- Verify cross-user export is denied.

Completion criteria:
- Story 5.3 acceptance criteria are satisfied.
- Next recommended Goal is Story 5.4.
```

---

## Goal 5.4 - Save, Load, and Export Round-Trip Validation

```text
/goal Implement Story 5.4: save, load, and export round-trip validation.

Before implementing, read:
- _bmad-output/planning-artifacts/epics.md Story 5.4
- _bmad-output/planning-artifacts/prd.md Data Integrity NFRs
- _bmad-output/planning-artifacts/architecture.md layout persistence and performance patterns

Objective:
Add automated or documented validation proving that layout save/load/export preserves required layout and furniture fields exactly except server-managed metadata.

Scope:
- Create round-trip fixture/test for layout data.
- Save, load, and export the fixture.
- Compare required fields for exact preservation.
- Check non-CV API p95 target where measurable.

Validation:
- Round-trip comparison passes for room dimensions, floor plan data, source metadata references, furniture IDs, categories, positions, sizes, rotations, and colors.
- Server-managed metadata is excluded from exact comparison.
- Project list/detail/layout save/load p95 target is measured or documented if not measurable.

Completion criteria:
- Story 5.4 acceptance criteria are satisfied.
- Epic 5 is ready for admin/troubleshooting work.
- Next recommended Goal is Story 6.1.
```

---

## Goal 6.1 - Admin Job List and Status Filters

```text
/goal Implement Story 6.1: admin job list and status filters.

Before implementing, read:
- _bmad-output/planning-artifacts/epics.md Story 6.1
- _bmad-output/planning-artifacts/architecture.md admin routes, authorization, status vocabulary, and API envelope
- _bmad-output/planning-artifacts/ux-design-specification.md Admin Ops Console and CV Job Status Timeline

Objective:
Allow authenticated admins to view reconstruction jobs grouped or filtered by allowed status values, while normal users are denied access.

Scope:
- Admin job list UI/API.
- Filters for created, uploading, processing, review_required, succeeded, failed, timeout, cancelled, retrying.
- Admin authorization distinct from normal authentication.
- Standard API envelope and `unauthorized` error for normal users.

Validation:
- Admin can view/filter jobs by all allowed statuses.
- Normal user cannot call admin job APIs.
- Status vocabulary matches persisted statuses exactly.
- `review_required` displays as `Needs review` in UI where user-facing copy is used.

Completion criteria:
- Story 6.1 acceptance criteria are satisfied.
- Next recommended Goal is Story 6.2.
```

---

## Goal 6.2 - Admin Job Detail and Event Trail

```text
/goal Implement Story 6.2: admin job detail and event trail.

Before implementing, read:
- _bmad-output/planning-artifacts/epics.md Story 6.2
- _bmad-output/planning-artifacts/architecture.md job status patterns, event trail, admin lookup, and status transition persistence

Objective:
Let admins inspect job details and status transitions to understand reconstruction history.

Scope:
- Job detail page/API.
- Show project/job header, current status, timestamps, provider or algorithm identifier, retry count, and failure reason where available.
- Show event trail with status, timestamp, actor/source, reason code, human-readable reason, and retry linkage where available.

Validation:
- Admin can load job detail.
- Event trail renders required fields where available.
- Normal user access is denied.
- API envelope and status vocabulary remain correct.

Completion criteria:
- Story 6.2 acceptance criteria are satisfied.
- Next recommended Goal is Story 6.3.
```

---

## Goal 6.3 - Admin OpenCV Artifact Viewer

```text
/goal Implement Story 6.3: admin OpenCV artifact viewer.

Before implementing, read:
- _bmad-output/planning-artifacts/epics.md Story 6.3
- _bmad-output/planning-artifacts/architecture.md OpenCV result persistence, candidate/confirmed separation, coordinate-space rules, and admin artifact visibility
- _bmad-output/planning-artifacts/ux-design-specification.md Admin CV Artifact Viewer and visual token matrix

Objective:
Allow admins to inspect original image access, candidate preview, confidence/failure metadata, calibration summary, and user correction status.

Scope:
- Admin artifact viewer UI/API.
- Show candidate and confirmed geometry visually and structurally separated.
- Include coordinate-space details where available.
- Show confidence/failure metadata and calibration summary.

Validation:
- Admin can inspect artifacts for a job with OpenCV output.
- Candidate and confirmed geometry are not merged.
- Normal user access is denied.
- Artifact missing/permission restricted states are handled.

Completion criteria:
- Story 6.3 acceptance criteria are satisfied.
- Next recommended Goal is Story 6.4.
```

---

## Goal 6.4 - Admin Retry Failed Jobs

```text
/goal Implement Story 6.4: admin retry failed jobs.

Before implementing, read:
- _bmad-output/planning-artifacts/epics.md Story 6.4
- _bmad-output/planning-artifacts/architecture.md retry attempts, job transitions, and admin action audit patterns

Objective:
Allow admins to retry failed or timed-out jobs where supported while preserving previous failure history.

Scope:
- Retry action for retryable failed/timed-out jobs.
- Create new retry attempt linked to original job.
- Preserve previous failure history.
- Explain why retry is unavailable when not supported.
- Audit admin action where implemented.

Validation:
- Retryable failed/timed-out job creates linked retry attempt.
- Previous failure history remains visible.
- Unsupported retry shows clear explanation.
- Normal user access is denied.

Completion criteria:
- Story 6.4 acceptance criteria are satisfied.
- Next recommended Goal is Story 6.5.
```

---

## Goal 6.5 - Admin Search Across Users, Projects, Layouts, and Jobs

```text
/goal Implement Story 6.5: admin search across users, projects, layouts, and jobs.

Before implementing, read:
- _bmad-output/planning-artifacts/epics.md Story 6.5
- _bmad-output/planning-artifacts/architecture.md admin search, authorization, API envelope, and repository boundaries
- _bmad-output/planning-artifacts/ux-design-specification.md admin search/filter patterns

Objective:
Allow support/admin users to search by user, project, layout, or job identifier and navigate to details.

Scope:
- Admin search UI/API.
- Return enough context to navigate to details.
- Empty state for no results.
- Do not expose unauthorized data.

Validation:
- Admin search returns matching records.
- No-match search shows empty state.
- Normal user access is denied.
- Results are scoped and do not expose unauthorized data.

Completion criteria:
- Story 6.5 acceptance criteria are satisfied.
- Next recommended Goal is Story 6.6.
```

---

## Goal 6.6 - Provider State and Failure Source Diagnosis

```text
/goal Implement Story 6.6: provider state and failure source diagnosis.

Before implementing, read:
- _bmad-output/planning-artifacts/epics.md Story 6.6
- _bmad-output/planning-artifacts/architecture.md provider state, failure-source categories, and optional provider boundaries
- _bmad-output/planning-artifacts/ux-design-specification.md admin provider/status visibility and recovery language

Objective:
Let admins distinguish OpenCV/manual-assisted provider state and failure sources across input quality, OpenCV candidate detection, user calibration, API handling, database state, and optional provider processing.

Scope:
- Provider state panel or API response.
- Show OpenCV/manual-assisted provider details, active job count, recent failure state, and optional GPU lifecycle fields only when enabled.
- Show failure source classification where known.
- Do not fake optional provider state when disabled.

Validation:
- Admin sees provider state where available.
- Failure source classification appears for known failures.
- Optional future GPU fields are disabled/absent/documented when not enabled.
- Normal user access is denied.

Completion criteria:
- Story 6.6 acceptance criteria are satisfied.
- Epic 6 is complete for MVP-critical admin operations.
- Final report lists remaining MVP hardening, deployment, and usability-review follow-ups.
```
