---
title: 'CV-UI.3 React Candidate Review Tray'
type: 'feature'
created: '2026-06-07'
status: 'done'
baseline_commit: '0f4fffeccc714893fe3a228fda1392652feec480'
context:
  - '{project-root}/_bmad-output/planning-artifacts/cv-scene-understanding-epics-and-stories.md'
  - '{project-root}/_bmad-output/planning-artifacts/cv-provider-decision-gate.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-cv-ui-2-react-owned-editor-controls.md'
---

<frozen-after-approval reason="human-owned intent - do not modify unless human renegotiates">

## Intent

**Problem:** CV candidates are now present in the editor runtime model and React owns the visible editor controls, but candidate review still lives inside hidden embedded runtime chrome. Users need a product-facing review tray that separates CV candidates from placed and confirmed scene objects.

**Approach:** Add a React-owned candidate review section in the web editor inspector. It should read runtime scene payloads, render candidate state and evidence, and send existing runtime bridge commands for place, reject, and category update.

## Boundaries & Constraints

**Always:** Keep `editor/` as the Three.js/OpenCV runtime and `web` as the product UI owner. Preserve candidate-vs-placed-vs-confirmed separation. Display `review_required` as `Needs review`. Use camelCase bridge fields and do not introduce persisted statuses or server-side CV inference.

**Ask First:** Any persistence schema change, API endpoint change, drag/drop implementation, fixture wall editing workflow, or new ML/CV provider integration.

**Never:** Do not restore iframe embedding. Do not make hidden runtime DOM controls the product UI. Do not silently convert all candidates into confirmed saved objects. Do not add Cloud GPU, SAM, or heavy inference to this story.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Candidates loaded | Runtime spatial payload contains furniture and fixture `candidateObjects` | React tray lists each candidate with label, category, confidence, source/evidence, and review state | Unknown fields fall back to readable defaults |
| Needs review | Candidate has `reviewState: review_required` or low confidence | Tray visibly shows `Needs review` text, not color-only state | Missing confidence shows `n/a` |
| Place furniture | User activates Place on an unplaced furniture candidate | React sends `roomforge.candidate.place`; runtime places editable furniture and React summary updates from response/events | Place is disabled for rejected/placed/non-furniture candidates |
| Reject candidate | User activates Reject | React sends `roomforge.candidate.reject`; candidate remains traceable as rejected and placed object is removed by runtime | Button disabled when already rejected |
| Category change | User changes category select | React sends `roomforge.candidate.updateCategory`; runtime recalculates category-derived suggestions and marks review required | Unsupported category options are not shown |

</frozen-after-approval>

## Code Map

- `web/src/features/editor/EditorPage.tsx` -- product editor shell that owns React controls and runtime bridge dispatch.
- `web/src/features/editor/editorCandidateReview.ts` -- new parser/model helpers for React candidate review data.
- `web/src/design/globals.css` -- web editor inspector and tray styling.
- `web/scripts/verify-editor-candidate-review.mjs` -- focused contract check for candidate parsing and state labels.
- `web/package.json` -- adds the focused candidate review verification script.
- `editor/src/runtime.ts` -- existing bridge command handlers for candidate place/reject/category update; should not need new behavior unless a payload gap is found.
- `editor/src/candidateTray.ts` -- runtime model behavior and category list reference.

## Tasks & Acceptance

**Execution:**
- [x] `web/src/features/editor/editorCandidateReview.ts` -- add typed candidate review parsing, category option constants, labels, counts, and action availability helpers -- keeps data interpretation testable outside the React component.
- [x] `web/src/features/editor/EditorPage.tsx` -- store candidate review state from runtime payloads, render the React-owned candidate tray, and dispatch candidate bridge commands -- makes the product editor UI own candidate review.
- [x] `web/src/design/globals.css` -- style the tray with dense inspector-friendly cards, visible state text, category controls, and stable responsive dimensions -- keeps UI aligned with the existing editor design.
- [x] `web/scripts/verify-editor-candidate-review.mjs` and `web/package.json` -- add a focused verification command -- prevents regressions in Needs review, action availability, and candidate/placed/confirmed counts.
- [x] `_bmad-output/implementation-artifacts/spec-cv-ui-3-react-candidate-review-tray.md` -- update completion notes and validation results -- preserves story history.

**Acceptance Criteria:**
- Given candidate objects exist, when the React editor renders, then the inspector shows a candidate tray separate from placed and confirmed object counts.
- Given a low-confidence or `review_required` candidate, when displayed, then `Needs review` is visible as text.
- Given an unplaced furniture candidate, when Place is activated, then React sends the candidate place bridge command and runtime events update the tray state.
- Given a candidate is rejected, when runtime state returns, then the tray still shows it as `Rejected` for traceability and disables incompatible actions.
- Given a category changes, when runtime state returns, then the tray shows the updated category and `Needs review` state.

## Spec Change Log

## Design Notes

The tray belongs in the React inspector rather than in hidden runtime chrome. The runtime remains authoritative for scene mutation; React only interprets payloads and sends commands. This keeps the next fixture/drag-drop stories additive instead of forcing another ownership change.

## Verification

**Commands:**
- `npm --prefix web run typecheck` -- expected: TypeScript passes.
- `npm --prefix web run build` -- expected: Vite build passes with only existing OpenCV/chunk warnings if any.
- `npm --prefix web run test:editor-candidates` -- expected: candidate review parser contract passes.
- `npm --prefix editor run typecheck` -- expected: runtime command surface remains valid.
- `npm --prefix editor run test:cv-3.2` -- expected: runtime candidate tray model contract still passes.
- Browser smoke on `/projects/demo-project/editor` with injected candidate payload -- expected: no iframe, canvas renders, React tray shows candidates, Place/Reject/Category commands emit runtime events with no console errors.

## Completion Notes

- Added a React-owned candidate review tray in the web editor inspector.
- Added `editorCandidateReview.ts` so payload parsing, category options, action availability, and candidate/placed/confirmed counts are testable outside React rendering.
- Added a dev-only `?candidateFixture=1` editor route fixture to support browser smoke without changing production data flow.
- The tray sends existing runtime bridge commands for `roomforge.candidate.place`, `roomforge.candidate.reject`, and `roomforge.candidate.updateCategory`.
- Local review found and fixed one count bug: placed/rejected candidates no longer inflate the unresolved `Needs review` count.
- Sub-agent review was not run because this session's sub-agent tool is restricted to explicit user requests for delegation.

## Validation Results

- Passed: `npm --prefix web run test:editor-candidates`
- Passed: `npm --prefix web run typecheck`
- Passed: `npm --prefix editor run typecheck`
- Passed: `npm --prefix editor run test:cv-3.2`
- Passed: `npm --prefix web run build`
- Passed: `npm --prefix editor run build`
- Passed: `git diff --check`
- Passed: browser smoke on `http://127.0.0.1:9242/projects/demo-project/editor?candidateFixture=1`; `iframeCount = 0`, `canvasCount = 1`, `trayCount = 1`, `cardCount = 3`, candidate place/category/reject events emitted, and console error logs were empty.
- Smoke screenshot: `/private/tmp/roomforge-cv-ui-3-candidate-review-smoke.png`

## Suggested Review Order

**Entry Point**

- Runtime payloads become React-owned candidate tray state here.
  [`EditorPage.tsx:265`](../../web/src/features/editor/EditorPage.tsx#L265)

- The inspector mounts the tray beside existing React editor controls.
  [`EditorPage.tsx:648`](../../web/src/features/editor/EditorPage.tsx#L648)

**Candidate Model**

- Parser preserves candidate/placed/confirmed separation and action availability.
  [`editorCandidateReview.ts:48`](../../web/src/features/editor/editorCandidateReview.ts#L48)

- Candidate cards expose Place, Reject, and category bridge actions.
  [`EditorPage.tsx:789`](../../web/src/features/editor/EditorPage.tsx#L789)

**Smoke Fixture And Styling**

- Dev-only query fixture enables deterministic browser candidate review smoke.
  [`EditorPage.tsx:917`](../../web/src/features/editor/EditorPage.tsx#L917)

- Inspector tray styles keep state text visible in compact cards.
  [`globals.css:5226`](../../web/src/design/globals.css#L5226)

**Verification**

- Focused parser contract covers Needs review, placed, rejected, and counts.
  [`verify-editor-candidate-review.mjs:8`](../../web/scripts/verify-editor-candidate-review.mjs#L8)

- Package script exposes the focused candidate review verification.
  [`package.json:10`](../../web/package.json#L10)
