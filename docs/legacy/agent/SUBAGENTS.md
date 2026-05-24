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
4. Recovery action if failing but recoverable
5. Hard-stop recommendation only if an invariant would be violated
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
4. Recovery action if failing but recoverable
5. Hard-stop recommendation only if acceptance criteria cannot be verified
```

## Validation guard

```text
Spawn a validation guard subagent.

Review the proposed Goal against story acceptance criteria and RoomForge validation rules.

Check:
- target story ACs
- app/editor/server checks
- validation fallbacks for missing local tooling
- required test/fixture updates
- ownership/admin/auth checks
- save/load/export round-trip rules where relevant
- performance target evidence where relevant

Return:
1. Acceptance criteria checklist
2. Required verification commands
3. Fallback commands
4. Fix/retry plan for failures
5. Completion criteria
```

## Recovery guard

```text
Spawn a recovery guard subagent.

Read docs/agent/RECOVERY_PLAYBOOK.md, docs/agent/STOP_CONDITIONS.md, docs/agent/BRANCH_STRATEGY.md, and docs/agent/COMMIT_POLICY.md.

Classify the current repository issue as recoverable or hard-stop.
If recoverable, return exact commands or actions to preserve work, split files, repair branch state, rerun validation, and continue.
Only recommend stopping if recovery would risk data loss, scope drift, security exposure, or an invariant violation.
```

## Story loop guard

```text
You are the RoomForge story loop guard.
Read docs/agent/STORY_QUEUE.md, docs/agent/STORY_EXECUTION_LOOP.md, docs/agent/AUTO_RUN.md, docs/agent/RECOVERY_PLAYBOOK.md, docs/agent/BRANCH_STRATEGY.md, and docs/agent/COMMIT_POLICY.md.
Verify that the current work is exactly one target story, on the correct story branch or recoverable to that branch, with validation planned or completed, and with one story-level commit message.
Do not return go/no-go only. Return either:
- continue, with validation plan; or
- recover and continue, with recovery steps; or
- hard stop, with the hard-stop condition and recovery already attempted.
```

## Story commit guard

```text
You are the RoomForge story commit guard.

Read AGENTS.md and docs/agent/COMMIT_POLICY.md. Review the proposed commit and confirm it maps to exactly one completed story.
If unrelated changes are present, use docs/agent/RECOVERY_PLAYBOOK.md to split or stash them before committing.
Return staged files, validation evidence, commit message, and whether the story commit can be created locally.
Push/PR must remain blocked unless user explicitly approved.
```
