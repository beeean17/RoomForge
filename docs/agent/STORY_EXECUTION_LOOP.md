# RoomForge Story Execution Loop

Use this loop for every remaining RoomForge story.

The loop is designed for the current state where Stories 1.1 through 3.6 are treated as completed baseline and active implementation starts at Story 4.1.

## Core rule

```text
1 Story = 1 Branch = 1 Goal = 1 Validation Loop = 1 Completion Report = 1 Story Commit
```

Push and PR/MR creation require explicit user permission. Local branch creation, recovery, validation, story commits, and local fast-forward merges are allowed when the user asks to run or continue the queue.

## Files to read before using the loop

Always read these files before implementing a story:

1. `AGENTS.md`
2. `MANIFEST.md`
3. `docs/agent/CURRENT_PROGRESS.md`
4. `docs/agent/STORY_QUEUE.md`
5. `docs/agent/STORY_EXECUTION_LOOP.md`
6. `docs/agent/AUTO_RUN.md` when running multiple stories or continuing automatically
7. `docs/agent/RECOVERY_PLAYBOOK.md`
8. `docs/agent/GOALS.md`
9. `docs/agent/BRANCH_STRATEGY.md`
10. `docs/agent/COMMIT_POLICY.md`
11. `docs/agent/VALIDATION.md`
12. `docs/agent/STOP_CONDITIONS.md`

Then read the planning artifacts required by the target story.

## Active queue

```text
4.1 -> 4.2 -> 4.3 -> 4.4 -> 4.5 -> 4.6 ->
5.1 -> 5.2 -> 5.3 -> 5.4 ->
6.1 -> 6.2 -> 6.3 -> 6.4 -> 6.5 -> 6.6
```

Before Story 4.1, run the pre-goal handoff gate in `docs/agent/GOALS.md`.

## Step 0 - Determine the next story

Use `docs/agent/STORY_QUEUE.md`.

If repository evidence contradicts the Story 3.6 baseline, first decide whether the gap is:

- small and required for the current queue, in which case create a focused fix branch;
- a non-blocking limitation, in which case document it and proceed;
- a hard prerequisite, in which case stop after recovery attempts.

## Step 1 - Check and repair Git readiness

Run:

```bash
git branch --show-current
git status --short
git diff --stat
```

If the result is not ready, use `docs/agent/RECOVERY_PLAYBOOK.md` before stopping.

Report:

```text
Story loop readiness:
- Primary branch:
- Current branch:
- Working tree status:
- Recovery needed:
- Recovery action taken:
- Target story:
- Expected story branch:
- Expected story commit message:
```

Do not treat a dirty worktree, wrong branch, or mixed agent docs as an immediate stop. Repair and continue.

## Step 2 - Create or switch to the story branch

Use the branch name from `docs/agent/STORY_QUEUE.md`.

```bash
git fetch origin || true
git switch <primary-branch>
git pull --ff-only || true
git switch -c <target-story-branch> || git switch <target-story-branch>
```

If the branch already exists, verify it maps to the target story. If it contains unrelated work, use the recovery playbook to stash, split, or recreate the branch.

## Step 3 - Run story preflight

Before coding, produce:

```text
Story preflight:
- Target story:
- Acceptance criteria from epics.md:
- Requirements covered:
- Boundaries touched: app/editor/server/packages/docs
- Required planning files:
- Expected files or areas likely to change:
- Validation commands and fallbacks:
- RoomForge invariants to verify:
- Hard stop conditions:
- Suggested story commit message:
```

Then code. Do not wait for a separate approval unless the user explicitly requested preflight-only behavior.

## Step 4 - Execute exactly one story Goal

Use the matching Goal from `docs/agent/GOALS.md`.

Rules:

- Keep implementation scoped to the target story.
- Do not implement the next story early.
- Do not merge candidate geometry and confirmed geometry.
- Do not introduce persisted status names outside the allowed list.
- Do not run heavy OpenCV, deep-learning, or GPU inference on the API server.
- Do not bypass authentication, ownership, or admin authorization requirements.
- Document assumptions when planning artifacts do not specify a detail.

## Step 5 - Validate, fix, and revalidate

Use `docs/agent/VALIDATION.md`.

Run affected checks where available. If a command is missing, use fallbacks. If a check fails due to current-story code, fix and rerun. Repeat up to three validation/fix cycles.

Do not stop just because Flutter is not installed, `python` is missing, or a Vite warning appears. Use substitutes or document environment limitations.

## Step 6 - Produce completion report

Use `docs/agent/COMPLETION_REPORT.md`.

The report must include:

- target story and implemented outcome;
- acceptance criteria pass/partial/fail evidence;
- checks run and results;
- fix/retry cycles;
- environment limitations;
- recovery actions used;
- RoomForge invariants verified;
- changed files;
- assumptions and decisions;
- risks and follow-ups;
- branch and commit readiness;
- next story from `docs/agent/STORY_QUEUE.md`.

## Step 7 - Commit one completed story locally

When queue/autonomous mode is active, create one local story commit after validation passes.

```bash
git branch --show-current
git status --short
git diff --stat
git add <target-story-files-only>
git diff --cached --name-only
git commit -m "<message from STORY_QUEUE.md>"
```

If unrelated files are present, use the recovery playbook to separate them. Do not stop until separation fails.

## Step 8 - Local continuation merge

To continue to the next story without waiting for remote PR flow, fast-forward merge the story commit into the local primary branch:

```bash
git switch <primary-branch>
git merge --ff-only <target-story-branch>
```

If fast-forward fails, use Recovery D from `RECOVERY_PLAYBOOK.md`. Stop only if conflicts require product decisions.

## Step 9 - Advance to the next story

After local merge:

```bash
git switch -c <next-story-branch>
```

Then repeat from Step 3 for the next story.

Do not start the next story from the previous story branch.

## Push and PR/MR

Do not push or create a PR/MR unless the user explicitly asks.

When push is approved:

```bash
git push -u origin <story-branch>
```

When PR creation is approved and tooling exists:

```bash
gh pr create --base <primary-branch> --head <story-branch> --title "<story commit message>" --body-file docs/agent/last-completion-report.md
```

If tooling is unavailable, report branch, commit hash, title, and body.

## Master prompt for the whole remaining queue

```text
Run the RoomForge story queue in auto-run mode.

Read AGENTS.md, MANIFEST.md, docs/agent/CURRENT_PROGRESS.md, docs/agent/STORY_QUEUE.md, docs/agent/STORY_EXECUTION_LOOP.md, docs/agent/AUTO_RUN.md, docs/agent/RECOVERY_PLAYBOOK.md, docs/agent/GOALS.md, docs/agent/BRANCH_STRATEGY.md, docs/agent/COMMIT_POLICY.md, docs/agent/VALIDATION.md, and docs/agent/STOP_CONDITIONS.md.

Use the current baseline through Story 3.6. Do not restart from Story 1.1 unless repository evidence shows a missing or regressed prerequisite.

Proceed through the active queue from Story 4.1 through Story 6.6.

For each story:
1. Repair branch/worktree issues instead of stopping.
2. Produce story preflight.
3. Execute exactly one story Goal.
4. Validate, fix, and revalidate.
5. Produce completion report.
6. Create one local story commit.
7. Fast-forward merge locally into the primary branch.
8. Create the next story branch and continue.

Do not push or create PRs unless I explicitly approve.
```
