# Story 4.3: Add and Select Furniture Proxy Objects

Status: complete

## Story

As a user,
I want to add and select furniture proxy objects,
so that I can begin planning a room layout.

## Acceptance Criteria

1. Given I am in the planning editor, when I add a furniture proxy object, then it appears in the shared spatial model with ID, category, size, position, rotation, and color.
2. Given furniture exists, when I select an object in 2D or 3D, then the selected state is visible with outline, halo, handle, or marker treatment and the inspector shows that object's editable properties.
3. Given a furniture object is selected, when selection is represented visually, then the selected state does not rely on color alone and a textual selection summary is available in the Flutter-controlled inspector or status area where feasible.

## Tasks / Subtasks

- [x] Lock furniture add/select model behavior with automated validation.
  - [x] Cover furniture object fields: ID, category, size, position, rotation, and color.
  - [x] Cover add operation selecting the new object and marking unsaved state.
  - [x] Cover selecting an existing object without changing object identity.
- [x] Verify selection representation and inspector summary.
  - [x] Cover non-color-only selection tokens.
  - [x] Cover textual selected-object summary with dimensions, position, and rotation.
  - [x] Confirm editor selection outline uses the shared visual token contract.
- [x] Run editor/app validation and focused review.

## Dev Notes

- Current branch uses a recovery branch name because `story/4.3-add-select-furniture` already exists as an older merged ancestor of the current primary.
- Primary implementation surfaces:
  - `editor/src/furnitureModel.ts`
  - `editor/src/main.ts`
  - `editor/src/spatialModel.ts`
- Furniture selection should remain in the shared spatial model and must not create separate 2D/3D selection stores.
- Story 4.4 owns move/rotate/resize/delete interaction expansion; keep this story focused on add/select and selection representation.

### References

- `docs/legacy/_bmad-output/planning-artifacts/epics.md` Story 4.3.
- `docs/legacy/_bmad-output/planning-artifacts/architecture.md` editor furniture and shared scene boundaries.
- `docs/legacy/_bmad-output/planning-artifacts/ux-design-specification.md` furniture inspector and non-color-only selection guidance.
- `docs/legacy/agent/STORY_QUEUE.md` Story 4.3.

## Dev Agent Record

### Agent Model Used

GPT-5 Codex

### Debug Log References

- `npm run test:story-4.3`
- `npm run typecheck`
- `npm run test:story-4.1`
- `npm run test:story-4.2`
- `npm run build`
- `npm run test`
- `npm run check:editor-firebase-boundary`
- `flutter analyze`
- `flutter test`
- `flutter build web --release`
- `git diff --check`
- Subagent focused review found no blocking or material findings.

### Completion Notes List

- Extracted furniture add/select model helpers into `editor/src/furnitureModel.ts`.
- Added a Story 4.3 verification script covering required furniture fields, add/select shared-model updates, textual inspector summary, and non-color-only selection tokens.
- Wired existing editor add/select paths through the shared helper contract.
- Kept Story 4.4 movement/editing behavior out of scope.
- Subagent review verified the add path, identity-preserving selection, non-color-only outline token, and inspector summary.

### File List

- `_bmad-output/implementation-artifacts/4-3-add-and-select-furniture-proxy-objects.md`
- `editor/package.json`
- `editor/scripts/verify-story-4.3-furniture-selection.mjs`
- `editor/src/furnitureModel.ts`
- `editor/src/main.ts`
