import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'

const projectDataSource = await readFile(new URL('../src/features/projects/projectData.ts', import.meta.url), 'utf8')
const projectRepositorySource = await readFile(new URL('../src/features/projects/projectRepository.ts', import.meta.url), 'utf8')
const projectsPageSource = await readFile(new URL('../src/features/projects/ProjectsPage.tsx', import.meta.url), 'utf8')
const overviewPageSource = await readFile(new URL('../src/features/projects/ProjectOverviewPage.tsx', import.meta.url), 'utf8')
const sourcePageSource = await readFile(new URL('../src/features/source/SourceImagesPage.tsx', import.meta.url), 'utf8')
const editorPageSource = await readFile(new URL('../src/features/editor/EditorPage.tsx', import.meta.url), 'utf8')
const firestoreRules = await readFile(new URL('../../app/firestore.rules', import.meta.url), 'utf8')

for (const marker of [
  'export const requiredSourceImageCount = 8',
  'export function projectHasCompleteSourceCapture',
  'export function projectReadyForEditor',
  'projectHasCompleteSourceCapture(project)',
]) {
  assert.ok(projectDataSource.includes(marker), `Missing shared project progress marker: ${marker}`)
}

for (const marker of [
  'source_image_count: 0',
  'source_capture_complete: false',
  "current_pipeline_step: 'source'",
  'syncProjectProgressFromSourceImages',
  'snapshot.size >= requiredSourceImageCount',
  'pipeline_progress',
]) {
  assert.ok(projectRepositorySource.includes(marker), `Missing project repository progress marker: ${marker}`)
}

for (const marker of [
  'projectReadyForEditor',
  'routes.editor(project.id)',
]) {
  assert.ok(projectsPageSource.includes(marker), `Missing projects page resume marker: ${marker}`)
  assert.ok(overviewPageSource.includes(marker), `Missing overview page resume marker: ${marker}`)
}

for (const marker of [
  "searchParams.get('reconstruct') === '1'",
  'ensureCompleteSourceSlots',
  '소스 이미지 재구성',
  '저장된 소스 이미지 8장을 채운 상태',
]) {
  assert.ok(sourcePageSource.includes(marker), `Missing source reconstruction marker: ${marker}`)
}

for (const marker of [
  'restartSourceReconstruction',
  'window.confirm',
  '?reconstruct=1',
  '소스 이미지 재구성',
]) {
  assert.ok(editorPageSource.includes(marker), `Missing editor reconstruction marker: ${marker}`)
}

for (const marker of [
  "'source_image_count'",
  "'source_capture_complete'",
  "'current_pipeline_step'",
  "'pipeline_progress'",
  'validProjectProgressState',
  'isAllowedProjectPipelineStep',
]) {
  assert.ok(firestoreRules.includes(marker), `Missing Firestore progress rule marker: ${marker}`)
}

console.log('Web project progress routing contract verified')
