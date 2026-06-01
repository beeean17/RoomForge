import assert from 'node:assert/strict'

import { candidateTrayItems } from '../src/candidateTray.ts'
import { mergeSceneCandidates } from '../src/sceneCandidateMerge.ts'
import { sceneUnderstandingResponseMessage } from '../src/sceneUnderstandingWorker.ts'
import { defaultSpatialModel } from '../src/spatialModel.ts'

function candidate({
  id,
  category,
  role,
  position,
  score,
  size = { x: 1.5, y: 0.55, z: 2 },
}) {
  return {
    candidateId: id,
    objectType: 'furniture',
    category,
    label: `Detected ${category}`,
    sourceImageId: `source-${role}-${id}`,
    captureImageId: `capture-${role}-${id}`,
    sourceImageRole: role,
    coordinateSpace: 'image_pixels',
    boundingBox: { x: 100, y: 400, width: 240, height: 300 },
    confidenceScore: score,
    reviewState: 'new',
    reviewLabel: 'Candidate',
    suggestedAssetId: `${category}.proxy`,
    suggestedPosition: position,
    suggestedWallId: role.replace('_', '-'),
    suggestedSize: size,
    suggestedRotationDegrees: 0,
  }
}

const duplicateMerge = mergeSceneCandidates([
  candidate({
    id: 'candidate-bed-front',
    category: 'bed',
    role: 'front_wall',
    position: { x: 2.8, y: 0, z: 1 },
    score: 0.86,
  }),
  candidate({
    id: 'candidate-bed-right',
    category: 'bed',
    role: 'right_wall',
    position: { x: 3.2, y: 0, z: 1.1 },
    score: 0.91,
  }),
])
assert.equal(duplicateMerge.length, 1)
assert.equal(duplicateMerge[0].category, 'bed')
assert.equal(duplicateMerge[0].confidenceScore, 0.91)
assert.equal(duplicateMerge[0].sourceEvidence?.length, 2)
assert.deepEqual(
  duplicateMerge[0].sourceEvidence?.map((item) => item.sourceImageRole),
  ['front_wall', 'right_wall'],
)
assert.ok(duplicateMerge[0].notes?.includes('Merged 2 same-category detections'))

const farApart = mergeSceneCandidates([
  candidate({
    id: 'candidate-chair-front',
    category: 'chair',
    role: 'front_wall',
    position: { x: 0.8, y: 0, z: 0.5 },
    score: 0.82,
    size: { x: 0.55, y: 0.85, z: 0.55 },
  }),
  candidate({
    id: 'candidate-chair-back',
    category: 'chair',
    role: 'back_wall',
    position: { x: 3.4, y: 0, z: 2.4 },
    score: 0.84,
    size: { x: 0.55, y: 0.85, z: 0.55 },
  }),
])
assert.equal(farApart.length, 2)

const conflict = mergeSceneCandidates([
  candidate({
    id: 'candidate-table-front',
    category: 'table',
    role: 'front_wall',
    position: { x: 2, y: 0, z: 1.1 },
    score: 0.74,
    size: { x: 1.2, y: 0.74, z: 0.75 },
  }),
  candidate({
    id: 'candidate-desk-front',
    category: 'desk',
    role: 'front_wall',
    position: { x: 2.05, y: 0, z: 1.05 },
    score: 0.9,
    size: { x: 1.2, y: 0.75, z: 0.65 },
  }),
])
assert.equal(conflict.length, 1)
assert.equal(conflict[0].category, 'desk')
assert.equal(conflict[0].reviewState, 'review_required')
assert.equal(conflict[0].reviewLabel, 'Needs review')
assert.ok(conflict[0].notes?.includes('category conflict'))
assert.equal(conflict[0].sourceEvidence?.length, 2)

const trayModel = {
  ...defaultSpatialModel(),
  candidateObjects: duplicateMerge,
}
assert.equal(candidateTrayItems(trayModel)[0].sourceLabel, 'front_wall, right_wall (2 sources)')

const captureSession = {
  captureSessionId: 'capture-session-5-3',
  projectId: 'project-1',
  depthEnabled: false,
  availableRoles: ['front_wall', 'right_wall', 'back_wall'],
  images: [
    {
      captureImageId: 'capture-image-front',
      captureSessionId: 'capture-session-5-3',
      sourceImageId: 'source-image-front',
      role: 'front_wall',
      widthPx: 1000,
      heightPx: 800,
      contentType: 'image/png',
    },
    {
      captureImageId: 'capture-image-right',
      captureSessionId: 'capture-session-5-3',
      sourceImageId: 'source-image-right',
      role: 'right_wall',
      widthPx: 1000,
      heightPx: 800,
      contentType: 'image/png',
    },
    {
      captureImageId: 'capture-image-back',
      captureSessionId: 'capture-session-5-3',
      sourceImageId: 'source-image-back',
      role: 'back_wall',
      widthPx: 1000,
      heightPx: 800,
      contentType: 'image/png',
    },
  ],
}

const workerResponse = sceneUnderstandingResponseMessage(
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
        className: 'bed',
        score: 0.9,
        captureImageId: 'capture-image-right',
        box: { x: 220, y: 500, width: 160, height: 300 },
      },
      {
        className: 'chair',
        score: 0.88,
        captureImageId: 'capture-image-back',
        box: { x: 720, y: 500, width: 120, height: 260 },
      },
    ],
  },
  'cv-5.3-worker-merge',
)

assert.equal(workerResponse.type, 'roomforge.sceneUnderstanding.candidatesExtracted')
const workerCandidates = workerResponse.payload.sceneUnderstandingResult.candidateObjects
assert.equal(workerCandidates.length, 2)
const workerBed = workerCandidates.find((item) => item.category === 'bed')
assert.ok(workerBed)
assert.equal(workerBed.sourceEvidence.length, 2)
assert.deepEqual(
  workerBed.sourceEvidence.map((item) => item.sourceImageRole),
  ['front_wall', 'right_wall'],
)
assert.equal(workerCandidates.some((item) => item.category === 'chair'), true)

console.log('CV-5.3 multi-photo candidate merge contract verified')
