import assert from 'node:assert/strict'

import {
  candidateTrayItems,
  placeCandidateInModel,
  rejectCandidateInModel,
  releaseCandidatePlacementInModel,
} from '../src/candidateTray.ts'
import {
  editSelectedFurnitureInModel,
  selectedFurniture,
} from '../src/furnitureModel.ts'
import { defaultSpatialModel } from '../src/spatialModel.ts'

const model = {
  ...defaultSpatialModel(),
  candidateObjects: [
    {
      candidateId: 'candidate-bed-1',
      objectType: 'furniture',
      category: 'bed',
      label: 'Detected bed',
      coordinateSpace: 'image_pixels',
      confidenceScore: 0.84,
      reviewState: 'new',
      suggestedAssetId: 'bed.double',
      suggestedPosition: { x: 1.1, y: 0, z: 2.1 },
      suggestedSize: { x: 1.5, y: 0.55, z: 2 },
      suggestedRotationDegrees: 90,
    },
  ],
}

const placed = placeCandidateInModel(model, 'candidate-bed-1')
assert.notEqual(placed, model)
assert.equal(placed.furniture.length, 1)
assert.equal(placed.furniture[0].candidateId, 'candidate-bed-1')
assert.equal(placed.furniture[0].source, 'cv_candidate')
assert.equal(placed.furniture[0].category, 'bed')
assert.equal(placed.furniture[0].size.widthMeters, 1.5)
assert.equal(placed.furniture[0].size.depthMeters, 2)
assert.equal(placed.furniture[0].size.heightMeters, 0.55)
assert.equal(placed.furniture[0].position.x, 1.1)
assert.equal(placed.furniture[0].position.y, 2.1)
assert.equal(placed.furniture[0].rotationDegrees, 90)
assert.deepEqual(placed.selected, { objectId: 'cv-candidate-bed-1', objectType: 'furniture' })
assert.equal(placed.placedObjects.length, 1)
assert.equal(placed.placedObjects[0].candidateId, 'candidate-bed-1')
assert.equal(placed.candidateObjects[0].reviewState, 'placed')
assert.equal(candidateTrayItems(placed)[0].placed, true)

const moved = editSelectedFurnitureInModel(placed, 'move-right').model
assert.equal(selectedFurniture(moved)?.position.x, 1.2)
assert.equal(selectedFurniture(moved)?.candidateId, 'candidate-bed-1')

const deleted = editSelectedFurnitureInModel(moved, 'delete').model
const released = releaseCandidatePlacementInModel(deleted, 'candidate-bed-1')
assert.equal(released.furniture.length, 0)
assert.equal(released.placedObjects.length, 0)
assert.equal(released.candidateObjects[0].reviewState, 'review_required')
assert.equal(candidateTrayItems(released)[0].placed, false)

const replaced = placeCandidateInModel(released, 'candidate-bed-1')
assert.equal(replaced.furniture.length, 1)

const rejected = rejectCandidateInModel(replaced, 'candidate-bed-1')
assert.equal(rejected.furniture.length, 0)
assert.equal(rejected.placedObjects.length, 0)
assert.equal(rejected.candidateObjects[0].reviewState, 'rejected')

console.log('CV-3.3 candidate placement and editing contract verified')
