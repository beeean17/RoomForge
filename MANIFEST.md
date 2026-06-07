# Manifest

Place this file at the RoomForge project root beside `AGENTS.md`.

`MANIFEST.md` is an installation index and handoff checklist. It is not the main instruction file. The main instruction file is `AGENTS.md`; this manifest tells humans and agents which support files should exist and where they belong.

## Placement

```text
roomforge/
├── AGENTS.md
├── MANIFEST.md
├── app/AGENTS.md
├── editor/AGENTS.md
├── server/AGENTS.md
└── docs/agent/
    ├── README.md
    ├── CURRENT_PROGRESS.md
    ├── STORY_QUEUE.md
    ├── STORY_EXECUTION_LOOP.md
    ├── AUTO_RUN.md
    ├── RECOVERY_PLAYBOOK.md
    ├── TEAM.md
    ├── GOAL_TEMPLATE.md
    ├── GOALS.md
    ├── VALIDATION.md
    ├── STOP_CONDITIONS.md
    ├── BRANCH_STRATEGY.md
    ├── COMMIT_POLICY.md
    ├── SUBAGENTS.md
    └── COMPLETION_REPORT.md
```

Do not place this file inside `_bmad-output/planning-artifacts/`. That folder contains planning source documents, not agent operating instructions.

## Package metadata

```json
{
  "generated_for": "RoomForge agent markdown files v6",
  "assumed_current_progress": "through Story 3.6",
  "default_next_story": "Story 4.1",
  "execution_loop": "1 story = 1 branch = 1 goal = 1 validation loop = 1 completion report = 1 story commit",
  "remote_policy": "push and PR/MR require explicit user permission",
  "local_policy": "local branch creation, validation recovery, story commits, and local fast-forward merges are allowed when queue/autonomous mode is requested",
  "major_change_from_v5": "recoverable branch/worktree/validation issues are auto-repaired instead of triggering immediate stops"
}
```

## Required files

- `AGENTS.md` - root agent instructions.
- `app/AGENTS.md` - Flutter shell rules.
- `editor/AGENTS.md` - Three.js/OpenCV editor rules.
- `server/AGENTS.md` - FastAPI/Oracle server rules.
- `docs/agent/CURRENT_PROGRESS.md` - current Story 3.6 baseline.
- `docs/agent/STORY_QUEUE.md` - story order, branch names, commit messages.
- `docs/agent/STORY_EXECUTION_LOOP.md` - repeatable story loop.
- `docs/agent/AUTO_RUN.md` - prompt and rules for continuing through all stories.
- `docs/agent/RECOVERY_PLAYBOOK.md` - automatic recovery for dirty worktree, mixed docs/product changes, validation failures, and branch mismatch.
- `docs/agent/TEAM.md` - teammate/reviewer behavior.
- `docs/agent/GOAL_TEMPLATE.md` - `/goal` shape.
- `docs/agent/GOALS.md` - story-specific Goals.
- `docs/agent/VALIDATION.md` - validation and fallback checks.
- `docs/agent/STOP_CONDITIONS.md` - hard stops only after recovery attempts.
- `docs/agent/BRANCH_STRATEGY.md` - branch lifecycle.
- `docs/agent/COMMIT_POLICY.md` - story commit policy.
- `docs/agent/SUBAGENTS.md` - review subagent prompts.
- `docs/agent/COMPLETION_REPORT.md` - completion report template.

## Recommended install command

```bash
cd /path/to/roomforge
unzip /path/to/roomforge-agent-markdown-v6.zip -d /tmp/roomforge-agent-files
rsync -av /tmp/roomforge-agent-files/roomforge-agent-markdown-v6/ ./
```

## Recommended first commit for agent files

If these files are newly installed or updated, commit them separately before product story work:

```bash
git switch main
git pull --ff-only
git switch -c chore/agent-instructions
git add AGENTS.md MANIFEST.md app/AGENTS.md editor/AGENTS.md server/AGENTS.md docs/agent
git commit -m "chore: update RoomForge Codex agent instructions"
```

If product story changes are already mixed into the worktree, do not stop. Use `docs/agent/RECOVERY_PLAYBOOK.md` to split them automatically.

## Recommended Codex prompt

```text
Read AGENTS.md, MANIFEST.md, docs/agent/CURRENT_PROGRESS.md, docs/agent/STORY_QUEUE.md, docs/agent/STORY_EXECUTION_LOOP.md, docs/agent/AUTO_RUN.md, docs/agent/RECOVERY_PLAYBOOK.md, docs/agent/GOALS.md, docs/agent/VALIDATION.md, docs/agent/STOP_CONDITIONS.md, docs/agent/BRANCH_STRATEGY.md, and docs/agent/COMMIT_POLICY.md.

Run the remaining story queue from Story 4.1 through Story 6.6.
Use automatic recovery for dirty worktree, mixed agent docs, branch mismatch, missing validation commands, and validation failures.
Create local story branches and one local story commit per validated story.
Fast-forward merge each completed story locally into the primary branch, then continue to the next story.
Do not push or create PRs unless I explicitly approve.
```
