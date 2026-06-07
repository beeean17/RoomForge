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
import type { EditorOpenCvResultBridgePayload } from './editorBridge'

export type OpenCvResultState = {
  status: 'loading' | 'ready' | 'empty' | 'error'
  bridgePayload?: EditorOpenCvResultBridgePayload
  resultId?: string
  error?: string
}

export function useLatestOpenCvResultPayload(
  project: WorkspaceProject | null | undefined,
): OpenCvResultState {
  const auth = useAuth()
  const [state, setState] = useState<OpenCvResultState>({ status: 'loading' })

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
    loadLatestOpenCvResult(project)
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

async function loadLatestOpenCvResult(
  project: WorkspaceProject,
): Promise<EditorOpenCvResultBridgePayload | undefined> {
  const firestore = getFirestore(roomForgeFirebaseApp())
  const latestSnapshot = await getDoc(doc(firestore, 'projects', project.id, 'opencv_results', 'latest'))
  if (latestSnapshot.exists()) {
    return openCvResultFromData(latestSnapshot.data(), latestSnapshot.id)
  }

  const snapshot = await getDocs(
    query(
      collection(firestore, 'projects', project.id, 'opencv_results'),
      orderBy('created_at', 'desc'),
      limit(1),
    ),
  )
  const [latest] = snapshot.docs
  return latest ? openCvResultFromSnapshot(latest) : undefined
}

function openCvResultFromSnapshot(
  snapshot: QueryDocumentSnapshot<DocumentData>,
): EditorOpenCvResultBridgePayload | undefined {
  return openCvResultFromData(snapshot.data(), snapshot.id)
}

function openCvResultFromData(
  data: DocumentData,
  fallbackId: string,
): EditorOpenCvResultBridgePayload | undefined {
  const sourceImageId = stringValue(data.source_image_id)
  const jobId = stringValue(data.job_id)
  if (!sourceImageId || !jobId || data.coordinate_space !== 'image_pixels') {
    return undefined
  }

  const resultId = stringValue(data.result_id) ?? fallbackId
  const boundaryHints = toCamelCaseDeep(listValue(data.boundary_hints))
  const candidateCorners = toCamelCaseDeep(listValue(data.candidate_corners))
  const candidateLines = toCamelCaseDeep(listValue(data.candidate_lines))
  const candidateEdges = toCamelCaseDeep(listValue(data.candidate_edges))

  return {
    resultId,
    jobId,
    sourceImageId,
    coordinateSpace: 'image_pixels',
    algorithm: stringValue(data.algorithm_id) ?? 'opencv-js-canny-hough-v1',
    openCvVersion: stringValue(data.opencv_version),
    confidence: numberValue(data.confidence_score),
    qualityStatus: qualityStatusValue(data.quality_status),
    reasonCode: stringValue(data.failure_reason_code),
    reasonMessage: stringValue(data.failure_reason),
    candidateGeometry: {
      image: {},
      candidateEdges,
      candidateLines,
      candidateCorners,
      boundaryHints,
      candidateSets: boundaryHints,
      overlayStyle: {
        candidate: 'dashed-low-opacity-purple',
        confirmed: 'solid-blue-with-handles',
      },
    },
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
