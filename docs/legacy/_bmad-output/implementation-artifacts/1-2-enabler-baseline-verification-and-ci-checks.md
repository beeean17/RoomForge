# Story 1.2: Enabler - Baseline Verification and CI Checks

## Status

review

## Story

As a developer, I want baseline verification commands for the Flutter app, Three.js editor, and FastAPI server, so that the greenfield monorepo can catch integration regressions before feature work accelerates.

## Acceptance Criteria

- Local verification commands cover app, editor, and server checks.
- Flutter has an analyze placeholder.
- Editor has typecheck/build/test placeholders.
- Server has an import or test placeholder.
- Expected CI checks for Flutter, editor, and server are explicit enough to reproduce locally.

## Tasks / Subtasks

- [x] Add root foundation verification script.
- [x] Add Flutter analyze command.
- [x] Add editor typecheck and test scripts.
- [x] Add server compile/import-oriented verification placeholder.
- [x] Add CI workflow for app, editor, and server baseline checks.
- [x] Document local verification commands.
- [x] Run foundation verification locally.

## Dev Notes

- Baseline verification is intentionally lightweight until feature dependencies and test fixtures settle.
- Server pytest support is declared as a dev optional dependency, while the baseline check uses `compileall` so the scaffold is verifiable before environment setup is finalized.
- CI mirrors the same three domains: Flutter app, TypeScript editor, and FastAPI server scaffold.

## Dev Agent Record

### Debug Log

- Initial sandboxed verification failed because Flutter attempted to update/read SDK cache outside the workspace.
- Verification was rerun with approved escalation and completed successfully.

### Completion Notes

- `./scripts/verify-foundation.sh` passed.
- CI workflow is available at `.github/workflows/foundation.yml`.
- Story is ready for code review.

### File List

- `scripts/verify-foundation.sh`
- `.github/workflows/foundation.yml`
- `docs/baseline-verification.md`
- `editor/package.json`
- `server/tests/test_import.py`
- `server/pyproject.toml`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`

## Change Log

- 2026-05-11: Added baseline verification script, CI workflow, and verification docs.
