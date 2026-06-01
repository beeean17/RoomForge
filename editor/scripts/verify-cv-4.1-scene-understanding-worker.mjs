import assert from 'node:assert/strict'

import { sceneUnderstandingResponseMessage } from '../src/sceneUnderstandingWorker.ts'
import { spatialModelFromBridgePayload } from '../src/spatialModel.ts'

const captureSession = {
  captureSessionId: 'capture-session-1',
  projectId: 'project-1',
  depthEnabled: false,
  availableRoles: ['overview', 'front_wall'],
  images: [
    {
      captureImageId: 'capture-image-overview',
      captureSessionId: 'capture-session-1',
      sourceImageId: 'source-image-overview',
      role: 'overview',
      widthPx: 1600,
      heightPx: 900,
      contentType: 'image/png',
    },
    {
      captureImageId: 'capture-image-front',
      captureSessionId: 'capture-session-1',
      sourceImageId: 'source-image-front',
      role: 'front_wall',
      widthPx: 1500,
      heightPx: 900,
      contentType: 'image/png',
    },
  ],
}

const success = sceneUnderstandingResponseMessage({ captureSession }, 'scene-understanding-test')
assert.equal(success.type, 'roomforge.sceneUnderstanding.candidatesExtracted')
assert.equal(success.requestId, 'scene-understanding-test')

const result = success.payload.sceneUnderstandingResult
assert.equal(result.providerType, 'browser_cv_mock')
assert.equal(result.algorithmId, 'mock-scene-understanding-v1')
assert.equal(result.captureSessionId, 'capture-session-1')
assert.equal(result.candidateObjects.length, 1)
assert.equal(result.candidateObjects[0].sourceImageId, 'source-image-overview')
assert.equal(result.candidateObjects[0].coordinateSpace, 'image_pixels')
assert.equal(result.structuralFixtures.length, 1)
assert.equal(result.structuralFixtures[0].category, 'window')

const appliedModel = spatialModelFromBridgePayload({
  scene: {
    room: {
      objectId: 'room-shell',
      label: 'Room shell',
      heightMeters: 2.7,
      floorPlan: {
        floorPlanId: 'floor-plan-1',
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
  },
  sceneUnderstandingResult: result,
})
assert.equal(appliedModel.candidateObjects.length, 1)
assert.equal(appliedModel.structuralFixtures.length, 1)

const failure = sceneUnderstandingResponseMessage({}, 'scene-understanding-empty')
assert.equal(failure.type, 'roomforge.sceneUnderstanding.candidatesFailed')
assert.equal(failure.payload.error.code, 'no_capture_images')
assert.equal(failure.payload.sceneUnderstandingResult.qualityStatus, 'failed')
assert.deepEqual(failure.payload.sceneUnderstandingResult.candidateObjects, [])

console.log('CV-4.1 scene understanding worker contract verified')
