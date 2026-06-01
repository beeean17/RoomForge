import assert from 'node:assert/strict'

import {
  editSelectedFixtureInModel,
  selectFixtureInModel,
  selectedFixture,
  selectedFixtureSummary,
} from '../src/fixtureModel.ts'
import { defaultSpatialModel, spatialModelFromBridgePayload } from '../src/spatialModel.ts'

const model = spatialModelFromBridgePayload({
  scene: {
    room: defaultSpatialModel().room,
    structuralFixtures: [
      {
        fixtureId: 'fixture-window-1',
        candidateId: 'candidate-window-1',
        category: 'window',
        wallId: 'front-wall',
        label: 'Front window',
        position: { x: 1.2, y: 1.1, z: 0 },
        size: { x: 1.1, y: 0.9, z: 0.1 },
        rotationDegrees: 0,
        confidenceScore: 0.52,
        locked: true,
      },
    ],
  },
})

assert.equal(model.structuralFixtures.length, 1)
assert.equal(model.furniture.length, 0)

let selectedModel = selectFixtureInModel(model, 'fixture-window-1')
assert.deepEqual(selectedModel.selected, { objectId: 'fixture-window-1', objectType: 'fixture' })
assert.equal(selectedFixture(selectedModel)?.category, 'window')
assert.equal(selectedFixtureSummary(selectedModel).includes('front-wall'), true)

selectedModel = editSelectedFixtureInModel(selectedModel, 'wall-next').model
assert.equal(selectedFixture(selectedModel)?.wallId, 'right-wall')
selectedModel = editSelectedFixtureInModel(selectedModel, 'offset-increase').model
assert.equal(selectedFixture(selectedModel)?.position?.x, 1.3)
selectedModel = editSelectedFixtureInModel(selectedModel, 'wider').model
assert.equal(selectedFixture(selectedModel)?.size?.x, 1.2)
selectedModel = editSelectedFixtureInModel(selectedModel, 'taller').model
assert.equal(selectedFixture(selectedModel)?.size?.y, 1)
selectedModel = editSelectedFixtureInModel(selectedModel, 'category-next').model
assert.equal(selectedFixture(selectedModel)?.category, 'door')

const payload = {
  structuralFixtures: selectedModel.structuralFixtures,
}
assert.equal(payload.structuralFixtures[0].category, 'door')
assert.equal(payload.structuralFixtures[0].wallId, 'right-wall')

const deleted = editSelectedFixtureInModel(selectedModel, 'delete')
assert.equal(deleted.deleted, true)
assert.equal(deleted.model.structuralFixtures.length, 0)
assert.deepEqual(deleted.model.selected, { objectId: selectedModel.room.objectId, objectType: 'room' })

console.log('CV-3.4 structural fixture edit contract verified')
