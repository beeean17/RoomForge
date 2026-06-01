import assert from 'node:assert/strict'

import {
  candidateTrayItems,
  rejectCandidateInModel,
  updateCandidateCategoryInModel,
} from '../src/candidateTray.ts'
import { defaultSpatialModel } from '../src/spatialModel.ts'

const model = {
  ...defaultSpatialModel(),
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
      confidenceScore: 0.52,
      reviewState: 'review_required',
      suggestedAssetId: 'bed.double',
    },
    {
      candidateId: 'candidate-chair-1',
      objectType: 'furniture',
      category: 'chair',
      sourceImageRole: 'overview',
      coordinateSpace: 'image_pixels',
      confidenceScore: 0.91,
      reviewState: 'new',
    },
  ],
  placedObjects: [
    {
      objectId: 'placed-bed-1',
      candidateId: 'candidate-bed-1',
      objectType: 'furniture',
      category: 'bed',
      rotationDegrees: 0,
      locked: false,
    },
  ],
}

const items = candidateTrayItems(model)
assert.equal(items.length, 2)
assert.equal(items[0].label, 'Detected bed')
assert.equal(items[0].reviewLabel, 'Needs review')
assert.equal(items[0].lowConfidence, true)
assert.equal(items[0].sourceLabel, 'front_wall')
assert.equal(items[1].reviewLabel, 'Candidate')

const rejected = rejectCandidateInModel(model, 'candidate-bed-1')
assert.notEqual(rejected, model)
assert.equal(rejected.hasUnsavedChanges, true)
assert.equal(rejected.candidateObjects[0].reviewState, 'rejected')
assert.equal(rejected.candidateObjects[0].reviewLabel, 'Rejected')
assert.equal(rejected.candidateObjects.length, 2)
assert.equal(rejected.placedObjects.some((object) => object.candidateId === 'candidate-bed-1'), false)

const changedCategory = updateCandidateCategoryInModel({
  model,
  candidateId: 'candidate-chair-1',
  category: 'sofa',
})
assert.equal(changedCategory.candidateObjects[1].category, 'sofa')
assert.equal(changedCategory.candidateObjects[1].reviewLabel, 'Needs review')
assert.equal(changedCategory.candidateObjects[1].suggestedAssetId, 'sofa.pending')
assert.equal(changedCategory.hasUnsavedChanges, true)

assert.equal(
  updateCandidateCategoryInModel({
    model,
    candidateId: 'candidate-chair-1',
    category: 'unsupported',
  }),
  model,
)

console.log('CV-3.2 candidate tray review state contract verified')
