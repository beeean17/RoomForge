# RoomForge Recovery Playbook

Use this file before stopping on branch, worktree, mixed-change, or validation issues.

## Principle

Most operational problems are recoverable. First preserve the user's work, classify it, repair it, validate, and continue. Only hard stop if recovery would risk data loss, scope drift, security problems, or unresolvable semantic conflicts.

## File buckets

Classify changed files into these buckets:

### Agent ops files

```text
AGENTS.md
MANIFEST.md
app/AGENTS.md
editor/AGENTS.md
server/AGENTS.md
docs/agent/**
```

### Product story files

Usually one or more of:

```text
app/lib/**
app/test/**
editor/src/**
editor/tests/**
server/app/**
server/tests/**
packages/**
docs/story/**
```

### Planning source files

```text
_bmad-output/planning-artifacts/**
```

Do not edit planning source files during story implementation unless the user explicitly asks to update planning artifacts.

### Unrelated or unknown files

Any changed file not needed for the target story and not in the agent ops bucket.

## Recovery A - Dirty worktree before story start

1. Inspect:

```bash
git branch --show-current
git status --short
git diff --stat
```

2. Classify changed files by bucket.
3. If only target-story files are dirty and current branch matches target story, continue.
4. If only agent ops files are dirty, create/update `chore/agent-instructions`, commit them locally, fast-forward merge into primary, and resume.
5. If agent ops and target-story files are mixed, use Recovery B.
6. If unrelated/unknown files exist, stash them with a descriptive name, continue, and report the stash name.

## Recovery B - Agent instruction changes mixed with product story changes

Use this when files such as `AGENTS.md`, `MANIFEST.md`, or `docs/agent/**` are mixed with `app/lib/**`, `editor/src/**`, or `server/app/**`.

```bash
# 1. Preserve all current changes.
git stash push -u -m "auto-split agent docs and product story work"

# 2. Update agent docs on a chore branch.
git switch <primary-branch>
git pull --ff-only || true
git switch -c chore/agent-instructions || git switch chore/agent-instructions

git restore --source=stash^{/"auto-split agent docs and product story work"} --worktree --staged \
  AGENTS.md MANIFEST.md app/AGENTS.md editor/AGENTS.md server/AGENTS.md docs/agent || true

git add AGENTS.md MANIFEST.md app/AGENTS.md editor/AGENTS.md server/AGENTS.md docs/agent
git diff --cached --quiet || git commit -m "chore: update RoomForge Codex agent instructions"

# 3. Bring the agent-docs commit into the local primary branch.
git switch <primary-branch>
git merge --ff-only chore/agent-instructions || git merge --no-edit chore/agent-instructions

# 4. Recreate or switch to the target story branch from the updated primary.
git switch -c <target-story-branch> || git switch <target-story-branch>

# 5. Restore only target story product files from the stash.
git restore --source=stash^{/"auto-split agent docs and product story work"} --worktree --staged \
  app/lib app/test editor/src editor/tests server/app server/tests packages || true

# 6. Confirm no agent ops files remain modified on the story branch.
git status --short
```

If `git restore` pathspecs fail because a directory does not exist, ignore the failed path and continue with existing paths.

## Recovery C - Wrong branch

If on the primary branch with no product changes:

```bash
git switch -c <target-story-branch>
```

If on the primary branch with product changes:

```bash
git stash push -u -m "auto-move product changes to <target-story-branch>"
git switch -c <target-story-branch>
git stash apply stash^{/"auto-move product changes to <target-story-branch>"}
```

If on another story branch with target-story changes:

- If the branch has no commits unique to the wrong story, rename it:

```bash
git branch -m <target-story-branch>
```

- If it already contains another story's committed work, stash current target changes, switch/create the correct target story branch, apply the stash, and continue.

## Recovery D - Previous story locally committed but not merged

If the previous story branch has one validated local story commit and the primary branch can fast-forward:

```bash
git switch <primary-branch>
git merge --ff-only <previous-story-branch>
git switch -c <next-story-branch>
```

If fast-forward fails:

```bash
git switch <previous-story-branch>
git rebase <primary-branch>
# resolve simple conflicts if they are mechanical and inside current story scope
git switch <primary-branch>
git merge --ff-only <previous-story-branch>
```

Hard stop only if rebase/merge conflicts require product decisions or risk losing work.

## Recovery E - Validation command missing

Missing commands are not automatic blockers.

Use fallbacks:

### Server

Try in order:

```bash
cd server && python -m pytest
cd server && python3 -m pytest
cd server && .venv/bin/python -m pytest
cd server && uv run pytest
cd server && poetry run pytest
```

For compile/import checks:

```bash
cd server && python -m compileall app
cd server && python3 -m compileall app
cd server && .venv/bin/python -m compileall app
```

### Editor

Check available scripts first:

```bash
cd editor && cat package.json
```

Then run scripts that exist:

```bash
cd editor && npm run typecheck
cd editor && npm run build
cd editor && npm test
```

A Vite chunk-size warning is not a failure unless the command exits non-zero or the story explicitly requires bundle-size work.

### App

Try:

```bash
cd app && flutter analyze
cd app && flutter test
```

If Flutter is not installed or not in PATH, document:

```text
app validation unavailable: flutter not found in PATH
```

Then use available substitutes where possible:

```bash
cd app && dart --version
cd app && dart format --set-exit-if-changed lib test
```

If `dart` is also unavailable, document environment limitation and continue only if acceptance criteria can be verified by other evidence.

## Recovery F - Validation failure

When validation fails:

1. Identify whether the failure is caused by current-story changes.
2. Fix current-story failures within the story branch.
3. Re-run the failed command.
4. Run the full affected validation set after the fix.
5. Repeat up to three validation/fix cycles.

Hard stop only if:

- the same failure remains after three focused fix attempts;
- the failure is unrelated to the target story and cannot be safely isolated;
- the fix requires implementing a different story;
- the fix would violate a RoomForge invariant.

## Recovery G - Fixture or partial handoff

If Story 4.1 cannot load a persisted floor plan from the API but can initialize a valid metric fixture/demo floor plan:

- continue with Story 4.1;
- document the limitation as partial handoff;
- ensure the fixture uses meters and a clearly stated coordinate space;
- do not claim persisted handoff is complete;
- leave a follow-up for later API integration if needed.

## Recovery report shape

Whenever recovery is used, include this in the completion report:

```text
Recovery used:
- Issue:
- Recovery playbook section:
- Commands/actions taken:
- Result:
- Remaining limitation:
```
