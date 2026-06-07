import {
  collection,
  doc,
  getDoc,
  getDocs,
  getFirestore,
  limit,
  orderBy,
  query,
  type DocumentData,
  type QueryDocumentSnapshot,
} from 'firebase/firestore'
import { useEffect, useState } from 'react'

import { hasFirebaseConfig, roomForgeFirebaseApp } from '../../firebase/config'
import { useAuth } from '../auth/AuthProvider'
import type { WorkspaceProject } from '../projects/projectData'
import type { EditorSceneUnderstandingResultBridgePayload } from './editorBridge'

export type SceneUnderstandingResultState = {
  status: 'loading' | 'ready' | 'empty' | 'error'
  bridgePayload?: EditorSceneUnderstandingResultBridgePayload
  resultId?: string
  error?: string
}

export function useLatestSceneUnderstandingResultPayload(
  project: WorkspaceProject | null | undefined,
): SceneUnderstandingResultState {
  const auth = useAuth()
  const [state, setState] = useState<SceneUnderstandingResultState>({ status: 'loading' })

  useEffect(() => {
    let active = true

    if (!project || !hasFirebaseConfig()) {
      setState({ status: 'empty' })
      return () => {
        active = false
      }
    }

    if (auth.status === 'loading') {
      setState({ status: 'loading' })
      return () => {
        active = false
      }
    }

    if (auth.status !== 'signed-in') {
      setState({ status: 'empty' })
      return () => {
        active = false
      }
    }

    setState({ status: 'loading' })
    loadLatestSceneUnderstandingResult(project)
      .then((bridgePayload) => {
        if (!active) return
        if (!bridgePayload) {
          setState({ status: 'empty' })
          return
        }
        setState({
          status: 'ready',
          bridgePayload,
          resultId: bridgePayload.resultId,
        })
      })
      .catch((error) => {
        if (!active) return
        setState({
          status: 'error',
          error: error instanceof Error ? error.message : String(error),
        })
      })

    return () => {
      active = false
    }
  }, [auth, project])

  return state
}

async function loadLatestSceneUnderstandingResult(
  project: WorkspaceProject,
): Promise<EditorSceneUnderstandingResultBridgePayload | undefined> {
  const firestore = getFirestore(roomForgeFirebaseApp())
  const latestSnapshot = await getDoc(
    doc(firestore, 'projects', project.id, 'scene_understanding_results', 'latest'),
  )
  if (latestSnapshot.exists()) {
    return sceneUnderstandingResultFromData(latestSnapshot.data(), latestSnapshot.id)
  }

  const snapshot = await getDocs(
    query(
      collection(firestore, 'projects', project.id, 'scene_understanding_results'),
      orderBy('updated_at', 'desc'),
      limit(1),
    ),
  )
  const [latest] = snapshot.docs
  if (latest) {
    return sceneUnderstandingResultFromSnapshot(latest)
  }

  const createdAtSnapshot = await getDocs(
    query(
      collection(firestore, 'projects', project.id, 'scene_understanding_results'),
      orderBy('created_at', 'desc'),
      limit(1),
    ),
  )
  const [latestByCreatedAt] = createdAtSnapshot.docs
  return latestByCreatedAt ? sceneUnderstandingResultFromSnapshot(latestByCreatedAt) : undefined
}

function sceneUnderstandingResultFromSnapshot(
  snapshot: QueryDocumentSnapshot<DocumentData>,
): EditorSceneUnderstandingResultBridgePayload | undefined {
  return sceneUnderstandingResultFromData(snapshot.data(), snapshot.id)
}

function sceneUnderstandingResultFromData(
  data: DocumentData,
  fallbackId: string,
): EditorSceneUnderstandingResultBridgePayload | undefined {
  const resultId = stringValue(data.result_id) ?? fallbackId
  const captureSessionId = stringValue(data.capture_session_id)
  if (!resultId || !captureSessionId) {
    return undefined
  }

  return {
    resultId,
    captureSessionId,
    providerType: stringValue(data.provider_type) ?? 'browser',
    algorithmId: stringValue(data.algorithm_id) ?? 'browser-scene-understanding-v1',
    modelId: stringValue(data.model_id),
    runtime: stringValue(data.runtime),
    detectorScoreThreshold: numberValue(data.detector_score_threshold),
    confidenceScore: numberValue(data.confidence_score),
    qualityStatus: qualityStatusValue(data.quality_status),
    failureReasonCode: stringValue(data.failure_reason_code),
    failureReason: stringValue(data.failure_reason),
    coverage: toCamelCaseDeep(recordValue(data.coverage)) as Record<string, unknown>,
    candidateObjects: toCamelCaseDeep(listValue(data.candidate_objects)) as unknown[],
    placedObjects: toCamelCaseDeep(listValue(data.placed_objects)) as unknown[],
    confirmedObjects: toCamelCaseDeep(listValue(data.confirmed_objects)) as unknown[],
    structuralFixtures: toCamelCaseDeep(listValue(data.structural_fixtures)) as unknown[],
  }
}

function toCamelCaseDeep(value: unknown): unknown {
  if (Array.isArray(value)) {
    return value.map(toCamelCaseDeep)
  }

  if (typeof value !== 'object' || value === null) {
    return value
  }

  return Object.fromEntries(
    Object.entries(value as Record<string, unknown>)
      .filter(([, item]) => item !== undefined)
      .map(([key, item]) => [camelCaseKey(key), toCamelCaseDeep(item)]),
  )
}

function camelCaseKey(key: string): string {
  return key.replace(/_([a-z])/g, (_, letter: string) => letter.toUpperCase())
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

function numberValue(value: unknown): number | undefined {
  return typeof value === 'number' && Number.isFinite(value) ? value : undefined
}

function qualityStatusValue(value: unknown): 'success' | 'review_required' | 'failed' {
  if (value === 'success' || value === 'review_required' || value === 'failed') {
    return value
  }
  return 'review_required'
}
