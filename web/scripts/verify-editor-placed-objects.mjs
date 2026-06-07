import assert from 'node:assert/strict'

import {
  maxValueForField,
  placedObjectStateFromPayload,
  placedObjectTransformFields,
  transformValueForItem,
} from '../src/features/editor/editorPlacedObjects.ts'

const state = placedObjectStateFromPayload({
  selected: { objectId: 'cv-candidate-bed-1', objectType: 'furniture' },
  room: {
    floorPlan: {
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
      objectId: 'cv-candidate-bed-1',
      candidateId: 'candidate-bed-1',
      source: 'cv_candidate',
      category: 'bed',
      label: 'Detected bed',
      position: { x: 2.1, y: 2.2 },
      size: { widthMeters: 1.9, depthMeters: 1.45, heightMeters: 0.65 },
      rotationDegrees: 15,
      locked: false,
    },
    {
      objectId: 'furniture-desk-1',
      source: 'catalog',
      category: 'desk',
      label: 'Desk',
      position: { x: 4.1, y: 3.5 },
      size: { widthMeters: 1.2, depthMeters: 0.7, heightMeters: 0.75 },
      rotationDegrees: 0,
      locked: true,
    },
  ],
})

assert.ok(state)
assert.equal(state.items.length, 2)
assert.equal(state.selectedItem?.objectId, 'cv-candidate-bed-1')
assert.equal(state.counts.total, 2)
assert.equal(state.counts.cvCandidates, 1)
assert.equal(state.counts.catalog, 1)
assert.equal(state.counts.locked, 1)
assert.equal(state.counts.outsideRoom, 1)
assert.equal(state.roomBounds.widthMeters, 4.2)
assert.equal(state.roomBounds.depthMeters, 3.6)

const selected = state.selectedItem
assert.ok(selected)
assert.equal(selected.sourceLabel, 'CV candidate')
assert.equal(selected.coordinateSpace, 'meters')
assert.equal(selected.canEdit, true)
assert.equal(selected.locked, false)
assert.equal(transformValueForItem(selected, 'position-x'), 2.1)
assert.equal(transformValueForItem(selected, 'position-y'), 2.2)
assert.equal(transformValueForItem(selected, 'rotation'), 15)
assert.equal(transformValueForItem(selected, 'width'), 1.9)
assert.equal(transformValueForItem(selected, 'depth'), 1.45)
assert.equal(transformValueForItem(selected, 'height'), 0.65)

const locked = state.items.find((item) => item.objectId === 'furniture-desk-1')
assert.ok(locked)
assert.equal(locked.sourceLabel, 'Catalog')
assert.equal(locked.canEdit, false)
assert.equal(locked.canToggleLock, true)
assert.equal(locked.outsideRoom, true)

assert.equal(maxValueForField('position-x', state.roomBounds), 4.2)
assert.equal(maxValueForField('position-y', state.roomBounds), 3.6)
assert.equal(maxValueForField('rotation', state.roomBounds), 345)
assert.equal(maxValueForField('height', state.roomBounds), 3)
assert.equal(placedObjectTransformFields.length, 6)
assert.ok(placedObjectStateFromPayload({ candidateObjects: [] }) === null)

console.log('Web editor placed object contract verified')
