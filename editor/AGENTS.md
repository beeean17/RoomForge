# RoomForge editor/ Instructions

This directory is the Three.js / TypeScript spatial editor.

## Responsibilities

The editor owns:

- source-image alignment
- OpenCV overlays
- geometry handles
- 2D/3D rendering
- camera behavior
- furniture manipulation
- spatial validation
- Flutter bridge messages

## Current baseline

Implementation is assumed complete through Story 3.6. The editor should now move from reconstruction review into the planning editor sequence:

1. shared spatial model and 2D/3D shell
2. camera controls
3. furniture add/select
4. furniture move/rotate/resize/delete
5. measurement and placement guidance
6. responsive/accessibility hardening

Before Story 4.1 implementation, confirm the editor receives or can load a valid metric floor plan from the reconstruction flow. If no metric floor plan handoff exists, report the missing prerequisite.

## Rules

- Run OpenCV candidate extraction in the browser/editor layer, preferably with OpenCV.js in a Web Worker.
- Do not call Oracle APIs directly from rendering modules.
- Keep candidate geometry separate from confirmed geometry.
- Bridge messages use:
  - `type`
  - `version`
  - `payload`
  - optional `requestId`
- Editor bridge fields use `camelCase`.
- Geometry must state coordinate space:
  - image pixels before calibration
  - meters after calibration
- Candidate overlays must be visually distinct from confirmed geometry using non-color-only treatment.
- Invalid geometry must block progression for fewer than three corners, open boundaries, or self-intersections.
- 2D and 3D views must derive from one shared spatial model.
- View switching must preserve selection, object identity, metric coordinates, scale, and unsaved state.
- Keep visible selection, reset/preset controls, and textual summaries where feasible.

## Validation

Run or create placeholders for:

```bash
npm run typecheck
npm run build
npm test
```

For Epic 4 work, verify:

- 2D/3D state synchronization
- selection persistence across view switches
- camera reset and preset availability
- non-color-only selected/warning states
- local editor update target where feasible
- 30 FPS target where feasible for MVP-scale scenes
