# RoomForge

English | [Korean](README_KR.md)

RoomForge is a web-first room reconstruction and furniture planning application.
It uses a practical computer vision workflow to turn room photos and known room
dimensions into an editable metric floor plan and a 2D/3D planning workspace.

This README is staged in `private/` first so the project documentation can be
reviewed before it is promoted to the public repository root.

## What RoomForge Does

RoomForge helps a user answer a concrete spatial question: "Will this furniture
arrangement work in my real room?"

The product flow is:

1. Sign in with Google.
2. Create or open a room project.
3. Upload or capture source room images.
4. Enter known room dimensions.
5. Use OpenCV-assisted detection to propose room geometry.
6. Let the user correct the detected geometry.
7. Calibrate the result into metric space.
8. Inspect the floor plan and room scene in a 2D/3D editor.
9. Add, move, rotate, resize, and delete proxy furniture.
10. Save or export the resulting layout.

The key product principle is control over automation. Computer vision output is
treated as a candidate, not as guaranteed truth. The user can correct geometry
and furniture placement, which keeps the workflow useful even when the photo is
imperfect.

## Why This Exists

RoomForge was created for people who are moving, rearranging a room, or trying
to plan a small living space before doing the physical work. Instead of moving a
bed, desk, wardrobe, or sofa repeatedly to test size and placement, the user can
simulate the arrangement first and use that plan as the basis for setting up the
actual room.

The expected demand is strongest for spaces where layout mistakes are expensive
in daily life: studio apartments, dorm rooms, small bedrooms, and other compact
rooms. In those environments, furniture size, walking paths, storage access, and
usable desk or sleep space all depend on the layout. RoomForge is built around
that practical need for room layout simulation.

## Current Architecture

RoomForge is organized as a multi-surface workspace:

```text
app/       Flutter app shell, mobile/capture path, legacy web support
web/       React + Vite desktop web workspace, landing, editor host, admin UI
editor/    TypeScript + Vite + Three.js/OpenCV.js spatial editor
server/    Legacy FastAPI files, pending relocation to legacy/reference space
packages/  Shared schemas, tokens, and cross-package utilities
docs/      Product, refactor, design, and validation documentation
private/   Private draft workspace, not part of the deployed app
```

The current default backend direction is Firebase:

- Firebase Auth for identity.
- Cloud Firestore for project, geometry, reconstruction, layout, and admin data.
- Cloud Storage for source images and generated artifacts.
- Firebase Security Rules for owner/admin access control.
- Local draft/cache state where the UI needs recovery behavior.

The legacy FastAPI/Oracle path remains in the repository for reference and
explicit `legacy_api` work only. The current `server/` tree should be treated as
legacy FastAPI code that is expected to move into a legacy/reference location,
not as RoomForge's active backend.

## Boundary Rules

The main implementation boundaries are:

- App/web surfaces own authentication, routing, permissions, persistence,
  recovery states, and user-facing workflows.
- The editor owns Three.js rendering, OpenCV overlays, geometry handles,
  furniture manipulation, camera controls, and spatial validation.
- The editor must not import Firebase SDKs or read/write Firestore or Storage
  directly.
- Candidate geometry and user-confirmed geometry must stay separate in state,
  persistence, and exports.
- Persisted Firebase and export fields use `snake_case`.
- Editor bridge payloads use `camelCase`.
- Persisted reconstruction statuses use exactly:
  `created`, `uploading`, `processing`, `review_required`, `succeeded`,
  `failed`, `timeout`, `cancelled`, and `retrying`.
- User-facing UI displays `review_required` as `Needs review`.

## Private Draft Note

`private/` is a separate Git submodule and is not part of the deployed app. This
README is being drafted here only as a review step before the public README is
updated.

Do not move secrets, local `.env` files, real room photos, private Firebase
credentials, or personal test artifacts into the public root repository. If
private submodule changes need to be published, commit and push the `private`
submodule first, then update the root repository submodule pointer.

## Quick Start

Run commands from the RoomForge repository root unless a command says otherwise.

```bash
cd /Users/yoon/Documents/github/RoomForge
```

Install package dependencies as needed:

```bash
npm install
(cd web && npm install)
(cd editor && npm install)
(cd app && flutter pub get)
```

The legacy server is optional and should be prepared only when validating
explicit archived server or `legacy_api` behavior:

```bash
cd server
python3 -m venv .venv
.venv/bin/python -m pip install -e '.[dev]'
cd ..
```

## Validation

Use package-level checks for the public project surface:

```bash
(cd web && npm run build)
(cd editor && npm run typecheck)
(cd app && flutter analyze)
```

Use Firebase CLI checks from `app/` when Firestore, Storage, Hosting, or
emulator configuration changes:

```bash
cd app
firebase emulators:start --only auth,firestore,storage,hosting
```

## Demo Screenshots

README demo screenshots should live in the repository root `images/` directory.
The current demo set shows the main web flow and the editor's 2D/3D workspace.

| Landing | Login |
| --- | --- |
| ![RoomForge landing page](images/demo-landing.png) | ![RoomForge login page](images/demo-login.png) |

| Projects | Reconstruction Review |
| --- | --- |
| ![RoomForge projects dashboard](images/demo-projects.png) | ![RoomForge reconstruction review workflow](images/demo-reconstruction1.png) |

| 2D Editor | 3D Editor |
| --- | --- |
| ![RoomForge 2D editor view](images/demo-editor1.png) | ![RoomForge 3D editor view](images/demo-editor2.png) |

## Deployment Plan

RoomForge's web deployment target is Firebase Hosting. The production site name
is not fixed in this draft yet; add the deployed URL here after the first
deployment.

```text
Production site: TBD
```

Planned web deployment flow:

```bash
cd /Users/yoon/Documents/github/RoomForge
(cd web && npm run build)
(cd app && firebase deploy)
```

The Firebase config currently lives under `app/`, and `app/firebase.json`
publishes the React web build from `../web/dist`.

RoomForge also plans to ship an Android build through GitHub Releases. Build the
Android release artifact from the Flutter app, then attach it to the matching
GitHub Release.

```bash
cd /Users/yoon/Documents/github/RoomForge/app
flutter build apk --release
```

Default APK output:

```text
app/build/app/outputs/flutter-apk/app-release.apk
```

If a Play Store-style bundle is needed later:

```bash
cd /Users/yoon/Documents/github/RoomForge/app
flutter build appbundle --release
```

Default app bundle output:

```text
app/build/app/outputs/bundle/release/app-release.aab
```

The GitHub Release title, tag, release notes, and attached artifacts should be
decided at release time.

## Important Documentation

- Root README: [../README.md](../README.md)
- Firebase refactor index: [../docs/refactor/README.md](../docs/refactor/README.md)
- Firebase target architecture:
  [../docs/refactor/firebase-target-architecture.md](../docs/refactor/firebase-target-architecture.md)
- Routing page definition:
  [../docs/refactor/routing-page-definition.md](../docs/refactor/routing-page-definition.md)
- Product PRD: [../docs/product/prd.md](../docs/product/prd.md)
- Design index: [../docs/design/README.md](../docs/design/README.md)

## Development Notes

- Keep product changes scoped to the owning package.
- Run the smallest validation loop that proves the changed boundary.
- For Firebase or security work, verify Firestore/Storage Rules, not just UI
  behavior.
- For CV/editor work, verify runtime code paths in `editor/`, not only product
  documentation.
