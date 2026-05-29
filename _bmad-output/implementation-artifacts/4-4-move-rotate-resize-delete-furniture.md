# Story 4.4: Move, Rotate, Resize, and Delete Furniture

Status: complete

## Story

As a user,
I want to move, rotate, resize, and delete furniture proxy objects,
so that I can test different layout arrangements.

## Acceptance Criteria

1. Given a furniture object is selected, when I move, rotate, or resize it, then the shared spatial model updates within 100 ms for MVP-scale scenes and both 2D and 3D views stay synchronized.
2. Given a furniture object is selected, when I delete it and confirm if needed, then the object is removed from the layout state and selection and inspector state update cleanly.
3. Given I edit furniture with pointer, keyboard-accessible controls, or inspector fields, when I move, rotate, resize, or delete an object, then the interaction preserves visible focus or selected state and compact controls use feasible 44x44px targets on touch-oriented layouts.

## Tasks / Subtasks

- [x] Lock furniture mutation behavior with automated validation.
  - [x] Cover move, rotate, resize, lock, and delete actions.
  - [x] Cover selected state persistence after non-delete edits.
  - [x] Cover clean selection fallback after delete.
- [x] Verify 2D/3D shared model synchronization.
  - [x] Cover edits in 2D and 3D view-mode state without duplicating furniture state.
  - [x] Cover MVP-scale edit loop under 100 ms.
- [x] Verify editor control accessibility evidence.
  - [x] Confirm edit controls are keyboard/non-canvas buttons.
  - [x] Confirm buttons keep 44px minimum height and visible focus styling.
- [x] Run editor/app validation and focused review.

## Dev Notes

- Current branch uses a recovery branch name because `story/4.4-edit-furniture` already exists as an older merged ancestor of the current primary.
- Primary implementation surfaces:
  - `editor/src/furnitureModel.ts`
  - `editor/src/main.ts`
  - `editor/src/style.css`
- Keep one shared furniture model. Do not create separate 2D and 3D furniture state.
- Delete currently removes the selected object and returns selection to the room shell. No additional confirmation UI is required by the current implementation.

### References

- `docs/legacy/_bmad-output/planning-artifacts/epics.md` Story 4.4.
- `docs/legacy/_bmad-output/planning-artifacts/architecture.md` editor interaction and performance targets.
- `docs/legacy/_bmad-output/planning-artifacts/ux-design-specification.md` furniture inspector, direct manipulation, touch target, and motion guidance.
- `docs/legacy/agent/STORY_QUEUE.md` Story 4.4.

## Dev Agent Record

### Agent Model Used

GPT-5 Codex

### Debug Log References

- `npm run test:story-4.4`
- `npm run typecheck`
- `npm run test:story-4.3`
- `npm run build`
- `npm run test`
- `npm run check:editor-firebase-boundary`
- `flutter analyze`
- `flutter test`
- `flutter build web --release`
- `git diff --check`
- Subagent focused review found no blocking or material findings.

### Completion Notes List

- Promoted furniture edit behavior into `editor/src/furnitureModel.ts` so movement, rotation, resize, lock, and delete update one shared spatial model.
- Added a Story 4.4 verification script covering move/rotate/resize/delete, selected identity preservation, clean room-shell selection after delete, locked edit blocking, and a 20-object MVP-scale edit loop under 100 ms.
- Wired existing editor controls through the shared edit helper while keeping localized status copy and scene update emissions.
- Kept the existing non-canvas edit buttons and focus/touch-target CSS evidence.
- Subagent focused review verified non-delete selection preservation, delete room-shell fallback, lock behavior, and the focused MVP edit loop threshold.

### File List

- `_bmad-output/implementation-artifacts/4-4-move-rotate-resize-delete-furniture.md`
- `editor/package.json`
- `editor/scripts/verify-story-4.4-furniture-editing.mjs`
- `editor/src/furnitureModel.ts`
- `editor/src/main.ts`
