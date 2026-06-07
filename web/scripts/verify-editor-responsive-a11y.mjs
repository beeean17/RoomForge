import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'

const pageSource = await readFile(new URL('../src/features/editor/EditorPage.tsx', import.meta.url), 'utf8')
const cssSource = await readFile(new URL('../src/design/globals.css', import.meta.url), 'utf8')

for (const marker of [
  'className="candidate-review-counts" aria-label="CV candidate counts" aria-live="polite"',
  'className="placed-object-counts" aria-label="Placed object counts" aria-live="polite"',
  'className="fixture-review-counts" aria-label="Structural fixture counts" aria-live="polite"',
  'className="confirmation-counts" aria-label="Confirmation handoff counts" aria-live="polite"',
  "{ category: 'bed', label: '침대' }",
  "{ category: 'chair', label: '의자' }",
  "{ category: 'wardrobe', label: '옷장' }",
  '소스 이미지 재구성',
  'id="editor-inspector-tab-selection"',
  '<h2>크기 및 회전</h2>',
  '<SelectedPlacedObjectControls',
  '<h3>Size</h3>',
  'data-selected-size-field={config.field}',
  'const enterCommitField = isEnterCommitSizeField(config.field) ? config.field : null',
  "if (enterCommitField && event.key === 'Enter')",
  'commitPendingSize(enterCommitField)',
]) {
  assert.ok(pageSource.includes(marker), `Missing live count marker: ${marker}`)
}

for (const removedMarker of [
  'activeInspectorTab',
  'setActiveInspectorTab',
  'editor-inspector-tab-candidates',
  'editor-inspector-tab-placement',
  'editor-inspector-tab-confirmation',
  'editor-inspector-tab-status',
]) {
  assert.equal(pageSource.includes(removedMarker), false, `Inspector should not render removed tab: ${removedMarker}`)
}

for (const marker of [
  '.editor-runtime-toolbar',
  'flex-wrap: wrap;',
  'overscroll-behavior: contain;',
  '.placed-object-card:focus-visible',
  '.fixture-object-card:focus-visible',
  '.confirmation-actions .rf-btn:focus-visible',
  '.candidate-review-category select:focus-visible',
  '.placed-object-transform-grid input:focus-visible',
  '@media (max-width: 1100px)',
  '@media (max-width: 760px)',
  '.candidate-review-meta,',
  '.confirmation-actions',
]) {
  assert.ok(cssSource.includes(marker), `Missing responsive/a11y CSS marker: ${marker}`)
}

console.log('Web editor responsive accessibility contract verified')
