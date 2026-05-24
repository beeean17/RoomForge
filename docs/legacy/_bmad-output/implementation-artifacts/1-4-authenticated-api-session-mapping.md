# Story 1.4: Authenticated API Session Mapping

## Status

review

## Story

As a signed-in user, I want the server to recognize my Firebase identity, so that my data can be linked to a RoomForge user record.

## Acceptance Criteria

- Given the client has a Firebase ID token, when it calls a protected API endpoint, then FastAPI verifies the token and maps it to an Oracle `users` record.
- Given authenticated user mapping is implemented, when Oracle schema changes are added, then the story creates or modifies only user/session mapping tables and fields required for this capability.
- Given the token is missing, expired, or invalid, when a protected endpoint is called, then the API returns the standard envelope with `unauthenticated` and no user, project, layout, image, job, or result data is returned.

## Tasks / Subtasks

- [x] Add Firebase Admin token verification boundary.
- [x] Add authenticated user/session API schema and standard error envelope.
- [x] Add Oracle user mapping repository and migration.
- [x] Add protected `/auth/session` endpoint.
- [x] Add missing/invalid token tests or verification coverage.
- [x] Document server auth configuration.
- [x] Run server/foundation verification.

## Dev Notes

- Story 1.4 owns API-side Firebase token verification and Oracle user mapping only.
- Project CRUD remains Story 1.5.
- Admin role enforcement remains Story 1.7, but the `users` table may include a role field for future authorization.
- Invalid auth responses must not include user or application data.

## Dev Agent Record

### Debug Log

- Added `firebase-admin` dependency for server-side token verification.
- `pip install -e '.[dev]'` initially failed because setuptools detected `migrations` as a second top-level package; fixed package discovery to include only `app*`.
- Server pytest uses fake token verifier and fake user repository to verify auth behavior without requiring live Firebase or Oracle.

### Completion Notes

- Added `/auth/session` protected endpoint.
- Missing or invalid bearer tokens return the standard `unauthenticated` envelope with no user/application data.
- Valid Firebase identities are mapped through the `UserRepository` boundary and Oracle `users` migration.
- Added server auth docs and test coverage.
- `server/.venv/bin/python -m pytest` passed.
- `python3 -m compileall app tests` passed.

### File List

- `server/pyproject.toml`
- `server/.env.example`
- `server/README.md`
- `server/app/auth/dependencies.py`
- `server/app/auth/firebase.py`
- `server/app/core/config.py`
- `server/app/core/errors.py`
- `server/app/core/request.py`
- `server/app/main.py`
- `server/app/repositories/users.py`
- `server/app/routers/auth.py`
- `server/app/schemas/auth.py`
- `server/migrations/001_user_session_mapping.sql`
- `server/tests/test_auth_session.py`
- `.github/workflows/foundation.yml`
- `docs/baseline-verification.md`
- `scripts/verify-foundation.sh`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`

## Change Log

- 2026-05-12: Implemented authenticated API session mapping and moved story to review.
