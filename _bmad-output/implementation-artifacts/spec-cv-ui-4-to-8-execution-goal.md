---
title: 'CV-UI.4-8 Execution Goal'
type: 'goal'
created: '2026-06-07'
status: 'done'
baseline_commit: '98162a7039ded0f0cf2725d7203977c3fcd6493b'
---

# CV-UI.4-8 Execution Goal

## Objective

Complete the remaining React-owned CV editor UI work through CV-UI.8. Each story must run on its own local branch, produce one validated local commit, and be merged back into `epic/cv-final-refactor` before the next story starts.

## Fixed Architecture

- Keep `editor/` as the Three.js/OpenCV runtime package.
- Keep `web/` as the React product UI owner for editor chrome, inspector controls, candidate review, and user workflow state.
- Do not restore iframe embedding.
- Do not create a separate editor product `main`.
- React sends bridge commands; the runtime remains authoritative for scene mutation.
- Preserve candidate, placed, confirmed, and structural fixture separation.
- Do not introduce server-side heavy CV, persisted fake statuses, or API/schema changes in this UI track.

## Story Queue

| Story | Branch | Commit Message | Goal |
| --- | --- | --- | --- |
| CV-UI.4 | `story/cv-ui-4-placed-object-editing` | `feat(cv-ui.4): add react placed object editor` | React-owned placed furniture list and transform controls backed by runtime bridge commands. |
| CV-UI.5 | `story/cv-ui-5-structural-fixture-review` | `feat(cv-ui.5): add react structural fixture review` | React-owned structural fixture review and wall/category controls backed by runtime bridge commands. |
| CV-UI.6 | `story/cv-ui-6-confirmed-object-handoff` | `feat(cv-ui.6): add confirmed object handoff controls` | React-owned confirmation handoff separating candidate, placed, and confirmed scene objects. |
| CV-UI.7 | `story/cv-ui-7-responsive-a11y-hardening` | `feat(cv-ui.7): harden editor responsive accessibility` | Responsive and accessible editor controls with no hidden runtime chrome dependency. |
| CV-UI.8 | `story/cv-ui-8-final-validation-report` | `docs(cv-ui.8): finalize cv ui validation report` | Final validation, browser smoke, and documentation of the integrated CV UI architecture. |

## Validation Policy

Each implementation story must run the smallest focused contract check plus:

- `npm --prefix web run typecheck`
- `npm --prefix editor run typecheck`
- `npm --prefix web run build`
- `npm --prefix editor run build`
- `git diff --check`

Stories that change visible editor behavior must also run a browser smoke on `/projects/demo-project/editor?candidateFixture=1` and confirm:

- no iframe owns the product editor;
- exactly one Three.js canvas renders;
- React-owned controls for the story are visible;
- bridge commands emit responses or scene updates;
- console error logs are empty.

## Completion Summary

Completed locally through CV-UI.8.

| Story | Commit | Result |
| --- | --- | --- |
| CV-UI.4 | `bea4726` | React placed object editor, transform controls, and runtime furniture bridge commands. |
| CV-UI.5 | `32e7b49` | React structural fixture review, fixture candidate placement, and runtime fixture bridge commands. |
| CV-UI.6 | `7d22fbf` | React confirmation handoff and runtime confirmed object bridge commands. |
| CV-UI.7 | `0c9deed` | Responsive and accessibility hardening for React-owned CV editor panels. |
| CV-UI.8 | `this commit` | Final validation report and execution goal closure. |

Final validation is recorded in `_bmad-output/implementation-artifacts/spec-cv-ui-8-final-validation-report.md`.
