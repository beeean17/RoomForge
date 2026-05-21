# RoomForge Branch Strategy

Read this together with `docs/agent/STORY_QUEUE.md`, `docs/agent/STORY_EXECUTION_LOOP.md`, and `docs/agent/RECOVERY_PLAYBOOK.md`.

## Default rule

Use a story-branch workflow.

```text
primary branch = stable validated local baseline
story branch   = one target story
story commit   = one completed and validated story
remote PR/MR   = optional remote collaboration step, requires user approval
epic           = multiple story branches, never one branch by default
```

## Branch naming

Use lowercase branch names with the story number and a short slug:

```text
story/4.1-shared-spatial-model
story/4.2-3d-room-inspection-controls
story/4.3-add-select-furniture
story/4.4-edit-furniture
story/4.5-measurement-placement-guidance
story/4.6-responsive-accessible-editor
story/5.1-save-layout
story/5.2-load-layout
story/5.3-export-layout-json
story/5.4-layout-round-trip-validation
story/6.1-admin-job-list
story/6.2-admin-job-detail
story/6.3-admin-artifact-viewer
story/6.4-admin-retry
story/6.5-admin-search
story/6.6-provider-failure-diagnosis
```

Use these for non-story work:

```text
chore/agent-instructions
fix/story-4.1-view-state
spike/story-3.1-editor-bridge
docs/story-5.4-round-trip
```

## Primary branch detection

Detect the repository primary branch instead of assuming.

Preferred order:

1. remote HEAD branch from `git remote show origin`;
2. `main`;
3. `master`;
4. `trunk`.

## Normal story lifecycle

```bash
git fetch origin || true
git switch <primary-branch>
git pull --ff-only || true
git switch -c <target-story-branch> || git switch <target-story-branch>
```

If the worktree is dirty or the wrong branch is active, use `docs/agent/RECOVERY_PLAYBOOK.md` instead of stopping.

## Agent instruction setup branch

Agent instruction changes belong on a chore branch:

```bash
git switch -c chore/agent-instructions || git switch chore/agent-instructions
git add AGENTS.md MANIFEST.md app/AGENTS.md editor/AGENTS.md server/AGENTS.md docs/agent
git commit -m "chore: update RoomForge Codex agent instructions"
```

If agent instruction files are already mixed with product story files, auto-split them using Recovery B.

## Local continuation mode

When the user asks to continue through the story queue, use local fast-forward merges to keep moving:

```bash
git switch <primary-branch>
git merge --ff-only <completed-story-branch>
git switch -c <next-story-branch>
```

This preserves one story commit per story and lets the next story start from the updated baseline.

Push and PR/MR creation are not part of local continuation mode and require separate user approval.

## Remote PR mode

When the user wants PR/MR review after each story:

1. commit one story on the story branch;
2. push branch only after user approval;
3. create PR/MR only after user approval;
4. stop after PR/MR and wait for merge before next story.

## What to do with dirty state

Do not stop immediately. Classify changed files:

- target story files: keep on story branch;
- agent ops files: split to `chore/agent-instructions`;
- unrelated files: stash with a descriptive name and continue;
- planning source files: stop unless user explicitly asked to edit planning artifacts.

## Branch completion report

Before each commit and local merge, report:

```text
Branch completion:
- Primary branch:
- Current branch:
- Target story:
- Files changed:
- Recovery used:
- Validation run:
- Commit message:
- Local merge planned:
- Push/PR requested by user:
- Unrelated changes present:
```
