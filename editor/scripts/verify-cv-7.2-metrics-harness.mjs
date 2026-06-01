import assert from 'node:assert/strict'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

import {
  computeCvMetrics,
  loadJsonFile,
} from './cv-metrics-harness.mjs'

const scriptDir = path.dirname(fileURLToPath(import.meta.url))
const editorRoot = path.resolve(scriptDir, '..')

const report = computeCvMetrics({
  manifest: loadJsonFile(
    path.join(editorRoot, 'fixtures', 'cv-evaluation', 'manifest.example.json'),
  ),
  results: loadJsonFile(
    path.join(editorRoot, 'fixtures', 'cv-evaluation', 'results.example.json'),
  ),
})

assert.equal(report.fixtureCount, 1)
assert.equal(report.aggregate.detectionRecall.status, 'available')
assert.equal(report.aggregate.detectionRecall.value, 1)
assert.equal(report.aggregate.categoryAccuracy.value, 0.667)
assert.equal(report.aggregate.falsePositiveCount.value, 1)
assert.equal(report.aggregate.placementMeanErrorMeters.value, 0.174)
assert.equal(report.aggregate.sizeMeanErrorMeters.value, 0.108)
assert.equal(report.aggregate.processingTimeMs.value, 842)
assert.equal(report.aggregate.userCorrectionCount.value, 3)
assert.ok(report.userEditFallbackRationale.includes('review and edit'))

const fixture = report.fixtures[0]
assert.equal(fixture.matchedObjectCount, 3)
assert.deepEqual(fixture.falsePositivePredictions, ['pred-extra-chair'])
assert.deepEqual(fixture.missedExpectedObjects, [])

const unavailableReport = computeCvMetrics({
  manifest: {
    schemaVersion: 1,
    fixtures: [
      {
        fixtureId: 'partial-ground-truth',
        expectedObjects: [
          {
            objectId: 'bed-1',
            objectType: 'furniture',
            category: 'bed',
          },
        ],
      },
    ],
  },
  results: {
    schemaVersion: 1,
    runs: [
      {
        fixtureId: 'partial-ground-truth',
        predictions: [
          {
            predictionId: 'pred-bed-1',
            objectType: 'furniture',
            category: 'bed',
          },
        ],
      },
    ],
  },
})

assert.equal(unavailableReport.aggregate.detectionRecall.value, 1)
assert.equal(unavailableReport.aggregate.categoryAccuracy.value, 1)
assert.equal(unavailableReport.aggregate.placementMeanErrorMeters.status, 'unavailable')
assert.equal(unavailableReport.aggregate.sizeMeanErrorMeters.status, 'unavailable')
assert.equal(unavailableReport.aggregate.processingTimeMs.status, 'unavailable')
assert.equal(unavailableReport.aggregate.userCorrectionCount.status, 'unavailable')

console.log('CV-7.2 metrics harness contract verified')
