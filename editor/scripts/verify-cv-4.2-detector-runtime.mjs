import assert from 'node:assert/strict'

import { sceneUnderstandingResponseMessage } from '../src/sceneUnderstandingWorker.ts'

const captureSession = {
  captureSessionId: 'capture-session-4-2',
  projectId: 'project-1',
  depthEnabled: false,
  availableRoles: ['overview', 'front_wall'],
  images: [
    {
      captureImageId: 'capture-image-overview',
      captureSessionId: 'capture-session-4-2',
      sourceImageId: 'source-image-overview',
      role: 'overview',
      widthPx: 1600,
      heightPx: 900,
      contentType: 'image/png',
    },
    {
      captureImageId: 'capture-image-front',
      captureSessionId: 'capture-session-4-2',
      sourceImageId: 'source-image-front',
      role: 'front_wall',
      widthPx: 1500,
      heightPx: 900,
      contentType: 'image/png',
    },
  ],
}

const detectorOutput = [
  {
    className: 'bed',
    score: 0.91,
    captureImageId: 'capture-image-front',
    box: { x: 80, y: 260, width: 640, height: 420 },
  },
  {
    className: 'window',
    score: 0.82,
    sourceImageRole: 'front_wall',
    box: { x: 820, y: 120, width: 360, height: 220 },
  },
  {
    className: 'floor_lamp',
    score: 0.78,
    sourceImageId: 'source-image-overview',
    box: { x: 1200, y: 310, width: 120, height: 420 },
  },
  {
    className: 'chair',
    score: 0.2,
    box: { x: 620, y: 380, width: 200, height: 260 },
  },
]

const webgpu = sceneUnderstandingResponseMessage(
  {
    captureSession,
    detectorRuntime: {
      webgpuAvailable: true,
      modelAssetsPresent: true,
      scoreThreshold: 0.45,
    },
    detectorOutput,
  },
  'cv-4.2-webgpu',
)

assert.equal(webgpu.type, 'roomforge.sceneUnderstanding.candidatesExtracted')
assert.equal(webgpu.requestId, 'cv-4.2-webgpu')

const webgpuResult = webgpu.payload.sceneUnderstandingResult
assert.equal(webgpuResult.providerType, 'browser_cv_webgpu_mock')
assert.equal(webgpuResult.runtime, 'webgpu')
assert.equal(webgpuResult.modelId, 'roomforge-detector-webgpu-mock')
assert.equal(webgpuResult.detectorScoreThreshold, 0.45)
assert.equal(webgpuResult.candidateObjects.length, 2)
assert.equal(webgpuResult.structuralFixtures.length, 1)
assert.equal(webgpuResult.structuralFixtures[0].category, 'window')

const bed = webgpuResult.candidateObjects.find((candidate) => candidate.category === 'bed')
assert.ok(bed)
assert.equal(bed.sourceImageId, 'source-image-front')
assert.equal(bed.captureImageId, 'capture-image-front')
assert.equal(bed.sourceImageRole, 'front_wall')
assert.equal(bed.coordinateSpace, 'image_pixels')
assert.deepEqual(bed.boundingBox, { x: 80, y: 260, width: 640, height: 420 })
assert.equal(bed.confidenceScore, 0.91)

const custom = webgpuResult.candidateObjects.find((candidate) => candidate.category === 'custom')
assert.ok(custom)
assert.equal(custom.sourceImageId, 'source-image-overview')
assert.deepEqual(custom.boundingBox, { x: 1200, y: 310, width: 120, height: 420 })
assert.equal(
  webgpuResult.candidateObjects.some((candidate) => candidate.category === 'chair'),
  false,
)

const wasm = sceneUnderstandingResponseMessage(
  {
    captureSession,
    detectorRuntime: {
      webgpuAvailable: false,
      modelAssetsPresent: true,
    },
    detectorOutput: [
      {
        className: 'desk',
        score: 0.72,
        box: { x: 220, y: 330, width: 420, height: 250 },
      },
    ],
  },
  'cv-4.2-wasm',
)
assert.equal(wasm.type, 'roomforge.sceneUnderstanding.candidatesExtracted')
assert.equal(wasm.payload.sceneUnderstandingResult.runtime, 'wasm')
assert.equal(wasm.payload.sceneUnderstandingResult.candidateObjects[0].category, 'desk')

const mock = sceneUnderstandingResponseMessage({ captureSession }, 'cv-4.2-mock')
assert.equal(mock.type, 'roomforge.sceneUnderstanding.candidatesExtracted')
assert.equal(mock.payload.sceneUnderstandingResult.runtime, 'mock')
assert.equal(mock.payload.sceneUnderstandingResult.providerType, 'browser_cv_mock')
assert.equal(mock.payload.sceneUnderstandingResult.candidateObjects.length, 1)

const unsupported = sceneUnderstandingResponseMessage(
  {
    captureSession,
    detectorRuntime: {
      forceUnsupported: true,
    },
  },
  'cv-4.2-unsupported',
)
assert.equal(unsupported.type, 'roomforge.sceneUnderstanding.candidatesFailed')
assert.equal(unsupported.payload.error.code, 'unsupported_runtime')
assert.equal(unsupported.payload.sceneUnderstandingResult.qualityStatus, 'failed')
assert.equal(unsupported.payload.sceneUnderstandingResult.failureReasonCode, 'unsupported_runtime')

console.log('CV-4.2 browser detector runtime contract verified')
