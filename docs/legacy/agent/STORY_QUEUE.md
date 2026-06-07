# RoomForge Story Queue

This queue makes the branch/goal/validation/commit loop apply consistently to every story. In auto-run mode, every item in this queue should be executed with automatic recovery and validation retries.

## Current baseline

The user has stated that implementation is complete through **Story 3.6**.

Default active queue starts at **Story 4.1**. Treat Stories 1.1 through 3.6 as baseline unless repository evidence contradicts this.

If repository evidence shows an earlier story is incomplete or regressed, use `RECOVERY_PLAYBOOK.md` first and choose one of these before continuing:

1. a focused `fix/story-x.y-...` branch, when the story was previously completed but now has a gap;
2. a retroactive `story/x.y-...` branch, when that story was never implemented;
3. a documentation-only note, when the gap is only an undocumented assumption.

Do not silently fold earlier-story fixes into a later story branch unless the fix is tiny, unavoidable, validated, and explicitly documented in the completion report.

## Active queue: remaining MVP stories

| Order | Story | Branch | Commit message | Goal source |
|---:|---|---|---|---|
| 0 | Handoff gate before Epic 4 | `story/4.1-shared-spatial-model` or review-only | no commit unless a prerequisite fix is needed | `docs/agent/GOALS.md` pre-goal gate |
| 1 | Story 4.1 - Shared Spatial Model and 2D/3D View Shell | `story/4.1-shared-spatial-model` | `feat(story-4.1): implement shared spatial model and 2d 3d view shell` | Goal 4.1 |
| 2 | Story 4.2 - 3D Room Inspection Controls | `story/4.2-3d-room-inspection-controls` | `feat(story-4.2): add 3d camera inspection controls` | Goal 4.2 |
| 3 | Story 4.3 - Add and Select Furniture Proxy Objects | `story/4.3-add-select-furniture` | `feat(story-4.3): add and select furniture proxy objects` | Goal 4.3 |
| 4 | Story 4.4 - Move, Rotate, Resize, and Delete Furniture | `story/4.4-edit-furniture` | `feat(story-4.4): edit furniture movement rotation resize and deletion` | Goal 4.4 |
| 5 | Story 4.5 - Scale, Measurement, and Placement Guidance | `story/4.5-measurement-placement-guidance` | `feat(story-4.5): add measurement labels and placement warnings` | Goal 4.5 |
| 6 | Story 4.6 - Responsive and Accessible Editor Controls | `story/4.6-responsive-accessible-editor` | `feat(story-4.6): harden responsive accessible editor controls` | Goal 4.6 |
| 7 | Story 5.1 - Save Layout with Room and Furniture State | `story/5.1-save-layout` | `feat(story-5.1): save layout with room and furniture state` | Goal 5.1 |
| 8 | Story 5.2 - Load Saved Layout | `story/5.2-load-layout` | `feat(story-5.2): load saved layout into editor state` | Goal 5.2 |
| 9 | Story 5.3 - Export Layout as JSON | `story/5.3-export-layout-json` | `feat(story-5.3): export layout as json` | Goal 5.3 |
| 10 | Story 5.4 - Save, Load, and Export Round-Trip Validation | `story/5.4-layout-round-trip-validation` | `test(story-5.4): validate save load export round trip` | Goal 5.4 |
| 11 | Story 6.1 - Admin Job List and Status Filters | `story/6.1-admin-job-list` | `feat(story-6.1): add admin job list and status filters` | Goal 6.1 |
| 12 | Story 6.2 - Admin Job Detail and Event Trail | `story/6.2-admin-job-detail` | `feat(story-6.2): add admin job detail and event trail` | Goal 6.2 |
| 13 | Story 6.3 - Admin OpenCV Artifact Viewer | `story/6.3-admin-artifact-viewer` | `feat(story-6.3): add admin opencv artifact viewer` | Goal 6.3 |
| 14 | Story 6.4 - Admin Retry Failed Jobs | `story/6.4-admin-retry` | `feat(story-6.4): add admin retry for failed jobs` | Goal 6.4 |
| 15 | Story 6.5 - Admin Search Across Users, Projects, Layouts, and Jobs | `story/6.5-admin-search` | `feat(story-6.5): add admin search across operational records` | Goal 6.5 |
| 16 | Story 6.6 - Provider State and Failure Source Diagnosis | `story/6.6-provider-failure-diagnosis` | `feat(story-6.6): add provider state and failure diagnosis` | Goal 6.6 |

## Full story registry

Use this registry when repository evidence contradicts the current baseline and an earlier story must be repaired or replayed.

| Story | Branch | Commit message |
|---|---|---|
| 1.1 - Enabler: Initial Project Setup | `story/1.1-initial-project-setup` | `chore(story-1.1): set up initial RoomForge project boundaries` |
| 1.2 - Enabler: Baseline Verification and CI Checks | `story/1.2-baseline-verification` | `chore(story-1.2): add baseline verification checks` |
| 1.3 - Google Sign-In and Sign-Out | `story/1.3-google-auth` | `feat(story-1.3): add google sign in and sign out` |
| 1.4 - Authenticated API Session Mapping | `story/1.4-auth-session-mapping` | `feat(story-1.4): map firebase identity to api user session` |
| 1.5 - User Project List and Creation | `story/1.5-project-list-create` | `feat(story-1.5): add project list and creation` |
| 1.6 - Open, Update, and Delete Own Projects | `story/1.6-project-detail-crud` | `feat(story-1.6): manage own project details` |
| 1.7 - Admin Access Boundary | `story/1.7-admin-access-boundary` | `feat(story-1.7): protect admin access boundary` |
| 2.1 - Photo Suitability Upload Entry | `story/2.1-photo-suitability` | `feat(story-2.1): add photo suitability upload guidance` |
| 2.2 - Enabler: Image Size and Retention Policy | `story/2.2-image-policy` | `chore(story-2.2): define image size and retention policy` |
| 2.3 - Source Image Upload and Metadata Persistence | `story/2.3-source-image-upload` | `feat(story-2.3): upload source image and persist metadata` |
| 2.4 - Room Dimension Entry | `story/2.4-room-dimensions` | `feat(story-2.4): capture room dimensions with units` |
| 3.1 - Spike/Enabler: Editor Bridge and OpenCV Runtime Packaging | `story/3.1-editor-bridge-opencv-runtime` | `feat(story-3.1): prove editor bridge and opencv runtime` |
| 3.2 - Reconstruction Job Creation and Status Tracking | `story/3.2-reconstruction-jobs` | `feat(story-3.2): create and track reconstruction jobs` |
| 3.3 - OpenCV Candidate Extraction and Overlay Persistence | `story/3.3-opencv-candidates` | `feat(story-3.3): extract and persist opencv candidates` |
| 3.4 - Geometry Candidate Review and Manual Correction | `story/3.4-geometry-review` | `feat(story-3.4): review and correct geometry candidates` |
| 3.5 - Metric Calibration and Floor Plan Generation | `story/3.5-metric-calibration` | `feat(story-3.5): calibrate metric floor plan` |
| 3.6 - Reconstruction Quality, Failure Guidance, and Retry | `story/3.6-reconstruction-recovery` | `feat(story-3.6): add reconstruction quality recovery and retry` |
| 4.1 - Shared Spatial Model and 2D/3D View Shell | `story/4.1-shared-spatial-model` | `feat(story-4.1): implement shared spatial model and 2d 3d view shell` |
| 4.2 - 3D Room Inspection Controls | `story/4.2-3d-room-inspection-controls` | `feat(story-4.2): add 3d camera inspection controls` |
| 4.3 - Add and Select Furniture Proxy Objects | `story/4.3-add-select-furniture` | `feat(story-4.3): add and select furniture proxy objects` |
| 4.4 - Move, Rotate, Resize, and Delete Furniture | `story/4.4-edit-furniture` | `feat(story-4.4): edit furniture movement rotation resize and deletion` |
| 4.5 - Scale, Measurement, and Placement Guidance | `story/4.5-measurement-placement-guidance` | `feat(story-4.5): add measurement labels and placement warnings` |
| 4.6 - Responsive and Accessible Editor Controls | `story/4.6-responsive-accessible-editor` | `feat(story-4.6): harden responsive accessible editor controls` |
| 5.1 - Save Layout with Room and Furniture State | `story/5.1-save-layout` | `feat(story-5.1): save layout with room and furniture state` |
| 5.2 - Load Saved Layout | `story/5.2-load-layout` | `feat(story-5.2): load saved layout into editor state` |
| 5.3 - Export Layout as JSON | `story/5.3-export-layout-json` | `feat(story-5.3): export layout as json` |
| 5.4 - Save, Load, and Export Round-Trip Validation | `story/5.4-layout-round-trip-validation` | `test(story-5.4): validate save load export round trip` |
| 6.1 - Admin Job List and Status Filters | `story/6.1-admin-job-list` | `feat(story-6.1): add admin job list and status filters` |
| 6.2 - Admin Job Detail and Event Trail | `story/6.2-admin-job-detail` | `feat(story-6.2): add admin job detail and event trail` |
| 6.3 - Admin OpenCV Artifact Viewer | `story/6.3-admin-artifact-viewer` | `feat(story-6.3): add admin opencv artifact viewer` |
| 6.4 - Admin Retry Failed Jobs | `story/6.4-admin-retry` | `feat(story-6.4): add admin retry for failed jobs` |
| 6.5 - Admin Search Across Users, Projects, Layouts, and Jobs | `story/6.5-admin-search` | `feat(story-6.5): add admin search across operational records` |
| 6.6 - Provider State and Failure Source Diagnosis | `story/6.6-provider-failure-diagnosis` | `feat(story-6.6): add provider state and failure diagnosis` |

## Queue transition rule

After a story is completed, validated, and locally committed, auto-run mode fast-forwards the local primary branch to the story commit and starts the next story from the updated primary branch. Push/PR is a separate optional remote step that requires user approval.

Never start the next story from the previous story branch. Always return to the primary branch, fast-forward locally, then create the next story branch.

```bash
git switch main
git pull --ff-only
git switch -c story/<next-story-slug>
```

If the repository primary branch is not `main`, detect and use the actual primary branch.
