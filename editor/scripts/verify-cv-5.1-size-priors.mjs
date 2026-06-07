import assert from 'node:assert/strict'

import {
  placeCandidateInModel,
  updateCandidateCategoryInModel,
} from '../src/candidateTray.ts'
import { sceneUnderstandingResponseMessage } from '../src/sceneUnderstandingWorker.ts'
import {
  furnitureSizePriorForCategory,
  structuralFixtureSizePriorForCategory,
} from '../src/sizePriors.ts'
import { defaultSpatialModel } from '../src/spatialModel.ts'

const requiredFurnitureCategories = [
  'bed',
  'desk',
  'chair',
  'wardrobe',
  'dresser',
  'nightstand',
  'sofa',
  'table',
  'shelf',
  'cabinet',
]

for (const category of requiredFurnitureCategories) {
  const prior = furnitureSizePriorForCategory(category)
  assert.equal(prior.category, category)
  assert.ok(prior.size.widthMeters > 0)
  assert.ok(prior.size.depthMeters > 0)
  assert.ok(prior.size.heightMeters > 0)
  assert.deepEqual(prior.suggestedSize, {
    x: prior.size.widthMeters,
    y: prior.size.heightMeters,
    z: prior.size.depthMeters,
  })
  assert.notEqual(prior.assetId, `${category}.pending`)
}

const unknownPrior = furnitureSizePriorForCategory('floor_lamp')
assert.equal(unknownPrior.category, 'custom')
assert.equal(unknownPrior.assetId, 'custom.proxy')
assert.deepEqual(unknownPrior.suggestedSize, { x: 0.8, y: 0.8, z: 0.8 })
assert.equal(furnitureSizePriorForCategory('dresser').assetId, 'dresser.standard')
assert.equal(furnitureSizePriorForCategory('nightstand').assetId, 'drawer.nightstand')

assert.equal(structuralFixtureSizePriorForCategory('window').assetId, 'fixture.window.standard')
assert.equal(structuralFixtureSizePriorForCategory('door').assetId, 'fixture.door.standard')
assert.equal(structuralFixtureSizePriorForCategory('unknown_fixture').assetId, 'fixture.built_in.proxy')

const model = {
  ...defaultSpatialModel(),
  candidateObjects: [
    {
      candidateId: 'candidate-chair-1',
      objectType: 'furniture',
      category: 'chair',
      label: 'Detected chair',
      coordinateSpace: 'image_pixels',
      confidenceScore: 0.88,
      reviewState: 'new',
      suggestedAssetId: 'chair.desk',
      suggestedSize: { x: 0.55, y: 0.85, z: 0.55 },
    },
  ],
  furniture: [
    {
      objectId: 'cv-candidate-chair-1',
      candidateId: 'candidate-chair-1',
      source: 'cv_candidate',
      category: 'chair',
      label: 'Edited chair',
      size: { widthMeters: 0.7, depthMeters: 0.72, heightMeters: 0.9 },
      position: { x: 1.4, y: 1.5 },
      rotationDegrees: 15,
      color: '#64748b',
      locked: false,
    },
  ],
  placedObjects: [
    {
      objectId: 'cv-candidate-chair-1',
      candidateId: 'candidate-chair-1',
      objectType: 'furniture',
      category: 'chair',
      assetId: 'chair.desk',
      size: { x: 0.7, y: 0.9, z: 0.72 },
      position: { x: 1.4, y: 0, z: 1.5 },
      rotationDegrees: 15,
      locked: false,
    },
  ],
  confirmedObjects: [
    {
      objectId: 'confirmed-chair-1',
      candidateId: 'candidate-chair-1',
      objectType: 'furniture',
      category: 'chair',
      assetId: 'chair.desk',
      size: { x: 0.7, y: 0.9, z: 0.72 },
      position: { x: 1.4, y: 0, z: 1.5 },
      rotationDegrees: 15,
      locked: false,
      confirmedByUid: 'user-1',
      confirmedAt: '2026-06-02T00:00:00.000Z',
    },
  ],
}

const changed = updateCandidateCategoryInModel({
  model,
  candidateId: 'candidate-chair-1',
  category: 'sofa',
})

assert.equal(changed.candidateObjects[0].category, 'sofa')
assert.equal(changed.candidateObjects[0].suggestedAssetId, 'sofa.two-seat')
assert.deepEqual(changed.candidateObjects[0].suggestedSize, { x: 1.8, y: 0.82, z: 0.85 })
assert.deepEqual(changed.furniture[0].size, model.furniture[0].size)
assert.deepEqual(changed.placedObjects[0].size, model.placedObjects[0].size)
assert.deepEqual(changed.confirmedObjects[0].size, model.confirmedObjects[0].size)

const placedFromPrior = placeCandidateInModel(
  {
    ...defaultSpatialModel(),
    candidateObjects: [
      {
        candidateId: 'candidate-wardrobe-1',
        objectType: 'furniture',
        category: 'wardrobe',
        coordinateSpace: 'image_pixels',
        confidenceScore: 0.76,
        reviewState: 'new',
      },
    ],
  },
  'candidate-wardrobe-1',
)
assert.equal(placedFromPrior.furniture[0].size.widthMeters, 1)
assert.equal(placedFromPrior.furniture[0].size.depthMeters, 0.6)
assert.equal(placedFromPrior.furniture[0].size.heightMeters, 2)
assert.equal(placedFromPrior.placedObjects[0].assetId, 'wardrobe.standard')

const captureSession = {
  captureSessionId: 'capture-session-5-1',
  projectId: 'project-1',
  depthEnabled: false,
  availableRoles: ['front_wall'],
  images: [
    {
      captureImageId: 'capture-image-front',
      captureSessionId: 'capture-session-5-1',
      sourceImageId: 'source-image-front',
      role: 'front_wall',
      widthPx: 1600,
      heightPx: 900,
      contentType: 'image/png',
    },
  ],
}

const response = sceneUnderstandingResponseMessage(
  {
    captureSession,
    detectorRuntime: {
      webgpuAvailable: true,
      modelAssetsPresent: true,
      scoreThreshold: 0.45,
    },
    detectorOutput: [
      {
        className: 'floor_lamp',
        score: 0.82,
        box: { x: 220, y: 330, width: 160, height: 440 },
      },
    ],
  },
  'cv-5.1-size-priors',
)

assert.equal(response.type, 'roomforge.sceneUnderstanding.candidatesExtracted')
const candidate = response.payload.sceneUnderstandingResult.candidateObjects[0]
assert.equal(candidate.category, 'custom')
assert.equal(candidate.suggestedAssetId, 'custom.proxy')
assert.deepEqual(candidate.suggestedSize, { x: 0.8, y: 0.8, z: 0.8 })

console.log('CV-5.1 category size prior contract verified')
