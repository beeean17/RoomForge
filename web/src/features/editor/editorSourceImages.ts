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
import { getBlob, getStorage, ref as storageRef } from 'firebase/storage'
import { useEffect, useState } from 'react'

import { hasFirebaseConfig, roomForgeFirebaseApp } from '../../firebase/config'
import { useAuth } from '../auth/AuthProvider'
import type { WorkspaceProject } from '../projects/projectData'
import type { EditorSourceImageBridgePayload } from './editorBridge'

export type SourceImageState = {
  status: 'loading' | 'ready' | 'empty' | 'error'
  bridgePayload?: EditorSourceImageBridgePayload
  sourceImageId?: string
  error?: string
}

type SourceImageMetadata = {
  sourceImageId: string
  storagePath: string
  contentType?: string
  widthPx?: number
  heightPx?: number
  captureSessionId?: string
  captureImageId?: string
  captureImageRole?: string
}

type CaptureImageMetadata = {
  captureImageId: string
  captureSessionId: string
  sourceImageId: string
  role: string
  storagePath?: string
  contentType?: string
  widthPx?: number
  heightPx?: number
  captureOrder?: number
  guidanceState?: string
}

export function useEditorSourceImagePayload(
  project: WorkspaceProject | null | undefined,
): SourceImageState {
  const auth = useAuth()
  const [state, setState] = useState<SourceImageState>({ status: 'loading' })

  useEffect(() => {
    let active = true

    if (!project) {
      setState({ status: 'empty' })
      return () => {
        active = false
      }
    }

    if (!hasFirebaseConfig()) {
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
    loadEditorSourceImage(project)
      .then((bridgePayload) => {
        if (!active) return
        if (!bridgePayload?.sourceImage) {
          setState({ status: 'empty' })
          return
        }
        setState({
          status: 'ready',
          bridgePayload,
          sourceImageId: bridgePayload.sourceImage.sourceImageId,
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

async function loadEditorSourceImage(
  project: WorkspaceProject,
): Promise<EditorSourceImageBridgePayload | undefined> {
  const app = roomForgeFirebaseApp()
  const firestore = getFirestore(app)
  const sourceImage = await loadLatestSourceImageMetadata(firestore, project)
  if (!sourceImage) {
    return undefined
  }

  const blob = await getBlob(storageRef(getStorage(app), sourceImage.storagePath))
  const dataUrl = await blobToDataUrl(blob)
  const captureSession = await loadCaptureSessionPayload(firestore, project.id, sourceImage)

  return {
    sourceImage: {
      sourceImageId: sourceImage.sourceImageId,
      dataUrl,
      widthPx: sourceImage.widthPx,
      heightPx: sourceImage.heightPx,
      contentType: sourceImage.contentType,
    },
    captureSession,
  }
}

async function loadLatestSourceImageMetadata(
  firestore: ReturnType<typeof getFirestore>,
  project: WorkspaceProject,
): Promise<SourceImageMetadata | null> {
  if (project.latestSourceImageId) {
    const snapshot = await getDoc(
      doc(firestore, 'projects', project.id, 'source_images', project.latestSourceImageId),
    )
    return snapshot.exists() ? sourceImageFromData(snapshot.data(), snapshot.id) : null
  }

  const snapshot = await getDocs(
    query(
      collection(firestore, 'projects', project.id, 'source_images'),
      orderBy('uploaded_at', 'desc'),
      limit(1),
    ),
  )
  const [latest] = snapshot.docs
  return latest ? sourceImageFromSnapshot(latest) : null
}

async function loadCaptureSessionPayload(
  firestore: ReturnType<typeof getFirestore>,
  projectId: string,
  sourceImage: SourceImageMetadata,
): Promise<NonNullable<EditorSourceImageBridgePayload['captureSession']>> {
  const captureSessionId =
    sourceImage.captureSessionId ?? `single-source-${sourceImage.sourceImageId}`
  const fallbackImage = captureImageFromSourceImage(sourceImage, captureSessionId)

  if (!sourceImage.captureSessionId) {
    return {
      captureSessionId,
      projectId,
      captureMethod: 'desktop_upload',
      depthEnabled: false,
      availableRoles: [fallbackImage.role],
      images: [fallbackImage],
    }
  }

  const sessionSnapshot = await getDoc(
    doc(firestore, 'projects', projectId, 'capture_sessions', sourceImage.captureSessionId),
  )
  const imageSnapshot = await getDocs(
    query(
      collection(
        firestore,
        'projects',
        projectId,
        'capture_sessions',
        sourceImage.captureSessionId,
        'images',
      ),
      orderBy('capture_order', 'asc'),
    ),
  )
  const images = imageSnapshot.docs
    .map((snapshot) => captureImageFromSnapshot(snapshot))
    .filter((image) => image !== null)

  const session = sessionSnapshot.data() ?? {}
  const availableRoles = uniqueStrings(
    images.length > 0 ? images.map((image) => image.role) : [fallbackImage.role],
  )

  return {
    captureSessionId: sourceImage.captureSessionId,
    projectId,
    roomDimensionsId: stringValue(session.room_dimensions_id),
    captureMethod: stringValue(session.capture_method),
    depthEnabled: booleanValue(session.depth_enabled) ?? false,
    availableRoles,
    images: images.length > 0 ? images : [fallbackImage],
  }
}

function sourceImageFromSnapshot(
  snapshot: QueryDocumentSnapshot<DocumentData>,
): SourceImageMetadata | null {
  return sourceImageFromData(snapshot.data(), snapshot.id)
}

function sourceImageFromData(data: DocumentData, fallbackId: string): SourceImageMetadata | null {
  const storagePath = stringValue(data.storage_path)
  if (!storagePath) {
    return null
  }
  return {
    sourceImageId: stringValue(data.source_image_id) ?? fallbackId,
    storagePath,
    contentType: stringValue(data.content_type),
    widthPx: positiveNumberValue(data.width_px),
    heightPx: positiveNumberValue(data.height_px),
    captureSessionId: stringValue(data.capture_session_id),
    captureImageId: stringValue(data.capture_image_id),
    captureImageRole: stringValue(data.capture_image_role),
  }
}

function captureImageFromSnapshot(
  snapshot: QueryDocumentSnapshot<DocumentData>,
): CaptureImageMetadata | null {
  const data = snapshot.data()
  const captureImageId = stringValue(data.capture_image_id) ?? snapshot.id
  const captureSessionId = stringValue(data.capture_session_id)
  const sourceImageId = stringValue(data.source_image_id)
  const role = stringValue(data.role)
  if (!captureSessionId || !sourceImageId || !role) {
    return null
  }
  return {
    captureImageId,
    captureSessionId,
    sourceImageId,
    role,
    storagePath: stringValue(data.storage_path),
    contentType: stringValue(data.content_type),
    widthPx: positiveNumberValue(data.width_px),
    heightPx: positiveNumberValue(data.height_px),
    captureOrder: nonNegativeNumberValue(data.capture_order),
    guidanceState: stringValue(data.guidance_state),
  }
}

function captureImageFromSourceImage(
  sourceImage: SourceImageMetadata,
  captureSessionId: string,
): CaptureImageMetadata {
  return {
    captureImageId: sourceImage.captureImageId ?? sourceImage.sourceImageId,
    captureSessionId,
    sourceImageId: sourceImage.sourceImageId,
    role: sourceImage.captureImageRole ?? 'overview',
    storagePath: sourceImage.storagePath,
    contentType: sourceImage.contentType,
    widthPx: sourceImage.widthPx,
    heightPx: sourceImage.heightPx,
    captureOrder: 0,
    guidanceState: 'uploaded',
  }
}

function blobToDataUrl(blob: Blob): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.onload = () => resolve(String(reader.result))
    reader.onerror = () => reject(reader.error ?? new Error('Unable to read source image blob.'))
    reader.readAsDataURL(blob)
  })
}

function uniqueStrings(values: string[]): string[] {
  return Array.from(new Set(values.filter((value) => value.length > 0)))
}

function stringValue(value: unknown): string | undefined {
  return typeof value === 'string' && value.length > 0 ? value : undefined
}

function booleanValue(value: unknown): boolean | undefined {
  return typeof value === 'boolean' ? value : undefined
}

function positiveNumberValue(value: unknown): number | undefined {
  return typeof value === 'number' && Number.isFinite(value) && value > 0 ? value : undefined
}

function nonNegativeNumberValue(value: unknown): number | undefined {
  return typeof value === 'number' && Number.isFinite(value) && value >= 0 ? value : undefined
}
