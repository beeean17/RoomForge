import { Grid2X2, List, MoreHorizontal, Plus, SlidersHorizontal } from 'lucide-react'
import { useEffect, useRef, useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'

import { ProductShell } from '../../components/shell/ProductShell'
import { StatusPill } from '../../components/ui/StatusPill'
import { routes } from '../../lib/routes'
import { useAuth } from '../auth/AuthProvider'
import { getProjectFilters, type ProjectFilterKey, type WorkspaceProject } from './projectData'
import { createWorkspaceProject, useProjects } from './projectRepository'

type ProjectViewMode = 'grid' | 'list'

export function ProjectsPage() {
  const auth = useAuth()
  const navigate = useNavigate()
  const projectState = useProjects()
  const projects = projectState.projects
  const filters = getProjectFilters(projects)
  const [activeFilter, setActiveFilter] = useState<ProjectFilterKey>('all')
  const [viewMode, setViewMode] = useState<ProjectViewMode>('grid')
  const [isCreating, setIsCreating] = useState(false)
  const [createError, setCreateError] = useState<string | null>(null)
  const visibleProjects = projects.filter((project) => {
    if (activeFilter === 'all') return true
    if (activeFilter === 'active') return ['uploading', 'processing', 'retrying'].includes(project.status)
    if (activeFilter === 'review') return project.status === 'review_required'
    if (activeFilter === 'done') return project.status === 'succeeded'
    return false
  })
  const demoEmptyProjectId = projects.find((project) => project.imageCount === 0)?.id ?? projects[0]?.id

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
          <p className="rf-eyebrow">Workspace</p>
          <h1>내 프로젝트</h1>
          <p>사진에서 시작한 공간 모델, 재구성 상태, 편집 진입점을 한 곳에서 관리합니다.</p>
        </div>
        <div className="workspace-toolbar">
          <button className="rf-btn" type="button">
            <SlidersHorizontal size={15} />
            최근 수정순
          </button>
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

      <section className={`project-grid ${viewMode === 'list' ? 'project-grid--list' : ''}`} aria-label="프로젝트 목록">
        <button className="create-project-card" type="button" onClick={handleCreateProject} disabled={isCreating}>
          <span className="create-icon"><Plus size={22} /></span>
          <span className="create-copy">
            <strong>{isCreating ? '프로젝트 생성 중' : '새 프로젝트'}</strong>
            <span>빈 프로젝트를 만들고 첫 소스 이미지를 추가하세요.</span>
          </span>
        </button>

        {visibleProjects.map((project) => (
          <ProjectCard key={project.id} project={project} />
        ))}
      </section>
    </ProductShell>
  )
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
