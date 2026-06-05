import { Check, DoorOpen, Ruler, Smartphone } from 'lucide-react'
import { Link, useParams } from 'react-router-dom'

import { ProductShell } from '../../components/shell/ProductShell'
import { StatePanel } from '../../components/ui/StatePanel'
import { StatusPill } from '../../components/ui/StatusPill'
import { demoProjectId, routes } from '../../lib/routes'
import { useProject } from './projectRepository'

const wallRows = [
  ['북쪽 벽', '5.20 m', '창 1'],
  ['동쪽 벽', '6.00 m', '창 1'],
  ['남쪽 벽', '5.20 m', '문 1'],
  ['서쪽 벽', '6.00 m', '개구부 없음'],
] as const

export function RoomDimensionsPage() {
  const projectId = useParams().projectId ?? demoProjectId
  const { project, status, error } = useProject(projectId)

  if (!project && status === 'loading') {
    return <StatePanel eyebrow="Room" title="방 치수를 불러오는 중입니다" body="저장된 metric room state와 스케일 기준을 확인하고 있습니다." />
  }

  if (!project) {
    return (
      <StatePanel
        eyebrow="Room"
        title="프로젝트를 찾을 수 없습니다"
        body={error ?? '요청한 프로젝트가 없거나 현재 계정에 접근 권한이 없습니다.'}
        action={<Link className="rf-btn rf-btn--primary" to={routes.projects}>프로젝트 목록</Link>}
      />
    )
  }

  return (
    <ProductShell active="room" project={project}>
      <header className="page-head">
        <div>
          <p className="rf-eyebrow">Metric room</p>
          <h1>방 치수</h1>
          <p>소스 이미지와 재구성 결과가 공유하는 meter 단위의 기준 치수입니다.</p>
        </div>
        <div className="workspace-toolbar">
          <StatusPill label="meters" tone="accent" />
          <Link className="rf-btn rf-btn--primary" to={routes.source(project.id)}>
            소스 이미지로 이동
          </Link>
        </div>
      </header>

      <section className="room-dimension-grid">
        <article className="summary-card room-canvas-card">
          <header>
            <h2>평면 기준</h2>
            <StatusPill label="5.2 x 6.0 m" tone="success" />
          </header>
          <div className="room-plan-preview" aria-label="방 치수 평면도">
            <svg viewBox="0 0 520 600" aria-hidden="true">
              <rect x="20" y="20" width="480" height="560" rx="8" />
              <line x1="160" y1="20" x2="300" y2="20" />
              <path d="M20 430a110 110 0 0 0 110 110" />
              <text x="260" y="55">5.20 m</text>
              <text x="462" y="308" transform="rotate(90 462 308)">6.00 m</text>
            </svg>
          </div>
        </article>

        <aside className="room-side-stack">
          <article className="summary-card">
            <header><h2>기준 치수</h2><Ruler size={16} /></header>
            <div className="dimension-field-grid">
              <label><span>너비</span><input defaultValue="5.20" /><small>m</small></label>
              <label><span>깊이</span><input defaultValue="6.00" /><small>m</small></label>
              <label><span>천장</span><input defaultValue="2.80" /><small>m</small></label>
              <label><span>스케일 기준</span><input defaultValue="문 높이 2.04" /><small>m</small></label>
            </div>
          </article>

          <article className="summary-card">
            <header><h2>벽 · 개구부</h2><DoorOpen size={16} /></header>
            <ul className="wall-list">
              {wallRows.map(([label, length, openings]) => (
                <li key={label}>
                  <span><Check size={14} /></span>
                  <strong>{label}</strong>
                  <em>{length}</em>
                  <small>{openings}</small>
                </li>
              ))}
            </ul>
          </article>

          <article className="app-guide-card">
            <span><Smartphone size={20} /></span>
            <div>
              <strong>모바일 앱 촬영으로 보강</strong>
              <p>실측 기준이 부족하면 앱 가이드 촬영으로 빈 각도를 채웁니다.</p>
            </div>
            <a href={`roomforge://projects/${project.id}/capture`}>연결</a>
          </article>
        </aside>
      </section>
    </ProductShell>
  )
}
