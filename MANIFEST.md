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
  "generated_for": "RoomForge agent markdown files v4",
  "assumed_current_progress": "through Story 3.6",
  "default_next_story": "Story 4.1",
  "branch_policy": "story branches: one target story equals one branch",
  "commit_policy": "story-sized commits: one completed story equals one commit",
  "files": [
    "AGENTS.md",
    "MANIFEST.md",
    "app/AGENTS.md",
    "docs/agent/COMPLETION_REPORT.md",
    "docs/agent/BRANCH_STRATEGY.md",
    "docs/agent/COMMIT_POLICY.md",
    "docs/agent/CURRENT_PROGRESS.md",
    "docs/agent/GOALS.md",
    "docs/agent/GOAL_TEMPLATE.md",
    "docs/agent/README.md",
    "docs/agent/STOP_CONDITIONS.md",
    "docs/agent/SUBAGENTS.md",
    "docs/agent/TEAM.md",
    "docs/agent/VALIDATION.md",
    "editor/AGENTS.md",
    "server/AGENTS.md"
  ]
}
```

## Install check

After copying the files into the project root, verify:

```bash
test -f AGENTS.md
test -f MANIFEST.md
test -f docs/agent/GOALS.md
test -f docs/agent/BRANCH_STRATEGY.md
test -f docs/agent/COMMIT_POLICY.md
test -f app/AGENTS.md
test -f editor/AGENTS.md
test -f server/AGENTS.md
```

## Agent start prompt

```text
Read AGENTS.md, MANIFEST.md, docs/agent/CURRENT_PROGRESS.md, docs/agent/TEAM.md, docs/agent/GOALS.md, docs/agent/BRANCH_STRATEGY.md, and docs/agent/COMMIT_POLICY.md.

Use the current baseline through Story 3.6. Do not restart from Story 1.1.
Before coding, confirm branch readiness and produce a story execution plan. Each commit should represent one completed, validated story.
Do not combine multiple stories in one commit, and do not split a story into tiny commits unless explicitly requested.
Use a story branch such as story/4.1-shared-spatial-model. Review the handoff gate, then proceed with Goal 4.1 if the Story 3.5/3.6 handoff is sufficient.
```
