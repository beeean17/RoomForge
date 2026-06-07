# Firebase Implementation Readiness Review Inputs

## Purpose

This document prepares the input packet for the next implementation readiness
workflow. It is not an implementation readiness report and does not approve or
block the refactor by itself. The readiness workflow should use this document to
validate traceability, story order, open decisions, and stop criteria without
inventing schema, rules behavior, or validation order from scratch.

## Input Packet

Read these documents in order:

1. Product intent:
   - `docs/product/product-brief-RoomForge.md`
   - `docs/product/prd.md`
   - `docs/product/ux-design-specification.md`
   - `docs/product/ux-design-directions.html`
2. Firebase refactor context:
   - `docs/refactor/firebase-backend-refactor-plan.md`
   - `docs/refactor/firebase-ux-design-specification.md`
   - `docs/refactor/firebase-target-architecture.md`
   - `docs/refactor/firebase-data-contract.md`
3. Implementation and validation sequencing:
   - `docs/refactor/firebase-refactor-workplan.md`
   - `docs/refactor/firebase-validation-plan.md`
   - `docs/refactor/firebase-validation-runbook.md`
   - `docs/refactor/firebase-epics-and-stories.md`
4. Readiness support:
   - `docs/refactor/firebase-default-smoke-flow.md`
   - `docs/refactor/firebase-local-baseline.md`
   - `docs/refactor/firebase-admin-role-bootstrap.md`
   - `docs/refactor/README.md`

Use `docs/legacy/` only for historical comparison or explicit `legacy_api`
work.

## FB Work Package Traceability

| Work package | Stories | Readiness focus |
| --- | --- | --- |
| FB-1 Firebase Baseline | FES-1.1, FES-1.2, FES-1.3 | Emulator config, deny-by-default rules, Flutter Firebase baseline, editor no-Firebase boundary. |
| FB-2 Data Contract Models | FES-2.1, FES-2.2, FES-2.3 | Firestore/export `snake_case`, Dart/editor `camelCase`, validators, repository boundaries. |
| FB-3 Auth and Role | FES-3.1, FES-3.2, FES-3.3 | Profile projection, privileged role preservation, self-escalation denial, admin route guard. |
| FB-4 Projects and Upload | FES-4.1, FES-4.2, FES-4.3 | Owned project CRUD, dimensions, Storage upload, metadata persistence, upload recovery. |
| FB-5 Reconstruction | FES-5.1, FES-5.2, FES-5.3 | Jobs, transitions, candidate/confirmed geometry separation, floor plans, artifact refs. |
| FB-6 Layout Save/Load/Export | FES-6.1, FES-6.2, FES-6.3 | Layout cloud source of truth, furniture/editor state, export JSON, `Needs review` warning. |
| FB-7 Draft Recovery | FES-7.1, FES-7.2, FES-7.3 | IndexedDB draft/cache separation, conflict UX, no silent stream overwrite. |
| FB-8 Admin Diagnostics | FES-8.1, FES-8.2, FES-8.3 | Admin collection group access, indexes, artifact diagnostics, audited retry, append-only actions. |
| FB-9 Legacy Cutover | FES-9.1, FES-9.2, FES-9.3 | Firebase default mode, legacy adapter isolation, default smoke flow. |
| FB-10 Readiness | FES-10.1, FES-10.2, FES-10.3 | Validation runbook, source order, readiness input packet. |

## PRD Functional Traceability

| PRD group | Requirements | Firebase story coverage |
| --- | --- | --- |
| User accounts and access | FR1-FR4 | FES-1.3, FES-3.1, FES-3.2, FES-3.3, FES-8.1 |
| Room project management | FR5-FR9 | FES-4.1, FES-9.3 |
| Room input and capture guidance | FR10-FR14 | FES-4.2, FES-4.3 |
| OpenCV-assisted reconstruction workflow | FR15-FR21 | FES-5.1, FES-5.2, FES-5.3 |
| Reconstruction result and quality handling | FR22-FR28 | FES-5.1, FES-5.2, FES-5.3, FES-8.2, FES-8.3 |
| 3D room and furniture editing | FR29-FR36 | FES-6.1, FES-6.2, FES-7.3 |
| Layout persistence and export | FR37-FR40 | FES-6.1, FES-6.2, FES-6.3, FES-7.1, FES-7.2 |
| Admin operations | FR41-FR47 | FES-3.2, FES-3.3, FES-8.1, FES-8.2, FES-8.3 |
| Support and troubleshooting | FR48-FR50 | FES-5.1, FES-8.1, FES-8.2, FES-8.3 |

## PRD Non-Functional Traceability

| NFR group | Requirements | Firebase story coverage |
| --- | --- | --- |
| Performance | NFR1-NFR5 | FES-5.1, FES-6.1, FES-6.2, FES-9.3 |
| Security | NFR6-NFR10 | FES-1.1, FES-1.2, FES-3.1, FES-3.2, FES-3.3, FES-4.1, FES-4.2, FES-8.1 |
| Reliability and recoverability | NFR11-NFR15 | FES-5.1, FES-5.3, FES-7.1, FES-7.2, FES-8.2, FES-8.3 |
| Cost and resource efficiency | NFR16-NFR19 | FES-1.3, FES-5.2, FES-8.2, FES-9.1, FES-9.2 |
| Data integrity | NFR20-NFR23 | FES-2.1, FES-2.2, FES-5.1, FES-5.2, FES-6.1, FES-6.2, FES-6.3 |
| Accessibility and usability | NFR24-NFR26 | FES-4.3, FES-5.3, FES-6.3, FES-7.2, FES-7.3, FES-8.2 |

## Open Decisions and Readiness Questions

| Decision | Assigned story or source | Readiness question |
| --- | --- | --- |
| Firebase rules test harness path and language | FES-1.2, validation runbook | Are all required root `npm run test:firebase-rules:*` scripts present and mapped to validation IDs? |
| Admin role bootstrap method | FES-3.2, `firebase-admin-role-bootstrap.md` | Is the local/dev bootstrap documented, and is production role assignment explicitly scoped or deferred? |
| Source image orphan mitigation | FES-4.2 | Does the chosen implementation prevent or document recovery for Storage uploads without matching metadata? |
| Missing Firestore index errors | FES-8.1 | Are admin query/index failures surfaced as diagnostics instead of empty successful states? |
| Artifact write authority | FES-5.3, FES-8.2 | Are artifact refs readable by owners/admins without making artifact paths public? |
| Optional layout export content hash | FES-6.3 or future enhancement | If absent, is exact field round-trip validation sufficient for MVP readiness? |

## Stop Criteria Review Inputs

| Stop criterion | Expected evidence before approval |
| --- | --- |
| Data contract and architecture disagree on paths, status values, or ownership fields. | Compare `firebase-target-architecture.md` and `firebase-data-contract.md`; block on contradiction. |
| Normal users can self-write `users/{uid}.role`. | Profile/role rules tests and repository tests deny role escalation and preserve privileged fields. |
| No Firebase emulator validation path exists. | `package.json` rules scripts and `firebase-validation-runbook.md` provide executable emulator commands. |
| Editor imports Firebase or calls Firestore/Storage directly. | `npm run check:editor-firebase-boundary` passes. |
| Layout export uses unsaved IndexedDB draft as source of truth. | Layout save/load/export stories and draft recovery stories keep cloud save separate from local draft. |
| `legacy_api` remains the default backend path. | Backend binding tests and docs state Firebase default, with `legacy_api` explicit only. |
| Admin reads rely on client-side filtering rather than rules-backed authorization. | Admin rules/repository stories cover non-admin denial, admin allow, query shapes, and audit actions. |

## Readiness Workflow Checklist

- Confirm every FR1-FR50 group maps to at least one Firebase story.
- Confirm every FB-1 through FB-10 work package maps to at least one story.
- Confirm every story has at least one source document and validation layer.
- Confirm Firebase default and `legacy_api` explicit-only language is consistent across current refactor docs.
- Confirm legacy API envelope guidance is marked legacy-only.
- Confirm product PRD/UX are preserved as product sources while Firebase docs define backend refactor specifics.
- Confirm remaining open decisions are story-scoped, deferred explicitly, or promoted to readiness blockers.
