import assert from 'node:assert/strict'

import {
  addFurnitureToModel,
  furnitureDefaults,
  selectedFurniture,
  selectedFurnitureSummary,
  selectionVisualTokens,
  selectFurnitureInModel,
} from '../src/furnitureModel.ts'
import { defaultSpatialModel } from '../src/spatialModel.ts'

let model = {
  ...defaultSpatialModel(),
  room: {
    ...defaultSpatialModel().room,
    floorPlan: {
      floorPlanId: 'floor-plan-furniture',
      metricGeometry: {
        coordinateSpace: 'meters',
        points: [
          { x: 0, y: 0 },
          { x: 5, y: 0 },
          { x: 5, y: 3 },
          { x: 0, y: 3 },
        ],
      },
    },
  },
}

const chair = furnitureDefaults({
  category: 'chair',
  id: 'furniture-chair-1',
  model,
})

assert.equal(chair.objectId, 'furniture-chair-1')
assert.equal(chair.category, 'chair')
assert.equal(chair.size.widthMeters, 0.55)
assert.equal(chair.position.x, 3.4)
assert.equal(chair.position.y, 2.04)
assert.equal(chair.rotationDegrees, 0)
assert.equal(chair.color, '#64748b')

model = addFurnitureToModel(model, chair)
assert.equal(model.hasUnsavedChanges, true)
assert.deepEqual(model.selected, { objectId: 'furniture-chair-1', objectType: 'furniture' })
assert.equal(model.furniture.length, 1)
assert.equal(selectedFurniture(model)?.objectId, 'furniture-chair-1')

const sofa = furnitureDefaults({
  category: 'sofa',
  id: 'furniture-sofa-1',
  model,
})
model = addFurnitureToModel(model, sofa)
model = selectFurnitureInModel(model, 'furniture-chair-1')
assert.equal(selectedFurniture(model)?.category, 'chair')
assert.equal(selectFurnitureInModel(model, 'missing-object'), model)

const summary = selectedFurnitureSummary(model)
assert.equal(summary.includes('Chair'), true)
assert.equal(summary.includes('0.55 m x 0.55 m x 0.85 m'), true)
assert.equal(summary.includes('position 3.40 m, 2.04 m'), true)
assert.equal(summary.includes('rotation 0 deg'), true)

const selectedTokens = selectionVisualTokens({ selected: true })
assert.deepEqual(selectedTokens, {
  outline: true,
  scale: 1.05,
  marker: 'edge-outline',
})
assert.equal(selectionVisualTokens({ selected: false }).outline, false)

console.log('Story 4.3 furniture selection contract verified')
