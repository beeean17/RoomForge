# RoomForge server/ Instructions

This directory is the lightweight FastAPI / Oracle API server.

## Responsibilities

The server owns:

- Firebase token verification
- authorization
- REST API routing
- Oracle DB access through repositories
- job/status records
- layout persistence
- admin lookup
- export responses

## Current baseline

Implementation is assumed complete through Story 3.6. New server work should primarily support:

- Epic 5 layout persistence/export APIs
- Epic 6 admin operations APIs
- any small Epic 4 API contract needed for loading/persisting editor state

Do not rework reconstruction job/status APIs unless a Story 3.6 regression or prerequisite gap is found.

## Rules

- Do not run heavy OpenCV, deep-learning, or GPU inference on this server.
- Keep server modules separated into routers, schemas, services, repositories, auth, core, and db.
- Use python-oracledb for Oracle DB access.
- Keep DB access inside repository modules.
- Enforce authentication and ownership before returning user data.
- Admin APIs require admin authorization distinct from normal auth.
- API JSON fields use `snake_case`.
- DB tables/columns use `snake_case`.
- Use the shared response envelope:
  - `data`
  - `error`
  - `meta.request_id`
- Allowed persisted reconstruction statuses only:
  - `created`
  - `uploading`
  - `processing`
  - `review_required`
  - `succeeded`
  - `failed`
  - `timeout`
  - `cancelled`
  - `retrying`
- Do not persist `needs_review`.
- Save/load/export APIs must preserve layout domain fields exactly except server-managed metadata.

## Validation

Run or create placeholders for:

```bash
python -m pytest
python -m compileall app
```

For Epic 5/6 work, include ownership/admin authorization tests where feasible.
