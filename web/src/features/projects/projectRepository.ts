import {
  collection,
  doc,
  getDoc,
  getFirestore,
  onSnapshot,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  where,
  type DocumentData,
  type QueryDocumentSnapshot,
  type Unsubscribe,
} from 'firebase/firestore'
import { useEffect, useMemo, useState } from 'react'

import { useAuth } from '../auth/AuthProvider'
import { roomForgeFirebaseApp } from '../../firebase/config'
import {
  demoProjects,
  projectLabelForStatus,
  projectToneForStatus,
  type ProjectStatus,
  type WorkspaceProject,
} from './projectData'

type ProjectDataState = {
  status: 'loading' | 'ready' | 'error'
  source: 'firebase' | 'demo'
  projects: WorkspaceProject[]
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

export function useProjects(): ProjectDataState {
  const auth = useAuth()
  const [state, setState] = useState<ProjectDataState>({
    status: auth.isConfigured ? 'loading' : 'ready',
    source: auth.isConfigured ? 'firebase' : 'demo',
    projects: auth.isConfigured ? [] : demoProjects,
    error: null,
  })

  useEffect(() => {
    if (!auth.isConfigured) {
      setState({ status: 'ready', source: 'demo', projects: demoProjects, error: null })
      return undefined
    }

    if (auth.status === 'loading') {
      setState({ status: 'loading', source: 'firebase', projects: [], error: null })
      return undefined
    }

    if (auth.status !== 'signed-in') {
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
        setState({
          status: 'ready',
          source: 'firebase',
          projects: snapshot.docs.map(projectFromSnapshot),
          error: null,
        })
      },
      (error) => {
        setState({
          status: 'error',
          source: 'firebase',
          projects: [],
          error: error.message,
        })
      },
    )

    return () => unsubscribe?.()
  }, [auth])

  return state
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
        setRemoteProject(snapshot.exists() ? projectFromSnapshot(snapshot) : null)
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

export async function createWorkspaceProject(owner: { uid: string }) {
  const firestore = getFirestore(roomForgeFirebaseApp())
  const projectRef = doc(collection(firestore, 'projects'))

  await setDoc(projectRef, {
    project_id: projectRef.id,
    owner_uid: owner.uid,
    name: '새 프로젝트',
    description: '첫 소스 이미지를 추가하면 공간 재구성을 시작할 수 있습니다.',
    schema_version: 1,
    created_at: serverTimestamp(),
    updated_at: serverTimestamp(),
  })

  return projectRef.id
}

function projectFromSnapshot(snapshot: QueryDocumentSnapshot<DocumentData> | Awaited<ReturnType<typeof getDoc>>) {
  const data = (snapshot.data() ?? {}) as Record<string, unknown>
  const status = parseProjectStatus(data.current_reconstruction_status)
  const imageCount = numberValue(data.source_image_count) ?? numberValue(data.image_count) ?? 0
  const updatedAt = dateFromFirestore(data.updated_at)

  return {
    id: stringValue(data.project_id) ?? snapshot.id,
    name: stringValue(data.name) ?? 'Untitled room',
    status,
    statusLabel: projectLabelForStatus(status),
    tone: projectToneForStatus(status),
    imageCount,
    latestSourceImageId: stringValue(data.latest_source_image_id) ?? undefined,
    latestJobId: stringValue(data.latest_job_id) ?? undefined,
    updatedAtLabel: updatedAt ? relativeDateLabel(updatedAt) : '업데이트 시간 없음',
    roomEstimate: stringValue(data.room_estimate_label) ?? undefined,
    progress: progressForStatus(status),
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

function descriptionForStatus(status: ProjectStatus) {
  if (status === 'succeeded') return '재구성이 완료되었고 에디터에서 2D/3D 배치가 가능합니다.'
  if (status === 'review_required') return '재구성 후보에 사람 검토가 필요한 항목이 있습니다.'
  if (status === 'processing' || status === 'retrying') return '사진 기반 공간 재구성이 진행 중입니다.'
  if (status === 'failed' || status === 'timeout') return '재구성을 다시 실행하거나 소스 이미지를 보강해야 합니다.'
  return '앱 가이드 촬영 또는 데스크탑 업로드로 첫 소스 이미지를 추가하세요.'
}

function stringValue(value: unknown) {
  return typeof value === 'string' && value.length > 0 ? value : null
}

function numberValue(value: unknown) {
  return typeof value === 'number' && Number.isFinite(value) ? value : null
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
