# CV Provider Decision Gate

Date: 2026-06-02

This gate decides whether RoomForge stays browser-first or adds an optional SAM 3 / Cloud Run GPU provider. It is intentionally evidence-based: browser CV remains the default until local fixture metrics show that it cannot meet the project needs with user-edit fallback.

## Current Position

- Default provider: browser CV in the editor layer.
- Optional future provider: SAM 3 or another cloud GPU scene-understanding provider.
- Current decision: do not deploy Cloud GPU yet.
- Evidence source: `editor/fixtures/cv-evaluation/*.json` and generated reports such as `_bmad-output/implementation-artifacts/cv-7-2-metrics-report-2026-06-02.json`.

The current example report is synthetic and has only one fixture. It shows strong recall and placement in that fixture, but category accuracy is only `0.667` and one false positive is present. That is enough to prove the metrics harness works, not enough to justify Cloud GPU deployment.

## Metrics Inputs

Use the CV-7.2 metrics harness:

```bash
cd editor
npm run metrics:cv -- --manifest fixtures/cv-evaluation/manifest.example.json --results fixtures/cv-evaluation/results.example.json --out ../_bmad-output/implementation-artifacts/cv-metrics-local.json
```

Required metrics:

- Detection recall
- Category accuracy
- False positive count
- Placement mean error in meters
- Size mean error in meters
- Processing time
- Expected user correction count

Unavailable metrics must be reported as `unavailable`, not interpreted as pass.

## Stay Browser-First When

Use browser CV as the product default when a representative local fixture set meets all of these conditions:

- At least 5 room fixtures are evaluated, covering small bedrooms, desk rooms, cluttered rooms, and structural fixtures.
- Detection recall is at least `0.75` overall and at least `0.65` for required furniture categories used in the demo.
- Structural fixture recall for doors/windows is at least `0.60`.
- Category accuracy is at least `0.70`.
- False positives average no more than `1.0` per room.
- Placement mean error is no more than `0.75 m`.
- Size mean error is no more than `0.50 m`.
- Expected user corrections average no more than `3` per room.
- Processing time remains acceptable on the target browser device class, with median runtime under `5 s`.

If these pass, improve browser CV and UX guidance before adding GPU. User review remains part of the workflow.

## Recommend SAM 3 / Cloud GPU When

Recommend an optional cloud provider when any of these hold on representative fixtures:

- Detection recall stays below `0.70` after guided capture, wall-role placement, and depth metadata are used.
- Bed, desk, chair, wardrobe, or sofa categories fall below `0.60` recall in rooms where those objects are important.
- Doors/windows or built-in fixtures are consistently missed, below `0.50` recall.
- Category accuracy stays below `0.65`, especially when furniture categories are confused in a way that changes the editable proxy object.
- False positives exceed `2` per room or repeatedly create high-effort cleanup.
- Placement mean error exceeds `1.0 m` or size mean error exceeds `0.75 m` after metric room dimensions and depth hints are applied.
- Expected user corrections exceed `5` per room for common room layouts.
- Browser runtime or device support blocks the target demo flow.

When this threshold is crossed, Cloud GPU should be introduced as an optional provider, not as a replacement for manual review.

## Provider Contract Reuse

Future providers must reuse the current contracts:

- Capture session and image metadata flow through the editor bridge using camelCase.
- Persisted Firebase/API data remains snake_case.
- Scene-understanding outputs use candidate objects, structural fixtures, placed objects, confirmed objects, provider type, algorithm ID, model ID, confidence, quality status, and artifact refs.
- Candidate geometry stays separate from user-confirmed geometry.
- No new persisted reconstruction statuses are introduced; use existing quality/review fields and `review_required` display rules.
- The lightweight API server does not run heavy GPU inference.

Cloud GPU output should be another scene-understanding provider result that can be reviewed and edited in the same editor.

## Implementation Boundary

This gate does not select or deploy SAM 3 / Cloud GPU. Do not add:

- SAM runtime dependencies
- model weight downloads
- Cloud Run GPU services
- CUDA/ML framework dependencies in the app/editor/server
- editor-to-Firebase shortcuts that bypass the backend ownership model

The next step before any cloud provider work is to collect real local fixture metrics and compare them against the thresholds above.
