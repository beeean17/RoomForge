# Story 4.5: Scale, Measurement, and Placement Guidance

Status: complete

## Story

As a user,
I want measurement labels, dimension guidance, and placement warnings,
so that I can understand whether the layout is realistic.

## Acceptance Criteria

1. Given I am editing a room layout, when dimensions, measurement guides, grid, or furniture bounds are enabled, then labels display stable numeric formatting with units.
2. Given a furniture placement is outside the valid room area or conflicts with spatial constraints, when the object is selected or moved, then the editor shows a placement warning without relying on color alone.
3. Given measurement, grid, or placement guidance is visible at different responsive widths, when labels or warnings render near geometry, then text remains readable, does not overlap primary controls, and provides units or action-oriented guidance.

## Tasks / Subtasks

- [x] Lock measurement and placement guidance with automated validation.
  - [x] Cover room measurement labels with stable numeric units.
  - [x] Cover selected furniture measurement labels with units.
  - [x] Cover outside-room placement warning and safe null state.
- [x] Verify editor overlay/status integration.
  - [x] Confirm measurement status uses the shared formatting helper.
  - [x] Confirm placement warning is textual and action-oriented.
  - [x] Confirm responsive CSS constrains measurement/warning overlays away from primary controls.
- [x] Run editor/app validation and focused review.

## Dev Notes

- Current branch uses a recovery branch name because `story/4.5-measurement-placement-guidance` already exists as an older merged ancestor of the current primary.
- Primary implementation surfaces:
  - `editor/src/measurementGuidance.ts`
  - `editor/src/main.ts`
  - `editor/src/style.css`
- Keep labels in meters with fixed two-decimal formatting.
- Placement warnings must not rely on color alone; they need textual warning and action guidance.

### References

- `docs/legacy/_bmad-output/planning-artifacts/epics.md` Story 4.5.
- `docs/legacy/_bmad-output/planning-artifacts/architecture.md` coordinate-space and validation patterns.
- `docs/legacy/_bmad-output/planning-artifacts/ux-design-specification.md` measurement labels, layer toggles, placement warnings, and non-color-only states.
- `docs/legacy/agent/STORY_QUEUE.md` Story 4.5.

## Dev Agent Record

### Agent Model Used

GPT-5 Codex

### Debug Log References

- `npm run test:story-4.5`
- `npm run typecheck`
- `npm run test:story-4.4`
- `npm run build`
- `npm run test`
- `npm run check:editor-firebase-boundary`
- `flutter analyze`
- `flutter test`
- `flutter build web --release`
- `git diff --check`
- Subagent focused review completed with no blocking or material findings.

### Completion Notes List

- Added `editor/src/measurementGuidance.ts` for stable two-decimal meter labels and action-oriented placement warnings.
- Added a Story 4.5 verification script covering room measurement labels, selected furniture labels, outside-room warnings, and no-warning safe state.
- Wired existing editor measurement and placement status overlays through the shared guidance helper.
- Verified existing CSS keeps measurement/warning overlays constrained on desktop and mobile-review widths.

### File List

- `_bmad-output/implementation-artifacts/4-5-scale-measurement-placement-guidance.md`
- `editor/package.json`
- `editor/scripts/verify-story-4.5-measurement-guidance.mjs`
- `editor/src/main.ts`
- `editor/src/measurementGuidance.ts`
