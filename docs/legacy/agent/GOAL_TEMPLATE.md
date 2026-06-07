# RoomForge Goal Template

Use this template for every `/goal`.

Before every `/goal`, use the story loop from `docs/agent/STORY_EXECUTION_LOOP.md`, recovery rules from `docs/agent/RECOVERY_PLAYBOOK.md`, and branch/commit metadata from `docs/agent/STORY_QUEUE.md`.

```text
/goal [one concrete story outcome]

Current baseline:
- Treat RoomForge as implemented through Story 3.6 unless repository evidence contradicts this.
- Do not reimplement completed stories unless the Goal explicitly asks for a fix.

Before implementing:
- Identify the exact target story from docs/agent/STORY_QUEUE.md.
- Repair branch/worktree issues using docs/agent/RECOVERY_PLAYBOOK.md.
- Read _bmad-output/planning-artifacts/implementation-readiness-report-2026-05-08.md.
- Read _bmad-output/planning-artifacts/epics.md for the target story acceptance criteria.
- Read _bmad-output/planning-artifacts/architecture.md for boundaries and patterns.
- Read PRD/UX documents only when the story affects product behavior, UX, accessibility, or editor interactions.
- Produce a short story preflight.

Branch setup:
- Use the target story branch from docs/agent/STORY_QUEUE.md.
- If the branch/worktree is not ready, repair instead of stopping.
- Agent instruction updates must be split to chore/agent-instructions automatically if mixed with product work.

Scope:
- Keep changes limited to the target story unless a direct prerequisite is missing.
- Do not broaden MVP scope.
- Do not add post-MVP features except as documented stubs or extension points.

Validation:
- Run documented checks for affected workspaces.
- Use fallback validation commands when local tooling differs.
- Fix validation failures caused by current-story code and rerun checks.
- Repeat up to three validation/fix cycles.
- Missing Flutter or another local SDK is an environment limitation, not an automatic stop.

Hard stop only if:
- The task requires changing MVP scope.
- The task requires heavy CV/GPU/deep-learning execution on the API server.
- The task requires a persisted status outside the allowed list.
- The task would merge candidate geometry and confirmed geometry.
- The task bypasses auth/ownership checks.
- The task requires direct editor-to-Oracle API calls from rendering modules.
- Acceptance criteria remain unverifiable after recovery and validation attempts.

Complete when:
- Acceptance criteria are pass or documented partial with evidence.
- Relevant checks pass, are substituted, or are unavailable with documented environment reason.
- Completion report is produced.
- One local story commit is created when auto-run mode is active.
- The next story is identified from STORY_QUEUE.md.
```
