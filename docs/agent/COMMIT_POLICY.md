# RoomForge Commit Policy

Read this together with `docs/agent/STORY_QUEUE.md`, `docs/agent/STORY_EXECUTION_LOOP.md`, and `docs/agent/AUTO_RUN.md`.

## Default rule

```text
1 completed story = 1 local commit
```

A story commit should contain everything needed to satisfy and validate that story's acceptance criteria. It may touch app, editor, server, tests, docs, and shared packages when those changes are required by the same story.

Do not combine multiple stories, an entire epic, or unrelated cleanup into one story commit.

## Permission model

When the user asks to run the queue, continue the loop, or proceed automatically:

- local story commits are allowed;
- local fast-forward merges into the local primary branch are allowed;
- push and PR/MR creation are not allowed unless explicitly approved.

When the user asks for preflight-only or review-only, do not commit.

## Relationship between Goals, stories, and commits

```text
Goal       = usually one story
Story      = acceptance-criteria unit from epics.md
Commit     = one completed and validated story
Epic       = multiple stories; never one commit by default
```

If a Goal includes multiple stories, implement them sequentially and create one local commit per completed story.

## Commit message format

Use:

```text
<type>(story-<n.n>): <story outcome>
```

Use the exact message from `docs/agent/STORY_QUEUE.md` when available.

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

## What belongs in one story commit

Acceptable:

- app/editor/server changes required by the same story;
- tests or fixtures proving the story;
- local docs explaining story decisions;
- small formatting changes in files already touched for the story.

Not acceptable:

- two or more story implementations;
- epic-wide cleanup;
- unrelated bug fixes;
- broad formatting across untouched files;
- new dependencies not needed for the target story;
- agent instruction updates mixed with product story work.

## Commit readiness

Before committing, verify:

```text
Story commit readiness:
- Story:
- Branch:
- Acceptance criteria status:
- Files changed:
- Files staged:
- Validation run:
- Fix/retry cycles:
- Environment limitations:
- Known limitations:
- Suggested commit message:
```

If unrelated changes appear, use `docs/agent/RECOVERY_PLAYBOOK.md` to split or stash them instead of stopping immediately.

## When not to commit

Do not commit when:

- acceptance criteria cannot be verified after validation recovery;
- no relevant validation or substitute evidence exists;
- staged diff includes multiple stories and cannot be split;
- staged diff includes unrelated work and cannot be separated;
- the repository is in a broken state caused by unresolved hard-stop conditions.

## After commit in local continuation mode

Fast-forward merge to local primary and continue:

```bash
git switch <primary-branch>
git merge --ff-only <completed-story-branch>
git switch -c <next-story-branch>
```

Do not push or create PR/MR unless the user explicitly approves.
