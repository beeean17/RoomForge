import assert from 'node:assert/strict'

import {
  confirmationHandoffStateFromPayload,
} from '../src/features/editor/editorConfirmationHandoff.ts'

const state = confirmationHandoffStateFromPayload({
  selected: { objectId: 'fixture-window-1', objectType: 'fixture' },
  furniture: [
    {
      objectId: 'furniture-bed-1',
      candidateId: 'candidate-bed-1',
      category: 'bed',
      label: 'Detected bed',
    },
    {
      objectId: 'furniture-desk-1',
      category: 'desk',
      label: 'Desk',
    },
  ],
  structuralFixtures: [
    {
      fixtureId: 'fixture-window-1',
      candidateId: 'candidate-window-1',
      category: 'window',
      label: 'Window',
    },
  ],
  confirmedObjects: [
    {
      objectId: 'furniture-bed-1',
      objectType: 'furniture',
      category: 'bed',
      label: 'Detected bed',
      confirmedAt: '2026-06-07T00:00:00.000Z',
    },
  ],
})

assert.ok(state)
assert.equal(state.placedItems.length, 3)
assert.equal(state.confirmedItems.length, 1)
assert.equal(state.selectedItem?.objectId, 'fixture-window-1')
assert.equal(state.selectedItem?.objectType, 'structural_fixture')
assert.equal(state.selectedItem?.confirmed, false)
assert.equal(state.counts.placed, 3)
assert.equal(state.counts.confirmed, 1)
assert.equal(state.counts.unconfirmed, 2)
assert.equal(state.counts.selectedConfirmed, 0)
assert.equal(state.canConfirmSelected, true)
assert.equal(state.canConfirmAll, true)

const bed = state.placedItems.find((item) => item.objectId === 'furniture-bed-1')
assert.ok(bed)
assert.equal(bed.confirmed, true)
assert.equal(bed.sourceLabel, 'CV candidate')

const desk = state.placedItems.find((item) => item.objectId === 'furniture-desk-1')
assert.ok(desk)
assert.equal(desk.confirmed, false)
assert.equal(desk.sourceLabel, 'Catalog')

const noPlaced = confirmationHandoffStateFromPayload({ confirmedObjects: [] })
assert.ok(noPlaced)
assert.equal(noPlaced.canConfirmAll, false)

assert.equal(confirmationHandoffStateFromPayload({ candidateObjects: [] }), null)

console.log('Web editor confirmation handoff contract verified')
