import assert from 'node:assert/strict'

import { spatialModelFromBridgePayload, spatialSummary } from '../src/spatialModel.ts'

function scenePayload(viewMode) {
  return {
    scene: {
      sceneId: `loaded-${viewMode}-scene`,
      coordinateSpace: 'meters',
      unit: 'meters',
      viewMode,
      selected: { objectId: 'chair-1', objectType: 'furniture' },
      hasUnsavedChanges: false,
      scale: { metersPerSceneUnit: 1 },
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
      furniture: [
        {
          objectId: 'chair-1',
          category: 'chair',
          label: 'Desk chair',
          size: { widthMeters: 0.6, depthMeters: 0.7, heightMeters: 0.9 },
          position: { x: 1.2, y: 2.4 },
          rotationDegrees: 15,
          color: '#64748b',
          locked: false,
        },
      ],
    },
  }
}

for (const viewMode of ['2d', '3d']) {
  const model = spatialModelFromBridgePayload(scenePayload(viewMode))

  assert.equal(model.sceneId, `loaded-${viewMode}-scene`)
  assert.equal(model.viewMode, viewMode)
  assert.equal(model.coordinateSpace, 'meters')
  assert.equal(model.unit, 'meters')
  assert.deepEqual(model.selected, { objectId: 'chair-1', objectType: 'furniture' })
  assert.equal(model.hasUnsavedChanges, false)
  assert.equal(model.room.heightMeters, 2.7)
  assert.equal(model.room.floorPlan.floorPlanId, 'floor-plan-1')
  assert.equal(model.room.floorPlan.metricGeometry.coordinateSpace, 'meters')
  assert.equal(model.room.floorPlan.metricGeometry.points.length, 4)
  assert.equal(model.furniture.length, 1)
  assert.equal(model.furniture[0].objectId, 'chair-1')
  assert.equal(model.furniture[0].category, 'chair')
  assert.equal(model.furniture[0].size.widthMeters, 0.6)
  assert.equal(model.furniture[0].size.depthMeters, 0.7)
  assert.equal(model.furniture[0].size.heightMeters, 0.9)
  assert.equal(model.furniture[0].position.x, 1.2)
  assert.equal(model.furniture[0].position.y, 2.4)
  assert.equal(model.furniture[0].rotationDegrees, 15)
  assert.equal(model.furniture[0].color, '#64748b')
  assert.equal(spatialSummary(model).startsWith(viewMode.toUpperCase()), true)
}

console.log('Story 5.2 load layout spatial restoration contract verified')
