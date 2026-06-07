# Story 1.7: Admin Access Boundary

## Status

review

## Story

As an admin user, I want admin-only routes and APIs to require an admin role, so that operational tools are protected from normal users.

## Acceptance Criteria

- Given I am a normal signed-in user, when I try to access admin UI or admin APIs, then access is denied with the standard `unauthorized` error category.
- Given I am an admin user, when I access the admin route, then the app allows entry to the admin shell and admin capabilities remain separate from normal project workspace capabilities.

## Tasks / Subtasks

- [x] Add a reusable server-side admin authorization boundary distinct from normal authentication.
- [x] Add a minimal admin API route protected by the admin role.
- [x] Add tests for missing-token, normal-user, and admin-user admin API access.
- [x] Add Flutter admin API access check and a separate admin shell entry from the workspace.
- [x] Update server documentation for the admin access boundary.
- [x] Run server/editor/foundation verification where possible and document any environment blockers.

## Dev Notes

- Epic 1 closes the authenticated project workspace with a role boundary only; job monitoring, artifact viewers, retries, and admin search remain Epic 6.
- Existing `users.role` values are constrained to `user` and `admin` in `server/migrations/001_user_session_mapping.sql`; no new migration is needed for this story.
- Use Firebase token verification and Oracle-side `UserRecord.role` for admin authorization.
- Standard error envelope must remain `{data: null, error: {code, message}, meta: {request_id}}`.
- Normal authenticated users must receive `unauthorized`, not `unauthenticated`, when their role is not admin.
- Flutter should keep admin UI separate from the regular project workspace. A minimal admin shell is enough for this story; operational admin workflows belong to Epic 6.
- Previous story learnings: project routes use fake repositories in tests and return non-disclosing errors; keep this story similarly small and testable.

## Dev Agent Record

### Debug Log

- Story created from Epic 1.7 requirements and current auth/project implementation context.
- Added failing admin API tests first; they failed with 404 until the admin router was implemented.
- `dart format` initially timed out under the workspace sandbox and completed with approved execution.
- `flutter analyze` could not complete because the installed Dart SDK is 3.10.7 while `app/pubspec.yaml` requires `^3.11.0`.

### Completion Notes

- Added `authorize_admin_request` to enforce Oracle-side `UserRecord.role == "admin"` after Firebase authentication.
- Added `GET /admin/session`, returning `unauthenticated` for missing/invalid tokens, `unauthorized` for normal users, and a minimal admin session for admin users.
- Added Flutter `AdminApi` plus a separate `AdminShellScreen`; the workspace checks admin access before entering the admin shell.
- Server pytest passed with 17 tests, including the new admin boundary coverage.
- Editor typecheck and test passed. Flutter analyze remains blocked until Flutter/Dart is upgraded to a SDK with Dart `>=3.11.0`.

### File List

- `app/lib/main.dart`
- `app/lib/src/admin/admin_api.dart`
- `server/README.md`
- `server/app/auth/dependencies.py`
- `server/app/main.py`
- `server/app/routers/admin.py`
- `server/tests/test_admin.py`
- `_bmad-output/implementation-artifacts/1-7-admin-access-boundary.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`

## Change Log

- 2026-05-17: Created story and started implementation.
- 2026-05-17: Implemented admin access boundary and moved story to review.
