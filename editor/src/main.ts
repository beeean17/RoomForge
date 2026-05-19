import * as THREE from 'three'

import './style.css'
import {
  BRIDGE_VERSION,
  isBridgeMessage,
  postBridgeMessage,
  type BridgeMessage,
} from './bridge'

const app = document.querySelector<HTMLDivElement>('#app')

if (!app) {
  throw new Error('Missing editor root element.')
}

app.innerHTML = `
<section class="editor-shell">
  <div class="viewport" aria-label="RoomForge editor viewport">
    <canvas class="editor-canvas" aria-label="Three.js reconstruction viewport"></canvas>
  </div>
  <aside class="status-panel">
    <p class="eyebrow">RoomForge editor</p>
    <h1>Reconstruction bridge ready</h1>
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
    </dl>
    <div class="geometry-controls" aria-label="Geometry correction controls">
      <button id="accept-candidate" type="button">Accept candidate</button>
      <button id="manual-outline" type="button">Manual rectangle</button>
      <button id="add-corner" type="button">Add corner</button>
      <button id="delete-corner" type="button">Delete corner</button>
      <button id="reset-candidate" type="button">Reset</button>
    </div>
  </aside>
</section>
`

const canvas = document.querySelector<HTMLCanvasElement>('.editor-canvas')
const bridgeStatus = document.querySelector<HTMLElement>('#bridge-status')
const opencvStatus = document.querySelector<HTMLElement>('#opencv-status')
const viewportStatus = document.querySelector<HTMLElement>('#viewport-status')
const geometryStatus = document.querySelector<HTMLElement>('#geometry-status')

if (!canvas || !bridgeStatus || !opencvStatus || !viewportStatus || !geometryStatus) {
  throw new Error('Missing editor UI element.')
}

const editorCanvas = canvas
const bridgeStatusElement = bridgeStatus
const opencvStatusElement = opencvStatus
const viewportStatusElement = viewportStatus
const geometryStatusElement = geometryStatus

const renderer = new THREE.WebGLRenderer({ canvas: editorCanvas, antialias: true })
renderer.setPixelRatio(window.devicePixelRatio)
renderer.setClearColor(0xeef2f7)

const scene = new THREE.Scene()
const camera = new THREE.PerspectiveCamera(42, 1, 0.1, 100)
camera.position.set(3.5, 4, 5)
camera.lookAt(0, 0, 0)

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
    },
  })
}

window.addEventListener('message', (event: MessageEvent<unknown>) => {
  if (!isBridgeMessage(event.data)) {
    return
  }

  if (event.data.version !== BRIDGE_VERSION) {
    return
  }

  respondToFlutter(event.data)
})

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

editorCanvas.addEventListener('pointerdown', (event) => {
  setPointerFromEvent(event)
  raycaster.setFromCamera(pointer, camera)
  const intersections = raycaster.intersectObjects(cornerMeshes)
  if (intersections.length === 0) {
    return
  }
  const cornerIndex = cornerMeshes.indexOf(intersections[0].object as THREE.Mesh)
  if (cornerIndex < 0) {
    return
  }
  activeCornerIndex = cornerIndex
  editorCanvas.setPointerCapture(event.pointerId)
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
  }
  activeCornerIndex = null
  editorCanvas.releasePointerCapture(event.pointerId)
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
      type: 'roomforge.opencv.candidatesExtracted',
      version: BRIDGE_VERSION,
      payload: {
        coordinate_space: 'image_pixels',
        confidence: 0.72,
        candidate_geometry: candidateGeometry(),
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
    },
  })
})

function candidateGeometry(): Record<string, unknown> {
  return {
    image: {
      width_px: 1600,
      height_px: 1200,
    },
    candidate_sets: [
      {
        id: 'candidate-1',
        kind: 'room_boundary',
        coordinate_space: 'image_pixels',
        points: [
          { x: 120, y: 240 },
          { x: 1420, y: 220 },
          { x: 1480, y: 980 },
          { x: 180, y: 1020 },
        ],
      },
    ],
    overlay_style: {
      candidate: 'dashed-low-opacity-purple',
      confirmed: 'solid-blue-with-handles',
    },
  }
}

function updateConfirmedGeometry(message: string, emit = true): void {
  const closedPoints = [...confirmedPoints, confirmedPoints[0]]
  confirmedLine.geometry.dispose()
  confirmedLine.geometry = new THREE.BufferGeometry().setFromPoints(closedPoints)

  while (cornerMeshes.length < confirmedPoints.length) {
    const corner = new THREE.Mesh(new THREE.SphereGeometry(0.08, 16, 16), cornerMaterial)
    room.add(corner)
    cornerMeshes.push(corner)
  }
  while (cornerMeshes.length > confirmedPoints.length) {
    const corner = cornerMeshes.pop()
    if (corner) {
      room.remove(corner)
    }
  }
  for (const [index, point] of confirmedPoints.entries()) {
    cornerMeshes[index].position.copy(point)
  }

  geometryStatusElement.textContent = message
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
    coordinate_space: 'image_pixels',
    geometry_kind: 'room_boundary',
    points: confirmedPoints.map((point) => ({
      x: Math.round((point.x + 2) * 400),
      y: Math.round((point.z + 1.5) * 400),
    })),
  }
}

function setPointerFromEvent(event: PointerEvent): void {
  const rect = editorCanvas.getBoundingClientRect()
  pointer.x = ((event.clientX - rect.left) / rect.width) * 2 - 1
  pointer.y = -(((event.clientY - rect.top) / rect.height) * 2 - 1)
}
