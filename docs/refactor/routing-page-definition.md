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
| `/` | Static landing | 0 | Approved HTML landing remains the public first paint. |
| `/m` | Static landing alias | 0 | Optional mobile landing alias; may redirect to `/`. |
| `/app/**` | React web app | 0-1 | Authenticated product shell. Mobile viewport renders limited mode. |
| `/admin/**` | React admin app | 2 | Admin is outside `/app` and uses separate authorization. |
| `/legacy/**` | Flutter web legacy | 0-4 | Temporary fallback for existing Flutter web routes. |
| Native deep links | Flutter mobile app | 3 | Capture-first app routes, not Firebase Hosting routes. |

`/app/**` is a single responsive React router. Mobile web is not a separate
full product implementation; it is the same route family with capability gates.
`/m/**` should be used only for the landing alias or temporary compatibility
redirects, not as a second complete product route tree.

## Public And Auth Routes

| Route | Page | Owner | Auth | Mobile web policy |
|---|---|---|---|---|
| `/` | Public landing | Static HTML | Public | Allowed |
| `/m` | Mobile landing alias | Static HTML | Public | Allowed |
| `/login` | Auth callback / explicit sign-in | React web | Public -> auth | Allowed |
| `/app` | Signed-in main landing | React web | Required | Allowed |
| `/app/projects` | My projects | React web | Required | Allowed |
| `/app/projects/new` | Create project modal route | React web | Required | Allowed |
| `/app/projects/:projectId` | Project overview | React web | Required + owner/admin | Allowed |

The main logged-in route is `/app`, not `/app/projects`. `/app/projects` is the
project list and lookup space.

## Project Workflow Routes

| Route | Page | Owner | Desktop web | Mobile web | Native mobile |
|---|---|---|---|---|---|
| `/app/projects/:projectId/workspace` | Project workspace | React web | Full | Limited summary | Lightweight project shell |
| `/app/projects/:projectId/room` | Room dimensions | React web | Full | View-only or locked edit | Optional later |
| `/app/projects/:projectId/source` | Source images / upload status | React web | Upload/select | View-only, app handoff | Guided upload |
| `/app/projects/:projectId/status` | Reconstruction status | React web | Full | Full status | Full status |
| `/app/projects/:projectId/review` | CV candidate review | React web + editor bridge | Full | Locked, desktop handoff | Partial/later |
| `/app/projects/:projectId/floor-plan` | Floor plan review | React web + editor bridge | Full | Preview only | Preview only |
| `/app/projects/:projectId/editor` | 2D/3D editor | React editor | Full | Locked, desktop handoff | Viewer only |
| `/app/projects/:projectId/layouts` | Save/load layout | React web | Full | Preview/recent only | Preview/recent only |
| `/app/projects/:projectId/export` | Export JSON | React web | Full | Locked or download-only | Locked |
| `/app/projects/:projectId/recovery` | Draft/sync recovery | React web | Full | Limited recovery notices | Native draft handling |

Route names use `projects/:projectId` instead of the current
`workspaces/:projectId` path. "Workspace" becomes a page under a project, not
the primary entity path.

## Editor Routes

| Route | Page | Owner | Notes |
|---|---|---|---|
| `/app/projects/:projectId/review` | CV candidate review | React web + React editor shell | Uses existing postMessage bridge contract. |
| `/app/projects/:projectId/floor-plan` | Metric floor plan review | React web + React editor shell | Shows confirmed meter-space model. |
| `/app/projects/:projectId/editor` | Precision 2D/3D editor | React editor | React + react-three-fiber target. |
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
| `/app` | `/app` | `/legacy/app` |
| `/app/projects` | `/app/projects` | `/legacy/app/projects` |
| `/app/workspaces/:projectId` | `/app/projects/:projectId/workspace` | `/legacy/app/workspaces/:projectId` |
| `/app/workspaces/:projectId/editor` | `/app/projects/:projectId/editor` | `/legacy/app/workspaces/:projectId/editor` |
| `/m/app/**` | `/app/**` limited mobile mode | `/legacy/m/app/**` |
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
| CV candidate review | Yes | Locked | Later/partial |
| Geometry correction | Yes | Locked | Later/partial |
| 2D/3D editor | Yes | Locked | Viewer only |
| Layout save/load | Yes | Preview/recent only | Preview/recent only |
| Export | Yes | Locked or download-only | No |
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
/app
/app/projects
/app/projects/demo-project
/app/projects/demo-project/workspace
/app/projects/demo-project/editor
/admin
/legacy/app
```

The first implementation step should update Hosting targets and route guards to
make this contract visible before moving editor or admin code.
