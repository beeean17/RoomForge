# CV Evaluation Fixtures

RoomForge CV evaluation uses a small JSON manifest so detection, category, placement, size, and correction-cost metrics can be compared without committing private room photos.

## Files

- Checked-in example: `editor/fixtures/cv-evaluation/manifest.example.json`
- Checked-in example result: `editor/fixtures/cv-evaluation/results.example.json`
- Validator: `editor/scripts/validate-cv-evaluation-manifest.mjs`
- Metrics harness: `editor/scripts/cv-metrics-harness.mjs`
- Default validation: `cd editor && npm run test:cv-7.1`
- Metrics validation: `cd editor && npm run test:cv-7.2`
- Local private media directory: `editor/fixtures/cv-evaluation/local/`

The `local/` directory and common room media extensions under `editor/fixtures/cv-evaluation/` are gitignored. Commit manifests and docs, not private room photos.

## Manifest Shape

Each manifest has `schemaVersion: 1` and a `fixtures` array.

Each fixture should include:

- `fixtureId`: stable local identifier.
- `room`: `widthMeters`, `depthMeters`, and `heightMeters`.
- `images`: one or more role-tagged images with `imageId`, `role`, local relative `path`, `widthPx`, and `heightPx`.
- `expectedObjects`: furniture or structural fixtures expected in the room.
- `metrics`: optional notes such as expected detection count.

Allowed image roles are `overview`, `front_wall`, `right_wall`, `back_wall`, `left_wall`, and `extra`.

## Ground Truth Fields

For each expected object:

- `objectId`: stable object label in the fixture.
- `objectType`: `furniture` or `structural_fixture`.
- `category`: expected category such as `bed`, `desk`, `chair`, `window`, or `door`.
- `visibleIn`: image roles where the object should be visible.
- `wallRole`: optional wall role for structural fixtures or wall-adjacent objects.
- `approxPositionMeters`: approximate center point in room coordinates.
- `approxSizeMeters`: approximate width, height, and depth in meters.
- `positionToleranceMeters`: acceptable placement error for metrics.
- `sizeToleranceMeters`: acceptable size error for metrics.
- `expectedCorrections`: optional rough count of manual corrections expected after browser CV output.

## Adding a Local Fixture

1. Put private photos under `editor/fixtures/cv-evaluation/local/<fixture-id>/`.
2. Copy `manifest.example.json` to a new manifest file or append a fixture entry.
3. Use relative paths like `local/my-room/front.jpg`; do not use absolute paths or URLs.
4. Record room dimensions and expected object positions in meters.
5. Run `cd editor && npm run test:cv-7.1 -- fixtures/cv-evaluation/<manifest>.json`.
6. Check `git status` before committing. Private images should remain ignored.

The manifest does not require image files to exist during validation. This keeps repository checks reproducible while allowing each developer to run private local photo sets.

## Running Metrics

Use an output JSON shaped like `results.example.json`, then run:

```bash
cd editor
npm run metrics:cv -- --manifest fixtures/cv-evaluation/manifest.example.json --results fixtures/cv-evaluation/results.example.json --out ../_bmad-output/implementation-artifacts/cv-metrics-local.json
```

The metrics report includes detection recall, category accuracy, false positive count, placement error, size error, processing time, and expected user correction count when those fields exist. If a metric has no ground truth, the report marks it `unavailable` with a reason instead of failing.

Reports are evaluation artifacts. Commit synthetic or shareable reports when useful, and keep private media local.
