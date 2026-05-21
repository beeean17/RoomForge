# RoomForge app/ Instructions

This directory is the Flutter app shell.

## Responsibilities

Flutter owns:

- app routing
- auth state
- project screens
- upload UI
- reconstruction workflow UI
- inspector panels
- admin UI
- accessible controls
- API calls

## Current baseline

Implementation is assumed complete through Story 3.6. For new work, the app layer should primarily support Epic 4, Epic 5, and Epic 6 UI surfaces unless a previous-story defect is explicitly found.

Default next app responsibilities:

- Story 4.1: app/editor route shell, view switch controls, inspector entry point, status area
- Story 4.2: accessible camera preset controls and reduced-motion handling
- Story 4.3: Flutter-controlled inspector selection summary for furniture objects
- Story 4.4: inspector fields and destructive action confirmation
- Story 4.5: measurement/placement warning summaries
- Story 4.6: responsive/accessibility hardening
- Epic 5: save/load/export UI states
- Epic 6: admin UI surfaces

## Rules

- Use Material 3 as the baseline UI system.
- Use Riverpod for app state and async API state.
- Use go_router for routing and deep-link structure.
- Keep Three.js rendering and OpenCV detector internals out of Flutter widgets.
- Non-canvas controls target WCAG 2.2 AA.
- User-facing `review_required` copy is `Needs review`.
- Do not create a separate persisted `needs_review` enum.
- API serialization maps to `snake_case`.
- API responses must be handled through `data`, `error`, `meta.request_id`.
- For editor and admin states, expose textual summaries where feasible so canvas-only state is not the only accessible source of truth.

## Validation

Run or create placeholders for:

```bash
flutter analyze
flutter test
```

When the story touches responsive/accessibility behavior, also verify desktop, tablet, and mobile-review layouts manually or with widget tests where feasible.
