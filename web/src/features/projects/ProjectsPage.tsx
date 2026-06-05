import { Grid2X2, List, MoreHorizontal, Plus, SlidersHorizontal } from 'lucide-react'
import { useState } from 'react'
import { Link } from 'react-router-dom'

import { ProductShell } from '../../components/shell/ProductShell'
import { StatusPill } from '../../components/ui/StatusPill'
import { routes } from '../../lib/routes'
import { demoProjectId } from '../../lib/routes'
import { getProjectFilters, type ProjectFilterKey, type WorkspaceProject } from './projectData'
import { useProjects } from './projectRepository'

export function ProjectsPage() {
  const projectState = useProjects()
  const projects = projectState.projects
  const filters = getProjectFilters(projects)
  const [activeFilter, setActiveFilter] = useState<ProjectFilterKey>('all')
  const visibleProjects = projects.filter((project) => {
    if (activeFilter === 'all') return true
    if (activeFilter === 'active') return ['uploading', 'processing', 'retrying'].includes(project.status)
    if (activeFilter === 'review') return project.status === 'review_required'
    if (activeFilter === 'done') return project.status === 'succeeded'
    return false
  })
  const firstProjectId = projects[0]?.id ?? demoProjectId

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
            <button className="is-active" type="button" aria-label="그리드 보기" aria-pressed="true"><Grid2X2 size={16} /></button>
            <button type="button" aria-label="리스트 보기" aria-pressed="false"><List size={16} /></button>
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

      <section className="project-grid" aria-label="프로젝트 목록">
        <Link className="create-project-card" to={routes.source(firstProjectId)}>
          <span className="create-icon"><Plus size={22} /></span>
          <strong>새 프로젝트</strong>
          <span>사진 업로드 또는 앱 가이드 촬영으로 방을 재구성하세요.</span>
        </Link>

        {visibleProjects.map((project) => (
          <ProjectCard key={project.id} project={project} />
        ))}
      </section>
    </ProductShell>
  )
}

function ProjectCard({ project }: { project: WorkspaceProject }) {
  return (
    <Link className="project-card" to={routes.project(project.id)}>
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
      <div className="project-card-body">
        <div className="project-card-title">
          <h2>{project.name}</h2>
          <span aria-label="더보기"><MoreHorizontal size={18} /></span>
        </div>
        <p>{project.imageCount ? `이미지 ${project.imageCount} · ${project.updatedAtLabel}` : `앱으로 가이드 촬영 · ${project.updatedAtLabel}`}</p>
        <small>{project.description}</small>
      </div>
    </Link>
  )
}
