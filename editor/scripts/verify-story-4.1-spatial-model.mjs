import assert from 'node:assert/strict'

import { spatialModelFromBridgePayload, spatialSummary } from '../src/spatialModel.ts'

const metricScene = {
  scene: {
    sceneId: 'story-4-1-scene',
    coordinateSpace: 'meters',
    unit: 'meters',
    viewMode: '2d',
    selected: { objectId: 'chair-1', objectType: 'furniture' },
    hasUnsavedChanges: true,
    scale: { metersPerSceneUnit: 0.25 },
    room: {
      objectId: 'room-shell',
      label: 'Metric room shell',
      heightMeters: 2.8,
      floorPlan: {
        floorPlanId: 'floor-plan-4-1',
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
    furniture: [
      {
        objectId: 'chair-1',
        category: 'chair',
        label: 'Desk chair',
        size: { widthMeters: 0.5, depthMeters: 0.5, heightMeters: 0.9 },
        position: { x: 1.25, y: 1.4 },
        rotationDegrees: 15,
        color: '#2563eb',
      },
    ],
  },
}

const model2d = spatialModelFromBridgePayload(metricScene)
const model3d = spatialModelFromBridgePayload({
  scene: { ...metricScene.scene, viewMode: '3d' },
})

for (const model of [model2d, model3d]) {
  assert.equal(model.coordinateSpace, 'meters')
  assert.equal(model.unit, 'meters')
  assert.equal(model.sceneId, 'story-4-1-scene')
  assert.equal(model.room.floorPlan.floorPlanId, 'floor-plan-4-1')
  assert.equal(model.room.floorPlan.metricGeometry.coordinateSpace, 'meters')
  assert.equal(model.room.floorPlan.metricGeometry.points[2].x, 5)
  assert.equal(model.room.floorPlan.metricGeometry.points[2].y, 3)
  assert.equal(model.scale.metersPerSceneUnit, 0.25)
  assert.equal(model.hasUnsavedChanges, true)
  assert.deepEqual(model.selected, { objectId: 'chair-1', objectType: 'furniture' })
  assert.equal(model.furniture[0].objectId, 'chair-1')
  assert.equal(model.furniture[0].position.x, 1.25)
}

assert.equal(model2d.viewMode, '2d')
assert.equal(model3d.viewMode, '3d')
assert.equal(spatialSummary(model3d).includes('selected chair-1'), true)
assert.equal(spatialSummary(model3d).includes('Unsaved changes'), true)

const invalidPixelModel = spatialModelFromBridgePayload({
  scene: {
    ...metricScene.scene,
    floorPlan: undefined,
    room: {
      ...metricScene.scene.room,
      floorPlan: {
        floorPlanId: 'pixel-plan',
        metricGeometry: {
          coordinateSpace: 'image_pixels',
          points: [
            { x: 0, y: 0 },
            { x: 640, y: 0 },
            { x: 640, y: 480 },
          ],
        },
      },
    },
  },
})

assert.equal(invalidPixelModel.room.floorPlan.floorPlanId, 'demo-floor-plan')
assert.equal(invalidPixelModel.room.floorPlan.metricGeometry.coordinateSpace, 'meters')

console.log('Story 4.1 spatial model contract verified')
