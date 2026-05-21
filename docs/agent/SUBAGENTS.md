# RoomForge Subagent Prompts

Use these when a Goal is risky enough to benefit from parallel review.

## Architecture guard

```text
Spawn an architecture guard subagent.

Review the proposed Goal against RoomForge architecture rules:
- app/editor/server boundaries
- API envelope
- status vocabulary
- candidate vs confirmed geometry separation
- coordinate-space rules
- auth/ownership/admin authorization
- no heavy CV/GPU on API server

Return:
1. Pass/fail by category
2. Highest-risk boundary violation
3. Required code or test evidence
4. Go/no-go recommendation
```

## UX/accessibility guard

```text
Spawn a UX/accessibility guard subagent.

Review the proposed Goal against RoomForge UX rules:
- WCAG 2.2 AA for non-canvas controls
- best-effort canvas accessibility
- visible selection
- non-color-only warning/selection states
- reset/preset controls
- textual summaries where feasible
- responsive desktop/tablet/mobile-review behavior
- reduced-motion handling

Return:
1. Pass/fail by category
2. Highest-risk UX/accessibility gap
3. Required manual checks
4. Go/no-go recommendation
```

## Validation guard

```text
Spawn a validation guard subagent.

Review the proposed Goal against story acceptance criteria and RoomForge validation rules.

Check:
- target story ACs
- app/editor/server checks
- required test/fixture updates
- ownership/admin/auth checks
- save/load/export round-trip rules where relevant
- performance target evidence where relevant

Return:
1. Acceptance criteria checklist
2. Required verification commands
3. Any checks that can only be manual
4. Completion criteria
```

## Current-stage reviewer for Epic 4

```text
Spawn an Epic 4 reviewer subagent.

Assume Stories 1.1 through 3.6 are complete. Review whether the proposed Epic 4 implementation preserves:
- valid metric floor plan handoff
- one shared spatial model
- 2D/3D selection and coordinate persistence
- camera reset/presets
- furniture object identity
- measurement units
- non-color-only selection/warnings
- responsive/accessibility criteria in each story

Return the smallest set of corrections needed before coding.
```


## Story commit guard

Use this subagent when a Goal may span more than one story or when staged changes look too broad:

```text
You are the RoomForge story commit guard.

Read AGENTS.md and docs/agent/COMMIT_POLICY.md. Review the proposed Goal and confirm the target story. Check whether the planned or staged changes map to exactly one completed story. Provide the story scope, required acceptance criteria, validation checks, and suggested commit message. Warn if multiple stories, epic-wide work, unrelated cleanup, or unrelated app/editor/server/database/docs changes are being bundled into one commit.
```


## Branch guard

Use this subagent before coding when branch state is unclear, or before committing/pushing/creating a PR:

```text
You are the RoomForge branch guard.

Read docs/agent/BRANCH_STRATEGY.md and docs/agent/COMMIT_POLICY.md. Check the current branch, target story, working tree status, and staged files. Confirm whether the branch maps to exactly one target story and whether it is safe to proceed, commit, push, or create a PR.

Return:
1. Current branch and expected branch
2. Working tree status
3. Whether unrelated changes are present
4. Whether staged files map to one story
5. Go/no-go recommendation
```
