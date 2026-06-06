import { doc, getFirestore, serverTimestamp, setDoc } from 'firebase/firestore'

import { roomForgeFirebaseApp } from '../../firebase/config'
import type { WorkspaceProject } from '../projects/projectData'
import type { EditorBridgeMessage, EditorSourceImageBridgePayload } from './editorBridge'

type PersistenceContext = {
  project: WorkspaceProject
  ownerUid?: string
  source?: EditorSourceImageBridgePayload
}

export type EditorEventPersistenceResult = {
  status: 'ignored' | 'stored' | 'skipped'
  label: string
}

export async function persistEditorBridgeEvent({
  message,
  project,
  ownerUid,
  source,
}: PersistenceContext & { message: EditorBridgeMessage }): Promise<EditorEventPersistenceResult> {
  if (!isPersistableEditorEvent(message.type)) {
    return { status: 'ignored', label: 'Event ignored' }
  }

  if (!ownerUid) {
    return { status: 'skipped', label: 'Signed-in Firebase user required' }
  }

  const sourceImageId = source?.sourceImage?.sourceImageId ?? project.latestSourceImageId
  if (!sourceImageId) {
    return { status: 'skipped', label: 'Source image required before CV persistence' }
  }

  if (message.type === 'roomforge.sceneUnderstanding.candidatesExtracted') {
    return persistSceneUnderstandingResult({ message, project, ownerUid, sourceImageId, source })
  }

  if (!project.latestJobId) {
    return { status: 'skipped', label: 'Reconstruction job required before geometry persistence' }
  }

  if (message.type === 'roomforge.opencv.candidatesExtracted') {
    return persistOpenCvResult({ message, project, ownerUid, sourceImageId })
  }

  if (message.type === 'roomforge.geometry.confirmedChanged') {
    return persistConfirmedGeometry({ message, project, ownerUid, sourceImageId })
  }

  return { status: 'ignored', label: 'Event ignored' }
}

function isPersistableEditorEvent(type: string): boolean {
  return (
    type === 'roomforge.opencv.candidatesExtracted' ||
    type === 'roomforge.sceneUnderstanding.candidatesExtracted' ||
    type === 'roomforge.geometry.confirmedChanged'
  )
}

async function persistOpenCvResult({
  message,
  project,
  ownerUid,
  sourceImageId,
}: PersistenceContext & { message: EditorBridgeMessage; ownerUid: string; sourceImageId: string }) {
  const resultId = safeDocumentId(`opencv-${message.requestId ?? Date.now()}`)
  const payload = recordValue(message.payload)
  const geometry = recordValue(payload.candidateGeometry)
  const firestore = getFirestore(roomForgeFirebaseApp())

  await setDoc(doc(firestore, 'projects', project.id, 'opencv_results', resultId), withoutUndefined({
    result_id: resultId,
    project_id: project.id,
    owner_uid: ownerUid,
    job_id: project.latestJobId,
    source_image_id: stringValue(payload.sourceImageId) ?? sourceImageId,
    coordinate_space: 'image_pixels',
    algorithm_id: stringValue(payload.algorithm) ?? 'opencv-js-canny-hough-v1',
    opencv_version: stringValue(payload.openCvVersion),
    candidate_edges: toSnakeCaseDeep(listValue(geometry.candidateEdges)),
    candidate_lines: toSnakeCaseDeep(listValue(geometry.candidateLines)),
    candidate_corners: toSnakeCaseDeep(listValue(geometry.candidateCorners)),
    boundary_hints: toSnakeCaseDeep(
      listValue(geometry.boundaryHints).length > 0
        ? listValue(geometry.boundaryHints)
        : listValue(geometry.candidateSets),
    ),
    confidence_score: normalizedNumber(payload.confidence),
    quality_status: qualityStatusValue(payload.qualityStatus),
    failure_reason_code: failureReasonCode(payload.reasonCode, payload.qualityStatus),
    failure_reason: stringValue(payload.reasonMessage),
    artifact_refs: [],
    processing_completed_at: serverTimestamp(),
    created_at: serverTimestamp(),
    updated_at: serverTimestamp(),
    schema_version: 1,
  }))

  return { status: 'stored', label: 'OpenCV result persisted' } as const
}

async function persistSceneUnderstandingResult({
  message,
  project,
  ownerUid,
  source,
}: PersistenceContext & { message: EditorBridgeMessage; ownerUid: string; sourceImageId: string }) {
  const payload = recordValue(message.payload)
  const result = recordValue(payload.sceneUnderstandingResult)
  const resultId = safeDocumentId(stringValue(result.resultId) ?? `scene-understanding-${Date.now()}`)
  const firestore = getFirestore(roomForgeFirebaseApp())
  const qualityStatus = qualityStatusValue(result.qualityStatus)

  await setDoc(doc(firestore, 'projects', project.id, 'scene_understanding_results', resultId), withoutUndefined({
    result_id: resultId,
    project_id: project.id,
    owner_uid: ownerUid,
    capture_session_id:
      stringValue(result.captureSessionId) ??
      source?.captureSession?.captureSessionId ??
      `single-source-${source?.sourceImage?.sourceImageId ?? project.latestSourceImageId ?? project.id}`,
    job_id: project.latestJobId,
    provider_type: sceneProviderType(result.providerType),
    algorithm_id: stringValue(result.algorithmId) ?? 'browser-scene-understanding-v1',
    model_id: stringValue(result.modelId),
    confidence_score: normalizedNumber(result.confidenceScore),
    quality_status: qualityStatus,
    failure_reason_code: sceneFailureReasonCode(result.failureReasonCode, qualityStatus),
    failure_reason: stringValue(result.failureReason),
    coverage: toSnakeCaseDeep(recordValue(result.coverage)),
    candidate_objects: toSnakeCaseDeep(listValue(result.candidateObjects)),
    placed_objects: toSnakeCaseDeep(listValue(result.placedObjects)),
    confirmed_objects: toSnakeCaseDeep(listValue(result.confirmedObjects)),
    structural_fixtures: toSnakeCaseDeep(listValue(result.structuralFixtures)),
    artifact_refs: [],
    processing_completed_at: serverTimestamp(),
    created_at: serverTimestamp(),
    updated_at: serverTimestamp(),
    schema_version: 1,
  }))

  return { status: 'stored', label: 'Scene understanding result persisted' } as const
}

async function persistConfirmedGeometry({
  message,
  project,
  ownerUid,
  sourceImageId,
}: PersistenceContext & { message: EditorBridgeMessage; ownerUid: string; sourceImageId: string }) {
  const payload = recordValue(message.payload)
  const points = listValue(payload.points)
  if (points.length < 3) {
    return { status: 'skipped', label: 'Confirmed geometry needs at least 3 points' } as const
  }

  const geometryId = safeDocumentId(`geometry-${Date.now()}`)
  const firestore = getFirestore(roomForgeFirebaseApp())
  await setDoc(doc(firestore, 'projects', project.id, 'confirmed_geometries', geometryId), withoutUndefined({
    geometry_id: geometryId,
    project_id: project.id,
    owner_uid: ownerUid,
    job_id: project.latestJobId,
    source_image_id: sourceImageId,
    coordinate_space: 'image_pixels',
    boundary_type: points.length === 4 ? 'rectangle' : 'simple_polygon',
    boundary_points: toSnakeCaseDeep(points),
    correction_method: 'editor_confirmed',
    confirmed_by_uid: ownerUid,
    created_at: serverTimestamp(),
    updated_at: serverTimestamp(),
    schema_version: 1,
  }))

  return { status: 'stored', label: 'Confirmed geometry persisted' } as const
}

function safeDocumentId(value: string): string {
  return value.replace(/[^A-Za-z0-9_-]/g, '-').slice(0, 140)
}

function toSnakeCaseDeep(value: unknown): unknown {
  if (Array.isArray(value)) {
    return value.map(toSnakeCaseDeep)
  }

  if (typeof value !== 'object' || value === null) {
    return value
  }

  return Object.fromEntries(
    Object.entries(value as Record<string, unknown>)
      .filter(([, item]) => item !== undefined)
      .map(([key, item]) => [snakeCaseKey(key), toSnakeCaseDeep(item)]),
  )
}

function snakeCaseKey(key: string): string {
  return key.replace(/[A-Z]/g, (letter) => `_${letter.toLowerCase()}`)
}

function withoutUndefined<T extends Record<string, unknown>>(value: T): T {
  return Object.fromEntries(
    Object.entries(value).filter(([, item]) => item !== undefined),
  ) as T
}

function recordValue(value: unknown): Record<string, unknown> {
  return typeof value === 'object' && value !== null ? (value as Record<string, unknown>) : {}
}

function listValue(value: unknown): unknown[] {
  return Array.isArray(value) ? value : []
}

function stringValue(value: unknown): string | undefined {
  return typeof value === 'string' && value.length > 0 ? value : undefined
}

function normalizedNumber(value: unknown): number | undefined {
  return typeof value === 'number' && Number.isFinite(value) && value >= 0 && value <= 1
    ? value
    : undefined
}

function qualityStatusValue(value: unknown): 'success' | 'review_required' | 'failed' {
  if (value === 'success' || value === 'review_required' || value === 'failed') {
    return value
  }
  return 'review_required'
}

function failureReasonCode(value: unknown, qualityStatus: unknown): string | undefined {
  const reason = stringValue(value)
  if (reason === 'no_source_image' || reason === 'no_capture_images') return 'no_source_images'
  if (reason === 'unsupported_runtime') return 'unsupported_runtime'
  if (reason === 'low_confidence') return 'low_confidence'
  if (reason === 'provider_unavailable') return 'provider_unavailable'
  if (qualityStatus === 'failed') return 'detector_failed'
  return reason
}

function sceneFailureReasonCode(
  value: unknown,
  qualityStatus: 'success' | 'review_required' | 'failed',
): string | undefined {
  const reason = failureReasonCode(value, qualityStatus)
  return qualityStatus === 'failed' ? reason ?? 'detector_failed' : reason
}

function sceneProviderType(value: unknown): 'browser_cv' | 'android_arcore_depth' | 'cloud_gpu' | 'manual' {
  if (
    value === 'android_arcore_depth' ||
    value === 'cloud_gpu' ||
    value === 'manual'
  ) {
    return value
  }
  return 'browser_cv'
}
