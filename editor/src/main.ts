import * as THREE from 'three'

import './style.css'
import {
  BRIDGE_VERSION,
  isBridgeMessage,
  postBridgeMessage,
  type BridgePayload,
  type BridgeMessage,
} from './bridge'
import {
  cameraSnapshotForRoom,
  isCameraAction,
  shouldAnimateCamera,
  type CameraAction,
  type CameraSnapshot,
} from './cameraControls'
import {
  captureRoleSummary,
  captureSessionFromBridgePayload,
  type CaptureSessionForSceneUnderstanding,
} from './captureSession'
import {
  candidateCategoryOptions,
  candidateTrayItems,
  placeCandidateInModel,
  releaseCandidatePlacementInModel,
  rejectCandidateInModel,
  updateCandidateCategoryInModel,
} from './candidateTray'
import {
  addFurnitureToModel,
  editSelectedFurnitureInModel,
  furnitureDefaults,
  selectedFurniture as selectedFurnitureFromModel,
  selectedFurnitureSummary,
  selectionVisualTokens,
  selectFurnitureInModel,
  type FurnitureEditAction,
} from './furnitureModel'
import {
  editSelectedFixtureInModel,
  selectFixtureInModel,
  selectedFixture as selectedFixtureFromModel,
  selectedFixtureSummary,
  type FixtureEditAction,
} from './fixtureModel'
import {
  furnitureOutsideRoom,
  measurementSummaryForModel,
  placementWarningForModel,
} from './measurementGuidance'
import {
  computeSceneCoverage,
  coverageGuidanceText,
  type SceneCoverageSummary,
} from './sceneCoverage'
import { applyMetricPlacementToCandidates } from './scenePlacement'
import {
  defaultSpatialModel,
  roomBounds,
  spatialModelFromBridgePayload,
  type FurnitureCategory,
  type FurnitureObject,
  type SpatialModel,
  type StructuralFixtureObject,
  type ViewMode,
} from './spatialModel'
import { furnitureSizePriorForCategory } from './sizePriors.ts'

const app = document.querySelector<HTMLDivElement>('#app')

if (!app) {
  throw new Error('Missing editor root element.')
}

const localeOverride = new URLSearchParams(window.location.search).get('locale')?.toLowerCase() ?? ''
const usesKorean = localeOverride.startsWith('ko') || navigator.language.toLowerCase().startsWith('ko')
const t = (english: string, korean: string): string => (usesKorean ? korean : english)

const catalogFurnitureItems: Array<{
  category: FurnitureCategory
  label: string
  labelKo: string
  note: string
  noteKo: string
}> = [
  { category: 'bed', label: 'Bed', labelKo: '침대', note: 'sleep zone', noteKo: '수면 영역' },
  { category: 'desk', label: 'Desk', labelKo: '책상', note: 'work surface', noteKo: '작업면' },
  { category: 'chair', label: 'Chair', labelKo: '의자', note: 'seating', noteKo: '좌석' },
  { category: 'wardrobe', label: 'Storage', labelKo: '수납장', note: 'wall aligned', noteKo: '벽면 정렬' },
]

const furnitureCatalogMarkup = catalogFurnitureItems
  .map((item) => {
    const prior = furnitureSizePriorForCategory(item.category)
    const label = t(item.label, item.labelKo)
    const note = t(item.note, item.noteKo)
    return `<button class="obj-tile" type="button" data-furniture-category="${item.category}">
      <strong>${label}</strong>
      <span>${prior.size.widthMeters.toFixed(1)} x ${prior.size.depthMeters.toFixed(1)} m</span>
      <small>${note}</small>
    </button>`
  })
  .join('')

app.innerHTML = `
<section class="editor-shell">
  <header class="editor-topbar" aria-label="${t('Editor top bar', '편집기 상단 바')}">
    <div class="editor-project">
      <strong>${t('Bedroom remodel', '침실 리모델링')}</strong>
      <span>${t('meters coordinate space · autosave on', 'meters 좌표계 · 자동 저장 켜짐')}</span>
    </div>
    <div class="editor-top-actions">
      <button id="top-undo" type="button" aria-label="${t('Undo geometry edit', '지오메트리 편집 되돌리기')}">${t('Undo', '되돌리기')}</button>
      <button id="top-redo" type="button" aria-label="${t('Redo geometry edit', '지오메트리 편집 다시 실행')}">${t('Redo', '다시 실행')}</button>
      <button id="save-layout" type="button">${t('Save', '저장')}</button>
      <span class="state-pill confirmed" id="editor-save-state">${t('saved', '저장됨')}</span>
      <button id="export-layout" type="button">${t('Export', '내보내기')}</button>
    </div>
  </header>
  <div class="editor-stage">
  <nav class="tool-rail" aria-label="${t('Editor tools', '편집 도구')}">
    <button type="button" data-editor-tool="select" aria-pressed="true" title="${t('Select', '선택')}" aria-label="${t('Select', '선택')}">S</button>
    <button type="button" data-editor-tool="move" aria-pressed="false" title="${t('Move', '이동')}" aria-label="${t('Move', '이동')}">M</button>
    <button type="button" data-editor-tool="furniture" aria-pressed="false" title="${t('Add furniture', '가구 추가')}" aria-label="${t('Add furniture', '가구 추가')}">F</button>
    <button type="button" data-editor-tool="measure" aria-pressed="false" title="${t('Measure', '측정')}" aria-label="${t('Measure', '측정')}">R</button>
    <button type="button" data-editor-tool="layers" aria-pressed="false" title="${t('Layers', '레이어')}" aria-label="${t('Layers', '레이어')}">L</button>
  </nav>
  <div class="viewport" aria-label="${t('RoomForge editor viewport', 'RoomForge 편집기 뷰포트')}">
    <div class="viewport-toolbar" aria-label="${t('Planning view controls', '배치 보기 컨트롤')}">
      <button id="view-2d" type="button" aria-label="${t('Show 2D planning view', '2D 배치 보기 표시')}" aria-pressed="true">2D</button>
      <button id="view-3d" type="button" aria-label="${t('Show 3D inspection view', '3D 검사 보기 표시')}" aria-pressed="false">3D</button>
      <button id="view-split" type="button" aria-label="${t('Show split planning view', 'Split 배치 보기 표시')}" aria-pressed="false">Split</button>
    </div>
    <div class="canvas-toolbar" role="toolbar" aria-label="${t('Canvas tools', '캔버스 도구')}">
      <button type="button" data-camera-action="fit">${t('Fit', '맞춤')}</button>
      <button type="button" data-camera-action="reset">${t('Reset', '초기화')}</button>
      <button type="button" data-canvas-toggle="snap" aria-pressed="true">${t('Snap', '스냅')}</button>
      <button type="button" data-canvas-toggle="grid" aria-pressed="true">${t('Grid', '그리드')}</button>
    </div>
    <div class="viewport-layer-controls" aria-label="${t('Candidate layer visibility', '후보 레이어 표시')}">
      <button type="button" data-layer-toggle="furniture" aria-pressed="true">
        <span class="layer-dot furniture" aria-hidden="true"></span>${t('Furniture', '가구')}
      </button>
      <button type="button" data-layer-toggle="fixtures" aria-pressed="true">
        <span class="layer-dot fixtures" aria-hidden="true"></span>${t('Fixtures', '고정 요소')}
      </button>
      <button type="button" data-layer-toggle="boundaries" aria-pressed="true">
        <span class="layer-dot boundaries" aria-hidden="true"></span>${t('Boundaries', '경계선')}
      </button>
      <button type="button" data-layer-toggle="lowConfidence" aria-pressed="true">
        <span class="layer-dot low-confidence" aria-hidden="true"></span>${t('Low confidence', '낮은 신뢰도')}
      </button>
    </div>
    <div class="viewport-measurements" id="measurement-status" role="status" aria-live="polite">
      ${t('Room 4.20 m x 3.60 m', '방 4.20 m x 3.60 m')}
    </div>
    <div class="viewport-warning" id="placement-status" role="status" aria-live="assertive" hidden>
      ${t('Placement warning', '배치 경고')}
    </div>
    <canvas
      class="editor-canvas"
      aria-describedby="measurement-status scene-status inspector-status placement-summary"
      aria-label="${t('Three.js reconstruction viewport', 'Three.js 재구성 뷰포트')}"
      role="application"
      tabindex="0"
    ></canvas>
    <div class="viewport-status-strip" id="scene-status" role="status" aria-live="polite">
      ${t('Initializing metric room scene', '미터 단위 방 장면 초기화 중')}
    </div>
    <div class="viewport-cv-readout" aria-hidden="true">
      <span>${t('source image canvas', '소스 이미지 캔버스')}</span>
      <strong>${t('CV overlay active', 'CV 오버레이 활성')}</strong>
    </div>
  </div>
  <aside class="status-panel" aria-label="${t('Inspector and status', '인스펙터 및 상태')}">
    <p class="eyebrow">${t('RoomForge editor', 'RoomForge 편집기')}</p>
    <h1>${t('Planning editor', '배치 편집기')}</h1>
    <dl class="status-list">
      <div>
        <dt>${t('Bridge', '브리지')}</dt>
        <dd id="bridge-status" role="status" aria-live="polite">${t('Waiting for Flutter shell', 'Flutter 셸 대기 중')}</dd>
      </div>
      <div>
        <dt>${t('OpenCV runtime', 'OpenCV 런타임')}</dt>
        <dd id="opencv-status" role="status" aria-live="polite">${t('Loading worker assets', '워커 자산 로드 중')}</dd>
      </div>
      <div>
        <dt>${t('Capture images', '촬영 이미지')}</dt>
        <dd id="capture-session-status" role="status" aria-live="polite">${t('No capture session images', '촬영 세션 이미지 없음')}</dd>
      </div>
      <div>
        <dt>${t('Viewport', '뷰포트')}</dt>
        <dd id="viewport-status">${t('Sizing scene', '장면 크기 조정 중')}</dd>
      </div>
      <div>
        <dt>${t('Geometry', '지오메트리')}</dt>
        <dd id="geometry-status">${t('Candidate and confirmed overlays visible', '후보 및 확정 오버레이 표시 중')}</dd>
      </div>
      <div>
        <dt>${t('Scene', '장면')}</dt>
        <dd id="spatial-status" role="status" aria-live="polite">${t('Waiting for metric floor plan', '미터 단위 평면도 대기 중')}</dd>
      </div>
      <div>
        <dt>${t('Inspector', '인스펙터')}</dt>
        <dd id="inspector-status" role="status" aria-live="polite">${t('Selected room shell', '방 외곽 선택됨')}</dd>
      </div>
      <div>
        <dt>${t('Placement', '배치')}</dt>
        <dd id="placement-summary" role="status" aria-live="polite">${t('All objects inside room bounds', '모든 객체가 방 경계 안에 있음')}</dd>
      </div>
    </dl>
    <section class="panel-section" aria-labelledby="opencv-review-title">
      <div class="panel-section-header">
        <div>
          <p class="eyebrow">${t('OpenCV review', 'OpenCV 검토')}</p>
          <h2 id="opencv-review-title">${t('Candidate outline', '후보 윤곽')}</h2>
        </div>
        <span class="state-pill warning">${t('Needs review', '검토 필요')}</span>
      </div>
      <dl class="compact-metrics">
        <div>
          <dt>${t('Candidates', '후보')}</dt>
          <dd id="candidate-count">${t('1 set', '1개 세트')}</dd>
        </div>
        <div>
          <dt>${t('Confidence', '신뢰도')}</dt>
          <dd id="candidate-confidence">0.72</dd>
        </div>
      </dl>
      <div class="candidate-state-row" aria-label="${t('Candidate review states', '후보 검토 상태')}">
        <span class="state-pill candidate">${t('candidate', '후보')}</span>
        <span class="state-pill warning">${t('low confidence', '낮은 신뢰도')}</span>
        <span class="state-pill confirmed">${t('accepted', '적용됨')}</span>
      </div>
      <div class="outline-validity-panel" id="outline-validity-panel" role="status" aria-live="polite">
        <span class="state-pill confirmed" id="outline-validity-state">${t('valid polygon', '유효한 폴리곤')}</span>
        <span id="outline-summary">${t('4 points · 15.1 m² · image pixels', '4점 · 15.1 m² · image pixels')}</span>
      </div>
      <div class="geometry-controls" aria-label="${t('Geometry correction controls', '지오메트리 보정 컨트롤')}">
        <button id="accept-candidate" type="button">${t('Accept candidate', '후보 적용')}</button>
        <button id="confirm-outline" type="button">${t('Confirm outline', '윤곽 확정')}</button>
        <button id="manual-outline" type="button">${t('Manual rectangle', '수동 사각형')}</button>
        <button id="orthogonalize-outline" type="button">${t('Right angle', '직각 보정')}</button>
        <button id="add-corner" type="button">${t('Add corner', '꼭짓점 추가')}</button>
        <button id="delete-corner" type="button">${t('Delete corner', '꼭짓점 삭제')}</button>
        <button id="undo-geometry" type="button">${t('Undo', '되돌리기')}</button>
        <button id="redo-geometry" type="button">${t('Redo', '다시 실행')}</button>
        <button id="reset-candidate" type="button">${t('Reset', '초기화')}</button>
      </div>
    </section>
    <section class="panel-section" aria-labelledby="candidate-tray-title">
      <div class="panel-section-header">
        <div>
          <p class="eyebrow">${t('Scene candidates', '장면 후보')}</p>
          <h2 id="candidate-tray-title">${t('Candidate tray', '후보 트레이')}</h2>
        </div>
        <span class="state-pill" id="candidate-tray-count">${t('0 candidates', '후보 0개')}</span>
      </div>
      <p class="helper-text" id="candidate-tray-status" role="status" aria-live="polite">${t('No CV candidates loaded.', '불러온 CV 후보가 없습니다.')}</p>
      <div class="candidate-tray-list" id="candidate-tray-list" role="list" aria-label="${t('CV candidates', 'CV 후보')}"></div>
    </section>
    <section class="panel-section" aria-labelledby="scale-title">
      <div class="panel-section-header">
        <div>
          <p class="eyebrow">${t('Scale', '스케일')}</p>
          <h2 id="scale-title">${t('Metric floor plan', '미터 평면도')}</h2>
        </div>
        <span class="state-pill measurement" id="scale-state">${t('reference selected', '기준선 선택됨')}</span>
      </div>
      <div class="reference-line-list" id="reference-line-list" aria-label="${t('Reference wall segment', '기준 벽 세그먼트')}"></div>
      <label class="field-label" for="known-wall-length">${t('Known wall length', '알려진 벽 길이')}</label>
      <div class="scale-input-row">
        <input
          id="known-wall-length"
          type="number"
          min="0.1"
          step="0.01"
          value="4.20"
          inputmode="decimal"
          aria-describedby="scale-status"
        />
        <span aria-hidden="true">m</span>
      </div>
      <div class="scale-summary-grid" aria-label="${t('Scale calibration summary', '스케일 보정 요약')}">
        <div>
          <strong id="scale-ratio">142 px/m</strong>
          <span>${t('conversion ratio', '변환 비율')}</span>
        </div>
        <div>
          <strong id="scale-error">±0.0%</strong>
          <span>${t('estimated error', '예상 오차')}</span>
        </div>
      </div>
      <div class="scale-recalculate-notice" id="scale-recalculate-notice" hidden>
        ${t('Outline changed. Recalculate scale before exporting.', '윤곽이 변경되었습니다. 내보내기 전에 스케일을 다시 계산하세요.')}
      </div>
      <p class="helper-text" id="scale-status">${t('Use the longest trusted wall to anchor image pixels into meters.', '가장 신뢰할 수 있는 긴 벽을 기준으로 이미지 픽셀을 미터로 보정하세요.')}</p>
      <button id="generate-floor-plan" type="button">${t('Apply scale', '스케일 적용')}</button>
    </section>
    <section class="panel-section" aria-labelledby="floor-plan-review-title">
      <div class="panel-section-header">
        <div>
          <p class="eyebrow">${t('Plan review', '평면도 검토')}</p>
          <h2 id="floor-plan-review-title">${t('Floor plan review', '평면도 검토')}</h2>
        </div>
        <span class="state-pill confirmed" id="floor-plan-state">${t('metric ready', '미터 평면도 준비됨')}</span>
      </div>
      <div class="review-metrics-grid" aria-label="${t('Metric floor plan summary', '미터 평면도 요약')}">
        <div>
          <strong id="review-room-size">4.20 x 3.60 m</strong>
          <span>${t('room size', '방 크기')}</span>
        </div>
        <div>
          <strong id="review-coordinate-space">meters</strong>
          <span>${t('coordinate space', '좌표계')}</span>
        </div>
      </div>
      <div class="warning-rail" id="floor-warning-rail" role="list" aria-label="${t('Floor plan warnings', '평면도 경고')}"></div>
      <div class="artifact-grid" id="floor-artifact-grid" aria-label="${t('Generated artifacts', '생성 아티팩트')}"></div>
      <div class="proceed-controls" aria-label="${t('Floor plan proceed controls', '평면도 진행 컨트롤')}">
        <button id="review-candidates" type="button">${t('Review candidates', '후보 재검토')}</button>
        <button id="return-correction" type="button">${t('Manual correction', '수동 보정')}</button>
        <button id="proceed-editor" type="button">${t('Proceed to editor', '편집기로 이동')}</button>
      </div>
    </section>
    <section class="panel-section" aria-labelledby="furniture-catalog-title">
      <div class="panel-section-header">
        <div>
          <p class="eyebrow">${t('Objects', '오브젝트')}</p>
          <h2 id="furniture-catalog-title">${t('Furniture catalog', '가구 카탈로그')}</h2>
        </div>
        <span class="state-pill" id="furniture-count">${t('0 objects', '객체 0개')}</span>
      </div>
      <p class="helper-text" id="furniture-catalog-status">${t('Choose a preset to place it inside the measured room.', '측정된 방 안에 배치할 프리셋을 선택하세요.')}</p>
      <div class="object-state-row" aria-label="${t('Object state legend', '오브젝트 상태 범례')}">
        <span class="state-pill candidate">${t('candidate', '후보')}</span>
        <span class="state-pill confirmed">${t('confirmed', '확정')}</span>
        <span class="state-pill selected">${t('selected', '선택됨')}</span>
        <span class="state-pill collision">${t('collision', '충돌')}</span>
      </div>
      <div class="object-catalog furniture-controls" aria-label="${t('Furniture catalog', '가구 카탈로그')}">
        ${furnitureCatalogMarkup}
      </div>
      <div class="furniture-object-list" id="furniture-object-list" role="list" aria-label="${t('Placed furniture objects', '배치된 가구 오브젝트')}"></div>
    </section>
    <section class="panel-section" aria-labelledby="selection-inspector-title">
      <div class="panel-section-header">
        <div>
          <p class="eyebrow">${t('Inspector', '인스펙터')}</p>
          <h2 id="selection-inspector-title">${t('Selected object', '선택된 객체')}</h2>
        </div>
        <span class="state-pill" id="selection-state">${t('Room', '방')}</span>
      </div>
      <div class="selected-object-card" id="selected-object-card" aria-label="${t('Selected object summary', '선택 객체 요약')}">
        <div class="selected-object-header">
          <strong id="selected-object-title">${t('Room shell', '방 외곽')}</strong>
          <span id="selected-object-source">${t('meters coordinate space', 'meters 좌표계')}</span>
        </div>
        <dl class="transform-readout" aria-label="${t('Selected transform readout', '선택 객체 변환 값')}">
          <div>
            <dt>X</dt>
            <dd id="transform-x-readout">--</dd>
          </div>
          <div>
            <dt>Y</dt>
            <dd id="transform-y-readout">--</dd>
          </div>
          <div>
            <dt>${t('Rotate', '회전')}</dt>
            <dd id="transform-rotation-readout">--</dd>
          </div>
          <div>
            <dt>${t('Size', '크기')}</dt>
            <dd id="transform-size-readout">--</dd>
          </div>
        </dl>
      </div>
      <div class="transform-slider-grid" aria-label="${t('Transform sliders', '변환 슬라이더')}">
        <label>
          <span>X</span>
          <input type="range" min="0" max="4.2" step="0.05" data-transform-field="position-x" disabled />
          <output data-transform-output="position-x">--</output>
        </label>
        <label>
          <span>Y</span>
          <input type="range" min="0" max="3.6" step="0.05" data-transform-field="position-y" disabled />
          <output data-transform-output="position-y">--</output>
        </label>
        <label>
          <span>${t('Rotation', '회전')}</span>
          <input type="range" min="0" max="345" step="15" data-transform-field="rotation" disabled />
          <output data-transform-output="rotation">--</output>
        </label>
        <label>
          <span>${t('Width', '너비')}</span>
          <input type="range" min="0.2" max="3" step="0.05" data-transform-field="width" disabled />
          <output data-transform-output="width">--</output>
        </label>
        <label>
          <span>${t('Depth', '깊이')}</span>
          <input type="range" min="0.2" max="3" step="0.05" data-transform-field="depth" disabled />
          <output data-transform-output="depth">--</output>
        </label>
        <label>
          <span>${t('Height', '높이')}</span>
          <input type="range" min="0.2" max="2.7" step="0.05" data-transform-field="height" disabled />
          <output data-transform-output="height">--</output>
        </label>
      </div>
      <div class="placement-warning-card" id="furniture-placement-warning" role="status" aria-live="polite">
        <span class="state-pill confirmed">${t('clear', '정상')}</span>
        <span>${t('All objects inside room bounds', '모든 객체가 방 경계 안에 있음')}</span>
      </div>
      <div class="furniture-edit-controls" aria-label="${t('Selected furniture editing controls', '선택 가구 편집 컨트롤')}">
        <button type="button" data-furniture-edit="move-up">${t('Move up', '위로 이동')}</button>
        <button type="button" data-furniture-edit="move-down">${t('Move down', '아래로 이동')}</button>
        <button type="button" data-furniture-edit="move-left">${t('Move left', '왼쪽 이동')}</button>
        <button type="button" data-furniture-edit="move-right">${t('Move right', '오른쪽 이동')}</button>
        <button type="button" data-furniture-edit="rotate-left">${t('Rotate -15', '-15도 회전')}</button>
        <button type="button" data-furniture-edit="rotate-right">${t('Rotate +15', '+15도 회전')}</button>
        <button type="button" data-furniture-edit="narrower">${t('Narrower', '너비 줄이기')}</button>
        <button type="button" data-furniture-edit="wider">${t('Wider', '너비 늘리기')}</button>
        <button type="button" data-furniture-edit="shallower">${t('Shallower', '깊이 줄이기')}</button>
        <button type="button" data-furniture-edit="deeper">${t('Deeper', '깊이 늘리기')}</button>
        <button type="button" data-furniture-edit="toggle-lock">${t('Lock object', '객체 잠금')}</button>
        <button type="button" data-furniture-edit="delete">${t('Delete', '삭제')}</button>
      </div>
      <div class="fixture-edit-controls" aria-label="${t('Selected fixture editing controls', '선택 고정 요소 편집 컨트롤')}">
        <button type="button" data-fixture-edit="wall-previous">${t('Previous wall', '이전 벽')}</button>
        <button type="button" data-fixture-edit="wall-next">${t('Next wall', '다음 벽')}</button>
        <button type="button" data-fixture-edit="offset-decrease">${t('Offset -', '오프셋 -')}</button>
        <button type="button" data-fixture-edit="offset-increase">${t('Offset +', '오프셋 +')}</button>
        <button type="button" data-fixture-edit="narrower">${t('Narrower', '너비 줄이기')}</button>
        <button type="button" data-fixture-edit="wider">${t('Wider', '너비 늘리기')}</button>
        <button type="button" data-fixture-edit="shorter">${t('Shorter', '높이 줄이기')}</button>
        <button type="button" data-fixture-edit="taller">${t('Taller', '높이 늘리기')}</button>
        <button type="button" data-fixture-edit="category-next">${t('Change category', '카테고리 변경')}</button>
        <button type="button" data-fixture-edit="delete">${t('Delete fixture', '고정 요소 삭제')}</button>
      </div>
    </section>
    <section class="panel-section persistence-panel" aria-labelledby="persistence-title">
      <div class="panel-section-header">
        <div>
          <p class="eyebrow">${t('Persistence', '저장')}</p>
          <h2 id="persistence-title">${t('Save / load / export', '저장 / 로드 / 내보내기')}</h2>
        </div>
        <span class="state-pill confirmed" id="persistence-state">${t('saved', '저장됨')}</span>
      </div>
      <div class="save-board" id="save-board" aria-label="${t('Save targets', '저장 대상')}"></div>
      <div class="load-selector" id="layout-load-selector" aria-label="${t('Load source selector', '로드 소스 선택')}">
        <button type="button" data-load-source="latest" aria-pressed="true">${t('Latest cloud', '최신 클라우드')}</button>
        <button type="button" data-load-source="draft" aria-pressed="false">${t('Local draft', '로컬 draft')}</button>
        <button type="button" data-load-source="export" aria-pressed="false">${t('Previous export', '이전 export')}</button>
      </div>
      <pre class="json-preview" id="layout-export-preview" aria-label="${t('JSON export preview', 'JSON 내보내기 미리보기')}"></pre>
      <div class="round-trip-notice" id="round-trip-notice" role="status" aria-live="polite">
        <span class="state-pill confirmed">${t('verified', '검증됨')}</span>
        <span>${t('Save, load, and export fields match.', '저장, 로드, 내보내기 필드가 일치합니다.')}</span>
      </div>
      <div class="persistence-actions" aria-label="${t('Persistence actions', '저장 작업')}">
        <button type="button" data-persistence-action="load">${t('Open selected', '선택 저장본 열기')}</button>
        <button type="button" data-persistence-action="save">${t('Save layout', '레이아웃 저장')}</button>
        <button type="button" data-persistence-action="export">${t('Export JSON', 'JSON 내보내기')}</button>
      </div>
    </section>
    <section class="panel-section" aria-labelledby="camera-title">
      <div class="panel-section-header">
        <div>
          <p class="eyebrow">${t('View', '보기')}</p>
          <h2 id="camera-title">${t('3D camera', '3D 카메라')}</h2>
        </div>
        <span class="state-pill">${t('Presets', '프리셋')}</span>
      </div>
      <div class="camera-controls" aria-label="${t('3D camera controls', '3D 카메라 컨트롤')}">
        <button type="button" data-camera-action="reset">${t('Reset', '초기화')}</button>
        <button type="button" data-camera-action="fit">${t('Fit', '맞춤')}</button>
        <button type="button" data-camera-action="top">${t('Top', '상단')}</button>
        <button type="button" data-camera-action="front">${t('Front', '정면')}</button>
        <button type="button" data-camera-action="corner">${t('Corner', '코너')}</button>
        <button type="button" data-camera-action="eye">${t('Eye-level', '눈높이')}</button>
      </div>
      <p class="camera-status" id="camera-status">${t('Camera ready', '카메라 준비됨')}</p>
    </section>
  </aside>
  </div>
  <footer class="editor-statusbar" aria-label="${t('Editor status bar', '편집기 상태 바')}">
    <span class="state-pill confirmed" id="layout-validity">${t('valid layout', '유효한 레이아웃')}</span>
    <span id="layout-counts">${t('0 objects · 0 fixtures', '객체 0개 · 고정 요소 0개')}</span>
    <span id="layout-area">15.1 m²</span>
    <span class="editor-cursor-coords" id="cursor-coords">x 0.00 · y 0.00</span>
  </footer>
</section>
`

const canvas = document.querySelector<HTMLCanvasElement>('.editor-canvas')
const bridgeStatus = document.querySelector<HTMLElement>('#bridge-status')
const opencvStatus = document.querySelector<HTMLElement>('#opencv-status')
const captureSessionStatus = document.querySelector<HTMLElement>('#capture-session-status')
const viewportStatus = document.querySelector<HTMLElement>('#viewport-status')
const geometryStatus = document.querySelector<HTMLElement>('#geometry-status')
const spatialStatus = document.querySelector<HTMLElement>('#spatial-status')
const inspectorStatus = document.querySelector<HTMLElement>('#inspector-status')
const measurementStatus = document.querySelector<HTMLElement>('#measurement-status')
const placementStatus = document.querySelector<HTMLElement>('#placement-status')
const placementSummary = document.querySelector<HTMLElement>('#placement-summary')
const sceneStatus = document.querySelector<HTMLElement>('#scene-status')
const cameraStatus = document.querySelector<HTMLElement>('#camera-status')
const candidateCount = document.querySelector<HTMLElement>('#candidate-count')
const candidateConfidence = document.querySelector<HTMLElement>('#candidate-confidence')
const candidateTrayCount = document.querySelector<HTMLElement>('#candidate-tray-count')
const candidateTrayStatus = document.querySelector<HTMLElement>('#candidate-tray-status')
const candidateTrayList = document.querySelector<HTMLElement>('#candidate-tray-list')
const outlineValidityState = document.querySelector<HTMLElement>('#outline-validity-state')
const outlineSummary = document.querySelector<HTMLElement>('#outline-summary')
const undoGeometryButton = document.querySelector<HTMLButtonElement>('#undo-geometry')
const redoGeometryButton = document.querySelector<HTMLButtonElement>('#redo-geometry')
const confirmOutlineButton = document.querySelector<HTMLButtonElement>('#confirm-outline')
const knownWallLengthInput = document.querySelector<HTMLInputElement>('#known-wall-length')
const scaleStatus = document.querySelector<HTMLElement>('#scale-status')
const scaleState = document.querySelector<HTMLElement>('#scale-state')
const referenceLineList = document.querySelector<HTMLElement>('#reference-line-list')
const scaleRatio = document.querySelector<HTMLElement>('#scale-ratio')
const scaleError = document.querySelector<HTMLElement>('#scale-error')
const scaleRecalculateNotice = document.querySelector<HTMLElement>('#scale-recalculate-notice')
const floorPlanState = document.querySelector<HTMLElement>('#floor-plan-state')
const reviewRoomSize = document.querySelector<HTMLElement>('#review-room-size')
const reviewCoordinateSpace = document.querySelector<HTMLElement>('#review-coordinate-space')
const floorWarningRail = document.querySelector<HTMLElement>('#floor-warning-rail')
const floorArtifactGrid = document.querySelector<HTMLElement>('#floor-artifact-grid')
const reviewCandidatesButton = document.querySelector<HTMLButtonElement>('#review-candidates')
const returnCorrectionButton = document.querySelector<HTMLButtonElement>('#return-correction')
const proceedEditorButton = document.querySelector<HTMLButtonElement>('#proceed-editor')
const furnitureObjectList = document.querySelector<HTMLElement>('#furniture-object-list')
const furnitureCount = document.querySelector<HTMLElement>('#furniture-count')
const furnitureCatalogStatus = document.querySelector<HTMLElement>('#furniture-catalog-status')
const selectionState = document.querySelector<HTMLElement>('#selection-state')
const selectedObjectTitle = document.querySelector<HTMLElement>('#selected-object-title')
const selectedObjectSource = document.querySelector<HTMLElement>('#selected-object-source')
const transformXReadout = document.querySelector<HTMLElement>('#transform-x-readout')
const transformYReadout = document.querySelector<HTMLElement>('#transform-y-readout')
const transformRotationReadout = document.querySelector<HTMLElement>('#transform-rotation-readout')
const transformSizeReadout = document.querySelector<HTMLElement>('#transform-size-readout')
const furniturePlacementWarning = document.querySelector<HTMLElement>('#furniture-placement-warning')
const view2dButton = document.querySelector<HTMLButtonElement>('#view-2d')
const view3dButton = document.querySelector<HTMLButtonElement>('#view-3d')
const viewSplitButton = document.querySelector<HTMLButtonElement>('#view-split')
const topUndoButton = document.querySelector<HTMLButtonElement>('#top-undo')
const topRedoButton = document.querySelector<HTMLButtonElement>('#top-redo')
const saveLayoutButton = document.querySelector<HTMLButtonElement>('#save-layout')
const editorSaveState = document.querySelector<HTMLElement>('#editor-save-state')
const exportLayoutButton = document.querySelector<HTMLButtonElement>('#export-layout')
const persistenceState = document.querySelector<HTMLElement>('#persistence-state')
const saveBoard = document.querySelector<HTMLElement>('#save-board')
const layoutLoadSelector = document.querySelector<HTMLElement>('#layout-load-selector')
const layoutExportPreview = document.querySelector<HTMLElement>('#layout-export-preview')
const roundTripNotice = document.querySelector<HTMLElement>('#round-trip-notice')
const layoutValidity = document.querySelector<HTMLElement>('#layout-validity')
const layoutCounts = document.querySelector<HTMLElement>('#layout-counts')
const layoutArea = document.querySelector<HTMLElement>('#layout-area')
const cursorCoords = document.querySelector<HTMLElement>('#cursor-coords')
const toolRailButtons = Array.from(
  document.querySelectorAll<HTMLButtonElement>('[data-editor-tool]'),
)
const canvasToggleButtons = Array.from(
  document.querySelectorAll<HTMLButtonElement>('[data-canvas-toggle]'),
)
const layerToggleButtons = Array.from(
  document.querySelectorAll<HTMLButtonElement>('[data-layer-toggle]'),
)
const cameraActionButtons = Array.from(
  document.querySelectorAll<HTMLButtonElement>('[data-camera-action]'),
)
const furnitureCategoryButtons = Array.from(
  document.querySelectorAll<HTMLButtonElement>('[data-furniture-category]'),
)
const furnitureEditButtons = Array.from(
  document.querySelectorAll<HTMLButtonElement>('[data-furniture-edit]'),
)
const transformInputs = Array.from(
  document.querySelectorAll<HTMLInputElement>('[data-transform-field]'),
)
const transformOutputs = Array.from(
  document.querySelectorAll<HTMLOutputElement>('[data-transform-output]'),
)
const persistenceActionButtons = Array.from(
  document.querySelectorAll<HTMLButtonElement>('[data-persistence-action]'),
)
const layoutLoadSourceButtons = Array.from(
  document.querySelectorAll<HTMLButtonElement>('[data-load-source]'),
)
const fixtureEditButtons = Array.from(
  document.querySelectorAll<HTMLButtonElement>('[data-fixture-edit]'),
)

if (
  !canvas ||
  !bridgeStatus ||
  !opencvStatus ||
  !captureSessionStatus ||
  !viewportStatus ||
  !geometryStatus ||
  !spatialStatus ||
  !inspectorStatus ||
  !measurementStatus ||
  !placementStatus ||
  !placementSummary ||
  !sceneStatus ||
  !cameraStatus ||
  !candidateCount ||
  !candidateConfidence ||
  !candidateTrayCount ||
  !candidateTrayStatus ||
  !candidateTrayList ||
  !outlineValidityState ||
  !outlineSummary ||
  !undoGeometryButton ||
  !redoGeometryButton ||
  !confirmOutlineButton ||
  !knownWallLengthInput ||
  !scaleStatus ||
  !scaleState ||
  !referenceLineList ||
  !scaleRatio ||
  !scaleError ||
  !scaleRecalculateNotice ||
  !floorPlanState ||
  !reviewRoomSize ||
  !reviewCoordinateSpace ||
  !floorWarningRail ||
  !floorArtifactGrid ||
  !reviewCandidatesButton ||
  !returnCorrectionButton ||
  !proceedEditorButton ||
  !furnitureObjectList ||
  !furnitureCount ||
  !furnitureCatalogStatus ||
  !selectionState ||
  !selectedObjectTitle ||
  !selectedObjectSource ||
  !transformXReadout ||
  !transformYReadout ||
  !transformRotationReadout ||
  !transformSizeReadout ||
  !furniturePlacementWarning ||
  !view2dButton ||
  !view3dButton ||
  !viewSplitButton ||
  !topUndoButton ||
  !topRedoButton ||
  !saveLayoutButton ||
  !editorSaveState ||
  !exportLayoutButton ||
  !persistenceState ||
  !saveBoard ||
  !layoutLoadSelector ||
  !layoutExportPreview ||
  !roundTripNotice ||
  !layoutValidity ||
  !layoutCounts ||
  !layoutArea ||
  !cursorCoords ||
  toolRailButtons.length === 0 ||
  canvasToggleButtons.length === 0 ||
  layerToggleButtons.length === 0 ||
  cameraActionButtons.length === 0 ||
  furnitureCategoryButtons.length === 0 ||
  furnitureEditButtons.length === 0 ||
  transformInputs.length === 0 ||
  transformOutputs.length === 0 ||
  persistenceActionButtons.length === 0 ||
  layoutLoadSourceButtons.length === 0 ||
  fixtureEditButtons.length === 0
) {
  throw new Error('Missing editor UI element.')
}

const editorCanvas = canvas
const bridgeStatusElement = bridgeStatus
const opencvStatusElement = opencvStatus
const captureSessionStatusElement = captureSessionStatus
const viewportStatusElement = viewportStatus
const geometryStatusElement = geometryStatus
const spatialStatusElement = spatialStatus
const inspectorStatusElement = inspectorStatus
const measurementStatusElement = measurementStatus
const placementStatusElement = placementStatus
const placementSummaryElement = placementSummary
const sceneStatusElement = sceneStatus
const cameraStatusElement = cameraStatus
const candidateCountElement = candidateCount
const candidateConfidenceElement = candidateConfidence
const candidateTrayCountElement = candidateTrayCount
const candidateTrayStatusElement = candidateTrayStatus
const candidateTrayListElement = candidateTrayList
const outlineValidityStateElement = outlineValidityState
const outlineSummaryElement = outlineSummary
const undoGeometryButtonElement = undoGeometryButton
const redoGeometryButtonElement = redoGeometryButton
const confirmOutlineButtonElement = confirmOutlineButton
const knownWallLengthInputElement = knownWallLengthInput
const scaleStatusElement = scaleStatus
const scaleStateElement = scaleState
const referenceLineListElement = referenceLineList
const scaleRatioElement = scaleRatio
const scaleErrorElement = scaleError
const scaleRecalculateNoticeElement = scaleRecalculateNotice
const floorPlanStateElement = floorPlanState
const reviewRoomSizeElement = reviewRoomSize
const reviewCoordinateSpaceElement = reviewCoordinateSpace
const floorWarningRailElement = floorWarningRail
const floorArtifactGridElement = floorArtifactGrid
const reviewCandidatesButtonElement = reviewCandidatesButton
const returnCorrectionButtonElement = returnCorrectionButton
const proceedEditorButtonElement = proceedEditorButton
const furnitureObjectListElement = furnitureObjectList
const furnitureCountElement = furnitureCount
const furnitureCatalogStatusElement = furnitureCatalogStatus
const selectionStateElement = selectionState
const selectedObjectTitleElement = selectedObjectTitle
const selectedObjectSourceElement = selectedObjectSource
const transformXReadoutElement = transformXReadout
const transformYReadoutElement = transformYReadout
const transformRotationReadoutElement = transformRotationReadout
const transformSizeReadoutElement = transformSizeReadout
const furniturePlacementWarningElement = furniturePlacementWarning
const view2dButtonElement = view2dButton
const view3dButtonElement = view3dButton
const viewSplitButtonElement = viewSplitButton
const topUndoButtonElement = topUndoButton
const topRedoButtonElement = topRedoButton
const saveLayoutButtonElement = saveLayoutButton
const editorSaveStateElement = editorSaveState
const exportLayoutButtonElement = exportLayoutButton
const persistenceStateElement = persistenceState
const saveBoardElement = saveBoard
const layoutLoadSelectorElement = layoutLoadSelector
const layoutExportPreviewElement = layoutExportPreview
const roundTripNoticeElement = roundTripNotice
const layoutValidityElement = layoutValidity
const layoutCountsElement = layoutCounts
const layoutAreaElement = layoutArea
const cursorCoordsElement = cursorCoords
const toolRailButtonElements = toolRailButtons
const canvasToggleButtonElements = canvasToggleButtons
const layerToggleButtonElements = layerToggleButtons
const transformInputElements = transformInputs
const transformOutputElements = transformOutputs
const persistenceActionButtonElements = persistenceActionButtons
const layoutLoadSourceButtonElements = layoutLoadSourceButtons
const fixtureEditButtonElements = fixtureEditButtons

const renderer = new THREE.WebGLRenderer({ canvas: editorCanvas, antialias: true })
renderer.setPixelRatio(window.devicePixelRatio)
renderer.setClearColor(0x090a0c)

const scene = new THREE.Scene()
const camera = new THREE.PerspectiveCamera(42, 1, 0.1, 100)
camera.position.set(3.5, 4, 5)
camera.lookAt(0, 0, 0)

let spatialModel: SpatialModel = defaultSpatialModel()

const room = new THREE.Group()
const floor = new THREE.Mesh(
  new THREE.PlaneGeometry(4, 3),
  new THREE.MeshBasicMaterial({
    color: 0xd8c7a3,
    transparent: true,
    opacity: 0.14,
    side: THREE.DoubleSide,
  }),
)
floor.rotation.x = -Math.PI / 2
floor.userData.objectId = spatialModel.room.objectId
room.add(floor)

const outlineMaterial = new THREE.LineBasicMaterial({ color: 0xf4f1ea })
const outlinePoints = [
  new THREE.Vector3(-2, 0.02, -1.5),
  new THREE.Vector3(2, 0.02, -1.5),
  new THREE.Vector3(2, 0.02, 1.5),
  new THREE.Vector3(-2, 0.02, 1.5),
  new THREE.Vector3(-2, 0.02, -1.5),
]
let confirmedPoints = outlinePoints.slice(0, 4).map((point) => point.clone())
const confirmedLine = new THREE.Line(
  new THREE.BufferGeometry().setFromPoints([...confirmedPoints, confirmedPoints[0]]),
  outlineMaterial,
)
room.add(confirmedLine)

const wallMaterial = new THREE.MeshBasicMaterial({
  color: 0x5d6673,
  transparent: true,
  opacity: 0.24,
  side: THREE.DoubleSide,
})
const wallGroup = new THREE.Group()
room.add(wallGroup)

const furnitureGroup = new THREE.Group()
room.add(furnitureGroup)

const fixtureGroup = new THREE.Group()
room.add(fixtureGroup)

const selectionMaterial = new THREE.LineBasicMaterial({ color: 0xd6a75b })
const selectionLine = new THREE.Line(new THREE.BufferGeometry(), selectionMaterial)
selectionLine.visible = true
room.add(selectionLine)

const furnitureSelectionMaterial = new THREE.LineBasicMaterial({ color: 0xf4f1ea })
const furnitureMeshes = new Map<string, THREE.Mesh>()
const furnitureOutlineObjects: THREE.LineSegments[] = []
const fixtureMeshes = new Map<string, THREE.Mesh>()
const fixtureOutlineObjects: THREE.LineSegments[] = []

const cornerMaterial = new THREE.MeshBasicMaterial({ color: 0xd6a75b })
const cornerMeshes: THREE.Mesh[] = []
for (const point of confirmedPoints) {
  const corner = new THREE.Mesh(new THREE.SphereGeometry(0.08, 16, 16), cornerMaterial)
  corner.position.copy(point)
  room.add(corner)
  cornerMeshes.push(corner)
}
scene.add(room)

const candidateMaterial = new THREE.LineDashedMaterial({
  color: 0xd6a75b,
  dashSize: 0.12,
  gapSize: 0.08,
  transparent: true,
  opacity: 0.58,
})
let candidatePoints = [
  new THREE.Vector3(-1.85, 0.06, -1.34),
  new THREE.Vector3(1.86, 0.06, -1.42),
  new THREE.Vector3(1.72, 0.06, 1.34),
  new THREE.Vector3(-1.78, 0.06, 1.42),
  new THREE.Vector3(-1.85, 0.06, -1.34),
]
const candidateLine = new THREE.Line(
  new THREE.BufferGeometry().setFromPoints(candidatePoints),
  candidateMaterial,
)
candidateLine.computeLineDistances()
room.add(candidateLine)

let runtimeState: Record<string, unknown> = { state: 'loading' }
let runtimeReady = false
let sourceImageForExtraction: SourceImageForExtraction | null = null
let captureSessionForSceneUnderstanding: CaptureSessionForSceneUnderstanding | null = null
let latestCandidateGeometry: Record<string, unknown> | null = null
let latestCandidateQualityStatus = 'review_required'
let latestCandidateReasonCode: string | null = 'low_confidence'
let latestCandidateReasonMessage: string | null = t(
  'Candidate geometry should be reviewed before save or export.',
  '저장 또는 내보내기 전에 후보 지오메트리를 검토해야 합니다.',
)
let activeCornerIndex: number | null = null
const raycaster = new THREE.Raycaster()
const pointer = new THREE.Vector2()
const dragPlane = new THREE.Plane(new THREE.Vector3(0, 1, 0), -0.02)
const cameraTarget = new THREE.Vector3()
const reducedMotionMedia = window.matchMedia('(prefers-reduced-motion: reduce)')

type CameraDragMode = 'orbit' | 'pan'

type SourceImageForExtraction = {
  dataUrl?: string
  sourceImageId?: string
  widthPx?: number
  heightPx?: number
  contentType?: string
}

type CameraTransition = {
  from: CameraSnapshot
  to: CameraSnapshot
  startedAt: number
  durationMs: number
}

type CandidateLayer = 'furniture' | 'fixtures' | 'boundaries' | 'lowConfidence'

type PersistenceState = 'saved' | 'saving' | 'exportFailed'

type LoadSource = 'latest' | 'draft' | 'export'

type TransformField =
  | 'position-x'
  | 'position-y'
  | 'rotation'
  | 'width'
  | 'depth'
  | 'height'

type OutlineValidity = {
  state: 'calibrating' | 'invalid' | 'valid'
  label: string
  detail: string
  areaSquareMeters: number
}

let activeCameraDrag:
  | {
      pointerId: number
      mode: CameraDragMode
      lastX: number
      lastY: number
    }
  | null = null
let cameraTransition: CameraTransition | null = null
let furnitureIdCounter = 0
let selectedReferenceEdgeIndex = 0
let scaleNeedsRecalculation = false
let splitViewActive = false
let persistenceStateValue: PersistenceState = 'saved'
let selectedLoadSource: LoadSource = 'latest'
const canvasToggleState: Record<'grid' | 'snap', boolean> = {
  grid: true,
  snap: true,
}
const geometryUndoStack: THREE.Vector3[][] = []
const geometryRedoStack: THREE.Vector3[][] = []
const layerVisibility: Record<CandidateLayer, boolean> = {
  furniture: true,
  fixtures: true,
  boundaries: true,
  lowConfidence: true,
}

function resizeRenderer(): void {
  const parent = editorCanvas.parentElement
  if (!parent) {
    return
  }

  const width = parent.clientWidth
  const height = parent.clientHeight
  renderer.setSize(width, height, false)
  camera.aspect = width / Math.max(height, 1)
  camera.updateProjectionMatrix()
  viewportStatusElement.textContent = `${width} x ${height}px`
  applyViewModeCamera()
}

function render(): void {
  updateCameraTransition()
  renderer.render(scene, camera)
  requestAnimationFrame(render)
}

function postToParent(message: BridgeMessage): void {
  if (window.parent && window.parent !== window) {
    postBridgeMessage(window.parent, message)
  }
}

function respondToFlutter(message: BridgeMessage): void {
  bridgeStatusElement.textContent = t(
    `Received ${message.type}`,
    `${message.type} 수신됨`,
  )
  postToParent({
    type: `${message.type}.response`,
    version: BRIDGE_VERSION,
    requestId: message.requestId,
    payload: {
      ok: true,
      receivedType: message.type,
      editor: 'roomforge-three-editor',
      runtime: runtimeState,
      viewport: {
        width: editorCanvas.clientWidth,
        height: editorCanvas.clientHeight,
      },
      captureSession: captureSessionForSceneUnderstanding,
      focusable: true,
      cameraPose: cameraPosePayload(),
      spatialModel: spatialModelPayload(),
    },
  })
}

function handleBridgeCommand(message: BridgeMessage): void {
  if (message.type === 'roomforge.scene.initialize') {
    sourceImageForExtraction = sourceImageFromPayload(message.payload)
    captureSessionForSceneUnderstanding = captureSessionFromBridgePayload(message.payload)
    spatialModel = recalculateCandidatePlacements(spatialModelFromBridgePayload(message.payload))
    updateCaptureSessionStatus()
    applySpatialModel()
    respondToFlutter(message)
    emitSceneState('roomforge.scene.initialized', message.requestId)
    requestCandidateExtraction()
    return
  }

  if (message.type === 'roomforge.view.setMode') {
    const viewMode = message.payload.viewMode
    if (viewMode === '2d' || viewMode === '3d') {
      setViewMode(viewMode)
    }
    respondToFlutter(message)
    return
  }

  if (message.type === 'roomforge.sceneUnderstanding.extractCandidates') {
    requestSceneUnderstanding(message.requestId, message.payload)
    respondToFlutter(message)
    return
  }

  respondToFlutter(message)
}

window.addEventListener('message', (event: MessageEvent<unknown>) => {
  if (!isBridgeMessage(event.data)) {
    return
  }

  if (event.data.version !== BRIDGE_VERSION) {
    return
  }

  handleBridgeCommand(event.data)
})

view2dButtonElement.addEventListener('click', () => setViewMode('2d'))
view3dButtonElement.addEventListener('click', () => setViewMode('3d'))
viewSplitButtonElement.addEventListener('click', () => setSplitViewMode())
topUndoButtonElement.addEventListener('click', () => restoreGeometryHistory('undo'))
topRedoButtonElement.addEventListener('click', () => restoreGeometryHistory('redo'))
saveLayoutButtonElement.addEventListener('click', () => saveLayoutFromEditor())
exportLayoutButtonElement.addEventListener('click', () => prepareLayoutExport())
layoutLoadSelectorElement.addEventListener('click', (event) => {
  const target = event.target instanceof HTMLElement ? event.target : null
  const button = target?.closest<HTMLButtonElement>('[data-load-source]')
  const source = button?.dataset.loadSource
  if (isLoadSource(source)) {
    selectedLoadSource = source
    updatePersistencePanel()
  }
})
for (const button of persistenceActionButtonElements) {
  button.addEventListener('click', () => {
    const action = button.dataset.persistenceAction
    if (action === 'save') {
      saveLayoutFromEditor()
    } else if (action === 'export') {
      prepareLayoutExport()
    } else if (action === 'load') {
      sceneStatusElement.textContent = localizedLoadSourceMessage(selectedLoadSource)
      updatePersistencePanel()
    }
  })
}
for (const button of toolRailButtonElements) {
  button.addEventListener('click', () => {
    for (const item of toolRailButtonElements) {
      item.setAttribute('aria-pressed', String(item === button))
      item.classList.toggle('is-active', item === button)
    }
    sceneStatusElement.textContent = `${button.textContent?.trim() ?? ''} ${t('tool selected', '도구 선택됨')}`
  })
}
for (const button of canvasToggleButtonElements) {
  button.addEventListener('click', () => {
    const key = button.dataset.canvasToggle
    if (key !== 'grid' && key !== 'snap') {
      return
    }
    canvasToggleState[key] = !canvasToggleState[key]
    syncCanvasToggleButtons()
    sceneStatusElement.textContent = usesKorean
      ? `${key === 'grid' ? '그리드' : '스냅'} ${canvasToggleState[key] ? '켜짐' : '꺼짐'}`
      : `${key} ${canvasToggleState[key] ? 'on' : 'off'}`
  })
}
for (const button of layerToggleButtonElements) {
  button.addEventListener('click', () => {
    const layer = button.dataset.layerToggle
    if (!isCandidateLayer(layer)) {
      return
    }
    layerVisibility[layer] = !layerVisibility[layer]
    syncLayerToggleButtons()
    applyLayerVisibility()
    geometryStatusElement.textContent = usesKorean
      ? `${localizedLayerLabel(layer)} 레이어 ${layerVisibility[layer] ? '표시' : '숨김'}`
      : `${localizedLayerLabel(layer)} layer ${layerVisibility[layer] ? 'shown' : 'hidden'}`
  })
}
for (const button of cameraActionButtons) {
  button.addEventListener('click', () => {
    const action = button.dataset.cameraAction
    if (isCameraAction(action)) {
      applyCameraAction(action)
    }
  })
}
for (const button of furnitureCategoryButtons) {
  button.addEventListener('click', () => {
    const category = button.dataset.furnitureCategory
    if (isFurnitureCategory(category)) {
      addFurniture(category)
    }
  })
}
for (const button of furnitureEditButtons) {
  button.addEventListener('click', () => {
    const action = button.dataset.furnitureEdit
    if (isFurnitureEditAction(action)) {
      editSelectedFurniture(action)
    }
  })
}
furnitureObjectListElement.addEventListener('click', (event) => {
  const target = event.target instanceof HTMLElement ? event.target : null
  const button = target?.closest<HTMLButtonElement>('[data-furniture-select]')
  if (button?.dataset.furnitureSelect) {
    selectFurniture(button.dataset.furnitureSelect)
  }
})
for (const input of transformInputElements) {
  input.addEventListener('input', () => {
    const field = input.dataset.transformField
    if (isTransformField(field)) {
      updateSelectedFurnitureTransform(field, input.valueAsNumber)
    }
  })
}
for (const button of fixtureEditButtonElements) {
  button.addEventListener('click', () => {
    const action = button.dataset.fixtureEdit
    if (isFixtureEditAction(action)) {
      editSelectedFixture(action)
    }
  })
}

candidateTrayListElement.addEventListener('click', (event) => {
  const target = event.target instanceof HTMLElement ? event.target : null
  const button = target?.closest<HTMLButtonElement>('[data-candidate-action]')
  const action = button?.dataset.candidateAction
  const candidateId = button?.dataset.candidateId
  if (candidateId && action === 'place') {
    placeCandidate(candidateId)
  } else if (candidateId && action === 'reject') {
    rejectCandidate(candidateId)
  }
})

candidateTrayListElement.addEventListener('change', (event) => {
  const target = event.target instanceof HTMLElement ? event.target : null
  const select = target?.closest<HTMLSelectElement>('select[data-candidate-category]')
  const candidateId = select?.dataset.candidateId
  const category = select?.value
  if (candidateId && category) {
    updateCandidateCategory(candidateId, category)
  }
})

document.querySelector<HTMLButtonElement>('#accept-candidate')?.addEventListener('click', () => {
  pushGeometryUndoState()
  confirmedPoints = candidatePoints.slice(0, 4).map((point) => point.clone())
  updateConfirmedGeometry(t('Accepted OpenCV candidate.', 'OpenCV 후보를 적용했습니다.'))
})

confirmOutlineButtonElement.addEventListener('click', () => {
  const validity = outlineValidity()
  if (validity.state === 'invalid') {
    geometryStatusElement.textContent = validity.detail
    updateOutlineValidityPanel()
    return
  }
  updateConfirmedGeometry(t('Confirmed corrected room outline.', '보정된 방 윤곽을 확정했습니다.'))
})

document.querySelector<HTMLButtonElement>('#manual-outline')?.addEventListener('click', () => {
  pushGeometryUndoState()
  confirmedPoints = outlinePoints.slice(0, 4).map((point) => point.clone())
  updateConfirmedGeometry(t('Started from manual rectangle.', '수동 사각형에서 시작했습니다.'))
})

document.querySelector<HTMLButtonElement>('#orthogonalize-outline')?.addEventListener('click', () => {
  if (confirmedPoints.length < 3) {
    geometryStatusElement.textContent = t('At least three corners are required.', '최소 3개 꼭짓점이 필요합니다.')
    updateOutlineValidityPanel()
    return
  }
  pushGeometryUndoState()
  confirmedPoints = orthogonalizedOutlinePoints()
  updateConfirmedGeometry(t('Orthogonalized the room outline.', '방 윤곽을 직각으로 보정했습니다.'))
})

document.querySelector<HTMLButtonElement>('#add-corner')?.addEventListener('click', () => {
  pushGeometryUndoState()
  const lastPoint = confirmedPoints[confirmedPoints.length - 1]
  const firstPoint = confirmedPoints[0]
  confirmedPoints.push(lastPoint.clone().lerp(firstPoint, 0.5))
  updateConfirmedGeometry(t('Added a boundary corner.', '경계 꼭짓점을 추가했습니다.'))
})

document.querySelector<HTMLButtonElement>('#delete-corner')?.addEventListener('click', () => {
  if (confirmedPoints.length <= 3) {
    geometryStatusElement.textContent = t('At least three corners are required.', '최소 3개 꼭짓점이 필요합니다.')
    updateOutlineValidityPanel()
    return
  }
  pushGeometryUndoState()
  confirmedPoints.pop()
  updateConfirmedGeometry(t('Deleted the last boundary corner.', '마지막 경계 꼭짓점을 삭제했습니다.'))
})

undoGeometryButtonElement.addEventListener('click', () => restoreGeometryHistory('undo'))
redoGeometryButtonElement.addEventListener('click', () => restoreGeometryHistory('redo'))

referenceLineListElement.addEventListener('click', (event) => {
  const target = event.target instanceof HTMLElement ? event.target : null
  const button = target?.closest<HTMLButtonElement>('[data-reference-edge]')
  const index = Number.parseInt(button?.dataset.referenceEdge ?? '', 10)
  if (!Number.isInteger(index) || index < 0 || index >= confirmedPoints.length) {
    return
  }
  selectedReferenceEdgeIndex = index
  scaleNeedsRecalculation = true
  updateScaleCalibrationPanel()
})

knownWallLengthInputElement.addEventListener('input', () => {
  scaleNeedsRecalculation = true
  updateScaleCalibrationPanel()
})

reviewCandidatesButtonElement.addEventListener('click', () => {
  candidateTrayStatusElement.textContent = t(
    'Return to the candidate tray and resolve warnings before proceeding.',
    '후보 트레이로 돌아가 경고를 해결한 뒤 진행하세요.',
  )
})

returnCorrectionButtonElement.addEventListener('click', () => {
  geometryStatusElement.textContent = t(
    'Manual correction controls are ready.',
    '수동 보정 컨트롤을 사용할 수 있습니다.',
  )
  editorCanvas.focus()
})

proceedEditorButtonElement.addEventListener('click', () => {
  setViewMode('3d')
  sceneStatusElement.textContent = t(
    'Metric floor plan handed off to the layout editor.',
    '미터 평면도를 배치 편집기로 넘겼습니다.',
  )
})

document.querySelector<HTMLButtonElement>('#reset-candidate')?.addEventListener('click', () => {
  pushGeometryUndoState()
  confirmedPoints = candidatePoints.slice(0, 4).map((point) => point.clone())
  updateConfirmedGeometry(t('Reset to OpenCV candidate.', 'OpenCV 후보로 초기화했습니다.'))
})

document.querySelector<HTMLButtonElement>('#generate-floor-plan')?.addEventListener('click', () => {
  if (confirmedPoints.length < 3) {
    geometryStatusElement.textContent = t(
      'Confirm at least three corners before generation.',
      '생성 전에 최소 3개 꼭짓점을 확정하세요.',
    )
    return
  }
  const knownLength = Number.parseFloat(knownWallLengthInputElement.value)
  if (!Number.isFinite(knownLength) || knownLength <= 0 || knownLength > 50) {
    scaleStatusElement.textContent = t(
      'Enter a positive known wall length before generating a floor plan.',
      '평면도를 생성하기 전에 양수 벽 길이를 입력하세요.',
    )
    geometryStatusElement.textContent = t('Invalid calibration length.', '잘못된 보정 길이입니다.')
    updateScaleCalibrationPanel()
    return
  }
  const depth = roomBounds(spatialModel).depthMeters
  geometryStatusElement.textContent = t(
    'Generated meter-space MVP floor plan.',
    '미터 공간 MVP 평면도를 생성했습니다.',
  )
  scaleStatusElement.textContent = t(
    `Calibrated with ${knownLength.toFixed(2)} m known wall length.`,
    `알려진 벽 길이 ${knownLength.toFixed(2)} m로 보정했습니다.`,
  )
  scaleNeedsRecalculation = false
  const imageGeometryBeforeCalibration = confirmedGeometryPayload()
  const metricGeometry = {
    coordinateSpace: 'meters' as const,
    points: [
      { x: 0, y: 0 },
      { x: knownLength, y: 0 },
      { x: knownLength, y: depth },
      { x: 0, y: depth },
    ],
  }
  spatialModel = {
    ...spatialModel,
    hasUnsavedChanges: true,
    room: {
      ...spatialModel.room,
      floorPlan: {
        ...spatialModel.room.floorPlan,
        metricGeometry,
      },
    },
  }
  spatialModel = recalculateCandidatePlacements(spatialModel)
  applySpatialModel()
  updateScaleCalibrationPanel()
  postToParent({
    type: 'roomforge.calibration.floorPlanGenerated',
    version: BRIDGE_VERSION,
    payload: {
      unit: 'meters',
      scaleSummary: `${knownLength.toFixed(2)} m x ${depth.toFixed(2)} m rectangular MVP floor plan`,
      referenceLine: { fromIndex: 0, toIndex: 1 },
      referenceLengthValue: knownLength,
      perspectiveAssumptions: {
        model: 'mvp_rectangular_projection',
        sourceCoordinateSpace: 'image_pixels',
        targetCoordinateSpace: 'meters',
      },
      imageGeometry: imageGeometryBeforeCalibration,
      metricGeometry,
    },
  })
})

editorCanvas.addEventListener('pointerdown', (event) => {
  setPointerFromEvent(event)
  raycaster.setFromCamera(pointer, camera)
  const intersections = raycaster.intersectObjects(cornerMeshes)
  if (intersections.length > 0) {
    const cornerIndex = cornerMeshes.indexOf(intersections[0].object as THREE.Mesh)
    if (cornerIndex < 0) {
      return
    }
    pushGeometryUndoState()
    activeCornerIndex = cornerIndex
    syncCornerHandleStyles()
    editorCanvas.setPointerCapture(event.pointerId)
    return
  }

  const furnitureIntersections = raycaster.intersectObjects([...furnitureMeshes.values()])
  if (furnitureIntersections.length > 0) {
    selectFurniture(furnitureIntersections[0].object.userData.objectId)
    return
  }

  const fixtureIntersections = raycaster.intersectObjects([...fixtureMeshes.values()])
  if (fixtureIntersections.length > 0) {
    selectFixture(fixtureIntersections[0].object.userData.objectId)
    return
  }

  if (spatialModel.viewMode === '3d') {
    activeCameraDrag = {
      pointerId: event.pointerId,
      mode: event.shiftKey || event.button === 1 || event.button === 2 ? 'pan' : 'orbit',
      lastX: event.clientX,
      lastY: event.clientY,
    }
    cameraTransition = null
    cameraStatusElement.textContent =
      activeCameraDrag.mode === 'pan'
        ? t('Panning 3D camera', '3D 카메라 패닝 중')
        : t('Orbiting 3D camera', '3D 카메라 회전 중')
    editorCanvas.setPointerCapture(event.pointerId)
    event.preventDefault()
    return
  }

  const roomIntersections = raycaster.intersectObject(floor)
  if (roomIntersections.length > 0) {
    spatialModel = {
      ...spatialModel,
      selected: { objectId: spatialModel.room.objectId, objectType: 'room' },
    }
    updateSpatialStatus()
    emitSceneState('roomforge.selection.changed')
  }
})

editorCanvas.addEventListener('pointermove', (event) => {
  updateCursorCoordinates(event)
  if (activeCameraDrag) {
    const deltaX = event.clientX - activeCameraDrag.lastX
    const deltaY = event.clientY - activeCameraDrag.lastY
    activeCameraDrag.lastX = event.clientX
    activeCameraDrag.lastY = event.clientY
    if (activeCameraDrag.mode === 'pan') {
      panCamera(deltaX, deltaY)
    } else {
      orbitCamera(deltaX, deltaY)
    }
    event.preventDefault()
    return
  }

  if (activeCornerIndex === null) {
    return
  }
  setPointerFromEvent(event)
  raycaster.setFromCamera(pointer, camera)
  const target = new THREE.Vector3()
  if (raycaster.ray.intersectPlane(dragPlane, target)) {
    confirmedPoints[activeCornerIndex] = target
    updateConfirmedGeometry(t('Dragging confirmed boundary corner.', '확정 경계 꼭짓점 드래그 중.'), false)
  }
})

editorCanvas.addEventListener('pointerup', (event) => {
  if (activeCameraDrag?.pointerId === event.pointerId) {
    if (editorCanvas.hasPointerCapture(event.pointerId)) {
      editorCanvas.releasePointerCapture(event.pointerId)
    }
    activeCameraDrag = null
    cameraStatusElement.textContent = t('Camera adjusted', '카메라 조정됨')
    emitCameraChanged()
    return
  }

  if (activeCornerIndex !== null) {
    updateConfirmedGeometry(t('Updated confirmed boundary by dragging corner.', '꼭짓점 드래그로 확정 경계를 업데이트했습니다.'))
    if (editorCanvas.hasPointerCapture(event.pointerId)) {
      editorCanvas.releasePointerCapture(event.pointerId)
    }
  }
  activeCornerIndex = null
  syncCornerHandleStyles()
})

editorCanvas.addEventListener('pointercancel', (event) => {
  if (activeCameraDrag?.pointerId === event.pointerId) {
    activeCameraDrag = null
  }
  activeCornerIndex = null
  syncCornerHandleStyles()
})

editorCanvas.addEventListener(
  'wheel',
  (event) => {
    if (spatialModel.viewMode !== '3d') {
      return
    }
    zoomCamera(event.deltaY)
    cameraStatusElement.textContent = t('Zoomed 3D camera', '3D 카메라 확대/축소됨')
    emitCameraChanged()
    event.preventDefault()
  },
  { passive: false },
)

editorCanvas.addEventListener('contextmenu', (event) => event.preventDefault())
editorCanvas.addEventListener('keydown', (event) => {
  if (event.key === '2') {
    setViewMode('2d')
    event.preventDefault()
  } else if (event.key === '3') {
    setViewMode('3d')
    event.preventDefault()
  } else if (event.key === 'Escape') {
    spatialModel = {
      ...spatialModel,
      selected: { objectId: spatialModel.room.objectId, objectType: 'room' },
    }
    rebuildFurniture()
    updateSpatialStatus()
    emitSceneState('roomforge.selection.changed')
    event.preventDefault()
  }
})

let worker: Worker | null = null
let sceneUnderstandingWorker: Worker | null = null

function ensureOpenCvWorker(): Worker {
  if (worker !== null) {
    return worker
  }

  worker = new Worker(new URL('./opencvWorker.ts', import.meta.url), {
    type: 'module',
  })
  worker.onmessage = (event: MessageEvent<BridgeMessage>) => {
    runtimeState = event.data.payload
    if (event.data.type === 'roomforge.opencv.runtimeLoaded') {
      runtimeReady = true
      opencvStatusElement.textContent = t('OpenCV.js runtime loaded', 'OpenCV.js 런타임 로드됨')
    } else if (event.data.type === 'roomforge.opencv.runtimeFailed') {
      runtimeReady = false
      opencvStatusElement.textContent = t('OpenCV.js runtime failed', 'OpenCV.js 런타임 실패')
    }
    postToParent(event.data)
    if (event.data.type === 'roomforge.opencv.runtimeLoaded') {
      requestCandidateExtraction()
    } else if (event.data.type === 'roomforge.opencv.candidatesExtracted') {
      applyCandidateExtraction(event.data.payload)
      postCandidateQualityWarning()
    }
  }
  worker.postMessage({
    type: 'roomforge.opencv.loadRuntime',
    version: BRIDGE_VERSION,
    requestId: 'opencv-runtime-bootstrap',
    payload: {},
  } satisfies BridgeMessage)
  return worker
}

function ensureSceneUnderstandingWorker(): Worker {
  if (sceneUnderstandingWorker !== null) {
    return sceneUnderstandingWorker
  }

  sceneUnderstandingWorker = new Worker(new URL('./sceneUnderstandingWorker.ts', import.meta.url), {
    type: 'module',
  })
  sceneUnderstandingWorker.onmessage = (event: MessageEvent<BridgeMessage>) => {
    if (!isBridgeMessage(event.data)) {
      return
    }
    if (event.data.type === 'roomforge.sceneUnderstanding.candidatesExtracted') {
      applySceneUnderstandingResult(event.data.payload)
      candidateTrayStatusElement.textContent = t(
        'Scene understanding candidates loaded.',
        '장면 이해 후보를 불러왔습니다.',
      )
    } else if (event.data.type === 'roomforge.sceneUnderstanding.candidatesFailed') {
      const error = recordFromUnknown(event.data.payload.error)
      candidateTrayStatusElement.textContent =
        stringFromUnknown(error.message) ??
        t('Scene understanding could not run.', '장면 이해를 실행할 수 없습니다.')
    }
    postToParent(event.data)
  }
  return sceneUnderstandingWorker
}

function requestSceneUnderstanding(requestId?: string, payload: BridgePayload = {}): void {
  ensureSceneUnderstandingWorker().postMessage({
    type: 'roomforge.sceneUnderstanding.extractCandidates',
    version: BRIDGE_VERSION,
    requestId: requestId ?? `scene-understanding-${Date.now()}`,
    payload: {
      ...payload,
      captureSession: captureSessionForSceneUnderstanding ?? payload.captureSession,
      sourceImage: sourceImageForExtraction ?? payload.sourceImage,
      spatialModel: spatialModelPayload(),
    },
  } satisfies BridgeMessage)
}

function applySceneUnderstandingResult(payload: Record<string, unknown>): void {
  const result = recordFromUnknown(payload.sceneUnderstandingResult)
  const nextModel = spatialModelFromBridgePayload({
    scene: spatialModelPayload(),
    sceneUnderstandingResult: result,
  })
  spatialModel = recalculateCandidatePlacements({
    ...spatialModel,
    hasUnsavedChanges: true,
    candidateObjects: nextModel.candidateObjects,
    placedObjects: nextModel.placedObjects,
    confirmedObjects: nextModel.confirmedObjects,
    structuralFixtures: nextModel.structuralFixtures,
  })
  rebuildStructuralFixtures()
  rebuildFurniture()
  updateSpatialStatus()
  emitSceneState('roomforge.sceneUnderstanding.applied')
}

function recalculateCandidatePlacements(model: SpatialModel): SpatialModel {
  return applyMetricPlacementToCandidates({
    model,
    images: captureSessionForSceneUnderstanding?.images ?? [],
  })
}

syncLayerToggleButtons()
syncCanvasToggleButtons()
applySpatialModel()
window.addEventListener('resize', resizeRenderer)
resizeRenderer()
render()

queueMicrotask(() => {
  postToParent({
    type: 'roomforge.editor.ready',
    version: BRIDGE_VERSION,
    payload: {
      editor: 'roomforge-three-editor',
      bridgeVersion: BRIDGE_VERSION,
      spatialModel: spatialModelPayload(),
    },
  })
})

function applySpatialModel(): void {
  const bounds = roomBounds(spatialModel)
  const width = Math.max(bounds.widthMeters, 0.1)
  const depth = Math.max(bounds.depthMeters, 0.1)
  floor.geometry.dispose()
  floor.geometry = new THREE.PlaneGeometry(width, depth)
  floor.position.set(0, 0, 0)

  confirmedPoints = spatialModel.room.floorPlan.metricGeometry.points.map((point) =>
    metricPointToScene(point.x, point.y, 0.02),
  )
  syncConfirmedGeometryMeshes()
  rebuildWalls()
  rebuildStructuralFixtures()
  rebuildFurniture()
  applyViewModeCamera()
  updateSpatialStatus()
}

function setViewMode(viewMode: ViewMode): void {
  splitViewActive = false
  spatialModel = { ...spatialModel, viewMode }
  rebuildStructuralFixtures()
  rebuildFurniture()
  applyViewModeCamera()
  updateSpatialStatus()
  emitSceneState('roomforge.view.changed')
}

function setSplitViewMode(): void {
  splitViewActive = true
  spatialModel = { ...spatialModel, viewMode: '3d' }
  rebuildStructuralFixtures()
  rebuildFurniture()
  queueCameraSnapshot(cameraSnapshotFor('corner'), 'Split inspection view', true)
  applyLayerVisibility()
  updateSpatialStatus()
  emitSceneState('roomforge.view.changed')
}

function applyViewModeCamera(): void {
  if (spatialModel.viewMode === '2d') {
    queueCameraSnapshot(cameraSnapshotFor('top'), '2D top view', false)
  } else if (splitViewActive) {
    queueCameraSnapshot(cameraSnapshotFor('corner'), 'Split inspection view', true)
  } else {
    queueCameraSnapshot(cameraSnapshotFor('corner'), '3D corner view', true)
  }
  applyLayerVisibility()
}

function isCandidateLayer(value: string | undefined): value is CandidateLayer {
  return value === 'furniture' || value === 'fixtures' || value === 'boundaries' || value === 'lowConfidence'
}

function syncLayerToggleButtons(): void {
  for (const button of layerToggleButtonElements) {
    const layer = button.dataset.layerToggle
    if (!isCandidateLayer(layer)) {
      continue
    }
    const isVisible = layerVisibility[layer]
    button.setAttribute('aria-pressed', String(isVisible))
    button.classList.toggle('is-active', isVisible)
  }
}

function applyLayerVisibility(): void {
  furnitureGroup.visible = layerVisibility.furniture
  fixtureGroup.visible = layerVisibility.fixtures
  candidateLine.visible = layerVisibility.lowConfidence
  confirmedLine.visible = layerVisibility.boundaries
  for (const corner of cornerMeshes) {
    corner.visible = layerVisibility.boundaries
  }
  selectionLine.visible =
    layerVisibility.boundaries && spatialModel.selected?.objectId === spatialModel.room.objectId
  wallGroup.visible = layerVisibility.boundaries && spatialModel.viewMode === '3d'
}

function localizedLayerLabel(layer: CandidateLayer): string {
  if (usesKorean) {
    return {
      furniture: '가구',
      fixtures: '고정 요소',
      boundaries: '경계선',
      lowConfidence: '낮은 신뢰도',
    }[layer]
  }
  return {
    furniture: 'Furniture',
    fixtures: 'Fixtures',
    boundaries: 'Boundaries',
    lowConfidence: 'Low confidence',
  }[layer]
}

function cloneConfirmedPoints(): THREE.Vector3[] {
  return confirmedPoints.map((point) => point.clone())
}

function pushGeometryUndoState(): void {
  geometryUndoStack.push(cloneConfirmedPoints())
  if (geometryUndoStack.length > 24) {
    geometryUndoStack.shift()
  }
  geometryRedoStack.length = 0
  updateGeometryUndoRedoControls()
}

function restoreGeometryHistory(direction: 'undo' | 'redo'): void {
  const sourceStack = direction === 'undo' ? geometryUndoStack : geometryRedoStack
  const targetStack = direction === 'undo' ? geometryRedoStack : geometryUndoStack
  const nextPoints = sourceStack.pop()
  if (!nextPoints) {
    updateGeometryUndoRedoControls()
    return
  }
  targetStack.push(cloneConfirmedPoints())
  confirmedPoints = nextPoints.map((point) => point.clone())
  updateConfirmedGeometry(
    direction === 'undo'
      ? t('Reverted the previous geometry edit.', '이전 지오메트리 편집을 되돌렸습니다.')
      : t('Reapplied the geometry edit.', '지오메트리 편집을 다시 적용했습니다.'),
  )
}

function updateGeometryUndoRedoControls(): void {
  undoGeometryButtonElement.disabled = geometryUndoStack.length === 0
  redoGeometryButtonElement.disabled = geometryRedoStack.length === 0
  topUndoButtonElement.disabled = geometryUndoStack.length === 0
  topRedoButtonElement.disabled = geometryRedoStack.length === 0
}

function orthogonalizedOutlinePoints(): THREE.Vector3[] {
  const xs = confirmedPoints.map((point) => point.x)
  const zs = confirmedPoints.map((point) => point.z)
  const minX = Math.min(...xs)
  const maxX = Math.max(...xs)
  const minZ = Math.min(...zs)
  const maxZ = Math.max(...zs)
  return [
    new THREE.Vector3(minX, 0.02, minZ),
    new THREE.Vector3(maxX, 0.02, minZ),
    new THREE.Vector3(maxX, 0.02, maxZ),
    new THREE.Vector3(minX, 0.02, maxZ),
  ]
}

function updateOutlineValidityPanel(): void {
  const validity = outlineValidity()
  const stateClass =
    validity.state === 'valid'
      ? 'confirmed'
      : validity.state === 'calibrating'
        ? 'measurement'
        : 'error'
  outlineValidityStateElement.className = `state-pill ${stateClass}`
  outlineValidityStateElement.textContent = validity.label
  outlineSummaryElement.textContent = validity.detail
  confirmOutlineButtonElement.disabled = validity.state === 'invalid'
  updateGeometryUndoRedoControls()
}

function outlineValidity(): OutlineValidity {
  const area = polygonAreaSquareMeters()
  const coordinateSpace = String(confirmedGeometryPayload().coordinateSpace)
  const pointSummary = usesKorean
    ? `${confirmedPoints.length}점 · ${area.toFixed(1)} m² · ${coordinateSpace}`
    : `${confirmedPoints.length} points · ${area.toFixed(1)} m² · ${coordinateSpace}`
  if (confirmedPoints.length < 3) {
    return {
      state: 'invalid',
      label: t('invalid polygon', '잘못된 폴리곤'),
      detail: t(
        `${pointSummary} · at least three points required`,
        `${pointSummary} · 최소 3개 점 필요`,
      ),
      areaSquareMeters: area,
    }
  }
  if (outlineHasSelfIntersection()) {
    return {
      state: 'invalid',
      label: t('invalid polygon', '잘못된 폴리곤'),
      detail: t(`${pointSummary} · self-intersection`, `${pointSummary} · 자체 교차`),
      areaSquareMeters: area,
    }
  }
  if (area < 0.1) {
    return {
      state: 'calibrating',
      label: t('calibrating', '보정 중'),
      detail: t(`${pointSummary} · area too small`, `${pointSummary} · 면적이 너무 작음`),
      areaSquareMeters: area,
    }
  }
  return {
    state: 'valid',
    label: t('valid polygon', '유효한 폴리곤'),
    detail: pointSummary,
    areaSquareMeters: area,
  }
}

function polygonAreaSquareMeters(): number {
  if (confirmedPoints.length < 3) {
    return 0
  }
  const points = confirmedPoints.map(scenePointToMetric)
  let sum = 0
  for (let index = 0; index < points.length; index += 1) {
    const current = points[index]
    const next = points[(index + 1) % points.length]
    sum += current.x * next.y - next.x * current.y
  }
  return Math.abs(sum / 2)
}

function outlineHasSelfIntersection(): boolean {
  if (confirmedPoints.length < 4) {
    return false
  }
  for (let first = 0; first < confirmedPoints.length; first += 1) {
    const firstNext = (first + 1) % confirmedPoints.length
    for (let second = first + 1; second < confirmedPoints.length; second += 1) {
      const secondNext = (second + 1) % confirmedPoints.length
      const adjacent =
        first === second ||
        firstNext === second ||
        secondNext === first
      if (adjacent) {
        continue
      }
      if (
        segmentsIntersect(
          confirmedPoints[first],
          confirmedPoints[firstNext],
          confirmedPoints[second],
          confirmedPoints[secondNext],
        )
      ) {
        return true
      }
    }
  }
  return false
}

function segmentsIntersect(
  aStart: THREE.Vector3,
  aEnd: THREE.Vector3,
  bStart: THREE.Vector3,
  bEnd: THREE.Vector3,
): boolean {
  const d1 = orientation(aStart, aEnd, bStart)
  const d2 = orientation(aStart, aEnd, bEnd)
  const d3 = orientation(bStart, bEnd, aStart)
  const d4 = orientation(bStart, bEnd, aEnd)
  return d1 * d2 < 0 && d3 * d4 < 0
}

function orientation(a: THREE.Vector3, b: THREE.Vector3, c: THREE.Vector3): number {
  return (b.x - a.x) * (c.z - a.z) - (b.z - a.z) * (c.x - a.x)
}

function syncCornerHandleStyles(): void {
  for (const [index, corner] of cornerMeshes.entries()) {
    corner.scale.setScalar(index === activeCornerIndex ? 1.55 : 1)
  }
}

function syncCanvasToggleButtons(): void {
  for (const button of canvasToggleButtonElements) {
    const key = button.dataset.canvasToggle
    if (key !== 'grid' && key !== 'snap') {
      continue
    }
    const active = canvasToggleState[key]
    button.setAttribute('aria-pressed', String(active))
    button.classList.toggle('is-active', active)
  }
  document.querySelector('.viewport')?.classList.toggle('is-grid-hidden', !canvasToggleState.grid)
}

function updateScaleCalibrationPanel(): void {
  if (confirmedPoints.length < 2) {
    referenceLineListElement.innerHTML = ''
    scaleStateElement.className = 'state-pill error'
    scaleStateElement.textContent = t('invalid length', '잘못된 길이')
    scaleRatioElement.textContent = 'n/a'
    scaleErrorElement.textContent = 'n/a'
    scaleRecalculateNoticeElement.hidden = false
    return
  }
  if (selectedReferenceEdgeIndex >= confirmedPoints.length) {
    selectedReferenceEdgeIndex = 0
  }
  renderReferenceLineButtons()
  const knownLength = Number.parseFloat(knownWallLengthInputElement.value)
  const edge = selectedReferenceEdge()
  const pixelLength = referencePixelLength(edge)
  const currentMeters = referenceMetricLength(edge)
  if (!Number.isFinite(knownLength) || knownLength <= 0 || knownLength > 50) {
    scaleStateElement.className = 'state-pill error'
    scaleStateElement.textContent = t('invalid length', '잘못된 길이')
    scaleRatioElement.textContent = 'n/a'
    scaleErrorElement.textContent = 'n/a'
    scaleRecalculateNoticeElement.hidden = false
    scaleStatusElement.textContent = t(
      'Enter a wall length between 0.10 m and 50.00 m.',
      '0.10 m에서 50.00 m 사이의 벽 길이를 입력하세요.',
    )
    return
  }
  const pixelsPerMeter = pixelLength / knownLength
  const errorPercent =
    currentMeters > 0 ? (Math.abs(currentMeters - knownLength) / knownLength) * 100 : 0
  scaleRatioElement.textContent = `${Math.round(pixelsPerMeter)} px/m`
  scaleErrorElement.textContent = `±${errorPercent.toFixed(1)}%`
  scaleStateElement.className = scaleNeedsRecalculation
    ? 'state-pill warning'
    : 'state-pill measurement'
  scaleStateElement.textContent = scaleNeedsRecalculation
    ? t('recalculate', '재계산 필요')
    : t('reference selected', '기준선 선택됨')
  scaleRecalculateNoticeElement.hidden = !scaleNeedsRecalculation
  if (!scaleNeedsRecalculation) {
    scaleStatusElement.textContent = t(
      `Reference wall ${selectedReferenceEdgeIndex + 1} maps ${Math.round(
        pixelLength,
      )} px to ${knownLength.toFixed(2)} m.`,
      `기준 벽 ${selectedReferenceEdgeIndex + 1}: ${Math.round(
        pixelLength,
      )} px를 ${knownLength.toFixed(2)} m로 매핑했습니다.`,
    )
  }
}

function renderReferenceLineButtons(): void {
  referenceLineListElement.innerHTML = confirmedPoints
    .map((_, index) => {
      const selected = index === selectedReferenceEdgeIndex
      const next = (index + 1) % confirmedPoints.length
      const label = usesKorean
        ? `벽 ${index + 1}-${next + 1}`
        : `Wall ${index + 1}-${next + 1}`
      return `<button type="button" data-reference-edge="${index}" aria-pressed="${selected}" class="${
        selected ? 'is-active' : ''
      }">${label}</button>`
    })
    .join('')
}

function selectedReferenceEdge(): { start: THREE.Vector3; end: THREE.Vector3 } {
  const start = confirmedPoints[selectedReferenceEdgeIndex]
  const end = confirmedPoints[(selectedReferenceEdgeIndex + 1) % confirmedPoints.length]
  return { start, end }
}

function referencePixelLength(edge: { start: THREE.Vector3; end: THREE.Vector3 }): number {
  const start = scenePointToImage(edge.start)
  const end = scenePointToImage(edge.end)
  return Math.hypot(end.x - start.x, end.y - start.y)
}

function referenceMetricLength(edge: { start: THREE.Vector3; end: THREE.Vector3 }): number {
  const start = scenePointToMetric(edge.start)
  const end = scenePointToMetric(edge.end)
  return Math.hypot(end.x - start.x, end.y - start.y)
}

function updateFloorPlanReviewPanel(): void {
  const bounds = roomBounds(spatialModel)
  const coordinateSpace = spatialModel.room.floorPlan.metricGeometry.coordinateSpace
  const lowConfidenceCandidates = spatialModel.candidateObjects.filter(
    (candidate) => typeof candidate.confidenceScore === 'number' && candidate.confidenceScore < 0.7,
  )
  const lowConfidenceFixtures = spatialModel.structuralFixtures.filter(
    (fixture) => typeof fixture.confidenceScore === 'number' && fixture.confidenceScore < 0.7,
  )
  const warnings = [
    ...lowConfidenceCandidates.map((candidate) =>
      t(
        `${candidate.category} confidence ${Math.round((candidate.confidenceScore ?? 0) * 100)}%`,
        `${candidate.category} confidence ${Math.round((candidate.confidenceScore ?? 0) * 100)}%`,
      ),
    ),
    ...lowConfidenceFixtures.map((fixture) =>
      t(
        `${fixture.category} fixture confidence ${Math.round((fixture.confidenceScore ?? 0) * 100)}%`,
        `${fixture.category} 고정 요소 confidence ${Math.round((fixture.confidenceScore ?? 0) * 100)}%`,
      ),
    ),
  ]
  const placement = placementWarning(spatialModel)
  if (placement) {
    warnings.push(placement)
  }
  if (scaleNeedsRecalculation) {
    warnings.push(t('Scale should be recalculated after outline edits.', '윤곽 수정 후 스케일 재계산이 필요합니다.'))
  }

  reviewRoomSizeElement.textContent = `${bounds.widthMeters.toFixed(2)} x ${bounds.depthMeters.toFixed(2)} m`
  reviewCoordinateSpaceElement.textContent = coordinateSpace
  const hasMetricPlan = coordinateSpace === 'meters' && confirmedPoints.length >= 3
  floorPlanStateElement.className = hasMetricPlan
    ? warnings.length > 0
      ? 'state-pill warning'
      : 'state-pill confirmed'
    : 'state-pill error'
  floorPlanStateElement.textContent = hasMetricPlan
    ? warnings.length > 0
      ? t('warning', '경고')
      : t('metric ready', '미터 평면도 준비됨')
    : t('artifact missing', '아티팩트 누락')
  floorWarningRailElement.innerHTML =
    warnings.length === 0
      ? warningRailRowMarkup('confirmed', t('No blocking warnings.', '차단 경고 없음'))
      : warnings.map((warning) => warningRailRowMarkup('warning', warning)).join('')
  floorArtifactGridElement.innerHTML = floorPlanArtifactRows()
}

function warningRailRowMarkup(state: 'confirmed' | 'warning' | 'error', message: string): string {
  const label = state === 'confirmed' ? t('ready', '준비됨') : state === 'warning' ? t('warning', '경고') : t('missing', '누락')
  return `<div class="warning-row" role="listitem"><span class="state-pill ${state}">${label}</span><span>${escapeHtml(message)}</span></div>`
}

function floorPlanArtifactRows(): string {
  const artifacts = [
    {
      label: 'overlay',
      ready: latestCandidateGeometry !== null || confirmedPoints.length >= 3,
      detail: t('candidate and confirmed outline', '후보 및 확정 윤곽'),
    },
    {
      label: 'mask',
      ready: latestCandidateGeometry !== null,
      detail: t('OpenCV segmentation artifact', 'OpenCV segmentation 아티팩트'),
    },
    {
      label: 'depth.json',
      ready: (captureSessionForSceneUnderstanding?.images ?? []).some(
        (image) => (image.depthArtifactRefs ?? []).length > 0 || image.cameraPose?.depthEstimateMeters,
      ),
      detail: t('ARCore depth metadata', 'ARCore depth 메타데이터'),
    },
  ]
  return artifacts
    .map((artifact) => {
      const state = artifact.ready ? 'confirmed' : 'error'
      const label = artifact.ready ? t('ready', '준비됨') : t('missing', '누락')
      return `<div class="artifact-row"><strong>${escapeHtml(artifact.label)}</strong><span>${escapeHtml(
        artifact.detail,
      )}</span><span class="state-pill ${state}">${label}</span></div>`
    })
    .join('')
}

function updateEditorStatusBar(): void {
  const area = polygonAreaSquareMeters()
  const warning = placementWarning(spatialModel)
  const saveState = saveStateDisplay()
  editorSaveStateElement.className = `state-pill ${saveState.className}`
  editorSaveStateElement.textContent = saveState.label
  layoutValidityElement.className = warning ? 'state-pill warning' : 'state-pill confirmed'
  layoutValidityElement.textContent = warning
    ? t('warning layout', '경고 레이아웃')
    : t('valid layout', '유효한 레이아웃')
  layoutCountsElement.textContent = usesKorean
    ? `가구 ${spatialModel.furniture.length}개 · 고정 요소 ${spatialModel.structuralFixtures.length}개`
    : `${spatialModel.furniture.length} objects · ${spatialModel.structuralFixtures.length} fixtures`
  layoutAreaElement.textContent = `${area.toFixed(1)} m²`
}

function saveStateDisplay(): { className: string; label: string } {
  if (persistenceStateValue === 'saving') {
    return { className: 'save', label: t('saving', '저장 중') }
  }
  if (persistenceStateValue === 'exportFailed') {
    return { className: 'error', label: t('export failed', '내보내기 실패') }
  }
  if (spatialModel.hasUnsavedChanges) {
    return { className: 'warning', label: t('unsaved', '저장 안 됨') }
  }
  return { className: 'confirmed', label: t('saved', '저장됨') }
}

function saveLayoutFromEditor(): void {
  persistenceStateValue = 'saving'
  updateEditorStatusBar()
  updatePersistencePanel()
  sceneStatusElement.textContent = t('Saving layout draft.', '레이아웃 draft 저장 중입니다.')
  window.setTimeout(() => {
    spatialModel = { ...spatialModel, hasUnsavedChanges: false }
    persistenceStateValue = 'saved'
    updateSpatialStatus()
    sceneStatusElement.textContent = t('Layout saved and ready to reload.', '레이아웃이 저장되어 다시 로드할 수 있습니다.')
    emitSceneState('roomforge.layout.saved')
  }, 180)
}

function prepareLayoutExport(): void {
  const warning = placementWarning(spatialModel)
  persistenceStateValue = warning ? 'exportFailed' : 'saved'
  updateEditorStatusBar()
  updatePersistencePanel()
  sceneStatusElement.textContent = warning
    ? t(
        'Export preview has placement warnings. Resolve them before downloading JSON.',
        '내보내기 미리보기에 배치 경고가 있습니다. JSON 다운로드 전에 해결하세요.',
      )
    : t(
        'Layout JSON export preview is ready.',
        '레이아웃 JSON 내보내기 미리보기가 준비되었습니다.',
      )
  postToParent({
    type: 'roomforge.layout.exportPreviewed',
    version: BRIDGE_VERSION,
    payload: layoutExportPayload(),
  })
}

function updatePersistencePanel(): void {
  const saveState = saveStateDisplay()
  persistenceStateElement.className = `state-pill ${saveState.className}`
  persistenceStateElement.textContent = saveState.label
  saveBoardElement.innerHTML = saveBoardMarkup()
  layoutExportPreviewElement.textContent = JSON.stringify(layoutExportPayload(), null, 2)
  for (const button of layoutLoadSourceButtonElements) {
    const active = button.dataset.loadSource === selectedLoadSource
    button.setAttribute('aria-pressed', String(active))
    button.classList.toggle('is-active', active)
  }
  const warning = placementWarning(spatialModel)
  const roundTripClass = warning || spatialModel.hasUnsavedChanges ? 'warning' : 'confirmed'
  const roundTripLabel = warning
    ? t('review', '검토 필요')
    : spatialModel.hasUnsavedChanges
      ? t('draft', 'draft')
      : t('verified', '검증됨')
  const roundTripMessage = warning
    ? t(
        'Round-trip preview includes placement warnings.',
        'Round-trip 미리보기에 배치 경고가 포함되어 있습니다.',
      )
    : spatialModel.hasUnsavedChanges
      ? t(
          'Local draft differs from the last saved cloud layout.',
          '로컬 draft가 마지막 클라우드 저장본과 다릅니다.',
        )
      : t(
          'Save, load, and export fields match.',
          '저장, 로드, 내보내기 필드가 일치합니다.',
        )
  roundTripNoticeElement.innerHTML = `<span class="state-pill ${roundTripClass}">${roundTripLabel}</span><span>${escapeHtml(
    roundTripMessage,
  )}</span>`
}

function saveBoardMarkup(): string {
  const saveState = saveStateDisplay()
  const warning = placementWarning(spatialModel)
  const cloudLabel = spatialModel.hasUnsavedChanges ? t('previous cloud layout', '이전 클라우드 저장본') : t('cloud layout', '클라우드 저장본')
  return [
    {
      chipClass: saveState.className,
      chipLabel: saveState.label,
      title: cloudLabel,
      detail: usesKorean
        ? `${spatialModel.furniture.length}개 객체 · ${spatialModel.coordinateSpace} · ${spatialModel.viewMode.toUpperCase()}`
        : `${spatialModel.furniture.length} objects · ${spatialModel.coordinateSpace} · ${spatialModel.viewMode.toUpperCase()}`,
    },
    {
      chipClass: spatialModel.hasUnsavedChanges ? 'warning' : 'confirmed',
      chipLabel: spatialModel.hasUnsavedChanges ? t('local draft', '로컬 draft') : t('synced', '동기화됨'),
      title: t('local draft', '로컬 draft'),
      detail: warning ?? t('No placement warnings.', '배치 경고 없음.'),
    },
    {
      chipClass: persistenceStateValue === 'exportFailed' ? 'error' : 'measurement',
      chipLabel: persistenceStateValue === 'exportFailed' ? t('export failed', '내보내기 실패') : t('export', '내보내기'),
      title: 'layout-export.json',
      detail: t('room, furniture, camera, meta', 'room, furniture, camera, meta 포함'),
    },
  ]
    .map(
      (item) => `<div>
        <span class="state-pill ${item.chipClass}">${item.chipLabel}</span>
        <b>${escapeHtml(item.title)}</b>
        <span>${escapeHtml(item.detail)}</span>
      </div>`,
    )
    .join('')
}

function layoutExportPayload(): Record<string, unknown> {
  const bounds = roomBounds(spatialModel)
  return {
    export_format: 'roomforge_layout_json',
    export_version: 1,
    coordinate_space: spatialModel.coordinateSpace,
    unit: spatialModel.unit,
    scene_id: spatialModel.sceneId,
    room: {
      room_id: spatialModel.room.objectId,
      width_m: Number(bounds.widthMeters.toFixed(2)),
      depth_m: Number(bounds.depthMeters.toFixed(2)),
      height_m: spatialModel.room.heightMeters,
      floor_plan: spatialModel.room.floorPlan,
    },
    furniture_objects: spatialModel.furniture.map((item) => ({
      furniture_id: item.objectId,
      category: item.category,
      label: item.label,
      position_m: item.position,
      size_m: item.size,
      rotation_deg: item.rotationDegrees,
      locked: item.locked === true,
      source: item.source ?? 'catalog',
    })),
    editor_scene: {
      view_mode: spatialModel.viewMode,
      selected: spatialModel.selected,
      has_unsaved_changes: spatialModel.hasUnsavedChanges,
    },
    meta: {
      review_required: placementWarning(spatialModel) !== null,
      selected_load_source: selectedLoadSource,
    },
  }
}

function localizedLoadSourceMessage(source: LoadSource): string {
  if (source === 'draft') {
    return t('Local draft selected for load preview.', '로컬 draft를 로드 미리보기로 선택했습니다.')
  }
  if (source === 'export') {
    return t('Previous export selected for load preview.', '이전 export를 로드 미리보기로 선택했습니다.')
  }
  return t('Latest cloud layout selected for load preview.', '최신 클라우드 저장본을 로드 미리보기로 선택했습니다.')
}

function updateCursorCoordinates(event: PointerEvent): void {
  setPointerFromEvent(event)
  raycaster.setFromCamera(pointer, camera)
  const target = new THREE.Vector3()
  if (!raycaster.ray.intersectPlane(dragPlane, target)) {
    return
  }
  const metric = scenePointToMetric(target)
  cursorCoordsElement.textContent = `x ${metric.x.toFixed(2)} · y ${metric.y.toFixed(2)}`
}

function rebuildWalls(): void {
  for (const child of [...wallGroup.children]) {
    wallGroup.remove(child)
    if (child instanceof THREE.Mesh) {
      child.geometry.dispose()
    }
  }

  const height = spatialModel.room.heightMeters
  for (let index = 0; index < confirmedPoints.length; index += 1) {
    const start = confirmedPoints[index]
    const end = confirmedPoints[(index + 1) % confirmedPoints.length]
    const dx = end.x - start.x
    const dz = end.z - start.z
    const length = Math.hypot(dx, dz)
    const wall = new THREE.Mesh(new THREE.PlaneGeometry(length, height), wallMaterial)
    wall.position.set(start.x + dx / 2, height / 2, start.z + dz / 2)
    wall.rotation.y = -Math.atan2(dz, dx)
    wall.userData.objectId = spatialModel.room.objectId
    wallGroup.add(wall)
  }
}

function syncConfirmedGeometryMeshes(): void {
  const closedPoints = [...confirmedPoints, confirmedPoints[0]]
  confirmedLine.geometry.dispose()
  confirmedLine.geometry = new THREE.BufferGeometry().setFromPoints(closedPoints)

  selectionLine.geometry.dispose()
  selectionLine.geometry = new THREE.BufferGeometry().setFromPoints(
    closedPoints.map((point) => point.clone().setY(0.09)),
  )

  while (cornerMeshes.length < confirmedPoints.length) {
    const corner = new THREE.Mesh(new THREE.SphereGeometry(0.08, 16, 16), cornerMaterial)
    room.add(corner)
    cornerMeshes.push(corner)
  }
  while (cornerMeshes.length > confirmedPoints.length) {
    const corner = cornerMeshes.pop()
    if (corner) {
      room.remove(corner)
      corner.geometry.dispose()
    }
  }
  for (const [index, point] of confirmedPoints.entries()) {
    cornerMeshes[index].position.copy(point)
  }
  syncCornerHandleStyles()
  applyLayerVisibility()
}

function rebuildStructuralFixtures(): void {
  for (const child of [...fixtureGroup.children]) {
    fixtureGroup.remove(child)
    if (child instanceof THREE.Mesh || child instanceof THREE.LineSegments) {
      child.geometry.dispose()
    }
  }
  fixtureMeshes.clear()
  fixtureOutlineObjects.length = 0

  for (const fixture of spatialModel.structuralFixtures) {
    const isSelected =
      spatialModel.selected?.objectType === 'fixture' &&
      spatialModel.selected.objectId === fixture.fixtureId
    const size = fixture.size ?? { x: 0.8, y: 1, z: 0.1 }
    const height = spatialModel.viewMode === '2d' ? 0.07 : Math.max(size.y, 0.2)
    const depth = spatialModel.viewMode === '2d' ? 0.08 : Math.max(size.z, 0.06)
    const geometry = new THREE.BoxGeometry(Math.max(size.x, 0.2), height, depth)
    const material = new THREE.MeshBasicMaterial({
      color: new THREE.Color(fixtureColor(fixture.category)),
      transparent: true,
      opacity: fixture.confidenceScore !== undefined && fixture.confidenceScore < 0.7 ? 0.58 : 0.82,
    })
    const mesh = new THREE.Mesh(geometry, material)
    const position = fixtureScenePosition(fixture, height)
    mesh.position.copy(position)
    mesh.rotation.y = fixtureWallRotation(fixture.wallId)
    mesh.userData.objectId = fixture.fixtureId
    mesh.userData.objectType = 'fixture'
    fixtureGroup.add(mesh)
    fixtureMeshes.set(fixture.fixtureId, mesh)

    if (isSelected) {
      const outline = new THREE.LineSegments(new THREE.EdgesGeometry(geometry), furnitureSelectionMaterial)
      outline.position.copy(position)
      outline.rotation.copy(mesh.rotation)
      outline.scale.setScalar(1.06)
      outline.userData.objectId = fixture.fixtureId
      outline.userData.objectType = 'fixture-outline'
      fixtureGroup.add(outline)
      fixtureOutlineObjects.push(outline)
    }
  }
}

function rebuildFurniture(): void {
  for (const child of [...furnitureGroup.children]) {
    furnitureGroup.remove(child)
    if (child instanceof THREE.Mesh || child instanceof THREE.LineSegments) {
      child.geometry.dispose()
    }
  }
  furnitureMeshes.clear()
  furnitureOutlineObjects.length = 0

  for (const item of spatialModel.furniture) {
    const isSelected =
      spatialModel.selected?.objectType === 'furniture' &&
      spatialModel.selected.objectId === item.objectId
    const height = spatialModel.viewMode === '2d' ? 0.08 : item.size.heightMeters
    const geometry = new THREE.BoxGeometry(item.size.widthMeters, height, item.size.depthMeters)
    const material = new THREE.MeshBasicMaterial({
      color: new THREE.Color(item.color),
      transparent: true,
      opacity: spatialModel.viewMode === '2d' ? 0.72 : 0.86,
    })
    const mesh = new THREE.Mesh(geometry, material)
    const position = metricPointToScene(item.position.x, item.position.y, height / 2 + 0.03)
    mesh.position.copy(position)
    mesh.rotation.y = THREE.MathUtils.degToRad(item.rotationDegrees)
    mesh.userData.objectId = item.objectId
    mesh.userData.objectType = 'furniture'
    furnitureGroup.add(mesh)
    furnitureMeshes.set(item.objectId, mesh)

    if (isSelected) {
      const tokens = selectionVisualTokens({ selected: true })
      const outline = new THREE.LineSegments(new THREE.EdgesGeometry(geometry), furnitureSelectionMaterial)
      outline.position.copy(position)
      outline.rotation.copy(mesh.rotation)
      outline.scale.setScalar(tokens.scale)
      outline.userData.objectId = item.objectId
      outline.userData.objectType = tokens.marker
      furnitureGroup.add(outline)
      furnitureOutlineObjects.push(outline)
    }
  }
}

function updateCaptureSessionStatus(): void {
  if (!captureSessionForSceneUnderstanding) {
    captureSessionStatusElement.textContent = t(
      'No capture session images',
      '촬영 세션 이미지 없음',
    )
    return
  }
  const roleCount = captureSessionForSceneUnderstanding.availableRoles.length
  if (roleCount === 0) {
    captureSessionStatusElement.textContent = t(
      'No capture session images',
      '촬영 세션 이미지 없음',
    )
    return
  }
  const roleList = captureSessionForSceneUnderstanding.availableRoles.join(', ')
  captureSessionStatusElement.textContent = usesKorean
    ? `${roleCount}개 촬영 역할: ${roleList}`
    : captureRoleSummary(captureSessionForSceneUnderstanding)
}

function updateSpatialStatus(): void {
  spatialStatusElement.textContent = localizedSpatialSummary(spatialModel)
  sceneStatusElement.textContent = localizedSpatialSummary(spatialModel)
  inspectorStatusElement.textContent = inspectorSummary(spatialModel)
  measurementStatusElement.textContent = measurementSummary(spatialModel)
  updateCandidateTray()
  const warning = placementWarning(spatialModel)
  placementStatusElement.hidden = warning === null
  placementStatusElement.textContent = warning ?? ''
  placementSummaryElement.textContent = warning ?? t('All objects inside room bounds', '모든 객체가 방 경계 안에 있음')
  view2dButtonElement.setAttribute('aria-pressed', String(spatialModel.viewMode === '2d' && !splitViewActive))
  view3dButtonElement.setAttribute('aria-pressed', String(spatialModel.viewMode === '3d' && !splitViewActive))
  viewSplitButtonElement.setAttribute('aria-pressed', String(splitViewActive))
  view2dButtonElement.classList.toggle('is-active', spatialModel.viewMode === '2d' && !splitViewActive)
  view3dButtonElement.classList.toggle('is-active', spatialModel.viewMode === '3d' && !splitViewActive)
  viewSplitButtonElement.classList.toggle('is-active', splitViewActive)
  applyLayerVisibility()
  updateOutlineValidityPanel()
  updateScaleCalibrationPanel()
  updateFloorPlanReviewPanel()
  updateEditorStatusBar()
  updatePersistencePanel()
  const furnitureSelected = spatialModel.selected?.objectType === 'furniture'
  const fixtureSelected = spatialModel.selected?.objectType === 'fixture'
  const selected = selectedFurniture()
  const fixture = selectedFixture()
  furnitureCountElement.textContent = `${spatialModel.furniture.length} ${
    usesKorean ? '개 객체' : spatialModel.furniture.length === 1 ? 'object' : 'objects'
  }`
  furnitureCatalogStatusElement.textContent =
    spatialModel.furniture.length === 0
      ? t(
          'Catalog presets are available. Add one to start layout planning.',
          '카탈로그 프리셋을 사용할 수 있습니다. 하나를 추가해 배치를 시작하세요.',
        )
      : t(
          'Select an object in the viewport or add another preset.',
          '뷰포트에서 객체를 선택하거나 다른 프리셋을 추가하세요.',
        )
  selectionStateElement.textContent = selected
    ? selected.locked
      ? t('Locked', '잠김')
      : t('Selected', '선택됨')
    : fixture
      ? t('Fixture', '고정 요소')
    : t('Room', '방')
  selectionStateElement.className = selected
    ? selected.locked
      ? 'state-pill warning'
      : 'state-pill selected'
    : fixture
      ? 'state-pill measurement'
      : 'state-pill confirmed'
  updateFurnitureInspector(selected, fixture, warning)
  for (const button of furnitureEditButtons) {
    const action = button.dataset.furnitureEdit
    const locked = selected?.locked === true
    button.disabled =
      !furnitureSelected || (locked && action !== 'toggle-lock' && action !== 'delete')
    if (action === 'toggle-lock') {
      button.textContent = locked ? t('Unlock object', '객체 잠금 해제') : t('Lock object', '객체 잠금')
    }
  }
  for (const button of fixtureEditButtonElements) {
    button.disabled = !fixtureSelected
  }
}

function updateFurnitureInspector(
  selected: FurnitureObject | null,
  fixture: StructuralFixtureObject | null,
  warning: string | null,
): void {
  furnitureObjectListElement.innerHTML = furnitureObjectListMarkup()
  updateTransformControls(selected)

  if (selected) {
    selectedObjectTitleElement.textContent = localizedFurnitureLabel(selected)
    selectedObjectSourceElement.textContent =
      selected.source === 'cv_candidate'
        ? t('CV candidate proxy', 'CV 후보 프록시')
        : t('catalog proxy', '카탈로그 프록시')
  } else if (fixture) {
    selectedObjectTitleElement.textContent = localizedFixtureLabel(fixture)
    selectedObjectSourceElement.textContent = t('structural fixture', '구조 고정 요소')
  } else {
    selectedObjectTitleElement.textContent = t('Room shell', '방 외곽')
    selectedObjectSourceElement.textContent = t('meters coordinate space', 'meters 좌표계')
  }

  const selectedOutside = selected ? furnitureOutsideRoom(selected, roomBounds(spatialModel)) : false
  const warningMessage = selectedOutside
    ? t(
        `${selected?.label ?? 'Object'} is outside room bounds. Move or resize it before saving.`,
        `${selected ? localizedFurnitureLabel(selected) : '오브젝트'}이(가) 방 경계 밖에 있습니다. 저장 전에 이동하거나 크기를 조정하세요.`,
      )
    : warning && usesKorean
      ? '배치 경고가 있습니다. 저장 전에 모든 오브젝트를 방 경계 안으로 이동하거나 크기를 조정하세요.'
      : warning
  const stateClass = warningMessage ? 'collision' : 'confirmed'
  const stateLabel = warningMessage ? t('collision', '충돌') : t('clear', '정상')
  furniturePlacementWarningElement.innerHTML = `<span class="state-pill ${stateClass}">${stateLabel}</span><span>${escapeHtml(
    warningMessage ?? t('All objects inside room bounds', '모든 객체가 방 경계 안에 있음'),
  )}</span>`
}

function furnitureObjectListMarkup(): string {
  if (spatialModel.furniture.length === 0) {
    return `<p class="object-list-empty">${t(
      'No furniture proxies placed yet.',
      '아직 배치된 가구 프록시가 없습니다.',
    )}</p>`
  }

  const bounds = roomBounds(spatialModel)
  return spatialModel.furniture
    .map((item) => {
      const selected = spatialModel.selected?.objectId === item.objectId
      const state = furnitureObjectState(item, selected, bounds)
      return `<button class="object-chip${selected ? ' is-selected' : ''}${
        state.className === 'collision' ? ' is-collision' : ''
      }" type="button" role="listitem" data-furniture-select="${escapeAttribute(item.objectId)}">
        <strong>${escapeHtml(localizedFurnitureLabel(item))}</strong>
        <span class="state-pill ${state.className}">${state.label}</span>
        <small>${item.size.widthMeters.toFixed(2)} x ${item.size.depthMeters.toFixed(
          2,
        )} m · x ${item.position.x.toFixed(2)} · y ${item.position.y.toFixed(2)}</small>
      </button>`
    })
    .join('')
}

function furnitureObjectState(
  item: FurnitureObject,
  selected: boolean,
  bounds: ReturnType<typeof roomBounds>,
): { className: string; label: string } {
  if (furnitureOutsideRoom(item, bounds)) {
    return { className: 'collision', label: t('collision', '충돌') }
  }
  if (selected) {
    return { className: 'selected', label: t('selected', '선택됨') }
  }
  if (item.source === 'cv_candidate') {
    return { className: 'candidate', label: t('candidate', '후보') }
  }
  return { className: 'confirmed', label: t('confirmed', '확정') }
}

function updateTransformControls(selected: FurnitureObject | null): void {
  if (!selected) {
    transformXReadoutElement.textContent = '--'
    transformYReadoutElement.textContent = '--'
    transformRotationReadoutElement.textContent = '--'
    transformSizeReadoutElement.textContent = '--'
    for (const input of transformInputElements) {
      input.disabled = true
    }
    for (const output of transformOutputElements) {
      output.textContent = '--'
    }
    return
  }

  const bounds = roomBounds(spatialModel)
  transformXReadoutElement.textContent = `${selected.position.x.toFixed(2)} m`
  transformYReadoutElement.textContent = `${selected.position.y.toFixed(2)} m`
  transformRotationReadoutElement.textContent = `${selected.rotationDegrees.toFixed(0)} deg`
  transformSizeReadoutElement.textContent = `${selected.size.widthMeters.toFixed(
    2,
  )} x ${selected.size.depthMeters.toFixed(2)} x ${selected.size.heightMeters.toFixed(2)} m`
  setTransformControl('position-x', selected.position.x, 0, bounds.widthMeters, false)
  setTransformControl('position-y', selected.position.y, 0, bounds.depthMeters, false)
  setTransformControl('rotation', selected.rotationDegrees, 0, 345, false)
  setTransformControl('width', selected.size.widthMeters, 0.2, Math.max(bounds.widthMeters, 0.2), false)
  setTransformControl('depth', selected.size.depthMeters, 0.2, Math.max(bounds.depthMeters, 0.2), false)
  setTransformControl('height', selected.size.heightMeters, 0.2, Math.max(spatialModel.room.heightMeters, 0.2), false)
}

function setTransformControl(
  field: TransformField,
  value: number,
  min: number,
  max: number,
  disabled: boolean,
): void {
  const input = transformInputElements.find((item) => item.dataset.transformField === field)
  const output = transformOutputElements.find((item) => item.dataset.transformOutput === field)
  if (!input || !output) {
    return
  }
  input.disabled = disabled
  input.min = String(min)
  input.max = String(max)
  input.value = String(value)
  output.textContent = field === 'rotation' ? `${Math.round(value)} deg` : `${value.toFixed(2)} m`
}

function updateCandidateTray(): void {
  const items = candidateTrayItems(spatialModel)
  const activeCount = items.filter((item) => !item.rejected).length
  const coverage = currentSceneCoverage()
  candidateTrayCountElement.textContent = usesKorean
    ? `후보 ${items.length}개`
    : `${items.length} ${items.length === 1 ? 'candidate' : 'candidates'}`
  if (items.length === 0) {
    candidateTrayStatusElement.textContent = t(
      'No CV candidates loaded.',
      '불러온 CV 후보가 없습니다.',
    )
    candidateTrayListElement.innerHTML = ''
    return
  }
  const needsReviewCount = items.filter((item) => item.lowConfidence && !item.rejected).length
  const guidance = localizedCoverageGuidance(coverage)
  candidateTrayStatusElement.textContent = usesKorean
    ? `활성 후보 ${activeCount}개; 검토 필요 ${needsReviewCount}개. ${guidance}`
    : `${activeCount} active candidates; ${needsReviewCount} need review. ${guidance}`
  candidateTrayListElement.innerHTML = items.map(candidateTrayItemMarkup).join('')
}

function currentSceneCoverage(): SceneCoverageSummary {
  return computeSceneCoverage({
    availableRoles: captureSessionForSceneUnderstanding?.availableRoles ?? [],
    images: captureSessionForSceneUnderstanding?.images ?? [],
    candidateObjects: spatialModel.candidateObjects,
    structuralFixtures: spatialModel.structuralFixtures,
  })
}

function localizedCoverageGuidance(summary: SceneCoverageSummary): string {
  const guidance = coverageGuidanceText(summary)
  if (!usesKorean) {
    return guidance
  }
  if (summary.canContinue) {
    return '촬영 범위가 충분합니다. 생성된 배치를 계속 편집하세요.'
  }
  const role = (summary.guidance[0] ?? '').match(/(front_wall|right_wall|back_wall|left_wall)/)?.[0] ?? 'wall'
  if ((summary.guidance[0] ?? '').startsWith('Capture')) {
    return `${role} 사진을 추가로 촬영하세요.`
  }
  if ((summary.guidance[0] ?? '').startsWith('Retake')) {
    return `${role} 사진을 벽과 가구가 보이도록 다시 촬영하세요.`
  }
  return `${role} 사진을 각도를 바꿔 추가하거나 수동으로 확인하세요.`
}

function candidateTrayItemMarkup(item: ReturnType<typeof candidateTrayItems>[number]): string {
  const stateClass = item.placed
    ? ' confirmed'
    : item.rejected || item.lowConfidence
      ? ' warning'
      : ' candidate'
  const cardStateClass = item.placed
    ? ' is-accepted'
    : item.lowConfidence
      ? ' is-low-confidence'
      : ''
  const disabled = item.rejected ? ' disabled' : ''
  const placeDisabled = item.rejected || item.placed ? ' disabled' : ''
  const placeText = item.placed ? t('Placed', '배치됨') : t('Place', '배치')
  const rejectText = item.rejected ? t('Rejected', '거절됨') : t('Reject', '거절')
  return `
    <article class="candidate-card${item.rejected ? ' is-rejected' : ''}${cardStateClass}" role="listitem" data-candidate-id="${escapeAttribute(
      item.candidateId,
    )}">
      <div class="candidate-card-header">
        <strong>${escapeHtml(item.label)}</strong>
        <span class="state-pill${stateClass}">${escapeHtml(localizedCandidateState(item.reviewLabel))}</span>
      </div>
      <dl class="candidate-meta">
        <div>
          <dt>${t('Confidence', '신뢰도')}</dt>
          <dd>${escapeHtml(item.confidenceLabel)}</dd>
        </div>
        <div>
          <dt>${t('Source', '소스')}</dt>
          <dd>${escapeHtml(item.sourceLabel)}</dd>
        </div>
      </dl>
      <label class="candidate-category-field">
        <span>${t('Category', '카테고리')}</span>
        <select data-candidate-category data-candidate-id="${escapeAttribute(item.candidateId)}"${disabled}>
          ${candidateCategoryOptions
            .map(
              (category) =>
                `<option value="${escapeAttribute(category)}"${category === item.category ? ' selected' : ''}>${escapeHtml(
                  category,
                )}</option>`,
            )
            .join('')}
        </select>
      </label>
      <div class="candidate-card-actions">
        <button type="button" data-candidate-action="reject" data-candidate-id="${escapeAttribute(
          item.candidateId,
        )}"${disabled}>${rejectText}</button>
        <button type="button" data-candidate-action="place" data-candidate-id="${escapeAttribute(
          item.candidateId,
        )}"${placeDisabled}>${placeText}</button>
      </div>
    </article>
  `
}

function placeCandidate(candidateId: string): void {
  const nextModel = placeCandidateInModel(spatialModel, candidateId)
  if (nextModel === spatialModel) {
    return
  }
  spatialModel = nextModel
  rebuildFurniture()
  geometryStatusElement.textContent = t(
    'Candidate placed as an editable furniture object.',
    '후보를 편집 가능한 가구 객체로 배치했습니다.',
  )
  updateSpatialStatus()
  emitSceneState('roomforge.candidate.placed')
}

function rejectCandidate(candidateId: string): void {
  const nextModel = rejectCandidateInModel(spatialModel, candidateId)
  if (nextModel === spatialModel) {
    return
  }
  spatialModel = nextModel
  rebuildFurniture()
  geometryStatusElement.textContent = t(
    'Candidate rejected and removed from placed CV objects.',
    '후보를 거절하고 배치된 CV 객체에서 제거했습니다.',
  )
  updateSpatialStatus()
  emitSceneState('roomforge.candidate.updated')
}

function updateCandidateCategory(candidateId: string, category: string): void {
  const nextModel = updateCandidateCategoryInModel({
    model: spatialModel,
    candidateId,
    category,
  })
  if (nextModel === spatialModel) {
    return
  }
  spatialModel = recalculateCandidatePlacements(nextModel)
  geometryStatusElement.textContent = t(
    `Candidate category changed to ${category}; suggested size and asset were recalculated.`,
    `후보 카테고리를 ${category}(으)로 변경했습니다. 추천 크기와 에셋을 다시 계산했습니다.`,
  )
  updateSpatialStatus()
  emitSceneState('roomforge.candidate.updated')
}

function localizedCandidateState(label: string): string {
  if (!usesKorean) {
    return label
  }
  if (label === 'Needs review') {
    return '검토 필요'
  }
  if (label === 'Rejected') {
    return '거절됨'
  }
  if (label === 'Placed') {
    return '배치됨'
  }
  return '후보'
}

function escapeHtml(value: string): string {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;')
}

function escapeAttribute(value: string): string {
  return escapeHtml(value)
}

function localizedSpatialSummary(model: SpatialModel): string {
  const bounds = roomBounds(model)
  const selected =
    model.selected?.objectType === 'furniture'
      ? selectedFurniture()?.label ?? model.selected.objectId
      : model.selected?.objectType === 'fixture'
        ? selectedFixture()?.label ?? model.selected.objectId
      : t('room shell', '방 외곽')
  const saveState = model.hasUnsavedChanges ? t('Unsaved changes', '저장 안 됨') : t('Saved', '저장됨')
  const furnitureCount = usesKorean
    ? `가구 ${model.furniture.length}개`
    : `${model.furniture.length} furniture`

  return t(
    `${model.viewMode.toUpperCase()} | ${bounds.widthMeters.toFixed(2)} m x ${bounds.depthMeters.toFixed(
      2,
    )} m | ${furnitureCount} | selected ${selected} | ${saveState}`,
    `${model.viewMode.toUpperCase()} | ${bounds.widthMeters.toFixed(2)} m x ${bounds.depthMeters.toFixed(
      2,
    )} m | ${furnitureCount} | 선택 ${selected} | ${saveState}`,
  )
}

function emitSceneState(type: string, requestId?: string): void {
  postToParent({
    type,
    version: BRIDGE_VERSION,
    requestId,
    payload: spatialModelPayload(),
  })
}

function spatialModelPayload(): Record<string, unknown> {
  return {
    sceneId: spatialModel.sceneId,
    coordinateSpace: spatialModel.coordinateSpace,
    unit: spatialModel.unit,
    viewMode: spatialModel.viewMode,
    selected: spatialModel.selected,
    hasUnsavedChanges: spatialModel.hasUnsavedChanges,
    scale: spatialModel.scale,
    room: spatialModel.room,
    furniture: spatialModel.furniture,
    candidateObjects: spatialModel.candidateObjects,
    placedObjects: spatialModel.placedObjects,
    confirmedObjects: spatialModel.confirmedObjects,
    structuralFixtures: spatialModel.structuralFixtures,
  }
}

function addFurniture(category: FurnitureCategory): void {
  furnitureIdCounter += 1
  const item = furnitureDefaults({
    category,
    id: `furniture-${category}-${Date.now()}-${furnitureIdCounter}`,
    model: spatialModel,
  })
  spatialModel = addFurnitureToModel(spatialModel, item)
  rebuildFurniture()
  updateSpatialStatus()
  emitSceneState('roomforge.selection.changed')
}

function selectFurniture(objectId: unknown): void {
  if (typeof objectId !== 'string') {
    return
  }
  const nextModel = selectFurnitureInModel(spatialModel, objectId)
  if (nextModel === spatialModel) {
    return
  }
  spatialModel = nextModel
  rebuildFurniture()
  updateSpatialStatus()
  emitSceneState('roomforge.selection.changed')
}

function selectFixture(objectId: unknown): void {
  if (typeof objectId !== 'string') {
    return
  }
  const nextModel = selectFixtureInModel(spatialModel, objectId)
  if (nextModel === spatialModel) {
    return
  }
  spatialModel = nextModel
  rebuildStructuralFixtures()
  updateSpatialStatus()
  emitSceneState('roomforge.selection.changed')
}

function editSelectedFurniture(action: FurnitureEditAction): void {
  const startedAt = performance.now()
  const result = editSelectedFurnitureInModel(spatialModel, action)
  const selected = result.selected
  if (!selected) {
    return
  }
  if (result.blockedByLock) {
    geometryStatusElement.textContent = t(
      `${selected.label} is locked. Unlock it before editing.`,
      `${localizedFurnitureLabel(selected)}은 잠겨 있습니다. 편집 전에 잠금을 해제하세요.`,
    )
    updateSpatialStatus()
    return
  }
  if (!result.changed) {
    return
  }

  spatialModel = result.model
  if (action === 'toggle-lock') {
    geometryStatusElement.textContent = selected.locked
      ? t(`${selected.label} unlocked.`, `${localizedFurnitureLabel(selected)} 잠금 해제됨.`)
      : t(`${selected.label} locked.`, `${localizedFurnitureLabel(selected)} 잠김.`)
  } else if (result.deleted) {
    spatialModel = selected.candidateId
      ? releaseCandidatePlacementInModel(spatialModel, selected.candidateId)
      : spatialModel
    geometryStatusElement.textContent = t(`Deleted ${selected.label}.`, `${localizedFurnitureLabel(selected)} 삭제됨.`)
  } else {
    const elapsed = performance.now() - startedAt
    geometryStatusElement.textContent = t(
      `Updated ${selected.label} in ${elapsed.toFixed(1)} ms.`,
      `${localizedFurnitureLabel(selected)} 업데이트됨 (${elapsed.toFixed(1)} ms).`,
    )
  }
  rebuildFurniture()
  updateSpatialStatus()
  emitSceneState('roomforge.scene.updated')
}

function updateSelectedFurnitureTransform(field: TransformField, value: number): void {
  const selected = selectedFurniture()
  if (!selected || !Number.isFinite(value)) {
    return
  }
  if (selected.locked) {
    geometryStatusElement.textContent = t(
      `${selected.label} is locked. Unlock it before editing.`,
      `${localizedFurnitureLabel(selected)}은 잠겨 있습니다. 편집 전에 잠금을 해제하세요.`,
    )
    updateSpatialStatus()
    return
  }

  const bounds = roomBounds(spatialModel)
  const nextItem = transformFurnitureObject(selected, field, value, bounds)
  spatialModel = {
    ...spatialModel,
    hasUnsavedChanges: true,
    furniture: spatialModel.furniture.map((item) =>
      item.objectId === selected.objectId ? nextItem : item,
    ),
  }
  rebuildFurniture()
  geometryStatusElement.textContent = t(
    `Updated ${selected.label} transform.`,
    `${localizedFurnitureLabel(selected)} 변환 값을 업데이트했습니다.`,
  )
  updateSpatialStatus()
  emitSceneState('roomforge.scene.updated')
}

function transformFurnitureObject(
  item: FurnitureObject,
  field: TransformField,
  value: number,
  bounds: ReturnType<typeof roomBounds>,
): FurnitureObject {
  if (field === 'position-x') {
    return {
      ...item,
      position: { ...item.position, x: Number(clampNumber(value, 0, bounds.widthMeters).toFixed(2)) },
    }
  }
  if (field === 'position-y') {
    return {
      ...item,
      position: { ...item.position, y: Number(clampNumber(value, 0, bounds.depthMeters).toFixed(2)) },
    }
  }
  if (field === 'rotation') {
    return { ...item, rotationDegrees: Math.round(clampNumber(value, 0, 345)) }
  }
  if (field === 'width') {
    return {
      ...item,
      size: {
        ...item.size,
        widthMeters: Number(clampNumber(value, 0.2, Math.max(bounds.widthMeters, 0.2)).toFixed(2)),
      },
    }
  }
  if (field === 'depth') {
    return {
      ...item,
      size: {
        ...item.size,
        depthMeters: Number(clampNumber(value, 0.2, Math.max(bounds.depthMeters, 0.2)).toFixed(2)),
      },
    }
  }
  return {
    ...item,
    size: {
      ...item.size,
      heightMeters: Number(clampNumber(value, 0.2, Math.max(spatialModel.room.heightMeters, 0.2)).toFixed(2)),
    },
  }
}

function editSelectedFixture(action: FixtureEditAction): void {
  const result = editSelectedFixtureInModel(spatialModel, action)
  const selected = result.selected
  if (!selected || !result.changed) {
    return
  }
  spatialModel = result.model
  rebuildStructuralFixtures()
  geometryStatusElement.textContent = result.deleted
    ? t(`Deleted ${selected.label ?? selected.category}.`, `${localizedFixtureLabel(selected)} 삭제됨.`)
    : t(
        `Updated ${selected.label ?? selected.category}.`,
        `${localizedFixtureLabel(selected)} 업데이트됨.`,
      )
  updateSpatialStatus()
  emitSceneState('roomforge.fixture.updated')
}

function selectedFurniture(): FurnitureObject | null {
  return selectedFurnitureFromModel(spatialModel)
}

function selectedFixture(): StructuralFixtureObject | null {
  return selectedFixtureFromModel(spatialModel)
}

function localizedFurnitureLabel(item: FurnitureObject): string {
  if (!usesKorean) {
    return item.label
  }
  if (item.category === 'bed') {
    return '침대'
  }
  if (item.category === 'desk') {
    return '책상'
  }
  if (item.category === 'chair') {
    return '의자'
  }
  if (item.category === 'wardrobe') {
    return '수납장'
  }
  if (item.category === 'table') {
    return '테이블'
  }
  if (item.category === 'sofa') {
    return '소파'
  }
  if (item.category === 'shelf') {
    return '선반'
  }
  if (item.category === 'cabinet') {
    return '캐비닛'
  }
  return item.label
}

function localizedFixtureLabel(item: StructuralFixtureObject): string {
  if (!usesKorean) {
    return item.label ?? item.category
  }
  if (item.category === 'window') {
    return '창문'
  }
  if (item.category === 'door') {
    return '문'
  }
  if (item.category === 'built_in') {
    return '붙박이 요소'
  }
  return item.label ?? item.category
}

function applyCameraAction(action: CameraAction): void {
  if (spatialModel.viewMode !== '3d') {
    spatialModel = { ...spatialModel, viewMode: '3d' }
    wallGroup.visible = true
    updateSpatialStatus()
  }
  queueCameraSnapshot(cameraSnapshotFor(action), cameraLabelFor(action), true)
}

function cameraSnapshotFor(action: CameraAction): CameraSnapshot {
  return cameraSnapshotForRoom({
    action,
    bounds: roomBounds(spatialModel),
    roomHeightMeters: spatialModel.room.heightMeters,
    fovDegrees: camera.fov,
    labels: {
      reset: t('Reset camera preset', '카메라 프리셋 초기화'),
      fit: t('Fit-to-room camera preset', '방 맞춤 카메라 프리셋'),
      top: t('Top camera preset', '상단 카메라 프리셋'),
      front: t('Front camera preset', '정면 카메라 프리셋'),
      corner: t('Corner camera preset', '코너 카메라 프리셋'),
      eye: t('Eye-level camera preset', '눈높이 카메라 프리셋'),
    },
  })
}

function queueCameraSnapshot(snapshot: CameraSnapshot, status: string, animate: boolean): void {
  const reducedMotion = reducedMotionMedia.matches
  cameraStatusElement.textContent = reducedMotion
    ? `${status}; ${t('reduced motion', '움직임 줄임')}`
    : `${status}; ${t('camera moving', '카메라 이동 중')}`
  if (!shouldAnimateCamera({ reducedMotion, animate })) {
    applyCameraSnapshot(snapshot)
    emitCameraChanged()
    return
  }
  cameraTransition = {
    from: currentCameraSnapshot('Current camera'),
    to: snapshot,
    startedAt: performance.now(),
    durationMs: 180,
  }
}

function updateCameraTransition(): void {
  if (!cameraTransition) {
    return
  }
  const elapsed = performance.now() - cameraTransition.startedAt
  const progress = Math.min(elapsed / cameraTransition.durationMs, 1)
  const eased = 1 - (1 - progress) ** 3
  camera.position.lerpVectors(cameraTransition.from.position, cameraTransition.to.position, eased)
  camera.up.lerpVectors(cameraTransition.from.up, cameraTransition.to.up, eased).normalize()
  cameraTarget.lerpVectors(cameraTransition.from.target, cameraTransition.to.target, eased)
  camera.lookAt(cameraTarget)
  camera.updateProjectionMatrix()
  if (progress >= 1) {
    const label = cameraTransition.to.label
    cameraTransition = null
    cameraStatusElement.textContent = label
    emitCameraChanged()
  }
}

function applyCameraSnapshot(snapshot: CameraSnapshot): void {
  camera.position.copy(snapshot.position)
  camera.up.copy(snapshot.up)
  cameraTarget.copy(snapshot.target)
  camera.lookAt(cameraTarget)
  camera.updateProjectionMatrix()
  cameraStatusElement.textContent = snapshot.label
}

function currentCameraSnapshot(label: string): CameraSnapshot {
  return {
    position: camera.position.clone(),
    target: cameraTarget.clone(),
    up: camera.up.clone(),
    label,
  }
}

function orbitCamera(deltaX: number, deltaY: number): void {
  const offset = camera.position.clone().sub(cameraTarget)
  const spherical = new THREE.Spherical().setFromVector3(offset)
  spherical.theta -= deltaX * 0.006
  spherical.phi = THREE.MathUtils.clamp(spherical.phi - deltaY * 0.006, 0.18, Math.PI - 0.18)
  camera.position.copy(new THREE.Vector3().setFromSpherical(spherical).add(cameraTarget))
  camera.up.set(0, 1, 0)
  camera.lookAt(cameraTarget)
  camera.updateProjectionMatrix()
}

function panCamera(deltaX: number, deltaY: number): void {
  const distance = Math.max(camera.position.distanceTo(cameraTarget), 1)
  const amount = distance * 0.0015
  const forward = new THREE.Vector3()
  camera.getWorldDirection(forward)
  const right = new THREE.Vector3().crossVectors(forward, camera.up).normalize()
  const up = camera.up.clone().normalize()
  const offset = right.multiplyScalar(-deltaX * amount).add(up.multiplyScalar(deltaY * amount))
  camera.position.add(offset)
  cameraTarget.add(offset)
  camera.lookAt(cameraTarget)
  camera.updateProjectionMatrix()
}

function zoomCamera(deltaY: number): void {
  const offset = camera.position.clone().sub(cameraTarget)
  const scale = THREE.MathUtils.clamp(1 + deltaY * 0.001, 0.72, 1.32)
  const nextDistance = THREE.MathUtils.clamp(offset.length() * scale, 0.8, 30)
  camera.position.copy(cameraTarget.clone().add(offset.normalize().multiplyScalar(nextDistance)))
  camera.lookAt(cameraTarget)
  camera.updateProjectionMatrix()
}

function emitCameraChanged(): void {
  postToParent({
    type: 'roomforge.camera.changed',
    version: BRIDGE_VERSION,
    payload: {
      cameraPose: cameraPosePayload(),
      reducedMotion: reducedMotionMedia.matches,
    },
  })
}

function cameraPosePayload(): Record<string, unknown> {
  return {
    position: vectorPayload(camera.position),
    target: vectorPayload(cameraTarget),
    up: vectorPayload(camera.up),
  }
}

function vectorPayload(vector: THREE.Vector3): Record<string, number> {
  return {
    x: Number(vector.x.toFixed(3)),
    y: Number(vector.y.toFixed(3)),
    z: Number(vector.z.toFixed(3)),
  }
}

function cameraLabelFor(action: CameraAction): string {
  if (action === 'fit') {
    return t('Fit-to-room', '방에 맞춤')
  }
  const labels: Record<CameraAction, string> = {
    reset: t('Reset view', '보기 초기화'),
    fit: t('Fit-to-room', '방에 맞춤'),
    top: t('Top view', '상단 보기'),
    front: t('Front view', '정면 보기'),
    corner: t('Corner view', '코너 보기'),
    eye: t('Eye-level view', '눈높이 보기'),
  }
  return labels[action]
}

function metricPointToScene(x: number, y: number, height = 0): THREE.Vector3 {
  const bounds = roomBounds(spatialModel)
  return new THREE.Vector3(x - bounds.centerX, height, y - bounds.centerY)
}

function fixtureScenePosition(fixture: StructuralFixtureObject, height: number): THREE.Vector3 {
  const bounds = roomBounds(spatialModel)
  const size = fixture.size ?? { x: 0.8, y: 1, z: 0.1 }
  const position = fixture.position ?? { x: bounds.centerX, y: size.y / 2, z: 0 }
  const wallPoint = fixtureWallMetricPoint(fixture.wallId, position.x, bounds)
  const y = spatialModel.viewMode === '2d' ? 0.11 : Math.max(position.y, height / 2)
  return metricPointToScene(wallPoint.x, wallPoint.y, y)
}

function fixtureWallMetricPoint(
  wallId: string,
  offset: number,
  bounds: { widthMeters: number; depthMeters: number },
): { x: number; y: number } {
  if (wallId === 'right-wall') {
    return { x: bounds.widthMeters, y: clampNumber(offset, 0, bounds.depthMeters) }
  }
  if (wallId === 'back-wall') {
    return { x: clampNumber(bounds.widthMeters - offset, 0, bounds.widthMeters), y: bounds.depthMeters }
  }
  if (wallId === 'left-wall') {
    return { x: 0, y: clampNumber(bounds.depthMeters - offset, 0, bounds.depthMeters) }
  }
  return { x: clampNumber(offset, 0, bounds.widthMeters), y: 0 }
}

function fixtureWallRotation(wallId: string): number {
  if (wallId === 'right-wall' || wallId === 'left-wall') {
    return Math.PI / 2
  }
  return 0
}

function fixtureColor(category: string): string {
  if (category === 'door') {
    return '#8b6f61'
  }
  if (category === 'built_in') {
    return '#64748b'
  }
  return '#2563eb'
}

function scenePointToMetric(point: THREE.Vector3): { x: number; y: number } {
  const bounds = roomBounds(spatialModel)
  return {
    x: Number((point.x + bounds.centerX).toFixed(3)),
    y: Number((point.z + bounds.centerY).toFixed(3)),
  }
}

function requestCandidateExtraction(): void {
  if (!sourceImageForExtraction?.dataUrl) {
    const payload = noSourceImagePayload()
    applyCandidateExtraction(payload)
    postToParent({
      type: 'roomforge.opencv.candidatesExtracted',
      version: BRIDGE_VERSION,
      requestId: `opencv-candidate-extract-${Date.now()}`,
      payload,
    })
    postCandidateQualityWarning()
    return
  }

  const activeWorker = ensureOpenCvWorker()
  if (!runtimeReady) {
    opencvStatusElement.textContent = t('Loading OpenCV.js runtime', 'OpenCV.js 런타임 로드 중')
    return
  }

  activeWorker.postMessage({
    type: 'roomforge.opencv.extractCandidates',
    version: BRIDGE_VERSION,
    requestId: `opencv-candidate-extract-${Date.now()}`,
    payload: {
      sourceImage: sourceImageForExtraction ?? {},
    },
  } satisfies BridgeMessage)
  opencvStatusElement.textContent = t('Extracting OpenCV candidates', 'OpenCV 후보 추출 중')
}

function noSourceImagePayload(): Record<string, unknown> {
  return {
    sourceImageId: sourceImageForExtraction?.sourceImageId,
    coordinateSpace: 'image_pixels',
    confidence: 0,
    qualityStatus: 'failed',
    reasonCode: 'no_source_image',
    reasonMessage: 'Source image bytes are only available in the current browser session.',
    algorithm: 'opencv-js-canny-hough-v1',
    candidateGeometry: {
      image: {
        widthPx: sourceImageForExtraction?.widthPx,
        heightPx: sourceImageForExtraction?.heightPx,
      },
      candidateEdges: [],
      candidateLines: [],
      candidateCorners: [],
      boundaryHints: [],
      candidateSets: [],
      overlayStyle: {
        candidate: 'dashed-low-opacity-purple',
        confirmed: 'solid-blue-with-handles',
      },
    },
  }
}

function applyCandidateExtraction(payload: Record<string, unknown>): void {
  const geometry = recordFromUnknown(payload.candidateGeometry)
  latestCandidateGeometry = geometry
  latestCandidateQualityStatus = stringFromUnknown(payload.qualityStatus) ?? 'review_required'
  latestCandidateReasonCode = stringFromUnknown(payload.reasonCode) ?? null
  latestCandidateReasonMessage = stringFromUnknown(payload.reasonMessage) ?? null

  const confidence = numberFromUnknown(payload.confidence, 0)
  const boundaryPoints = candidateBoundaryPoints(geometry)
  candidateCountElement.textContent =
    boundaryPoints.length >= 3 ? t('1 set', '1개 세트') : t('0 sets', '0개 세트')
  candidateConfidenceElement.textContent = confidence.toFixed(2)

  if (boundaryPoints.length >= 3) {
    updateCandidateLineFromImagePoints(boundaryPoints, geometry)
    geometryStatusElement.textContent =
      latestCandidateQualityStatus === 'success'
        ? t('OpenCV candidate outline extracted.', 'OpenCV 후보 윤곽을 추출했습니다.')
        : t('OpenCV candidate outline needs review.', 'OpenCV 후보 윤곽 검토가 필요합니다.')
  } else {
    geometryStatusElement.textContent = t(
      'OpenCV could not form a candidate outline.',
      'OpenCV가 후보 윤곽을 만들지 못했습니다.',
    )
  }

  opencvStatusElement.textContent =
    latestCandidateQualityStatus === 'failed'
      ? t('Candidate extraction failed', '후보 추출 실패')
      : latestCandidateQualityStatus === 'success'
        ? t('Candidate extraction complete', '후보 추출 완료')
        : t('Candidate extraction needs review', '후보 추출 검토 필요')
}

function postCandidateQualityWarning(): void {
  if (latestCandidateQualityStatus === 'success') {
    return
  }
  postToParent({
    type: 'roomforge.reconstruction.qualityWarning',
    version: BRIDGE_VERSION,
    payload: {
      status: latestCandidateQualityStatus,
      label:
        latestCandidateQualityStatus === 'failed'
          ? t('Failed', '실패')
          : t('Needs review', '검토 필요'),
      reasonCode: latestCandidateReasonCode,
      reasonMessage:
        latestCandidateReasonMessage ??
        t(
          'Candidate geometry should be reviewed before save or export.',
          '저장 또는 내보내기 전에 후보 지오메트리를 검토해야 합니다.',
        ),
      recoveryActions: ['manual_outline', 'corner_correction', 'reupload'],
    },
  })
}

function candidateGeometry(): Record<string, unknown> {
  if (latestCandidateGeometry !== null) {
    return latestCandidateGeometry
  }
  const widthPx = sourceImageForExtraction?.widthPx ?? 1600
  const heightPx = sourceImageForExtraction?.heightPx ?? 1200
  return {
    image: {
      widthPx,
      heightPx,
    },
    candidateSets: [
      {
        id: 'candidate-1',
        kind: 'room_boundary',
        coordinateSpace: 'image_pixels',
        points: [
          { x: widthPx * 0.075, y: heightPx * 0.2 },
          { x: widthPx * 0.8875, y: heightPx * 0.183 },
          { x: widthPx * 0.925, y: heightPx * 0.817 },
          { x: widthPx * 0.1125, y: heightPx * 0.85 },
        ],
      },
    ],
    overlayStyle: {
      candidate: 'dashed-low-opacity-purple',
      confirmed: 'solid-blue-with-handles',
    },
  }
}

function sourceImageFromPayload(payload: Record<string, unknown>): SourceImageForExtraction | null {
  const direct = recordFromUnknown(payload.sourceImage)
  const scene = recordFromUnknown(payload.scene)
  const fromScene = recordFromUnknown(scene.sourceImage)
  const sourceImage = Object.keys(direct).length > 0 ? direct : fromScene
  const dataUrl = stringFromUnknown(sourceImage.dataUrl)
  const sourceImageId = stringFromUnknown(sourceImage.sourceImageId)
  const widthPx = positiveNumberFromUnknown(sourceImage.widthPx)
  const heightPx = positiveNumberFromUnknown(sourceImage.heightPx)
  const contentType = stringFromUnknown(sourceImage.contentType)
  if (!dataUrl && !sourceImageId && !widthPx && !heightPx && !contentType) {
    return null
  }
  return {
    dataUrl,
    sourceImageId,
    widthPx,
    heightPx,
    contentType,
  }
}

function updateCandidateLineFromImagePoints(
  imagePoints: Array<{ x: number; y: number }>,
  geometry: Record<string, unknown>,
): void {
  const image = candidateImageMetadata(geometry)
  const nextPoints = imagePoints.map((point) =>
    imagePointToScene(point, image.widthPx, image.heightPx),
  )
  if (nextPoints.length < 3) {
    return
  }
  const firstPoint = nextPoints[0]
  const lastPoint = nextPoints[nextPoints.length - 1]
  candidatePoints =
    firstPoint.distanceTo(lastPoint) < 0.001 ? nextPoints : [...nextPoints, firstPoint.clone()]
  candidateLine.geometry.dispose()
  candidateLine.geometry = new THREE.BufferGeometry().setFromPoints(candidatePoints)
  candidateLine.computeLineDistances()
}

function candidateBoundaryPoints(geometry: Record<string, unknown>): Array<{ x: number; y: number }> {
  const candidateSets = listFromUnknown(geometry.candidateSets)
  const firstSet = recordFromUnknown(candidateSets[0])
  const candidateSetPoints = pointsFromUnknown(firstSet.points)
  if (candidateSetPoints.length >= 3) {
    return candidateSetPoints
  }

  const boundaryHints = listFromUnknown(geometry.boundaryHints)
  const firstBoundary = recordFromUnknown(boundaryHints[0])
  const boundaryPoints = pointsFromUnknown(firstBoundary.points)
  if (boundaryPoints.length >= 3) {
    return boundaryPoints
  }

  return pointsFromUnknown(geometry.candidateCorners)
}

function candidateImageMetadata(geometry: Record<string, unknown>): {
  widthPx: number
  heightPx: number
} {
  const image = recordFromUnknown(geometry.image)
  return {
    widthPx: positiveNumberFromUnknown(image.widthPx) ?? sourceImageForExtraction?.widthPx ?? 1600,
    heightPx: positiveNumberFromUnknown(image.heightPx) ?? sourceImageForExtraction?.heightPx ?? 1200,
  }
}

function imagePointToScene(point: { x: number; y: number }, widthPx: number, heightPx: number): THREE.Vector3 {
  const bounds = roomBounds(spatialModel)
  const metricX = clampNumber(point.x / Math.max(widthPx, 1), 0, 1) * bounds.widthMeters
  const metricY = clampNumber(point.y / Math.max(heightPx, 1), 0, 1) * bounds.depthMeters
  return metricPointToScene(metricX, metricY, 0.06)
}

function scenePointToImage(point: THREE.Vector3): { x: number; y: number } {
  const geometry = candidateGeometry()
  const image = candidateImageMetadata(geometry)
  const bounds = roomBounds(spatialModel)
  const metricPoint = scenePointToMetric(point)
  return {
    x: Math.round(clampNumber(metricPoint.x / Math.max(bounds.widthMeters, 0.001), 0, 1) * image.widthPx),
    y: Math.round(clampNumber(metricPoint.y / Math.max(bounds.depthMeters, 0.001), 0, 1) * image.heightPx),
  }
}

function recordFromUnknown(value: unknown): Record<string, unknown> {
  return typeof value === 'object' && value !== null ? (value as Record<string, unknown>) : {}
}

function listFromUnknown(value: unknown): unknown[] {
  return Array.isArray(value) ? value : []
}

function pointsFromUnknown(value: unknown): Array<{ x: number; y: number }> {
  return listFromUnknown(value)
    .map(recordFromUnknown)
    .map((point) => {
      const x = numberFromUnknown(point.x, Number.NaN)
      const y = numberFromUnknown(point.y, Number.NaN)
      return { x, y }
    })
    .filter((point) => Number.isFinite(point.x) && Number.isFinite(point.y))
}

function stringFromUnknown(value: unknown): string | undefined {
  return typeof value === 'string' && value.length > 0 ? value : undefined
}

function numberFromUnknown(value: unknown, fallback: number): number {
  return typeof value === 'number' && Number.isFinite(value) ? value : fallback
}

function positiveNumberFromUnknown(value: unknown): number | undefined {
  return typeof value === 'number' && Number.isFinite(value) && value > 0 ? value : undefined
}

function clampNumber(value: number, min: number, max: number): number {
  return Math.min(Math.max(value, min), max)
}

function updateConfirmedGeometry(message: string, emit = true): void {
  scaleNeedsRecalculation = true
  spatialModel = {
    ...spatialModel,
    hasUnsavedChanges: true,
    room: {
      ...spatialModel.room,
      floorPlan: {
        ...spatialModel.room.floorPlan,
        metricGeometry: {
          coordinateSpace: 'meters',
          points: confirmedPoints.map(scenePointToMetric),
        },
      },
    },
  }
  spatialModel = recalculateCandidatePlacements(spatialModel)

  syncConfirmedGeometryMeshes()
  rebuildWalls()
  geometryStatusElement.textContent = message
  updateSpatialStatus()
  if (emit) {
    postToParent({
      type: 'roomforge.geometry.confirmedChanged',
      version: BRIDGE_VERSION,
      payload: confirmedGeometryPayload(),
    })
  }
}

function confirmedGeometryPayload(): Record<string, unknown> {
  return {
    coordinateSpace: 'image_pixels',
    geometryKind: 'room_boundary',
    points: confirmedPoints.map(scenePointToImage),
  }
}

function inspectorSummary(model: SpatialModel): string {
  const bounds = roomBounds(model)
  if (model.selected?.objectType === 'furniture') {
    const item = model.furniture.find((candidate) => candidate.objectId === model.selected?.objectId)
    if (item) {
      const label = localizedFurnitureLabel(item)
      const locked = item.locked ? t('; locked', '; 잠김') : ''
      return t(
        selectedFurnitureSummary(model),
        `${label}; ${item.size.widthMeters.toFixed(2)} m x ${item.size.depthMeters.toFixed(
          2,
        )} m x ${item.size.heightMeters.toFixed(2)} m; 위치 ${item.position.x.toFixed(
          2,
        )} m, ${item.position.y.toFixed(2)} m; 회전 ${item.rotationDegrees.toFixed(0)}도${locked}`,
      )
    }
  }
  if (model.selected?.objectType === 'fixture') {
    const fixture = selectedFixtureFromModel(model)
    if (fixture) {
      const size = fixture.size ?? { x: 0.8, y: 1, z: 0.1 }
      const review = fixture.confidenceScore !== undefined && fixture.confidenceScore < 0.7
        ? t('; Needs review', '; 검토 필요')
        : ''
      return t(
        `${selectedFixtureSummary(model)}${review}`,
        `${localizedFixtureLabel(fixture)}; ${fixture.wallId}; 너비 ${size.x.toFixed(
          2,
        )} m x 높이 ${size.y.toFixed(2)} m${review}`,
      )
    }
  }
  const selected = model.selected?.objectId ?? 'none'
  return t(
    `${selected}; ${bounds.widthMeters.toFixed(2)} m x ${bounds.depthMeters.toFixed(
      2,
    )} m x ${model.room.heightMeters.toFixed(2)} m`,
    `${selected}; ${bounds.widthMeters.toFixed(2)} m x ${bounds.depthMeters.toFixed(
      2,
    )} m x ${model.room.heightMeters.toFixed(2)} m`,
  )
}

function isFurnitureCategory(value: string | undefined): value is FurnitureCategory {
  return (
    value === 'bed' ||
    value === 'desk' ||
    value === 'chair' ||
    value === 'wardrobe' ||
    value === 'sofa' ||
    value === 'table' ||
    value === 'shelf' ||
    value === 'cabinet' ||
    value === 'custom'
  )
}

function isTransformField(value: string | undefined): value is TransformField {
  return (
    value === 'position-x' ||
    value === 'position-y' ||
    value === 'rotation' ||
    value === 'width' ||
    value === 'depth' ||
    value === 'height'
  )
}

function isLoadSource(value: string | undefined): value is LoadSource {
  return value === 'latest' || value === 'draft' || value === 'export'
}

function measurementSummary(model: SpatialModel): string {
  const selected = selectedFurniture()
  return measurementSummaryForModel({
    model,
    selected,
    selectedLabel: selected ? localizedFurnitureLabel(selected) : undefined,
    roomLabel: t('Room', '방'),
  }).replace('room', t('room', '방'))
}

function placementWarning(model: SpatialModel): string | null {
  const warning = placementWarningForModel({
    model,
    labelFor: localizedFurnitureLabel,
  })
  if (!warning || !usesKorean) {
    return warning
  }
  const bounds = roomBounds(model)
  const outside = model.furniture.find((item) => furnitureOutsideRoom(item, bounds))
  if (!outside) {
    return '배치 경고가 있습니다. 저장 전에 모든 오브젝트를 확인하세요.'
  }
  return `${localizedFurnitureLabel(outside)}이(가) ${bounds.widthMeters.toFixed(
    2,
  )} m x ${bounds.depthMeters.toFixed(2)} m 방 경계 밖에 있습니다. 저장 전에 이동하거나 크기를 조정하세요.`
}

function isFurnitureEditAction(value: string | undefined): value is FurnitureEditAction {
  return (
    value === 'move-up' ||
    value === 'move-down' ||
    value === 'move-left' ||
    value === 'move-right' ||
    value === 'rotate-left' ||
    value === 'rotate-right' ||
    value === 'narrower' ||
    value === 'wider' ||
    value === 'shallower' ||
    value === 'deeper' ||
    value === 'toggle-lock' ||
    value === 'delete'
  )
}

function isFixtureEditAction(value: string | undefined): value is FixtureEditAction {
  return (
    value === 'wall-previous' ||
    value === 'wall-next' ||
    value === 'offset-decrease' ||
    value === 'offset-increase' ||
    value === 'narrower' ||
    value === 'wider' ||
    value === 'shorter' ||
    value === 'taller' ||
    value === 'category-next' ||
    value === 'delete'
  )
}

function setPointerFromEvent(event: PointerEvent): void {
  const rect = editorCanvas.getBoundingClientRect()
  pointer.x = ((event.clientX - rect.left) / rect.width) * 2 - 1
  pointer.y = -(((event.clientY - rect.top) / rect.height) * 2 - 1)
}
