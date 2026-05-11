# Story 1.1: Enabler - Set Up Initial Project from Minimal Official Starters

## Status

review

## Story

As a developer, I want the RoomForge MVP workspace initialized from minimal official starters with app, editor, and server boundaries, so that user-facing auth and project features can be implemented consistently.

## Acceptance Criteria

- Repository contains `app/`, `editor/`, `server/`, and `packages/` boundaries.
- Flutter, FastAPI, and TypeScript editor responsibilities are documented in the project structure.
- Firebase Hosting, Firebase Auth, Oracle DB, and API environment settings have clear placeholder configuration.
- No heavy OpenCV, deep-learning, or GPU process is configured to run on the 1GB API server.
- The app uses a Flutter starter, the editor uses a Vite vanilla TypeScript starter, and the server uses a lightweight FastAPI scaffold.
- Shared status tokens exist for candidate, confirmed, selected, warning, error, measurement, save, and admin states.

## Tasks / Subtasks

- [x] Create Flutter app shell under `app/`.
- [x] Create Vite vanilla TypeScript editor package under `editor/`.
- [x] Create lightweight FastAPI scaffold under `server/`.
- [x] Add shared token source under `packages/`.
- [x] Document workspace boundaries and placeholder configuration.
- [x] Keep heavy CV/GPU work out of the server scaffold.

## Dev Notes

- Flutter shell owns app navigation, auth surfaces, forms, admin UI, and accessible non-canvas controls.
- Three.js editor owns spatial rendering, OpenCV overlays, geometry correction, furniture manipulation, and bridge messages.
- FastAPI server owns auth verification, authorization, REST APIs, Oracle DB access, metadata, persistence, and admin operations.
- MVP OpenCV processing belongs in the browser/editor layer, preferably in a Web Worker.

## Dev Agent Record

### Debug Log

- `npm create vite@latest editor -- --template vanilla-ts` required network access and succeeded after rerun with escalation.
- `flutter analyze` initially failed because `MaterialApp` was marked `const` while using non-const `AppBar`; fixed in `app/lib/main.dart`.

### Completion Notes

- Project foundation scaffold is in place.
- Architecture and project structure docs describe responsibilities and server constraints.
- Shared design/status tokens are available at `packages/design-tokens.json`.
- Story is ready for code review.

### File List

- `app/`
- `editor/`
- `server/`
- `packages/design-tokens.json`
- `packages/README.md`
- `docs/project-structure.md`
- `README.md`
- `.gitignore`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`

## Change Log

- 2026-05-11: Implemented initial app/editor/server/packages foundation.
