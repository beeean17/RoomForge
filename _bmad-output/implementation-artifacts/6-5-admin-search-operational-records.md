# Story 6.5: Admin Search Across Users, Projects, Layouts, and Jobs

Status: complete

## Story

As a support/admin user,
I want to search by user, project, layout, or job identifier,
so that I can quickly find records related to a reported issue.

## Acceptance Criteria

1. Given I have admin access, when I search using a user, project, layout, or job identifier, then matching records are returned with enough context to navigate to details.
2. Given no matching records exist, when I search, then the UI shows an empty state without exposing unauthorized data.

## Tasks / Subtasks

- [x] Verify admin search API authorization and envelope behavior.
  - [x] Confirm `/admin/search` requires admin authorization before repository lookup.
  - [x] Confirm non-admin access returns `unauthorized`.
  - [x] Confirm success and empty results use the shared `data`, `error`, and `meta.request_id` envelope.
- [x] Verify search result context.
  - [x] Confirm user results include label and safe context.
  - [x] Confirm project results include label and owner context.
  - [x] Confirm layout results include project/user context.
  - [x] Confirm job results include status, project/user, provider, and failure context.
- [x] Verify Flutter admin search behavior.
  - [x] Confirm search API parsing preserves labels and context maps.
  - [x] Confirm no-match and blank searches show the empty state.
  - [x] Confirm job results can open job detail, artifacts, and diagnosis.
- [x] Run full app/server validation and focused subagent review.

## Dev Notes

- Current baseline already contained a simple admin search endpoint and UI. This story strengthens navigable context and fixes UI behavior for blank/stale searches.
- The active branch uses a recovery branch name because `story/6.5-admin-search` already exists as an older merged ancestor of current primary.
- Default Oracle search remains identifier-based and numeric. This matches the story wording around identifiers; broader email/name search can be added later if needed.
- Job results are directly actionable in the current admin UI. User/project/layout results expose context for support lookup but do not yet have dedicated detail pages.

### References

- `docs/legacy/_bmad-output/planning-artifacts/epics.md` Story 6.5.
- `docs/legacy/_bmad-output/planning-artifacts/architecture.md` admin authorization, Oracle records, and API envelope rules.
- `docs/legacy/_bmad-output/planning-artifacts/prd.md` admin lookup/support troubleshooting requirements.
- `docs/legacy/_bmad-output/planning-artifacts/ux-design-specification.md` admin search/filter/detail flow guidance.
- `docs/legacy/agent/STORY_QUEUE.md` Story 6.5.

## Dev Agent Record

### Agent Model Used

GPT-5 Codex

### Debug Log References

- `dart format lib/main.dart test/src/admin/admin_api_test.dart`
- `flutter test test/src/admin/admin_api_test.dart test/src/admin/firebase_admin_access_repository_test.dart test/src/admin/firebase_admin_diagnostics_test.dart`
- `.venv/bin/python -m pytest tests/test_admin.py`
- `flutter analyze`
- `flutter test`
- `.venv/bin/python -m pytest`
- `.venv/bin/python -m compileall app`
- `npm run check:editor-firebase-boundary`
- `npm run build`
- `flutter build web --release`
- `git diff --check`
- Subagent focused review completed, found two UI blockers, then rechecked after fixes with no blockers.

### Completion Notes List

- Added safe `context` metadata to default Oracle admin search results.
- Added Flutter search API coverage for result labels/context and empty results.
- Updated admin search UI to render labels with context, show an empty state for blank searches, and let job results open detail/artifact/diagnosis panels.
- Tightened server tests for search result context, unauthorized access, and no-match behavior.

### File List

- `_bmad-output/implementation-artifacts/6-5-admin-search-operational-records.md`
- `_bmad-output/implementation-artifacts/6-5-completion-report-2026-05-29.md`
- `app/lib/main.dart`
- `app/test/src/admin/admin_api_test.dart`
- `server/app/routers/admin.py`
- `server/tests/test_admin.py`
