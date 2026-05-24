# Story 3.6: Reconstruction Quality, Failure Guidance, and Retry

## Status

review

## Story

As a user,
I want reconstruction quality states, failure reasons, and retry options,
So that I can recover when OpenCV cannot produce a trustworthy result.

## Acceptance Criteria

- Given reconstruction confidence is weak or needs review, when the result is shown, then the UI displays a visible warning before save or export is allowed.
- Given reconstruction fails, when I view the result, then I see a failure reason for blur, low light, hidden boundaries, occlusion, distortion, unsupported image, OpenCV failure, invalid geometry, or calibration failure where known.
- Given I correct input or upload a new image, when I retry reconstruction, then a retry attempt is linked to the original job and prior failure history is preserved.

## Tasks / Subtasks

- [x] Add reconstruction retry API linked to the original job.
- [x] Preserve original job transition history while creating a retry attempt.
- [x] Add tests for retry linkage and cross-user non-disclosure.
- [x] Add Flutter warning/failure guidance for `review_required` and failed jobs.
- [x] Add Flutter retry action for terminal or review-required jobs.
- [x] Add editor quality warning event with recovery actions.
- [x] Update documentation and BMAD sprint status.

## Dev Notes

- Full admin retry/failure operations are Epic 6; this story provides the user-facing retry boundary.
- The persisted status remains `review_required`; UI label remains "Needs review".

## Dev Agent Record

### Debug Log

- Added `POST /room-projects/{project_id}/reconstruction-jobs/{job_id}/retry`.
- Added retry job creation with `retry_of_job_id` and a `retry_requested` transition.
- Added Flutter retry controls and failure guidance text.
- Added editor `roomforge.reconstruction.qualityWarning` event.

### Completion Notes

- Retry attempts are new reconstruction job records linked to the original job.
- Existing failure/review status history remains on the original job.
- Users see recovery guidance for needs-review or failed job states.

### File List

- `app/lib/main.dart`
- `app/lib/src/projects/project_api.dart`
- `editor/src/main.ts`
- `server/README.md`
- `server/app/repositories/reconstruction_jobs.py`
- `server/app/routers/reconstruction_jobs.py`
- `server/tests/test_reconstruction_jobs.py`
- `_bmad-output/implementation-artifacts/3-6-reconstruction-quality-failure-guidance-and-retry.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`

## Change Log

- 2026-05-19: Implemented reconstruction retry and recovery guidance, then moved story to review.
