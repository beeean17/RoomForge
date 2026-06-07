import { mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const scriptPath = fileURLToPath(import.meta.url)
const scriptDir = path.dirname(scriptPath)
const editorRoot = path.resolve(scriptDir, '..')
const repoRoot = path.resolve(editorRoot, '..')
const defaultManifestPath = path.join(
  editorRoot,
  'fixtures',
  'cv-evaluation',
  'manifest.example.json',
)
const defaultResultsPath = path.join(
  editorRoot,
  'fixtures',
  'cv-evaluation',
  'results.example.json',
)

export function computeCvMetrics({ manifest, results }) {
  const fixtures = arrayValue(manifest.fixtures)
  const runs = arrayValue(results.runs)
  const runByFixture = new Map(
    runs
      .map((run) => recordValue(run))
      .filter((run) => typeof run.fixtureId === 'string')
      .map((run) => [run.fixtureId, run]),
  )
  const fixtureReports = fixtures.map((fixtureValue) => {
    const fixture = recordValue(fixtureValue)
    return computeFixtureMetrics({
      fixture,
      run: runByFixture.get(fixture.fixtureId) ?? {},
    })
  })
  const aggregate = aggregateFixtureReports(fixtureReports)
  return {
    schemaVersion: 1,
    generatedAt: new Date().toISOString(),
    fixtureCount: fixtureReports.length,
    aggregate,
    fixtures: fixtureReports,
    userEditFallbackRationale:
      'Browser CV is evaluated as a suggestion layer. Missed detections, category errors, false positives, and placement/size error mean users must be able to review and edit room objects before saving confirmed layouts.',
  }
}

export function loadJsonFile(filePath) {
  return JSON.parse(readFileSync(filePath, 'utf8'))
}

export function metricValue(value, unit = undefined) {
  return { status: 'available', value, ...(unit ? { unit } : {}) }
}

export function unavailableMetric(reason) {
  return { status: 'unavailable', reason }
}

function computeFixtureMetrics({ fixture, run }) {
  const expectedObjects = arrayValue(fixture.expectedObjects).map(recordValue)
  const predictions = arrayValue(run.predictions).map(recordValue)
  const matches = matchPredictions(expectedObjects, predictions)
  const matchedExpectedIds = new Set(matches.map((match) => match.expected.objectId))
  const matchedPredictionIds = new Set(matches.map((match) => match.prediction.predictionId))
  const falsePositivePredictions = predictions.filter(
    (prediction) => !matchedPredictionIds.has(prediction.predictionId),
  )
  const missedExpectedObjects = expectedObjects.filter(
    (expected) => !matchedExpectedIds.has(expected.objectId),
  )

  return {
    fixtureId: stringValue(fixture.fixtureId, 'unknown-fixture'),
    description: optionalStringValue(fixture.description),
    expectedObjectCount: expectedObjects.length,
    predictionCount: predictions.length,
    matchedObjectCount: matches.length,
    metrics: {
      detectionRecall: detectionRecallMetric(matches, expectedObjects),
      categoryAccuracy: categoryAccuracyMetric(matches),
      falsePositiveCount: metricValue(falsePositivePredictions.length, 'count'),
      placementMeanErrorMeters: placementErrorMetric(matches),
      sizeMeanErrorMeters: sizeErrorMetric(matches),
      processingTimeMs: processingTimeMetric(run),
      userCorrectionCount: correctionCountMetric(expectedObjects),
    },
    missedExpectedObjects: missedExpectedObjects.map((item) => stringValue(item.objectId, 'unknown')),
    falsePositivePredictions: falsePositivePredictions.map((item) =>
      stringValue(item.predictionId, 'unknown'),
    ),
  }
}

function matchPredictions(expectedObjects, predictions) {
  const matches = []
  const usedPredictionIds = new Set()

  for (const expected of expectedObjects) {
    const explicit = predictions.find(
      (prediction) =>
        prediction.matchedObjectId === expected.objectId &&
        !usedPredictionIds.has(prediction.predictionId),
    )
    if (explicit) {
      usedPredictionIds.add(explicit.predictionId)
      matches.push({ expected, prediction: explicit })
      continue
    }

    const candidate = bestGreedyMatch(expected, predictions, usedPredictionIds)
    if (candidate) {
      usedPredictionIds.add(candidate.predictionId)
      matches.push({ expected, prediction: candidate })
    }
  }

  return matches
}

function bestGreedyMatch(expected, predictions, usedPredictionIds) {
  const expectedPosition = pointValue(expected.approxPositionMeters)
  let best = null
  for (const prediction of predictions) {
    if (usedPredictionIds.has(prediction.predictionId)) {
      continue
    }
    if (prediction.objectType !== expected.objectType || prediction.category !== expected.category) {
      continue
    }
    if (!expectedPosition) {
      return prediction
    }
    const predictionPosition = pointValue(prediction.positionMeters)
    const distance = predictionPosition
      ? pointDistance(expectedPosition, predictionPosition)
      : Number.POSITIVE_INFINITY
    if (!best || distance < best.distance) {
      best = { prediction, distance }
    }
  }
  return best?.prediction ?? null
}

function detectionRecallMetric(matches, expectedObjects) {
  if (expectedObjects.length === 0) {
    return unavailableMetric('No expected objects were provided.')
  }
  return metricValue(round(matches.length / expectedObjects.length), 'ratio')
}

function categoryAccuracyMetric(matches) {
  if (matches.length === 0) {
    return unavailableMetric('No matched detections were available for category comparison.')
  }
  const correct = matches.filter(
    ({ expected, prediction }) => prediction.category === expected.category,
  ).length
  return metricValue(round(correct / matches.length), 'ratio')
}

function placementErrorMetric(matches) {
  const errors = matches
    .map(({ expected, prediction }) => {
      const expectedPoint = pointValue(expected.approxPositionMeters)
      const actualPoint = pointValue(prediction.positionMeters)
      return expectedPoint && actualPoint ? pointDistance(expectedPoint, actualPoint) : null
    })
    .filter((item) => item !== null)
  if (errors.length === 0) {
    return unavailableMetric('No matched objects had both expected and predicted positions.')
  }
  return metricValue(round(mean(errors)), 'meters')
}

function sizeErrorMetric(matches) {
  const errors = matches
    .map(({ expected, prediction }) => {
      const expectedSize = pointValue(expected.approxSizeMeters)
      const actualSize = pointValue(prediction.sizeMeters)
      return expectedSize && actualSize ? pointDistance(expectedSize, actualSize) : null
    })
    .filter((item) => item !== null)
  if (errors.length === 0) {
    return unavailableMetric('No matched objects had both expected and predicted sizes.')
  }
  return metricValue(round(mean(errors)), 'meters')
}

function processingTimeMetric(run) {
  return typeof run.processingTimeMs === 'number' && Number.isFinite(run.processingTimeMs)
    ? metricValue(run.processingTimeMs, 'milliseconds')
    : unavailableMetric('No processing time was provided for this fixture run.')
}

function correctionCountMetric(expectedObjects) {
  const corrections = expectedObjects
    .map((item) => item.expectedCorrections)
    .filter((item) => Number.isInteger(item) && item >= 0)
  if (corrections.length === 0) {
    return unavailableMetric('No expected correction counts were provided.')
  }
  return metricValue(
    corrections.reduce((sum, item) => sum + item, 0),
    'count',
  )
}

function aggregateFixtureReports(reports) {
  return {
    detectionRecall: averageMetric(reports, 'detectionRecall', 'ratio'),
    categoryAccuracy: averageMetric(reports, 'categoryAccuracy', 'ratio'),
    falsePositiveCount: sumMetric(reports, 'falsePositiveCount', 'count'),
    placementMeanErrorMeters: averageMetric(reports, 'placementMeanErrorMeters', 'meters'),
    sizeMeanErrorMeters: averageMetric(reports, 'sizeMeanErrorMeters', 'meters'),
    processingTimeMs: averageMetric(reports, 'processingTimeMs', 'milliseconds'),
    userCorrectionCount: sumMetric(reports, 'userCorrectionCount', 'count'),
  }
}

function averageMetric(reports, metricName, unit) {
  const values = availableMetricValues(reports, metricName)
  if (values.length === 0) {
    return unavailableMetric(`No fixture reported ${metricName}.`)
  }
  return metricValue(round(mean(values)), unit)
}

function sumMetric(reports, metricName, unit) {
  const values = availableMetricValues(reports, metricName)
  if (values.length === 0) {
    return unavailableMetric(`No fixture reported ${metricName}.`)
  }
  return metricValue(round(values.reduce((sum, value) => sum + value, 0)), unit)
}

function availableMetricValues(reports, metricName) {
  return reports
    .map((report) => report.metrics[metricName])
    .filter((metric) => metric?.status === 'available')
    .map((metric) => metric.value)
}

function pointValue(value) {
  const point = recordValue(value)
  return typeof point.x === 'number' &&
    Number.isFinite(point.x) &&
    typeof point.y === 'number' &&
    Number.isFinite(point.y) &&
    typeof point.z === 'number' &&
    Number.isFinite(point.z)
    ? { x: point.x, y: point.y, z: point.z }
    : null
}

function pointDistance(first, second) {
  return Math.sqrt(
    (first.x - second.x) ** 2 +
      (first.y - second.y) ** 2 +
      (first.z - second.z) ** 2,
  )
}

function mean(values) {
  return values.reduce((sum, value) => sum + value, 0) / values.length
}

function round(value) {
  return Number(value.toFixed(3))
}

function recordValue(value) {
  return typeof value === 'object' && value !== null && !Array.isArray(value) ? value : {}
}

function arrayValue(value) {
  return Array.isArray(value) ? value : []
}

function stringValue(value, fallback) {
  return typeof value === 'string' && value.length > 0 ? value : fallback
}

function optionalStringValue(value) {
  return typeof value === 'string' && value.length > 0 ? value : undefined
}

function parseArgs(argv) {
  const args = {
    manifestPath: defaultManifestPath,
    resultsPath: defaultResultsPath,
    outPath: null,
  }
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index]
    const next = argv[index + 1]
    if (arg === '--manifest' && next) {
      args.manifestPath = path.resolve(process.cwd(), next)
      index += 1
    } else if (arg === '--results' && next) {
      args.resultsPath = path.resolve(process.cwd(), next)
      index += 1
    } else if (arg === '--out' && next) {
      args.outPath = path.resolve(process.cwd(), next)
      index += 1
    } else {
      throw new Error(`Unsupported argument: ${arg}`)
    }
  }
  return args
}

function runCli() {
  const args = parseArgs(process.argv.slice(2))
  const report = computeCvMetrics({
    manifest: loadJsonFile(args.manifestPath),
    results: loadJsonFile(args.resultsPath),
  })
  const serialized = `${JSON.stringify(report, null, 2)}\n`
  if (args.outPath) {
    mkdirSync(path.dirname(args.outPath), { recursive: true })
    writeFileSync(args.outPath, serialized)
    console.log(`Wrote CV metrics report to ${path.relative(repoRoot, args.outPath)}`)
  } else {
    process.stdout.write(serialized)
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === scriptPath) {
  try {
    runCli()
  } catch (error) {
    console.error(`FAIL ${error.message}`)
    process.exit(1)
  }
}
