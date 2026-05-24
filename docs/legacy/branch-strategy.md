# RoomForge Branch Strategy

RoomForge는 BMAD Story를 그대로 브랜치로 쪼개기보다, 실무에서 리뷰와 통합이 쉬운 **feature branch 단위**로 묶고 각 브랜치 안에서 Story를 commit/PR checklist로 추적한다.

## Branch Model

```text
main
develop
feature/*
spike/*
fix/*
chore/*
```

- `main`: 안정 버전. 배포 가능한 상태만 유지한다.
- `develop`: feature/spike 브랜치가 통합되는 기본 개발 브랜치.
- `feature/*`: 사용자 가치가 있는 기능 묶음. 여러 BMAD Story를 포함할 수 있다.
- `spike/*`: 기술 검증용 브랜치. 검증 후 feature 작업에 반영한다.
- `fix/*`: 통합 또는 리뷰 중 발견한 버그 수정.
- `chore/*`: CI, 설정, 문서, 개발환경 등 기능 외 작업.

## Recommended Branches and Stories

### 1. Project Foundation

```text
branch: feature/project-foundation
```

- 1.1 Enabler - Set Up Initial Project from Minimal Official Starters
- 1.2 Enabler - Baseline Verification and CI Checks

### 2. Auth Workspace

```text
branch: feature/auth-workspace
```

- 1.3 Google Sign-In and Sign-Out
- 1.4 Authenticated API Session Mapping
- 1.5 User Project List and Creation
- 1.6 Open, Update, and Delete Own Projects
- 1.7 Admin Access Boundary

### 3. Photo Intake

```text
branch: feature/photo-intake
```

- 2.1 Photo Suitability Upload Entry
- 2.2 Enabler - Image Size and Retention Policy
- 2.3 Source Image Upload and Metadata Persistence
- 2.4 Room Dimension Entry

### 4. OpenCV Runtime Spike

```text
branch: spike/opencv-runtime
```

- 3.1 Spike/Enabler - Editor Bridge and OpenCV Runtime Packaging

### 5. Reconstruction MVP

```text
branch: feature/reconstruction-mvp
```

- 3.2 Reconstruction Job Creation and Status Tracking
- 3.3 OpenCV Candidate Extraction and Overlay Persistence
- 3.4 Geometry Candidate Review and Manual Correction
- 3.5 Metric Calibration and Floor Plan Generation
- 3.6 Reconstruction Quality, Failure Guidance, and Retry

### 6. Editor MVP

```text
branch: feature/editor-mvp
```

- 4.1 Shared Spatial Model and 2D/3D View Shell
- 4.2 3D Room Inspection Controls
- 4.3 Add and Select Furniture Proxy Objects
- 4.4 Move, Rotate, Resize, and Delete Furniture
- 4.5 Scale, Measurement, and Placement Guidance
- 4.6 Responsive and Accessible Editor Controls

### 7. Layout Persistence

```text
branch: feature/layout-persistence
```

- 5.1 Save Layout with Room and Furniture State
- 5.2 Load Saved Layout
- 5.3 Export Layout as JSON
- 5.4 Validation - Save, Load, and Export Round-Trip Validation

### 8. Admin Ops

```text
branch: feature/admin-ops
```

- 6.1 Admin Job List and Status Filters
- 6.2 Admin Job Detail and Event Trail
- 6.3 Admin OpenCV Artifact Viewer
- 6.4 Admin Retry Failed Jobs
- 6.5 Admin Search Across Users, Projects, Layouts, and Jobs
- 6.6 Provider State and Failure Source Diagnosis

## Recommended Merge Order

```text
feature/project-foundation
feature/auth-workspace
feature/photo-intake
spike/opencv-runtime
feature/reconstruction-mvp
feature/editor-mvp
feature/layout-persistence
feature/admin-ops
```

This order keeps the dependency chain sane: scaffold first, then auth/project ownership, then input data, then OpenCV feasibility, then reconstruction/editor/layout/admin workflows.

## PR Checklist Template

Use the PR checklist to keep BMAD Story traceability inside larger feature branches.

```md
## BMAD Stories

- [ ] 1.3 Google Sign-In and Sign-Out
- [ ] 1.4 Authenticated API Session Mapping
- [ ] 1.5 User Project List and Creation

## Verification

- [ ] Tests pass
- [ ] Manual flow checked
- [ ] `sprint-status.yaml` updated if story status changed
```

## Commit Message Convention

Prefer one BMAD Story per meaningful commit when practical.

```text
story 1.3: add google sign-in and sign-out
story 1.4: map firebase token to api session
story 1.5: add project list and creation
fix auth: handle expired firebase token
chore ci: add baseline verification workflow
```

## When to Split Further

Split a feature branch into smaller Story branches if:

- the PR becomes hard to review,
- the branch cannot be merged within a few days,
- multiple people need to work in the same area at once,
- one Story blocks unrelated Stories,
- database/API/editor changes start creating risky conflicts.

High-risk areas such as OpenCV geometry, Flutter-to-Three.js bridge behavior, authorization boundaries, and layout round-trip persistence should stay especially small and reviewable.
