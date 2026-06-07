---
title: 'CV-UI.7 Responsive Accessibility Hardening'
type: 'feature'
created: '2026-06-07'
status: 'done'
baseline_commit: '7d22fbfcac413e0e71c0f8a0d2d1e62bfd8306fb'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/spec-cv-ui-4-to-8-execution-goal.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-cv-ui-6-confirmed-object-handoff.md'
  - '{project-root}/architecture.md'
---

# CV-UI.7 Responsive Accessibility Hardening

## Intent

The React-owned editor inspector now contains candidate review, placed object editing, structural fixture review, and confirmation handoff controls. This story hardens those controls for responsive desktop widths and best-effort accessibility.

## Boundaries

No new CV logic, persistence behavior, or product workflow state is added. This story only changes React semantics, CSS responsive/focus behavior, and focused validation.

## Tasks & Acceptance

- [x] `web/src/features/editor/EditorPage.tsx` adds live semantics to changing count/status groups.
- [x] `web/src/design/globals.css` adds focus-visible styles, stable wrapping, and narrow breakpoint grids for CV UI panels.
- [x] `web/scripts/verify-editor-responsive-a11y.mjs` validates the responsive/a11y contract.
- [x] Validation and browser smoke pass.

Acceptance criteria:

- Given runtime counts change, candidate/placed/fixture/confirmation count groups expose polite live updates.
- Given keyboard focus lands on new React-owned cards or action buttons, visible focus is present.
- Given the editor is viewed at a narrow desktop/tablet width, toolbar rows wrap and inspector control grids collapse instead of overflowing horizontally.
- Given mobile web is not fixture-overridden, the existing mobile gate remains intact.
- Given browser smoke runs with `desktopFixture=1`, no incoherent overlap or horizontal document overflow is detected.

## Verification Plan

- `npm --prefix web run test:editor-a11y`
- `npm --prefix web run typecheck`
- `npm --prefix editor run typecheck`
- `npm --prefix web run build`
- `npm --prefix editor run build`
- `git diff --check`
- Browser smoke on `/projects/demo-project/editor?candidateFixture=1&desktopFixture=1`.

## Completion Notes

- Added `aria-live="polite"` to candidate, placed object, structural fixture, and confirmation count groups.
- Added focus-visible styles for React-owned object cards, fixture cards, candidate controls, transform inputs, selects, and confirmation actions.
- Hardened runtime toolbar wrapping and inspector overscroll behavior.
- Added narrow breakpoint rules that collapse inspector metadata/action grids to one column and avoid horizontal document overflow.
- Added `test:editor-a11y` to validate the responsive/a11y CSS and ARIA contract.

## Validation Results

- Passed: `npm --prefix web run test:editor-a11y`
- Passed: `npm --prefix web run typecheck`
- Passed: `npm --prefix editor run typecheck`
- Passed: `npm --prefix web run build`
- Passed: `npm --prefix editor run build`
- Passed: `git diff --check`
- Passed: browser smoke on `http://127.0.0.1:9243/projects/demo-project/editor?locale=ko&candidateFixture=1&desktopFixture=1`; in-app browser width was `461px`, `iframeCount = 0`, `canvasCount = 1`, all four React CV panels rendered, all four count groups had `aria-live = polite`, toolbar `flex-wrap = wrap`, inspector overscroll was `contain`, `scrollWidth = clientWidth = 461`, and console error logs were empty.
- Smoke screenshot: `/private/tmp/roomforge-cv-ui-7-responsive-a11y-smoke.png`

## Suggested Review Order

- ARIA live count groups: `web/src/features/editor/EditorPage.tsx`
- Responsive/focus CSS: `web/src/design/globals.css`
- Focused verification: `web/scripts/verify-editor-responsive-a11y.mjs`
