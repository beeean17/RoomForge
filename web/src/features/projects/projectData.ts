import { demoProjectId } from '../../lib/routes'

export type ProjectTone = 'success' | 'accent' | 'warning' | 'danger' | 'muted'

export type ProjectStatus = 'created' | 'processing' | 'review_required' | 'succeeded' | 'failed'

export type WorkspaceProject = {
  id: string
  name: string
  status: ProjectStatus
  statusLabel: string
  tone: ProjectTone
  imageCount: number
  updatedAtLabel: string
  roomEstimate?: string
  progress?: number
  coverMode: 'image' | 'placeholder'
  description: string
}

export type SourceDirection = {
  key: 'NW' | 'N' | 'NE' | 'W' | 'ROOM' | 'E' | 'SW' | 'S' | 'SE'
  label: string
  filled: boolean
  quality?: 'ok' | 'warn'
  brightness?: number
}

export type ReconstructionStep = {
  label: string
  state: 'done' | 'active' | 'pending' | 'failed'
  note?: string
}

export const demoProjects: WorkspaceProject[] = [
  {
    id: demoProjectId,
    name: '거실 리노베이션',
    status: 'succeeded',
    statusLabel: '3D 완료',
    tone: 'success',
    imageCount: 24,
    updatedAtLabel: '2일 전 수정',
    roomEstimate: '5.2 x 6.0 m',
    progress: 100,
    coverMode: 'image',
    description: '후보 geometry 확인이 끝났고, 에디터에서 2D/3D 배치가 가능합니다.',
  },
  {
    id: 'bedroom-a',
    name: '침실 A동',
    status: 'processing',
    statusLabel: '재구성 중 62%',
    tone: 'accent',
    imageCount: 18,
    updatedAtLabel: '방금 전 업데이트',
    roomEstimate: '4.8 x 5.4 m',
    progress: 62,
    coverMode: 'image',
    description: '포인트 클라우드 생성 중입니다. 완료되면 상태 화면에서 후보 geometry를 확인할 수 있습니다.',
  },
  {
    id: 'meeting-room',
    name: '사무실 회의실',
    status: 'review_required',
    statusLabel: 'Needs review',
    tone: 'warning',
    imageCount: 16,
    updatedAtLabel: '1일 전',
    roomEstimate: '7.1 x 4.6 m',
    progress: 86,
    coverMode: 'image',
    description: '벽 후보와 창문 후보가 겹쳐 사람 검토가 필요합니다.',
  },
  {
    id: 'studio-room',
    name: '원룸 스튜디오',
    status: 'created',
    statusLabel: '촬영 필요',
    tone: 'muted',
    imageCount: 0,
    updatedAtLabel: '방금 생성됨',
    coverMode: 'placeholder',
    description: '앱 가이드 촬영 또는 데스크탑 업로드로 첫 소스 이미지를 추가하세요.',
  },
  {
    id: 'balcony-extension',
    name: '발코니 확장',
    status: 'succeeded',
    statusLabel: '3D 완료',
    tone: 'success',
    imageCount: 31,
    updatedAtLabel: '5일 전 수정',
    roomEstimate: '6.4 x 3.2 m',
    progress: 100,
    coverMode: 'image',
    description: '스케일 기준과 개구부 추정이 완료된 보관 후보 프로젝트입니다.',
  },
]

export const projectFilters = [
  { key: 'all', label: '전체', count: 6 },
  { key: 'active', label: '진행 중', count: 2 },
  { key: 'review', label: '검토 대기', count: 1 },
  { key: 'done', label: '완료', count: 2 },
  { key: 'archived', label: '보관', count: 0 },
] as const

export const pipelineSteps = [
  { key: 'source', label: '소스' },
  { key: 'status', label: '재구성' },
  { key: 'editor', label: '편집' },
] as const

export const sourceDirections: SourceDirection[] = [
  { key: 'NW', label: 'NW', filled: true, quality: 'ok', brightness: 0.9 },
  { key: 'N', label: 'N', filled: true, quality: 'ok', brightness: 0.85 },
  { key: 'NE', label: 'NE', filled: false },
  { key: 'W', label: 'W', filled: true, quality: 'warn', brightness: 0.6 },
  { key: 'ROOM', label: '거실', filled: true },
  { key: 'E', label: 'E', filled: true, quality: 'ok', brightness: 0.78 },
  { key: 'SW', label: 'SW', filled: false },
  { key: 'S', label: 'S', filled: true, quality: 'ok', brightness: 0.7 },
  { key: 'SE', label: 'SE', filled: true, quality: 'ok', brightness: 0.82 },
]

export const reconstructionSteps: ReconstructionStep[] = [
  { label: '업로드 검증', state: 'done' },
  { label: '특징점 추출', state: 'done' },
  { label: '카메라 정합', state: 'done' },
  { label: '포인트 클라우드', state: 'done' },
  { label: '메시·평면 추출', state: 'done' },
  { label: '후보 geometry', state: 'done' },
]

export function getProject(projectId: string | undefined) {
  return demoProjects.find((project) => project.id === projectId) ?? demoProjects[0]
}

export function getPipelineState(project: WorkspaceProject, current: 'source' | 'status' | 'editor') {
  if (project.status === 'succeeded') {
    return { source: 'done', status: 'done', editor: current === 'editor' ? 'active' : 'pending' } as const
  }
  if (project.status === 'processing' || project.status === 'failed' || project.status === 'review_required') {
    return { source: 'done', status: current === 'status' ? 'active' : 'done', editor: 'pending' } as const
  }
  return { source: current === 'source' ? 'active' : 'pending', status: 'pending', editor: 'pending' } as const
}
