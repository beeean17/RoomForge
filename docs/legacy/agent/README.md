# RoomForge Agent Playbooks

This folder contains repeatable instructions for Codex agents working in the RoomForge repository.

## File map

- `CURRENT_PROGRESS.md` - current implementation baseline and next-story order.
- `STORY_QUEUE.md` - canonical story order, branch names, and story-level commit messages.
- `STORY_EXECUTION_LOOP.md` - repeatable branch/goal/validation/commit loop for every story.
- `AUTO_RUN.md` - auto-run mode for continuing through all remaining stories without repeated stops.
- `RECOVERY_PLAYBOOK.md` - automatic recovery for dirty worktree, mixed agent docs/product changes, validation failures, and branch mismatch.
- `TEAM.md` - review/teammate role for scope, sequencing, risk, and validation.
- `GOAL_TEMPLATE.md` - template for every `/goal`.
- `GOALS.md` - concrete Goals starting from the current baseline after Story 3.6.
- `VALIDATION.md` - global and story-specific validation checks with fallbacks.
- `STOP_CONDITIONS.md` - hard stops only after recovery attempts.
- `BRANCH_STRATEGY.md` - branch naming, branch lifecycle, local continuation, push/PR rules.
- `COMMIT_POLICY.md` - story-level local commit rules.
- `SUBAGENTS.md` - suggested architecture/UX/validation/story-loop subagent prompts.
- `COMPLETION_REPORT.md` - required report format after each Goal.

## Core loop

Use this rule for all remaining stories:

```text
1 Story = 1 Branch = 1 Goal = 1 Validation Loop = 1 Completion Report = 1 Story Commit
```

Active queue:

```text
4.1 -> 4.2 -> 4.3 -> 4.4 -> 4.5 -> 4.6 ->
5.1 -> 5.2 -> 5.3 -> 5.4 ->
6.1 -> 6.2 -> 6.3 -> 6.4 -> 6.5 -> 6.6
```

Before Story 4.1, run the Story 3.5/3.6 handoff gate from `GOALS.md`.

## Auto-run mode

Use auto-run mode when the user says the loop should continue across all stories or should not repeatedly stop for recoverable problems.

```text
Read AGENTS.md, MANIFEST.md, docs/agent/CURRENT_PROGRESS.md, docs/agent/STORY_QUEUE.md, docs/agent/STORY_EXECUTION_LOOP.md, docs/agent/AUTO_RUN.md, docs/agent/RECOVERY_PLAYBOOK.md, docs/agent/GOALS.md, docs/agent/BRANCH_STRATEGY.md, docs/agent/COMMIT_POLICY.md, docs/agent/VALIDATION.md, and docs/agent/STOP_CONDITIONS.md.

Run the remaining story queue from Story 4.1 through Story 6.6.

Use automatic recovery for:
- dirty worktree
- mixed agent docs and product files
- wrong branch
- missing validation commands
- validation failures caused by current-story code

Create one local story commit per validated story.
Fast-forward merge each completed story locally into the primary branch, then continue to the next story.
Do not push or create PRs unless I explicitly approve.
```

## Review-only mode

Use this when the user wants planning but not edits:

```text
Run story preflight only for the next story. Do not modify files, commit, merge, push, or create PRs.
```

## Current baseline assumption

The user stated that RoomForge is currently done through **Story 3.6**. These files are intentionally biased toward the next work: Epic 4 planning editor, Epic 5 persistence/export, and Epic 6 admin operations.

If the repository contradicts the Story 3.6 baseline, try the recovery playbook and focused fix-branch path before stopping.

## Commit granularity

The default granularity is **one completed story = one local commit**. Push and PR creation require explicit user approval.
