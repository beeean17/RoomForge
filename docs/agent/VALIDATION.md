# RoomForge Validation Rules

## Global validation

For every task, verify:

- Target story acceptance criteria
- Correct story branch is used for implementation work
- Working tree was clean before starting or pre-existing changes were reported
- App/editor/server boundary
- No heavy CV/GPU/deep-learning process on API server
- Candidate geometry and confirmed geometry remain separate
- Allowed persisted status vocabulary only
- `review_required` persists and displays as `Needs review`
- API response envelope: `data`, `error`, `meta.request_id`
- API `snake_case`, editor bridge `camelCase`, DB `snake_case`
- Geometry coordinate space is explicit
- Auth and ownership checks are enforced where user data is returned
- Admin auth is distinct from normal auth where admin data/actions are exposed
- Non-canvas accessibility and responsive requirements are not deferred silently


## Branch validation

For every implementation story, verify:

```bash
git branch --show-current
git status --short
git diff --stat
```

Expected branch behavior:

- Current branch is the target story branch, such as `story/4.1-shared-spatial-model`.
- Product story work is not implemented directly on `main`, `master`, or the repository primary branch unless the user explicitly asked.
- Story branch contains only the target story plus required tests/docs for that story.
- Agent instruction updates are not mixed with product story branches.
- Before commit, staged files map to exactly one story.
- Before push or PR, acceptance criteria and relevant checks are complete or documented as partial with reason.

## Workspace checks

Use the repository's documented commands once they exist.

Expected categories:

```bash
# app
cd app
flutter analyze
flutter test

# editor
cd editor
npm run typecheck
npm run build
npm test

# server
cd server
python -m pytest
python -m compileall app
```

If a command does not exist yet, create the smallest useful placeholder or document why it is deferred.

## Current-stage validation

Because the project is assumed complete through Story 3.6, the main validation focus is now Epic 4 through Epic 6.

### Pre-Epic 4 handoff

- Valid metric floor plan is available from reconstruction flow
- Metric floor plan uses meters after calibration
- Image-pixel input geometry remains traceable
- Failure/needs-review/retry behavior exists from Story 3.6
- Editor bridge or initialization path can receive floor plan or scene data

### Epic 4 - Editor

- 2D and 3D derive from one shared spatial model
- 2D/3D switching preserves selection, object identity, metric coordinates, scale, and unsaved state
- Camera controls include orbit, pan, zoom, reset, fit-to-room, Top, Front, Corner, Eye-level
- Reduced motion preference is respected where applicable
- Furniture model includes ID, category, size, position, rotation, and color
- Move/rotate/resize/delete update both 2D and 3D views from shared state
- Layout editing target: local editor update within 100 ms where measurable
- 3D target: at least 30 FPS for rectangular room with up to 20 proxy furniture objects where measurable
- Selection and warnings do not rely on color alone
- Responsive layouts remain usable at desktop, tablet, and mobile-review widths
- Non-canvas controls target WCAG 2.2 AA

### Epic 5 - Persistence and export

- Save requires authentication and ownership
- Load requires authentication and ownership
- Export requires authentication and ownership
- Saved layout preserves room dimensions, floor plan data, source metadata references, and furniture objects
- Furniture objects preserve ID, category, position, size, rotation, and color
- Save success/failure copy uses `Saved` / `Save failed`
- Export failure copy uses `Export failed`
- Export review-required warning appears before export when reconstruction status is `review_required`
- Save/load/export round trip preserves required fields exactly except server-managed metadata
- Non-CV API p95 target is checked where measurable

### Epic 6 - Admin operations

- Admin APIs require admin authorization distinct from normal authentication
- Normal users receive `unauthorized` for admin APIs
- Job list filters use allowed persisted statuses exactly
- Job detail shows current status, timestamps, provider/algorithm identifier, retry count, and failure reason where available
- Event trail shows status, timestamp, actor/source, reason code, human-readable reason, and retry linkage where available
- Artifact viewer separates candidate and confirmed geometry visually and structurally
- Retry creates a new linked retry attempt and preserves previous failure history
- Admin search returns scoped records without exposing unauthorized data
- Failure-source diagnosis distinguishes input quality, OpenCV candidate detection, user calibration, API handling, database state, and optional provider processing

## Performance targets

Use these when the story touches performance:

- Non-CV API p95 target: 1 second for project list, project detail, layout save, layout load
- Local editor update target: 100 ms for MVP-scale scenes
- 3D target: 30 FPS on a recent laptop browser for a rectangular room with up to 20 furniture proxy objects
- Job status retrieval: at least every 5 seconds while relevant
- Long-running reconstruction must not rely on a blocking HTTP request longer than 30 seconds


## Story commit readiness validation

Before each suggested or actual commit, verify:

- The commit maps to exactly one completed story.
- All acceptance criteria for that story are pass/partial/fail with evidence.
- Relevant app/editor/server checks were run, or an explicit reason is documented.
- The commit does not include unrelated work from another story or epic.
- Formatting-only changes are local to the story files, or are separated when broad.
- The commit message follows the story-prefixed format from `COMMIT_POLICY.md`.

Use this report shape:

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
