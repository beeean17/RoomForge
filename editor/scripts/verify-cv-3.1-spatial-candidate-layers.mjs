import assert from 'node:assert/strict'

import {
  defaultSpatialModel,
  spatialModelFromBridgePayload,
} from '../src/spatialModel.ts'
import {
  addFurnitureToModel,
  editSelectedFurnitureInModel,
  furnitureDefaults,
  selectedFurniture,
} from '../src/furnitureModel.ts'

const metricRoom = {
  objectId: 'room-shell',
  label: 'Room shell',
  heightMeters: 2.7,
  floorPlan: {
    floorPlanId: 'floor-plan-cv-3-1',
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
}

const model = spatialModelFromBridgePayload({
  scene: {
    sceneId: 'cv-3-1-scene',
    viewMode: '2d',
    room: metricRoom,
    candidateObjects: [
      {
        candidateId: 'candidate-bed-1',
        objectType: 'furniture',
        category: 'bed',
        label: 'Detected bed',
        sourceImageId: 'source-image-front',
        captureImageId: 'capture-image-front',
        sourceImageRole: 'front_wall',
        coordinateSpace: 'image_pixels',
        boundingBox: { x: 120, y: 240, width: 520, height: 300 },
        confidenceScore: 0.82,
        reviewState: 'review_required',
        reviewLabel: 'Needs review',
        suggestedAssetId: 'bed.double',
        suggestedPosition: { x: 1.2, y: 0, z: 2.3 },
        suggestedSize: { x: 1.5, y: 0.55, z: 2 },
        suggestedRotationDegrees: 90,
      },
    ],
    structuralFixtures: [
      {
        fixtureId: 'fixture-window-1',
        candidateId: 'candidate-window-1',
        category: 'window',
        wallId: 'front-wall',
        label: 'Front window',
        position: { x: 2.1, y: 1.1, z: 0 },
        size: { x: 1.2, y: 1, z: 0.1 },
        rotationDegrees: 0,
        confidenceScore: 0.76,
        locked: true,
      },
    ],
    placedObjects: [
      {
        objectId: 'placed-bed-1',
        candidateId: 'candidate-bed-1',
        objectType: 'furniture',
        category: 'bed',
        assetId: 'bed.double',
        label: 'Placed bed',
        position: { x: 1.2, y: 0, z: 2.3 },
        size: { x: 1.5, y: 0.55, z: 2 },
        rotationDegrees: 90,
        confidenceScore: 0.82,
      },
    ],
    confirmedObjects: [
      {
        objectId: 'confirmed-bed-1',
        candidateId: 'candidate-bed-1',
        objectType: 'furniture',
        category: 'bed',
        assetId: 'bed.double',
        label: 'Confirmed bed',
        position: { x: 1.2, y: 0, z: 2.3 },
        size: { x: 1.5, y: 0.55, z: 2 },
        rotationDegrees: 90,
        confirmedByUid: 'user-1',
        confirmedAt: '2026-06-02T00:00:00.000Z',
      },
    ],
    furniture: [],
  },
})

assert.equal(model.candidateObjects.length, 1)
assert.equal(model.candidateObjects[0].candidateId, 'candidate-bed-1')
assert.equal(model.candidateObjects[0].category, 'bed')
assert.equal(model.candidateObjects[0].coordinateSpace, 'image_pixels')
assert.equal(model.candidateObjects[0].boundingBox?.width, 520)
assert.equal(model.candidateObjects[0].suggestedPosition?.z, 2.3)
assert.equal(model.furniture.length, 0)

assert.equal(model.structuralFixtures.length, 1)
assert.equal(model.structuralFixtures[0].fixtureId, 'fixture-window-1')
assert.equal(model.structuralFixtures[0].wallId, 'front-wall')
assert.equal(model.structuralFixtures[0].locked, true)
assert.equal(model.furniture.some((item) => item.objectId === 'fixture-window-1'), false)

assert.equal(model.placedObjects.length, 1)
assert.equal(model.placedObjects[0].candidateId, 'candidate-bed-1')
assert.equal(model.confirmedObjects.length, 1)
assert.equal(model.confirmedObjects[0].confirmedByUid, 'user-1')

const resultScopedModel = spatialModelFromBridgePayload({
  scene: {
    sceneId: 'cv-3-1-result-scene',
    room: metricRoom,
  },
  sceneUnderstandingResult: {
    candidateObjects: model.candidateObjects,
    structuralFixtures: model.structuralFixtures,
  },
})
assert.equal(resultScopedModel.candidateObjects.length, 1)
assert.equal(resultScopedModel.structuralFixtures.length, 1)

const fallback = defaultSpatialModel()
assert.deepEqual(fallback.candidateObjects, [])
assert.deepEqual(fallback.structuralFixtures, [])
assert.deepEqual(spatialModelFromBridgePayload({}).candidateObjects, [])

let furnitureModel = addFurnitureToModel(
  model,
  furnitureDefaults({ category: 'chair', id: 'chair-1', model }),
)
furnitureModel = { ...furnitureModel, selected: { objectId: 'chair-1', objectType: 'furniture' } }
const moved = editSelectedFurnitureInModel(furnitureModel, 'move-right').model
assert.equal(selectedFurniture(moved)?.objectId, 'chair-1')
assert.equal(moved.candidateObjects[0].candidateId, 'candidate-bed-1')
assert.equal(moved.structuralFixtures[0].fixtureId, 'fixture-window-1')

console.log('CV-3.1 spatial candidate and fixture layer contract verified')
