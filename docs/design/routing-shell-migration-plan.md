# RoomForge Routing And Shell Migration Plan

> Superseded for the React/native refactor by
> `docs/refactor/routing-page-definition.md`. Keep this document as historical
> context for the earlier Flutter-web shell migration plan.

This plan restructures RoomForge around the approved HTML landing page while
keeping the product application in Flutter Web. It supersedes the earlier
single-entry `MaterialApp(home: AuthGate)` routing shape for production UI work,
and it should be executed phase by phase.

```text
1 phase = 1 goal = 1 validation loop = 1 local commit
```

Do not push or open a PR unless the user explicitly approves it.

## Current State

- `docs/design/landing.html` is the approved visual and interaction baseline.
- `docs/design/system/tokens.css`, `docs/design/system/base.css`, and
  `docs/design/system/motion.js` are the shared HTML design-system source.
- `app/lib/main.dart` currently boots a single Flutter app through
  `MaterialApp(home: AuthGate)`.
- Product navigation is mostly `Navigator.push(MaterialPageRoute)`, so browser
  URLs do not represent product screens.
- `ProjectWorkspaceScreen` currently combines app home, project list, project
  detail/workspace, admin entry, and editor entry concerns.
- `EditorBridgeScreen` already embeds the TypeScript/Three.js editor through an
  HTML iframe. Desktop editor and mobile review flows must therefore be routed
  intentionally instead of treating mobile as a narrow desktop editor.
- `app/firebase.json` serves `app/build/web` as the hosting public root, with no
  rewrite policy yet.

## Target URL Contract

```text
/                                   desktop HTML landing
/m                                  mobile HTML landing

/app                                Flutter app home
/app/projects                       project list
/app/workspaces/:projectId          project workspace
/app/workspaces/:projectId/editor   desktop precision editor

/m/app                              mobile app home
/m/app/projects                     mobile project list
/m/app/workspaces/:projectId        mobile workspace overview
/m/app/workspaces/:projectId/capture mobile capture and upload
/m/app/workspaces/:projectId/status  mobile reconstruction status
/m/app/workspaces/:projectId/review  mobile review and handoff

/admin                              admin dashboard
/admin/jobs                         admin job list
/admin/jobs/:jobId                  admin job detail
/admin/retries                      admin retry operations
/admin/audit                        admin audit trail
```

`/admin` is intentionally outside `/app`. Admin is an operational console with a
separate authorization boundary, not a normal user workspace route.

## Shell Responsibilities

### HTML Landing Shell

The landing shell owns:

- first page render for `/` and `/m`;
- the approved micro-interactions from `docs/design/landing.html`;
- desktop and mobile landing-specific media behavior;
- CTA links into Flutter routes.

The landing shell must not own:

- Firebase auth state management;
- project data;
- workspace state;
- admin authorization;
- editor bridge state.

### Flutter App Shell

The Flutter app shell owns:

- auth and user profile sync;
- `/app/**` desktop product routes;
- `/m/app/**` mobile product routes;
- route-level project loading;
- route-level admin guard for `/admin/**`;
- API calls, ownership-aware data access, and user-visible app states.

### Editor Shell

The editor shell owns:

- Three.js canvas rendering;
- CV candidate overlays;
- confirmed geometry editing;
- 2D/3D camera and furniture manipulation;
- editor bridge messages.

Desktop opens the editor at `/app/workspaces/:projectId/editor`.
Mobile web should prefer `/m/app/workspaces/:projectId/review` unless a future
mobile editor shell is explicitly implemented.

## Hosting And Build Strategy

The final Firebase public root remains `app/build/web`, but it should no longer
be a single Flutter root.

Recommended build layout:

```text
app/build/web/index.html             copied HTML landing for /
app/build/web/m/index.html           copied or generated mobile landing for /m
app/build/web/landing-assets/**      landing CSS, JS, images, Three.js

app/build/web/app/index.html         Flutter Web bootstrap, base href /app/
app/build/web/app/**                 Flutter runtime assets
```

Firebase Hosting rewrite policy should return `app/index.html` for product
routes while preserving the browser URL:

```json
{
  "source": "/app/**",
  "destination": "/app/index.html"
},
{
  "source": "/m/app/**",
  "destination": "/app/index.html"
},
{
  "source": "/admin/**",
  "destination": "/app/index.html"
}
```

Flutter can still see `/m/app/...` and `/admin/...` from the browser URL, while
its runtime assets resolve from `/app/`.

## Design Token Mapping

The HTML landing remains the design source for the production UI. Flutter should
map the HTML tokens into a shared app theme instead of inventing a parallel
palette.

| HTML source | Flutter target |
|---|---|
| `--page-black`, `--rf-bg` | scaffold/background colors |
| `--text-main`, `--text-muted`, `--text-dim` | text color roles |
| `--line-soft`, `--line-strong` | borders/dividers/focus outlines |
| `--rf-grad-primary`, `--rf-grad-brand` | CTA/brand treatments |
| `--rf-dur-*`, `--rf-ease-*` | animation durations/curves |
| 8px radius language | buttons, inputs, panels, repeated cards |

Design direction:

- dark premium surface, restrained blue/teal accents, no toy-like color spread;
- canvas and workspace surfaces are not nested cards;
- project/admin pages can be denser than the landing, but share typography,
  spacing, radius, borders, and motion;
- mobile uses larger touch targets, fewer simultaneous panels, and bottom action
  areas.

## Phase Plan

### Phase 1 - Routing Plan

Goal: document the new route contract, shell boundaries, build packaging,
desktop/mobile split, admin route boundary, and design-token migration strategy.

Targets:

- `docs/design/routing-shell-migration-plan.md`

Validation:

- static document review;
- `git diff --check`.

Commit:

```text
docs(routing): plan html landing and app route shells
```

### Phase 2 - HTML Landing Entrypoints

Goal: make the approved HTML landing the real `/` and `/m` web entry while
preserving its CSS, JavaScript, Three.js, pointer, scroll, ripple, and reveal
interactions.

Targets:

- landing source under an app-owned web packaging directory;
- landing assets copied from `docs/design/assets/`,
  `docs/design/system/`, and `docs/design/landing.html`;
- CTA links updated to `/app`, `/m/app`, or `/app/projects`;
- build/package script for landing assets if needed.

Validation:

- desktop `/` browser render;
- mobile `/m` browser render;
- console issue check;
- landing CTA route link check.

Commit:

```text
feat(web): serve html landing entrypoints
```

### Phase 3 - Flutter Route Shells

Goal: introduce explicit Flutter route handling for `/app`, `/m/app`, and
`/admin` without splitting auth, API, or repository code.

Targets:

- add `go_router` or an equivalent route table;
- replace `MaterialApp(home: AuthGate)` with router-based app startup;
- create route shells for desktop app, mobile app, and admin;
- keep auth/profile sync as a route guard or shell wrapper;
- update Firebase Hosting rewrites.

Validation:

- `flutter analyze`;
- `flutter test` where available;
- browser route reload checks for `/app`, `/m/app`, and `/admin`;
- unauthenticated route behavior check.

Commit:

```text
feat(app): add product and admin route shells
```

### Phase 4 - Project Screens Split

Goal: split the current combined `ProjectWorkspaceScreen` into separate route
targets for app home, project list, and workspace detail.

Targets:

- `AppHomeScreen`;
- `ProjectsScreen`;
- `WorkspaceScreen(projectId)`;
- shared project loading and empty/error states;
- route navigation replacing local `ProjectWorkspaceScreen` selection where
  appropriate.

Validation:

- `flutter analyze`;
- `flutter test` where available;
- desktop `/app`, `/app/projects`, `/app/workspaces/:projectId` browser checks;
- direct reload behavior for project routes.

Commit:

```text
feat(app): split home projects and workspace routes
```

### Phase 5 - Mobile Workflow Routes

Goal: make mobile web a functional capture/status/review flow, not just a narrow
desktop layout.

Targets:

- `/m/app`;
- `/m/app/projects`;
- `/m/app/workspaces/:projectId`;
- `/m/app/workspaces/:projectId/capture`;
- `/m/app/workspaces/:projectId/status`;
- `/m/app/workspaces/:projectId/review`;
- mobile-first bottom actions, large touch targets, and guided capture emphasis.

Validation:

- `flutter analyze`;
- browser checks at 390px and 768px;
- upload/capture/status/review state render checks;
- reduced-motion behavior check where motion is introduced.

Commit:

```text
feat(mobile): add mobile workspace workflow routes
```

### Phase 6 - Admin Route Guard

Goal: move admin access from an in-workspace button flow to route-level
authorization at `/admin/**`.

Targets:

- `/admin`;
- `/admin/jobs`;
- `/admin/jobs/:jobId`;
- `/admin/retries`;
- `/admin/audit`;
- admin denied/stale-role/unauthenticated states;
- reuse existing admin diagnostics/data widgets where possible.

Validation:

- `flutter analyze`;
- admin route reload check;
- normal user denied state;
- admin user allowed state where local setup permits;
- no normal workspace route exposes admin data.

Commit:

```text
feat(admin): move admin console to guarded routes
```

### Phase 7 - Unified Production UI Design

Goal: apply the landing HTML visual language consistently across Flutter
product routes and the editor shell.

Targets:

- shared Flutter theme/tokens;
- app home/projects/workspace/admin surfaces;
- mobile shell controls;
- editor command bar and supporting panels;
- CSS token cleanup in `editor/src/style.css` where needed.

Validation:

- `flutter analyze`;
- `npm run build` in `editor` when editor CSS/TS changes;
- screenshots for `/`, `/m`, `/app/projects`, `/m/app/.../capture`,
  `/app/.../editor`, and `/admin`;
- visual comparison against `docs/design/landing.html` and relevant screen
  mockups.

Commit:

```text
design(ui): unify app routes with landing system
```

### Phase 8 - End-To-End Route Verification

Goal: verify the full route map, build packaging, reload behavior, and visual
continuity after all phases.

Targets:

- Firebase Hosting config;
- build/package commands;
- route smoke test notes;
- any small fixes discovered by route reload or browser checks.

Validation:

- full Flutter web build;
- editor build if editor changed;
- route reload checks:
  `/`, `/m`, `/app`, `/app/projects`,
  `/app/workspaces/:projectId`, `/m/app/workspaces/:projectId/capture`,
  `/admin`;
- no fresh browser console errors for the checked routes.

Commit:

```text
chore(web): verify routing shells and build packaging
```

## Dependencies And Ordering Rules

- Phase 2 must happen before removing the Flutter landing from the app startup.
- Phase 3 must happen before deep-linkable project/admin routes can be reliable.
- Phase 4 should preserve existing project API and repository behavior.
- Phase 5 should reuse project/workspace data models from Phase 4.
- Phase 6 should not weaken admin authorization; it should only move the guard
  from a button interaction to route-level access.
- Phase 7 should avoid broad behavioral changes unless required for consistent
  screen composition.
- Phase 8 is validation and packaging hardening, not a new feature phase.

## Non-Negotiable Product Constraints

- Flutter owns auth, project/workspace screens, upload/status UI, admin UI,
  accessible non-canvas controls, and API calls.
- Three.js/editor owns source-image alignment, OpenCV overlays, geometry
  handles, 2D/3D rendering, furniture manipulation, and spatial validation.
- Mobile web is capture/status/review-first; desktop remains precision
  editor-first.
- Candidate geometry and confirmed geometry stay visually and structurally
  distinct.
- Persisted reconstruction statuses remain:
  `created`, `uploading`, `processing`, `review_required`, `succeeded`,
  `failed`, `timeout`, `cancelled`, `retrying`.
- `review_required` displays to users as `Needs review`.
- API JSON remains `snake_case`; editor bridge fields remain `camelCase`.
- `/admin/**` requires admin authorization distinct from normal authenticated
  user access.
