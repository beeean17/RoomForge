# Local Service Test

Use this flow when Oracle is not ready but you need to test the RoomForge service
locally through the browser.

## Runtime Model

- Firebase Auth runs through the local Firebase Auth emulator.
- FastAPI runs on `127.0.0.1:8010` by default.
- FastAPI uses in-memory repositories when started with `scripts/server-local.sh`.
- The editor runs on `127.0.0.1:5173`.
- Flutter web connects to both the API and editor through dart defines from
  `app/.env`.

In-memory data is reset whenever the FastAPI process restarts.

## Terminals

Start each process in a separate terminal.

### 1. Firebase Auth Emulator

```bash
./scripts/server-emulator.sh
```

### 2. FastAPI Local Server

```bash
./scripts/server-local.sh
```

This enables:

```env
ROOMFORGE_USE_IN_MEMORY_REPOSITORIES=true
ROOMFORGE_FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099
```

Override the API port if needed:

```bash
ROOMFORGE_SERVER_PORT=8000 ./scripts/server-local.sh
```

### 3. Editor

```bash
./scripts/editor-local.sh
```

### 4. Flutter Web

```bash
./scripts/web-emulator.sh
```

## Manual Test Flow

1. Sign in through Firebase Auth emulator.
2. Create a room project.
3. Select the project.
4. Upload a JPEG, PNG, or WebP room photo.
5. Save width and depth; leave height blank to verify default height.
6. Submit reconstruction.
7. Open reconstruction and verify the editor bridge status.
8. Use geometry controls in the editor.
9. Generate a floor plan.
10. Retry reconstruction from the project detail panel if a review or terminal
    status is shown.

## Health Check

```bash
curl -i http://127.0.0.1:8010/health
```

Protected API routes still require Firebase ID tokens. Use the Flutter UI for
normal end-to-end testing.
