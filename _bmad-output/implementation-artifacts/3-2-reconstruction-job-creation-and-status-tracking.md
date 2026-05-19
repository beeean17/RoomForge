# Story 3.2: Reconstruction Job Creation and Status Tracking

## Status

review

## Story

As a signed-in user,
I want to submit and track a reconstruction job,
So that I can see whether my room image is being processed, needs review, failed, or completed.

## Acceptance Criteria

- Given I have a valid source image and room dimensions, when I submit reconstruction, then the API creates a reconstruction job with allowed status values only.
- Given a reconstruction job exists, when the client polls job status at least every 5 seconds, then the UI displays the current state using action-oriented language.
- Given the persisted job status is `review_required`, when the client displays the state, then the user-facing label is "Needs review" and the system does not introduce a separate persisted `needs_review` status.
- Given a job reaches a terminal state, when the state is persisted, then the job is marked `succeeded`, `failed`, `timeout`, or `cancelled`, and status transitions include timestamp, actor/source, reason code where available, and human-readable reason where available.

## Tasks / Subtasks

- [x] Add reconstruction job schema with allowed persisted statuses.
- [x] Add reconstruction job transition schema for status history.
- [x] Add authenticated create/status API routes scoped by project owner.
- [x] Add tests for authentication, ownership, ready input, transition history, and `review_required` label mapping.
- [x] Add Flutter API client methods for job create/status.
- [x] Add Flutter project detail controls for submit and 5-second status polling.
- [x] Update server documentation and BMAD sprint status.

## Dev Notes

- This story creates and tracks job records only; OpenCV candidate extraction and result persistence are Story 3.3.
- Long-running processing must not run in the FastAPI request.
- Polling metadata uses `meta.poll_after_seconds: 5`.

## Dev Agent Record

### Debug Log

- Added `reconstruction_jobs` and `reconstruction_job_transitions` DDL.
- Added server repository, schemas, and routes for creating and retrieving owned reconstruction jobs.
- Added status labels, including persisted `review_required` -> user-facing "Needs review".
- Added Flutter project detail job submit controls and a 5-second polling timer.

### Completion Notes

- API creates jobs only for owned projects with a source image and saved dimensions.
- Job responses include current status, action-oriented label, terminal flag, provider, failure metadata, and transition history.
- Flutter blocks submit until source image and dimensions exist in client state.

### File List

- `app/lib/main.dart`
- `app/lib/src/projects/project_api.dart`
- `server/README.md`
- `server/app/main.py`
- `server/app/repositories/reconstruction_jobs.py`
- `server/app/routers/reconstruction_jobs.py`
- `server/app/schemas/reconstruction_jobs.py`
- `server/migrations/004_reconstruction_jobs.sql`
- `server/tests/test_reconstruction_jobs.py`
- `_bmad-output/implementation-artifacts/3-2-reconstruction-job-creation-and-status-tracking.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`

## Change Log

- 2026-05-19: Implemented reconstruction job creation/status tracking and moved story to review.
