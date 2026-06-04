# Current Workspace Refactor Workflow

This workflow governs the current `codex/refactoring-architecture` workspace
while RoomForge moves from the old Flutter-web screen catalog toward the
route-driven React web / native mobile architecture.

It is intentionally narrower than the older story queue. The current work is a
refactor-planning and design-surface migration workflow, not feature
implementation.

## Operating Rule

```text
1 route group = 1 goal = 1 validation loop = 1 local commit
```

Do not push or create a PR without explicit user approval. Keep `private`
submodule changes out of root commits unless the user explicitly asks to update
that submodule pointer.

## Source Of Truth Order

Use this order when a document or mockup disagrees:

1. `docs/refactor/routing-page-definition.md`
2. `docs/refactor/current-workspace-workflow.md`
3. `docs/design/landing.html` and `docs/design/specs/00-landing.md`
4. `docs/design/system/tokens.css`, `base.css`, and `motion.js`
5. Firebase data/status/security contracts in `docs/refactor/`
6. Older `docs/design/production-ui-migration-plan.md` and numbered screen specs

Older documents that say Flutter owns desktop routing, admin UI, or all product
screens are historical for this refactor. Preserve their useful state lists, but
do not let them override the route ownership table.

## Current Worktree Policy

The current workspace may contain design WIP from an interrupted refactor pass.
Before editing route mockups, classify the WIP instead of reverting it.

Observed WIP categories:

| Path pattern | Treatment |
|---|---|
| `docs/design/landing.html` | Keep as landing source; compare against `landing.backup.html` before committing new landing edits. |
| `docs/design/landing.backup.html` | Temporary recovery artifact; remove only after landing parity is verified. |
| `docs/design/screens/desktop/login.html`, `projects.html`, `workspace.html` | Treat as route-draft mockups. Normalize into the route-based catalog before committing. |
| Deleted `docs/design/screens/{desktop,mobile}/NN-*.html` | Do not blindly restore. Retire after equivalent route-based mockups exist, or archive intentionally. |
| `docs/design/system/vendor/*` | Keep only if explicitly required by route mockups. Prefer shared tokens/base/motion first. |
| `docs/legacy/desktop`, `docs/legacy/mobile` | Use as archive candidates for retired numbered mockups if they contain preserved old screens. |
| `private` | Ignore at root level unless explicitly working in the submodule. |

## Target Design Folder Shape

The design folder should become route-based, not numbered-screen-based.

```text
docs/design/
├── landing.html
├── index.html
├── assets/
├── system/
│   ├── tokens.css
│   ├── base.css
│   ├── motion.js
│   └── route-mockups.css
├── routes/
│   ├── login.html
│   ├── projects.html
│   ├── project-overview.html
│   ├── project-workspace.html
│   ├── room.html
│   ├── source.html
│   ├── status.html
│   ├── review.html
│   ├── floor-plan.html
│   ├── editor.html
│   ├── layouts.html
│   ├── export.html
│   ├── recovery.html
│   ├── admin-dashboard.html
│   ├── admin-jobs.html
│   ├── admin-job-detail.html
│   ├── admin-job-retry.html
│   ├── admin-job-audit.html
│   ├── admin-audit.html
│   ├── admin-access-denied.html
│   ├── mobile-locked.html
│   └── native-handoff.html
└── specs/
```

`docs/design/screens/desktop` and `docs/design/screens/mobile` are legacy
screen-catalog locations during this refactor. They should not be the final
source of truth for route pages.

## Route Groups

### Group 0 - Workspace Audit

Goal: make the dirty design worktree understandable before changing assets.

Tasks:

- capture `git status --short`;
- list current design HTML files;
- classify deleted numbered screens, new draft screens, vendor files, and backup
  files;
- decide whether old numbered screens are archived or replaced by route pages.

Validation:

```bash
git diff --check
rg --files docs/design docs/refactor
```

Commit:

```text
docs(refactor): define current workspace workflow
```

### Group 1 - Design System Base

Goal: establish the shared route mockup shell before individual pages.

Tasks:

- keep `tokens.css`, `base.css`, and `motion.js` as the visual baseline;
- create or rename route-specific shared CSS, preferably
  `docs/design/system/route-mockups.css`;
- remove unnecessary vendor dependencies unless a page needs them;
- update `docs/design/index.html` to point to route-based pages.

Validation:

```bash
git diff --check
```

Browser check:

- landing renders;
- route index renders;
- no missing shared CSS/JS paths.

Commit:

```text
design(routes): establish route mockup system
```

### Group 2 - Public And Auth Routes

Routes:

- `/`
- `/login`

Mockups:

- `docs/design/landing.html`
- `docs/design/routes/login.html`

Validation:

- desktop width;
- mobile width;
- login idle/loading/error states;
- landing CTA goes to `/projects`, not `/app`.

Commit:

```text
design(routes): define public and auth pages
```

### Group 3 - Project Entry Routes

Routes:

- `/projects`
- `/projects/new`
- `/projects/:projectId`

Mockups:

- `docs/design/routes/projects.html`
- `docs/design/routes/project-overview.html`

Validation:

- empty project list;
- populated project list;
- create project modal state;
- mobile web stays allowed.

Commit:

```text
design(routes): define project entry pages
```

### Group 4 - Core Project Workflow Routes

Routes:

- `/projects/:projectId/workspace`
- `/projects/:projectId/room`
- `/projects/:projectId/source`
- `/projects/:projectId/status`

Mockups:

- `project-workspace.html`
- `room.html`
- `source.html`
- `status.html`

Validation:

- status vocabulary preserves persisted values;
- `review_required` displays as `Needs review`;
- mobile source upload shows native-app handoff, not a fake camera workflow.

Commit:

```text
design(routes): define core project workflow pages
```

### Group 5 - CV And Editor Routes

Routes:

- `/projects/:projectId/review`
- `/projects/:projectId/floor-plan`
- `/projects/:projectId/editor`

Mockups:

- `review.html`
- `floor-plan.html`
- `editor.html`
- `mobile-locked.html`
- `native-handoff.html`

Validation:

- desktop CV review and editor are full workflows;
- mobile web shows locked state and handoff;
- editor persistence remains outside the editor surface.

Commit:

```text
design(routes): define cv and editor pages
```

### Group 6 - Layout And Recovery Routes

Routes:

- `/projects/:projectId/layouts`
- `/projects/:projectId/export`
- `/projects/:projectId/recovery`

Mockups:

- `layouts.html`
- `export.html`
- `recovery.html`

Validation:

- local draft is not presented as cloud source of truth;
- export is desktop-first;
- mobile web can preview/recent layouts only.

Commit:

```text
design(routes): define layout and recovery pages
```

### Group 7 - Admin Routes

Routes:

- `/admin`
- `/admin/jobs`
- `/admin/jobs/:jobId`
- `/admin/jobs/:jobId/retry`
- `/admin/jobs/:jobId/audit`
- `/admin/audit`
- `/admin/access-denied`

Mockups:

- `admin-dashboard.html`
- `admin-jobs.html`
- `admin-job-detail.html`
- `admin-job-retry.html`
- `admin-job-audit.html`
- `admin-audit.html`
- `admin-access-denied.html`

Validation:

- admin routes are outside product workspace;
- mobile web admin is locked with desktop guidance;
- retry/audit flows reference Callable Functions, not client-only privileged
  writes.

Commit:

```text
design(routes): define admin pages
```

## Validation Loop

For each group:

1. Run static checks:

   ```bash
   git diff --check
   rg --files docs/design docs/refactor
   ```

2. Render at minimum widths:

   ```text
   1440 desktop
   1024 tablet
   390 mobile
   ```

3. Check links:

   - no final `/app/**`;
   - no final `/m/app/**`;
   - no final `/m/projects/**`;
   - `/projects/**` is the authenticated product route family;
   - `/admin/**` is separate;
   - `/legacy/**` is migration-only.

4. Commit only the current group.

## Stop Conditions

Stop and ask before proceeding if:

- a route requires a data contract not covered by Firebase docs;
- a mobile web screen starts duplicating native camera behavior;
- editor mockups require Firebase SDK access inside editor code;
- old numbered mockups contain states not represented in the route table;
- the work would require committing `private` submodule changes.
