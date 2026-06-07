import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const scriptDir = path.dirname(fileURLToPath(import.meta.url))
const repoRoot = path.resolve(scriptDir, '..', '..')
const decisionGatePath = path.join(
  repoRoot,
  '_bmad-output',
  'planning-artifacts',
  'cv-provider-decision-gate.md',
)
const metricsReportPath = path.join(
  repoRoot,
  '_bmad-output',
  'implementation-artifacts',
  'cv-7-2-metrics-report-2026-06-02.json',
)
const dependencyFiles = [
  'package.json',
  'editor/package.json',
  'app/pubspec.yaml',
]
const forbiddenRuntimePatterns = [
  /sam-?3/i,
  /segment-anything/i,
  /onnxruntime/i,
  /tensorflow/i,
  /torch/i,
  /cuda/i,
  /vertexai/i,
  /google-cloud-aiplatform/i,
  /cloud-run-gpu/i,
  /transformers/i,
]

const gate = readFileSync(decisionGatePath, 'utf8')
assert.match(gate, /Current decision: do not deploy Cloud GPU yet\./)
assert.match(gate, /Detection recall/)
assert.match(gate, /0\.75/)
assert.match(gate, /Category accuracy/)
assert.match(gate, /0\.70/)
assert.match(gate, /Recommend SAM 3 \/ Cloud GPU When/)
assert.match(gate, /Provider Contract Reuse/)
assert.match(gate, /No new persisted reconstruction statuses/)
assert.match(gate, /The lightweight API server does not run heavy GPU inference/)

const metricsReport = JSON.parse(readFileSync(metricsReportPath, 'utf8'))
assert.equal(metricsReport.aggregate.detectionRecall.status, 'available')
assert.equal(metricsReport.aggregate.categoryAccuracy.value, 0.667)
assert.ok(metricsReport.userEditFallbackRationale.includes('review and edit'))

for (const file of dependencyFiles) {
  const content = readFileSync(path.join(repoRoot, file), 'utf8')
  for (const pattern of forbiddenRuntimePatterns) {
    assert.equal(
      pattern.test(content),
      false,
      `${file} must not add SAM/Cloud GPU runtime dependency matching ${pattern}`,
    )
  }
}

console.log('CV-7.3 provider decision gate verified')
