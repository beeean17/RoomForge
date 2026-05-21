# RoomForge Goal Template

Use this template for every `/goal`.

```text
/goal [one concrete outcome]

Current baseline:
- Treat RoomForge as implemented through Story 3.6 unless repository evidence contradicts this.
- Do not reimplement completed stories unless the Goal explicitly asks for a fix.

Before implementing:
- Read `docs/agent/BRANCH_STRATEGY.md` and `docs/agent/COMMIT_POLICY.md`.
- Identify the exact target story, confirm branch readiness, and produce a story execution plan before coding.
- Read `_bmad-output/planning-artifacts/implementation-readiness-report-2026-05-08.md`.
- Read `_bmad-output/planning-artifacts/epics.md` for the target story acceptance criteria.
- Read `_bmad-output/planning-artifacts/architecture.md` for boundaries and patterns.
- Read PRD/UX documents only when the story affects product behavior, UX, accessibility, or editor interactions.
- Summarize the target story, acceptance criteria, constraints, validation plan, and stop conditions before coding.
- If implementing Story 4.1 or later, verify that the Story 3.5/3.6 reconstruction-to-editor handoff is sufficient.


Branch setup:
- Do not implement on `main` or the repository primary branch unless the user explicitly asks.
- Use a story branch such as `story/4.1-shared-spatial-model`.
- Confirm the working tree is clean before branch creation.
- If unrelated user changes exist, stop and report them.
- Do not commit, push, or create a PR unless the user explicitly asks.

Scope:
- Keep changes limited to the target story unless a direct prerequisite is missing.
- Do not broaden MVP scope.
- Do not add post-MVP features except as documented stubs or extension points.

Story branch and commit plan:
- The default branch unit is one target story.
- If the Goal includes multiple stories, implement and validate one story at a time.
- Each story plan should list likely files, acceptance criteria, validation, and suggested commit message.
- Do not combine multiple stories or epics in one commit.

Validation:
- Run documented checks for affected workspaces.
- Add or update the smallest meaningful test/check for the story.
- Verify acceptance criteria directly.
- Verify RoomForge invariants from AGENTS.md.

Stop and report if:
- The task requires changing MVP scope.
- The task requires heavy CV/GPU/deep-learning execution on the API server.
- The task requires a persisted status outside the allowed list.
- The task would merge candidate geometry and confirmed geometry.
- The task bypasses auth/ownership checks.
- The task requires direct editor-to-Oracle API calls from rendering modules.
- A required story prerequisite is missing.
- Verification cannot be run and no substitute check is possible.

Before each commit suggestion, actual commit, push, or PR:
- Report branch name, story, acceptance criteria status, files changed, validation run, result, known limitations, suggested commit message, and PR readiness.

Complete only when:
- Acceptance criteria are implemented or explicitly documented as deferred with reason.
- Relevant checks pass or failures are reported.
- Changed files, verification results, assumptions, risks, and next recommended Goal are reported.
```
