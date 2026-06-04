# RoomForge Routing Shell Validation Report

Date: 2026-06-04
Branch: `codex/landing-routing-restructure`

This report records the completed routing-shell migration slice for the HTML
landing, Flutter product app, mobile web app, and guarded admin routes.

## Completed Commits

```text
0670e6f docs(routing): plan html landing and app route shells
8bf7f61 feat(web): serve html landing entrypoints
3f53763 feat(app): add product and admin route shells
95f1be0 feat(app): split home projects and workspace routes
9d22e05 feat(mobile): add mobile workspace workflow routes
c45723e feat(admin): move admin console to guarded routes
```

## Implemented Route Contract

```text
/                                      HTML landing
/m                                     mobile HTML landing

/app                                   Flutter app home
/app/projects                          project list
/app/workspaces/:projectId             project workspace

/m/app                                 mobile app home
/m/app/projects                        mobile project list
/m/app/workspaces/:projectId           mobile workspace overview
/m/app/workspaces/:projectId/capture   mobile capture
/m/app/workspaces/:projectId/status    mobile reconstruction status
/m/app/workspaces/:projectId/review    mobile review handoff

/admin                                 admin dashboard
/admin/jobs                            admin job list
/admin/jobs/:jobId                     admin job detail
/admin/jobs/:jobId/retry               admin retry focus
/admin/jobs/:jobId/audit               admin audit focus
/admin/retries                         admin retry queue
/admin/audit                           admin audit target prompt
```

## Validation Performed

- `dart format app/lib/main.dart`
- `flutter analyze`
- `flutter test`
- `app/tool/build_web_shells.sh --dart-define=ROOMFORGE_LOCALE=ko`
- Static route shell checks with a local fallback server:
  - `/admin`
  - `/admin/jobs`
  - `/admin/retries`
  - `/admin/audit`
  - `/admin/jobs/admin-smoke/retry`
  - `/admin/jobs/admin-smoke/audit`
- In-app browser check for `/admin/jobs/admin-smoke/audit`:
  - browser path stayed `/admin/jobs/admin-smoke/audit`
  - base href was `/app/`
  - Flutter bootstrap script was present
  - Flutter host appeared after bootstrap
  - document title became `RoomForge`

Known build warnings remain unchanged from the previous phases:

- Flutter Wasm dry run reports `dart:html` usage in the web app and IndexedDB
  draft store.
- Flutter reports the existing CupertinoIcons font warning.

## Boundary Decisions

- The approved HTML landing remains the production landing shell for `/` and
  `/m`; Flutter does not own the landing page.
- Flutter owns authenticated product routes under `/app/**` and `/m/app/**`.
- Mobile web is route-separated as capture/status/review workflow surfaces,
  not a narrow desktop editor.
- `/admin/**` is outside `/app/**` and remains protected by a distinct admin
  authorization check before diagnostics data is shown.
- Admin job detail, retry, and audit routes reuse the existing Firebase admin
  repository queries instead of adding a second admin data access path.

## Remaining Work

The original plan's visual-unification phase is still a separate follow-up:

- map the HTML landing tokens into a shared Flutter theme;
- align app home, projects, workspace, mobile controls, and admin surfaces with
  the landing system;
- apply the same visual language to editor command bars and supporting panels;
- run screenshot comparison against `docs/design/landing.html` and the screen
  mockups.

There is also pre-existing uncommitted design/UI WIP in the working tree. It was
intentionally not included in these routing commits.
