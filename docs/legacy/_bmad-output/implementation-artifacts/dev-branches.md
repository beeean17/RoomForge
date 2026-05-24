# RoomForge Development Branches

이 문서는 BMAD Epic 단위로 개발을 진행할 때 사용할 기준 브랜치 이름을 정리한다.

## Branch Naming Rule

- Epic 단위 작업은 `feature/*` 브랜치를 사용한다.
- 각 Epic 브랜치 안에서 Story 단위 commit을 쌓는다.
- Story 구현이 커지거나 리뷰가 어려워지면 Story 전용 하위 브랜치로 분리할 수 있다.
- 모든 feature 브랜치는 `develop`에서 분기하고, 완료 후 `develop`으로 병합한다.

## Epic Branches

| Epic | Scope | Branch |
| --- | --- | --- |
| Epic 1 | Authenticated Project Workspace | `feature/auth-workspace` |
| Epic 2 | Room Photo Intake and Dimension Setup | `feature/photo-intake-dimensions` |
| Epic 3 | OpenCV-Assisted Geometry Review and Metric Reconstruction | `feature/reconstruction-mvp` |
| Epic 4 | Interactive 2D/3D Furniture Planning Editor | `feature/editor-mvp` |
| Epic 5 | Layout Persistence and Export | `feature/layout-persistence` |
| Epic 6 | Admin Operations and CV Troubleshooting | `feature/admin-ops` |

## Optional Story Branch Pattern

Story 단위 브랜치가 필요할 때는 아래 형식을 사용한다.

```text
feature/{epic-scope}/{story-id}-{short-name}
```

예시:

```text
feature/photo-intake-dimensions/2-1-photo-suitability-upload-entry
feature/photo-intake-dimensions/2-4-room-dimension-entry
feature/reconstruction-mvp/3-2-reconstruction-job-status
```

## Recommended Next Branch

Epic 1 완료 후 다음 작업 브랜치는 아래 이름을 사용한다.

```bash
git checkout develop
git pull
git checkout -b feature/photo-intake-dimensions
```
