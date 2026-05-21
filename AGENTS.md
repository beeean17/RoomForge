# RoomForge Agent Instructions

## Purpose

You are working on RoomForge, a web-first room reconstruction and furniture planning app.

Do not implement the whole MVP at once. Work story-by-story, keep changes scoped, verify acceptance criteria, and report exactly what changed.

## Current baseline

The user has stated that implementation is currently complete through **Story 3.6**.

Treat Stories 1.1 through 3.6 as the current baseline unless repository evidence contradicts that. Do not reimplement earlier stories unless the current Goal explicitly asks for a bug fix, integration gap, or regression fix.

Default next implementation sequence:

1. Story 4.1 - Shared Spatial Model and 2D/3D View Shell
2. Story 4.2 - 3D Room Inspection Controls
3. Story 4.3 - Add and Select Furniture Proxy Objects
4. Story 4.4 - Move, Rotate, Resize, and Delete Furniture
5. Story 4.5 - Scale, Measurement, and Placement Guidance
6. Story 4.6 - Responsive and Accessible Editor Controls
7. Story 5.1 - Save Layout with Room and Furniture State
8. Story 5.2 - Load Saved Layout
9. Story 5.3 - Export Layout as JSON
10. Story 5.4 - Save, Load, and Export Round-Trip Validation
11. Story 6.1 through Story 6.6 - Admin Operations and CV Troubleshooting

Before beginning Story 4.1, verify that the current implementation has a usable metric floor plan handoff from Story 3.5 and the reconstruction quality/failure/retry behavior from Story 3.6. If those are incomplete, stop and report the exact missing prerequisite instead of silently rebuilding earlier stories.



## Branch strategy

Default branch granularity is **one target story = one story branch**.

Before implementation, read `docs/agent/BRANCH_STRATEGY.md` together with `docs/agent/COMMIT_POLICY.md`.

Branch rules:

- Do not implement feature work directly on `main` or the repository primary branch unless the user explicitly asks.
- Start each story from the latest primary branch.
- Use a branch name like `story/4.1-shared-spatial-model`.
- Keep one story branch focused on one story.
- Do not combine agent instruction updates with product story work.
- If a prerequisite fix belongs to an earlier story, stop and propose a separate `fix/story-x.y-...` branch.
- Do not commit, push, or create a PR unless the user explicitly asks.
- If committing is requested, produce one completed story commit on the story branch.

Before coding a Goal, report branch readiness:

```text
Branch readiness:
- Primary branch:
- Current branch:
- Working tree clean:
- Target story:
- Planned story branch:
- Branch created:
- Expected commit message:
```

## Commit policy

Default commit granularity is **one completed story = one commit**.

Goals may be story-sized. If a Goal contains multiple stories, implement and validate one story at a time, then suggest or create one commit per story.

Before coding a Goal:

1. Read `docs/agent/BRANCH_STRATEGY.md` and `docs/agent/COMMIT_POLICY.md`.
2. Identify the exact target story.
3. Produce branch readiness and a story execution plan with scope, expected files, validation, branch name, and commit message.
4. Implement the story in internal checkpoints if needed, but keep the final commit at story granularity.

When committing is requested:

- Create one commit per completed story.
- Do not combine multiple stories, epics, or unrelated follow-up fixes in one commit.
- Do not split a story into many tiny commits unless the user explicitly asks for smaller commits or the story must be separated for safety.
- Formatting-only cleanup can be included in the story commit only when it is local to the story files.
- Use story-prefixed messages such as `feat(story-4.1): implement shared spatial model and view shell`.

Before suggesting or creating a commit, report:

```text
Story commit readiness:
- Story:
- Acceptance criteria status:
- Files changed:
- Validation run:
- Result:
- Known limitations:
- Suggested commit message:
```

## Required reading order

Before implementation, read only the documents needed for the current task.

Always start with:

1. `_bmad-output/planning-artifacts/implementation-readiness-report-2026-05-08.md`
2. `_bmad-output/planning-artifacts/epics.md`
3. `_bmad-output/planning-artifacts/architecture.md`

Read these when the story touches product behavior or UX:

4. `_bmad-output/planning-artifacts/prd.md`
5. `_bmad-output/planning-artifacts/ux-design-specification.md`

Read this only when visual layout interpretation is needed:

6. `_bmad-output/planning-artifacts/ux-design-directions.html`

Treat `implementation-readiness-report-2026-05-08.md` as the latest implementation-readiness source unless a newer readiness report exists.

## Non-negotiable RoomForge invariants

- Keep `app/`, `editor/`, `server/`, and optional `packages/` boundaries.
- Flutter owns app routing, auth state, project screens, upload UI, reconstruction workflow UI, inspectors, admin UI, accessible controls, and API calls.
- Three.js owns source-image alignment, OpenCV overlays, geometry handles, 2D/3D rendering, camera behavior, furniture manipulation, and spatial validation.
- FastAPI owns token verification, authorization, API routing, Oracle DB access, job/status records, layout persistence, admin lookup, and export responses.
- Do not run heavy OpenCV, deep-learning, or GPU inference on the lightweight API server.
- Run MVP OpenCV candidate extraction in the browser/editor layer, preferably via OpenCV.js in a Web Worker.
- Store candidate geometry separately from user-confirmed geometry in editor state, API, DB, and layout schemas.
- Use the persisted reconstruction statuses exactly: `created`, `uploading`, `processing`, `review_required`, `succeeded`, `failed`, `timeout`, `cancelled`, `retrying`.
- Persist `review_required`; display it to users as `Needs review`.
- Do not create a persisted `needs_review`, `done`, `complete`, or `error` job status.
- API responses must use the shared envelope: `data`, `error`, and `meta.request_id`.
- API JSON uses `snake_case`.
- Editor bridge fields use `camelCase`.
- Database tables and columns use `snake_case`.
- Geometry payloads must state coordinate space: image pixels before calibration, meters after calibration.
- Every user-facing API for project, layout, image, job, or result data must enforce authentication and ownership.
- Admin APIs require admin authorization distinct from normal authenticated user access.
- Non-canvas controls target WCAG 2.2 AA. Canvas/editor controls get best-effort accessibility with visible selection, non-color-only states, reset/preset controls, textual summaries where feasible, and recovery paths.

## How to work

Before coding:

1. Identify the target story or stories.
2. Read the story acceptance criteria from `epics.md`.
3. Read architecture rules that affect the touched boundary.
4. Summarize the target story, constraints, validation plan, and stop conditions.
5. If the requested work conflicts with the planning artifacts, stop and report the conflict.
6. If the current Goal starts at Story 4.1 or later, confirm the Story 3.5/3.6 handoff is sufficient for the work.

During coding:

- Keep changes limited to the target story.
- Do not add post-MVP features unless needed as a documented stub or extension point.
- Do not broaden product scope.
- Prefer the smallest reversible implementation decision.
- Document assumptions when the planning artifacts do not specify a detail.
- Add or update the smallest meaningful test/check for the story.

Before completion:

- Run the relevant app/editor/server checks when available.
- Verify acceptance criteria directly.
- Verify the RoomForge invariants above.
- Report any check that could not be run and why.

## Completion report format

Use the format in `docs/agent/COMPLETION_REPORT.md`.

## Agent playbooks

Use these files for repeatable workflows:

- `docs/agent/README.md`
- `docs/agent/CURRENT_PROGRESS.md`
- `docs/agent/TEAM.md`
- `docs/agent/GOAL_TEMPLATE.md`
- `docs/agent/GOALS.md`
- `docs/agent/VALIDATION.md`
- `docs/agent/COMMIT_POLICY.md`
- `docs/agent/SUBAGENTS.md`
- `docs/agent/COMPLETION_REPORT.md`
