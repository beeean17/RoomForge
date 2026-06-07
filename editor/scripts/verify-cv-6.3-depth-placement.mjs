import assert from 'node:assert/strict'

import {
  applyMetricPlacementToCandidates,
  estimateMetricPlacementForCandidate,
} from '../src/scenePlacement.ts'
import { sceneUnderstandingResponseMessage } from '../src/sceneUnderstandingWorker.ts'
import { defaultSpatialModel } from '../src/spatialModel.ts'

function roomModel(widthMeters, depthMeters, candidateObjects) {
  const base = defaultSpatialModel()
  return {
    ...base,
    room: {
      ...base.room,
      floorPlan: {
        ...base.room.floorPlan,
        metricGeometry: {
          coordinateSpace: 'meters',
          points: [
            { x: 0, y: 0 },
            { x: widthMeters, y: 0 },
            { x: widthMeters, y: depthMeters },
            { x: 0, y: depthMeters },
          ],
        },
      },
    },
    candidateObjects,
  }
}

function candidate(overrides = {}) {
  return {
    candidateId: 'candidate-table-front-wall',
    objectType: 'furniture',
    category: 'table',
    label: 'Detected table',
    sourceImageId: 'source-image-front_wall',
    captureImageId: 'capture-image-front_wall',
    sourceImageRole: 'front_wall',
    coordinateSpace: 'image_pixels',
    boundingBox: { x: 400, y: 500, width: 200, height: 220 },
    confidenceScore: 0.86,
    reviewState: 'new',
    suggestedAssetId: 'table.dining',
    suggestedSize: { x: 1.2, y: 0.74, z: 0.75 },
    ...overrides,
  }
}

function image(overrides = {}) {
  return {
    captureImageId: 'capture-image-front_wall',
    captureSessionId: 'capture-session-6-3',
    sourceImageId: 'source-image-front_wall',
    role: 'front_wall',
    widthPx: 1000,
    heightPx: 800,
    ...overrides,
  }
}

function depthImage(overrides = {}) {
  return image({
    depthArtifactRefs: [
      {
        artifactId: 'depth-artifact-1',
        artifactType: 'arcore_depth',
        storagePath:
          'users/user-1/projects/project-1/capture-sessions/capture-session-6-3/artifacts/depth-artifact-1/depth.json',
        contentType: 'application/json',
        byteSize: 128,
      },
    ],
    cameraPose: {
      depthEstimateMeters: 1.35,
      depthConfidence: 0.84,
      sizeScale: 1.1,
      translationM: { x: 0.2, y: 1.4, z: 2.1 },
    },
    ...overrides,
  })
}

const baseModel = roomModel(4, 3, [])
const fallbackEstimate = estimateMetricPlacementForCandidate({
  candidate: candidate(),
  model: baseModel,
  images: [image()],
})
assert.deepEqual(fallbackEstimate.suggestedPosition, { x: 2, y: 0, z: 0.48 })
assert.deepEqual(fallbackEstimate.suggestedSize, { x: 1.2, y: 0.74, z: 0.75 })
assert.equal(fallbackEstimate.evidenceSource, 'wall_role')
assert.equal(fallbackEstimate.reviewRequired, false)

const depthEstimate = estimateMetricPlacementForCandidate({
  candidate: candidate(),
  model: baseModel,
  images: [depthImage()],
})
assert.equal(depthEstimate.evidenceSource, 'depth_assisted')
assert.equal(depthEstimate.depthConfidence, 0.84)
assert.deepEqual(depthEstimate.suggestedPosition, { x: 2, y: 0, z: 1.35 })
assert.deepEqual(depthEstimate.suggestedSize, { x: 1.32, y: 0.74, z: 0.83 })
assert.equal(depthEstimate.reviewRequired, false)
assert.notDeepEqual(depthEstimate.suggestedPosition, fallbackEstimate.suggestedPosition)

const lowConfidenceEstimate = estimateMetricPlacementForCandidate({
  candidate: candidate(),
  model: baseModel,
  images: [depthImage({ cameraPose: { depthEstimateMeters: 1.25, depthConfidence: 0.62 } })],
})
assert.equal(lowConfidenceEstimate.evidenceSource, 'depth_assisted')
assert.deepEqual(lowConfidenceEstimate.suggestedPosition, { x: 2, y: 0, z: 1.25 })
assert.equal(lowConfidenceEstimate.reviewRequired, true)
assert.ok(lowConfidenceEstimate.reviewReasons.includes('depth_assisted_low_confidence'))

const noisyDepthEstimate = estimateMetricPlacementForCandidate({
  candidate: candidate(),
  model: baseModel,
  images: [depthImage({ cameraPose: { depthEstimateMeters: 8, depthConfidence: 0.9 } })],
})
assert.equal(noisyDepthEstimate.evidenceSource, 'wall_role')
assert.deepEqual(noisyDepthEstimate.suggestedPosition, fallbackEstimate.suggestedPosition)
assert.equal(noisyDepthEstimate.reviewRequired, true)
assert.ok(noisyDepthEstimate.reviewReasons.includes('noisy_depth_metadata'))

const placedCandidate = candidate({
  reviewState: 'placed',
  reviewLabel: 'Placed',
  suggestedPosition: { x: 3.2, y: 0, z: 2.1 },
  suggestedSize: { x: 2, y: 1, z: 1 },
})
const afterDepthPlacement = applyMetricPlacementToCandidates({
  model: roomModel(4, 3, [placedCandidate]),
  images: [depthImage()],
}).candidateObjects[0]
assert.deepEqual(afterDepthPlacement.suggestedPosition, placedCandidate.suggestedPosition)
assert.deepEqual(afterDepthPlacement.suggestedSize, placedCandidate.suggestedSize)
assert.equal(afterDepthPlacement.reviewState, 'placed')

const workerResponse = sceneUnderstandingResponseMessage(
  {
    captureSession: {
      captureSessionId: 'capture-session-6-3',
      projectId: 'project-1',
      depthEnabled: true,
      availableRoles: ['front_wall'],
      images: [depthImage()],
    },
    spatialModel: roomModel(4, 3, []),
    detectorRuntime: {
      webgpuAvailable: true,
      modelAssetsPresent: true,
      scoreThreshold: 0.45,
    },
    detectorOutput: [
      {
        className: 'table',
        score: 0.9,
        captureImageId: 'capture-image-front_wall',
        box: { x: 400, y: 500, width: 200, height: 220 },
      },
    ],
  },
  'cv-6.3-worker-depth-placement',
)
assert.equal(workerResponse.type, 'roomforge.sceneUnderstanding.candidatesExtracted')
const workerCandidate = workerResponse.payload.sceneUnderstandingResult.candidateObjects[0]
assert.deepEqual(workerCandidate.suggestedPosition, { x: 2, y: 0, z: 1.35 })
assert.equal(workerCandidate.suggestedSize.x, 1.32)
assert.equal(workerCandidate.reviewState, 'new')
assert.ok(workerCandidate.notes.includes('depth metadata'))

console.log('CV-6.3 depth-assisted placement contract verified')
