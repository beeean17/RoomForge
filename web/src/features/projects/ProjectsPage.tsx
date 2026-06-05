import { Grid2X2, List, MoreHorizontal, Plus, SlidersHorizontal } from 'lucide-react'
import { useState } from 'react'
import { Link } from 'react-router-dom'

import { ProductShell } from '../../components/shell/ProductShell'
import { StatusPill } from '../../components/ui/StatusPill'
import { routes } from '../../lib/routes'
import { demoProjects, projectFilters, type WorkspaceProject } from './projectData'

export function ProjectsPage() {
  const [activeFilter, setActiveFilter] = useState<(typeof projectFilters)[number]['key']>('all')

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

      <div className="filter-row" role="group" aria-label="프로젝트 필터">
        {projectFilters.map((filter) => (
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
        <Link className="create-project-card" to={routes.source(demoProjects[0].id)}>
          <span className="create-icon"><Plus size={22} /></span>
          <strong>새 프로젝트</strong>
          <span>사진 업로드 또는 앱 가이드 촬영으로 방을 재구성하세요.</span>
        </Link>

        {demoProjects.map((project) => (
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
