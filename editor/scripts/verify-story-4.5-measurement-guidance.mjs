import assert from 'node:assert/strict'

import {
  furnitureOutsideRoom,
  measurementSummaryForModel,
  placementWarningForModel,
} from '../src/measurementGuidance.ts'
import { defaultSpatialModel } from '../src/spatialModel.ts'

const insideChair = {
  objectId: 'chair-inside',
  category: 'chair',
  label: 'Chair',
  size: { widthMeters: 0.55, depthMeters: 0.55, heightMeters: 0.85 },
  position: { x: 2.5, y: 1.5 },
  rotationDegrees: 0,
  color: '#64748b',
}

const outsideSofa = {
  objectId: 'sofa-outside',
  category: 'sofa',
  label: 'Sofa',
  size: { widthMeters: 1.8, depthMeters: 0.85, heightMeters: 0.82 },
  position: { x: 4.75, y: 2.8 },
  rotationDegrees: 0,
  color: '#8b6f61',
}

const model = {
  ...defaultSpatialModel(),
  room: {
    ...defaultSpatialModel().room,
    heightMeters: 2.7,
    floorPlan: {
      floorPlanId: 'floor-plan-measurement',
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
  furniture: [insideChair, outsideSofa],
}

assert.equal(
  measurementSummaryForModel({ model, roomLabel: 'Room' }),
  'Room 5.00 m x 3.00 m x 2.70 m',
)
assert.equal(
  measurementSummaryForModel({
    model,
    selected: insideChair,
    selectedLabel: 'Chair',
  }),
  'Chair: 0.55 m x 0.55 m; room 5.00 m x 3.00 m',
)

assert.equal(furnitureOutsideRoom(insideChair, { widthMeters: 5, depthMeters: 3 }), false)
assert.equal(furnitureOutsideRoom(outsideSofa, { widthMeters: 5, depthMeters: 3 }), true)

const warning = placementWarningForModel({ model })
assert.equal(
  warning,
  'Warning: Sofa is outside the 5.00 m x 3.00 m room bounds. Move or resize it inside the room before saving.',
)
assert.equal(warning.includes('Warning:'), true)
assert.equal(warning.includes('Move or resize'), true)
assert.equal(warning.includes('5.00 m x 3.00 m'), true)

const safeModel = { ...model, furniture: [insideChair] }
assert.equal(placementWarningForModel({ model: safeModel }), null)

console.log('Story 4.5 measurement and placement guidance contract verified')
