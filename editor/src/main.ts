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
  measurementSummaryForModel,
  placementWarningForModel,
} from './measurementGuidance'
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

const app = document.querySelector<HTMLDivElement>('#app')

if (!app) {
  throw new Error('Missing editor root element.')
}

const localeOverride = new URLSearchParams(window.location.search).get('locale')?.toLowerCase() ?? ''
const usesKorean = localeOverride.startsWith('ko') || navigator.language.toLowerCase().startsWith('ko')
const t = (english: string, korean: string): string => (usesKorean ? korean : english)

app.innerHTML = `
<section class="editor-shell">
  <div class="viewport" aria-label="${t('RoomForge editor viewport', 'RoomForge 편집기 뷰포트')}">
    <div class="viewport-toolbar" aria-label="${t('Planning view controls', '배치 보기 컨트롤')}">
      <button id="view-2d" type="button" aria-label="${t('Show 2D planning view', '2D 배치 보기 표시')}" aria-pressed="true">2D</button>
      <button id="view-3d" type="button" aria-label="${t('Show 3D inspection view', '3D 검사 보기 표시')}" aria-pressed="false">3D</button>
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
      <div class="geometry-controls" aria-label="${t('Geometry correction controls', '지오메트리 보정 컨트롤')}">
        <button id="accept-candidate" type="button">${t('Accept candidate', '후보 적용')}</button>
        <button id="manual-outline" type="button">${t('Manual rectangle', '수동 사각형')}</button>
        <button id="add-corner" type="button">${t('Add corner', '꼭짓점 추가')}</button>
        <button id="delete-corner" type="button">${t('Delete corner', '꼭짓점 삭제')}</button>
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
        <span class="state-pill measurement">${t('Meters', '미터')}</span>
      </div>
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
      <p class="helper-text" id="scale-status">${t('Use the longest trusted wall to anchor image pixels into meters.', '가장 신뢰할 수 있는 긴 벽을 기준으로 이미지 픽셀을 미터로 보정하세요.')}</p>
      <button id="generate-floor-plan" type="button">${t('Generate floor plan', '평면도 생성')}</button>
    </section>
    <section class="panel-section" aria-labelledby="furniture-catalog-title">
      <div class="panel-section-header">
        <div>
          <p class="eyebrow">${t('Furniture', '가구')}</p>
          <h2 id="furniture-catalog-title">${t('Add preset object', '프리셋 객체 추가')}</h2>
        </div>
        <span class="state-pill" id="furniture-count">${t('0 objects', '객체 0개')}</span>
      </div>
      <p class="helper-text" id="furniture-catalog-status">${t('Choose a preset to place it inside the measured room.', '측정된 방 안에 배치할 프리셋을 선택하세요.')}</p>
      <div class="furniture-controls" aria-label="${t('Furniture catalog', '가구 카탈로그')}">
        <button type="button" data-furniture-category="chair">${t('Add chair', '의자 추가')}</button>
        <button type="button" data-furniture-category="table">${t('Add table', '테이블 추가')}</button>
        <button type="button" data-furniture-category="sofa">${t('Add sofa', '소파 추가')}</button>
      </div>
    </section>
    <section class="panel-section" aria-labelledby="selection-inspector-title">
      <div class="panel-section-header">
        <div>
          <p class="eyebrow">${t('Inspector', '인스펙터')}</p>
          <h2 id="selection-inspector-title">${t('Selected object', '선택된 객체')}</h2>
        </div>
        <span class="state-pill" id="selection-state">${t('Room', '방')}</span>
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
const knownWallLengthInput = document.querySelector<HTMLInputElement>('#known-wall-length')
const scaleStatus = document.querySelector<HTMLElement>('#scale-status')
const furnitureCount = document.querySelector<HTMLElement>('#furniture-count')
const furnitureCatalogStatus = document.querySelector<HTMLElement>('#furniture-catalog-status')
const selectionState = document.querySelector<HTMLElement>('#selection-state')
const view2dButton = document.querySelector<HTMLButtonElement>('#view-2d')
const view3dButton = document.querySelector<HTMLButtonElement>('#view-3d')
const cameraActionButtons = Array.from(
  document.querySelectorAll<HTMLButtonElement>('[data-camera-action]'),
)
const furnitureCategoryButtons = Array.from(
  document.querySelectorAll<HTMLButtonElement>('[data-furniture-category]'),
)
const furnitureEditButtons = Array.from(
  document.querySelectorAll<HTMLButtonElement>('[data-furniture-edit]'),
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
  !knownWallLengthInput ||
  !scaleStatus ||
  !furnitureCount ||
  !furnitureCatalogStatus ||
  !selectionState ||
  !view2dButton ||
  !view3dButton ||
  cameraActionButtons.length === 0 ||
  furnitureCategoryButtons.length === 0 ||
  furnitureEditButtons.length === 0 ||
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
const knownWallLengthInputElement = knownWallLengthInput
const scaleStatusElement = scaleStatus
const furnitureCountElement = furnitureCount
const furnitureCatalogStatusElement = furnitureCatalogStatus
const selectionStateElement = selectionState
const view2dButtonElement = view2dButton
const view3dButtonElement = view3dButton

const renderer = new THREE.WebGLRenderer({ canvas: editorCanvas, antialias: true })
renderer.setPixelRatio(window.devicePixelRatio)
renderer.setClearColor(0xeef2f7)

const scene = new THREE.Scene()
const camera = new THREE.PerspectiveCamera(42, 1, 0.1, 100)
camera.position.set(3.5, 4, 5)
camera.lookAt(0, 0, 0)

let spatialModel: SpatialModel = defaultSpatialModel()

const room = new THREE.Group()
const floor = new THREE.Mesh(
  new THREE.PlaneGeometry(4, 3),
  new THREE.MeshBasicMaterial({
    color: 0x2563eb,
    transparent: true,
    opacity: 0.16,
    side: THREE.DoubleSide,
  }),
)
floor.rotation.x = -Math.PI / 2
floor.userData.objectId = spatialModel.room.objectId
room.add(floor)

const outlineMaterial = new THREE.LineBasicMaterial({ color: 0x2563eb })
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
  color: 0x94a3b8,
  transparent: true,
  opacity: 0.28,
  side: THREE.DoubleSide,
})
const wallGroup = new THREE.Group()
room.add(wallGroup)

const furnitureGroup = new THREE.Group()
room.add(furnitureGroup)

const fixtureGroup = new THREE.Group()
room.add(fixtureGroup)

const selectionMaterial = new THREE.LineBasicMaterial({ color: 0x0f172a })
const selectionLine = new THREE.Line(new THREE.BufferGeometry(), selectionMaterial)
selectionLine.visible = true
room.add(selectionLine)

const furnitureSelectionMaterial = new THREE.LineBasicMaterial({ color: 0x111827 })
const furnitureMeshes = new Map<string, THREE.Mesh>()
const furnitureOutlineObjects: THREE.LineSegments[] = []
const fixtureMeshes = new Map<string, THREE.Mesh>()
const fixtureOutlineObjects: THREE.LineSegments[] = []

const cornerMaterial = new THREE.MeshBasicMaterial({ color: 0x0f172a })
const cornerMeshes: THREE.Mesh[] = []
for (const point of confirmedPoints) {
  const corner = new THREE.Mesh(new THREE.SphereGeometry(0.08, 16, 16), cornerMaterial)
  corner.position.copy(point)
  room.add(corner)
  cornerMeshes.push(corner)
}
scene.add(room)

const candidateMaterial = new THREE.LineDashedMaterial({
  color: 0x7c3aed,
  dashSize: 0.12,
  gapSize: 0.08,
  transparent: true,
  opacity: 0.48,
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
for (const button of fixtureEditButtons) {
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
  confirmedPoints = candidatePoints.slice(0, 4).map((point) => point.clone())
  updateConfirmedGeometry(t('Accepted OpenCV candidate.', 'OpenCV 후보를 적용했습니다.'))
})

document.querySelector<HTMLButtonElement>('#manual-outline')?.addEventListener('click', () => {
  confirmedPoints = outlinePoints.slice(0, 4).map((point) => point.clone())
  updateConfirmedGeometry(t('Started from manual rectangle.', '수동 사각형에서 시작했습니다.'))
})

document.querySelector<HTMLButtonElement>('#add-corner')?.addEventListener('click', () => {
  const lastPoint = confirmedPoints[confirmedPoints.length - 1]
  const firstPoint = confirmedPoints[0]
  confirmedPoints.push(lastPoint.clone().lerp(firstPoint, 0.5))
  updateConfirmedGeometry(t('Added a boundary corner.', '경계 꼭짓점을 추가했습니다.'))
})

document.querySelector<HTMLButtonElement>('#delete-corner')?.addEventListener('click', () => {
  if (confirmedPoints.length <= 3) {
    geometryStatusElement.textContent = t('At least three corners are required.', '최소 3개 꼭짓점이 필요합니다.')
    return
  }
  confirmedPoints.pop()
  updateConfirmedGeometry(t('Deleted the last boundary corner.', '마지막 경계 꼭짓점을 삭제했습니다.'))
})

document.querySelector<HTMLButtonElement>('#reset-candidate')?.addEventListener('click', () => {
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
  if (!Number.isFinite(knownLength) || knownLength <= 0) {
    scaleStatusElement.textContent = t(
      'Enter a positive known wall length before generating a floor plan.',
      '평면도를 생성하기 전에 양수 벽 길이를 입력하세요.',
    )
    geometryStatusElement.textContent = t('Invalid calibration length.', '잘못된 보정 길이입니다.')
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
    activeCornerIndex = cornerIndex
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
})

editorCanvas.addEventListener('pointercancel', (event) => {
  if (activeCameraDrag?.pointerId === event.pointerId) {
    activeCameraDrag = null
  }
  activeCornerIndex = null
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
        'Scene understanding mock candidates loaded.',
        '장면 이해 mock 후보를 불러왔습니다.',
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
  spatialModel = { ...spatialModel, viewMode }
  rebuildStructuralFixtures()
  rebuildFurniture()
  applyViewModeCamera()
  updateSpatialStatus()
  emitSceneState('roomforge.view.changed')
}

function applyViewModeCamera(): void {
  if (spatialModel.viewMode === '2d') {
    wallGroup.visible = false
    queueCameraSnapshot(cameraSnapshotFor('top'), '2D top view', false)
  } else {
    wallGroup.visible = true
    queueCameraSnapshot(cameraSnapshotFor('corner'), '3D corner view', true)
  }
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
  selectionLine.visible = spatialModel.selected?.objectId === spatialModel.room.objectId

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
  selectionLine.visible = spatialModel.selected?.objectId === spatialModel.room.objectId
  view2dButtonElement.setAttribute('aria-pressed', String(spatialModel.viewMode === '2d'))
  view3dButtonElement.setAttribute('aria-pressed', String(spatialModel.viewMode === '3d'))
  view2dButtonElement.classList.toggle('is-active', spatialModel.viewMode === '2d')
  view3dButtonElement.classList.toggle('is-active', spatialModel.viewMode === '3d')
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
  for (const button of furnitureEditButtons) {
    const action = button.dataset.furnitureEdit
    const locked = selected?.locked === true
    button.disabled =
      !furnitureSelected || (locked && action !== 'toggle-lock' && action !== 'delete')
    if (action === 'toggle-lock') {
      button.textContent = locked ? t('Unlock object', '객체 잠금 해제') : t('Lock object', '객체 잠금')
    }
  }
  for (const button of fixtureEditButtons) {
    button.disabled = !fixtureSelected
  }
}

function updateCandidateTray(): void {
  const items = candidateTrayItems(spatialModel)
  const activeCount = items.filter((item) => !item.rejected).length
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
  candidateTrayStatusElement.textContent = t(
    `${activeCount} active candidates; ${needsReviewCount} need review.`,
    `활성 후보 ${activeCount}개; 검토 필요 ${needsReviewCount}개.`,
  )
  candidateTrayListElement.innerHTML = items.map(candidateTrayItemMarkup).join('')
}

function candidateTrayItemMarkup(item: ReturnType<typeof candidateTrayItems>[number]): string {
  const stateClass = item.rejected || item.lowConfidence ? ' warning' : ''
  const disabled = item.rejected ? ' disabled' : ''
  const placeDisabled = item.rejected || item.placed ? ' disabled' : ''
  const placeText = item.placed ? t('Placed', '배치됨') : t('Place', '배치')
  const rejectText = item.rejected ? t('Rejected', '거절됨') : t('Reject', '거절')
  return `
    <article class="candidate-card${item.rejected ? ' is-rejected' : ''}" role="listitem" data-candidate-id="${escapeAttribute(
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
      <button type="button" data-candidate-action="reject" data-candidate-id="${escapeAttribute(
        item.candidateId,
      )}"${disabled}>${rejectText}</button>
      <button type="button" data-candidate-action="place" data-candidate-id="${escapeAttribute(
        item.candidateId,
      )}"${placeDisabled}>${placeText}</button>
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
  if (item.category === 'chair') {
    return '의자'
  }
  if (item.category === 'table') {
    return '테이블'
  }
  if (item.category === 'sofa') {
    return '소파'
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
  return value === 'chair' || value === 'table' || value === 'sofa'
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
  return placementWarningForModel({
    model,
    labelFor: localizedFurnitureLabel,
  })
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
