import assert from 'node:assert/strict'

import {
  candidateReviewCategoryOptions,
  candidateReviewStateFromPayload,
} from '../src/features/editor/editorCandidateReview.ts'

const state = candidateReviewStateFromPayload({
  candidateObjects: [
    {
      candidateId: 'candidate-bed-1',
      objectType: 'furniture',
      category: 'bed',
      label: 'Detected bed',
      sourceImageRole: 'front_wall',
      coordinateSpace: 'image_pixels',
      confidenceScore: 0.52,
      reviewState: 'review_required',
    },
    {
      candidateId: 'candidate-chair-1',
      objectType: 'furniture',
      category: 'chair',
      sourceEvidence: [
        { candidateId: 'candidate-chair-1', sourceImageRole: 'overview' },
        { candidateId: 'candidate-chair-1', sourceImageRole: 'right_wall' },
      ],
      coordinateSpace: 'image_pixels',
      confidenceScore: 0.91,
      reviewState: 'new',
    },
    {
      candidateId: 'candidate-window-1',
      objectType: 'structural_fixture',
      category: 'window',
      sourceImageRole: 'left_wall',
      coordinateSpace: 'image_pixels',
      confidenceScore: 0.88,
      reviewState: 'rejected',
    },
  ],
  placedObjects: [
    {
      objectId: 'cv-candidate-chair-1',
      candidateId: 'candidate-chair-1',
      objectType: 'furniture',
      category: 'chair',
      rotationDegrees: 0,
      locked: false,
    },
  ],
  confirmedObjects: [
    {
      objectId: 'confirmed-chair-1',
      candidateId: 'candidate-chair-1',
      objectType: 'furniture',
      category: 'chair',
      rotationDegrees: 0,
      locked: false,
    },
  ],
})

assert.ok(state)
assert.equal(state.items.length, 3)
assert.equal(state.counts.candidates, 3)
assert.equal(state.counts.needsReview, 1)
assert.equal(state.counts.placed, 1)
assert.equal(state.counts.rejected, 1)
assert.equal(state.counts.confirmed, 1)

const bed = state.items.find((item) => item.candidateId === 'candidate-bed-1')
assert.ok(bed)
assert.equal(bed.reviewLabel, 'Needs review')
assert.equal(bed.needsReview, true)
assert.equal(bed.canPlace, true)
assert.equal(bed.canReject, true)
assert.equal(bed.sourceLabel, 'front_wall')

const chair = state.items.find((item) => item.candidateId === 'candidate-chair-1')
assert.ok(chair)
assert.equal(chair.reviewLabel, 'Placed')
assert.equal(chair.canPlace, false)
assert.equal(chair.sourceLabel, 'overview, right_wall (2 sources)')

const window = state.items.find((item) => item.candidateId === 'candidate-window-1')
assert.ok(window)
assert.equal(window.reviewLabel, 'Rejected')
assert.equal(window.canPlace, false)
assert.equal(window.canReject, false)
assert.equal(window.canChangeCategory, false)

const emptyState = candidateReviewStateFromPayload({ candidateObjects: [] })
assert.ok(emptyState)
assert.equal(emptyState.items.length, 0)

assert.ok(candidateReviewCategoryOptions.includes('sofa'))
assert.ok(candidateReviewCategoryOptions.includes('dresser'))
assert.ok(candidateReviewCategoryOptions.includes('nightstand'))
assert.ok(candidateReviewCategoryOptions.includes('window'))

console.log('Web editor candidate review contract verified')
