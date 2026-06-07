# CV Final Runtime Evaluation Report

Date: 2026-06-07
Story: CV-R3.1 - CV Runtime Evaluation Gate
Branch: `story/cv-r3.1-cv-runtime-evaluation-gate`

## Scope

This report validates the final CV refactor implementation path introduced by
`docs/refactor/cv-final-refactor-development-plan.md`.

The evaluated path is:

```text
React web editor host
-> editor iframe bridge
-> private source image handoff
-> OpenCV boundary extraction
-> scene understanding candidate generation
-> candidate/fixture review surfaces
-> host-side Firebase persistence mapping
```

## Result

Status: PASS_WITH_AUTH_LIMITED_BROWSER_SMOKE

Browser-first CV remains the MVP path. The current implementation now connects
React web hosting, editor bridge initialization, source image byte handoff, CV
event persistence mapping, and an image-driven scene proposal provider.

The provider is still a browser-first proposal provider, not a high-confidence
semantic detector. It derives furniture/fixture proposals from source image
bytes and dimensions when no configured detector output is supplied, then relies
on candidate review and user correction. This matches the current MVP decision:
do not add SAM, Cloud GPU, or a heavyweight API-server inference path until
fixture metrics justify it.

## Commands Run

```bash
npm --prefix editor run test:cv-7.1
npm --prefix editor run test:cv-7.2
npm --prefix editor run test:cv-7.3
npm --prefix web run build
npm --prefix editor run build
```

All commands passed.

Observed non-fatal warnings:

- `web` Vite build reports a chunk-size warning.
- `editor` Vite build reports OpenCV.js worker chunk size and browser
  externalization warnings for Node builtins imported by `@techstark/opencv-js`.

These warnings were already expected for the OpenCV.js bundle and did not fail
the build.

## Browser Smoke

Local servers:

```text
editor: http://127.0.0.1:9239/
web:    http://127.0.0.1:9241/  (9240 was already in use)
```

Checks:

- Direct editor runtime loaded at `http://127.0.0.1:9239/?locale=ko`.
- DOM contained the RoomForge editor shell, OpenCV status, and candidate tray.
- Web hosted route `http://127.0.0.1:9241/projects/demo-project/editor` redirected
  to the login page because this local environment has Firebase web config
  active and the route is protected by `RequireAuth`.

Hosted route bridge smoke was therefore auth-limited in this run. The route
guard behavior is correct, but iframe bridge initialization could not be
visually verified without signing into the configured Firebase project.

## Acceptance Evidence

- Fixture manifest validation passed.
- Metrics harness contract validation passed.
- Provider decision gate validation passed.
- Web production build passed with the React host, Firebase source-image handoff,
  and event persistence mapper included.
- Editor production build passed with OpenCV worker and image-driven scene
  proposal worker included.
- Direct editor runtime rendered the candidate tray and OpenCV status.

## Provider Decision

Keep browser-first CV for MVP.

Reasons:

- The editor runtime and OpenCV worker build locally.
- The scene understanding worker now has three paths:
  - deterministic `detectorOutput` for tests;
  - WebGPU/WASM model-asset boundary for future model providers;
  - source-image-driven browser proposal fallback for current MVP.
- User correction remains the primary fallback for false positives, missed
  objects, and weak placement.
- No current fixture evidence requires Cloud GPU or SAM.

Open a future model-provider story only after private fixtures show that the
browser proposal path cannot meet target review/correction thresholds.

## Remaining Gaps

- Hosted editor browser smoke needs a signed-in Firebase session or a deliberate
  local demo-auth test mode.
- Source image Storage reads were type/build validated but not exercised against
  a live owned Firebase project in this run.
- The image-driven provider proposes editable candidates; it is not yet a
  production-grade semantic furniture detector.
- A larger private fixture set is still needed. Current validation found one
  manifest file; the earlier provider gate recommendation targets at least five
  real room fixture sets before deciding on Cloud GPU/SAM.
