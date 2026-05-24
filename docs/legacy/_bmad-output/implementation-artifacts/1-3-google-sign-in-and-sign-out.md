# Story 1.3: Google Sign-In and Sign-Out

## Status

review

## Story

As a user, I want to sign in and sign out with Google, so that I can securely access my RoomForge projects.

## Acceptance Criteria

- Given I am not authenticated, when I open RoomForge, then I see a Google sign-in entry point.
- Given I complete Google sign-in successfully, when Firebase returns an authenticated user, then the app routes me to the project workspace and the UI uses clear signed-in status language.
- Given I am signed in, when I choose sign out, then my session is cleared and I return to the signed-out state.

## Tasks / Subtasks

- [x] Add Firebase Auth dependencies to Flutter app.
- [x] Add environment-driven Firebase web configuration placeholders.
- [x] Add Google sign-in entry point for signed-out users.
- [x] Route authenticated users to a project workspace placeholder.
- [x] Add sign-out action that returns to signed-out state.
- [x] Document Firebase auth setup and secret handling.
- [x] Add local `app/.env` workflow for Firebase dart defines.
- [x] Add local Firebase Auth emulator run scripts.
- [x] Run foundation verification.

## Dev Notes

- Firebase configuration must not be committed. The app reads Firebase web options from `--dart-define` values.
- Story 1.4 owns FastAPI token verification and Oracle user/session mapping. Story 1.3 only establishes the client-side signed-in state.
- Project list and creation remain placeholder text until Story 1.5.

## Dev Agent Record

### Debug Log

- `flutter pub add firebase_core firebase_auth` required approved escalation because Flutter needed SDK cache access and package downloads.

### Completion Notes

- Added Firebase Auth-backed Google sign-in entry point.
- Added signed-in workspace placeholder and sign-out action.
- Added Firebase web configuration docs and `scripts/run-app-web.sh` using `--dart-define-from-file`.
- `./scripts/verify-foundation.sh` passed.

### File List

- `app/lib/main.dart`
- `app/lib/src/auth/auth_repository.dart`
- `app/lib/src/auth/firebase_options_from_env.dart`
- `app/pubspec.yaml`
- `app/pubspec.lock`
- `docs/firebase-auth-setup.md`
- `app/.env.example`
- `scripts/run-app-web.sh`
- `scripts/run-firebase-emulator.sh`
- `scripts/run-app-web-with-emulator.sh`
- `scripts/run-app-web-emulator.sh`
- `README.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`

## Change Log

- 2026-05-11: Implemented Google sign-in/sign-out shell and moved story to review.
