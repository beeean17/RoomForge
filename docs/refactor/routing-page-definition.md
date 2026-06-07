# RoomForge Routing Page Definition

This document defines the route inventory for the React web / native mobile
refactor. It supersedes earlier Flutter-web ownership assumptions for routing,
admin UI, and desktop editor surfaces. Firebase data contracts, status names,
security rules, and editor bridge field casing remain governed by the Firebase
refactor docs unless this document says otherwise.

## Architecture Decision

RoomForge now has three product surfaces:

```text
Desktop web   = primary workspace, reconstruction review, React editor, admin
Mobile web    = responsive limited shell for viewing/status/preview only
Mobile native = camera guide, guided capture, upload, native capture workflow
```

The mobile web surface must not pretend to be a full editor or camera app. When
a mobile browser reaches a locked workflow, it should show a clear handoff:

- open on desktop web for CV correction, reconstruction review, or editor work;
- open the mobile app for guided camera capture and upload;
- stay on mobile web for project list, status, and preview.

## Route Ownership

| URL family | Owner after refactor | Phase | Notes |
|---|---|---:|---|
| `/` | Static/React landing | 0 | Approved landing remains the public first paint and homepage. |
| `/projects/**` | React web app | 0-1 | Authenticated product workspace. Mobile viewport renders limited mode. |
| `/admin/**` | React admin app | 2 | Admin is outside the product workspace and uses separate authorization. |
| `/legacy/**` | Flutter web legacy | 0-4 | Temporary fallback for existing Flutter web routes. |
| Native deep links | Flutter mobile app | 3 | Capture-first app routes, not Firebase Hosting routes. |

Product routes intentionally do not use an `/app` prefix after the refactor.
The root route stays the landing page, and signed-in calls to action continue
into `/projects` or a specific project route. Mobile web is not a separate full
product implementation; it is the same route family with capability gates.
`/app/**` and `/m/app/**` should exist only as temporary redirects or legacy
fallbacks during migration.

## Host And Runtime Surface Routing

`www` and `m` hosts may exist, but they must not create separate route tables.
They serve the same React web build and preserve the same path structure.

| Host | Canonical role | Route table | Runtime surface | Notes |
|---|---|---|---|---|
| `roomforge.com` | Apex redirect | Same as `www` | Determined after redirect | Prefer redirect to `www.roomforge.com`. |
| `www.roomforge.com` | Canonical web | `/`, `/projects/**`, `/admin/**` | Desktop web unless mobile detected | Primary SEO/canonical host. |
| `m.roomforge.com` | Mobile alias | Same paths as `www` | Mobile web | Capability gates are active by default. |
| Preview/local hosts | Development | Same paths as `www` | Derived from viewport/override | Used for local validation and Firebase preview channels. |

Examples:

```text
https://www.roomforge.com/projects/demo/status
https://m.roomforge.com/projects/demo/status
```

Both URLs resolve to the same route and page model. The second one runs in
mobile-web mode. Do not create path variants such as `/m/projects/...` or
`/m/app/...` for final routes.

Runtime surface selection:

```text
if host starts with "m.":
  surface = mobile-web
else if viewport/user-agent is mobile:
  surface = mobile-web
else:
  surface = desktop-web
```

Host detection is a default, not a security boundary. Authorization and data
access must come from Firebase Auth, Firestore Rules, Storage Rules, and
Callable Function checks. Mobile locks are UX capability gates only.

Canonical URL policy:

- canonical product URLs use `www.roomforge.com`;
- `m.roomforge.com` keeps the same path and may set canonical metadata pointing
  to `www`;
- `/app/**`, `/m/app/**`, and `/m/projects/**` are migration-only redirects;
- admin routes should prefer `www`; mobile admin access renders a locked
  desktop-guidance page instead of a second admin UI.

## Public And Auth Routes

| Route | Page | Owner | Auth | Mobile web policy |
|---|---|---|---|---|
| `/` | Public landing | Static/React landing | Public | Allowed |
| `/login` | Auth callback / explicit sign-in | React web | Public -> auth | Allowed |
| `/projects` | My projects | React web | Required | Allowed |
| `/projects/:projectId` | Project overview | React web | Required + owner/admin | Allowed |

There is no final `/app` route. The homepage remains `/`, and the authenticated
product entry is `/projects`.

There is no `/projects/new` route. Project creation provisions the project and
navigates directly to `/projects/:projectId/workspace`, where naming, photo
upload, and capture handoff happen. Desktop cannot capture, so the workspace
offers photo upload and a mobile-app capture handoff instead of a separate
create modal.

## Project Workflow Routes

| Route | Page | Owner | Desktop web | Mobile web | Native mobile |
|---|---|---|---|---|---|
| `/projects/:projectId/room` | Room dimensions | React web | Full | View-only or locked edit | Optional later |
| `/projects/:projectId/source` | Source images / upload status | React web | Upload/select | View-only, app handoff | Guided upload |
| `/projects/:projectId/status` | Reconstruction status | React web | Full | Full status | Full status |
| `/projects/:projectId/editor` | 2D/3D editor (floor plan + correction + furniture) | React editor | Full | Locked, desktop handoff | Viewer only |
| `/projects/:projectId/recovery` | Draft/sync recovery | React web | Full | Limited recovery notices | Native draft handling |

Route names use `projects/:projectId` instead of the current
`workspaces/:projectId` path.

`/projects/:projectId` (project overview) **is** the project hub: it shows the
pipeline, preview, source images, status, and next-step actions. There is no
separate `/projects/:projectId/workspace` route — overview and workspace are
merged into `/projects/:projectId`. The rows above are sections that live under
that hub (`/projects/:projectId/source`, `/status`, `/editor`, ...).

Reconstruction produces a best-effort editable model; there is **no separate
candidate-review step**. The metric **floor plan and corrections happen inside
the editor** (`/projects/:projectId/editor`), so there are no
`/projects/:projectId/review` or `/projects/:projectId/floor-plan` routes. The
project pipeline is: 소스(source) → 재구성(status) → 편집(editor).

There is **no export stage and no layouts stage**. Export is a single action
button in the editor's 2D toolbar that saves the floor plan as an image (PNG);
there is no `/projects/:projectId/export` route. The editor auto-saves a single
state, so there is no `/projects/:projectId/layouts` save/load route.

## Editor Routes

| Route | Page | Owner | Notes |
|---|---|---|---|
| `/projects/:projectId/editor` | Precision 2D/3D editor (floor plan + correction + furniture) | React editor | React + react-three-fiber target. Uses the postMessage bridge contract. Includes the metric 2D floor-plan view/mode and geometry correction. |
| `/legacy/editor/:projectId` | Legacy editor fallback | Flutter web legacy | Temporary only. |

The editor must not import Firebase SDKs or own persistence. It receives project
state and emits bridge messages; the web app owns auth, loading, saving, and
permission handling.

## Admin Routes

| Route | Page | Owner | Auth |
|---|---|---|---|
| `/admin` | Admin dashboard | React admin | Admin only |
| `/admin/jobs` | Job search/list | React admin | Admin only |
| `/admin/jobs/:jobId` | Job detail | React admin | Admin only |
| `/admin/jobs/:jobId/retry` | Retry operation | React admin + Callable Function | Admin only |
| `/admin/jobs/:jobId/audit` | Job audit trail | React admin + Callable Function | Admin only |
| `/admin/audit` | Global audit | React admin + Callable Function | Admin only |
| `/admin/access-denied` | Admin guard result | React admin | Signed-in non-admin |

Mobile web should not expose admin workflows. A mobile browser that reaches
`/admin/**` should render an admin-unavailable page with desktop guidance.

## Mobile Native Deep Links

Native routes are app routes, not Hosting routes. Web pages can generate these
handoffs when the app is installed and fall back to install/open guidance.

| Deep link | Native page | Purpose |
|---|---|---|
| `roomforge://projects` | Project list | Continue from mobile app. |
| `roomforge://projects/:projectId` | Project status | Project overview/status. |
| `roomforge://projects/:projectId/capture` | Guided camera capture | Camera guide and capture workflow. |
| `roomforge://projects/:projectId/upload` | Upload progress | Native upload and retry. |
| `roomforge://projects/:projectId/preview` | Model preview | Lightweight viewer. |

Native mobile owns real camera guidance. Mobile web must not implement the
camera-guide workflow beyond handoff and status/preview.

## Legacy Route Mapping

During the migration, Flutter web remains available under `/legacy/**`.

| Current route | New route | Legacy fallback |
|---|---|---|
| `/app` | `/projects` | `/legacy/app` |
| `/app/projects` | `/projects` | `/legacy/app/projects` |
| `/app/workspaces/:projectId` | `/projects/:projectId` | `/legacy/app/workspaces/:projectId` |
| `/app/workspaces/:projectId/editor` | `/projects/:projectId/editor` | `/legacy/app/workspaces/:projectId/editor` |
| `/m/app/**` | Matching unprefixed route with mobile gates | `/legacy/m/app/**` |
| `/admin/**` | `/admin/**` | `/legacy/admin/**` |

Redirects should be explicit and tracked. Do not silently map old workspace
paths to project paths inside unrelated feature code.

## Capability Matrix

| Feature | Desktop web | Mobile web | Native mobile |
|---|---|---|---|
| Landing | Yes | Yes | No |
| Sign in | Yes | Yes | Yes |
| Project list | Yes | Yes | Yes |
| Project overview | Yes | Yes | Yes |
| Room dimensions edit | Yes | Locked or view-only | Later |
| Source upload | Yes | App handoff | Yes |
| Guided camera capture | No | Locked | Yes |
| Reconstruction status | Yes | Yes | Yes |
| Geometry correction (in editor) | Yes | Locked | Later/partial |
| 2D/3D editor (incl. floor plan) | Yes | Locked | Viewer only |
| Floor-plan image export (button) | Yes | Locked | No |
| Admin | Yes | Locked | No |

## Phase Entry Criteria

Before coding each phase, the route table for that phase must identify:

- owning app package;
- auth requirement;
- mobile web behavior;
- legacy fallback, if any;
- bridge contract involvement;
- Firebase read/write authority;
- validation URL.

Minimum validation URLs for Phase 0/1:

```text
/
/projects
/projects/demo-project
/projects/demo-project/editor
/admin
/legacy/app
```

The first implementation step should update Hosting targets and route guards to
make this contract visible before moving editor or admin code.
