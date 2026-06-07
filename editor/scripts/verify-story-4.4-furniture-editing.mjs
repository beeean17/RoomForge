import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { performance } from 'node:perf_hooks'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

import {
  addFurnitureToModel,
  editFurnitureObject,
  editSelectedFurnitureInModel,
  furnitureDefaults,
  selectedFurniture,
} from '../src/furnitureModel.ts'
import {
  furnitureMagneticSnapPosition,
  signedPlanAngleDeltaDegrees,
  snappedRotationDegrees,
} from '../src/furniturePlacement.ts'
import { defaultSpatialModel } from '../src/spatialModel.ts'

const rootDir = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const runtimeSource = readFileSync(resolve(rootDir, 'src/runtime.ts'), 'utf8')
const cssSource = readFileSync(resolve(rootDir, 'src/style.css'), 'utf8')

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
const flippedHorizontal = editSelectedFurnitureInModel(deeper, 'flip-horizontal').model
assert.equal(selectedFurniture(flippedHorizontal)?.flipX, true)
const flippedVertical = editSelectedFurnitureInModel(flippedHorizontal, 'flip-vertical').model
assert.equal(selectedFurniture(flippedVertical)?.flipY, true)

const locked = editSelectedFurnitureInModel(flippedVertical, 'toggle-lock').model
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
for (const action of ['move-up', 'move-down', 'move-left', 'move-right', 'rotate-left', 'rotate-right', 'flip-horizontal', 'flip-vertical', 'narrower', 'wider', 'shallower', 'deeper']) {
  perfModel = editSelectedFurnitureInModel(perfModel, action).model
}
const elapsedMs = performance.now() - startedAt
assert.equal(elapsedMs < 100, true, `MVP-scale edit loop took ${elapsedMs.toFixed(2)} ms`)

assert.equal(editFurnitureObject(selectedBefore, 'narrower').size.widthMeters, 0.45)
assert.equal(editFurnitureObject({ ...selectedBefore, size: { ...selectedBefore.size, widthMeters: 0.2 } }, 'narrower').size.widthMeters, 0.2)

const placementItem = {
  size: { widthMeters: 2, depthMeters: 0.8, heightMeters: 0.7 },
  rotationDegrees: 0,
}
const placementBounds = { widthMeters: 5, depthMeters: 3 }
assert.deepEqual(
  furnitureMagneticSnapPosition({
    item: placementItem,
    position: { x: -0.7, y: 1.2 },
    bounds: placementBounds,
    snapEnabled: true,
  }),
  { x: -0.7, y: 1.2 },
  'furniture can be dragged freely outside the room when it is not near a wall',
)
assert.deepEqual(
  furnitureMagneticSnapPosition({
    item: placementItem,
    position: { x: 0.94, y: 1.2 },
    bounds: placementBounds,
    snapEnabled: true,
  }),
  { x: 1, y: 1.2 },
  'furniture edge magnet-snaps to the left wall when it is very close',
)
assert.deepEqual(
  furnitureMagneticSnapPosition({
    item: placementItem,
    position: { x: 2.5, y: 2.56 },
    bounds: placementBounds,
    snapEnabled: true,
  }),
  { x: 2.5, y: 2.6 },
  'furniture edge magnet-snaps to the back wall when it is very close',
)
assert.deepEqual(
  furnitureMagneticSnapPosition({
    item: placementItem,
    position: { x: 0.94, y: 1.2 },
    bounds: placementBounds,
    snapEnabled: false,
  }),
  { x: 0.94, y: 1.2 },
  'wall magnetic snapping follows the snap toggle',
)
assert.equal(signedPlanAngleDeltaDegrees(-90, 0), 90)
assert.equal(signedPlanAngleDeltaDegrees(170, -170), 20)
assert.equal(snappedRotationDegrees(0 - signedPlanAngleDeltaDegrees(-90, 0), true), 270)

assert.ok(
  runtimeSource.includes('role="dialog" aria-modal="false" aria-labelledby="selected-furniture-panel-title"'),
  'selected object click should open a top-left size modal, not only the right inspector',
)
assert.ok(
  runtimeSource.includes('data-selected-size-field="width"') &&
    runtimeSource.includes('data-selected-size-field="depth"') &&
    runtimeSource.includes('data-selected-size-field="height"'),
  'selected object modal should expose width/depth/height number inputs',
)
assert.ok(
  runtimeSource.includes('const panelVisible = selected !== null || fixture !== null'),
  'selected object modal should stay visible whenever an object is selected',
)
assert.ok(
  runtimeSource.includes('setSelectedSizeControl') &&
    runtimeSource.includes('updateSelectedFurnitureTransform(field, input.valueAsNumber)'),
  'selected object modal size inputs should update the selected object transform',
)
assert.ok(
  runtimeSource.includes('function scheduleLayoutAutosave()') &&
    runtimeSource.includes('scheduleLayoutAutosave()') &&
    runtimeSource.includes("type: 'roomforge.layout.saved'"),
  'furniture edits should schedule layout autosave so project data syncs after changes',
)
assert.ok(cssSource.includes('.selected-furniture-panel') && cssSource.includes('z-index: 8;'))

console.log('Story 4.4 furniture editing contract verified')
