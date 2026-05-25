# Firebase Refactor Documentation Index

## Current Decision

Firebase is the default RoomForge backend path. The default application path
uses Firebase Auth, Cloud Firestore, Cloud Storage for Firebase, Firebase
Security Rules, and local IndexedDB draft/cache support. The legacy FastAPI and
Oracle path remains reference code only and must be selected explicitly with
`legacy_api`.

Legacy API response envelopes using `data`, `error`, and `meta.request_id`
apply only to the legacy FastAPI API. Direct Firebase repository calls do not
use that envelope.

## Source-of-Truth Order

Use this order when starting a Firebase refactor story:

1. Product intent:
   - [Product Brief](../product/product-brief-RoomForge.md)
   - [Product PRD](../product/prd.md)
   - [Product UX Specification](../product/ux-design-specification.md)
   - [Product UX Directions](../product/ux-design-directions.html)
2. Firebase refactor direction:
   - [Firebase Backend Refactor Plan](firebase-backend-refactor-plan.md)
   - [Firebase UX Design Specification](firebase-ux-design-specification.md)
3. Technical source of truth:
   - [Firebase Target Architecture](firebase-target-architecture.md)
   - [Firebase Data Contract](firebase-data-contract.md)
4. Implementation sequencing and validation:
   - [Firebase Refactor Workplan](firebase-refactor-workplan.md)
   - [Firebase Validation Plan](firebase-validation-plan.md)
   - [Firebase Validation Runbook](firebase-validation-runbook.md)
   - [Firebase Epics and Stories](firebase-epics-and-stories.md)
5. Story gate and support references:
   - [Firebase Default Smoke Flow](firebase-default-smoke-flow.md)
   - [Firebase Local Baseline](firebase-local-baseline.md)
   - [Firebase Admin Role Bootstrap](firebase-admin-role-bootstrap.md)
   - [Firebase Readiness Review Inputs](firebase-readiness-review-inputs.md)
   - [Firebase Implementation Readiness Report](firebase-implementation-readiness-report.md)

If product PRD or product UX still mention Oracle or the old API server, treat
that as product-era context. For Firebase refactor implementation, the Firebase
architecture, data contract, workplan, validation plan, and epics define the
backend default.

## Legacy Documents

Historical Oracle/FastAPI planning and implementation artifacts live under
`docs/legacy/`. They are useful for reference, but they are not the current
default implementation plan.

Do not resume new Firebase work from:

- `docs/legacy/_bmad-output/planning-artifacts/`
- `docs/legacy/_bmad-output/implementation-artifacts/`
- `docs/legacy/agent/`

Use those documents only when intentionally working in explicit `legacy_api`
mode or comparing previous behavior.

## Story Startup Checklist

Before editing code for a Firebase story:

- Confirm the target story in [Firebase Epics and Stories](firebase-epics-and-stories.md).
- Read the relevant sections of [Firebase Target Architecture](firebase-target-architecture.md) and [Firebase Data Contract](firebase-data-contract.md).
- Select validation commands from [Firebase Validation Runbook](firebase-validation-runbook.md).
- Confirm the editor remains Firebase-free.
- Confirm persisted fields and export JSON stay `snake_case`.
- Confirm editor bridge payloads stay `camelCase`.
- Confirm `review_required` remains the persisted status and displays as `Needs review`.
- Confirm `legacy_api` remains explicit only.
