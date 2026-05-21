# Current RoomForge Progress

## User-supplied baseline

The user stated that implementation is currently complete through:

```text
Story 3.6 - Reconstruction Quality, Failure Guidance, and Retry
```

This means the default next implementation target is:

```text
Story 4.1 - Shared Spatial Model and 2D/3D View Shell
```

## Completed or baseline stories

Treat these as completed unless repository evidence contradicts the claim:

- Story 1.1 - Initial project foundation
- Story 1.2 - Baseline verification and CI checks
- Story 1.3 - Google sign-in and sign-out
- Story 1.4 - Authenticated API session mapping
- Story 1.5 - User project list and creation
- Story 1.6 - Open, update, and delete own projects
- Story 1.7 - Admin access boundary
- Story 2.1 - Photo suitability upload entry
- Story 2.2 - Image size and retention policy
- Story 2.3 - Source image upload and metadata persistence
- Story 2.4 - Room dimension entry
- Story 3.1 - Editor bridge and OpenCV runtime packaging
- Story 3.2 - Reconstruction job creation and status tracking
- Story 3.3 - OpenCV candidate extraction and overlay persistence
- Story 3.4 - Geometry candidate review and manual correction
- Story 3.5 - Metric calibration and floor plan generation
- Story 3.6 - Reconstruction quality, failure guidance, and retry

## Required handoff check before Epic 4

Before implementing Story 4.1, verify these conditions from the current codebase:

- A valid metric floor plan can be created or loaded from the reconstruction flow.
- The floor plan geometry is explicitly in meters after calibration.
- Image-space geometry remains traceable separately from meter-space output.
- Reconstruction confidence/failure states are visible to the user.
- `review_required` persists and displays as `Needs review`.
- Save/export warnings exist or can be called when reconstruction needs review.
- Retry attempts link back to the original reconstruction job and preserve failure history.
- The editor bridge can receive the floor plan or a compatible scene initialization payload.

If any required handoff is missing, report it as a prerequisite gap and propose the smallest fix before continuing into Epic 4.

## Active next-story sequence

1. Story 4.1 - Shared spatial model and 2D/3D view shell
2. Story 4.2 - 3D room inspection controls
3. Story 4.3 - Add and select furniture proxy objects
4. Story 4.4 - Move, rotate, resize, and delete furniture
5. Story 4.5 - Scale, measurement, and placement guidance
6. Story 4.6 - Responsive and accessible editor controls
7. Story 5.1 - Save layout with room and furniture state
8. Story 5.2 - Load saved layout
9. Story 5.3 - Export layout as JSON
10. Story 5.4 - Save/load/export round-trip validation
11. Story 6.1 - Admin job list and status filters
12. Story 6.2 - Admin job detail and event trail
13. Story 6.3 - Admin OpenCV artifact viewer
14. Story 6.4 - Admin retry failed jobs
15. Story 6.5 - Admin search across users, projects, layouts, and jobs
16. Story 6.6 - Provider state and failure source diagnosis

## Do not do by default

- Do not restart from Story 1.1.
- Do not rebuild Epic 2 or Epic 3 unless a failing check reveals a prerequisite gap.
- Do not merge all remaining work into one large Goal.
- Do not implement Epic 5 before the shared spatial model is stable.
- Do not implement Epic 6 admin artifact views before the relevant artifacts exist.

## Default branch for next story

For the next implementation target, use:

```text
story/4.1-shared-spatial-model
```

After Story 4.1 is validated, committed, reviewed, and merged, start Story 4.2 from the updated primary branch rather than continuing on the Story 4.1 branch.
