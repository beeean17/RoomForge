# RoomForge Stop Conditions

This file defines **hard stops**. Recoverable branch, worktree, and validation issues must first go through `docs/agent/RECOVERY_PLAYBOOK.md`.

## Default behavior

Do not stop immediately for:

- dirty worktree;
- wrong branch;
- agent docs mixed with product work;
- missing local tool such as Flutter;
- `python` missing when substitutes exist;
- Vite chunk-size warning;
- validation failure caused by current-story code.

First attempt recovery. Stop only when a hard stop remains after recovery attempts.

## Hard stop: destructive or remote actions

Stop before doing any of these unless explicitly authorized:

- pushing to remote;
- creating a PR/MR;
- force-pushing;
- deleting remote branches;
- dropping a stash containing user work;
- running `git reset --hard` or `git clean -fd` on unpreserved user changes;
- rewriting published branch history.

## Hard stop: product and planning conflicts

Stop when:

- the requested work conflicts with planning artifacts and no small reversible assumption can resolve it;
- the requested work changes MVP scope;
- the requested work introduces a post-MVP feature as production behavior rather than a stub/extension point;
- the requested work jumps ahead of the story queue without a dependency reason;
- the requested work combines multiple stories and cannot be split automatically.

## Hard stop: architecture invariants

Stop when the implementation would require:

- heavy OpenCV, deep-learning, or GPU inference on the lightweight API server;
- direct editor-to-Oracle API calls from rendering modules;
- merging candidate geometry and confirmed geometry;
- introducing a persisted status outside the allowed list;
- removing the API envelope `data`, `error`, `meta.request_id`;
- omitting coordinate space from geometry payloads when geometry is persisted or exchanged;
- bypassing auth/ownership/admin authorization checks.

## Hard stop: unresolved prerequisite gaps

Before Story 4.1, hard stop only if all of these are true:

- no metric floor plan handoff exists;
- no valid metric fixture/demo floor plan can be used;
- editor initialization cannot receive floor plan or scene data;
- the missing prerequisite cannot be fixed in a small focused fix branch.

Before Story 5.1, hard stop only if:

- shared spatial model state cannot be serialized;
- furniture IDs or coordinates are unstable and cannot be fixed within the current story.

Before Story 6.1, hard stop only if:

- required job/status/artifact records do not exist;
- admin authorization boundary is absent and cannot be introduced as a focused prerequisite fix.

## Hard stop: validation after recovery

Stop only after validation recovery has been attempted when:

- no relevant check or substitute evidence can verify the story acceptance criteria;
- a current-story validation failure remains after three focused fix/retry cycles;
- a failing check indicates an unrelated earlier regression that cannot be isolated or fixed safely;
- acceptance criteria cannot be verified from implementation, tests, or documented manual checks.

## Hard stop: merge/rebase conflicts

Stop when:

- branch recovery produces conflicts that require product decisions;
- conflict resolution would alter unrelated stories;
- fast-forward/local merge cannot be repaired safely.

## Required hard-stop report

When stopping, report:

1. Hard stop condition.
2. Recovery attempts already performed.
3. Evidence from repository or documents.
4. Smallest safe next action.
5. Whether the current story should pause, shrink, or be replaced by a fix branch.
6. Current branch, stash names, and uncommitted changes.
