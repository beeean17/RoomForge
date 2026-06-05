import {
  Armchair,
  BedDouble,
  Check,
  Copy,
  DoorOpen,
  Download,
  Grid2X2,
  Hand,
  Home,
  Lamp,
  Layers,
  MessageSquare,
  Minus,
  MousePointer2,
  Plus,
  Redo2,
  Ruler,
  Search,
  Sofa,
  Square,
  Trash2,
  Undo2,
} from 'lucide-react'
import { useState } from 'react'
import { Link, useParams } from 'react-router-dom'

import { Brand } from '../../components/shell/Brand'
import { ThemeToggle } from '../../components/shell/ThemeToggle'
import { StatusPill } from '../../components/ui/StatusPill'
import { demoProjectId, routes } from '../../lib/routes'
import { getProject, pipelineSteps } from '../projects/projectData'

const tools = [
  { id: 'select', label: '선택', icon: MousePointer2 },
  { id: 'pan', label: '이동/팬', icon: Hand },
  { id: 'wall', label: '벽 편집', icon: Home },
  { id: 'opening', label: '문·창 개구부', icon: DoorOpen },
  { id: 'furniture', label: '가구', icon: Sofa },
  { id: 'measure', label: '측정', icon: Ruler },
] as const

const furnitureItems = [
  { label: '플랫폼 침대', icon: BedDouble },
  { label: '2인 소파', icon: Sofa },
  { label: '책상', icon: Square },
  { label: '오피스 의자', icon: Armchair },
  { label: '서랍장', icon: Layers },
  { label: '러그', icon: Grid2X2 },
  { label: '조명', icon: Lamp },
  { label: '화분', icon: Home },
] as const

const swatches = ['#2a2a30', '#6b6f78', '#b9bac2', '#7a5b46', '#3f6b46']

export function EditorPage() {
  const projectId = useParams().projectId ?? demoProjectId
  const project = getProject(projectId)
  const [activeTool, setActiveTool] = useState<(typeof tools)[number]['id']>('select')
  const [viewMode, setViewMode] = useState<'3d' | '2d'>('3d')
  const [material, setMaterial] = useState(swatches[0])

  return (
    <main className="editor-page" data-project-id={project.id}>
      <header className="editor-topbar">
        <Brand />
        <nav className="top-crumb editor-crumb" aria-label="에디터 경로">
          <Link to={routes.projects}>프로젝트</Link>
          <span>/</span>
          <Link to={routes.project(project.id)}>{project.name}</Link>
        </nav>
        <div className="editor-pipeline" aria-label="프로젝트 진행 단계">
          {pipelineSteps.map((step) => (
            <span className={`editor-pipeline-step ${step.key === 'editor' ? 'is-active' : 'is-done'}`} key={step.key}>
              <span>{step.key === 'editor' ? <span className="dot" /> : <Check size={12} />}</span>
              {step.label}
            </span>
          ))}
        </div>
        <div className="editor-top-actions">
          <StatusPill label="모든 변경 저장됨" tone="success" />
          <ThemeToggle />
          <button className="account-avatar" type="button" aria-label="계정">SY</button>
        </div>
      </header>

      <section className="editor-workbench">
        <aside className="editor-rail" aria-label="에디터 도구">
          {tools.map((tool) => (
            <button
              className={`editor-tool ${activeTool === tool.id ? 'is-active' : ''}`}
              key={tool.id}
              title={tool.label}
              type="button"
              onClick={() => setActiveTool(tool.id)}
            >
              <tool.icon size={19} />
            </button>
          ))}
          <button className="editor-tool mt-auto" title="메모" type="button">
            <MessageSquare size={19} />
          </button>
        </aside>

        <aside className="editor-library-panel">
          <header>
            <h2>가구 라이브러리</h2>
            <Search size={15} />
          </header>
          <div className="editor-tabs" role="group" aria-label="가구 카테고리">
            {['전체', '침대', '소파', '테이블', '수납'].map((tab, index) => (
              <button className={index === 0 ? 'is-active' : ''} key={tab} type="button">
                {tab}
              </button>
            ))}
          </div>
          <div className="furniture-grid">
            {furnitureItems.map((item) => (
              <button className="furniture-card" key={item.label} type="button" title="끌어다 배치">
                <span><item.icon size={26} /></span>
                <strong>{item.label}</strong>
              </button>
            ))}
          </div>
          <p className="drag-hint">끌어다 캔버스에 배치</p>
        </aside>

        <div className="editor-canvas-shell">
          <div className="editor-toolbar">
            <div className="view-segment" role="group" aria-label="에디터 보기">
              <button className={viewMode === '3d' ? 'is-active' : ''} type="button" onClick={() => setViewMode('3d')}>
                <Layers size={14} />
                3D
              </button>
              <button className={viewMode === '2d' ? 'is-active' : ''} type="button" onClick={() => setViewMode('2d')}>
                <Grid2X2 size={14} />
                2D 평면도
              </button>
            </div>
            <span className="toolbar-rule" />
            <button className="editor-icon-button" title="실행 취소" type="button"><Undo2 size={16} /></button>
            <button className="editor-icon-button" title="다시 실행" type="button"><Redo2 size={16} /></button>
            <div className="canvas-actions">
              <button className="editor-icon-button" title="축소" type="button"><Minus size={16} /></button>
              <span>100%</span>
              <button className="editor-icon-button" title="확대" type="button"><Plus size={16} /></button>
              <span className="snap-label"><Grid2X2 size={14} />스냅</span>
              <button className="rf-btn" type="button">
                <Download size={14} />
                이미지로 내보내기
              </button>
            </div>
          </div>

          <div className="editor-stage">
            {viewMode === '3d' ? <RoomScene material={material} /> : <FloorPlan />}
            {viewMode === '3d' && <div className="selection-badge"><span />침대 선택됨 · 드래그로 회전</div>}
          </div>
        </div>

        <aside className="editor-inspector-panel">
          <header>
            <BedDouble size={16} />
            <h2>침대</h2>
            <span>가구</span>
          </header>
          <div className="inspector-body">
            <InspectorGroup title="치수">
              <Field label="W" value="2.30" unit="m" />
              <Field label="D" value="2.75" unit="m" />
              <Field label="H" value="0.55" unit="m" />
            </InspectorGroup>
            <InspectorGroup title="위치 · 회전">
              <Field label="X" value="0.00" />
              <Field label="Y" value="-1.40" />
              <Field label="∠" value="0" unit="°" />
            </InspectorGroup>
            <div>
              <p className="inspector-label">재질</p>
              <div className="swatch-row">
                {swatches.map((swatch) => (
                  <button
                    className={material === swatch ? 'is-active' : ''}
                    key={swatch}
                    style={{ background: swatch }}
                    type="button"
                    onClick={() => setMaterial(swatch)}
                    aria-label={`${swatch} 재질`}
                  />
                ))}
              </div>
              <p className="material-name">다크 패브릭</p>
            </div>
            <div className="inspector-actions">
              <button className="rf-btn" type="button"><Copy size={14} />복제</button>
              <button className="danger-button" type="button"><Trash2 size={14} />삭제</button>
            </div>
          </div>
          <footer className="room-info">
            <p className="inspector-label">공간 정보</p>
            <dl className="metric-dl">
              <dt>방 크기</dt><dd>5.2 x 6.0 m</dd>
              <dt>천장 높이</dt><dd>2.8 m</dd>
              <dt>바닥 면적</dt><dd>31.2 m²</dd>
              <dt>배치 가구</dt><dd>6</dd>
            </dl>
          </footer>
        </aside>
      </section>
    </main>
  )
}

function InspectorGroup({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div>
      <p className="inspector-label">{title}</p>
      <div className="field-grid">{children}</div>
    </div>
  )
}

function Field({ label, value, unit }: { label: string; value: string; unit?: string }) {
  return (
    <label className="editor-field">
      <span>{label}</span>
      <input defaultValue={value} />
      {unit && <span>{unit}</span>}
    </label>
  )
}

function RoomScene({ material }: { material: string }) {
  return (
    <div className="css-room-scene" aria-label="3D room preview">
      <div className="room-shell">
        <span className="room-plane room-floor" />
        <span className="room-plane room-back" />
        <span className="room-plane room-left" />
        <span className="room-plane room-right" />
        <span className="room-object room-bed" style={{ background: material }} />
        <span className="room-object room-headboard" />
        <span className="room-object room-desk" />
        <span className="room-object room-storage" />
        <span className="room-object room-window" />
        <span className="room-selection" />
      </div>
    </div>
  )
}

function FloorPlan() {
  return (
    <div className="floor-plan-wrap">
      <svg viewBox="-40 -50 600 700" aria-label="2D floor plan">
        <defs>
          <pattern id="editor-grid" width="50" height="50" patternUnits="userSpaceOnUse">
            <path d="M50 0H0V50" />
          </pattern>
        </defs>
        <rect className="plan-grid" x="-40" y="-50" width="600" height="700" />
        <rect className="plan-wall" x="0" y="0" width="520" height="600" rx="2" />
        <line className="plan-window" x1="520" y1="105" x2="520" y2="335" />
        <path className="plan-door" d="M0 450 A100 100 0 0 1 100 550" />
        <line className="plan-door-gap" x1="0" y1="450" x2="0" y2="550" />
        <rect className="plan-furniture" x="12" y="120" width="58" height="170" rx="6" />
        <rect className="plan-furniture" x="455" y="285" width="52" height="170" rx="6" />
        <rect className="plan-selected" x="150" y="60" width="230" height="270" rx="8" />
        <line className="plan-selected-line" x1="150" y1="92" x2="380" y2="92" />
        <text x="265" y="205">침대</text>
        <line className="plan-dim" x1="0" y1="-20" x2="520" y2="-20" />
        <text className="plan-label" x="260" y="-26">5.2 m</text>
        <line className="plan-dim" x1="-22" y1="0" x2="-22" y2="600" />
        <text className="plan-label" x="-26" y="300" transform="rotate(-90 -26 300)">6.0 m</text>
      </svg>
    </div>
  )
}
