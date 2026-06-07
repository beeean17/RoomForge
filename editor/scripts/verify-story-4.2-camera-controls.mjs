import assert from 'node:assert/strict'

import {
  cameraSnapshotForRoom,
  shouldAnimateCamera,
} from '../src/cameraControls.ts'
import { defaultSpatialModel, roomBounds } from '../src/spatialModel.ts'

const labels = {
  reset: 'Reset view',
  fit: 'Fit-to-room',
  top: 'Top view',
  front: 'Front view',
  corner: 'Corner view',
  eye: 'Eye-level view',
}

const model = {
  ...defaultSpatialModel(),
  viewMode: '3d',
  selected: { objectId: 'chair-1', objectType: 'furniture' },
  hasUnsavedChanges: true,
  room: {
    ...defaultSpatialModel().room,
    heightMeters: 2.8,
    floorPlan: {
      floorPlanId: 'floor-plan-camera',
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
      label: 'Chair',
      size: { widthMeters: 0.5, depthMeters: 0.5, heightMeters: 0.9 },
      position: { x: 1.2, y: 1.2 },
      rotationDegrees: 0,
      color: '#2563eb',
    },
  ],
}

const before = JSON.stringify(model)
const snapshots = Object.fromEntries(
  Object.keys(labels).map((action) => [
    action,
    cameraSnapshotForRoom({
      action,
      bounds: roomBounds(model),
      roomHeightMeters: model.room.heightMeters,
      fovDegrees: 42,
      labels,
    }),
  ]),
)

assert.equal(JSON.stringify(model), before, 'camera presets must not mutate shared spatial state')
assert.equal(snapshots.reset.label, 'Reset view')
assert.equal(snapshots.fit.label, 'Fit-to-room')
assert.equal(snapshots.top.up.z, -1)
assert.equal(snapshots.front.position.z > snapshots.eye.position.z, true)
assert.equal(snapshots.corner.position.x, snapshots.corner.position.z)
assert.equal(snapshots.fit.position.x < snapshots.corner.position.x, true)
assert.equal(snapshots.eye.position.y, 1.6)

assert.equal(shouldAnimateCamera({ reducedMotion: false, animate: true }), true)
assert.equal(shouldAnimateCamera({ reducedMotion: true, animate: true }), false)
assert.equal(shouldAnimateCamera({ reducedMotion: false, animate: false }), false)

console.log('Story 4.2 camera controls contract verified')
