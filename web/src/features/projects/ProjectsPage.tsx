import { Check, Folder, Grid2X2, List, MoreHorizontal, Plus, SlidersHorizontal } from 'lucide-react'
import { useEffect, useRef, useState } from 'react'
import { Link, useNavigate, useSearchParams } from 'react-router-dom'

import { ProductShell } from '../../components/shell/ProductShell'
import { StatusPill } from '../../components/ui/StatusPill'
import { routes } from '../../lib/routes'
import { useAuth } from '../auth/AuthProvider'
import { getProjectFilters, type ProjectFilterKey, type WorkspaceProject } from './projectData'
import { createWorkspaceProject, useProjects } from './projectRepository'

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
    description: '사진에서 시작한 공간 모델, 재구성 상태, 편집 진입점을 한 곳에서 관리합니다.',
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
  const projects = projectState.projects
  const scope = parseProjectScope(searchParams.get('scope'))
  const searchQuery = (searchParams.get('q') ?? '').trim().toLowerCase()
  const scopeCopy = projectScopeCopy[scope]
  const filters = getProjectFilters(projects)
  const [activeFilter, setActiveFilter] = useState<ProjectFilterKey>('all')
  const [viewMode, setViewMode] = useState<ProjectViewMode>('grid')
  const [sortKey, setSortKey] = useState<ProjectSortKey>('updated')
  const [sortMenuOpen, setSortMenuOpen] = useState(false)
  const [isCreating, setIsCreating] = useState(false)
  const [createError, setCreateError] = useState<string | null>(null)
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

  async function handleCreateProject() {
    if (isCreating) {
      return
    }

    setCreateError(null)

    if (!auth.isConfigured) {
      if (demoEmptyProjectId) {
        navigate(routes.source(demoEmptyProjectId))
      }
      return
    }

    if (auth.status !== 'signed-in') {
      navigate(routes.login)
      return
    }

    setIsCreating(true)
    try {
      const projectId = await createWorkspaceProject(auth.user)
      navigate(routes.source(projectId))
    } catch (error) {
      setCreateError(error instanceof Error ? error.message : String(error))
    } finally {
      setIsCreating(false)
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
          <button className="create-project-card" type="button" onClick={handleCreateProject} disabled={isCreating}>
            <span className="create-icon"><Plus size={22} /></span>
            <span className="create-copy">
              <strong>{isCreating ? '프로젝트 생성 중' : '새 프로젝트'}</strong>
              <span>빈 프로젝트를 만들고 첫 소스 이미지를 추가하세요.</span>
            </span>
          </button>
        )}

        {visibleProjects.map((project) => (
          <ProjectCard key={project.id} project={project} />
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
    return 0
  })
}

function ProjectCard({ project }: { project: WorkspaceProject }) {
  const [menuOpen, setMenuOpen] = useState(false)
  const menuRef = useRef<HTMLDivElement | null>(null)

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
      <Link className="project-card-media-link" to={routes.project(project.id)} aria-label={`${project.name} 개요 보기`}>
        <div className={`project-card-media project-card-media--${project.coverMode}`}>
          {project.coverMode === 'image' ? (
            <img src="/assets/room.png" alt="" />
          ) : (
            <span className="placeholder-camera">촬영 대기</span>
          )}
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
          <Link className="project-title-link" to={routes.project(project.id)}>
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
                <Link role="menuitem" to={routes.editor(project.id)} onClick={() => setMenuOpen(false)}>
                  에디터 열기
                </Link>
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
