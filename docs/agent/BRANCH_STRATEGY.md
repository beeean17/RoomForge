# RoomForge Branch Strategy

## Default rule

Use a story-branch workflow.

```text
main / trunk    = stable validated baseline
story branch    = one target story
story commit    = one completed and validated story
pull request    = one story branch
epic            = multiple story branches, never one branch by default
```

Do not implement feature work directly on `main` or the repository's primary branch unless the user explicitly instructs you to do so.

## Branch naming

Use lowercase branch names with the story number and a short slug.

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

Use these only when appropriate:

```text
chore/agent-instructions       # agent files, setup docs, tooling docs
fix/story-4.1-view-state        # focused fix for a completed story
spike/story-3.1-editor-bridge   # explicit spike/enabler work
docs/story-5.4-round-trip       # documentation-only story output
```

## Branch lifecycle

Before starting a story:

```bash
git status --short
git fetch origin
git switch main
git pull --ff-only
git switch -c story/4.1-shared-spatial-model
```

If the repository uses `master`, `trunk`, or another primary branch, use that branch instead of `main`. Detect the primary branch from the repository instead of assuming.

If `git status --short` is not clean, stop and report the existing changes before creating or switching branches.

During the story:

- Keep all implementation work on the story branch.
- Keep scope limited to the target story.
- Do not start the next story on the same branch.
- Do not mix unrelated cleanup, experiments, or agent-file changes into a story branch.
- If a prerequisite gap belongs to an earlier completed story, stop and propose a separate `fix/story-x.y-...` branch.

After validation:

```bash
git status --short
git diff --stat
git add <story files only>
git commit -m "feat(story-4.1): implement shared spatial model and 2d 3d view shell"
git push -u origin story/4.1-shared-spatial-model
```

Open a PR or merge request from the story branch to `main` after human review.

If GitHub CLI is available and the user asked to create a PR:

```bash
gh pr create \
  --base main \
  --head story/4.1-shared-spatial-model \
  --title "feat(story-4.1): implement shared spatial model and 2d 3d view shell" \
  --body-file docs/agent/last-completion-report.md
```

Do not assume `gh` is installed. If it is not available, report the branch name, commit hash, and suggested PR title/body.

## Agent instruction setup branch

When installing or updating only these agent files, use a separate ops branch:

```bash
git switch -c chore/agent-instructions
git add AGENTS.md MANIFEST.md app/AGENTS.md editor/AGENTS.md server/AGENTS.md docs/agent
git commit -m "chore: add RoomForge Codex agent instructions"
git push -u origin chore/agent-instructions
```

Do not combine agent instruction changes with a product story implementation.

## Commit and merge policy

The desired repository history is:

```text
one story branch -> one validated story commit -> one PR/MR -> merge to main
```

If the story branch accidentally accumulates several checkpoint commits, squash or rebase them into one story commit before merge unless the user explicitly wants to keep the intermediate commits.

Do not merge a branch when:

- acceptance criteria are incomplete
- relevant checks were not run and no substitute evidence exists
- unrelated changes are staged or committed
- the branch contains multiple stories
- the branch was created from a stale primary branch and conflicts are unresolved

After merge:

```bash
git switch main
git pull --ff-only
git branch -d story/4.1-shared-spatial-model
```

Delete the remote branch if the hosting service does not do it automatically.

## Multiple-agent work

Use one implementation agent per story branch.

Parallel branches are acceptable only when they do not overlap the same files or contracts. If two branches both touch shared spatial model, bridge schema, API envelope, job status model, layout schema, or design tokens, run a Team review before coding and choose a sequence.

Recommended safe parallelism:

- one implementation branch
- one review-only subagent set
- one documentation/ops branch only when it does not touch product code

Avoid running two implementation agents on adjacent dependent stories at the same time. For example, do not implement Story 4.2 before Story 4.1 has merged unless the 4.1 contract is already stable.

## Branch readiness report

Before coding a story, report:

```text
Branch readiness:
- Primary branch:
- Current branch:
- Working tree clean:
- Target story:
- Planned story branch:
- Branch created:
- Expected commit message:
```

Before committing or pushing, report:

```text
Branch completion:
- Current branch:
- Target story:
- Files changed:
- Validation run:
- Commit message:
- Push/PR requested by user:
- Unrelated changes present:
```
