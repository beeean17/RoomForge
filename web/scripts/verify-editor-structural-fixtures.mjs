import assert from 'node:assert/strict'

import {
  structuralFixtureStateFromPayload,
} from '../src/features/editor/editorStructuralFixtures.ts'

const state = structuralFixtureStateFromPayload({
  selected: { objectId: 'fixture-candidate-window-1', objectType: 'fixture' },
  candidateObjects: [
    {
      candidateId: 'candidate-window-1',
      objectType: 'structural_fixture',
      category: 'window',
      label: 'Detected window',
      sourceImageRole: 'left_wall',
      confidenceScore: 0.88,
      reviewState: 'new',
    },
    {
      candidateId: 'candidate-door-1',
      objectType: 'structural_fixture',
      category: 'door',
      sourceImageRole: 'front_wall',
      confidenceScore: 0.54,
      reviewState: 'review_required',
    },
    {
      candidateId: 'candidate-sofa-1',
      objectType: 'furniture',
      category: 'sofa',
      confidenceScore: 0.9,
      reviewState: 'new',
    },
  ],
  structuralFixtures: [
    {
      fixtureId: 'fixture-candidate-window-1',
      candidateId: 'candidate-window-1',
      category: 'window',
      label: 'Detected window',
      wallId: 'left-wall',
      position: { x: 1.2, y: 1.4, z: 0 },
      size: { x: 1.1, y: 1, z: 0.1 },
      rotationDegrees: 270,
      confidenceScore: 0.88,
      locked: false,
    },
  ],
})

assert.ok(state)
assert.equal(state.candidates.length, 2)
assert.equal(state.fixtures.length, 1)
assert.equal(state.selectedFixture?.fixtureId, 'fixture-candidate-window-1')
assert.equal(state.counts.candidates, 2)
assert.equal(state.counts.needsReview, 1)
assert.equal(state.counts.placed, 1)
assert.equal(state.counts.rejected, 0)
assert.equal(state.counts.selected, 1)

const windowCandidate = state.candidates.find((candidate) => candidate.candidateId === 'candidate-window-1')
assert.ok(windowCandidate)
assert.equal(windowCandidate.reviewLabel, 'Placed')
assert.equal(windowCandidate.canPlace, false)
assert.equal(windowCandidate.sourceLabel, 'left_wall')

const doorCandidate = state.candidates.find((candidate) => candidate.candidateId === 'candidate-door-1')
assert.ok(doorCandidate)
assert.equal(doorCandidate.reviewLabel, 'Needs review')
assert.equal(doorCandidate.canPlace, true)

const fixture = state.selectedFixture
assert.ok(fixture)
assert.equal(fixture.sourceLabel, 'CV candidate')
assert.equal(fixture.confidenceLabel, '88%')
assert.equal(fixture.wallId, 'left-wall')
assert.equal(fixture.offsetMeters, 1.2)
assert.equal(fixture.widthMeters, 1.1)
assert.equal(fixture.heightMeters, 1)
assert.equal(fixture.canEdit, true)

assert.equal(structuralFixtureStateFromPayload({ furniture: [] }), null)

console.log('Web editor structural fixture contract verified')

