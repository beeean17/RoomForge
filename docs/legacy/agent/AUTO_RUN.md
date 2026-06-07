# RoomForge Auto Run Mode

Use this when the user asks to continue the loop, run all remaining stories, or avoid repeated stopping.

## Core rule

```text
1 Story = 1 Branch = 1 Goal = 1 Validation Loop = 1 Completion Report = 1 Story Commit
```

Remote PR/MR remains a collaboration artifact, but auto-run mode uses local fast-forward merges so the next story can start without waiting for manual PR handling.

## Permissions in auto-run mode

Allowed without asking again:

- inspect repository status;
- stash and restore changes for recovery;
- create local branches;
- create or update `chore/agent-instructions` for agent files;
- create focused local fix branches when a small prerequisite fix is required;
- run validation commands and substitute commands;
- fix validation failures caused by the current story;
- create one local commit per completed story;
- fast-forward merge a completed local story branch into the local primary branch;
- create the next story branch from the updated local primary branch;
- continue through the active queue.

Not allowed without explicit user approval:

- push to remote;
- create PR/MR;
- force-push;
- reset or clean user changes without first stashing or otherwise preserving them;
- delete remote branches;
- change product scope or planning artifacts to hide acceptance-criteria failure.

## Auto-run startup checklist

1. Read `AGENTS.md`, `MANIFEST.md`, and all files listed in `docs/agent/README.md`.
2. Detect the primary branch:
   - prefer the remote HEAD branch when available;
   - otherwise use `main`, `master`, or `trunk` in that order.
3. Determine the next story from `docs/agent/STORY_QUEUE.md`.
4. Run the Story 3.5/3.6 handoff gate before Story 4.1.
5. Run branch/worktree recovery before treating anything as blocked.

## Auto-run story loop

For every story:

1. Create or repair the story branch.
2. Produce story preflight.
3. Execute exactly one story Goal.
4. Run validation.
5. If validation fails, fix and retry up to three cycles.
6. Produce completion report.
7. Create one story commit.
8. Fast-forward merge the story commit into the local primary branch.
9. Create the next story branch.
10. Continue until the queue is complete or a hard stop remains after recovery attempts.

## Auto-run prompt

```text
Run the RoomForge story queue in auto-run mode.

Use the current baseline through Story 3.6. Start at Story 4.1.

Rules:
- Use docs/agent/STORY_QUEUE.md for the order, branch names, and commit messages.
- Use docs/agent/STORY_EXECUTION_LOOP.md for the loop.
- Use docs/agent/RECOVERY_PLAYBOOK.md before stopping on branch, worktree, mixed-file, or validation issues.
- Use docs/agent/VALIDATION.md to run checks, fix failures, and re-run checks.
- Create one local story commit per validated story.
- Fast-forward merge each completed story locally into the primary branch, then continue to the next story.
- Do not push or create PRs unless I explicitly approve.

If a hard stop remains after recovery attempts, report the exact condition, recovery attempted, and the smallest next action.
```

## What counts as success

A story is complete when:

- all target acceptance criteria are pass or documented partial with a valid reason;
- required invariants are verified;
- relevant validation commands passed or unavailable commands have documented substitutes;
- current-story validation failures were fixed and re-run;
- completion report is produced;
- one story commit exists on the story branch;
- local primary branch can fast-forward to that commit.

## What does not block continuation

These must be reported but should not stop the auto-run loop:

- Flutter SDK missing in the agent environment, if Flutter checks cannot be run;
- `python` command missing when `.venv/bin/python`, `python3`, `uv run`, or another substitute is available;
- Vite chunk-size warnings that do not fail build/test;
- pre-existing agent docs mixed with story changes, after automatic splitting;
- fixture/demo handoff in Story 4.1 when persisted floor-plan handoff is incomplete but not required by the Story 4.1 minimum acceptance criteria;
- manual checks required for responsive visual behavior, if they are documented and supported by code/test evidence where feasible.
