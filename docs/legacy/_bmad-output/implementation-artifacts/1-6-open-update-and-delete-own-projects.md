# Story 1.6: Open, Update, and Delete Own Projects

## Status

review

## Story

As a signed-in user, I want to open, rename, update, and delete my own room projects, so that I can manage my workspace over time.

## Acceptance Criteria

- Given I own a project, when I open the project detail view, then the app displays its current metadata and next available workflow action.
- Given I own a project, when I update valid project metadata, then the API persists the change and returns the updated project.
- Given I own a project, when I confirm deletion, then the project is deleted or marked deleted according to the persistence policy and it no longer appears in my active project list.
- Given I try to access a project owned by another user, when I call view, update, or delete APIs, then the API returns `unauthorized` or `not_found` without exposing that project's data.

## Tasks / Subtasks

- [x] Add owned project detail/update/delete API routes.
- [x] Implement repository methods scoped by `user_id`.
- [x] Use soft delete so deleted projects disappear from active list.
- [x] Add tests for own-project access and cross-user non-disclosure.
- [x] Add Flutter project detail, edit, and delete UI.
- [x] Update documentation.
- [x] Run app/server/foundation verification.

## Dev Notes

- Story 1.6 extends Story 1.5 project persistence.
- Deletion should mark `deleted_at` rather than physically deleting records.
- Cross-user access should return `not_found` to avoid exposing another user's project existence.
- Admin overrides are not part of this story.

## Dev Agent Record

### Debug Log

- Extended project repository protocol and fake test repository with get/update/delete methods.
- Added nonblank project name validation to avoid whitespace-only names reaching Oracle constraints.
- Verified cross-user access returns `not_found` without disclosing project data.

### Completion Notes

- Added owned project detail, update, and soft-delete API routes.
- Added Flutter project selection, detail panel, edit dialog, and delete confirmation.
- Deleted projects are marked with `deleted_at` and disappear from active project lists.
- `./scripts/verify-foundation.sh` passed.

### File List

- `app/lib/main.dart`
- `app/lib/src/projects/project_api.dart`
- `server/README.md`
- `server/app/repositories/projects.py`
- `server/app/routers/projects.py`
- `server/app/schemas/projects.py`
- `server/tests/test_projects.py`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`

## Change Log

- 2026-05-13: Implemented own-project open/update/delete and moved story to review.
