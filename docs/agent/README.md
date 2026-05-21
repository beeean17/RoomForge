# RoomForge Agent Playbooks

This folder contains repeatable instructions for Codex agents working in the RoomForge repository.

## File map

- `CURRENT_PROGRESS.md` - current implementation baseline and next-story order
- `TEAM.md` - review/teammate role for scope, sequencing, risk, and validation
- `GOAL_TEMPLATE.md` - template for every `/goal`
- `GOALS.md` - concrete Goals starting from the current baseline after Story 3.6
- `VALIDATION.md` - global and story-specific validation checks
- `STOP_CONDITIONS.md` - conditions where an agent must stop and report
- `SUBAGENTS.md` - suggested architecture/UX/validation subagent prompts
- `BRANCH_STRATEGY.md` - branch naming, branch lifecycle, push/PR rules
- `COMMIT_POLICY.md` - story-level commit rules
- `COMPLETION_REPORT.md` - required report format after each Goal

## How to use

Start a Codex session at the repository root and ask it to read:

```text
Read AGENTS.md, docs/agent/CURRENT_PROGRESS.md, docs/agent/TEAM.md, docs/agent/GOALS.md, and docs/agent/BRANCH_STRATEGY.md.
Use the current baseline through Story 3.6. Review the next Goal before coding.
```

Then run one Goal at a time:

```text
Run Goal 4.1 from docs/agent/GOALS.md.
Before coding, summarize target acceptance criteria, prerequisites, branch readiness, validation plan, and stop conditions.
Finish with docs/agent/COMPLETION_REPORT.md format.
```

## Current baseline assumption

The user stated that RoomForge is currently done through **Story 3.6**. These files are intentionally biased toward the next work: Epic 4 planning editor, Epic 5 persistence/export, and Epic 6 admin operations.

If the repository contradicts the Story 3.6 baseline, the agent should stop and report the mismatch rather than guessing.


## Commit granularity

Use `COMMIT_POLICY.md` for every Goal. The default granularity is **one completed story = one commit**. The agent should produce a story execution plan before coding and report story commit readiness after the story is validated.


## Branch workflow

Use `BRANCH_STRATEGY.md` for every implementation Goal. The default branch policy is **one target story = one branch**.

Recommended first story branch after the current baseline:

```bash
git switch main
git pull --ff-only
git switch -c story/4.1-shared-spatial-model
```

Do not implement product stories directly on `main`. Do not mix agent instruction updates with story implementation branches.
