import {
  collection,
  doc,
  getDoc,
  getDocs,
  getFirestore,
  limit,
  onSnapshot,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  writeBatch,
  type DocumentData,
  type Firestore,
  type QueryDocumentSnapshot,
  type Unsubscribe,
} from 'firebase/firestore'
import { getFunctions, httpsCallable } from 'firebase/functions'
import { useEffect, useMemo, useRef, useState, type Dispatch, type SetStateAction } from 'react'

import { useAuth } from '../auth/AuthProvider'
import { roomForgeFirebaseApp } from '../../firebase/config'
import {
  demoProjects,
  projectLabelForStatus,
  projectReadyForEditor,
  requiredSourceImageCount,
  projectToneForStatus,
  type ProjectPipelineStepKey,
  type ProjectStatus,
  type WorkspaceProject,
} from './projectData'

type ProjectDataState = {
  status: 'loading' | 'ready' | 'error'
  source: 'firebase' | 'demo'
  projects: WorkspaceProject[]
  error: string | null
}

type SourceImageSummary = {
  imageCount: number
  sourceCaptureComplete: boolean
  latestSourceImageId?: string
  latestUploadedAt?: Date
}

export type ProjectRoomDimensions = {
  roomDimensionsId: 'current'
  widthM: number
  depthM: number
  heightM: number
  unit: 'meters'
  source?: string
  updatedAt?: Date
}

export type RoomDimensionsInput = {
  widthM: number
  depthM: number
  heightM: number
}

type RoomDimensionsState = {
  status: 'loading' | 'ready' | 'empty' | 'error'
  dimensions: ProjectRoomDimensions
  error: string | null
}

const allowedStatuses = new Set<ProjectStatus>([
  'created',
  'uploading',
  'processing',
  'review_required',
  'succeeded',
  'failed',
  'timeout',
  'cancelled',
  'retrying',
])

export const defaultProjectRoomDimensions: ProjectRoomDimensions = {
  roomDimensionsId: 'current',
  widthM: 5.2,
  depthM: 6.0,
  heightM: 2.8,
  unit: 'meters',
  source: 'web_default',
}

export function useProjects(): ProjectDataState {
  const auth = useAuth()
  const sourceImageSubscriptions = useRef<Map<string, Unsubscribe>>(new Map())
  const [sourceImageSummaries, setSourceImageSummaries] = useState<Record<string, SourceImageSummary>>({})
  const [state, setState] = useState<ProjectDataState>({
    status: auth.isConfigured ? 'loading' : 'ready',
    source: auth.isConfigured ? 'firebase' : 'demo',
    projects: auth.isConfigured ? [] : demoProjects,
    error: null,
  })

  useEffect(() => {
    if (!auth.isConfigured) {
      unsubscribeAll(sourceImageSubscriptions.current)
      setSourceImageSummaries({})
      setState({ status: 'ready', source: 'demo', projects: demoProjects, error: null })
      return undefined
    }

    if (auth.status === 'loading') {
      unsubscribeAll(sourceImageSubscriptions.current)
      setSourceImageSummaries({})
      setState({ status: 'loading', source: 'firebase', projects: [], error: null })
      return undefined
    }

    if (auth.status !== 'signed-in') {
      unsubscribeAll(sourceImageSubscriptions.current)
      setSourceImageSummaries({})
      setState({ status: 'ready', source: 'firebase', projects: [], error: null })
      return undefined
    }

    const firestore = getFirestore(roomForgeFirebaseApp())
    const ownedProjects = query(
      collection(firestore, 'projects'),
      where('owner_uid', '==', auth.user.uid),
      orderBy('updated_at', 'desc'),
    )

    let unsubscribe: Unsubscribe | undefined
    unsubscribe = onSnapshot(
      ownedProjects,
      (snapshot) => {
        const activeDocs = snapshot.docs.filter(isActiveProjectSnapshot)
        const activeProjectIds = new Set(activeDocs.map((document) => document.id))
        syncSourceImageSubscriptions(
          firestore,
          activeProjectIds,
          sourceImageSubscriptions.current,
          setSourceImageSummaries,
        )
        setState({
          status: 'ready',
          source: 'firebase',
          projects: activeDocs.map(projectFromSnapshot),
          error: null,
        })
      },
      (error) => {
        unsubscribeAll(sourceImageSubscriptions.current)
        setSourceImageSummaries({})
        setState({
          status: 'error',
          source: 'firebase',
          projects: [],
          error: error.message,
        })
      },
    )

    return () => {
      unsubscribe?.()
      unsubscribeAll(sourceImageSubscriptions.current)
    }
  }, [auth])

  const projects = useMemo(
    () => state.projects.map((project) => mergeSourceImageSummary(project, sourceImageSummaries[project.id])),
    [sourceImageSummaries, state.projects],
  )

  return { ...state, projects }
}

export function useProject(projectId: string | undefined) {
  const auth = useAuth()
  const collectionState = useProjects()
  const [remoteProject, setRemoteProject] = useState<WorkspaceProject | null>(null)
  const [remoteError, setRemoteError] = useState<string | null>(null)

  useEffect(() => {
    let active = true

    if (!auth.isConfigured || auth.status !== 'signed-in' || !projectId) {
      setRemoteProject(null)
      setRemoteError(null)
      return () => {
        active = false
      }
    }

    getDoc(doc(getFirestore(roomForgeFirebaseApp()), 'projects', projectId))
      .then((snapshot) => {
        if (!active) return
        setRemoteProject(snapshot.exists() && isActiveProjectSnapshot(snapshot) ? projectFromSnapshot(snapshot) : null)
        setRemoteError(null)
      })
      .catch((error) => {
        if (!active) return
        setRemoteProject(null)
        setRemoteError(error instanceof Error ? error.message : String(error))
      })

    return () => {
      active = false
    }
  }, [auth, projectId])

  return useMemo(() => {
    const listedProject = collectionState.projects.find((project) => project.id === projectId)
    const demoProject = demoProjects.find((project) => project.id === projectId) ?? demoProjects[0]
    const project = listedProject ?? remoteProject ?? (!auth.isConfigured ? demoProject : null)

    return {
      ...collectionState,
      project,
      error: collectionState.error ?? remoteError,
    }
  }, [auth.isConfigured, collectionState, projectId, remoteError, remoteProject])
}

export function useProjectRoomDimensions(projectId: string | undefined): RoomDimensionsState {
  const auth = useAuth()
  const [state, setState] = useState<RoomDimensionsState>({
    status: 'loading',
    dimensions: defaultProjectRoomDimensions,
    error: null,
  })

  useEffect(() => {
    let active = true

    if (!projectId) {
      setState({ status: 'empty', dimensions: defaultProjectRoomDimensions, error: null })
      return () => {
        active = false
      }
    }

    if (!auth.isConfigured) {
      setState({ status: 'ready', dimensions: defaultProjectRoomDimensions, error: null })
      return () => {
        active = false
      }
    }

    if (auth.status === 'loading') {
      setState((current) => ({ ...current, status: 'loading', error: null }))
      return () => {
        active = false
      }
    }

    if (auth.status !== 'signed-in') {
      setState({ status: 'empty', dimensions: defaultProjectRoomDimensions, error: null })
      return () => {
        active = false
      }
    }

    setState((current) => ({ ...current, status: 'loading', error: null }))
    getDoc(doc(getFirestore(roomForgeFirebaseApp()), 'projects', projectId, 'room_dimensions', 'current'))
      .then((snapshot) => {
        if (!active) return
        if (!snapshot.exists()) {
          setState({ status: 'empty', dimensions: defaultProjectRoomDimensions, error: null })
          return
        }
        setState({
          status: 'ready',
          dimensions: roomDimensionsFromData(snapshot.data()),
          error: null,
        })
      })
      .catch((error) => {
        if (!active) return
        setState({
          status: 'error',
          dimensions: defaultProjectRoomDimensions,
          error: error instanceof Error ? error.message : String(error),
        })
      })

    return () => {
      active = false
    }
  }, [auth, projectId])

  return state
}

export async function createWorkspaceProject(owner: { uid: string }, name: string) {
  const firestore = getFirestore(roomForgeFirebaseApp())
  const projectRef = doc(collection(firestore, 'projects'))
  const projectName = name.trim() || '새 프로젝트'

  await setDoc(projectRef, {
    project_id: projectRef.id,
    owner_uid: owner.uid,
    name: projectName,
    description: '첫 소스 이미지를 추가하면 2D/3D 변환을 시작할 수 있습니다.',
    schema_version: 1,
    source_image_count: 0,
    source_capture_complete: false,
    current_pipeline_step: 'source',
    pipeline_progress: 0,
    created_at: serverTimestamp(),
    updated_at: serverTimestamp(),
    deleted_at: null,
  })

  return projectRef.id
}

export async function renameWorkspaceProject(projectId: string, name: string) {
  const firestore = getFirestore(roomForgeFirebaseApp())

  await updateDoc(doc(firestore, 'projects', projectId), {
    name,
    updated_at: serverTimestamp(),
  })
}

export async function deleteWorkspaceProject(projectId: string) {
  const functions = getFunctions(roomForgeFirebaseApp(), 'us-central1')
  const deleteProject = httpsCallable<{ projectId: string }, unknown>(functions, 'deleteProject')

  await deleteProject({ projectId })
}

export async function createProjectReconstructionJob(
  project: WorkspaceProject,
  owner: { uid: string },
  dimensions?: RoomDimensionsInput,
) {
  const firestore = getFirestore(roomForgeFirebaseApp())
  const sourceImageId = await latestSourceImageIdForProject(firestore, project.id) ?? project.latestSourceImageId

  if (!sourceImageId) {
    throw new Error('변환을 시작할 소스 이미지가 없습니다.')
  }

  if (dimensions) {
    const dimensionsAlreadyExist = await projectRoomDimensionsExist(firestore, project.id)
    try {
      await saveProjectRoomDimensions(project.id, owner, dimensions, 'web_source_form')
    } catch (error) {
      if (!dimensionsAlreadyExist) {
        throw error
      }
    }
  } else {
    await ensureDefaultRoomDimensions(firestore, project.id, owner.uid)
  }

  const projectRef = doc(firestore, 'projects', project.id)
  const jobRef = doc(collection(firestore, 'projects', project.id, 'reconstruction_jobs'))
  const transitionRef = doc(collection(firestore, 'projects', project.id, 'reconstruction_jobs', jobRef.id, 'transitions'))
  const timestamp = serverTimestamp()
  const batch = writeBatch(firestore)

  batch.set(jobRef, {
    job_id: jobRef.id,
    project_id: project.id,
    owner_uid: owner.uid,
    source_image_id: sourceImageId,
    room_dimensions_id: 'current',
    status: 'created',
    status_updated_at: timestamp,
    provider_type: 'manual_assisted_opencv',
    algorithm_id: 'opencv_lines_corners_v1',
    created_by_uid: owner.uid,
    root_job_id: jobRef.id,
    retry_count: 0,
    latest_transition_id: transitionRef.id,
    artifact_refs: [],
    created_at: timestamp,
    updated_at: timestamp,
    schema_version: 1,
  })
  batch.set(transitionRef, {
    transition_id: transitionRef.id,
    project_id: project.id,
    owner_uid: owner.uid,
    job_id: jobRef.id,
    to_status: 'created',
    occurred_at: timestamp,
    actor_type: 'user',
    actor_uid: owner.uid,
    reason_code: 'user_submitted',
    reason_message: 'Reconstruction job created from source image.',
    schema_version: 1,
  })
  await batch.commit()
  updateProjectReconstructionSummary(projectRef, sourceImageId, jobRef.id).catch(() => undefined)
  return jobRef.id
}

async function projectRoomDimensionsExist(firestore: Firestore, projectId: string): Promise<boolean> {
  try {
    return (await getDoc(doc(firestore, 'projects', projectId, 'room_dimensions', 'current'))).exists()
  } catch {
    return false
  }
}

async function updateProjectReconstructionSummary(
  projectRef: ReturnType<typeof doc>,
  sourceImageId: string,
  jobId: string,
) {
  await updateDoc(projectRef, {
    latest_source_image_id: sourceImageId,
    latest_job_id: jobId,
    current_reconstruction_status: 'created',
    current_pipeline_step: 'status',
    pipeline_progress: 12,
    updated_at: serverTimestamp(),
  })
}

export async function saveProjectRoomDimensions(
  projectId: string,
  owner: { uid: string },
  dimensions: RoomDimensionsInput,
  source = 'web_source_form',
) {
  const firestore = getFirestore(roomForgeFirebaseApp())
  const dimensionsRef = doc(firestore, 'projects', projectId, 'room_dimensions', 'current')
  const snapshot = await getDoc(dimensionsRef)
  const existing = snapshot.data()

  await setDoc(dimensionsRef, {
    project_id: projectId,
    owner_uid: owner.uid,
    width_m: roundDimension(dimensions.widthM),
    depth_m: roundDimension(dimensions.depthM),
    height_m: roundDimension(dimensions.heightM),
    unit: 'meters',
    source,
    created_at: existing?.created_at ?? serverTimestamp(),
    updated_at: serverTimestamp(),
    schema_version: 1,
  })
}

type ProjectSnapshot = QueryDocumentSnapshot<DocumentData> | Awaited<ReturnType<typeof getDoc>>

async function latestSourceImageIdForProject(firestore: Firestore, projectId: string) {
  const snapshot = await getDocs(
    query(
      collection(firestore, 'projects', projectId, 'source_images'),
      orderBy('uploaded_at', 'desc'),
      limit(1),
    ),
  )
  const latest = snapshot.docs[0]
  const latestData = latest?.data()
  return latest ? stringValue(latestData?.source_image_id) ?? latest.id : undefined
}

async function ensureDefaultRoomDimensions(firestore: Firestore, projectId: string, ownerUid: string) {
  const dimensionsRef = doc(firestore, 'projects', projectId, 'room_dimensions', 'current')
  const snapshot = await getDoc(dimensionsRef)

  if (snapshot.exists()) {
    return
  }

  await setDoc(dimensionsRef, {
    project_id: projectId,
    owner_uid: ownerUid,
    width_m: 5.2,
    depth_m: 6.0,
    height_m: 2.8,
    unit: 'meters',
    source: 'web_default',
    created_at: serverTimestamp(),
    updated_at: serverTimestamp(),
    schema_version: 1,
  })
}

function roomDimensionsFromData(data: DocumentData): ProjectRoomDimensions {
  return {
    roomDimensionsId: 'current',
    widthM: positiveNumberValue(data.width_m) ?? defaultProjectRoomDimensions.widthM,
    depthM: positiveNumberValue(data.depth_m) ?? defaultProjectRoomDimensions.depthM,
    heightM: positiveNumberValue(data.height_m) ?? defaultProjectRoomDimensions.heightM,
    unit: 'meters',
    source: stringValue(data.source) ?? undefined,
    updatedAt: dateFromFirestore(data.updated_at) ?? undefined,
  }
}

function positiveNumberValue(value: unknown) {
  return typeof value === 'number' && Number.isFinite(value) && value > 0 ? value : null
}

function roundDimension(value: number) {
  return Number(value.toFixed(2))
}

function syncSourceImageSubscriptions(
  firestore: Firestore,
  projectIds: Set<string>,
  subscriptions: Map<string, Unsubscribe>,
  setSourceImageSummaries: Dispatch<SetStateAction<Record<string, SourceImageSummary>>>,
) {
  for (const [projectId, unsubscribe] of subscriptions) {
    if (!projectIds.has(projectId)) {
      unsubscribe()
      subscriptions.delete(projectId)
    }
  }

  setSourceImageSummaries((current) => {
    let changed = false
    const next = { ...current }
    for (const projectId of Object.keys(next)) {
      if (!projectIds.has(projectId)) {
        delete next[projectId]
        changed = true
      }
    }
    return changed ? next : current
  })

  for (const projectId of projectIds) {
    if (subscriptions.has(projectId)) {
      continue
    }

    const sourceImages = query(
      collection(firestore, 'projects', projectId, 'source_images'),
      orderBy('uploaded_at', 'desc'),
    )
    const unsubscribe = onSnapshot(
      sourceImages,
      (snapshot) => {
        const latest = snapshot.docs[0]
        const latestData = latest?.data()
        const latestSourceImageId = latest
          ? stringValue(latestData?.source_image_id) ?? latest.id
          : undefined
        const latestUploadedAt = dateFromFirestore(latestData?.uploaded_at) ?? undefined
        const summary = {
          imageCount: snapshot.size,
          sourceCaptureComplete: snapshot.size >= requiredSourceImageCount,
          latestSourceImageId,
          latestUploadedAt,
        }
        setSourceImageSummaries((current) => ({
          ...current,
          [projectId]: summary,
        }))
        syncProjectProgressFromSourceImages(firestore, projectId, summary).catch(() => {
          // Parent progress metadata is best-effort; source image display still uses the child collection.
        })
      },
      () => {
        setSourceImageSummaries((current) => {
          const next = { ...current }
          delete next[projectId]
          return next
        })
      },
    )
    subscriptions.set(projectId, unsubscribe)
  }
}

async function syncProjectProgressFromSourceImages(
  firestore: Firestore,
  projectId: string,
  summary: SourceImageSummary,
) {
  const projectRef = doc(firestore, 'projects', projectId)
  const snapshot = await getDoc(projectRef)
  if (!snapshot.exists()) {
    return
  }

  const data = snapshot.data()
  const status = parseProjectStatus(data.current_reconstruction_status)
  const latestFloorPlanId = stringValue(data.latest_floor_plan_id) ?? undefined
  const latestLayoutId = stringValue(data.latest_layout_id) ?? undefined
  const nextPipelineStep = pipelineStepForProjectMetadata(
    { status, latestFloorPlanId, latestLayoutId },
    summary.imageCount,
    summary.sourceCaptureComplete,
  )
  const nextProgress = progressForProjectMetadata(
    status,
    summary.imageCount,
    summary.sourceCaptureComplete,
    nextPipelineStep,
  )
  const nextLatestSourceImageId = summary.latestSourceImageId ?? null
  const updates: Record<string, unknown> = {}

  if (numberValue(data.source_image_count) !== summary.imageCount) {
    updates.source_image_count = summary.imageCount
  }
  if (booleanValue(data.source_capture_complete) !== summary.sourceCaptureComplete) {
    updates.source_capture_complete = summary.sourceCaptureComplete
  }
  if ((stringValue(data.latest_source_image_id) ?? null) !== nextLatestSourceImageId) {
    updates.latest_source_image_id = nextLatestSourceImageId
  }
  if (pipelineStepValue(data.current_pipeline_step) !== nextPipelineStep) {
    updates.current_pipeline_step = nextPipelineStep
  }
  if (normalizedProgressValue(data.pipeline_progress) !== nextProgress) {
    updates.pipeline_progress = nextProgress
  }

  if (Object.keys(updates).length === 0) {
    return
  }

  await updateDoc(projectRef, {
    ...updates,
    updated_at: serverTimestamp(),
  })
}

function unsubscribeAll(subscriptions: Map<string, Unsubscribe>) {
  for (const unsubscribe of subscriptions.values()) {
    unsubscribe()
  }
  subscriptions.clear()
}

function isActiveProjectSnapshot(snapshot: ProjectSnapshot) {
  const data = (snapshot.data() ?? {}) as Record<string, unknown>
  return !data.deleted_at
}

function mergeSourceImageSummary(
  project: WorkspaceProject,
  summary: SourceImageSummary | undefined,
): WorkspaceProject {
  if (!summary || summary.imageCount <= 0) {
    return project
  }

  const latestUploadedAtMs = summary.latestUploadedAt?.getTime()
  const parentUpdatedAtMs = project.updatedAtMs ?? 0
  const imageCount = Math.max(project.imageCount, summary.imageCount)
  const latestSourceImageId = summary.latestSourceImageId ?? project.latestSourceImageId
  const summaryIsNewer = latestUploadedAtMs !== undefined && latestUploadedAtMs > parentUpdatedAtMs
  const sourceCaptureComplete = project.sourceCaptureComplete || summary.sourceCaptureComplete
  const currentPipelineStep = pipelineStepForProjectMetadata(project, imageCount, sourceCaptureComplete)
  const summaryProgress = progressForProjectMetadata(project.status, imageCount, sourceCaptureComplete, currentPipelineStep)

  return {
    ...project,
    imageCount,
    sourceCaptureComplete,
    latestSourceImageId,
    updatedAtMs: Math.max(parentUpdatedAtMs, latestUploadedAtMs ?? 0),
    updatedAtLabel: summaryIsNewer && summary.latestUploadedAt
      ? relativeDateLabel(summary.latestUploadedAt)
      : project.updatedAtLabel,
    progress: Math.max(project.progress ?? summaryProgress, summaryProgress),
    currentPipelineStep,
    coverMode: 'image',
    description: project.status === 'created' && project.imageCount === 0
      ? '소스 이미지가 동기화되었습니다. 2D/3D 변환을 실행해 공간 모델을 생성하세요.'
      : project.description,
  }
}

function projectFromSnapshot(snapshot: ProjectSnapshot) {
  const data = (snapshot.data() ?? {}) as Record<string, unknown>
  const status = parseProjectStatus(data.current_reconstruction_status)
  const imageCount = numberValue(data.source_image_count) ?? numberValue(data.image_count) ?? 0
  const sourceCaptureComplete = Boolean(booleanValue(data.source_capture_complete) || imageCount >= requiredSourceImageCount)
  const latestFloorPlanId = stringValue(data.latest_floor_plan_id) ?? undefined
  const latestLayoutId = stringValue(data.latest_layout_id) ?? undefined
  const currentPipelineStep =
    pipelineStepValue(data.current_pipeline_step) ??
    pipelineStepForProjectMetadata({ status, latestFloorPlanId, latestLayoutId }, imageCount, sourceCaptureComplete)
  const progress =
    normalizedProgressValue(data.pipeline_progress) ??
    progressForProjectMetadata(status, imageCount, sourceCaptureComplete, currentPipelineStep)
  const updatedAt = dateFromFirestore(data.updated_at)

  return {
    id: stringValue(data.project_id) ?? snapshot.id,
    name: stringValue(data.name) ?? 'Untitled room',
    status,
    statusLabel: projectLabelForStatus(status),
    tone: projectToneForStatus(status),
    imageCount,
    sourceCaptureComplete,
    currentPipelineStep,
    latestSourceImageId: stringValue(data.latest_source_image_id) ?? undefined,
    latestJobId: stringValue(data.latest_job_id) ?? undefined,
    latestFloorPlanId,
    latestLayoutId,
    updatedAtMs: updatedAt?.getTime(),
    updatedAtLabel: updatedAt ? relativeDateLabel(updatedAt) : '업데이트 시간 없음',
    roomEstimate: stringValue(data.room_estimate_label) ?? undefined,
    progress,
    coverMode: data.latest_source_image_id || imageCount > 0 ? 'image' : 'placeholder',
    description: stringValue(data.description) ?? descriptionForStatus(status),
  } satisfies WorkspaceProject
}

function parseProjectStatus(value: unknown): ProjectStatus {
  if (typeof value === 'string' && allowedStatuses.has(value as ProjectStatus)) {
    return value as ProjectStatus
  }
  return 'created'
}

function progressForStatus(status: ProjectStatus) {
  if (status === 'succeeded') return 100
  if (status === 'processing') return 62
  if (status === 'uploading') return 24
  if (status === 'retrying') return 42
  if (status === 'review_required') return 86
  return undefined
}

function pipelineStepForProjectMetadata(
  project: Pick<WorkspaceProject, 'status'> & Partial<Pick<WorkspaceProject, 'latestFloorPlanId' | 'latestLayoutId'>>,
  imageCount: number,
  sourceCaptureComplete: boolean,
): ProjectPipelineStepKey {
  if (projectReadyForEditor({
    status: project.status,
    imageCount,
    sourceCaptureComplete,
    latestFloorPlanId: project.latestFloorPlanId,
    latestLayoutId: project.latestLayoutId,
  })) {
    return 'editor'
  }
  if (
    project.status === 'uploading' ||
    project.status === 'processing' ||
    project.status === 'retrying' ||
    project.status === 'failed' ||
    project.status === 'timeout' ||
    project.status === 'cancelled'
  ) {
    return 'status'
  }
  return 'source'
}

function progressForProjectMetadata(
  status: ProjectStatus,
  imageCount: number,
  sourceCaptureComplete: boolean,
  currentPipelineStep?: ProjectPipelineStepKey,
) {
  if (currentPipelineStep === 'editor') return 100
  const statusProgress = progressForStatus(status)
  if (statusProgress !== undefined) return statusProgress
  if (sourceCaptureComplete) return 100
  if (imageCount <= 0) return 0
  return Math.min(95, Math.max(12, Math.round((imageCount / requiredSourceImageCount) * 56)))
}

function descriptionForStatus(status: ProjectStatus) {
  if (status === 'succeeded') return '2D/3D 변환이 완료되었고 에디터에서 배치가 가능합니다.'
  if (status === 'review_required') return '변환 후보에 사람 검토가 필요한 항목이 있습니다.'
  if (status === 'processing' || status === 'retrying') return '사진 기반 2D/3D 변환이 진행 중입니다.'
  if (status === 'failed' || status === 'timeout') return '변환을 다시 실행하거나 소스 이미지를 보강해야 합니다.'
  return '앱 가이드 촬영 또는 데스크탑 업로드로 첫 소스 이미지를 추가하세요.'
}

function stringValue(value: unknown) {
  return typeof value === 'string' && value.length > 0 ? value : null
}

function numberValue(value: unknown) {
  return typeof value === 'number' && Number.isFinite(value) ? value : null
}

function booleanValue(value: unknown) {
  return typeof value === 'boolean' ? value : null
}

function pipelineStepValue(value: unknown): ProjectPipelineStepKey | null {
  return value === 'source' || value === 'status' || value === 'editor' ? value : null
}

function normalizedProgressValue(value: unknown) {
  const numeric = numberValue(value)
  if (numeric === null) return null
  return Math.max(0, Math.min(100, Math.round(numeric)))
}

function dateFromFirestore(value: unknown) {
  if (!value) return null
  if (value instanceof Date) return value
  if (typeof value === 'string' || typeof value === 'number') {
    const date = new Date(value)
    return Number.isNaN(date.getTime()) ? null : date
  }
  if (typeof value === 'object' && 'toDate' in value && typeof value.toDate === 'function') {
    return value.toDate() as Date
  }
  return null
}

function relativeDateLabel(date: Date) {
  const diffMs = Date.now() - date.getTime()
  const minutes = Math.max(0, Math.round(diffMs / 60000))
  if (minutes < 1) return '방금 전 업데이트'
  if (minutes < 60) return `${minutes}분 전 업데이트`
  const hours = Math.round(minutes / 60)
  if (hours < 24) return `${hours}시간 전 업데이트`
  return `${Math.round(hours / 24)}일 전 수정`
}
