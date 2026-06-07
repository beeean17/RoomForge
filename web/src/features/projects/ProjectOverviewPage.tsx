import { ArrowRight, Check, MoreHorizontal, Pencil, Plus } from 'lucide-react'
import { useEffect, useRef, useState } from 'react'
import { Link, useParams } from 'react-router-dom'

import { ProductShell } from '../../components/shell/ProductShell'
import { StatePanel } from '../../components/ui/StatePanel'
import { StatusPill } from '../../components/ui/StatusPill'
import { demoProjectId, routes } from '../../lib/routes'
import { getPipelineState, pipelineSteps, projectReadyForEditor, type WorkspaceProject } from './projectData'
import { useProject } from './projectRepository'

export function ProjectOverviewPage() {
  const projectId = useParams().projectId ?? demoProjectId
  const { project, status, error } = useProject(projectId)
  const [displayName, setDisplayName] = useState('')
  const [nameDraft, setNameDraft] = useState('')
  const [isEditingName, setIsEditingName] = useState(false)
  const [moreOpen, setMoreOpen] = useState(false)
  const moreMenuRef = useRef<HTMLDivElement | null>(null)

  useEffect(() => {
    if (project?.name) {
      setDisplayName(project.name)
      setNameDraft(project.name)
    }
  }, [project?.name])

  useEffect(() => {
    if (!moreOpen) {
      return undefined
    }

    const closeOnOutsidePointer = (event: PointerEvent) => {
      if (!moreMenuRef.current?.contains(event.target as Node)) {
        setMoreOpen(false)
      }
    }

    window.addEventListener('pointerdown', closeOnOutsidePointer)
    return () => window.removeEventListener('pointerdown', closeOnOutsidePointer)
  }, [moreOpen])

  if (!project && status === 'loading') {
    return <StatePanel eyebrow="Workspace" title="프로젝트를 불러오는 중입니다" body="Firebase에서 소유 프로젝트와 최신 상태를 확인하고 있습니다." />
  }

  if (!project) {
    return (
      <StatePanel
        eyebrow="Workspace"
        title="프로젝트를 찾을 수 없습니다"
        body={error ?? '요청한 프로젝트가 없거나 현재 계정에 접근 권한이 없습니다.'}
        action={<Link className="rf-btn rf-btn--primary" to={routes.projects}>프로젝트 목록</Link>}
      />
    )
  }

  const pipelineState = getPipelineState(project, 'status')
  const visibleName = displayName || project.name
  const workflow = overviewWorkflow(project)

  function saveProjectName(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const nextName = nameDraft.trim()
    if (nextName) {
      setDisplayName(nextName)
      setNameDraft(nextName)
    }
    setIsEditingName(false)
  }

  return (
    <ProductShell active="overview" project={project}>
      <header className="page-head project-head">
        <div className="min-w-0">
          <div className="project-title-row">
            {isEditingName ? (
              <form className="project-title-edit" onSubmit={saveProjectName}>
                <input
                  aria-label="프로젝트 이름"
                  autoFocus
                  value={nameDraft}
                  onChange={(event) => setNameDraft(event.target.value)}
                />
                <button className="rf-btn rf-btn--primary" type="submit">저장</button>
                <button
                  className="rf-btn"
                  type="button"
                  onClick={() => {
                    setNameDraft(visibleName)
                    setIsEditingName(false)
                  }}
                >
                  취소
                </button>
              </form>
            ) : (
              <>
                <h1>{visibleName}</h1>
                <button className="icon-button" type="button" title="이름 편집" aria-label="이름 편집" onClick={() => setIsEditingName(true)}>
                  <Pencil size={15} />
                </button>
              </>
            )}
          </div>
          <div className="project-meta">
            <StatusPill label={project.statusLabel} tone={project.tone} />
            <span>이미지 {project.imageCount}</span>
            {project.roomEstimate && <span>방 추정 {project.roomEstimate}</span>}
            <span>{project.updatedAtLabel}</span>
          </div>
        </div>
        <div className="rf-menu-wrap ml-auto" ref={moreMenuRef}>
          <button
            className="icon-button"
            type="button"
            aria-label="더보기"
            aria-expanded={moreOpen}
            onClick={() => setMoreOpen((open) => !open)}
          >
            <MoreHorizontal size={18} />
          </button>
          {moreOpen && (
            <div className="rf-popover rf-popover--right compact-menu" role="menu">
              <Link role="menuitem" to={routes.source(project.id)} onClick={() => setMoreOpen(false)}>소스 이미지</Link>
              <Link role="menuitem" to={routes.status(project.id)} onClick={() => setMoreOpen(false)}>변환 상태</Link>
              <Link role="menuitem" to={routes.recovery(project.id)} onClick={() => setMoreOpen(false)}>복구 상태</Link>
              {projectReadyForEditor(project) ? (
                <Link role="menuitem" to={routes.editor(project.id)} onClick={() => setMoreOpen(false)}>에디터 열기</Link>
              ) : (
                <Link role="menuitem" to={routes.source(project.id)} onClick={() => setMoreOpen(false)}>변환 준비</Link>
              )}
            </div>
          )}
        </div>
      </header>

      <section className="pipeline-card" aria-label="프로젝트 진행 단계">
        <div className="pipeline-stepper">
          {pipelineSteps.map((step, index) => {
            const state = pipelineState[step.key]
            return (
              <span className="pipeline-item" key={step.key}>
                <span className={`pipeline-node pipeline-node--${state}`}>
                  {state === 'done' ? <Check size={13} /> : <span />}
                </span>
                <span>{step.label}</span>
                {index < pipelineSteps.length - 1 && <i />}
              </span>
            )
          })}
        </div>
      </section>

      <section className="project-overview-grid">
        <div className="project-main-column">
          <article className="workflow-card">
            <header>
              <p className="rf-eyebrow">{workflow.eyebrow}</p>
              <StatusPill label={project.statusLabel} tone={project.tone} />
            </header>
            <div>
              <h2>{workflow.title}</h2>
              <p>{workflow.body}</p>
            </div>
            <div className="workflow-flow" aria-label="소스 입력부터 에디터까지의 작업 흐름">
              {['소스 입력', '2D/3D 변환', '에디터'].map((label, index) => (
                <span className={index === workflow.activeIndex ? 'is-active' : index < workflow.activeIndex ? 'is-done' : ''} key={label}>
                  {index < workflow.activeIndex ? <Check size={13} /> : <i />}
                  {label}
                </span>
              ))}
            </div>
            <div className="workflow-actions">
              <Link className="rf-btn rf-btn--primary" to={workflow.primaryTo}>
                {workflow.primaryLabel}
                <ArrowRight size={15} />
              </Link>
              {workflow.secondaryTo && (
                <Link className="rf-btn" to={workflow.secondaryTo}>
                  {workflow.secondaryLabel}
                </Link>
              )}
            </div>
          </article>

          <article className="next-step-card">
            <p className="rf-eyebrow">다음 단계</p>
            <div>
              <h2>{workflow.nextTitle}</h2>
              <p>{workflow.nextBody}</p>
            </div>
            <Link className="rf-btn rf-btn--primary" to={workflow.primaryTo}>
              {workflow.primaryLabel}
              <ArrowRight size={15} />
            </Link>
          </article>
        </div>

        <aside className="project-side-column">
          <article className="summary-card">
            <header>
              <h2>소스 이미지</h2>
              <span>{project.imageCount}장</span>
              <Link to={routes.source(project.id)}>전체 보기</Link>
            </header>
            <div className="source-count-card">
              <strong>{project.imageCount}</strong>
              <span>등록된 소스 이미지</span>
              <Link className="rf-btn" to={routes.source(project.id)}>
                <Plus size={16} />
                관리
              </Link>
            </div>
          </article>

          <article className="summary-card">
            <header>
              <h2>변환 상태</h2>
              <Link to={routes.status(project.id)}>상세</Link>
            </header>
            <div className="status-summary-row">
              <span className={`status-icon status-icon--${project.tone}`}>
                <Check size={16} />
              </span>
              <span>
                <strong>{project.status === 'succeeded' ? '완료됨' : project.statusLabel}</strong>
                <small>{project.updatedAtLabel} · 약 4분 소요</small>
              </span>
            </div>
            <dl className="metric-dl">
              <dt>후보 면</dt><dd>12</dd>
              <dt>개구부</dt><dd>문 1 · 창 2</dd>
              <dt>스케일 기준</dt><dd>문 높이 2.04 m</dd>
            </dl>
          </article>
        </aside>
      </section>

      {project.status === 'created' && !projectReadyForEditor(project) && (
        <section className="empty-project-panel">
          <span className="create-icon"><Plus size={24} /></span>
          <div>
            <h2>방을 변환할 사진을 추가하세요</h2>
            <p>사진을 업로드하거나 앱의 가이드 촬영으로 시작하면 2D/3D 변환을 진행할 수 있습니다.</p>
          </div>
          <div className="empty-actions">
            <Link className="rf-btn rf-btn--primary" to={routes.source(project.id)}>
              사진 업로드
            </Link>
            <Link className="rf-btn" to={routes.source(project.id)}>
              앱으로 촬영
            </Link>
          </div>
        </section>
      )}
    </ProductShell>
  )
}

function overviewWorkflow(project: WorkspaceProject) {
  if (projectReadyForEditor(project)) {
    return {
      eyebrow: 'Editor ready',
      title: '에디터에서 이어서 작업할 수 있습니다',
      body: '서버에 저장된 소스 이미지와 프로젝트 진행도 기준으로 소스 재입력 없이 에디터를 바로 엽니다.',
      activeIndex: 2,
      primaryLabel: '에디터 바로 열기',
      primaryTo: routes.editor(project.id),
      secondaryLabel: '변환 상태',
      secondaryTo: routes.status(project.id),
      nextTitle: '에디터에서 공간을 다듬으세요',
      nextBody: '변환된 벽·바닥·개구부를 직접 보정하고, 2D 평면도와 3D로 가구를 배치합니다.',
    }
  }

  if (project.imageCount > 0) {
    return {
      eyebrow: 'Conversion required',
      title: '소스 이미지가 준비되었습니다',
      body: '소스 화면에서 입력 이미지를 확인한 뒤 변환 화면으로 넘어가 OpenCV worker를 실행합니다.',
      activeIndex: 1,
      primaryLabel: '소스 확인 후 변환',
      primaryTo: routes.source(project.id),
      secondaryLabel: project.latestJobId ? '변환 상태' : undefined,
      secondaryTo: project.latestJobId ? routes.status(project.id) : undefined,
      nextTitle: '2D/3D 변환을 실행하세요',
      nextBody: '변환 화면에서 worker 진행률을 확인하고 완료 후 에디터로 넘어갑니다.',
    }
  }

  return {
    eyebrow: 'Source required',
    title: '소스 이미지를 먼저 입력하세요',
    body: '소스 이미지 화면에서 사진을 업로드하거나 모바일 가이드 촬영으로 변환 입력을 준비합니다.',
    activeIndex: 0,
    primaryLabel: '소스 이미지 입력',
    primaryTo: routes.source(project.id),
    secondaryLabel: undefined,
    secondaryTo: undefined,
    nextTitle: '방을 변환할 사진을 추가하세요',
    nextBody: '사진을 입력한 뒤 2D/3D 변환 화면에서 OpenCV worker를 실행합니다.',
  }
}
