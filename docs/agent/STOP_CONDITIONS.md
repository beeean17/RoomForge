# RoomForge Stop Conditions

Agents must stop and report before implementing if any condition below is true.

## Branch stop conditions

- The agent is about to implement product story work directly on `main`, `master`, or the repository primary branch without explicit user instruction.
- The working tree has uncommitted changes not created by the current Goal.
- The current branch name does not match the target story and the user did not explicitly request using it.
- The branch already contains changes for another story.
- Agent instruction changes are mixed with product story implementation changes.
- A prerequisite fix belongs to an earlier story and would make the current story branch ambiguous.

## Scope stop conditions

- The requested work requires changing MVP scope.
- The requested work jumps ahead of the current story sequence without a dependency reason.
- The requested work reimplements completed Stories 1.1 through 3.6 without evidence of a defect.
- The requested work combines too many stories into one Goal.
- The requested work introduces post-MVP features as production behavior rather than stubs/extension points.

## Architecture stop conditions

- The task requires running heavy OpenCV, deep-learning, or GPU inference on the lightweight API server.
- The task requires direct editor-to-Oracle API calls from rendering modules.
- The task blurs Flutter, Three.js, and FastAPI responsibilities.
- The task requires changing API envelope or naming conventions without updating the architecture docs.
- The task introduces a persisted status outside the allowed list.

## Data integrity stop conditions

- Candidate geometry and confirmed geometry would be merged.
- Geometry coordinate space cannot be determined.
- Metric floor plan output cannot be traced to input geometry and calibration.
- Layout save/load/export cannot preserve required fields.
- Auth/ownership checks cannot be enforced.
- Admin authorization cannot be separated from normal authentication.

## Current-stage stop conditions

Before Story 4.1:

- No metric floor plan handoff exists from the reconstruction flow.
- Story 3.6 warning/failure/retry behavior is missing and blocks planning-editor trust.
- Editor bridge or initialization cannot receive room/floor plan data.

Before Story 5.1:

- Shared spatial model is not stable enough to serialize layout state.
- Furniture object IDs or coordinates are unstable.

Before Story 6.1:

- Required job/status/artifact records do not exist.
- Admin authorization boundary is not present.

## Verification stop conditions

- No relevant check can be run and no substitute check is possible.
- A failing check indicates a regression in an earlier completed story.
- Acceptance criteria cannot be verified from implementation or tests.

## Required stop report

When stopping, report:

1. The exact stop condition triggered
2. Evidence from repository or documents
3. Smallest safe fix
4. Whether the current Goal should pause, shrink, or be replaced
5. Recommended next Goal


## Commit / push / PR stop conditions

Stop before committing if:

- The current branch is not the target story branch.
- The staged change contains more than one story.
- The staged change contains epic-wide or cross-story work that cannot be explained as part of the target story.
- The staged change includes unrelated fixes, experiments, or cleanup outside the target story.
- A required acceptance criterion for the target story is unverified and no reason is documented.
- No relevant validation was run and no substitute validation is documented.
- The suggested commit message would need words like "complete epic", "everything", "misc", or multiple story numbers.

It is acceptable for one story commit to touch app, editor, server, tests, and docs when those changes are all required by that story and are validated together.
