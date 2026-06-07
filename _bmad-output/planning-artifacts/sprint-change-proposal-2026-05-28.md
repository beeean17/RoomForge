# Sprint Change Proposal: Real OpenCV Candidate Extraction Gap

Date: 2026-05-28
Project: RoomForge
Prepared by: Codex / BMad Correct Course

## 1. Issue Summary

RoomForge is positioned as a computer-vision-centered room reconstruction and furniture planning app. The PRD defines the MVP computer vision feature as OpenCV-assisted room geometry extraction and metric calibration from a source room photo, including edge detection, dominant line detection, corner candidate extraction, optional perspective or homography reasoning, user correction, and metric floor-plan generation.

Repository inspection shows that the current implementation has strong product scaffolding for this workflow, but the actual OpenCV execution is still a stub:

- `editor/public/opencv/opencv-runtime-manifest.json` declares `mode: "mvp-browser-worker-stub"`.
- `editor/public/opencv/opencv.js` and `editor/public/opencv/opencv.wasm` are placeholders.
- `editor/src/opencvWorker.ts` only fetches runtime assets and reports load success or failure.
- `editor/src/main.ts` emits a hard-coded candidate geometry and confidence score instead of processing an uploaded source image.
- Server and Firebase persistence support OpenCV result records, confirmed geometry, and floor plans, but they store externally supplied payloads rather than producing CV results.

The trigger is an acceptance gap in the previously assumed-complete reconstruction stories, especially:

- Story 3.3: OpenCV Candidate Extraction and Overlay Persistence.
- Story 3.5: Metric Calibration and Floor Plan Generation.

This is not a product pivot. It is a correction needed to make the existing product direction true in implementation.

## 2. Impact Analysis

### Epic Impact

Epic 3 is the directly affected epic. Its current acceptance intent remains valid, but Story 3.3 and part of Story 3.5 require a focused implementation fix before the project can honestly claim OpenCV-centered reconstruction.

Epic 4 through Epic 6 remain valid. However, later editor, layout, and admin stories depend on real candidate geometry and artifacts. Continuing with only hard-coded candidate geometry would weaken:

- 2D/3D editor credibility.
- Layout save/export source metadata.
- Admin OpenCV artifact inspection.
- Provider/failure-source diagnosis.
- Computer vision evaluation materials.

### Story Impact

Affected completed-baseline stories:

- Story 3.3 needs a fix story or replay to replace hard-coded candidate output with actual image-based OpenCV candidate extraction.
- Story 3.5 needs either a small extension or a follow-up story to compute and record calibration assumptions from confirmed image-space geometry and user-provided metric dimensions.

Future stories should not be resequenced permanently, but implementation should pause the remaining queue until this gap is closed. Otherwise Story 6.3 and Story 6.6 would inspect or diagnose fake artifacts.

### Artifact Conflicts

No PRD goal needs to be reduced. The PRD already requires OpenCV-assisted line, edge, corner detection, metric calibration, quality states, and evaluation artifacts.

Architecture remains compatible. It already assigns OpenCV candidate extraction to the browser/editor layer and keeps heavy CV off the lightweight API server.

UX remains compatible. It already expects source-image overlays, candidate geometry, confirmed geometry, confidence/review states, and recovery paths.

The conflict is between implementation reality and the existing artifacts, not between artifacts themselves.

### Technical Impact

The implementation must add a real browser/editor OpenCV path without moving CV work into the server:

- Load a real OpenCV.js runtime or a locally vendored equivalent.
- Send uploaded source image data or URL metadata from Flutter to the editor bridge.
- Decode the source image in the editor or worker.
- Run explainable CV steps in a Web Worker.
- Emit candidate edges, lines, corners, boundary candidates, confidence, and failure reasons.
- Persist candidate geometry separately from confirmed geometry.
- Keep coordinate spaces explicit: image pixels before calibration, meters after calibration.
- Add tests or fixtures proving the candidate extraction path is no longer hard-coded.

## 3. Recommended Approach

Recommended path: Direct Adjustment.

Scope classification: Moderate, but implementable as a focused Developer story.

Rationale:

- The product direction is sound and does not require a PRD or architecture rewrite.
- Existing persistence and bridge contracts give the fix a clear integration point.
- Rolling back later editor/admin work would not simplify the problem.
- Reducing MVP scope would undermine the project's intended computer vision value.

The best correction is a focused prerequisite story before continuing the remaining queue:

`fix/story-3.3-real-opencv-candidate-extraction`

This story should repair the baseline by replacing the OpenCV stub with real candidate extraction and by making the output inspectable and persistable.

## 4. Detailed Change Proposals

### Story Change: Story 3.3

Section: Acceptance Criteria

OLD:

- The editor produces candidate edges, lines, corners, or boundary hints.
- Candidate geometry is stored separately from confirmed geometry.
- Candidate overlays are visually distinct from confirmed geometry.

NEW:

- Given a source image is available in the editor, when OpenCV candidate extraction runs, then the editor worker processes actual image data rather than returning hard-coded candidate geometry.
- Given extraction succeeds, then the worker emits image-pixel candidate edges, dominant lines, corner candidates, at least one room-boundary candidate where possible, confidence, algorithm metadata, and source image dimensions.
- Given extraction cannot produce a usable boundary, then the worker emits a failed or review-required result with machine-readable reason codes such as `no_source_image`, `weak_edges`, `insufficient_lines`, `insufficient_corners`, or `low_confidence`.
- Given candidate geometry is emitted, then Flutter persists it under `opencv_results` and never merges it into `confirmed_geometries`.
- Given the editor displays candidates, then source image, candidate overlay, and confirmed geometry remain visually distinct using non-color-only treatment.
- Given tests inspect the candidate extraction path, then no production path may use the old hard-coded candidate geometry as the normal result.

Rationale:

This restores the original Story 3.3 intent and makes the computer vision contribution real enough for evaluation and demonstration.

### Story Change: Story 3.5

Section: Acceptance Criteria

OLD:

- The system generates a meter-space floor plan from confirmed geometry and room dimensions.
- Perspective assumptions and metric output are recorded.

NEW:

- Given confirmed image-space boundary points and user-provided metric dimensions, when calibration runs, then the system records image-space input geometry, meter-space output geometry, reference line or dimension anchor, and the perspective model or rectangular-room assumption used.
- Given a rectangular-room input is valid, then generated metric width and depth target <= 5% deviation from user-entered dimensions.
- Given calibration cannot produce a trustworthy floor plan, then the result is `review_required` or `failed` with a calibration-specific reason.

Rationale:

The MVP may keep a rectangular-room model, but it must make the image-to-meter handoff explicit and traceable rather than appearing as a generic dimensions-only rectangle.

### Architecture Note

No architecture rewrite is needed. Add an implementation note to the reconstruction/editor section:

- OpenCV extraction must run in the editor worker using browser-side image data.
- The worker owns low-level CV operations.
- Flutter owns persistence of candidate, confirmed, and floor-plan records.
- Server APIs and Firebase repositories remain persistence and authorization layers only.

### UX Note

No UX redesign is needed. The existing OpenCV review screen direction should be preserved, with one clarification:

- The review surface must show whether candidates came from actual source-image extraction, fixture/demo mode, or manual fallback.

## 5. Implementation Handoff

Handoff target: Developer agent.

Recommended next BMAD workflow:

1. Create Story: `fix/story-3.3-real-opencv-candidate-extraction`.
2. Validate Story.
3. Dev Story.
4. Code Review.
5. QA Automation Test for the source image to candidate to confirmation to floor-plan path.

Success criteria:

- OpenCV worker processes real image input.
- Hard-coded candidate geometry is only available as an explicit fixture/demo fallback, not the normal extraction path.
- Candidate payload includes image dimensions, coordinate space, candidate sets, confidence, algorithm ID, and failure/review reasons.
- Flutter/editor bridge handles candidate extraction messages and persistence handoff.
- Confirmed geometry remains separate from candidate geometry.
- Calibration output remains meter-space and records assumptions.
- At least one automated or fixture-driven validation proves candidate extraction is data-dependent.

## 6. Checklist Completion

- [x] 1.1 Trigger story identified: Story 3.3, with Story 3.5 partial impact.
- [x] 1.2 Core problem defined: implementation acceptance gap, not product pivot.
- [x] 1.3 Evidence collected: worker/runtime stubs, hard-coded candidate geometry, persistence-only backend.
- [x] 2.1 Current epic assessed: Epic 3 remains valid but needs correction.
- [x] 2.2 Epic changes: no new epic required.
- [x] 2.3 Future epics reviewed: Epic 4-6 remain valid but depend on truthful CV artifacts.
- [x] 2.4 No planned epic is invalidated.
- [x] 2.5 No permanent resequencing needed beyond prerequisite fix.
- [x] 3.1 PRD conflict checked: no conflict, PRD already requires this.
- [x] 3.2 Architecture conflict checked: no conflict, browser/editor worker path is already specified.
- [x] 3.3 UX conflict checked: no conflict, review UI already expects real candidates and overlays.
- [x] 3.4 Secondary artifacts noted: sprint status and story tracking are stale/misaligned.
- [x] 4.1 Direct adjustment selected as viable.
- [x] 4.2 Rollback rejected.
- [x] 4.3 MVP reduction rejected.
- [x] 4.4 Recommended path selected.
- [x] 5.1 Issue summary complete.
- [x] 5.2 Epic and artifact impact complete.
- [x] 5.3 Recommended path complete.
- [x] 5.4 MVP impact and action plan complete.
- [x] 5.5 Agent handoff plan complete.
- [x] 6.1 Checklist reviewed.
- [x] 6.2 Proposal reviewed for consistency.
- [!] 6.3 User approval required before implementation.
- [!] 6.4 Sprint status update deferred until approval.
- [x] 6.5 Next steps and handoff plan defined.
