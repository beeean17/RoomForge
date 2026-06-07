import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const workerSource = readFileSync(
  new URL('../src/features/reconstruction/openCvConversionWorker.ts', import.meta.url),
  'utf8',
)
const statusPageSource = readFileSync(
  new URL('../src/features/reconstruction/ReconstructionStatusPage.tsx', import.meta.url),
  'utf8',
)
const sourceImageSource = readFileSync(
  new URL('../src/features/editor/editorSourceImages.ts', import.meta.url),
  'utf8',
)

assert.match(
  workerSource,
  /let workerErrorTimer: number \| undefined/,
  'OpenCV worker host should track delayed worker.onerror handling.',
)
assert.match(
  workerSource,
  /event\.preventDefault\(\)/,
  'Worker error events should not immediately short-circuit the worker failure message path.',
)
assert.match(
  workerSource,
  /workerErrorTimer = window\.setTimeout\(\(\) => \{/,
  'Worker error events should be delayed so workerFailed/runtimeFailed details can arrive first.',
)
assert.match(
  workerSource,
  /workerFailureReported \|\| disposed \|\| runId !== runIdRef\.current/,
  'Delayed worker errors should not overwrite a detailed worker failure message or stale run.',
)
assert.match(
  statusPageSource,
  /const failedWithStoredData = conversion\.status === 'failed' && hasExistingConversionData/,
  'Conversion failure state should detect recoverable stored data.',
)
assert.match(
  statusPageSource,
  /저장된 데이터로 에디터 열기/,
  'Recoverable conversion failures should let users open the saved editor data.',
)
assert.match(
  statusPageSource,
  /completedOrRecoverable \? routes\.editor\(projectId\) : routes\.source\(projectId\)/,
  'Recoverable conversion failures should route to the editor instead of the source page.',
)
assert.match(
  statusPageSource,
  /const conversionProject = useMemo\(/,
  'Conversion project override should be memoized so source image loading does not restart every render.',
)
assert.match(
  sourceImageSource,
  /const sourceImageDataUrlCache = new Map<string, Promise<string>>\(\)/,
  'Editor source image loading should cache in-flight Storage downloads by path.',
)
assert.match(
  sourceImageSource,
  /sourceImageDataUrlCache\.get\(storagePath\)/,
  'Repeated source image loads should reuse the existing Storage download promise.',
)

console.log('Reconstruction worker recovery contract verified')
