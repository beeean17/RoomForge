# Project Structure

RoomForge uses a small monorepo with clear runtime boundaries.

```text
app/       Flutter app shell for auth, navigation, forms, project workflows, admin UI, and accessible non-canvas controls.
editor/    Vite + TypeScript editor package for Three.js rendering, OpenCV overlays, geometry correction, and Flutter bridge messages.
server/    Lightweight FastAPI API for Firebase token verification, authorization, Oracle DB access, metadata, persistence, and admin operations.
packages/  Shared schemas and token exports for app/editor/server alignment.
docs/      Project documentation and workflow notes.
```

The server owns API routing and persistence. It must not run heavy OpenCV, deep-learning, or GPU workloads. MVP OpenCV processing belongs in `editor/`, preferably in a Web Worker.

## Placeholder Configuration

- Firebase Hosting/Auth: app-side configuration is expected through Firebase project files and environment-specific deployment settings.
- API base URL: Flutter build/runtime configuration should point to the deployed FastAPI server.
- Oracle DB: server configuration uses `ROOMFORGE_ORACLE_*` environment variables; see `server/.env.example`.
- Optional providers: external CV/GPU providers are disabled by default with `ROOMFORGE_ENABLE_EXTERNAL_CV_PROVIDER=false`.
