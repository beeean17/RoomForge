import assert from 'node:assert/strict'

import {
  computeSceneCoverage,
  coverageGuidanceText,
  sceneCoveragePayload,
} from '../src/sceneCoverage.ts'
import { sceneUnderstandingResponseMessage } from '../src/sceneUnderstandingWorker.ts'
import { defaultSpatialModel } from '../src/spatialModel.ts'

function candidate(role, confidenceScore) {
  return {
    candidateId: `candidate-${role}`,
    objectType: 'furniture',
    category: 'chair',
    sourceImageRole: role,
    coordinateSpace: 'image_pixels',
    boundingBox: { x: 100, y: 300, width: 200, height: 260 },
    confidenceScore,
    reviewState: confidenceScore < 0.7 ? 'review_required' : 'new',
    suggestedPosition: { x: 1, y: 0, z: 1 },
    suggestedSize: { x: 0.55, y: 0.85, z: 0.55 },
    suggestedRotationDegrees: 0,
  }
}

const missing = computeSceneCoverage({
  availableRoles: ['front_wall', 'right_wall', 'back_wall'],
  candidateObjects: [
    candidate('front_wall', 0.9),
    candidate('right_wall', 0.82),
    candidate('back_wall', 0.85),
  ],
})
assert.equal(missing.walls.left_wall.state, 'missing')
assert.equal(missing.canContinue, false)
assert.ok(coverageGuidanceText(missing).includes('left_wall'))

const lowConfidence = computeSceneCoverage({
  availableRoles: ['front_wall', 'right_wall', 'back_wall', 'left_wall'],
  candidateObjects: [
    candidate('front_wall', 0.92),
    candidate('right_wall', 0.52),
    candidate('back_wall', 0.86),
    candidate('left_wall', 0.89),
  ],
})
assert.equal(lowConfidence.walls.right_wall.state, 'low_confidence')
assert.ok(lowConfidence.walls.right_wall.guidance.includes('Retake'))

const partial = computeSceneCoverage({
  availableRoles: ['front_wall', 'right_wall', 'back_wall', 'left_wall'],
  candidateObjects: [
    candidate('front_wall', 0.92),
    candidate('right_wall', 0.82),
    candidate('back_wall', 0.86),
  ],
})
assert.equal(partial.walls.left_wall.state, 'partial')
assert.ok(partial.walls.left_wall.guidance.includes('angled left_wall'))

const complete = computeSceneCoverage({
  availableRoles: ['front_wall', 'right_wall', 'back_wall', 'left_wall'],
  candidateObjects: [
    candidate('front_wall', 0.92),
    candidate('right_wall', 0.82),
    candidate('back_wall', 0.86),
    candidate('left_wall', 0.89),
  ],
})
assert.equal(complete.canContinue, true)
assert.equal(coverageGuidanceText(complete), 'Coverage looks sufficient. Continue editing the generated layout.')

const payload = sceneCoveragePayload(lowConfidence)
assert.equal(payload.canContinue, false)
assert.equal(payload.walls.right_wall.state, 'low_confidence')

const captureSession = {
  captureSessionId: 'capture-session-5-4',
  projectId: 'project-1',
  depthEnabled: false,
  availableRoles: ['front_wall', 'right_wall'],
  images: [
    {
      captureImageId: 'capture-image-front',
      captureSessionId: 'capture-session-5-4',
      sourceImageId: 'source-image-front',
      role: 'front_wall',
      widthPx: 1000,
      heightPx: 800,
      contentType: 'image/png',
    },
    {
      captureImageId: 'capture-image-right',
      captureSessionId: 'capture-session-5-4',
      sourceImageId: 'source-image-right',
      role: 'right_wall',
      widthPx: 1000,
      heightPx: 800,
      contentType: 'image/png',
    },
  ],
}

const response = sceneUnderstandingResponseMessage(
  {
    captureSession,
    spatialModel: defaultSpatialModel(),
    detectorRuntime: {
      webgpuAvailable: true,
      modelAssetsPresent: true,
      scoreThreshold: 0.45,
    },
    detectorOutput: [
      {
        className: 'bed',
        score: 0.86,
        captureImageId: 'capture-image-front',
        box: { x: 620, y: 500, width: 160, height: 300 },
      },
      {
        className: 'desk',
        score: 0.62,
        captureImageId: 'capture-image-right',
        box: { x: 220, y: 500, width: 160, height: 300 },
      },
    ],
  },
  'cv-5.4-coverage',
)

assert.equal(response.type, 'roomforge.sceneUnderstanding.candidatesExtracted')
const coverage = response.payload.sceneUnderstandingResult.coverage
assert.equal(coverage.canContinue, false)
assert.equal(coverage.walls.front_wall.state, 'complete')
assert.equal(coverage.walls.right_wall.state, 'low_confidence')
assert.equal(coverage.walls.back_wall.state, 'missing')
assert.equal(coverage.walls.left_wall.state, 'missing')
assert.ok(coverage.guidance.some((item) => item.includes('right_wall')))
assert.ok(coverage.guidance.some((item) => item.includes('back_wall')))

console.log('CV-5.4 capture coverage guidance contract verified')
