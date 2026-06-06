import { AlertTriangle, Check, Cloud, RefreshCw, RotateCcw } from 'lucide-react'
import { useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'

import { ProductShell } from '../../components/shell/ProductShell'
import { StatePanel } from '../../components/ui/StatePanel'
import { StatusPill } from '../../components/ui/StatusPill'
import { demoProjectId, routes } from '../../lib/routes'
import { useProject } from './projectRepository'

const recoveryRows = [
  ['로컬 draft', '2분 전', 'IndexedDB에 저장된 편집 상태', 'available'],
  ['클라우드 저장본', '5분 전', 'Firestore layout state', 'synced'],
  ['마지막 내보내기', '2일 전', 'PNG floor plan artifact', 'synced'],
] as const

export function DraftRecoveryPage() {
  const projectId = useParams().projectId ?? demoProjectId
  const navigate = useNavigate()
  const { project, status, error } = useProject(projectId)
  const [resolution, setResolution] = useState<'local' | 'cloud' | null>(null)

  if (!project && status === 'loading') {
    return <StatePanel eyebrow="Recovery" title="복구 상태를 불러오는 중입니다" body="로컬 draft와 클라우드 저장본 상태를 확인하고 있습니다." />
  }

  if (!project) {
    return (
      <StatePanel
        eyebrow="Recovery"
        title="프로젝트를 찾을 수 없습니다"
        body={error ?? '요청한 프로젝트가 없거나 현재 계정에 접근 권한이 없습니다.'}
        action={<Link className="rf-btn rf-btn--primary" to={routes.projects}>프로젝트 목록</Link>}
      />
    )
  }

  function resolveDraft(nextResolution: 'local' | 'cloud') {
    setResolution(nextResolution)
    window.setTimeout(() => navigate(`${routes.editor(project!.id)}?recovered=${nextResolution}`), 650)
  }

  return (
    <ProductShell active="recovery" project={project}>
      <header className="page-head">
        <div>
          <p className="rf-eyebrow">Draft recovery</p>
          <h1>복구</h1>
          <p>에디터 자동 저장, 로컬 draft, 클라우드 저장본의 차이를 확인하고 복구합니다.</p>
        </div>
        <Link className="rf-btn rf-btn--primary" to={routes.editor(project.id)}>
          에디터로 돌아가기
        </Link>
      </header>

      <section className="recovery-grid">
        <article className="summary-card recovery-primary-card">
          <span><AlertTriangle size={24} /></span>
          <div>
            <StatusPill label="복구 가능" tone="warning" />
            <h2>최근 로컬 draft가 클라우드 저장본보다 새롭습니다</h2>
            <p>복구하면 현재 에디터 상태가 로컬 draft 기준으로 열리고, 저장 시 Firestore layout state로 동기화됩니다.</p>
            {resolution && (
              <p className="recovery-result">
                {resolution === 'local' ? '로컬 draft를 적용합니다. 에디터로 이동 중입니다.' : '클라우드 저장본을 유지합니다. 에디터로 이동 중입니다.'}
              </p>
            )}
          </div>
          <div className="recovery-actions">
            <button className="rf-btn rf-btn--primary" type="button" onClick={() => resolveDraft('local')} disabled={resolution !== null}>
              <RotateCcw size={15} />
              {resolution === 'local' ? '복구 중' : '로컬 draft 복구'}
            </button>
            <button className="rf-btn" type="button" onClick={() => resolveDraft('cloud')} disabled={resolution !== null}>
              <Cloud size={15} />
              {resolution === 'cloud' ? '유지 중' : '클라우드 저장본 유지'}
            </button>
          </div>
        </article>

        <article className="summary-card">
          <header><h2>저장 상태</h2><RefreshCw size={16} /></header>
          <ul className="recovery-list">
            {recoveryRows.map(([label, time, detail, state]) => (
              <li key={label}>
                <span className={`history-dot history-dot--${state === 'available' ? 'warning' : 'success'}`} />
                <strong>{label}</strong>
                <em>{time}</em>
                <small>{detail}</small>
              </li>
            ))}
          </ul>
        </article>

        <article className="summary-card">
          <header><h2>동기화 정책</h2><Check size={16} /></header>
          <p>에디터는 Firebase SDK를 직접 사용하지 않고, web app shell이 인증·저장·복구 권한을 소유합니다.</p>
          <dl className="metric-dl">
            <dt>로컬 저장소</dt><dd>IndexedDB</dd>
            <dt>시스템 기록</dt><dd>Firestore</dd>
            <dt>내보내기</dt><dd>PNG artifact</dd>
          </dl>
        </article>
      </section>
    </ProductShell>
  )
}
