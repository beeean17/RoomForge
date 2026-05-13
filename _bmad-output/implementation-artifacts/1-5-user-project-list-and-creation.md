# Story 1.5: User Project List and Creation

## Status

review

## Story

As a signed-in user, I want to create and view my room projects, so that I can start organizing room reconstruction work.

## Acceptance Criteria

- Given I am signed in, when I create a room project with valid metadata, then the API stores the project in Oracle linked to my user and the project appears in my project list.
- Given I am signed in, when I view my project list, then I only see projects owned by my user account and the list loads through an authenticated API request.

## Tasks / Subtasks

- [x] Add Oracle `room_projects` schema for owner-linked project records.
- [x] Add authenticated project list/create API routes.
- [x] Add repository tests for ownership-scoped list/create behavior using fake dependencies.
- [x] Add Flutter API client for authenticated project calls.
- [x] Add signed-in project list and create project UI.
- [x] Document project API surface.
- [x] Run app/server/foundation verification.

## Dev Notes

- Story 1.5 owns project list and creation only.
- Story 1.6 owns project detail, rename/update, and delete.
- All project APIs must require Firebase authentication and must scope records by `user_id`.

## Dev Agent Record

### Debug Log

- Added direct Flutter `http` dependency for project API calls.
- `flutter analyze` initially failed on nullable token return and separator callback lint; both were fixed.
- Project API tests use fake auth/user/project repositories to verify ownership-scoped behavior without requiring Oracle.

### Completion Notes

- Added authenticated `GET /room-projects` and `POST /room-projects`.
- Added `room_projects` migration linked to `users`.
- Added Flutter signed-in workspace project list, create dialog, and authenticated API client.
- Added `ROOMFORGE_API_BASE_URL` to app env example.
- `./scripts/verify-foundation.sh` passed.

### File List

- `app/.env.example`
- `app/lib/main.dart`
- `app/lib/src/api/api_config.dart`
- `app/lib/src/auth/auth_repository.dart`
- `app/lib/src/projects/project_api.dart`
- `app/pubspec.yaml`
- `app/pubspec.lock`
- `server/README.md`
- `server/app/main.py`
- `server/app/repositories/projects.py`
- `server/app/routers/projects.py`
- `server/app/schemas/projects.py`
- `server/migrations/002_room_projects.sql`
- `server/tests/test_projects.py`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`

## Change Log

- 2026-05-13: Implemented user project list/create and moved story to review.
