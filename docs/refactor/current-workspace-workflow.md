# Current Workspace Design Workflow

This workflow governs the current `codex/refactoring-architecture` workspace
while RoomForge moves from the old Flutter-web screen catalog toward the
route-driven React web / native mobile architecture.

It is intentionally narrower than the older story queue. The current work is
screen design for the route table, not product feature implementation and not
route-table redesign.

## Current Decisions (supersede conflicting guidance below)

Agreed with the project owner during this design pass. Where this section
conflicts with "Target Design Folder Shape", the route groups, or the CSS rules
below, this section wins.

- **Scope: desktop web + native mobile mockups.** Product web route mockups are
  desktop-first under `screens/desktop/`. The mobile surface is the **Flutter
  native app** (capture-first); its screens are mocked as mobile-width HTML under
  `screens/mobile/` to serve as **Flutter implementation specs** (not React
  migration). Do not build a responsive mobile-web product app here — mobile is
  the native app.
- **Working location:** `docs/design/screens/desktop/` with route-named files
  (`login.html`, `projects.html`, `workspace.html`, ...). The `routes/`
  single-file shape in "Target Design Folder Shape" is not used.
- **CSS / tooling:** mockups use **Tailwind** (vendored at
  `system/vendor/tailwind.js`) with an inline `tailwind.config` that maps the
  design tokens to CSS variables, plus `tokens.css` for brand tokens. This keeps
  pages 1:1 translatable to the React app and is the source of the landing
  visual language. `base.css`/`motion.js` are optional and only used when they
  do not conflict with the token palette.
- **Project creation:** there is no `/projects/new` modal route. Creating a
  project provisions it and navigates directly to
  `/projects/:projectId/workspace`, where naming, photo upload, and capture
  handoff happen. `routing-page-definition.md` is updated to match.
- **No export/layouts stage:** export is a single "floor-plan image (PNG)"
  button in the editor 2D toolbar, not a route. Layouts (save/load) are removed
  — the editor auto-saves one state. Pipeline is just 소스 → 재구성 → 편집; Group 6's
  layouts/export mockups are dropped (recovery handled separately if needed).
- **No candidate review; floor-plan in editor:** reconstruction outputs a
  best-effort editable model. There is no `/projects/:projectId/review` route,
  and `/projects/:projectId/floor-plan` is folded into the editor as a 2D mode.
  Pipeline: 소스 → 재구성 → 편집 → 내보내기 (Group 5's review/floor-plan mockups are dropped).
- **Overview = workspace (merged):** `/projects/:projectId` is the single
  project hub (pipeline, preview, source, status, next-step actions). There is
  no separate `/projects/:projectId/workspace` route; Group 4's
  `project-workspace.html` is delivered as `screens/desktop/project.html`.
- **Validation widths:** desktop-first (1440 / 1024). The 390 mobile pass is
  owned by the Flutter app, not these HTML mockups.

## Operating Rule

Default rule for mockups:

```text
1 route page = 1 goal = 1 validation loop = 1 local commit
```

Shared foundation work, such as route mockup CSS or the design index, may use:

```text
1 shared design group = 1 goal = 1 validation loop = 1 local commit
```

Do not push or create a PR without explicit user approval. Keep `private`
submodule changes out of root commits unless the user explicitly asks to update
that submodule pointer.

Do not edit `docs/refactor/routing-page-definition.md` during page design. If a
page appears missing or a route seems wrong, stop and ask before changing the
route table.

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

During the current design pass, `routing-page-definition.md` is read-only route
inventory. `current-workspace-workflow.md` may be edited to clarify process,
file layout, validation, or WIP handling.

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

Each route page gets one canonical HTML mockup under `docs/design/routes/`.
Responsive desktop/mobile states should live in that route file instead of
creating parallel `desktop` and `mobile` page trees. Use explicit in-page states
for mobile-web locked/handoff behavior when the route is available on desktop
but restricted on mobile.

## Page Design Loop

Use this loop for every route page:

1. Select exactly one route from `routing-page-definition.md`.
2. Write a short goal for that route page:
   - canonical URL;
   - page purpose;
   - required states;
   - desktop behavior;
   - mobile-web behavior;
   - native app handoff, if any.
3. Create or update one file under `docs/design/routes/`.
4. Use shared `tokens.css`, `base.css`, and `motion.js` first.
5. Add route-specific CSS only when the shared system cannot express the page.
6. Verify links:
   - no final `/app/**`;
   - no final `/m/app/**`;
   - no final `/m/projects/**`;
   - product links go to `/projects/**`;
   - admin links go to `/admin/**`;
   - legacy links are clearly labeled migration-only.
7. Validate and commit only that page, unless the goal is a shared system group.

The page file should include at least these design states when relevant:

| State type | Examples |
|---|---|
| Empty | No projects, no uploads, no jobs. |
| Loading | Auth, project fetch, job status, admin lookup. |
| Ready | Normal usable route state. |
| Error | Permission, network, missing data, sync failure. |
| Mobile limited | Locked editor/admin/upload, desktop or native-app handoff. |
| Accessibility | Focus, keyboard target, non-color-only status. |

## Route Groups

Route groups define sequence only. Actual mockup commits should normally be
page-level.

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
design(routes): audit current design workspace
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
design(routes): define <page-name>
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
design(routes): define <page-name>
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
design(routes): define <page-name>
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
design(routes): define <page-name>
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
design(routes): define <page-name>
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
design(routes): define <page-name>
```

## Validation Loop

For each route page or shared design group:

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

4. Commit only the current route page or shared design group.

## Stop Conditions

Stop and ask before proceeding if:

- a route requires a data contract not covered by Firebase docs;
- a mobile web screen starts duplicating native camera behavior;
- editor mockups require Firebase SDK access inside editor code;
- old numbered mockups contain states not represented in the route table;
- the work would require committing `private` submodule changes.
