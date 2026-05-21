import * as THREE from 'three'

import './style.css'
import {
  BRIDGE_VERSION,
  isBridgeMessage,
  postBridgeMessage,
  type BridgeMessage,
} from './bridge'
import {
  defaultSpatialModel,
  roomBounds,
  spatialModelFromBridgePayload,
  spatialSummary,
  type SpatialModel,
  type ViewMode,
} from './spatialModel'

const app = document.querySelector<HTMLDivElement>('#app')

if (!app) {
  throw new Error('Missing editor root element.')
}

app.innerHTML = `
<section class="editor-shell">
  <div class="viewport" aria-label="RoomForge editor viewport">
    <div class="viewport-toolbar" aria-label="Planning view controls">
      <button id="view-2d" type="button" aria-pressed="true">2D</button>
      <button id="view-3d" type="button" aria-pressed="false">3D</button>
    </div>
    <canvas class="editor-canvas" aria-label="Three.js reconstruction viewport"></canvas>
    <div class="viewport-status-strip" id="scene-status">Initializing metric room scene</div>
  </div>
  <aside class="status-panel" aria-label="Inspector and status">
    <p class="eyebrow">RoomForge editor</p>
    <h1>Planning editor</h1>
    <dl class="status-list">
      <div>
        <dt>Bridge</dt>
        <dd id="bridge-status">Waiting for Flutter shell</dd>
      </div>
      <div>
        <dt>OpenCV runtime</dt>
        <dd id="opencv-status">Loading worker assets</dd>
      </div>
      <div>
        <dt>Viewport</dt>
        <dd id="viewport-status">Sizing scene</dd>
      </div>
      <div>
        <dt>Geometry</dt>
        <dd id="geometry-status">Candidate and confirmed overlays visible</dd>
      </div>
      <div>
        <dt>Scene</dt>
        <dd id="spatial-status">Waiting for metric floor plan</dd>
      </div>
      <div>
        <dt>Inspector</dt>
        <dd id="inspector-status">Selected room shell</dd>
      </div>
    </dl>
    <div class="geometry-controls" aria-label="Geometry correction controls">
      <button id="accept-candidate" type="button">Accept candidate</button>
      <button id="manual-outline" type="button">Manual rectangle</button>
      <button id="add-corner" type="button">Add corner</button>
      <button id="delete-corner" type="button">Delete corner</button>
      <button id="reset-candidate" type="button">Reset</button>
      <button id="generate-floor-plan" type="button">Generate floor plan</button>
    </div>
  </aside>
</section>
`

const canvas = document.querySelector<HTMLCanvasElement>('.editor-canvas')
const bridgeStatus = document.querySelector<HTMLElement>('#bridge-status')
const opencvStatus = document.querySelector<HTMLElement>('#opencv-status')
const viewportStatus = document.querySelector<HTMLElement>('#viewport-status')
const geometryStatus = document.querySelector<HTMLElement>('#geometry-status')
const spatialStatus = document.querySelector<HTMLElement>('#spatial-status')
const inspectorStatus = document.querySelector<HTMLElement>('#inspector-status')
const sceneStatus = document.querySelector<HTMLElement>('#scene-status')
const view2dButton = document.querySelector<HTMLButtonElement>('#view-2d')
const view3dButton = document.querySelector<HTMLButtonElement>('#view-3d')

if (
  !canvas ||
  !bridgeStatus ||
  !opencvStatus ||
  !viewportStatus ||
  !geometryStatus ||
  !spatialStatus ||
  !inspectorStatus ||
  !sceneStatus ||
  !view2dButton ||
  !view3dButton
) {
  throw new Error('Missing editor UI element.')
}

const editorCanvas = canvas
const bridgeStatusElement = bridgeStatus
const opencvStatusElement = opencvStatus
const viewportStatusElement = viewportStatus
const geometryStatusElement = geometryStatus
const spatialStatusElement = spatialStatus
const inspectorStatusElement = inspectorStatus
const sceneStatusElement = sceneStatus
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

const selectionMaterial = new THREE.LineBasicMaterial({ color: 0x0f172a })
const selectionLine = new THREE.Line(new THREE.BufferGeometry(), selectionMaterial)
selectionLine.visible = true
room.add(selectionLine)

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
const candidatePoints = [
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
let activeCornerIndex: number | null = null
const raycaster = new THREE.Raycaster()
const pointer = new THREE.Vector2()
const dragPlane = new THREE.Plane(new THREE.Vector3(0, 1, 0), -0.02)

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
  renderer.render(scene, camera)
  requestAnimationFrame(render)
}

function postToParent(message: BridgeMessage): void {
  if (window.parent && window.parent !== window) {
    postBridgeMessage(window.parent, message)
  }
}

function respondToFlutter(message: BridgeMessage): void {
  bridgeStatusElement.textContent = `Received ${message.type}`
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
      focusable: true,
      spatialModel: spatialModelPayload(),
    },
  })
}

function handleBridgeCommand(message: BridgeMessage): void {
  if (message.type === 'roomforge.scene.initialize') {
    spatialModel = spatialModelFromBridgePayload(message.payload)
    applySpatialModel()
    respondToFlutter(message)
    emitSceneState('roomforge.scene.initialized', message.requestId)
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

document.querySelector<HTMLButtonElement>('#accept-candidate')?.addEventListener('click', () => {
  confirmedPoints = candidatePoints.slice(0, 4).map((point) => point.clone())
  updateConfirmedGeometry('Accepted OpenCV candidate.')
})

document.querySelector<HTMLButtonElement>('#manual-outline')?.addEventListener('click', () => {
  confirmedPoints = outlinePoints.slice(0, 4).map((point) => point.clone())
  updateConfirmedGeometry('Started from manual rectangle.')
})

document.querySelector<HTMLButtonElement>('#add-corner')?.addEventListener('click', () => {
  const lastPoint = confirmedPoints[confirmedPoints.length - 1]
  const firstPoint = confirmedPoints[0]
  confirmedPoints.push(lastPoint.clone().lerp(firstPoint, 0.5))
  updateConfirmedGeometry('Added a boundary corner.')
})

document.querySelector<HTMLButtonElement>('#delete-corner')?.addEventListener('click', () => {
  if (confirmedPoints.length <= 3) {
    geometryStatusElement.textContent = 'At least three corners are required.'
    return
  }
  confirmedPoints.pop()
  updateConfirmedGeometry('Deleted the last boundary corner.')
})

document.querySelector<HTMLButtonElement>('#reset-candidate')?.addEventListener('click', () => {
  confirmedPoints = candidatePoints.slice(0, 4).map((point) => point.clone())
  updateConfirmedGeometry('Reset to OpenCV candidate.')
})

document.querySelector<HTMLButtonElement>('#generate-floor-plan')?.addEventListener('click', () => {
  if (confirmedPoints.length < 3) {
    geometryStatusElement.textContent = 'Confirm at least three corners before generation.'
    return
  }
  geometryStatusElement.textContent = 'Generated meter-space MVP floor plan.'
  spatialModel = {
    ...spatialModel,
    hasUnsavedChanges: true,
    room: {
      ...spatialModel.room,
      floorPlan: {
        ...spatialModel.room.floorPlan,
        metricGeometry: {
          coordinateSpace: 'meters',
          points: [
            { x: 0, y: 0 },
            { x: 4.2, y: 0 },
            { x: 4.2, y: 3.6 },
            { x: 0, y: 3.6 },
          ],
        },
      },
    },
  }
  applySpatialModel()
  postToParent({
    type: 'roomforge.calibration.floorPlanGenerated',
    version: BRIDGE_VERSION,
    payload: {
      unit: 'meters',
      scaleSummary: '4.20 m x 3.60 m rectangular MVP floor plan',
      referenceLine: { fromIndex: 0, toIndex: 1 },
      referenceLengthValue: 4.2,
      perspectiveAssumptions: {
        model: 'mvp_rectangular_projection',
        sourceCoordinateSpace: 'image_pixels',
        targetCoordinateSpace: 'meters',
      },
      imageGeometry: confirmedGeometryPayload(),
      metricGeometry: {
        coordinateSpace: 'meters',
        points: [
          { x: 0, y: 0 },
          { x: 4.2, y: 0 },
          { x: 4.2, y: 3.6 },
          { x: 0, y: 3.6 },
        ],
      },
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
  if (activeCornerIndex === null) {
    return
  }
  setPointerFromEvent(event)
  raycaster.setFromCamera(pointer, camera)
  const target = new THREE.Vector3()
  if (raycaster.ray.intersectPlane(dragPlane, target)) {
    confirmedPoints[activeCornerIndex] = target
    updateConfirmedGeometry('Dragging confirmed boundary corner.', false)
  }
})

editorCanvas.addEventListener('pointerup', (event) => {
  if (activeCornerIndex !== null) {
    updateConfirmedGeometry('Updated confirmed boundary by dragging corner.')
    if (editorCanvas.hasPointerCapture(event.pointerId)) {
      editorCanvas.releasePointerCapture(event.pointerId)
    }
  }
  activeCornerIndex = null
})

const worker = new Worker(new URL('./opencvWorker.ts', import.meta.url), {
  type: 'module',
})
worker.onmessage = (event: MessageEvent<BridgeMessage>) => {
  runtimeState = event.data.payload
  opencvStatusElement.textContent =
    event.data.type === 'roomforge.opencv.runtimeLoaded'
      ? 'Worker assets loaded'
      : 'Worker asset loading failed'
  postToParent(event.data)
  if (event.data.type === 'roomforge.opencv.runtimeLoaded') {
    postToParent({
      type: 'roomforge.reconstruction.qualityWarning',
      version: BRIDGE_VERSION,
      payload: {
        status: 'review_required',
        label: 'Needs review',
        reasonCode: 'low_confidence',
        reasonMessage: 'Candidate geometry should be reviewed before save or export.',
        recoveryActions: ['manual_outline', 'corner_correction', 'reupload'],
      },
    })
    postToParent({
      type: 'roomforge.opencv.candidatesExtracted',
      version: BRIDGE_VERSION,
      payload: {
        coordinateSpace: 'image_pixels',
        confidence: 0.72,
        candidateGeometry: candidateGeometry(),
      },
    })
  }
}
worker.postMessage({
  type: 'roomforge.opencv.loadRuntime',
  version: BRIDGE_VERSION,
  requestId: 'opencv-runtime-bootstrap',
  payload: {},
} satisfies BridgeMessage)

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
  applyViewModeCamera()
  updateSpatialStatus()
}

function setViewMode(viewMode: ViewMode): void {
  spatialModel = { ...spatialModel, viewMode }
  applyViewModeCamera()
  updateSpatialStatus()
  emitSceneState('roomforge.view.changed')
}

function applyViewModeCamera(): void {
  const bounds = roomBounds(spatialModel)
  const maxDimension = Math.max(bounds.widthMeters, bounds.depthMeters, 1)
  const distance = maxDimension / (2 * Math.tan(THREE.MathUtils.degToRad(camera.fov / 2)))

  if (spatialModel.viewMode === '2d') {
    wallGroup.visible = false
    camera.position.set(0, distance * 1.35, 0.001)
    camera.up.set(0, 0, -1)
  } else {
    wallGroup.visible = true
    camera.position.set(maxDimension * 0.85, maxDimension * 0.75, maxDimension * 0.95)
    camera.up.set(0, 1, 0)
  }

  camera.lookAt(0, 0, 0)
  camera.updateProjectionMatrix()
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

function updateSpatialStatus(): void {
  spatialStatusElement.textContent = spatialSummary(spatialModel)
  sceneStatusElement.textContent = spatialSummary(spatialModel)
  inspectorStatusElement.textContent = inspectorSummary(spatialModel)
  selectionLine.visible = spatialModel.selected?.objectId === spatialModel.room.objectId
  view2dButtonElement.setAttribute('aria-pressed', String(spatialModel.viewMode === '2d'))
  view3dButtonElement.setAttribute('aria-pressed', String(spatialModel.viewMode === '3d'))
  view2dButtonElement.classList.toggle('is-active', spatialModel.viewMode === '2d')
  view3dButtonElement.classList.toggle('is-active', spatialModel.viewMode === '3d')
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
  }
}

function metricPointToScene(x: number, y: number, height = 0): THREE.Vector3 {
  const bounds = roomBounds(spatialModel)
  return new THREE.Vector3(x - bounds.centerX, height, y - bounds.centerY)
}

function scenePointToMetric(point: THREE.Vector3): { x: number; y: number } {
  const bounds = roomBounds(spatialModel)
  return {
    x: Number((point.x + bounds.centerX).toFixed(3)),
    y: Number((point.z + bounds.centerY).toFixed(3)),
  }
}

function candidateGeometry(): Record<string, unknown> {
  return {
    image: {
      widthPx: 1600,
      heightPx: 1200,
    },
    candidateSets: [
      {
        id: 'candidate-1',
        kind: 'room_boundary',
        coordinateSpace: 'image_pixels',
        points: [
          { x: 120, y: 240 },
          { x: 1420, y: 220 },
          { x: 1480, y: 980 },
          { x: 180, y: 1020 },
        ],
      },
    ],
    overlayStyle: {
      candidate: 'dashed-low-opacity-purple',
      confirmed: 'solid-blue-with-handles',
    },
  }
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
    points: confirmedPoints.map((point) => ({
      x: Math.round((point.x + 2) * 400),
      y: Math.round((point.z + 1.5) * 400),
    })),
  }
}

function inspectorSummary(model: SpatialModel): string {
  const bounds = roomBounds(model)
  const selected = model.selected?.objectId ?? 'none'
  return `${selected}; ${bounds.widthMeters.toFixed(2)} m x ${bounds.depthMeters.toFixed(
    2,
  )} m x ${model.room.heightMeters.toFixed(2)} m`
}

function setPointerFromEvent(event: PointerEvent): void {
  const rect = editorCanvas.getBoundingClientRect()
  pointer.x = ((event.clientX - rect.left) / rect.width) * 2 - 1
  pointer.y = -(((event.clientY - rect.top) / rect.height) * 2 - 1)
}
