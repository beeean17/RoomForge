# RoomForge Firebase Backend Refactor Plan

## Summary

- Refactor RoomForge to make Firebase the default backend: Firebase Auth, Firestore, Cloud Storage for Firebase, Firebase Security Rules, and local IndexedDB draft/cache.
- Keep Flutter as the app shell and TypeScript/Three.js/OpenCV.js as the editor. Do not migrate to React.
- Remove FastAPI/Oracle from the default app path. Keep `server/` as inactive legacy/reference code only.
- Treat this as a refactor initiative, not a continuation of the old story queue, because the current implementation appears beyond the stale Story 4.1 queue state.

## Architecture And Interfaces

- Replace `ProjectApi` / `AdminApi` HTTP-first access with repository-style Firebase implementations. Default backend mode is `firebase`; optional `legacy_api` may remain behind an explicit build/config flag.
- Move persisted IDs from Oracle integer IDs to Firestore string document IDs in app models, editor bridge payload references, layouts, jobs, and source image metadata.
- Use Firestore persisted field names in `snake_case` to minimize existing model churn and preserve current JSON/export conventions.
- Firestore structure:
  - `users/{uid}`: Firebase UID, email/display name, role, timestamps.
  - `projects/{project_id}`: `owner_uid`, name, description, latest references, timestamps.
  - `projects/{project_id}/source_images/{source_image_id}`: metadata and `storage_path`.
  - `projects/{project_id}/room_dimensions/current`: metric room dimensions.
  - `projects/{project_id}/reconstruction_jobs/{job_id}`: allowed status values only.
  - `projects/{project_id}/opencv_results/{result_id}`: candidate geometry and CV metadata.
  - `projects/{project_id}/confirmed_geometries/{geometry_id}`: user-confirmed geometry.
  - `projects/{project_id}/floor_plans/{floor_plan_id}`: calibrated meter-space floor plan.
  - `projects/{project_id}/layouts/{layout_id}`: room, source metadata, floor plan, editor scene, furniture.
- Cloud Storage paths:
  - `users/{uid}/projects/{project_id}/source-images/{source_image_id}/{filename}`.
  - Keep JPEG, PNG, and WebP only, with a 10 MB maximum file size.
- Keep candidate geometry and confirmed geometry in separate Firestore collections. Geometry payloads must still declare coordinate space: image pixels before calibration, meters after calibration.
- Replace 5-second API polling with Firestore document streams where practical.
- Persisted reconstruction statuses remain: `created`, `uploading`, `processing`, `review_required`, `succeeded`, `failed`, `timeout`, `cancelled`, `retrying`.

## Implementation Changes

- Add Flutter Firebase packages for Firestore and Storage, update Firebase emulator config for Auth, Firestore, and Storage, and keep Firebase config values environment-driven.
- On sign-in, upsert `users/{uid}` from Firebase Auth. No separate Oracle user mapping remains in the default path.
- Project CRUD becomes direct Firestore reads/writes filtered by `owner_uid == request.auth.uid`.
- Upload flow stores the image file in Cloud Storage first, then writes source image metadata to Firestore. Preserve SHA-256, dimensions, size, content type, retention status, and project linkage.
- Reconstruction flow creates and updates job/result/geometry/floor-plan docs client-side after OpenCV.js runs in the editor worker. Flutter remains the only Firebase persistence owner; editor rendering modules should not talk directly to Firestore.
- Save/load/export use Firestore layout docs. JSON export is generated client-side from the latest saved layout and still warns when reconstruction status is `review_required`.
- Admin UI becomes Firebase-backed:
  - Admin role comes from `users/{uid}.role == "admin"`.
  - Admin reads use collection group queries where needed.
  - Admin retry creates a linked retry job document client-side, gated by admin rules.
- Security rules:
  - Auth required for all user data.
  - Normal users can read/write only projects where `owner_uid == request.auth.uid`.
  - Storage access is restricted to matching `users/{uid}/...` paths.
  - Admin access is distinct from normal user access.
  - Rules enforce allowed status values, image size/type constraints where supported, and no public image/layout reads.
- Documentation updates:
  - Update `architecture.md`, `docs/project-structure.md`, and agent workflow docs so Firebase is primary and Oracle/FastAPI is legacy.
  - Mark old API envelope rules as legacy-only; Firebase direct SDK calls do not use `data/error/meta.request_id`.

## Test Plan

- Flutter:
  - `cd app && flutter analyze`
  - `cd app && flutter test`
  - Add repository tests with fake Firebase-facing repositories for project CRUD, upload metadata, reconstruction status, layout save/load/export, and `review_required` copy.
- Firebase emulator/manual flow:
  - Start Auth, Firestore, and Storage emulators.
  - Verify sign-in, project create/update/delete, image upload metadata, reconstruction job status updates, candidate/confirmed geometry separation, floor plan persistence, layout save/load/export.
  - Verify user A cannot read user B's projects, images, jobs, geometry, or layouts.
  - Verify non-admin cannot access admin screens/data and admin can inspect jobs/artifacts.
- Editor:
  - `cd editor && npm run build`
  - Confirm editor still receives initialization payloads from Flutter and does not import Firebase SDKs.
- Legacy server:
  - No longer required for default validation.
  - Optional compile/test only if `legacy_api` mode is intentionally touched.

## Assumptions And References

- Chosen default: Blaze billing account connected, but implementation stays within free/no-cost quotas and uses budget alerts.
- No Oracle-to-Firebase data migration is required for existing demo data. Demo projects can be recreated in Firebase.
- FastAPI/Oracle code is not deleted in this refactor; it is disabled from the default app path and documented as legacy.
- Firestore free quota reference: [Firebase Firestore pricing](https://firebase.google.com/docs/firestore/pricing).
- Cloud Storage for Firebase currently requires Blaze for new setup: [Cloud Storage web start](https://firebase.google.com/docs/storage/web/start).
- Firebase plan behavior reference: [Firebase pricing plans](https://firebase.google.com/docs/projects/billing/firebase-pricing-plans).
