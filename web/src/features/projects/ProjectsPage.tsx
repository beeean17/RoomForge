import { Check, Folder, Grid2X2, List, MoreHorizontal, Pencil, Plus, SlidersHorizontal, Trash2 } from 'lucide-react'
import { useEffect, useMemo, useRef, useState, type FormEvent } from 'react'
import { Link, useNavigate, useSearchParams } from 'react-router-dom'

import { ProductShell } from '../../components/shell/ProductShell'
import { StatusPill } from '../../components/ui/StatusPill'
import { routes } from '../../lib/routes'
import { useAuth } from '../auth/AuthProvider'
import { getProjectFilters, projectReadyForEditor, type ProjectFilterKey, type WorkspaceProject } from './projectData'
import {
  createWorkspaceProject,
  deleteWorkspaceProject,
  renameWorkspaceProject,
  useProjects,
} from './projectRepository'

type ProjectViewMode = 'grid' | 'list'
type ProjectSortKey = 'updated' | 'name' | 'status'
type ProjectScope = 'mine' | 'shared' | 'templates' | 'archive'

const projectSortOptions = [
  { key: 'updated', label: '최근 수정순' },
  { key: 'name', label: '이름순' },
  { key: 'status', label: '상태순' },
] as const

const projectScopeCopy: Record<ProjectScope, { eyebrow: string; title: string; description: string; emptyTitle: string; emptyBody: string }> = {
  mine: {
    eyebrow: 'Workspace',
    title: '내 프로젝트',
    description: '사진에서 시작한 공간 모델, 변환 상태, 편집 진입점을 한 곳에서 관리합니다.',
    emptyTitle: '프로젝트가 없습니다',
    emptyBody: '새 프로젝트를 만들고 첫 소스 이미지를 추가하세요.',
  },
  shared: {
    eyebrow: 'Shared',
    title: '공유됨',
    description: '다른 멤버가 공유한 프로젝트가 여기에 표시됩니다.',
    emptyTitle: '공유된 프로젝트가 없습니다',
    emptyBody: '초대받은 프로젝트가 생기면 이 공간에서 바로 열 수 있습니다.',
  },
  templates: {
    eyebrow: 'Templates',
    title: '템플릿',
    description: '반복해서 쓰는 방 구성과 가구 배치 프리셋을 관리합니다.',
    emptyTitle: '저장된 템플릿이 없습니다',
    emptyBody: '편집기에서 배치를 템플릿으로 저장하면 이 공간에 나타납니다.',
  },
  archive: {
    eyebrow: 'Archive',
    title: '보관함',
    description: '완료되었거나 숨겨둔 프로젝트를 다시 찾아볼 수 있습니다.',
    emptyTitle: '보관된 프로젝트가 없습니다',
    emptyBody: '프로젝트 더보기 메뉴에서 보관한 항목이 이곳에 표시됩니다.',
  },
}

export function ProjectsPage() {
  const auth = useAuth()
  const navigate = useNavigate()
  const [searchParams] = useSearchParams()
  const projectState = useProjects()
  const [demoProjectNames, setDemoProjectNames] = useState<Record<string, string>>({})
  const [deletedDemoProjectIds, setDeletedDemoProjectIds] = useState<Set<string>>(() => new Set())
  const projects = useMemo(
    () =>
      projectState.projects
        .filter((project) => !deletedDemoProjectIds.has(project.id))
        .map((project) => ({
          ...project,
          name: demoProjectNames[project.id] ?? project.name,
        })),
    [deletedDemoProjectIds, demoProjectNames, projectState.projects],
  )
  const scope = parseProjectScope(searchParams.get('scope'))
  const searchQuery = (searchParams.get('q') ?? '').trim().toLowerCase()
  const scopeCopy = projectScopeCopy[scope]
  const filters = getProjectFilters(projects)
  const [activeFilter, setActiveFilter] = useState<ProjectFilterKey>('all')
  const [viewMode, setViewMode] = useState<ProjectViewMode>('grid')
  const [sortKey, setSortKey] = useState<ProjectSortKey>('updated')
  const [sortMenuOpen, setSortMenuOpen] = useState(false)
  const [isCreating, setIsCreating] = useState(false)
  const [createDialogOpen, setCreateDialogOpen] = useState(false)
  const [createProjectName, setCreateProjectName] = useState('')
  const [createError, setCreateError] = useState<string | null>(null)
  const [projectActionError, setProjectActionError] = useState<string | null>(null)
  const [projectActionBusy, setProjectActionBusy] = useState(false)
  const [renameTarget, setRenameTarget] = useState<WorkspaceProject | null>(null)
  const [renameValue, setRenameValue] = useState('')
  const [deleteTarget, setDeleteTarget] = useState<WorkspaceProject | null>(null)
  const sortMenuRef = useRef<HTMLDivElement | null>(null)
  const scopedProjects = scope === 'mine' ? projects : []
  const visibleProjects = sortProjects(scopedProjects.filter((project) => {
    if (activeFilter === 'all') return true
    if (activeFilter === 'active') return ['uploading', 'processing', 'retrying'].includes(project.status)
    if (activeFilter === 'review') return project.status === 'review_required'
    if (activeFilter === 'done') return project.status === 'succeeded'
    return false
  }).filter((project) => {
    if (!searchQuery) return true
    return [project.name, project.description, project.statusLabel, project.roomEstimate ?? '']
      .join(' ')
      .toLowerCase()
      .includes(searchQuery)
  }), sortKey)
  const demoEmptyProjectId = projects.find((project) => project.imageCount === 0)?.id ?? projects[0]?.id

  useEffect(() => {
    if (!sortMenuOpen) {
      return undefined
    }

    const closeOnOutsidePointer = (event: PointerEvent) => {
      if (!sortMenuRef.current?.contains(event.target as Node)) {
        setSortMenuOpen(false)
      }
    }

    window.addEventListener('pointerdown', closeOnOutsidePointer)
    return () => window.removeEventListener('pointerdown', closeOnOutsidePointer)
  }, [sortMenuOpen])

  function openCreateProjectDialog() {
    if (isCreating) {
      return
    }

    setCreateError(null)

    if (auth.isConfigured && auth.status === 'loading') {
      return
    }

    if (auth.isConfigured && auth.status !== 'signed-in') {
      navigate(routes.login)
      return
    }

    setCreateProjectName('')
    setCreateDialogOpen(true)
  }

  async function handleCreateProject(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (isCreating) {
      return
    }

    const nextName = createProjectName.trim()
    if (!nextName) {
      setCreateError('프로젝트 이름을 입력하세요.')
      return
    }

    setCreateError(null)

    setIsCreating(true)
    try {
      if (!auth.isConfigured) {
        if (!demoEmptyProjectId) {
          throw new Error('사용 가능한 데모 프로젝트가 없습니다.')
        }
        setDemoProjectNames((current) => ({ ...current, [demoEmptyProjectId]: nextName }))
        setCreateDialogOpen(false)
        setCreateProjectName('')
        navigate(routes.source(demoEmptyProjectId))
        return
      }

      if (auth.status !== 'signed-in') {
        navigate(routes.login)
        return
      }

      const projectId = await createWorkspaceProject(auth.user, nextName)
      setCreateDialogOpen(false)
      setCreateProjectName('')
      navigate(routes.source(projectId))
    } catch (error) {
      setCreateError(error instanceof Error ? error.message : String(error))
    } finally {
      setIsCreating(false)
    }
  }

  function openRenameDialog(project: WorkspaceProject) {
    setProjectActionError(null)
    setRenameTarget(project)
    setRenameValue(project.name)
  }

  function openDeleteDialog(project: WorkspaceProject) {
    setProjectActionError(null)
    setDeleteTarget(project)
  }

  async function handleRenameProject(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (!renameTarget || projectActionBusy) {
      return
    }

    const nextName = renameValue.trim()
    if (!nextName) {
      setProjectActionError('프로젝트 이름을 입력하세요.')
      return
    }

    setProjectActionBusy(true)
    setProjectActionError(null)
    try {
      if (!auth.isConfigured) {
        setDemoProjectNames((current) => ({ ...current, [renameTarget.id]: nextName }))
      } else if (auth.status === 'signed-in') {
        await renameWorkspaceProject(renameTarget.id, nextName)
      } else {
        navigate(routes.login)
        return
      }
      setRenameTarget(null)
      setRenameValue('')
    } catch (error) {
      setProjectActionError(error instanceof Error ? error.message : String(error))
    } finally {
      setProjectActionBusy(false)
    }
  }

  async function handleDeleteProject() {
    if (!deleteTarget || projectActionBusy) {
      return
    }

    setProjectActionBusy(true)
    setProjectActionError(null)
    try {
      if (!auth.isConfigured) {
        setDeletedDemoProjectIds((current) => new Set([...current, deleteTarget.id]))
      } else if (auth.status === 'signed-in') {
        await deleteWorkspaceProject(deleteTarget.id)
      } else {
        navigate(routes.login)
        return
      }
      setDeleteTarget(null)
    } catch (error) {
      setProjectActionError(error instanceof Error ? error.message : String(error))
    } finally {
      setProjectActionBusy(false)
    }
  }

  return (
    <ProductShell active="projects">
      <header className="page-head workspace-head">
        <div>
          <p className="rf-eyebrow">{scopeCopy.eyebrow}</p>
          <h1>{scopeCopy.title}</h1>
          <p>{scopeCopy.description}</p>
        </div>
        <div className="workspace-toolbar">
          <div className="rf-menu-wrap" ref={sortMenuRef}>
            <button
              className="rf-btn"
              type="button"
              aria-expanded={sortMenuOpen}
              onClick={() => setSortMenuOpen((open) => !open)}
            >
              <SlidersHorizontal size={15} />
              {projectSortOptions.find((option) => option.key === sortKey)?.label}
            </button>
            {sortMenuOpen && (
              <div className="rf-popover rf-popover--right compact-menu" role="menu">
                {projectSortOptions.map((option) => (
                  <button
                    key={option.key}
                    role="menuitem"
                    type="button"
                    onClick={() => {
                      setSortKey(option.key)
                      setSortMenuOpen(false)
                    }}
                  >
                    {sortKey === option.key && <Check size={14} />}
                    {option.label}
                  </button>
                ))}
              </div>
            )}
          </div>
          <div className="view-toggle" role="group" aria-label="보기 방식">
            <button
              className={viewMode === 'grid' ? 'is-active' : ''}
              type="button"
              aria-label="그리드 보기"
              aria-pressed={viewMode === 'grid'}
              onClick={() => setViewMode('grid')}
            >
              <Grid2X2 size={16} />
            </button>
            <button
              className={viewMode === 'list' ? 'is-active' : ''}
              type="button"
              aria-label="리스트 보기"
              aria-pressed={viewMode === 'list'}
              onClick={() => setViewMode('list')}
            >
              <List size={16} />
            </button>
          </div>
        </div>
      </header>

      {projectState.status === 'error' && (
        <section className="data-notice data-notice--danger">
          <strong>프로젝트 데이터를 불러오지 못했습니다</strong>
          <span>{projectState.error}</span>
        </section>
      )}

      {projectState.source === 'demo' && (
        <section className="data-notice">
          <strong>Demo mode</strong>
          <span>Firebase web config가 없어서 샘플 프로젝트로 화면을 확인합니다.</span>
        </section>
      )}

      {createError && (
        <section className="data-notice data-notice--danger">
          <strong>새 프로젝트를 만들지 못했습니다</strong>
          <span>{createError}</span>
        </section>
      )}

      {projectActionError && (
        <section className="data-notice data-notice--danger">
          <strong>프로젝트 작업을 완료하지 못했습니다</strong>
          <span>{projectActionError}</span>
        </section>
      )}

      {searchQuery && (
        <section className="data-notice">
          <strong>검색 적용</strong>
          <span>`{searchParams.get('q')}` 결과 {visibleProjects.length}개</span>
          <Link className="rf-inline-link" to={scope === 'mine' ? routes.projects : `${routes.projects}?scope=${scope}`}>검색 해제</Link>
        </section>
      )}

      {scope === 'mine' && (
        <div className="filter-row" role="group" aria-label="프로젝트 필터">
          {filters.map((filter) => (
            <button
              className={`filter-chip ${activeFilter === filter.key ? 'is-active' : ''}`}
              key={filter.key}
              type="button"
              onClick={() => setActiveFilter(filter.key)}
            >
              {filter.label}
              {filter.count > 0 && <span>{filter.count}</span>}
            </button>
          ))}
        </div>
      )}

      <section className={`project-grid ${viewMode === 'list' ? 'project-grid--list' : ''}`} aria-label="프로젝트 목록">
        {scope === 'mine' && (
          <button
            className="create-project-card"
            type="button"
            onClick={openCreateProjectDialog}
            disabled={isCreating || (auth.isConfigured && auth.status === 'loading')}
          >
            <span className="create-icon"><Plus size={22} /></span>
            <span className="create-copy">
              <strong>{isCreating ? '프로젝트 생성 중' : '새 프로젝트'}</strong>
              <span>빈 프로젝트를 만들고 첫 소스 이미지를 추가하세요.</span>
            </span>
          </button>
        )}

        {visibleProjects.map((project) => (
          <ProjectCard
            key={project.id}
            project={project}
            onRequestDelete={openDeleteDialog}
            onRequestRename={openRenameDialog}
          />
        ))}
      </section>

      {visibleProjects.length === 0 && scope !== 'mine' && (
        <section className="empty-project-panel">
          <span className="create-icon"><Folder size={24} /></span>
          <div>
            <h2>{scopeCopy.emptyTitle}</h2>
            <p>{scopeCopy.emptyBody}</p>
          </div>
          <div className="empty-actions">
            <Link className="rf-btn rf-btn--primary" to={routes.projects}>내 프로젝트로 이동</Link>
          </div>
        </section>
      )}

      {visibleProjects.length === 0 && scope === 'mine' && searchQuery && (
        <section className="empty-project-panel">
          <span className="create-icon"><Folder size={24} /></span>
          <div>
            <h2>검색 결과가 없습니다</h2>
            <p>다른 프로젝트 이름, 설명, 상태로 다시 검색해 보세요.</p>
          </div>
          <div className="empty-actions">
            <Link className="rf-btn rf-btn--primary" to={routes.projects}>검색 해제</Link>
          </div>
        </section>
      )}

      {createDialogOpen && (
        <ProjectCreateDialog
          busy={isCreating}
          value={createProjectName}
          onCancel={() => {
            setCreateDialogOpen(false)
            setCreateProjectName('')
            setCreateError(null)
          }}
          onChange={(value) => {
            setCreateProjectName(value)
            setCreateError(null)
          }}
          onSubmit={handleCreateProject}
        />
      )}

      {renameTarget && (
        <ProjectRenameDialog
          busy={projectActionBusy}
          project={renameTarget}
          value={renameValue}
          onCancel={() => {
            setRenameTarget(null)
            setRenameValue('')
          }}
          onChange={setRenameValue}
          onSubmit={handleRenameProject}
        />
      )}

      {deleteTarget && (
        <ProjectDeleteDialog
          busy={projectActionBusy}
          project={deleteTarget}
          onCancel={() => setDeleteTarget(null)}
          onConfirm={handleDeleteProject}
        />
      )}
    </ProductShell>
  )
}

function parseProjectScope(value: string | null): ProjectScope {
  if (value === 'shared' || value === 'templates' || value === 'archive') {
    return value
  }
  return 'mine'
}

function sortProjects(projects: WorkspaceProject[], sortKey: ProjectSortKey) {
  return [...projects].sort((left, right) => {
    if (sortKey === 'name') {
      return left.name.localeCompare(right.name, 'ko')
    }
    if (sortKey === 'status') {
      return left.statusLabel.localeCompare(right.statusLabel, 'ko') || left.name.localeCompare(right.name, 'ko')
    }
    return (right.updatedAtMs ?? 0) - (left.updatedAtMs ?? 0)
  })
}

function ProjectCard({
  project,
  onRequestDelete,
  onRequestRename,
}: {
  project: WorkspaceProject
  onRequestDelete: (project: WorkspaceProject) => void
  onRequestRename: (project: WorkspaceProject) => void
}) {
  const [menuOpen, setMenuOpen] = useState(false)
  const menuRef = useRef<HTMLDivElement | null>(null)
  const cardStage = projectCardStage(project)
  const editorReady = projectReadyForEditor(project)
  const primaryRoute = editorReady ? routes.editor(project.id) : routes.project(project.id)
  const primaryLabel = editorReady ? `${project.name} 에디터 열기` : `${project.name} 개요 보기`

  useEffect(() => {
    if (!menuOpen) {
      return undefined
    }

    const closeOnOutsidePointer = (event: PointerEvent) => {
      if (!menuRef.current?.contains(event.target as Node)) {
        setMenuOpen(false)
      }
    }

    window.addEventListener('pointerdown', closeOnOutsidePointer)
    return () => window.removeEventListener('pointerdown', closeOnOutsidePointer)
  }, [menuOpen])

  return (
    <article className="project-card">
      <Link className="project-card-media-link" to={primaryRoute} aria-label={primaryLabel}>
        <div className={`project-card-media project-card-media--${project.coverMode}`}>
          <span className="project-card-stage-kicker">{cardStage.kicker}</span>
          <div className="project-card-stage-copy">
            <strong>{cardStage.title}</strong>
            <span>{cardStage.body}</span>
          </div>
          <StatusPill label={project.statusLabel} tone={project.tone} />
          {project.progress !== undefined && project.progress < 100 && (
            <span className="progress-rail" aria-hidden="true">
              <span style={{ width: `${project.progress}%` }} />
            </span>
          )}
        </div>
      </Link>
      <div className="project-card-body">
        <div className="project-card-title">
          <Link className="project-title-link" to={primaryRoute}>
            <h2>{project.name}</h2>
          </Link>
          <div className="project-card-menu-wrap" ref={menuRef}>
            <button
              className="project-card-menu-button"
              type="button"
              aria-label={`${project.name} 작업 메뉴`}
              aria-expanded={menuOpen}
              onClick={() => setMenuOpen((open) => !open)}
            >
              <MoreHorizontal size={18} />
            </button>
            {menuOpen && (
              <div className="project-card-menu" role="menu">
                <Link role="menuitem" to={routes.project(project.id)} onClick={() => setMenuOpen(false)}>
                  개요 보기
                </Link>
                <Link role="menuitem" to={routes.source(project.id)} onClick={() => setMenuOpen(false)}>
                  소스 이미지
                </Link>
                {editorReady ? (
                  <Link role="menuitem" to={routes.editor(project.id)} onClick={() => setMenuOpen(false)}>
                    에디터 열기
                  </Link>
                ) : (
                  <Link role="menuitem" to={routes.source(project.id)} onClick={() => setMenuOpen(false)}>
                    변환 준비
                  </Link>
                )}
                <span className="project-card-menu-separator" />
                <button
                  role="menuitem"
                  type="button"
                  onClick={() => {
                    setMenuOpen(false)
                    onRequestRename(project)
                  }}
                >
                  <Pencil size={14} />
                  이름 변경
                </button>
                <button
                  className="is-danger"
                  role="menuitem"
                  type="button"
                  onClick={() => {
                    setMenuOpen(false)
                    onRequestDelete(project)
                  }}
                >
                  <Trash2 size={14} />
                  삭제
                </button>
              </div>
            )}
          </div>
        </div>
        <Link className="project-card-summary" to={routes.project(project.id)}>
          <p>{project.imageCount ? `이미지 ${project.imageCount} · ${project.updatedAtLabel}` : `앱으로 가이드 촬영 · ${project.updatedAtLabel}`}</p>
          <small>{project.description}</small>
        </Link>
      </div>
    </article>
  )
}

function projectCardStage(project: WorkspaceProject) {
  if (projectReadyForEditor(project)) {
    return {
      kicker: `소스 ${project.imageCount}장`,
      title: '에디터 준비',
      body: '변환 결과 확인 가능',
    }
  }

  if (project.imageCount > 0) {
    return {
      kicker: `소스 ${project.imageCount}장`,
      title: '변환 필요',
      body: '소스 확인 후 worker 실행',
    }
  }

  return {
    kicker: '소스 없음',
    title: '입력 대기',
    body: '사진 업로드 또는 앱 촬영 필요',
  }
}

function ProjectCreateDialog({
  busy,
  value,
  onCancel,
  onChange,
  onSubmit,
}: {
  busy: boolean
  value: string
  onCancel: () => void
  onChange: (value: string) => void
  onSubmit: (event: FormEvent<HTMLFormElement>) => void
}) {
  return (
    <div className="project-action-backdrop" role="presentation">
      <form
        aria-labelledby="project-create-title"
        aria-modal="true"
        className="project-action-dialog project-action-dialog--create"
        role="dialog"
        onSubmit={onSubmit}
      >
        <header>
          <span className="project-action-icon">
            <Plus size={18} />
          </span>
          <div>
            <p className="rf-eyebrow">Workspace</p>
            <h2 id="project-create-title">새 프로젝트</h2>
          </div>
        </header>
        <label className="project-action-field">
          <span>프로젝트 이름</span>
          <input
            autoFocus
            maxLength={80}
            placeholder="예: 거실 리노베이션"
            value={value}
            onChange={(event) => onChange(event.currentTarget.value)}
          />
        </label>
        <p className="project-action-copy">첫 소스 이미지를 추가할 공간 이름을 입력하세요.</p>
        <footer>
          <button className="rf-btn" disabled={busy} type="button" onClick={onCancel}>
            취소
          </button>
          <button className="rf-btn rf-btn--primary" disabled={busy || !value.trim()} type="submit">
            {busy ? '생성 중' : '만들기'}
          </button>
        </footer>
      </form>
    </div>
  )
}

function ProjectRenameDialog({
  busy,
  project,
  value,
  onCancel,
  onChange,
  onSubmit,
}: {
  busy: boolean
  project: WorkspaceProject
  value: string
  onCancel: () => void
  onChange: (value: string) => void
  onSubmit: (event: FormEvent<HTMLFormElement>) => void
}) {
  return (
    <div className="project-action-backdrop" role="presentation">
      <form
        aria-labelledby="project-rename-title"
        aria-modal="true"
        className="project-action-dialog"
        role="dialog"
        onSubmit={onSubmit}
      >
        <header>
          <span className="project-action-icon">
            <Pencil size={18} />
          </span>
          <div>
            <p className="rf-eyebrow">Project settings</p>
            <h2 id="project-rename-title">프로젝트 이름 변경</h2>
          </div>
        </header>
        <label className="project-action-field">
          <span>프로젝트 이름</span>
          <input
            autoFocus
            maxLength={80}
            value={value}
            onChange={(event) => onChange(event.currentTarget.value)}
          />
        </label>
        <p className="project-action-copy">현재 이름: {project.name}</p>
        <footer>
          <button className="rf-btn" disabled={busy} type="button" onClick={onCancel}>
            취소
          </button>
          <button className="rf-btn rf-btn--primary" disabled={busy || !value.trim()} type="submit">
            {busy ? '저장 중' : '저장'}
          </button>
        </footer>
      </form>
    </div>
  )
}

function ProjectDeleteDialog({
  busy,
  project,
  onCancel,
  onConfirm,
}: {
  busy: boolean
  project: WorkspaceProject
  onCancel: () => void
  onConfirm: () => void
}) {
  return (
    <div className="project-action-backdrop" role="presentation">
      <section className="project-action-dialog project-action-dialog--danger" role="dialog" aria-modal="true" aria-labelledby="project-delete-title">
        <header>
          <span className="project-action-icon project-action-icon--danger">
            <Trash2 size={18} />
          </span>
          <div>
            <p className="rf-eyebrow">Danger zone</p>
            <h2 id="project-delete-title">프로젝트 삭제</h2>
          </div>
        </header>
        <p className="project-action-copy">
          <strong>{project.name}</strong> 프로젝트를 삭제합니다. 이 작업은 목록에서 제거되며 되돌릴 수 없습니다.
        </p>
        <footer>
          <button className="rf-btn" disabled={busy} type="button" onClick={onCancel}>
            취소
          </button>
          <button className="danger-button" disabled={busy} type="button" onClick={onConfirm}>
            {busy ? '삭제 중' : '삭제'}
          </button>
        </footer>
      </section>
    </div>
  )
}
