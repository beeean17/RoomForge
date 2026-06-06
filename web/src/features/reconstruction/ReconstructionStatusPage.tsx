import { AlertTriangle, ArrowRight, Check, RotateCcw, X } from 'lucide-react'
import { useState } from 'react'
import { Link, useParams } from 'react-router-dom'

import { ProductShell } from '../../components/shell/ProductShell'
import { StatePanel } from '../../components/ui/StatePanel'
import { demoProjectId, routes } from '../../lib/routes'
import { reconstructionSteps, type ReconstructionStep } from '../projects/projectData'
import { useProject } from '../projects/projectRepository'

export function ReconstructionStatusPage() {
  const projectId = useParams().projectId ?? demoProjectId
  const { project, status, error } = useProject(projectId)
  const [statusOverride, setStatusOverride] = useState<string | null>(null)
  const [showLogs, setShowLogs] = useState(false)

  if (!project && status === 'loading') {
    return <StatePanel eyebrow="Reconstruction" title="재구성 상태를 불러오는 중입니다" body="최신 작업 상태와 실행 이력을 확인하고 있습니다." />
  }

  if (!project) {
    return (
      <StatePanel
        eyebrow="Reconstruction"
        title="프로젝트를 찾을 수 없습니다"
        body={error ?? '요청한 프로젝트가 없거나 현재 계정에 접근 권한이 없습니다.'}
        action={<Link className="rf-btn rf-btn--primary" to={routes.projects}>프로젝트 목록</Link>}
      />
    )
  }

  const effectiveStatus = statusOverride ?? project.status
  const isComplete = effectiveStatus === 'succeeded'

  return (
    <ProductShell active="status" project={project}>
      <header className="page-head">
        <div>
          <h1>재구성 상태</h1>
          <p>업로드한 사진으로 3D 공간을 재구성하는 작업의 진행 상황입니다.</p>
        </div>
        {isComplete && (
          <Link className="rf-btn" to={routes.source(project.id)}>
            <RotateCcw size={15} />
            재구성 다시 실행
          </Link>
        )}
      </header>

      <StatusHero projectStatus={effectiveStatus} projectId={project.id} onCancel={() => setStatusOverride('cancelled')} />

      <section className="status-grid">
        <article className="summary-card status-steps-card">
          <h2>재구성 단계</h2>
          <ul className="status-steps">
            {stepsFor(effectiveStatus).map((step) => (
              <StatusStepRow key={step.label} step={step} />
            ))}
          </ul>
        </article>

        <aside className="status-side-column">
          {isComplete && (
            <article className="summary-card">
              <h2>재구성 결과</h2>
              <dl className="metric-dl">
                <dt>사용 이미지</dt><dd>17 / 18</dd>
                <dt>후보 면</dt><dd>12</dd>
                <dt>개구부</dt><dd>문 1 · 창 2</dd>
                <dt>스케일 기준</dt><dd>문 높이 2.04 m</dd>
                <dt>포인트 수</dt><dd>1.2M</dd>
              </dl>
            </article>
          )}
          <article className="summary-card">
            <h2>실행 이력</h2>
            <ul className="history-list">
              <li>
                <span className="history-dot history-dot--success" />
                <strong>시도 #2</strong>
                <span>완료 · 2일 전 · 4분</span>
                <small>현재</small>
              </li>
              <li>
                <span className="history-dot history-dot--danger" />
                <strong>시도 #1</strong>
                <span>실패 · 2일 전 · 정합 단계</span>
                <button className="inline-action" type="button" onClick={() => setShowLogs((open) => !open)}>로그</button>
              </li>
            </ul>
          </article>
          {showLogs && (
            <article className="summary-card" id="logs">
              <h2>실패 로그</h2>
              <ul className="reconstruction-log">
                <li><strong>camera_alignment</strong><span>인접 이미지 겹침이 22%로 기준값보다 낮습니다.</span></li>
                <li><strong>feature_matching</strong><span>오른쪽 창 주변 반사 영역에서 특징점 신뢰도가 낮습니다.</span></li>
                <li><strong>next_action</strong><span>NE/SW 각도를 보강 촬영한 뒤 재구성을 다시 실행하세요.</span></li>
              </ul>
            </article>
          )}
        </aside>
      </section>
    </ProductShell>
  )
}

function StatusHero({ projectStatus, projectId, onCancel }: { projectStatus: string; projectId: string; onCancel: () => void }) {
  if (projectStatus === 'processing') {
    return (
      <section className="status-hero status-hero--accent">
        <span className="status-hero-icon is-spinning"><RotateCcw size={24} /></span>
        <div>
          <h2>재구성 중 · 62%</h2>
          <p>포인트 클라우드 생성 중 · 예상 2분 남음</p>
        </div>
        <button className="rf-btn" type="button" onClick={onCancel}>취소</button>
        <span className="hero-progress"><span style={{ width: '62%' }} /></span>
      </section>
    )
  }

  if (projectStatus === 'cancelled') {
    return (
      <section className="status-hero status-hero--danger">
        <span className="status-hero-icon"><X size={24} /></span>
        <div>
          <h2>재구성 취소됨</h2>
          <p>현재 실행 중이던 작업을 중단했습니다. 소스 이미지를 보강한 뒤 다시 실행할 수 있습니다.</p>
        </div>
        <Link className="rf-btn rf-btn--primary" to={routes.source(projectId)}>
          <RotateCcw size={15} />
          다시 실행
        </Link>
      </section>
    )
  }

  if (projectStatus === 'failed') {
    return (
      <section className="status-hero status-hero--danger">
        <span className="status-hero-icon"><AlertTriangle size={24} /></span>
        <div>
          <h2>재구성 실패</h2>
          <p>카메라 정합 단계에서 충분한 겹침을 찾지 못했습니다. 빈 각도를 더 촬영해 보세요.</p>
        </div>
        <Link className="rf-btn rf-btn--primary" to={routes.source(projectId)}>
          <RotateCcw size={15} />
          재시도
        </Link>
      </section>
    )
  }

  return (
    <section className="status-hero status-hero--success">
      <span className="status-hero-icon"><Check size={24} /></span>
      <div>
        <h2>재구성 완료</h2>
        <p>17장으로 약 4분 소요 · 2일 전 · 편집 가능한 공간 준비됨</p>
      </div>
      <Link className="rf-btn rf-btn--primary" to={routes.editor(projectId)}>
        에디터로 이동
        <ArrowRight size={15} />
      </Link>
    </section>
  )
}

function StatusStepRow({ step }: { step: ReconstructionStep }) {
  return (
    <li className={`status-step status-step--${step.state}`}>
      <span>
        {step.state === 'done' && <Check size={14} />}
        {step.state === 'failed' && <X size={14} />}
        {step.state === 'active' && <RotateCcw size={14} />}
      </span>
      <strong>{step.label}</strong>
      {step.note && <small>{step.note}</small>}
    </li>
  )
}

function stepsFor(status: string): ReconstructionStep[] {
  if (status === 'processing') {
    return reconstructionSteps.map((step, index) => {
      if (index === 3) return { ...step, state: 'active', note: '진행 중' }
      if (index > 3) return { ...step, state: 'pending' }
      return step
    })
  }

  if (status === 'failed') {
    return reconstructionSteps.map((step, index) => {
      if (index === 2) return { ...step, state: 'failed', note: '정합 실패' }
      if (index > 2) return { ...step, state: 'pending' }
      return step
    })
  }

  return reconstructionSteps
}
