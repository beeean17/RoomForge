import assert from 'node:assert/strict'

import { placeCandidateInModel } from '../src/candidateTray.ts'
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

function candidateForRole(role, overrides = {}) {
  return {
    candidateId: `candidate-table-${role}`,
    objectType: 'furniture',
    category: 'table',
    label: `Detected table ${role}`,
    sourceImageId: `source-image-${role}`,
    captureImageId: `capture-image-${role}`,
    sourceImageRole: role,
    coordinateSpace: 'image_pixels',
    boundingBox: { x: 400, y: 500, width: 200, height: 220 },
    confidenceScore: 0.86,
    reviewState: 'new',
    suggestedAssetId: 'table.dining',
    suggestedSize: { x: 1.2, y: 0.74, z: 0.75 },
    ...overrides,
  }
}

const images = ['front_wall', 'right_wall', 'back_wall', 'left_wall'].map((role) => ({
  captureImageId: `capture-image-${role}`,
  sourceImageId: `source-image-${role}`,
  role,
  widthPx: 1000,
  heightPx: 800,
}))

const candidates = images.map((image) => candidateForRole(image.role))
const placedModel = applyMetricPlacementToCandidates({
  model: roomModel(4, 3, candidates),
  images,
})

const front = placedModel.candidateObjects.find((candidate) => candidate.sourceImageRole === 'front_wall')
assert.ok(front)
assert.deepEqual(front.suggestedPosition, { x: 2, y: 0, z: 0.48 })
assert.equal(front.suggestedRotationDegrees, 0)
assert.equal(front.suggestedWallId, 'front-wall')

const right = placedModel.candidateObjects.find((candidate) => candidate.sourceImageRole === 'right_wall')
assert.ok(right)
assert.deepEqual(right.suggestedPosition, { x: 3.4, y: 0, z: 1.5 })
assert.equal(right.suggestedRotationDegrees, 90)
assert.equal(right.suggestedWallId, 'right-wall')

const back = placedModel.candidateObjects.find((candidate) => candidate.sourceImageRole === 'back_wall')
assert.ok(back)
assert.deepEqual(back.suggestedPosition, { x: 2, y: 0, z: 2.52 })
assert.equal(back.suggestedRotationDegrees, 180)
assert.equal(back.suggestedWallId, 'back-wall')

const left = placedModel.candidateObjects.find((candidate) => candidate.sourceImageRole === 'left_wall')
assert.ok(left)
assert.deepEqual(left.suggestedPosition, { x: 0.6, y: 0, z: 1.5 })
assert.equal(left.suggestedRotationDegrees, 270)
assert.equal(left.suggestedWallId, 'left-wall')

const weak = applyMetricPlacementToCandidates({
  model: roomModel(4, 3, [
    candidateForRole('overview', {
      candidateId: 'candidate-weak-role',
      sourceImageRole: 'overview',
      confidenceScore: 0.64,
      boundingBox: undefined,
    }),
  ]),
  images: [],
}).candidateObjects[0]
assert.equal(weak.reviewState, 'review_required')
assert.equal(weak.reviewLabel, 'Needs review')
assert.ok(weak.notes?.includes('weak_or_missing_wall_role'))
assert.ok(weak.notes?.includes('missing_or_invalid_bbox'))

const clamped = estimateMetricPlacementForCandidate({
  candidate: candidateForRole('front_wall', {
    candidateId: 'candidate-clamped-bed',
    category: 'bed',
    suggestedSize: { x: 1.5, y: 0.55, z: 2 },
    boundingBox: { x: 0, y: 760, width: 40, height: 80 },
  }),
  model: roomModel(4, 3, []),
  images,
})
assert.deepEqual(clamped.suggestedPosition, { x: 0.75, y: 0, z: 1 })

const fourMeterRoom = applyMetricPlacementToCandidates({
  model: roomModel(4, 3, [candidateForRole('front_wall')]),
  images,
}).candidateObjects[0]
const sixMeterRoom = applyMetricPlacementToCandidates({
  model: roomModel(6, 3, [candidateForRole('front_wall')]),
  images,
}).candidateObjects[0]
assert.equal(fourMeterRoom.suggestedPosition?.x, 2)
assert.equal(sixMeterRoom.suggestedPosition?.x, 3)

const placedFurniture = placeCandidateInModel(
  { ...placedModel, candidateObjects: [front] },
  front.candidateId,
)
assert.equal(placedFurniture.furniture[0].position.x, front.suggestedPosition?.x)
assert.equal(placedFurniture.furniture[0].position.y, front.suggestedPosition?.z)
assert.equal(placedFurniture.furniture[0].rotationDegrees, front.suggestedRotationDegrees)

const captureSession = {
  captureSessionId: 'capture-session-5-2',
  projectId: 'project-1',
  depthEnabled: false,
  availableRoles: ['right_wall'],
  images: [
    {
      captureImageId: 'capture-image-right_wall',
      captureSessionId: 'capture-session-5-2',
      sourceImageId: 'source-image-right_wall',
      role: 'right_wall',
      widthPx: 1000,
      heightPx: 800,
      contentType: 'image/png',
    },
  ],
}

const workerResponse = sceneUnderstandingResponseMessage(
  {
    captureSession,
    spatialModel: roomModel(4, 3, []),
    detectorRuntime: {
      webgpuAvailable: true,
      modelAssetsPresent: true,
      scoreThreshold: 0.45,
    },
    detectorOutput: [
      {
        className: 'desk',
        score: 0.9,
        captureImageId: 'capture-image-right_wall',
        box: { x: 400, y: 500, width: 200, height: 220 },
      },
    ],
  },
  'cv-5.2-worker-placement',
)
assert.equal(workerResponse.type, 'roomforge.sceneUnderstanding.candidatesExtracted')
const workerCandidate = workerResponse.payload.sceneUnderstandingResult.candidateObjects[0]
assert.equal(workerCandidate.suggestedWallId, 'right-wall')
assert.equal(workerCandidate.suggestedRotationDegrees, 90)
assert.equal(workerCandidate.suggestedPosition.x, 3.4)

console.log('CV-5.2 wall-role metric placement contract verified')
