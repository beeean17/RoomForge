import { AlertTriangle, ArrowRight, Check, RotateCcw, X } from 'lucide-react'
import { useState } from 'react'
import { Link, useParams, useSearchParams } from 'react-router-dom'

import { ProductShell } from '../../components/shell/ProductShell'
import { StatePanel } from '../../components/ui/StatePanel'
import { demoProjectId, routes } from '../../lib/routes'
import { useAuth } from '../auth/AuthProvider'
import { useLatestOpenCvResultPayload } from '../editor/editorOpenCvResults'
import { useLatestSceneUnderstandingResultPayload } from '../editor/editorSceneUnderstandingResults'
import { useEditorSourceImagePayload } from '../editor/editorSourceImages'
import { reconstructionSteps, type ReconstructionStep } from '../projects/projectData'
import { useProject } from '../projects/projectRepository'
import {
  openCvConversionStageOrder,
  useOpenCvConversionWorker,
  type OpenCvConversionState,
} from './openCvConversionWorker'

export function ReconstructionStatusPage() {
  const projectId = useParams().projectId ?? demoProjectId
  const [searchParams] = useSearchParams()
  const auth = useAuth()
  const { project, status, error } = useProject(projectId)
  const [statusOverride, setStatusOverride] = useState<string | null>(null)
  const [showLogs, setShowLogs] = useState(false)
  const effectiveStatus = statusOverride ?? project?.status
  const requestedConversion = searchParams.get('convert') === '1'
  const forceConversion = searchParams.get('rerun') === '1'
  const sourceImageState = useEditorSourceImagePayload(project)
  const openCvResultState = useLatestOpenCvResultPayload(project)
  const sceneUnderstandingResultState = useLatestSceneUnderstandingResultPayload(project)
  const conversionDataLoading =
    openCvResultState.status === 'loading' ||
    sceneUnderstandingResultState.status === 'loading'
  const hasExistingConversionData =
    openCvResultState.status === 'ready' ||
    sceneUnderstandingResultState.status === 'ready'
  const isConversionActive =
    effectiveStatus === 'created' &&
    requestedConversion &&
    !conversionDataLoading &&
    (forceConversion || !hasExistingConversionData)
  const conversion = useOpenCvConversionWorker({
    active: isConversionActive,
    ownerUid: auth.status === 'signed-in' ? auth.user.uid : undefined,
    project,
    sourceImageState,
  })

  if (!project && status === 'loading') {
    return <StatePanel eyebrow="Conversion" title="변환 상태를 불러오는 중입니다" body="최신 작업 상태와 실행 이력을 확인하고 있습니다." />
  }

  if (!project) {
    return (
      <StatePanel
        eyebrow="Conversion"
        title="프로젝트를 찾을 수 없습니다"
        body={error ?? '요청한 프로젝트가 없거나 현재 계정에 접근 권한이 없습니다.'}
        action={<Link className="rf-btn rf-btn--primary" to={routes.projects}>프로젝트 목록</Link>}
      />
    )
  }

  const isComplete = effectiveStatus === 'succeeded'

  return (
    <ProductShell active="status" project={project}>
      <header className="page-head">
        <div>
          <h1>2D/3D 변환</h1>
          <p>소스 이미지를 에디터에서 사용할 공간 데이터로 준비하는 진행 상황입니다.</p>
        </div>
        {isComplete && (
          <Link className="rf-btn" to={routes.source(project.id)}>
            <RotateCcw size={15} />
            다시 변환
          </Link>
        )}
      </header>

      <StatusHero
        conversion={conversion}
        conversionDataLoading={effectiveStatus === 'created' && conversionDataLoading}
        existingConversionLabel={existingConversionLabel(
          openCvResultState.status,
          sceneUnderstandingResultState.status,
        )}
        hasExistingConversionData={hasExistingConversionData}
        isConversionActive={isConversionActive}
        projectStatus={effectiveStatus}
        projectId={project.id}
        onCancel={() => {
          conversion.cancel()
          setStatusOverride('cancelled')
        }}
      />

      <section className="status-grid">
        <article className="summary-card status-steps-card">
          <h2>변환 단계</h2>
          <ul className="status-steps">
            {stepsFor(effectiveStatus, conversion, isConversionActive, hasExistingConversionData).map((step) => (
              <StatusStepRow key={step.label} step={step} />
            ))}
          </ul>
        </article>

        <aside className="status-side-column">
          {isComplete && (
            <article className="summary-card">
              <h2>변환 결과</h2>
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
            <h2>현재 변환</h2>
            <ul className="history-list">
              <li>
                <span className={`history-dot ${conversion.status === 'complete' ? 'history-dot--success' : ''}`} />
                <strong>{currentConversionTitle({
                  conversionDataLoading,
                  hasExistingConversionData,
                  isConversionActive,
                  phaseLabel: conversion.phaseLabel,
                })}</strong>
                <span>{project.imageCount}장 · {currentConversionDetail({
                  conversionDataLoading,
                  hasExistingConversionData,
                  isConversionActive,
                  conversionDetail: conversion.detail,
                })}</span>
                <small>{isConversionActive ? `${conversion.progress}%` : project.statusLabel}</small>
              </li>
              <li>
                <span className={`history-dot ${sourceImageState.status === 'ready' ? 'history-dot--success' : ''}`} />
                <strong>소스 동기화</strong>
                <span>{sourceImageStatusLabel(sourceImageState.status, project.latestSourceImageId)}</span>
                <button className="inline-action" type="button" onClick={() => setShowLogs((open) => !open)}>로그</button>
              </li>
            </ul>
          </article>
          {showLogs && (
            <article className="summary-card" id="logs">
              <h2>변환 로그</h2>
              <ul className="reconstruction-log">
                <li><strong>source_images</strong><span>{sourceImageStatusLabel(sourceImageState.status, project.latestSourceImageId)}</span></li>
                <li><strong>stored_results</strong><span>{existingConversionLabel(openCvResultState.status, sceneUnderstandingResultState.status)}</span></li>
                <li><strong>opencv_worker</strong><span>{conversion.phaseLabel} · {conversion.detail}</span></li>
                <li><strong>result</strong><span>{conversionResultLabel(conversion)}</span></li>
              </ul>
            </article>
          )}
        </aside>
      </section>
    </ProductShell>
  )
}

function StatusHero({
  conversion,
  conversionDataLoading,
  existingConversionLabel,
  hasExistingConversionData,
  isConversionActive,
  projectStatus,
  projectId,
  onCancel,
}: {
  conversion: OpenCvConversionState
  conversionDataLoading: boolean
  existingConversionLabel: string
  hasExistingConversionData: boolean
  isConversionActive: boolean
  projectStatus: string | undefined
  projectId: string
  onCancel: () => void
}) {
  if (projectStatus === 'processing' || projectStatus === 'retrying' || projectStatus === 'uploading') {
    return (
      <section className="status-hero status-hero--accent">
        <span className="status-hero-icon is-spinning"><RotateCcw size={24} /></span>
        <div>
          <h2>2D/3D 변환 중 · 62%</h2>
          <p>공간 후보 데이터를 준비하고 있습니다.</p>
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
          <h2>변환 취소됨</h2>
          <p>현재 실행 중이던 작업을 중단했습니다. 소스 이미지를 보강한 뒤 다시 실행할 수 있습니다.</p>
        </div>
        <Link className="rf-btn rf-btn--primary" to={routes.source(projectId)}>
          <RotateCcw size={15} />
          다시 변환
        </Link>
      </section>
    )
  }

  if (projectStatus === 'created') {
    if (conversionDataLoading) {
      return (
        <section className="status-hero status-hero--accent">
          <span className="status-hero-icon is-spinning"><RotateCcw size={24} /></span>
          <div>
            <h2>저장된 변환 데이터 확인 중</h2>
            <p>기존 결과가 있으면 worker를 다시 실행하지 않고 바로 에디터로 연결합니다.</p>
          </div>
        </section>
      )
    }

    if (hasExistingConversionData && !isConversionActive) {
      return (
        <section className="status-hero status-hero--success">
          <span className="status-hero-icon"><Check size={24} /></span>
          <div>
            <h2>저장된 변환 데이터가 있습니다</h2>
            <p>{existingConversionLabel} 다시 계산하지 않고 이 결과로 에디터를 열 수 있습니다.</p>
          </div>
          <div className="status-hero-actions">
            <Link className="rf-btn rf-btn--primary" to={routes.editor(projectId)}>
              이미 변환된 데이터로 진행하기
              <ArrowRight size={15} />
            </Link>
            <Link className="rf-btn" to={`${routes.status(projectId)}?convert=1&rerun=1`}>
              다시 변환하기
              <RotateCcw size={15} />
            </Link>
          </div>
        </section>
      )
    }

    if (isConversionActive) {
      const heroTone =
        conversion.status === 'failed'
          ? 'danger'
          : conversion.status === 'complete'
            ? 'success'
            : 'accent'
      const Icon = conversion.status === 'failed' ? AlertTriangle : conversion.status === 'complete' ? Check : RotateCcw
      return (
        <section className={`status-hero status-hero--${heroTone}`}>
          <span className={`status-hero-icon ${conversion.status === 'running' ? 'is-spinning' : ''}`}><Icon size={24} /></span>
          <div>
            <h2>
              {conversion.status === 'complete'
                ? '변환 완료'
                : conversion.status === 'failed'
                  ? '변환 실패'
                  : `${conversion.phaseLabel} · ${conversion.progress}%`}
            </h2>
            <p>{conversion.detail}</p>
          </div>
          {conversion.status === 'running' ? (
            <button className="rf-btn" type="button" onClick={onCancel}>취소</button>
          ) : (
            <Link className="rf-btn rf-btn--primary" to={conversion.status === 'failed' ? routes.source(projectId) : routes.editor(projectId)}>
              {conversion.status === 'failed' ? '소스 확인' : '완료 데이터로 에디터 열기'}
              <ArrowRight size={15} />
            </Link>
          )}
          <span className="hero-progress"><span style={{ width: `${conversion.progress}%` }} /></span>
        </section>
      )
    }

    return (
      <section className="status-hero status-hero--accent">
        <span className="status-hero-icon"><RotateCcw size={24} /></span>
        <div>
          <h2>변환 준비됨</h2>
          <p>소스 이미지와 기준 치수가 연결되었습니다. 변환을 시작하면 완료 후 에디터로 이동합니다.</p>
        </div>
        <Link className="rf-btn rf-btn--primary" to={`${routes.status(projectId)}?convert=1`}>
          2D/3D 변환 시작
          <ArrowRight size={15} />
        </Link>
      </section>
    )
  }

  if (projectStatus === 'review_required') {
    return (
      <section className="status-hero status-hero--danger">
        <span className="status-hero-icon"><AlertTriangle size={24} /></span>
        <div>
          <h2>검토 필요</h2>
          <p>변환 후보가 생성되었지만 사람 검토가 필요합니다. 에디터에서 경계와 후보를 확인하세요.</p>
        </div>
        <Link className="rf-btn rf-btn--primary" to={routes.editor(projectId)}>
          검토 열기
          <ArrowRight size={15} />
        </Link>
      </section>
    )
  }

  if (projectStatus === 'failed' || projectStatus === 'timeout') {
    return (
      <section className="status-hero status-hero--danger">
        <span className="status-hero-icon"><AlertTriangle size={24} /></span>
        <div>
          <h2>변환 실패</h2>
          <p>카메라 정합 단계에서 충분한 겹침을 찾지 못했습니다. 빈 각도를 더 촬영해 보세요.</p>
        </div>
        <Link className="rf-btn rf-btn--primary" to={routes.source(projectId)}>
          <RotateCcw size={15} />
          재시도
        </Link>
      </section>
    )
  }

  if (projectStatus === 'succeeded') {
    return (
      <section className="status-hero status-hero--success">
        <span className="status-hero-icon"><Check size={24} /></span>
        <div>
          <h2>변환 완료</h2>
          <p>편집 가능한 공간이 준비되었습니다.</p>
        </div>
        <Link className="rf-btn rf-btn--primary" to={routes.editor(projectId)}>
          에디터로 이동
          <ArrowRight size={15} />
        </Link>
      </section>
    )
  }

  return (
    <section className="status-hero status-hero--accent">
      <span className="status-hero-icon"><RotateCcw size={24} /></span>
      <div>
        <h2>변환 상태 확인 중</h2>
        <p>최신 작업 상태를 불러온 뒤 다음 단계를 표시합니다.</p>
      </div>
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

function sourceImageStatusLabel(status: string, latestSourceImageId?: string) {
  if (status === 'ready') return '최신 이미지 바이트와 메타데이터가 worker 입력으로 준비되었습니다.'
  if (status === 'loading') return 'Storage에서 최신 소스 이미지를 불러오고 있습니다.'
  if (status === 'error') return '소스 이미지 동기화에 실패했습니다.'
  if (latestSourceImageId) return '최신 이미지 메타데이터는 연결되어 있지만 바이트를 기다리고 있습니다.'
  return '변환할 소스 이미지를 기다리고 있습니다.'
}

function conversionResultLabel(conversion: OpenCvConversionState) {
  if (conversion.status === 'complete') {
    const confidence = typeof conversion.confidence === 'number'
      ? ` · confidence ${conversion.confidence.toFixed(2)}`
      : ''
    return `${conversion.qualityStatus ?? 'quality unknown'}${confidence} · ${conversion.persistence?.label ?? '저장 상태 확인 중'}`
  }
  if (conversion.status === 'failed') {
    return conversion.detail
  }
  return 'OpenCV 결과를 기다리고 있습니다.'
}

function existingConversionLabel(openCvStatus: string, sceneStatus: string): string {
  if (openCvStatus === 'ready' && sceneStatus === 'ready') {
    return 'OpenCV 윤곽과 자동 배치 초안이 저장되어 있습니다.'
  }
  if (sceneStatus === 'ready') {
    return '자동 배치 초안이 저장되어 있습니다.'
  }
  if (openCvStatus === 'ready') {
    return 'OpenCV 윤곽 결과가 저장되어 있습니다.'
  }
  if (openCvStatus === 'loading' || sceneStatus === 'loading') {
    return '저장된 변환 결과를 확인하고 있습니다.'
  }
  if (openCvStatus === 'error' || sceneStatus === 'error') {
    return '저장된 변환 결과 확인 중 일부 오류가 있었습니다.'
  }
  return '저장된 변환 결과가 없습니다.'
}

function currentConversionTitle({
  conversionDataLoading,
  hasExistingConversionData,
  isConversionActive,
  phaseLabel,
}: {
  conversionDataLoading: boolean
  hasExistingConversionData: boolean
  isConversionActive: boolean
  phaseLabel: string
}) {
  if (isConversionActive) return phaseLabel
  if (conversionDataLoading) return '저장 결과 확인'
  if (hasExistingConversionData) return '저장 결과 사용 가능'
  return '변환 대기'
}

function currentConversionDetail({
  conversionDataLoading,
  hasExistingConversionData,
  isConversionActive,
  conversionDetail,
}: {
  conversionDataLoading: boolean
  hasExistingConversionData: boolean
  isConversionActive: boolean
  conversionDetail: string
}) {
  if (isConversionActive) return conversionDetail
  if (conversionDataLoading) return 'worker 실행 전 기존 변환 결과를 확인하고 있습니다.'
  if (hasExistingConversionData) return '저장된 변환 결과로 에디터를 바로 열 수 있습니다.'
  return '소스 이미지와 작업 상태를 기다리고 있습니다.'
}

function stepsFor(
  status: string | undefined,
  conversion: OpenCvConversionState,
  isConversionActive = false,
  hasExistingConversionData = false,
): ReconstructionStep[] {
  if (status === 'created') {
    if (hasExistingConversionData && !isConversionActive) {
      return openCvConversionStageOrder.map((step) => ({
        label: step.label,
        state: 'done',
        note: '저장됨',
      }))
    }

    if (!isConversionActive) {
      return openCvConversionStageOrder.map((step, index) => ({
        label: step.label,
        state: index === 0 ? 'active' : 'pending',
        note: index === 0 ? '변환 대기' : `${step.progress}%`,
      }))
    }

    const activeStage = conversion.failedStage ?? conversion.stage
    const activeIndex = Math.max(
      0,
      openCvConversionStageOrder.findIndex((step) => step.stage === activeStage),
    )
    return openCvConversionStageOrder.map((step, index) => {
      if (conversion.status === 'complete' || index < activeIndex) {
        return { label: step.label, state: 'done', note: `${step.progress}%` }
      }
      if (index === activeIndex) {
        return {
          label: step.label,
          state: conversion.status === 'failed' ? 'failed' : 'active',
          note: conversion.status === 'failed' ? '실패' : `${conversion.progress}%`,
        }
      }
      return { label: step.label, state: 'pending', note: `${step.progress}%` }
    })
  }

  if (status === 'processing' || status === 'retrying' || status === 'uploading') {
    return openCvConversionStageOrder.map((step, index) => {
      if (index === 2) return { label: step.label, state: 'active', note: '진행 중' }
      if (index > 2) return { label: step.label, state: 'pending', note: `${step.progress}%` }
      return { label: step.label, state: 'done', note: `${step.progress}%` }
    })
  }

  if (status === 'review_required') {
    return reconstructionSteps.map((step, index) => {
      if (index === reconstructionSteps.length - 1) return { ...step, state: 'active', note: '검토 필요' }
      return step
    })
  }

  if (status === 'failed' || status === 'timeout') {
    return reconstructionSteps.map((step, index) => {
      if (index === 2) return { ...step, state: 'failed', note: '정합 실패' }
      if (index > 2) return { ...step, state: 'pending' }
      return step
    })
  }

  return reconstructionSteps
}
