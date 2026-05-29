import assert from 'node:assert/strict'
import { performance } from 'node:perf_hooks'

import {
  addFurnitureToModel,
  editFurnitureObject,
  editSelectedFurnitureInModel,
  furnitureDefaults,
  selectedFurniture,
} from '../src/furnitureModel.ts'
import { defaultSpatialModel } from '../src/spatialModel.ts'

let model = {
  ...defaultSpatialModel(),
  viewMode: '2d',
  room: {
    ...defaultSpatialModel().room,
    floorPlan: {
      floorPlanId: 'floor-plan-editing',
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

for (let index = 0; index < 20; index += 1) {
  const item = furnitureDefaults({
    category: index % 3 === 0 ? 'chair' : index % 3 === 1 ? 'table' : 'sofa',
    id: `furniture-${index}`,
    model,
  })
  model = addFurnitureToModel(model, item)
}

model = { ...model, selected: { objectId: 'furniture-0', objectType: 'furniture' } }
const selectedBefore = selectedFurniture(model)
assert.equal(selectedBefore?.objectId, 'furniture-0')

const moved = editSelectedFurnitureInModel(model, 'move-right').model
assert.equal(selectedFurniture(moved)?.position.x, Number((selectedBefore.position.x + 0.1).toFixed(2)))
assert.deepEqual(moved.selected, model.selected)
assert.equal(moved.viewMode, '2d')

const rotated = editSelectedFurnitureInModel({ ...moved, viewMode: '3d' }, 'rotate-right').model
assert.equal(selectedFurniture(rotated)?.rotationDegrees, 15)
assert.equal(rotated.viewMode, '3d')
assert.deepEqual(rotated.room, model.room)

const wider = editSelectedFurnitureInModel(rotated, 'wider').model
assert.equal(selectedFurniture(wider)?.size.widthMeters, 0.65)
const deeper = editSelectedFurnitureInModel(wider, 'deeper').model
assert.equal(selectedFurniture(deeper)?.size.depthMeters, 0.65)

const locked = editSelectedFurnitureInModel(deeper, 'toggle-lock').model
const blocked = editSelectedFurnitureInModel(locked, 'move-left')
assert.equal(blocked.blockedByLock, true)
assert.equal(blocked.changed, false)
assert.equal(selectedFurniture(blocked.model)?.position.x, selectedFurniture(locked)?.position.x)

const deleted = editSelectedFurnitureInModel(locked, 'delete')
assert.equal(deleted.deleted, true)
assert.equal(deleted.model.furniture.some((item) => item.objectId === 'furniture-0'), false)
assert.deepEqual(deleted.model.selected, { objectId: model.room.objectId, objectType: 'room' })

const startedAt = performance.now()
let perfModel = model
for (const action of ['move-up', 'move-down', 'move-left', 'move-right', 'rotate-left', 'rotate-right', 'narrower', 'wider', 'shallower', 'deeper']) {
  perfModel = editSelectedFurnitureInModel(perfModel, action).model
}
const elapsedMs = performance.now() - startedAt
assert.equal(elapsedMs < 100, true, `MVP-scale edit loop took ${elapsedMs.toFixed(2)} ms`)

assert.equal(editFurnitureObject(selectedBefore, 'narrower').size.widthMeters, 0.45)
assert.equal(editFurnitureObject({ ...selectedBefore, size: { ...selectedBefore.size, widthMeters: 0.2 } }, 'narrower').size.widthMeters, 0.2)

console.log('Story 4.4 furniture editing contract verified')
