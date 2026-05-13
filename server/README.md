# RoomForge Server

Lightweight FastAPI service for Firebase token verification, authorization, Oracle DB access, job metadata, layout persistence, and admin operations.

The Oracle Cloud 1GB API server must not run heavy OpenCV, deep-learning, or GPU inference workloads. MVP OpenCV candidate extraction runs in the browser/editor layer.

## Local Verification

```bash
python3 -m compileall app tests
```

After installing development dependencies:

```bash
python3 -m pytest
```

## Auth Session Mapping

Protected API routes use `Authorization: Bearer <firebase_id_token>`.

`GET /auth/session` verifies the Firebase ID token and maps the Firebase user to an Oracle `users` record. The initial schema is in `migrations/001_user_session_mapping.sql`.

Configuration:

```env
ROOMFORGE_FIREBASE_PROJECT_ID=roomforge-dev
ROOMFORGE_FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099
ROOMFORGE_FIREBASE_ADMIN_CREDENTIALS_PATH=
ROOMFORGE_ORACLE_DSN=localhost/freepdb1
ROOMFORGE_ORACLE_USER=roomforge
ROOMFORGE_ORACLE_PASSWORD=change-me
```

If `ROOMFORGE_FIREBASE_AUTH_EMULATOR_HOST` is set, Firebase Admin verifies tokens against the local Auth emulator.
