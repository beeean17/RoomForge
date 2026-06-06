import { ArrowRight, Check, Layers, MoreHorizontal, Pencil, Plus } from 'lucide-react'
import { useEffect, useRef, useState } from 'react'
import { Link, useParams } from 'react-router-dom'

import { ProductShell } from '../../components/shell/ProductShell'
import { StatePanel } from '../../components/ui/StatePanel'
import { StatusPill } from '../../components/ui/StatusPill'
import { demoProjectId, routes } from '../../lib/routes'
import { getPipelineState, pipelineSteps } from './projectData'
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
  const sourceThumbCount = Math.min(7, project.imageCount)

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
              <Link role="menuitem" to={routes.status(project.id)} onClick={() => setMoreOpen(false)}>재구성 상태</Link>
              <Link role="menuitem" to={routes.recovery(project.id)} onClick={() => setMoreOpen(false)}>복구 상태</Link>
              <Link role="menuitem" to={routes.editor(project.id)} onClick={() => setMoreOpen(false)}>에디터 열기</Link>
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
          <article className="preview-card">
            <div className="preview-media">
              {project.coverMode === 'image' ? <img src="/assets/room.png" alt="" /> : <span className="preview-placeholder">촬영 대기</span>}
              <StatusPill label="3D 재구성 프리뷰" tone="accent" />
              <div className="preview-actions">
                <Link className="rf-btn rf-btn--primary" to={routes.editor(project.id)}>
                  <Layers size={15} />
                  에디터 열기
                </Link>
                <Link className="rf-btn rf-btn--dark" to={routes.editor(project.id)}>
                  2D 평면도
                </Link>
              </div>
            </div>
          </article>

          <article className="next-step-card">
            <p className="rf-eyebrow">다음 단계</p>
            <div>
              <h2>에디터에서 공간을 다듬으세요</h2>
              <p>재구성된 벽·바닥·개구부를 직접 보정하고, 2D 평면도와 3D로 가구를 배치합니다.</p>
            </div>
            <Link className="rf-btn rf-btn--primary" to={routes.editor(project.id)}>
              에디터 열기
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
            <div className="thumb-grid">
              {Array.from({ length: sourceThumbCount }, (_, index) => (
                <span className="source-thumb" key={index} style={{ filter: `brightness(${0.62 + index * 0.06}) saturate(.86)` }} />
              ))}
              <Link className="source-thumb source-thumb--add" to={routes.source(project.id)} aria-label="소스 이미지 추가">
                <Plus size={16} />
              </Link>
            </div>
          </article>

          <article className="summary-card">
            <header>
              <h2>재구성 상태</h2>
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

      {project.status === 'created' && (
        <section className="empty-project-panel">
          <span className="create-icon"><Plus size={24} /></span>
          <div>
            <h2>방을 재구성할 사진을 추가하세요</h2>
            <p>사진을 업로드하거나 앱의 가이드 촬영으로 시작하면 자동으로 3D 재구성이 진행됩니다.</p>
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
