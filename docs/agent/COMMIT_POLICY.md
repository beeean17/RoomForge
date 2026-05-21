# RoomForge Commit Policy

## Default rule

The default commit granularity is:

```text
1 completed story = 1 commit
```

A story commit should contain everything needed to satisfy and validate that story's acceptance criteria. It may touch app, editor, server, tests, docs, and shared packages when those changes are required by the same story.

Do not combine multiple stories, an entire epic, or unrelated cleanup into one commit.

Do not split one story into many tiny commits by default. Split only when the user explicitly asks for smaller commits, when the story is too risky to review as one change, or when a separate prerequisite/fix must land before the story.

## Relationship to branches

Read `docs/agent/BRANCH_STRATEGY.md` before committing.

The default relationship is:

```text
one target story = one story branch = one final story commit = one PR/MR
```

Before committing, confirm:

- the current branch is the target story branch
- the current branch is not `main`, `master`, or the repository primary branch
- staged files belong to the target story
- no unrelated user changes are included
- validation has run or a substitute check is documented

## Relationship between Goals, stories, and commits

```text
Goal       = usually one story
Story      = acceptance-criteria unit from epics.md
Commit     = one completed and validated story
Epic       = multiple stories; never one commit by default
```

If a Goal includes multiple stories, implement them sequentially and prepare one commit per story.

## Before coding

Before implementation, confirm branch readiness and produce a story execution plan:

```text
Story execution plan:
- Target story branch:
- Target story:
- Acceptance criteria:
- Expected files/areas:
- Validation checks:
- Stop conditions:
- Suggested commit message:
```

## During coding

- Keep changes scoped to the target story.
- Internal checkpoints are allowed, but the final suggested commit remains story-sized.
- Do not start the next story until the current story is validated or explicitly paused.
- Do not hide unrelated refactors, dependency changes, or cleanup inside the story commit.
- If a prerequisite gap is found, stop and report whether it should be a separate prerequisite commit or handled inside the story.

## Commit message format

Use:

```text
<type>(story-<n.n>): <story outcome>
```

Recommended types:

- `feat` for user-facing or platform capability
- `fix` for a defect or regression
- `test` for validation-only stories or test-only corrections
- `docs` for documentation-only updates
- `chore` for setup, tooling, CI, or scaffold stories
- `refactor` only when behavior is intentionally unchanged

Examples:

```text
feat(story-4.1): implement shared spatial model and 2d 3d view shell
feat(story-4.2): add 3d camera inspection controls
feat(story-4.3): add and select furniture proxy objects
feat(story-4.4): edit furniture movement rotation resize and deletion
feat(story-4.5): add measurement labels and placement warnings
feat(story-4.6): harden responsive accessible editor controls
feat(story-5.1): save layout with room and furniture state
feat(story-5.2): load saved layout into editor state
feat(story-5.3): export layout as json
test(story-5.4): validate save load export round trip
feat(story-6.1): add admin job list and status filters
feat(story-6.2): add admin job detail and event trail
feat(story-6.3): add admin opencv artifact viewer
feat(story-6.4): add admin retry for failed jobs
feat(story-6.5): add admin search across operational records
feat(story-6.6): add provider state and failure diagnosis
```

Avoid vague messages:

```text
update editor
finish epic 4
misc fixes
everything for admin
```

## Story commit readiness

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

The acceptance criteria status should use:

```text
AC 1: pass/partial/fail + evidence
AC 2: pass/partial/fail + evidence
AC 3: pass/partial/fail + evidence
```

## What belongs in one story commit

Acceptable in one story commit:

- App/editor/server changes that are all required by the same story.
- Tests or fixtures proving that story.
- Local docs that explain decisions made for that story.
- Small local formatting changes in files already touched for that story.

Not acceptable in one story commit:

- Two or more story implementations.
- Epic-wide cleanup mixed with a story.
- Unrelated bug fixes.
- Broad formatting changes across untouched files.
- New dependencies that are not needed for the target story.
- Experimental work for a later story.

## When not to commit

Do not commit when:

- Acceptance criteria are not verified and no partial/deferred reason is documented.
- Validation was not run and no substitute check is documented.
- The staged diff includes multiple stories.
- The staged diff includes unrelated cleanup or exploratory code.
- The repository is in a broken state unrelated to the target story and the breakage is not documented.

## If the story is too large

If a story becomes too large to review safely, stop and propose one of these options:

1. Keep one story commit, but reduce the implementation to the minimum acceptance criteria.
2. Create a separate prerequisite commit for an infrastructure gap.
3. Ask the user whether to intentionally split the story into smaller commits.

By default, do **not** split without user approval.


## Direct commit safety

If the user asks the agent to commit:

1. Show `git branch --show-current`.
2. Show `git status --short`.
3. Confirm the branch matches the target story.
4. Stage only target-story files.
5. Show staged files.
6. Create exactly one story commit unless the user explicitly requests a different shape.
7. Push only if the user asked to push.
8. Create a PR only if the user asked to create a PR.

If any unrelated change appears, stop and report it.
