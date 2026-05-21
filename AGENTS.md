# RoomForge Agent Instructions

## Purpose

You are working on RoomForge, a web-first room reconstruction and furniture planning app.

Work story-by-story. Keep scope tight. Verify acceptance criteria. Commit at story granularity. When the user asks to run the story queue, do **not** keep stopping on recoverable operational issues. Repair the branch/worktree/validation state automatically, document what happened, and continue.

## Current baseline

The user has stated that implementation is currently complete through **Story 3.6**.

Treat Stories 1.1 through 3.6 as the current baseline unless repository evidence clearly contradicts that. Do not reimplement earlier stories unless the current Goal explicitly requires a bug fix, integration gap, or regression fix.

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

Before beginning Story 4.1, verify that the current implementation has a usable metric floor plan handoff from Story 3.5 and the reconstruction quality/failure/retry behavior from Story 3.6. If the handoff is partial but sufficient for a fixture/demo metric floor plan, proceed with Story 4.1 and document the limitation instead of stopping.

## Active execution mode

Use this rule for all remaining stories:

```text
1 Story = 1 Branch = 1 Goal = 1 Validation Loop = 1 Completion Report = 1 Story Commit
```

A PR/MR is still preferred for remote collaboration, but **push and PR/MR creation require explicit user permission**. Local branches and local story commits are allowed when the user asks to run the queue or continue the loop.

Read these operational playbooks before implementation:

- `docs/agent/STORY_QUEUE.md`
- `docs/agent/STORY_EXECUTION_LOOP.md`
- `docs/agent/AUTO_RUN.md`
- `docs/agent/RECOVERY_PLAYBOOK.md`
- `docs/agent/VALIDATION.md`
- `docs/agent/STOP_CONDITIONS.md`
- `docs/agent/BRANCH_STRATEGY.md`
- `docs/agent/COMMIT_POLICY.md`

## Non-blocking recovery rule

Do not stop merely because one of these recoverable issues appears:

- working tree is dirty;
- current branch is wrong;
- agent instruction files are mixed with story product files;
- a validation command is missing from the environment;
- a validation command fails because of current-story code;
- the previous story branch is locally committed but not merged;
- Flutter is unavailable in the current PATH;
- Vite reports a non-fatal chunk-size warning;
- `python` is missing but `.venv/bin/python`, `python3`, `uv run`, or another documented substitute exists.

Use `docs/agent/RECOVERY_PLAYBOOK.md` first. Stop only after the recovery playbook cannot safely resolve the issue, or when a hard stop from `docs/agent/STOP_CONDITIONS.md` remains after recovery attempts.

## Branch strategy

Default branch granularity is **one target story = one story branch**.

Branch rules:

- Do not implement feature work directly on `main`, `master`, `trunk`, or the repository primary branch.
- Start each story from the latest local primary branch.
- Use a branch name from `docs/agent/STORY_QUEUE.md`, such as `story/4.1-shared-spatial-model`.
- Keep one story branch focused on one story.
- Agent instruction updates belong on `chore/agent-instructions` or another ops/chore branch.
- If agent instruction updates are found mixed with product story work, split them automatically using `docs/agent/RECOVERY_PLAYBOOK.md`.
- If a prerequisite fix belongs to an earlier story and is small enough to unblock the queue, create a focused `fix/story-x.y-...` branch, validate it, locally merge it, and resume. If it is not small or safe, hard stop and report.
- Push and PR creation require explicit user permission.

## Commit policy

Default commit granularity is **one completed story = one commit**.

When the user asks to run the queue, continue the loop, or proceed autonomously, local story commits are permitted after validation passes. Push and PR/MR creation are not permitted unless the user explicitly grants them.

When committing:

- Create exactly one commit per completed story.
- Do not combine multiple stories, epics, or unrelated follow-up fixes in one story commit.
- Do not split a story into many tiny commits unless the user explicitly asks.
- Formatting-only cleanup can be included in the story commit only when it is local to story files.
- Use story-prefixed messages from `docs/agent/STORY_QUEUE.md`.

## Required reading order for product work

Before implementation, read only the documents needed for the current story.

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

1. Determine the next story from `docs/agent/STORY_QUEUE.md`.
2. Run branch/worktree readiness.
3. If readiness fails, repair using `docs/agent/RECOVERY_PLAYBOOK.md`.
4. Read target story acceptance criteria from `epics.md`.
5. Read architecture rules affecting the touched boundary.
6. Produce a short story preflight: scope, expected files, validation, invariants, and commit message.

During coding:

- Keep changes limited to the target story.
- Do not add post-MVP features unless needed as a documented stub or extension point.
- Do not broaden product scope.
- Prefer the smallest reversible implementation decision.
- Document assumptions when planning artifacts do not specify a detail.
- Add or update the smallest meaningful test/check for the story.

Validation loop:

1. Run relevant checks.
2. If a check fails because of current-story code, fix and rerun.
3. Repeat up to three validation/fix cycles.
4. Missing local tools are environment limitations, not automatic blockers; use substitutes and document them.
5. Stop only if acceptance criteria cannot be verified after reasonable recovery attempts.

Completion:

- Produce the report from `docs/agent/COMPLETION_REPORT.md`.
- Commit one validated story locally when queue/autonomous mode is active.
- Fast-forward merge the completed story into the local primary branch when local continuation mode is active.
- Create the next story branch and continue unless the user has asked to stop.
- Do not push or create a PR unless explicitly approved.

## Agent playbooks

Use these files for repeatable workflows:

- `docs/agent/README.md`
- `docs/agent/CURRENT_PROGRESS.md`
- `docs/agent/STORY_QUEUE.md`
- `docs/agent/STORY_EXECUTION_LOOP.md`
- `docs/agent/AUTO_RUN.md`
- `docs/agent/RECOVERY_PLAYBOOK.md`
- `docs/agent/TEAM.md`
- `docs/agent/GOAL_TEMPLATE.md`
- `docs/agent/GOALS.md`
- `docs/agent/VALIDATION.md`
- `docs/agent/STOP_CONDITIONS.md`
- `docs/agent/BRANCH_STRATEGY.md`
- `docs/agent/COMMIT_POLICY.md`
- `docs/agent/SUBAGENTS.md`
- `docs/agent/COMPLETION_REPORT.md`
