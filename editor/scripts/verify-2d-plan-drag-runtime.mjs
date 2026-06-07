import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const rootDir = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const runtimeSource = readFileSync(resolve(rootDir, 'src/runtime.ts'), 'utf8')
const cssSource = readFileSync(resolve(rootDir, 'src/style.css'), 'utf8')

function assertContains(source, expected, label) {
  assert.ok(source.includes(expected), `${label}: expected to find ${expected}`)
}

assertContains(runtimeSource, 'draggable="true" data-furniture-category', 'catalog tiles are draggable')
assertContains(runtimeSource, 'application/x-roomforge-furniture-category', 'drag payload uses a furniture MIME contract')
assertContains(runtimeSource, 'editorCanvas.addEventListener(\'drop\'', 'canvas accepts furniture drops')
assertContains(runtimeSource, 'metricPointFromCanvasEvent(event)', 'drop and drag convert pointer position into metric coordinates')
assertContains(runtimeSource, 'activeFurnitureDrag', 'placed furniture has pointer drag state')
assertContains(runtimeSource, 'setPointerCapture(event.pointerId)', 'dragged furniture captures the pointer')
assertContains(runtimeSource, 'clampedFurniturePosition', 'dragged furniture is clamped to room bounds')
assertContains(runtimeSource, 'snappedNumber', 'dragged furniture supports snap-to-grid placement')

assertContains(runtimeSource, 'createFurniturePlanSymbol', '2D mode renders top-down furniture symbols')
assertContains(runtimeSource, 'rebuildPlanMeasurementOverlay', '2D mode rebuilds metric overlays')
assertContains(runtimeSource, 'addDimensionLine', '2D mode renders dimension lines')
assertContains(runtimeSource, 'addPlanWallStrips', '2D mode renders top-down wall strips')
assertContains(runtimeSource, 'Area\', \'면적', '2D mode displays area metadata')
assertContains(runtimeSource, 'viewportElement.dataset.viewMode', 'viewport exposes mode for styling')

assertContains(cssSource, ".viewport[data-view-mode='2d']", '2D viewport has a dedicated light floor-plan grid')
assertContains(cssSource, '.viewport-plan-hint', '2D drag/drop helper text is styled')
assertContains(cssSource, ".viewport[data-view-mode='2d'] .editor-canvas", '2D canvas exposes drag cursor affordance')
assertContains(cssSource, '.viewport[data-view-mode=\'2d\'].is-dragging-furniture .editor-canvas', 'active furniture drag has cursor feedback')
assertContains(cssSource, '.obj-tile:active', 'catalog drag affordance has active state')

console.log('2D top-down plan and drag placement runtime contract verified')
