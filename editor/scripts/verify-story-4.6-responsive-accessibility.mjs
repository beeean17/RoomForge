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

function mediaBlock(query) {
  const marker = `@media (${query})`
  const start = cssSource.indexOf(marker)
  assert.notEqual(start, -1, `Expected ${marker} block`)
  const nextMedia = cssSource.indexOf('\n@media', start + marker.length)
  return cssSource.slice(start, nextMedia === -1 ? cssSource.length : nextMedia)
}

assertContains(runtimeSource, '<section class="editor-shell"', 'desktop shell exists')
assertContains(runtimeSource, '<div class="viewport"', 'central viewport exists')
assertContains(runtimeSource, '<aside class="status-panel"', 'right inspector/status panel exists')
assertContains(runtimeSource, 'class="viewport-toolbar"', 'persistent 2D/3D switcher exists')
assertContains(runtimeSource, 'Show 2D planning view', '2D button has accessible name')
assertContains(runtimeSource, 'Show 3D inspection view', '3D button has accessible name')
assertContains(runtimeSource, 'aria-pressed="true"', 'view switcher exposes pressed state')
assertContains(
  runtimeSource,
  'aria-describedby="measurement-status scene-status inspector-status placement-summary"',
  'canvas references textual measurement, scene, inspector, and placement summaries',
)
assertContains(runtimeSource, 'role="application"', 'canvas exposes interactive application role')
assertContains(runtimeSource, 'tabindex="0"', 'canvas is keyboard focusable')
assertContains(runtimeSource, 'aria-describedby="scale-status"', 'scale input references helper text')
assertContains(runtimeSource, 'role="status" aria-live="polite"', 'polite live status regions exist')
assertContains(runtimeSource, 'role="status" aria-live="assertive"', 'assertive placement warning exists')

assertContains(cssSource, 'grid-template-columns: minmax(0, 1fr) 320px;', 'desktop keeps large canvas with right inspector')
assertContains(cssSource, 'max-height: 100vh;', 'desktop shell and inspector fit viewport height')
assertContains(cssSource, 'justify-content: flex-start;', 'right inspector scrolls from the first control group')
assertContains(cssSource, 'overflow: auto;', 'right inspector can scroll')
assertContains(cssSource, 'min-height: 100vh;', 'desktop canvas fills the viewport')
assertContains(cssSource, 'grid-template-columns: repeat(2, 56px);', 'desktop switcher remains compact')
assertContains(cssSource, 'min-height: 44px;', 'controls meet minimum touch height')
assertContains(cssSource, 'min-width: 44px;', 'controls meet minimum touch width')
assertContains(cssSource, 'button:focus-visible', 'keyboard focus indicator exists')
assertContains(cssSource, 'outline: 3px solid #f59e0b;', 'focus indicator is visible without color-only state')

const tabletBlock = mediaBlock('max-width: 800px')
assertContains(tabletBlock, 'grid-template-columns: 1fr;', 'tablet/mobile collapses shell to one column')
assertContains(tabletBlock, 'min-height: 62vh;', 'tablet/mobile preserves a large canvas review area')
assertContains(tabletBlock, 'max-height: none;', 'tablet/mobile inspector can grow below canvas')
assertContains(tabletBlock, 'border-top: 1px solid #d9e2ef;', 'collapsed panel remains visually separated')
assertContains(tabletBlock, 'grid-template-columns: repeat(2, 64px);', 'mobile view switcher uses larger targets')
assertContains(tabletBlock, 'left: 12px;', 'viewport overlays avoid edge clipping on mobile')
assertContains(tabletBlock, 'right: 12px;', 'viewport overlays constrain text on mobile')

const phoneBlock = mediaBlock('max-width: 480px')
assertContains(phoneBlock, '.geometry-controls,', 'phone block includes geometry controls')
assertContains(phoneBlock, '.furniture-edit-controls,', 'phone block includes furniture edit controls')
assertContains(phoneBlock, '.camera-controls', 'phone block includes camera controls')
assertContains(phoneBlock, 'grid-template-columns: 1fr;', 'phone controls collapse to one column')

console.log('Story 4.6 responsive and accessibility contract verified')
