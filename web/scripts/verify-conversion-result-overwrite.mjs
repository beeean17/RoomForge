import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const persistenceSource = readFileSync(
  new URL('../src/features/editor/editorEventPersistence.ts', import.meta.url),
  'utf8',
)
const sceneResultsSource = readFileSync(
  new URL('../src/features/editor/editorSceneUnderstandingResults.ts', import.meta.url),
  'utf8',
)
const firestoreRulesSource = readFileSync(new URL('../../app/firestore.rules', import.meta.url), 'utf8')

assert.match(
  persistenceSource,
  /const resultId = 'latest'/,
  'Conversion persistence should use a stable latest document id for overwrite semantics.',
)
assert.doesNotMatch(
  persistenceSource,
  /opencv-\$\{message\.requestId/,
  'OpenCV reruns should not create a new request-scoped result document.',
)
assert.match(
  persistenceSource,
  /'projects', project\.id, 'opencv_results', 'latest'/,
  'OpenCV persistence should write projects/{projectId}/opencv_results/latest.',
)
assert.match(
  persistenceSource,
  /'projects', project\.id, 'scene_understanding_results', resultId/,
  'Scene understanding persistence should write the stable latest result document.',
)
assert.match(
  persistenceSource,
  /OpenCV result overwritten/,
  'OpenCV persistence feedback should describe overwrite behavior.',
)
assert.match(
  persistenceSource,
  /Scene understanding result overwritten/,
  'Scene understanding persistence feedback should describe overwrite behavior.',
)
assert.match(
  persistenceSource,
  /message\.type === 'roomforge\.layout\.saved'/,
  'Editor layout save events should be persisted by the web host.',
)
assert.match(
  persistenceSource,
  /'projects', project\.id, 'layouts', layoutId/,
  'Layout persistence should write projects/{projectId}/layouts/latest.',
)
assert.match(
  persistenceSource,
  /const layoutId = 'latest'/,
  'Layout persistence should use stable latest document overwrite semantics.',
)
assert.match(
  persistenceSource,
  /latest_layout_id: layoutId/,
  'Project metadata should point to the latest synced layout.',
)
assert.match(
  sceneResultsSource,
  /'projects', project\.id, 'scene_understanding_results', 'latest'/,
  'Scene understanding loading should prefer the latest overwrite document.',
)
assert.match(
  firestoreRulesSource,
  /resultId == 'latest'\s+\|\|\s+request\.resource\.data\.capture_session_id == resource\.data\.capture_session_id/,
  'Firestore rules should allow scene latest overwrites across capture sessions.',
)
assert.match(
  firestoreRulesSource,
  /'structural_fixture_objects'/,
  'Firestore layout rules should allow synced window and door objects.',
)

console.log('Conversion result overwrite contract verified')
