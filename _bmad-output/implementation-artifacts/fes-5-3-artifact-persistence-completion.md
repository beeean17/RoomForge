---
title: "FES-5.3 Artifact Persistence Completion"
status: "complete"
created: "2026-05-29"
storyId: "FES-5.3"
sourceStory: "docs/refactor/firebase-epics-and-stories.md#story-53-persist-metric-floor-plans-and-artifact-references"
---

# FES-5.3 Artifact Persistence Completion

## Story

As a signed-in user, I want a calibrated metric floor plan and reconstruction
artifacts to be stored, so that room editing and troubleshooting can use
reliable reconstruction outputs.

## Acceptance Criteria

1. Given confirmed image-space geometry and room dimensions are available, when
   calibration succeeds, then a floor plan is stored in meters.
2. Given a floor plan write uses `image_pixels`, when validation runs, then it
   is denied.
3. Given generated artifact refs are stored, when metadata is inspected, then
   `storage_path`, content type, owner/project/job linkage, byte size, checksum,
   and availability state follow the Firebase contract.
4. Given a reconstruction requires review, when the floor plan or job state is
   shown, then the user sees `Needs review`.

## Tasks / Subtasks

- [x] Generate floor-plan artifact payloads from the calibrated result.
  - [x] Create calibration JSON from reference line, image geometry, metric
        geometry, perspective assumptions, unit, and room dimensions.
  - [x] Create debug JSON with project/job/source/confirmed geometry IDs and
        quality metadata.
- [x] Upload generated artifact bytes to the contracted Storage artifact path.
  - [x] Use `users/{uid}/projects/{project_id}/artifacts/{job_id}/{artifact_id}/{filename}`.
  - [x] Include required Storage custom metadata: `owner_uid`, `project_id`,
        `job_id`, `artifact_id`, and `uploaded_by_uid`.
  - [x] Compute and persist `byte_size` and `sha256_hex`.
- [x] Persist artifact refs on the saved `floor_plans` document.
  - [x] Keep `coordinate_space: "meters"` on floor plans.
  - [x] Keep artifact refs private and contract-valid.
- [x] Add focused tests for artifact upload/ref persistence.
- [x] Run validation for app, editor boundary, and Firebase rules touched by
      FES-5.3.

## Dev Notes

- Flutter owns Firebase Auth, Firestore, Storage, persistence, and artifact
  uploads. The editor must not import Firebase or call Storage directly.
- Existing model validation already enforces `FirebaseFloorPlan.coordinateSpace`
  as `meters` and validates `FirebaseArtifactRef.storagePath`, content type,
  byte size, and project/job linkage.
- Existing Storage rules allow owner writes to artifact paths only when the
  project and reconstruction job exist, content type is allowed, size is within
  limits, and required metadata matches the path.
- Current gap from `fes-implementation-validation-2026-05-28.md`: `persistFloorPlanResult`
  saves metric floor plans but does not upload generated artifact bytes or
  attach artifact refs from the OpenCV/floor-plan flow.
- Scope stays inside Firebase default path. Do not broaden admin UI behavior in
  this story.

## Expected Files

- `app/lib/src/projects/firebase_project_api.dart`
- `app/test/src/projects/firebase_project_api_test.dart`
- `_bmad-output/implementation-artifacts/fes-5-3-artifact-persistence-completion.md`
- Optional completion report under `_bmad-output/implementation-artifacts/`

## Validation Plan

- `flutter analyze` from `app/`
- `flutter test` from `app/`
- `npm run check:editor-firebase-boundary`
- `npm run test:firebase-rules:floor-plans`
- `npm run test:firebase-rules:admin-storage`
- `npm run typecheck` and `npm run build` from `editor/` if editor bridge is touched

## Dev Agent Record

### Debug Log

- 2026-05-29: Created story from FES-5.3 after implementation validation
  identified artifact persistence as the highest-priority partial story.
- 2026-05-29: Implemented calibration/debug JSON artifact generation and
  upload before floor-plan persistence.
- 2026-05-29: Added unit coverage for successful artifact upload/ref
  persistence and upload-failure rollback of floor-plan metadata.
- 2026-05-29: Initial `npm run test:firebase-rules:admin-storage` failed under
  sandbox port/config restrictions; reran with approved escalation and passed.
- 2026-05-29: `docs/agent/COMPLETION_REPORT.md` referenced by AGENTS.md was
  not present in the repository, so the existing Story 3.7 completion report
  format was used.

### Completion Notes

- `persistFloorPlanResult` now uploads generated `calibration.json` and
  `debug.json` artifacts under the contracted private Storage path before
  saving the metric floor plan.
- Saved floor plans now include JSON artifact refs with `storage_path`,
  `content_type`, `byte_size`, `sha256_hex`, created timestamp, and
  project/job/artifact linkage.
- Artifact upload failures map to `artifact_upload_failed` and prevent
  floor-plan metadata from being saved, avoiding persisted refs to missing
  artifacts.
- If floor-plan metadata persistence fails after artifact upload, the uploaded
  artifacts are deleted on a best-effort path before the original save error is
  rethrown.
- Editor code was not touched; Firebase access remains inside the Flutter app
  boundary.

### File List

- `app/lib/src/projects/firebase_project_api.dart`
- `app/lib/src/projects/firebase_source_image_upload.dart`
- `app/test/src/projects/firebase_project_api_test.dart`
- `_bmad-output/implementation-artifacts/fes-5-3-artifact-persistence-completion.md`
- `_bmad-output/implementation-artifacts/fes-5-3-completion-report-2026-05-29.md`

### Change Log

- Added generated floor-plan artifact payloads and upload/ref persistence.
- Added Storage object deletion to the existing Firebase byte uploader for
  best-effort cleanup after post-upload floor-plan save failures.
- Added Firebase Project API tests for uploaded JSON payloads, artifact
  metadata, checksum/size refs, `Needs review` quality display, upload failure
  rollback, and post-upload save-failure cleanup.
- Validated Flutter app checks, editor Firebase boundary, and Firebase
  floor-plan/admin-storage rules.
