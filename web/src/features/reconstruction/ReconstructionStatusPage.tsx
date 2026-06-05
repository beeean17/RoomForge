import { AlertTriangle, ArrowRight, Check, RotateCcw, X } from 'lucide-react'
import { Link, useParams } from 'react-router-dom'

import { ProductShell } from '../../components/shell/ProductShell'
import { demoProjectId, routes } from '../../lib/routes'
import { getProject, reconstructionSteps, type ReconstructionStep } from '../projects/projectData'

export function ReconstructionStatusPage() {
  const projectId = useParams().projectId ?? demoProjectId
  const project = getProject(projectId)
  const isComplete = project.status === 'succeeded'

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

      <StatusHero projectStatus={project.status} projectId={project.id} />

      <section className="status-grid">
        <article className="summary-card status-steps-card">
          <h2>재구성 단계</h2>
          <ul className="status-steps">
            {stepsFor(project.status).map((step) => (
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
                <a href="#logs">로그</a>
              </li>
            </ul>
          </article>
        </aside>
      </section>
    </ProductShell>
  )
}

function StatusHero({ projectStatus, projectId }: { projectStatus: string; projectId: string }) {
  if (projectStatus === 'processing') {
    return (
      <section className="status-hero status-hero--accent">
        <span className="status-hero-icon is-spinning"><RotateCcw size={24} /></span>
        <div>
          <h2>재구성 중 · 62%</h2>
          <p>포인트 클라우드 생성 중 · 예상 2분 남음</p>
        </div>
        <button className="rf-btn" type="button">취소</button>
        <span className="hero-progress"><span style={{ width: '62%' }} /></span>
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
