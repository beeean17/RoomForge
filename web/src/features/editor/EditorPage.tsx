import {
  Armchair,
  ArrowLeft,
  Ban,
  Box,
  Camera,
  CheckCircle2,
  Cpu,
  Eye,
  EyeOff,
  ExternalLink,
  Grid3X3,
  Layers,
  ListChecks,
  LoaderCircle,
  Lock,
  Maximize2,
  MousePointer2,
  Move,
  PackagePlus,
  PanelRight,
  RefreshCw,
  RotateCcw,
  Ruler,
  ScanLine,
  ShieldCheck,
  SlidersHorizontal,
  Split,
  Square,
  Trash2,
} from 'lucide-react'
import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { Link, useLocation, useParams } from 'react-router-dom'

import { Brand } from '../../components/shell/Brand'
import { ThemeToggle } from '../../components/shell/ThemeToggle'
import { StatePanel } from '../../components/ui/StatePanel'
import { StatusPill } from '../../components/ui/StatusPill'
import { demoProjectId, routes } from '../../lib/routes'
import { useAuth } from '../auth/AuthProvider'
import { pipelineSteps } from '../projects/projectData'
import { useProject } from '../projects/projectRepository'
import {
  EDITOR_BRIDGE_VERSION,
  createEditorInitializeMessage,
  editorFrameSrc,
  type EditorBridgeMessage,
} from './editorBridge'
import {
  persistEditorBridgeEvent,
  type EditorEventPersistenceResult,
} from './editorEventPersistence'
import { EditorRuntimeSurface, type EditorRuntimeDispatch } from './EditorRuntimeSurface'
import {
  candidateReviewCategoryOptions,
  candidateReviewStateFromPayload,
  type CandidateReviewItem,
  type CandidateReviewState,
} from './editorCandidateReview'
import {
  maxValueForField,
  placedObjectStateFromPayload,
  placedObjectTransformFields,
  transformValueForItem,
  type PlacedObjectItem,
  type PlacedObjectState,
  type PlacedObjectTransformField,
} from './editorPlacedObjects'
import {
  structuralFixtureStateFromPayload,
  type StructuralFixtureCandidateItem,
  type StructuralFixtureItem,
  type StructuralFixtureState,
} from './editorStructuralFixtures'
import { useEditorSourceImagePayload } from './editorSourceImages'

type BridgeState = 'loading' | 'ready' | 'initializing' | 'initialized' | 'error'

type BridgeEventRecord = {
  id: string
  type: string
  receivedAt: string
}

type CvSummary = {
  opencvQuality: string
  sceneQuality: string
  candidateCount: number
  fixtureCount: number
  coverageLabel: string
}

type ViewModeControl = '2d' | '3d' | 'split'

type EditorTool = 'select' | 'move' | 'furniture' | 'measure'

type CandidateLayerKey = 'furniture' | 'fixtures' | 'boundaries' | 'lowConfidence'

type CanvasToggleKey = 'grid' | 'snap'

type LayerState = Record<CandidateLayerKey, boolean>

type CanvasToggleState = Record<CanvasToggleKey, boolean>

type RuntimeSceneSummary = {
  viewMode: ViewModeControl
  selectedLabel: string
  selectedType: string
  furnitureCount: number
  candidateCount: number
  fixtureCount: number
  saveLabel: string
}

const initialCvSummary: CvSummary = {
  opencvQuality: '대기 중',
  sceneQuality: '대기 중',
  candidateCount: 0,
  fixtureCount: 0,
  coverageLabel: '촬영 이미지 대기 중',
}

const initialLayerState: LayerState = {
  furniture: true,
  fixtures: true,
  boundaries: true,
  lowConfidence: true,
}

const initialCanvasToggleState: CanvasToggleState = {
  grid: true,
  snap: true,
}

const initialRuntimeSummary: RuntimeSceneSummary = {
  viewMode: '2d',
  selectedLabel: '방 외곽',
  selectedType: 'room',
  furnitureCount: 0,
  candidateCount: 0,
  fixtureCount: 0,
  saveLabel: 'Saved',
}

const initialCandidateReviewState: CandidateReviewState = {
  items: [],
  counts: {
    candidates: 0,
    needsReview: 0,
    placed: 0,
    rejected: 0,
    confirmed: 0,
  },
}

const initialPlacedObjectState: PlacedObjectState = {
  items: [],
  selectedItem: null,
  counts: {
    total: 0,
    cvCandidates: 0,
    catalog: 0,
    locked: 0,
    outsideRoom: 0,
  },
  roomBounds: {
    widthMeters: 4.2,
    depthMeters: 3.6,
  },
}

const initialStructuralFixtureState: StructuralFixtureState = {
  candidates: [],
  fixtures: [],
  selectedFixture: null,
  counts: {
    candidates: 0,
    needsReview: 0,
    placed: 0,
    rejected: 0,
    selected: 0,
  },
}

const toolControls: Array<{ key: EditorTool; label: string; icon: typeof MousePointer2 }> = [
  { key: 'select', label: '선택', icon: MousePointer2 },
  { key: 'move', label: '이동', icon: Move },
  { key: 'furniture', label: '가구', icon: Armchair },
  { key: 'measure', label: '측정', icon: Ruler },
]

const cameraControls = [
  { action: 'fit', label: '방에 맞춤', icon: Maximize2 },
  { action: 'top', label: '상단', icon: Square },
  { action: 'corner', label: '코너', icon: Box },
  { action: 'eye', label: '눈높이', icon: Camera },
] as const

const layerControls: Array<{ key: CandidateLayerKey; label: string; icon: typeof Layers }> = [
  { key: 'furniture', label: '가구', icon: Armchair },
  { key: 'fixtures', label: '고정 요소', icon: PackagePlus },
  { key: 'boundaries', label: '경계', icon: ScanLine },
  { key: 'lowConfidence', label: '검토 후보', icon: Eye },
]

const furnitureQuickAdds = [
  { category: 'sofa', label: '소파' },
  { category: 'table', label: '테이블' },
  { category: 'shelf', label: '선반' },
  { category: 'custom', label: '커스텀' },
] as const

const furnitureEditActions = [
  { action: 'rotate-left', label: '왼쪽 회전', icon: RotateCcw },
  { action: 'wider', label: '너비 증가', icon: Maximize2 },
  { action: 'toggle-lock', label: '잠금 전환', icon: Lock },
  { action: 'delete', label: '삭제', icon: Trash2 },
] as const

export function EditorPage() {
  const projectId = useParams().projectId ?? demoProjectId
  const location = useLocation()
  const auth = useAuth()
  const { project, status, error } = useProject(projectId)
  const runtimeDispatchRef = useRef<EditorRuntimeDispatch | null>(null)
  const lastInitializeKeyRef = useRef<string | null>(null)
  const commandCounterRef = useRef(0)
  const eventCounterRef = useRef(0)
  const [bridgeState, setBridgeState] = useState<BridgeState>('loading')
  const [runtimeReady, setRuntimeReady] = useState(false)
  const [runtimeKey, setRuntimeKey] = useState(0)
  const [runtimeError, setRuntimeError] = useState<string | null>(null)
  const [initializeMessage, setInitializeMessage] = useState<EditorBridgeMessage | null>(null)
  const [events, setEvents] = useState<BridgeEventRecord[]>([])
  const [viewMode, setViewMode] = useState<ViewModeControl>('2d')
  const [activeTool, setActiveTool] = useState<EditorTool>('select')
  const [layerState, setLayerState] = useState<LayerState>(initialLayerState)
  const [canvasToggleState, setCanvasToggleState] = useState<CanvasToggleState>(initialCanvasToggleState)
  const [runtimeSummary, setRuntimeSummary] = useState<RuntimeSceneSummary>(initialRuntimeSummary)
  const [candidateReviewState, setCandidateReviewState] = useState<CandidateReviewState>(initialCandidateReviewState)
  const [placedObjectState, setPlacedObjectState] = useState<PlacedObjectState>(initialPlacedObjectState)
  const [structuralFixtureState, setStructuralFixtureState] = useState<StructuralFixtureState>(initialStructuralFixtureState)
  const [persistenceState, setPersistenceState] = useState<EditorEventPersistenceResult>({
    status: 'ignored',
    label: 'Waiting for CV events',
  })
  const [cvSummary, setCvSummary] = useState<CvSummary>(initialCvSummary)
  const sourceImageState = useEditorSourceImagePayload(project)

  const standaloneEditorSrc = useMemo(() => editorFrameSrc(projectId), [projectId])

  const sendRuntimeCommand = useCallback((type: string, payload: Record<string, unknown> = {}) => {
    const dispatch = runtimeDispatchRef.current
    if (!dispatch) {
      return false
    }

    commandCounterRef.current += 1
    dispatch({
      type,
      version: EDITOR_BRIDGE_VERSION,
      requestId: `react-editor-command-${projectId}-${commandCounterRef.current}-${Date.now()}`,
      payload,
    })
    return true
  }, [projectId])

  const handleRuntimeMessage = useCallback((message: EditorBridgeMessage) => {
    const eventSequence = eventCounterRef.current + 1
    eventCounterRef.current = eventSequence
    setEvents((current) => [
      {
        id: `${message.type}-${message.requestId ?? 'event'}-${eventSequence}`,
        type: message.type,
        receivedAt: new Date().toLocaleTimeString(),
      },
      ...current,
    ].slice(0, 6))

    if (
      message.type === 'roomforge.scene.initialized' ||
      message.type === 'roomforge.scene.initialize.response'
    ) {
      setBridgeState('initialized')
    }

    if (message.type.endsWith('Failed')) {
      setBridgeState('error')
    }

    const nextCvSummary = cvSummaryFromMessage(message)
    if (nextCvSummary) {
      setCvSummary((current) => ({ ...current, ...nextCvSummary }))
    }

    const nextRuntimeSummary = runtimeSummaryFromPayload(message.payload)
    if (nextRuntimeSummary) {
      setRuntimeSummary(nextRuntimeSummary)
      setViewMode(nextRuntimeSummary.viewMode)
    }

    const nextLayerState = layerStateFromPayload(message.payload)
    if (nextLayerState) {
      setLayerState(nextLayerState)
    }

    const nextCanvasToggleState = canvasToggleStateFromPayload(message.payload)
    if (nextCanvasToggleState) {
      setCanvasToggleState(nextCanvasToggleState)
    }

    const nextCandidateReviewState = candidateReviewStateFromPayload(message.payload)
    if (nextCandidateReviewState) {
      setCandidateReviewState(nextCandidateReviewState)
    }

    const nextPlacedObjectState = placedObjectStateFromPayload(message.payload)
    if (nextPlacedObjectState) {
      setPlacedObjectState(nextPlacedObjectState)
    }

    const nextStructuralFixtureState = structuralFixtureStateFromPayload(message.payload)
    if (nextStructuralFixtureState) {
      setStructuralFixtureState(nextStructuralFixtureState)
    }

    if (!project) {
      return
    }

    persistEditorBridgeEvent({
      message,
      project,
      ownerUid: auth.status === 'signed-in' ? auth.user.uid : undefined,
      source: sourceImageState.bridgePayload,
    })
      .then((result) => {
        if (result.status !== 'ignored') {
          setPersistenceState(result)
        }
      })
      .catch((error) => {
        setPersistenceState({
          status: 'skipped',
          label: error instanceof Error ? error.message : String(error),
        })
      })
  }, [auth, project, sourceImageState.bridgePayload])

  const handleRuntimeReady = useCallback((dispatch: EditorRuntimeDispatch) => {
    runtimeDispatchRef.current = dispatch
    setRuntimeReady(true)
    setRuntimeError(null)
    setBridgeState('ready')
  }, [])

  const handleRuntimeError = useCallback((error: Error) => {
    runtimeDispatchRef.current = null
    setRuntimeReady(false)
    setRuntimeError(error.message)
    setBridgeState('error')
  }, [])

  const resetRuntime = useCallback(() => {
    setBridgeState('loading')
    setRuntimeReady(false)
    setRuntimeError(null)
    setInitializeMessage(null)
    runtimeDispatchRef.current = null
    lastInitializeKeyRef.current = null
    eventCounterRef.current = 0
    setRuntimeKey((key) => key + 1)
    setEvents([])
    setCvSummary(initialCvSummary)
    setViewMode('2d')
    setActiveTool('select')
    setLayerState(initialLayerState)
    setCanvasToggleState(initialCanvasToggleState)
    setRuntimeSummary(initialRuntimeSummary)
    setCandidateReviewState(initialCandidateReviewState)
    setPlacedObjectState(initialPlacedObjectState)
    setStructuralFixtureState(initialStructuralFixtureState)
  }, [])

  useEffect(() => {
    if (!project || !runtimeReady || !runtimeDispatchRef.current) {
      return
    }

    if (sourceImageState.status === 'loading') {
      return
    }

    const initializeKey = [
      runtimeKey,
      project.id,
      sourceImageState.status,
      sourceImageState.sourceImageId ?? 'no-source-image',
    ].join(':')
    if (lastInitializeKeyRef.current === initializeKey) {
      return
    }
    lastInitializeKeyRef.current = initializeKey

    const message = createEditorInitializeMessage({
      project,
      requestId: `react-editor-init-${project.id}-${Date.now()}`,
      route: `${location.pathname}${location.search}`,
      source: sourceImageState.bridgePayload,
    })

    setBridgeState('initializing')
    setInitializeMessage(withDevCandidateReviewFixture(message, location.search))
  }, [location.pathname, location.search, project, runtimeKey, runtimeReady, sourceImageState])

  if (!project && status === 'loading') {
    return (
      <StatePanel
        eyebrow="Editor"
        title="에디터 상태를 불러오는 중입니다"
        body="프로젝트 소유권과 저장된 편집 상태를 확인하고 있습니다."
      />
    )
  }

  if (!project) {
    return (
      <StatePanel
        eyebrow="Editor"
        title="프로젝트를 찾을 수 없습니다"
        body={error ?? '요청한 프로젝트가 없거나 현재 계정에 접근 권한이 없습니다.'}
        action={<Link className="rf-btn rf-btn--primary" to={routes.projects}>프로젝트 목록</Link>}
      />
    )
  }

  const bridgeLabel = bridgeStateLabel(bridgeState)
  const bridgeTone = bridgeStateTone(bridgeState)

  return (
    <main className="editor-page editor-host-page" data-project-id={project.id}>
      <header className="editor-topbar">
        <Brand />
        <nav className="top-crumb editor-crumb" aria-label="에디터 경로">
          <Link to={routes.projects}>프로젝트</Link>
          <span>/</span>
          <Link to={routes.project(project.id)}>{project.name}</Link>
        </nav>
        <div className="editor-pipeline" aria-label="프로젝트 진행 단계">
          {pipelineSteps.map((step) => (
            <span
              className={`editor-pipeline-step ${step.key === 'editor' ? 'is-active' : 'is-done'}`}
              key={step.key}
            >
              <span>{step.key === 'editor' ? <span className="dot" /> : <ShieldCheck size={12} />}</span>
              {step.label}
            </span>
          ))}
        </div>
        <div className="editor-top-actions">
          <StatusPill label={bridgeLabel} tone={bridgeTone} />
          <ThemeToggle />
          <Link className="rf-btn" to={routes.project(project.id)}>
            <ArrowLeft size={16} />
            프로젝트
          </Link>
        </div>
      </header>

      <section className="editor-workbench editor-workbench--runtime" aria-label="RoomForge CV editor host">
        <aside className="editor-rail editor-rail--runtime" aria-label="에디터 도구">
          {toolControls.map((control) => {
            const Icon = control.icon
            const isActive = activeTool === control.key
            return (
              <button
                aria-label={control.label}
                aria-pressed={isActive}
                className={`editor-tool${isActive ? ' is-active' : ''}`}
                key={control.key}
                title={control.label}
                type="button"
                onClick={() => {
                  setActiveTool(control.key)
                  if (control.key === 'select') {
                    sendRuntimeCommand('roomforge.selection.clear')
                  }
                }}
              >
                <Icon size={18} />
              </button>
            )
          })}
          <span className="editor-rail-rule" />
          <button
            aria-label="런타임 새로고침"
            className="editor-tool"
            title="런타임 새로고침"
            type="button"
            onClick={resetRuntime}
          >
            <RefreshCw size={18} />
          </button>
          <a
            aria-label="standalone editor"
            className="editor-tool editor-tool-link"
            href={standaloneEditorSrc}
            rel="noreferrer"
            target="_blank"
            title="standalone editor"
          >
            <ExternalLink size={18} />
          </a>
        </aside>

        <section className="editor-canvas-shell editor-runtime-canvas-shell" aria-label="Editor canvas">
          <div className="editor-toolbar editor-runtime-toolbar">
            <div className="view-segment" aria-label="보기 모드">
              {(['2d', '3d', 'split'] as const).map((mode) => (
                <button
                  className={viewMode === mode ? 'is-active' : ''}
                  disabled={!runtimeReady}
                  key={mode}
                  type="button"
                  onClick={() => {
                    setViewMode(mode)
                    sendRuntimeCommand('roomforge.view.setMode', { viewMode: mode })
                  }}
                >
                  {mode === 'split' ? <Split size={14} /> : null}
                  {mode.toUpperCase()}
                </button>
              ))}
            </div>

            <div className="toolbar-rule" />

            <div className="editor-toolbar-group" aria-label="카메라 프리셋">
              {cameraControls.map((control) => {
                const Icon = control.icon
                return (
                  <button
                    aria-label={control.label}
                    className="editor-icon-button"
                    disabled={!runtimeReady}
                    key={control.action}
                    title={control.label}
                    type="button"
                    onClick={() => {
                      setViewMode('3d')
                      sendRuntimeCommand('roomforge.camera.applyAction', { action: control.action })
                    }}
                  >
                    <Icon size={16} />
                  </button>
                )
              })}
            </div>

            <div className="toolbar-rule" />

            <div className="editor-toolbar-group" aria-label="캔버스 옵션">
              {(['grid', 'snap'] as const).map((key) => (
                <button
                  aria-label={key === 'grid' ? '그리드' : '스냅'}
                  aria-pressed={canvasToggleState[key]}
                  className={`editor-icon-button${canvasToggleState[key] ? ' is-active' : ''}`}
                  disabled={!runtimeReady}
                  key={key}
                  title={key === 'grid' ? '그리드' : '스냅'}
                  type="button"
                  onClick={() => {
                    const enabled = !canvasToggleState[key]
                    setCanvasToggleState((current) => ({ ...current, [key]: enabled }))
                    sendRuntimeCommand('roomforge.canvas.toggle', { key, enabled })
                  }}
                >
                  {key === 'grid' ? <Grid3X3 size={16} /> : <ScanLine size={16} />}
                </button>
              ))}
            </div>

            <div className="toolbar-rule" />

            <div className="editor-toolbar-group editor-layer-toggle-group" aria-label="레이어">
              {layerControls.map((control) => {
                const Icon = control.icon
                const visible = layerState[control.key]
                return (
                  <button
                    aria-label={control.label}
                    aria-pressed={visible}
                    className={`editor-layer-toggle${visible ? ' is-active' : ''}`}
                    disabled={!runtimeReady}
                    key={control.key}
                    title={control.label}
                    type="button"
                    onClick={() => {
                      const nextVisible = !visible
                      setLayerState((current) => ({ ...current, [control.key]: nextVisible }))
                      sendRuntimeCommand('roomforge.layer.toggle', {
                        layer: control.key,
                        visible: nextVisible,
                      })
                    }}
                  >
                    <Icon size={15} />
                    {visible ? <Eye size={13} /> : <EyeOff size={13} />}
                  </button>
                )
              })}
            </div>

            <div className="editor-toolbar-spacer" />
            <StatusPill label={bridgeLabel} tone={bridgeTone} />
          </div>

          <div className="editor-host-frame-wrap editor-host-frame-wrap--direct">
            {(bridgeState === 'loading' || bridgeState === 'initializing') && (
              <div className="editor-host-loading" role="status">
                <LoaderCircle size={18} />
                {bridgeState === 'initializing' ? '에디터 런타임 초기화 중' : '에디터 런타임 로딩 중'}
              </div>
            )}
            {runtimeError && (
              <div className="editor-host-runtime-error" role="status">
                {runtimeError}
              </div>
            )}
            <EditorRuntimeSurface
              initializeMessage={initializeMessage}
              mountKey={runtimeKey}
              onError={handleRuntimeError}
              onMessage={handleRuntimeMessage}
              onReady={handleRuntimeReady}
            />
          </div>
        </section>

        <aside className="editor-inspector-panel editor-runtime-inspector" aria-label="Editor bridge status">
          <header>
            <PanelRight size={17} />
            <h2>Inspector</h2>
          </header>

          <div className="editor-runtime-inspector-body">
            <section>
              <div className="editor-host-section-title">
                <MousePointer2 size={18} />
                <h2>Selection</h2>
              </div>
              <dl className="editor-host-status-list">
                <div>
                  <dt>선택</dt>
                  <dd>{runtimeSummary.selectedLabel}</dd>
                </div>
                <div>
                  <dt>유형</dt>
                  <dd>{runtimeSummary.selectedType}</dd>
                </div>
                <div>
                  <dt>보기</dt>
                  <dd>{runtimeSummary.viewMode.toUpperCase()}</dd>
                </div>
                <div>
                  <dt>저장 상태</dt>
                  <dd>{runtimeSummary.saveLabel}</dd>
                </div>
              </dl>
              <div className="editor-inspector-actions">
                {furnitureQuickAdds.map((item) => (
                  <button
                    className="rf-btn"
                    disabled={!runtimeReady}
                    key={item.category}
                    type="button"
                    onClick={() => {
                      setActiveTool('furniture')
                      sendRuntimeCommand('roomforge.furniture.add', { category: item.category })
                    }}
                  >
                    <Armchair size={15} />
                    {item.label}
                  </button>
                ))}
              </div>
              <div className="editor-inspector-icon-actions">
                {furnitureEditActions.map((item) => {
                  const Icon = item.icon
                  return (
                    <button
                      aria-label={item.label}
                      className="editor-icon-button"
                      disabled={!runtimeReady}
                      key={item.action}
                      title={item.label}
                      type="button"
                      onClick={() => sendRuntimeCommand('roomforge.furniture.editSelected', { action: item.action })}
                    >
                      <Icon size={16} />
                    </button>
                  )
                })}
              </div>
            </section>

            <CandidateReviewTray
              disabled={!runtimeReady}
              state={candidateReviewState}
              onCategoryChange={(candidateId, category) =>
                sendRuntimeCommand('roomforge.candidate.updateCategory', { candidateId, category })}
              onPlace={(candidateId) =>
                sendRuntimeCommand('roomforge.candidate.place', { candidateId })}
              onReject={(candidateId) =>
                sendRuntimeCommand('roomforge.candidate.reject', { candidateId })}
            />

            <PlacedObjectEditor
              disabled={!runtimeReady}
              state={placedObjectState}
              onEditAction={(action) =>
                sendRuntimeCommand('roomforge.furniture.editSelected', { action })}
              onSelect={(objectId) =>
                sendRuntimeCommand('roomforge.furniture.select', { objectId })}
              onTransformChange={(field, value) =>
                sendRuntimeCommand('roomforge.furniture.updateTransform', { field, value })}
            />

            <StructuralFixtureReview
              disabled={!runtimeReady}
              state={structuralFixtureState}
              onEditAction={(action) =>
                sendRuntimeCommand('roomforge.fixture.editSelected', { action })}
              onPlaceCandidate={(candidateId) =>
                sendRuntimeCommand('roomforge.fixture.placeCandidate', { candidateId })}
              onRejectCandidate={(candidateId) =>
                sendRuntimeCommand('roomforge.candidate.reject', { candidateId })}
              onSelect={(fixtureId) =>
                sendRuntimeCommand('roomforge.fixture.select', { fixtureId })}
            />

            <section>
              <div className="editor-host-section-title">
                <Cpu size={18} />
                <h2>Bridge</h2>
              </div>
              <dl className="editor-host-status-list">
                <div>
                  <dt>상태</dt>
                  <dd><StatusPill label={bridgeLabel} tone={bridgeTone} /></dd>
                </div>
                <div>
                  <dt>마운트</dt>
                  <dd>{runtimeReady ? 'React direct runtime' : 'Mounting runtime module'}</dd>
                </div>
                <div>
                  <dt>메시지</dt>
                  <dd>roomforge.scene.initialize</dd>
                </div>
                <div>
                  <dt>소스 이미지</dt>
                  <dd>{sourceImageStatusLabel(sourceImageState)}</dd>
                </div>
                <div>
                  <dt>저장</dt>
                  <dd>{persistenceState.label}</dd>
                </div>
              </dl>
            </section>

            <section>
            <div className="editor-host-section-title">
              <Layers size={18} />
              <h2>CV 요약</h2>
            </div>
            <dl className="editor-host-status-list">
              <div>
                <dt>OpenCV</dt>
                <dd>{cvSummary.opencvQuality}</dd>
              </div>
              <div>
                <dt>Scene</dt>
                <dd>{cvSummary.sceneQuality}</dd>
              </div>
              <div>
                <dt>오브젝트</dt>
                <dd>{runtimeSummary.furnitureCount} placed · {runtimeSummary.candidateCount} candidates</dd>
              </div>
              <div>
                <dt>고정 요소</dt>
                <dd>{runtimeSummary.fixtureCount} fixtures</dd>
              </div>
              <div>
                <dt>Coverage</dt>
                <dd>{cvSummary.coverageLabel}</dd>
              </div>
            </dl>
            </section>

            <section>
            <div className="editor-host-section-title">
              <Layers size={18} />
              <h2>최근 이벤트</h2>
            </div>
            {events.length === 0 ? (
              <p className="editor-host-empty">아직 editor runtime 이벤트가 없습니다.</p>
            ) : (
              <ol className="editor-host-event-list">
                {events.map((event) => (
                  <li key={event.id}>
                    <strong>{event.type}</strong>
                    <span>{event.receivedAt}</span>
                  </li>
                ))}
              </ol>
            )}
            </section>
          </div>
        </aside>
      </section>
    </main>
  )
}

function PlacedObjectEditor({
  disabled,
  state,
  onEditAction,
  onSelect,
  onTransformChange,
}: {
  disabled: boolean
  state: PlacedObjectState
  onEditAction: (action: string) => void
  onSelect: (objectId: string) => void
  onTransformChange: (field: PlacedObjectTransformField, value: number) => void
}) {
  const selected = state.selectedItem

  return (
    <section className="placed-object-editor" aria-labelledby="react-placed-object-title">
      <div className="editor-host-section-title">
        <SlidersHorizontal size={18} />
        <h2 id="react-placed-object-title">Placed objects</h2>
      </div>

      <div className="placed-object-counts" aria-label="Placed object counts">
        <span><strong>{state.counts.total}</strong> placed</span>
        <span><strong>{state.counts.cvCandidates}</strong> CV</span>
        <span><strong>{state.counts.locked}</strong> locked</span>
        <span><strong>{state.counts.outsideRoom}</strong> outside</span>
      </div>

      {state.items.length === 0 ? (
        <p className="editor-host-empty">배치된 객체가 없습니다. 후보를 배치하거나 프리셋을 추가하세요.</p>
      ) : (
        <div className="placed-object-list" role="list" aria-label="React placed object list">
          {state.items.map((item) => (
            <PlacedObjectCard
              disabled={disabled}
              item={item}
              key={item.objectId}
              onSelect={onSelect}
            />
          ))}
        </div>
      )}

      <SelectedPlacedObjectControls
        disabled={disabled}
        roomBounds={state.roomBounds}
        selected={selected}
        onEditAction={onEditAction}
        onTransformChange={onTransformChange}
      />
    </section>
  )
}

function PlacedObjectCard({
  disabled,
  item,
  onSelect,
}: {
  disabled: boolean
  item: PlacedObjectItem
  onSelect: (objectId: string) => void
}) {
  return (
    <article role="listitem">
      <button
        aria-label={`Select ${item.label}`}
        aria-pressed={item.selected}
        className={`placed-object-card${item.selected ? ' is-selected' : ''}${item.outsideRoom ? ' is-warning' : ''}`}
        data-object-id={item.objectId}
        disabled={disabled}
        type="button"
        onClick={() => onSelect(item.objectId)}
      >
        <span>
          <strong>{item.label}</strong>
          <small>{item.category} · {item.sourceLabel}</small>
        </span>
        <span className="placed-object-card-meta">
          <span className={`state-pill ${item.locked ? 'warning' : 'confirmed'}`}>
            {item.locked ? 'Locked' : 'Editable'}
          </span>
          {item.outsideRoom ? <span className="state-pill warning">Outside</span> : null}
        </span>
      </button>
    </article>
  )
}

function SelectedPlacedObjectControls({
  disabled,
  roomBounds,
  selected,
  onEditAction,
  onTransformChange,
}: {
  disabled: boolean
  roomBounds: PlacedObjectState['roomBounds']
  selected: PlacedObjectItem | null
  onEditAction: (action: string) => void
  onTransformChange: (field: PlacedObjectTransformField, value: number) => void
}) {
  if (!selected) {
    return (
      <div className="placed-object-selection-empty">
        <MousePointer2 size={16} />
        <span>객체를 선택하면 미터 단위 transform을 편집할 수 있습니다.</span>
      </div>
    )
  }

  const transformDisabled = disabled || !selected.canEdit

  return (
    <div className="placed-object-transform-panel" data-selected-object-id={selected.objectId}>
      <div className="placed-object-transform-header">
        <div>
          <strong>{selected.label}</strong>
          <span>{selected.coordinateSpace} · {selected.sourceLabel}</span>
        </div>
        <span className={`state-pill ${selected.locked ? 'warning' : 'selected'}`}>
          {selected.locked ? 'Locked' : 'Selected'}
        </span>
      </div>

      <dl className="placed-object-summary-grid" aria-label="Selected placed object summary">
        <div>
          <dt>Position</dt>
          <dd>{formatMeters(selected.positionX)}, {formatMeters(selected.positionY)}</dd>
        </div>
        <div>
          <dt>Size</dt>
          <dd>{formatMeters(selected.widthMeters)} x {formatMeters(selected.depthMeters)}</dd>
        </div>
        <div>
          <dt>Height</dt>
          <dd>{formatMeters(selected.heightMeters)}</dd>
        </div>
        <div>
          <dt>Rotation</dt>
          <dd>{selected.rotationDegrees.toFixed(0)} deg</dd>
        </div>
      </dl>

      <div className="placed-object-transform-grid" aria-label="Selected placed object transform">
        {placedObjectTransformFields.map((config) => {
          const value = transformValueForItem(selected, config.field)
          const max = maxValueForField(config.field, roomBounds) || config.maxFallback
          return (
            <label key={config.field}>
              <span>{config.label}</span>
              <input
                aria-label={`${selected.label} ${config.label}`}
                disabled={transformDisabled}
                inputMode="decimal"
                max={max}
                min={config.min}
                step={config.step}
                type="number"
                value={formatInputNumber(value)}
                onChange={(event) => {
                  const nextValue = event.currentTarget.valueAsNumber
                  if (Number.isFinite(nextValue)) {
                    onTransformChange(config.field, nextValue)
                  }
                }}
              />
              <small>{config.unit}</small>
            </label>
          )
        })}
      </div>

      <div className="placed-object-actions">
        <button
          className="rf-btn"
          disabled={disabled}
          type="button"
          onClick={() => onEditAction('toggle-lock')}
        >
          <Lock size={15} />
          {selected.locked ? 'Unlock' : 'Lock'}
        </button>
        <button
          className="rf-btn"
          disabled={disabled}
          type="button"
          onClick={() => onEditAction('rotate-right')}
        >
          <RotateCcw size={15} />
          Rotate
        </button>
        <button
          className="danger-button"
          disabled={disabled || !selected.canDelete}
          type="button"
          onClick={() => onEditAction('delete')}
        >
          <Trash2 size={15} />
          Delete
        </button>
      </div>
    </div>
  )
}

function formatMeters(value: number): string {
  return `${value.toFixed(2)} m`
}

function formatInputNumber(value: number): string {
  return Number.isFinite(value) ? String(Number(value.toFixed(2))) : '0'
}

function StructuralFixtureReview({
  disabled,
  state,
  onEditAction,
  onPlaceCandidate,
  onRejectCandidate,
  onSelect,
}: {
  disabled: boolean
  state: StructuralFixtureState
  onEditAction: (action: string) => void
  onPlaceCandidate: (candidateId: string) => void
  onRejectCandidate: (candidateId: string) => void
  onSelect: (fixtureId: string) => void
}) {
  return (
    <section className="structural-fixture-review" aria-labelledby="react-structural-fixture-title">
      <div className="editor-host-section-title">
        <PackagePlus size={18} />
        <h2 id="react-structural-fixture-title">Structural fixtures</h2>
      </div>

      <div className="fixture-review-counts" aria-label="Structural fixture counts">
        <span><strong>{state.counts.candidates}</strong> candidates</span>
        <span><strong>{state.counts.needsReview}</strong> Needs review</span>
        <span><strong>{state.counts.placed}</strong> placed</span>
        <span><strong>{state.fixtures.length}</strong> fixtures</span>
      </div>

      {state.candidates.length === 0 ? (
        <p className="editor-host-empty">구조물 후보가 아직 없습니다.</p>
      ) : (
        <div className="fixture-candidate-list" role="list" aria-label="Structural fixture candidates">
          {state.candidates.map((candidate) => (
            <StructuralFixtureCandidateCard
              candidate={candidate}
              disabled={disabled}
              key={candidate.candidateId}
              onPlaceCandidate={onPlaceCandidate}
              onRejectCandidate={onRejectCandidate}
            />
          ))}
        </div>
      )}

      {state.fixtures.length === 0 ? (
        <p className="editor-host-empty">배치된 구조 고정 요소가 없습니다.</p>
      ) : (
        <div className="fixture-object-list" role="list" aria-label="Placed structural fixtures">
          {state.fixtures.map((fixture) => (
            <StructuralFixtureCard
              disabled={disabled}
              fixture={fixture}
              key={fixture.fixtureId}
              onSelect={onSelect}
            />
          ))}
        </div>
      )}

      <SelectedStructuralFixtureControls
        disabled={disabled}
        fixture={state.selectedFixture}
        onEditAction={onEditAction}
      />
    </section>
  )
}

function StructuralFixtureCandidateCard({
  candidate,
  disabled,
  onPlaceCandidate,
  onRejectCandidate,
}: {
  candidate: StructuralFixtureCandidateItem
  disabled: boolean
  onPlaceCandidate: (candidateId: string) => void
  onRejectCandidate: (candidateId: string) => void
}) {
  return (
    <article
      className={`fixture-candidate-card${candidate.needsReview ? ' is-review-required' : ''}${candidate.isPlaced ? ' is-placed' : ''}`}
      role="listitem"
    >
      <div className="fixture-card-header">
        <div>
          <strong>{candidate.label}</strong>
          <span>{candidate.category} · {candidate.sourceLabel}</span>
        </div>
        <span className={`state-pill ${candidate.isPlaced ? 'confirmed' : candidate.needsReview ? 'candidate' : 'selected'}`}>
          {candidate.reviewLabel}
        </span>
      </div>
      <dl className="fixture-meta-grid">
        <div>
          <dt>Confidence</dt>
          <dd>{candidate.confidenceLabel}</dd>
        </div>
        <div>
          <dt>Source</dt>
          <dd>{candidate.sourceLabel}</dd>
        </div>
      </dl>
      <div className="fixture-review-actions">
        <button
          aria-label={`Reject fixture ${candidate.label}`}
          className="rf-btn"
          disabled={disabled || !candidate.canReject}
          type="button"
          onClick={() => onRejectCandidate(candidate.candidateId)}
        >
          <Ban size={15} />
          Reject
        </button>
        <button
          aria-label={`Place fixture ${candidate.label}`}
          className="rf-btn rf-btn--primary"
          disabled={disabled || !candidate.canPlace}
          type="button"
          onClick={() => onPlaceCandidate(candidate.candidateId)}
        >
          <CheckCircle2 size={15} />
          Place
        </button>
      </div>
    </article>
  )
}

function StructuralFixtureCard({
  disabled,
  fixture,
  onSelect,
}: {
  disabled: boolean
  fixture: StructuralFixtureItem
  onSelect: (fixtureId: string) => void
}) {
  return (
    <article role="listitem">
      <button
        aria-label={`Select fixture ${fixture.label}`}
        aria-pressed={fixture.selected}
        className={`fixture-object-card${fixture.selected ? ' is-selected' : ''}`}
        disabled={disabled}
        type="button"
        onClick={() => onSelect(fixture.fixtureId)}
      >
        <span>
          <strong>{fixture.label}</strong>
          <small>{fixture.category} · {fixture.wallId}</small>
        </span>
        <span className="state-pill selected">{fixture.confidenceLabel}</span>
      </button>
    </article>
  )
}

function SelectedStructuralFixtureControls({
  disabled,
  fixture,
  onEditAction,
}: {
  disabled: boolean
  fixture: StructuralFixtureItem | null
  onEditAction: (action: string) => void
}) {
  if (!fixture) {
    return (
      <div className="fixture-selection-empty">
        <PackagePlus size={16} />
        <span>구조 고정 요소를 선택하면 wall, category, size를 조정할 수 있습니다.</span>
      </div>
    )
  }

  const editDisabled = disabled || !fixture.canEdit

  return (
    <div className="fixture-edit-panel" data-selected-fixture-id={fixture.fixtureId}>
      <div className="fixture-card-header">
        <div>
          <strong>{fixture.label}</strong>
          <span>{fixture.wallId} · {fixture.sourceLabel}</span>
        </div>
        <span className={`state-pill ${fixture.locked ? 'warning' : 'selected'}`}>
          {fixture.locked ? 'Locked' : 'Selected'}
        </span>
      </div>

      <dl className="fixture-meta-grid">
        <div>
          <dt>Offset</dt>
          <dd>{formatMeters(fixture.offsetMeters)}</dd>
        </div>
        <div>
          <dt>Size</dt>
          <dd>{formatMeters(fixture.widthMeters)} x {formatMeters(fixture.heightMeters)}</dd>
        </div>
        <div>
          <dt>Depth</dt>
          <dd>{formatMeters(fixture.depthMeters)}</dd>
        </div>
        <div>
          <dt>Rotation</dt>
          <dd>{fixture.rotationDegrees.toFixed(0)} deg</dd>
        </div>
      </dl>

      <div className="fixture-action-grid" aria-label="Selected structural fixture actions">
        {fixtureEditActionButtons.map((action) => (
          <button
            aria-label={`${action.label} for ${fixture.label}`}
            className={action.action === 'delete' ? 'danger-button' : 'rf-btn'}
            disabled={disabled || (action.action !== 'delete' && editDisabled)}
            key={action.action}
            type="button"
            onClick={() => onEditAction(action.action)}
          >
            {action.icon === 'trash' ? <Trash2 size={15} /> : <PackagePlus size={15} />}
            {action.label}
          </button>
        ))}
      </div>
    </div>
  )
}

const fixtureEditActionButtons = [
  { action: 'wall-previous', label: 'Prev wall', icon: 'fixture' },
  { action: 'wall-next', label: 'Next wall', icon: 'fixture' },
  { action: 'offset-decrease', label: 'Offset -', icon: 'fixture' },
  { action: 'offset-increase', label: 'Offset +', icon: 'fixture' },
  { action: 'narrower', label: 'Narrower', icon: 'fixture' },
  { action: 'wider', label: 'Wider', icon: 'fixture' },
  { action: 'shorter', label: 'Shorter', icon: 'fixture' },
  { action: 'taller', label: 'Taller', icon: 'fixture' },
  { action: 'category-next', label: 'Category', icon: 'fixture' },
  { action: 'delete', label: 'Delete', icon: 'trash' },
] as const

function CandidateReviewTray({
  disabled,
  state,
  onCategoryChange,
  onPlace,
  onReject,
}: {
  disabled: boolean
  state: CandidateReviewState
  onCategoryChange: (candidateId: string, category: string) => void
  onPlace: (candidateId: string) => void
  onReject: (candidateId: string) => void
}) {
  return (
    <section className="candidate-review-tray" aria-labelledby="react-candidate-review-title">
      <div className="editor-host-section-title">
        <ListChecks size={18} />
        <h2 id="react-candidate-review-title">Candidate review</h2>
      </div>

      <div className="candidate-review-counts" aria-label="CV candidate counts">
        <span><strong>{state.counts.candidates}</strong> candidates</span>
        <span><strong>{state.counts.needsReview}</strong> Needs review</span>
        <span><strong>{state.counts.placed}</strong> placed</span>
        <span><strong>{state.counts.confirmed}</strong> confirmed</span>
      </div>

      {state.items.length === 0 ? (
        <p className="editor-host-empty">CV 후보가 아직 없습니다.</p>
      ) : (
        <div className="candidate-review-list" role="list" aria-label="React CV candidate tray">
          {state.items.map((item) => (
            <CandidateReviewCard
              disabled={disabled}
              item={item}
              key={item.candidateId}
              onCategoryChange={onCategoryChange}
              onPlace={onPlace}
              onReject={onReject}
            />
          ))}
        </div>
      )}
    </section>
  )
}

function CandidateReviewCard({
  disabled,
  item,
  onCategoryChange,
  onPlace,
  onReject,
}: {
  disabled: boolean
  item: CandidateReviewItem
  onCategoryChange: (candidateId: string, category: string) => void
  onPlace: (candidateId: string) => void
  onReject: (candidateId: string) => void
}) {
  return (
    <article
      className={`candidate-review-card ${candidateStateClass(item)}`}
      data-candidate-id={item.candidateId}
      role="listitem"
    >
      <div className="candidate-review-card-header">
        <div>
          <strong>{item.label}</strong>
          <span>{item.objectType} · {item.coordinateSpace}</span>
        </div>
        <span className={`state-pill ${candidateStatePillClass(item)}`}>{item.reviewLabel}</span>
      </div>

      <dl className="candidate-review-meta">
        <div>
          <dt>Confidence</dt>
          <dd>{item.confidenceLabel}</dd>
        </div>
        <div>
          <dt>Source</dt>
          <dd>{item.sourceLabel}</dd>
        </div>
        <div>
          <dt>Evidence</dt>
          <dd>{item.evidenceLabel}</dd>
        </div>
      </dl>

      <label className="candidate-review-category">
        <span>Category</span>
        <select
          aria-label={`${item.label} category`}
          disabled={disabled || !item.canChangeCategory}
          value={item.category}
          onChange={(event) => onCategoryChange(item.candidateId, event.target.value)}
        >
          {categoryOptionsFor(item.category).map((category) => (
            <option key={category} value={category}>{category}</option>
          ))}
        </select>
      </label>

      <div className="candidate-review-actions">
        <button
          aria-label={`Reject ${item.label}`}
          className="rf-btn"
          disabled={disabled || !item.canReject}
          type="button"
          onClick={() => onReject(item.candidateId)}
        >
          <Ban size={15} />
          Reject
        </button>
        <button
          aria-label={`Place ${item.label}`}
          className="rf-btn rf-btn--primary"
          disabled={disabled || !item.canPlace}
          type="button"
          onClick={() => onPlace(item.candidateId)}
        >
          <CheckCircle2 size={15} />
          Place
        </button>
      </div>
    </article>
  )
}

function categoryOptionsFor(category: string): string[] {
  const options = [...candidateReviewCategoryOptions]
  return options.includes(category as (typeof candidateReviewCategoryOptions)[number])
    ? options
    : [category, ...options]
}

function candidateStateClass(item: CandidateReviewItem): string {
  if (item.isRejected) return 'is-rejected'
  if (item.isPlaced) return 'is-placed'
  if (item.needsReview) return 'is-review-required'
  return 'is-candidate'
}

function candidateStatePillClass(item: CandidateReviewItem): string {
  if (item.isRejected) return 'warning'
  if (item.isPlaced) return 'confirmed'
  if (item.needsReview) return 'candidate'
  return 'selected'
}

function bridgeStateLabel(state: BridgeState) {
  const labels: Record<BridgeState, string> = {
    loading: 'Runtime loading',
    ready: 'Runtime ready',
    initializing: 'Initializing',
    initialized: 'Runtime initialized',
    error: 'Runtime error',
  }
  return labels[state]
}

function bridgeStateTone(state: BridgeState) {
  if (state === 'initialized') return 'success'
  if (state === 'error') return 'danger'
  if (state === 'loading' || state === 'initializing') return 'accent'
  return 'warning'
}

function sourceImageStatusLabel(state: ReturnType<typeof useEditorSourceImagePayload>) {
  if (state.status === 'ready') return `${state.sourceImageId} loaded`
  if (state.status === 'loading') return 'Loading private source image'
  if (state.status === 'error') return state.error ?? 'Source image load failed'
  return 'No source image bytes available'
}

function withDevCandidateReviewFixture(message: EditorBridgeMessage, search: string): EditorBridgeMessage {
  if (!import.meta.env.DEV || !new URLSearchParams(search).has('candidateFixture')) {
    return message
  }

  const scene = recordValue(message.payload.scene)
  return {
    ...message,
    payload: {
      ...message.payload,
      scene: {
        ...scene,
        candidateObjects: [
          {
            candidateId: 'candidate-bed-dev-fixture',
            objectType: 'furniture',
            category: 'bed',
            label: 'Detected bed',
            sourceImageRole: 'front_wall',
            coordinateSpace: 'image_pixels',
            confidenceScore: 0.52,
            reviewState: 'review_required',
            suggestedAssetId: 'bed.double',
            suggestedPosition: { x: 2.1, y: 0, z: 2.2 },
            suggestedSize: { x: 1.9, y: 0.65, z: 1.45 },
            suggestedRotationDegrees: 0,
          },
          {
            candidateId: 'candidate-chair-dev-fixture',
            objectType: 'furniture',
            category: 'chair',
            sourceEvidence: [
              { candidateId: 'candidate-chair-dev-fixture', sourceImageRole: 'overview' },
              { candidateId: 'candidate-chair-dev-fixture', sourceImageRole: 'right_wall' },
            ],
            coordinateSpace: 'image_pixels',
            confidenceScore: 0.91,
            reviewState: 'new',
            suggestedPosition: { x: 3.1, y: 0, z: 1.8 },
          },
          {
            candidateId: 'candidate-window-dev-fixture',
            objectType: 'structural_fixture',
            category: 'window',
            sourceImageRole: 'left_wall',
            coordinateSpace: 'image_pixels',
            confidenceScore: 0.88,
            reviewState: 'new',
          },
        ],
        placedObjects: [],
        confirmedObjects: [],
      },
    },
  }
}

function runtimeSummaryFromPayload(payload: Record<string, unknown>): RuntimeSceneSummary | null {
  if (!('viewMode' in payload) && !('selected' in payload) && !('furniture' in payload)) {
    return null
  }

  const furniture = listValue(payload.furniture)
  const candidates = listValue(payload.candidateObjects)
  const fixtures = listValue(payload.structuralFixtures)
  const selected = recordValue(payload.selected)
  const selectedObjectId = typeof selected.objectId === 'string' ? selected.objectId : undefined
  const selectedType = typeof selected.objectType === 'string' ? selected.objectType : 'room'
  const selectedLabel = selectedLabelFromPayload({
    selectedObjectId,
    selectedType,
    furniture,
    fixtures,
    room: recordValue(payload.room),
  })
  const viewMode = payload.viewMode === '2d'
    ? '2d'
    : payload.splitViewActive === true
      ? 'split'
      : '3d'

  return {
    viewMode,
    selectedLabel,
    selectedType,
    furnitureCount: furniture.length,
    candidateCount: candidates.length,
    fixtureCount: fixtures.length,
    saveLabel: payload.hasUnsavedChanges === true ? 'Unsaved changes' : 'Saved',
  }
}

function selectedLabelFromPayload({
  selectedObjectId,
  selectedType,
  furniture,
  fixtures,
  room,
}: {
  selectedObjectId?: string
  selectedType: string
  furniture: unknown[]
  fixtures: unknown[]
  room: Record<string, unknown>
}): string {
  if (selectedType === 'furniture' && selectedObjectId) {
    return labelForRecordList(furniture, selectedObjectId) ?? selectedObjectId
  }
  if (selectedType === 'fixture' && selectedObjectId) {
    return labelForRecordList(fixtures, selectedObjectId) ?? selectedObjectId
  }
  return typeof room.label === 'string' ? room.label : '방 외곽'
}

function labelForRecordList(items: unknown[], objectId: string): string | undefined {
  for (const item of items) {
    const record = recordValue(item)
    if (record.objectId === objectId && typeof record.label === 'string') {
      return record.label
    }
  }
  return undefined
}

function layerStateFromPayload(payload: Record<string, unknown>): LayerState | null {
  const layerVisibility = recordValue(payload.layerVisibility)
  if (Object.keys(layerVisibility).length === 0) {
    return null
  }
  return {
    furniture: booleanWithDefault(layerVisibility.furniture, true),
    fixtures: booleanWithDefault(layerVisibility.fixtures, true),
    boundaries: booleanWithDefault(layerVisibility.boundaries, true),
    lowConfidence: booleanWithDefault(layerVisibility.lowConfidence, true),
  }
}

function canvasToggleStateFromPayload(payload: Record<string, unknown>): CanvasToggleState | null {
  const toggleState = recordValue(payload.canvasToggleState)
  if (Object.keys(toggleState).length === 0) {
    return null
  }
  return {
    grid: booleanWithDefault(toggleState.grid, true),
    snap: booleanWithDefault(toggleState.snap, true),
  }
}

function booleanWithDefault(value: unknown, fallback: boolean): boolean {
  return typeof value === 'boolean' ? value : fallback
}

function cvSummaryFromMessage(message: { type: string; payload: Record<string, unknown> }): Partial<CvSummary> | null {
  if (message.type === 'roomforge.opencv.candidatesExtracted') {
    return {
      opencvQuality: qualityLabel(message.payload.qualityStatus),
    }
  }

  if (message.type === 'roomforge.sceneUnderstanding.candidatesExtracted') {
    const result = recordValue(message.payload.sceneUnderstandingResult)
    const coverage = recordValue(result.coverage)
    return {
      sceneQuality: qualityLabel(result.qualityStatus),
      candidateCount: listValue(result.candidateObjects).length,
      fixtureCount: listValue(result.structuralFixtures).length,
      coverageLabel: coverageLabel(coverage),
    }
  }

  if (message.type === 'roomforge.sceneUnderstanding.candidatesFailed') {
    return {
      sceneQuality: 'Failed',
      candidateCount: 0,
    }
  }

  return null
}

function qualityLabel(value: unknown): string {
  if (value === 'review_required') return 'Needs review'
  if (value === 'success') return 'Success'
  if (value === 'failed') return 'Failed'
  return '대기 중'
}

function coverageLabel(value: Record<string, unknown>): string {
  const canContinue = typeof value.canContinue === 'boolean' ? value.canContinue : undefined
  const roles = listValue(value.requiredRoles).filter((role): role is string => typeof role === 'string')
  const guidance = listValue(value.guidance).filter((item): item is string => typeof item === 'string')
  if (canContinue === undefined && roles.length === 0 && guidance.length === 0) {
    return 'Coverage pending'
  }
  const state = canContinue ? 'complete' : 'Needs review'
  return `${state} · ${guidance[0] ?? `${roles.length} roles checked`}`
}

function recordValue(value: unknown): Record<string, unknown> {
  return typeof value === 'object' && value !== null ? (value as Record<string, unknown>) : {}
}

function listValue(value: unknown): unknown[] {
  return Array.isArray(value) ? value : []
}
