# RoomForge Validation Rules

Validation should be automatic and iterative. Do not stop after the first failure unless it is a hard stop. Fix, rerun, and continue.

## Validation loop

For every story:

1. Identify affected workspaces: app, editor, server, packages, docs.
2. Run relevant checks.
3. If a check fails because of current-story code, fix it.
4. Re-run the failed check.
5. Re-run the affected validation set.
6. Repeat up to three validation/fix cycles.
7. Document unavailable commands and substitutes.
8. Continue when acceptance criteria are verified and no hard stop remains.

## Global validation

For every task, verify:

- Target story acceptance criteria.
- Correct story branch is used or recovered.
- App/editor/server boundary.
- No heavy CV/GPU/deep-learning process on API server.
- Candidate geometry and confirmed geometry remain separate.
- Allowed persisted status vocabulary only.
- `review_required` persists and displays as `Needs review`.
- API response envelope: `data`, `error`, `meta.request_id`.
- API `snake_case`, editor bridge `camelCase`, DB `snake_case`.
- Geometry coordinate space is explicit.
- Auth and ownership checks are enforced where user data is returned.
- Admin auth is distinct from normal auth where admin data/actions are exposed.
- Non-canvas accessibility and responsive requirements are not deferred silently.

## Branch validation

For every implementation story:

```bash
git branch --show-current
git status --short
git diff --stat
```

If branch validation fails, use `docs/agent/RECOVERY_PLAYBOOK.md`. Do not stop until recovery has been attempted.

Expected branch behavior:

- Current branch is the target story branch.
- Product story work is not implemented directly on the primary branch.
- Story branch contains only the target story plus required tests/docs for that story.
- Agent instruction updates are split into a chore branch.
- Before commit, staged files map to exactly one story.

## Workspace checks

Use the repository's documented commands once they exist. Run only commands that exist or are appropriate for the touched workspace.

### App

Preferred:

```bash
cd app && flutter analyze
cd app && flutter test
```

Fallbacks:

```bash
cd app && dart --version
cd app && dart format --set-exit-if-changed lib test
```

If Flutter/Dart are not installed, document the environment limitation. This is not a hard stop if the story can be verified by other evidence, but the completion report must say that app validation is incomplete due to missing local tooling.

### Editor

Inspect scripts:

```bash
cd editor && cat package.json
```

Run available scripts:

```bash
cd editor && npm run typecheck
cd editor && npm run build
cd editor && npm test
```

A Vite chunk-size warning is non-blocking unless the command exits non-zero or the target story explicitly requires bundle-size work.

### Server

Try primary and fallback Python commands:

```bash
cd server && python -m pytest
cd server && python3 -m pytest
cd server && .venv/bin/python -m pytest
cd server && uv run pytest
cd server && poetry run pytest
```

Compile/import checks:

```bash
cd server && python -m compileall app
cd server && python3 -m compileall app
cd server && .venv/bin/python -m compileall app
```

Use the first working command. Document substitutes.

## Current-stage validation

Because the project is assumed complete through Story 3.6, the main validation focus is Epic 4 through Epic 6.

### Pre-Epic 4 handoff

- Valid metric floor plan is available from reconstruction flow or fixture/demo handoff.
- Metric floor plan uses meters after calibration.
- Image-pixel input geometry remains traceable.
- Failure/needs-review/retry behavior exists from Story 3.6.
- Editor bridge or initialization path can receive floor plan or scene data.

### Epic 4 - Editor

- 2D and 3D derive from one shared spatial model.
- 2D/3D switching preserves selection, object identity, metric coordinates, scale, and unsaved state.
- Camera controls include orbit, pan, zoom, reset, fit-to-room, Top, Front, Corner, Eye-level.
- Reduced motion preference is respected where applicable.
- Furniture model includes ID, category, size, position, rotation, and color.
- Move/rotate/resize/delete update both 2D and 3D views from shared state.
- Layout editing target: local editor update within 100 ms where measurable.
- 3D target: at least 30 FPS for rectangular room with up to 20 proxy furniture objects where measurable.
- Selection and warnings do not rely on color alone.
- Responsive layouts remain usable at desktop, tablet, and mobile-review widths.
- Non-canvas controls target WCAG 2.2 AA.

### Epic 5 - Persistence and export

- Save requires authentication and ownership.
- Load requires authentication and ownership.
- Export requires authentication and ownership.
- Saved layout preserves room dimensions, floor plan data, source metadata references, and furniture objects.
- Furniture objects preserve ID, category, position, size, rotation, and color.
- Save success/failure copy uses `Saved` / `Save failed`.
- Export failure copy uses `Export failed`.
- Export review-required warning appears before export when reconstruction status is `review_required`.
- Save/load/export round trip preserves required fields exactly except server-managed metadata.
- Non-CV API p95 target is checked where measurable.

### Epic 6 - Admin operations

- Admin APIs require admin authorization distinct from normal authentication.
- Normal users receive `unauthorized` for admin APIs.
- Job list filters use allowed persisted statuses exactly.
- Job detail shows current status, timestamps, provider/algorithm identifier, retry count, and failure reason where available.
- Event trail shows status, timestamp, actor/source, reason code, human-readable reason, and retry linkage where available.
- Artifact viewer separates candidate and confirmed geometry visually and structurally.
- Retry creates a new linked retry attempt and preserves previous failure history.
- Admin search returns scoped records without exposing unauthorized data.
- Failure-source diagnosis distinguishes input quality, OpenCV candidate detection, user calibration, API handling, database state, and optional provider processing.

## Performance targets

Use these when the story touches performance:

- Non-CV API p95 target: 1 second for project list, project detail, layout save, layout load.
- Local editor update target: 100 ms for MVP-scale scenes.
- 3D target: 30 FPS on a recent laptop browser for a rectangular room with up to 20 furniture proxy objects.
- Job status retrieval: at least every 5 seconds while relevant.
- Long-running reconstruction must not rely on a blocking HTTP request longer than 30 seconds.

## Story commit readiness validation

Before each story commit, verify:

- The commit maps to exactly one completed story.
- All acceptance criteria for that story are pass or documented partial with evidence.
- Relevant checks were run, substituted, or explicitly unavailable due to environment.
- The commit does not include unrelated work from another story or epic.
- Formatting-only changes are local to the story files.
- The commit message follows `docs/agent/STORY_QUEUE.md`.

## Completion evidence

Use this report shape:

```text
Validation summary:
- Story:
- Acceptance criteria:
- Commands run:
- Failed commands:
- Fix/retry cycles:
- Substitute checks:
- Environment limitations:
- Manual checks:
- Final result:
```
