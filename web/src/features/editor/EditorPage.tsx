import {
  ArrowLeft,
  Cpu,
  ExternalLink,
  Layers,
  LoaderCircle,
  RefreshCw,
  ShieldCheck,
} from 'lucide-react'
import { useEffect, useMemo, useRef, useState } from 'react'
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
  createEditorInitializeMessage,
  editorFrameOrigin,
  editorFrameSrc,
  isEditorBridgeMessage,
} from './editorBridge'
import {
  persistEditorBridgeEvent,
  type EditorEventPersistenceResult,
} from './editorEventPersistence'
import { useEditorSourceImagePayload } from './editorSourceImages'

type BridgeState = 'loading' | 'ready' | 'initializing' | 'initialized' | 'error'

type BridgeEventRecord = {
  id: string
  type: string
  receivedAt: string
}

export function EditorPage() {
  const projectId = useParams().projectId ?? demoProjectId
  const location = useLocation()
  const auth = useAuth()
  const { project, status, error } = useProject(projectId)
  const iframeRef = useRef<HTMLIFrameElement | null>(null)
  const lastInitializeKeyRef = useRef<string | null>(null)
  const [bridgeState, setBridgeState] = useState<BridgeState>('loading')
  const [frameLoaded, setFrameLoaded] = useState(false)
  const [frameKey, setFrameKey] = useState(0)
  const [events, setEvents] = useState<BridgeEventRecord[]>([])
  const [persistenceState, setPersistenceState] = useState<EditorEventPersistenceResult>({
    status: 'ignored',
    label: 'Waiting for CV events',
  })
  const sourceImageState = useEditorSourceImagePayload(project)

  const frameSrc = useMemo(() => editorFrameSrc(projectId), [projectId, frameKey])
  const frameOrigin = useMemo(() => editorFrameOrigin(frameSrc), [frameSrc])

  useEffect(() => {
    if (!project || !iframeRef.current?.contentWindow) {
      return
    }

    if (!frameLoaded || sourceImageState.status === 'loading') {
      return
    }

    const initializeKey = [
      frameKey,
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
    iframeRef.current.contentWindow.postMessage(message, frameOrigin)
  }, [frameKey, frameLoaded, frameOrigin, location.pathname, location.search, project, sourceImageState])

  useEffect(() => {
    const onMessage = (event: MessageEvent<unknown>) => {
      if (event.source !== iframeRef.current?.contentWindow) {
        return
      }

      if (event.origin !== frameOrigin) {
        return
      }

      if (!isEditorBridgeMessage(event.data)) {
        return
      }

      const message = event.data
      setEvents((current) => [
        {
          id: `${message.type}-${message.requestId ?? Date.now()}`,
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

      if (project) {
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
      }
    }

    window.addEventListener('message', onMessage)
    return () => window.removeEventListener('message', onMessage)
  }, [auth, frameOrigin, project, sourceImageState.bridgePayload])

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

      <section className="editor-host-shell" aria-label="RoomForge CV editor host">
        <div className="editor-host-frame-panel">
          <div className="editor-host-frame-toolbar">
            <div>
              <p className="rf-eyebrow">CV editor runtime</p>
              <h1>{project.name}</h1>
            </div>
            <div className="editor-host-actions">
              <button
                className="rf-btn"
                type="button"
                onClick={() => {
                  setBridgeState('loading')
                  setFrameLoaded(false)
                  lastInitializeKeyRef.current = null
                  setFrameKey((key) => key + 1)
                  setEvents([])
                }}
              >
                <RefreshCw size={16} />
                새로고침
              </button>
              <a className="rf-btn" href={frameSrc} target="_blank" rel="noreferrer">
                <ExternalLink size={16} />
                직접 열기
              </a>
            </div>
          </div>

          <div className="editor-host-frame-wrap">
            {bridgeState === 'loading' && (
              <div className="editor-host-loading" role="status">
                <LoaderCircle size={18} />
                에디터 런타임 로딩 중
              </div>
            )}
            <iframe
              key={frameKey}
              ref={iframeRef}
              className="editor-host-frame"
              src={frameSrc}
              title={`${project.name} RoomForge CV editor`}
              allow="clipboard-write; fullscreen"
              onLoad={() => {
                setBridgeState('ready')
                setFrameLoaded(true)
              }}
            />
          </div>
        </div>

        <aside className="editor-host-status-panel" aria-label="Editor bridge status">
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
                <dt>대상 origin</dt>
                <dd>{frameOrigin}</dd>
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
              <h2>최근 이벤트</h2>
            </div>
            {events.length === 0 ? (
              <p className="editor-host-empty">아직 editor bridge 이벤트가 없습니다.</p>
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
        </aside>
      </section>
    </main>
  )
}

function bridgeStateLabel(state: BridgeState) {
  const labels: Record<BridgeState, string> = {
    loading: 'Editor loading',
    ready: 'Bridge ready',
    initializing: 'Initializing',
    initialized: 'Bridge initialized',
    error: 'Bridge error',
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
