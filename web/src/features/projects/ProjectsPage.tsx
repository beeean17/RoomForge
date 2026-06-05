import { Link } from 'react-router-dom'

import { ProductShell } from '../../components/shell/ProductShell'
import { StatusPill } from '../../components/ui/StatusPill'
import { demoProjectId, routes } from '../../lib/routes'

const projects = [
  { id: demoProjectId, name: '거실 리노베이션', status: '재구성 완료', tone: 'success' as const },
  { id: 'studio-corner', name: '작업실 코너', status: '소스 보강 필요', tone: 'warning' as const },
  { id: 'bedroom-layout', name: '침실 배치안', status: '편집 중', tone: 'accent' as const },
]

export function ProjectsPage() {
  return (
    <ProductShell active="projects">
      <header className="page-head">
        <div>
          <p className="rf-eyebrow">Workspace</p>
          <h1>내 프로젝트</h1>
          <p>로그인한 사용자의 RoomForge 프로젝트 목록입니다.</p>
        </div>
        <Link className="rf-btn rf-btn--primary ml-auto" to={routes.project(demoProjectId)}>
          새 프로젝트
        </Link>
      </header>
      <section className="card-grid">
        {projects.map((project) => (
          <Link className="route-card" key={project.id} to={routes.project(project.id)}>
            <StatusPill label={project.status} tone={project.tone} />
            <h2 className="mt-4">{project.name}</h2>
            <p>소스 이미지, 재구성 상태, 에디터 진입점을 한 카드에서 확인합니다.</p>
          </Link>
        ))}
      </section>
    </ProductShell>
  )
}
