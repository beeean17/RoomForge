# RoomForge CV 코드 편집 수행 리포트

작성일: 2026-06-02
리포트 작성 시점 브랜치: `develop`
리포트 작성 시점 원격 상태: `develop...origin/develop [ahead 94]`
Push/PR 상태: push하지 않음, PR 생성하지 않음

## 1. 요약

CV scene-understanding 구현 큐를 Epic CV-1부터 CV-7까지 수행했다. 작업은 사용자가 요청한 구조를 따랐다.

- Epic 단위 브랜치를 사용했다.
- Story 단위 로컬 커밋을 생성했다.
- 각 story와 epic에 필요한 검증을 실행했다.
- Firebase/Storage rules 검증이 필요한 경우 `private` submodule 검증 스크립트를 사용했다.
- 완료된 epic 브랜치는 local `develop`에 fast-forward merge했다.

이번 구현 결과로 RoomForge는 browser-first 방 scene-understanding 파이프라인을 갖게 되었다.

1. Flutter/Firebase 기반 capture session 계약과 Android guided capture 흐름.
2. Editor-side scene-understanding provider boundary.
3. Browser CV candidate extraction, candidate tray, editable placement, structural fixture 처리.
4. Metric furniture size prior, wall-role placement, multi-photo merge, capture coverage guidance.
5. 선택적 Android ARCore depth metadata 경로와 depth-assisted placement hint.
6. CV evaluation manifest, metrics harness, SAM 3 / Cloud GPU provider decision gate.

Cloud GPU, SAM 3 runtime, heavy server inference dependency는 추가하지 않았다.

## 2. 브랜치 및 커밋 구조

### Epic 브랜치

| Epic | Branch | 상태 |
| --- | --- | --- |
| CV-1 | `epic/cv-1-capture-scene-contract-foundation` | local `develop`에 merge 완료 |
| CV-2 | `epic/cv-2-guided-android-photo-capture` | local `develop`에 merge 완료 |
| CV-3 | `epic/cv-3-candidate-tray-editable-scene` | local `develop`에 merge 완료 |
| CV-4 | `epic/cv-4-browser-scene-understanding` | local `develop`에 merge 완료 |
| CV-5 | `epic/cv-5-metric-placement-multi-photo-merge` | local `develop`에 merge 완료 |
| CV-6 | `epic/cv-6-android-arcore-depth` | local `develop`에 merge 완료 |
| CV-7 | `epic/cv-7-evaluation-provider-gate` | local `develop`에 merge 완료 |

### Story 커밋

| Story | Commit | Message |
| --- | --- | --- |
| CV-1.1 | `cd54a3a` | `feat(cv-1.1): add capture session and scene understanding contracts` |
| CV-1.2 | `8db9262` | `feat(cv-1.2): define scene understanding provider boundary` |
| CV-2.1 | `8ee0bc8` | `feat(cv-2.1): add guided capture session creation` |
| CV-2.2 | `86e5e4e` | `feat(cv-2.2): upload guided photos with roles` |
| CV-2.3 | `0aeafac` | `feat(cv-2.3): continue capture sessions in editor` |
| CV-3.1 | `984a926` | `feat(cv-3.1): add candidate and fixture scene layers` |
| CV-3.2 | `b36e87d` | `feat(cv-3.2): add candidate tray review UI` |
| CV-3.3 | `19a63c3` | `feat(cv-3.3): place and edit cv candidates` |
| CV-3.4 | `5fe6947` | `feat(cv-3.4): edit structural fixture candidates` |
| CV-4.1 | `0b8dad0` | `feat(cv-4.1): scaffold scene understanding worker` |
| CV-4.2 | `ba0880f` | `feat(cv-4.2): add browser object detector runtime` |
| CV-4.3 | `a57c7e7` | `feat(cv-4.3): persist scene understanding results` |
| CV-5.1 | `52cfcba` | `feat(cv-5.1): add furniture size priors` |
| CV-5.2 | `44b7740` | `feat(cv-5.2): estimate metric placement from wall roles` |
| CV-5.3 | `1dbfd6f` | `feat(cv-5.3): merge candidates across guided photos` |
| CV-5.4 | `9c086ed` | `feat(cv-5.4): add capture coverage guidance` |
| CV-6.1 | `5636e15` | `feat(cv-6.1): add arcore depth capability toggle` |
| CV-6.2 | `7387dd5` | `feat(cv-6.2): store arcore depth metadata` |
| CV-6.3 | `eda4654` | `feat(cv-6.3): improve placement with depth metadata` |
| CV-7.1 | `47b1466` | `test(cv-7.1): add cv evaluation fixtures manifest` |
| CV-7.2 | `ceca926` | `test(cv-7.2): add cv metrics harness` |
| CV-7.3 | `cb8849a` | `docs(cv-7.3): document cv provider decision gate` |

Submodule 커밋:

- `private` submodule: `bdf974e test(cv-6.2): add depth artifact storage rules check`

## 3. Epic별 구현 요약

### CV-1: Capture and Scene Contract Foundation

Scene understanding을 위한 데이터 계약과 provider boundary를 구현했다.

- Capture session 및 capture image 계약.
- Scene-understanding result 계약.
- Candidate, placed, confirmed, structural fixture layer.
- Browser CV와 future provider를 위한 provider metadata field.
- Snake_case persistence와 camelCase editor bridge 분리.

핵심 결과: 향후 browser CV, ARCore depth, optional cloud provider가 하나의 scene-understanding 계약을 공유할 수 있게 되었다.

### CV-2: Guided Android Photo Capture

Guided capture session 생성과 role-based photo upload 흐름을 구현했다.

- 사용자가 room dimension을 입력한 뒤 guided capture session을 생성할 수 있다.
- Guided photo가 room-role metadata와 함께 업로드된다.
- Capture session을 desktop/editor 흐름에서 이어서 사용할 수 있다.
- 일부 role upload 실패가 있어도 이미 업로드된 role은 유지된다.

핵심 결과: 하나의 불완전한 방 사진에 의존하지 않고, 여러 role-tagged room image를 수집할 수 있게 되었다.

### CV-3: Candidate Tray and Editable Scene

Editor에서 CV candidate를 검토하고 편집하는 흐름을 구현했다.

- Candidate object와 structural fixture를 confirmed user object와 분리했다.
- Candidate tray에 detected furniture/fixture, confidence, source role, review state를 표시한다.
- 사용자는 CV-derived candidate를 place, reject, reset, edit할 수 있다.
- Window/door 같은 structural fixture는 movable furniture와 별도로 표현된다.

핵심 결과: CV output이 확정값이 아니라 editable suggestion으로 다뤄진다.

### CV-4: Browser Scene Understanding

Browser-first scene-understanding 경로를 구현했다.

- Scene-understanding worker scaffold.
- Browser detector runtime selection 및 mock detector mapping.
- Guided capture image에서 candidate와 fixture output 생성.
- Scene-understanding result 저장 및 editor reload 경로.

핵심 결과: Cloud GPU 없이 browser CV가 구조화된 furniture/fixture candidate를 생성할 수 있게 되었다.

### CV-5: Metric Placement and Multi-Photo Merge

Candidate의 공간 품질을 개선했다.

- Furniture 및 fixture size prior.
- Guided image role 기반 wall-role metric placement.
- Multi-photo duplicate/conflict merge logic.
- Capture coverage guidance 및 review/failure signal.

핵심 결과: 생성된 candidate가 바로 사용할 수 있는 room layout에 더 가까운 시작점이 되며, 그래도 user review를 전제로 유지한다.

### CV-6: Android ARCore Depth

선택적 depth metadata 지원을 구현했다.

- ARCore depth capability provider 및 Android MethodChannel toggle.
- 선택적 distance metadata를 위한 guided capture UI.
- Capture image metadata에 depth artifact ref와 camera pose 추가.
- Capture-session depth artifact를 위한 owner-scoped Firebase Storage rules.
- Editor bridge를 통한 depth ref 및 camera pose 전달.
- 유효한 depth metadata가 있을 때 position/size를 보정하는 depth-assisted placement hint.

핵심 결과: 지원되는 Android 기기에서는 더 나은 placement hint를 제공할 수 있고, 지원되지 않거나 꺼진 경우에는 normal guided photo capture가 그대로 fallback으로 동작한다.

알려진 제한: `flutter build apk --debug`는 현재 web-first app entrypoint가 `dart:html` / `dart:ui_web`를 import하기 때문에 실패한다. 이는 CV-6 story에서 새로 만든 문제가 아니며 CV-6.1 completion report에 기록했다. Android build를 통과시키려면 platform-specific entrypoint 또는 conditional import 정리가 필요하다.

### CV-7: Evaluation and Provider Decision Gate

평가 및 provider decision artifact를 구현했다.

- Privacy-safe CV fixture manifest format.
- Private local room photo 및 depth artifact를 위한 `.gitignore` 보호.
- Detection recall, category accuracy, false positive, placement error, size error, processing time, expected correction count를 계산하는 metrics harness.
- Example metrics report.
- Browser-first 유지 여부와 SAM 3 / Cloud Run GPU 도입 여부를 판단하는 provider decision gate.
- SAM/Cloud GPU runtime dependency가 추가되지 않았음을 확인하는 static check.

핵심 결과: 현재는 browser-first CV를 유지하고, 측정 결과가 기준을 넘을 때만 Cloud GPU 도입을 검토할 수 있게 되었다.

## 4. 주요 수정 영역

### Flutter App

- `app/lib/main.dart`
- `app/lib/src/firebase/firebase_models.dart`
- `app/lib/src/firebase/firebase_serializers.dart`
- `app/lib/src/projects/project_api.dart`
- `app/lib/src/projects/firebase_project_api.dart`
- `app/lib/src/projects/guided_capture_session_section.dart`
- `app/lib/src/projects/arcore_depth_capability.dart`
- `app/storage.rules`
- `app/test/src/...` 하위 관련 Flutter 테스트

### Android

- `app/android/app/src/main/kotlin/com/example/app/MainActivity.kt`

### Three.js / Browser Editor

- `editor/src/captureSession.ts`
- `editor/src/scenePlacement.ts`
- `editor/src/sceneUnderstandingWorker.ts`
- `editor/src/sceneCandidateMerge.ts`
- `editor/src/sceneCoverage.ts`
- `editor/src/candidateTray.ts`
- `editor/src/fixtureModel.ts`
- `editor/src/sizePriors.ts`
- `editor/scripts/` 하위 검증 스크립트

### Evaluation and Documentation

- `editor/fixtures/cv-evaluation/manifest.example.json`
- `editor/fixtures/cv-evaluation/results.example.json`
- `editor/scripts/cv-metrics-harness.mjs`
- `docs/refactor/cv-evaluation-fixtures.md`
- `_bmad-output/planning-artifacts/cv-provider-decision-gate.md`
- `_bmad-output/implementation-artifacts/cv-*-completion-report-2026-06-02.md`

### Submodule

- `private/scripts/firebase-capture-depth-rules.mjs`

## 5. 검증 요약

작업 중 실행한 주요 검증 명령은 다음과 같다.

- `flutter analyze`
- `flutter test ...`
- `npm run typecheck`
- `npm run build`
- `npm run test:cv-2.3`
- `npm run test:cv-3.1`
- `npm run test:cv-3.2`
- `npm run test:cv-3.3`
- `npm run test:cv-3.4`
- `npm run test:cv-4.1`
- `npm run test:cv-4.2`
- `npm run test:cv-5.1`
- `npm run test:cv-5.2`
- `npm run test:cv-5.3`
- `npm run test:cv-5.4`
- `npm run test:cv-6.3`
- `npm run test:cv-7.1`
- `npm run test:cv-7.2`
- `npm run test:cv-7.3`
- `firebase emulators:exec --only auth,firestore,storage "node ../private/scripts/firebase-capture-depth-rules.mjs"`
- `bash private/scripts/check-editor-firebase-boundary.sh`
- `git diff --check`

CV-6과 CV-7의 최종 epic-level validation은 통과했다.

`npm run build`는 성공한다. 다만 Vite/OpenCV 관련 browser externalization 및 chunk-size warning이 출력된다. 이 warning은 non-fatal이며 blocking failure로 처리하지 않았다.

## 6. Evaluation Report Snapshot

생성된 metrics report:

- `_bmad-output/implementation-artifacts/cv-7-2-metrics-report-2026-06-02.json`

예시 synthetic metrics:

- Detection recall: `1.0`
- Category accuracy: `0.667`
- False positives: `1`
- Placement mean error: `0.174 m`
- Size mean error: `0.108 m`
- Processing time: `842 ms`
- Expected correction count: `3`

해석: metrics harness는 정상 동작하며, browser CV output이 user-editable suggestion이어야 하는 이유를 보여준다. 이 예시는 synthetic fixture이므로 Cloud GPU 도입을 정당화하기에는 부족하다.

## 7. 유지된 불변 조건

- Browser-first CV가 기본 경로로 유지된다.
- Heavy OpenCV/GPU inference를 lightweight API server로 옮기지 않았다.
- Firebase/API persisted field는 snake_case를 유지한다.
- Editor bridge field는 camelCase를 유지한다.
- Candidate geometry와 user-confirmed geometry는 분리되어 있다.
- Capture depth metadata는 optional이다.
- Persisted review state는 `review_required`를 사용하며, `needs_review`, `done`, `complete`, `error` job status를 추가하지 않았다.
- Editor code에 Firebase SDK import를 추가하지 않았다.
- Admin/Cloud GPU provider 작업은 metrics 기반 decision gate 뒤로 남겨두었다.

## 8. 현재 Repository 상태

리포트 작성 시점 기준:

- 현재 브랜치: `develop`
- 이 리포트 작성 전 worktree: clean
- `develop`은 `origin/develop`보다 `94` commits ahead
- Push/PR: 수행하지 않음
- Active CV epic branch들은 local에 남아 있음
- `private` submodule pointer는 `bdf974e`를 가리킨다

이 리포트 파일 자체는 명시적으로 커밋하기 전까지 추가 uncommitted documentation artifact다.

## 9. 권장 다음 단계

1. 완료된 CV epic 작업을 push할지, PR을 만들지 결정한다.
2. Android APK 테스트가 필요하다면 Android platform build 분리를 정리한다.
3. 실제 private room fixture를 `editor/fixtures/cv-evaluation/local/` 아래에 추가한다.
4. 실제 fixture에 대해 CV metrics를 실행하고 `_bmad-output/planning-artifacts/cv-provider-decision-gate.md` 기준과 비교한다.
5. 측정 결과가 문서화된 escalation threshold를 넘는 경우에만 SAM 3 / Cloud Run GPU 도입을 검토한다.
