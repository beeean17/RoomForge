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
import { useEffect, useRef, useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'

import { Brand } from '../../components/shell/Brand'
import { ThemeToggle } from '../../components/shell/ThemeToggle'
import { StatePanel } from '../../components/ui/StatePanel'
import { StatusPill } from '../../components/ui/StatusPill'
import { demoProjectId, routes } from '../../lib/routes'
import { useAuth } from '../auth/AuthProvider'
import { pipelineSteps } from '../projects/projectData'
import { useProject } from '../projects/projectRepository'

const tools = [
  { id: 'select', label: '선택', icon: MousePointer2 },
  { id: 'pan', label: '이동/팬', icon: Hand },
  { id: 'wall', label: '벽 편집', icon: Home },
  { id: 'opening', label: '문·창 개구부', icon: DoorOpen },
  { id: 'furniture', label: '가구', icon: Sofa },
  { id: 'measure', label: '측정', icon: Ruler },
] as const

const furnitureCategories = ['전체', '침대', '소파', '테이블', '수납'] as const

const furnitureItems = [
  { id: 'bed', label: '플랫폼 침대', category: '침대', icon: BedDouble },
  { id: 'sofa', label: '2인 소파', category: '소파', icon: Sofa },
  { id: 'desk', label: '책상', category: '테이블', icon: Square },
  { id: 'chair', label: '오피스 의자', category: '테이블', icon: Armchair },
  { id: 'drawer', label: '서랍장', category: '수납', icon: Layers },
  { id: 'rug', label: '러그', category: '수납', icon: Grid2X2 },
  { id: 'lamp', label: '조명', category: '수납', icon: Lamp },
  { id: 'plant', label: '화분', category: '수납', icon: Home },
] as const

const swatches = ['#2a2a30', '#6b6f78', '#b9bac2', '#7a5b46', '#3f6b46']

type FurnitureCategory = (typeof furnitureCategories)[number]
type FurnitureTemplate = (typeof furnitureItems)[number]
type PlacedFurniture = {
  id: string
  templateId: FurnitureTemplate['id']
  label: string
  category: FurnitureTemplate['category']
  material: string
  x: number
  y: number
}

const initialPlacedFurniture: PlacedFurniture[] = [
  { id: 'furniture-bed-1', templateId: 'bed', label: '플랫폼 침대', category: '침대', material: swatches[0], x: 0.48, y: 0.56 },
]

export function EditorPage() {
  const projectId = useParams().projectId ?? demoProjectId
  const auth = useAuth()
  const navigate = useNavigate()
  const { project, status, error } = useProject(projectId)
  const [activeTool, setActiveTool] = useState<(typeof tools)[number]['id']>('select')
  const [viewMode, setViewMode] = useState<'3d' | '2d'>('3d')
  const [material, setMaterial] = useState(swatches[0])
  const [activeCategory, setActiveCategory] = useState<FurnitureCategory>('전체')
  const [zoom, setZoom] = useState(100)
  const [notesOpen, setNotesOpen] = useState(false)
  const [notice, setNotice] = useState('모든 변경 저장됨')
  const [accountOpen, setAccountOpen] = useState(false)
  const accountMenuRef = useRef<HTMLDivElement | null>(null)
  const [history, setHistory] = useState<PlacedFurniture[][]>([initialPlacedFurniture])
  const [historyIndex, setHistoryIndex] = useState(0)
  const [selectedFurnitureId, setSelectedFurnitureId] = useState<string | null>(initialPlacedFurniture[0]?.id ?? null)
  const placedFurniture = history[historyIndex] ?? []
  const selectedFurniture = placedFurniture.find((item) => item.id === selectedFurnitureId) ?? placedFurniture[0] ?? null
  const selectedTemplate = selectedFurniture ? furnitureItems.find((item) => item.id === selectedFurniture.templateId) : undefined
  const SelectedIcon = selectedTemplate?.icon ?? BedDouble
  const filteredFurnitureItems = activeCategory === '전체'
    ? furnitureItems
    : furnitureItems.filter((item) => item.category === activeCategory)
  const userLabel = auth.status === 'signed-in' ? auth.user.displayName ?? 'RoomForge 계정' : 'Demo user'
  const userEmail = auth.status === 'signed-in' ? auth.user.email ?? '로그인됨' : 'Firebase config 연결 전'
  const initials = auth.status === 'signed-in'
    ? (auth.user.displayName ?? auth.user.email ?? 'SY').slice(0, 2).toUpperCase()
    : 'SY'

  useEffect(() => {
    if (!accountOpen) {
      return undefined
    }

    const closeOnOutsidePointer = (event: PointerEvent) => {
      if (!accountMenuRef.current?.contains(event.target as Node)) {
        setAccountOpen(false)
      }
    }

    window.addEventListener('pointerdown', closeOnOutsidePointer)
    return () => window.removeEventListener('pointerdown', closeOnOutsidePointer)
  }, [accountOpen])

  if (!project && status === 'loading') {
    return <StatePanel eyebrow="Editor" title="에디터 상태를 불러오는 중입니다" body="프로젝트 소유권과 저장된 편집 상태를 확인하고 있습니다." />
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

  function commitFurniture(nextFurniture: PlacedFurniture[], nextSelection: string | null, nextNotice: string) {
    const nextHistory = [...history.slice(0, historyIndex + 1), nextFurniture]
    setHistory(nextHistory)
    setHistoryIndex(nextHistory.length - 1)
    setSelectedFurnitureId(nextSelection)
    setNotice(nextNotice)
  }

  function addFurniture(item: FurnitureTemplate) {
    const offset = placedFurniture.length % 5
    const id = `${item.id}-${Date.now()}`
    const nextItem: PlacedFurniture = {
      id,
      templateId: item.id,
      label: item.label,
      category: item.category,
      material,
      x: 0.28 + offset * 0.1,
      y: 0.36 + offset * 0.07,
    }
    commitFurniture([...placedFurniture, nextItem], id, `${item.label} 배치됨`)
    setActiveTool('furniture')
  }

  function duplicateSelectedFurniture() {
    if (!selectedFurniture) return
    const id = `${selectedFurniture.templateId}-${Date.now()}`
    const duplicate = {
      ...selectedFurniture,
      id,
      label: `${selectedFurniture.label} 복사본`,
      x: Math.min(0.82, selectedFurniture.x + 0.08),
      y: Math.min(0.82, selectedFurniture.y + 0.08),
    }
    commitFurniture([...placedFurniture, duplicate], id, `${selectedFurniture.label} 복제됨`)
  }

  function deleteSelectedFurniture() {
    if (!selectedFurniture) return
    const nextFurniture = placedFurniture.filter((item) => item.id !== selectedFurniture.id)
    commitFurniture(nextFurniture, nextFurniture[0]?.id ?? null, `${selectedFurniture.label} 삭제됨`)
  }

  function undo() {
    if (historyIndex === 0) return
    const nextIndex = historyIndex - 1
    setHistoryIndex(nextIndex)
    setSelectedFurnitureId(history[nextIndex]?.[0]?.id ?? null)
    setNotice('실행 취소됨')
  }

  function redo() {
    if (historyIndex >= history.length - 1) return
    const nextIndex = historyIndex + 1
    setHistoryIndex(nextIndex)
    setSelectedFurnitureId(history[nextIndex]?.[0]?.id ?? null)
    setNotice('다시 실행됨')
  }

  function changeZoom(delta: number) {
    setZoom((current) => Math.min(160, Math.max(60, current + delta)))
  }

  async function handleSignOut() {
    await auth.signOut()
    setAccountOpen(false)
    navigate(routes.landing)
  }

  function exportLayoutImage() {
    const svg = createLayoutExportSvg(project!.name, placedFurniture)
    const url = URL.createObjectURL(new Blob([svg], { type: 'image/svg+xml' }))
    const link = document.createElement('a')
    link.href = url
    link.download = `${project!.id}-layout.svg`
    link.click()
    URL.revokeObjectURL(url)
    setNotice('SVG 이미지로 내보냄')
  }

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
          <StatusPill label={notice} tone={notice === '모든 변경 저장됨' ? 'success' : 'accent'} />
          <ThemeToggle />
          <div className="rf-menu-wrap" ref={accountMenuRef}>
            <button
              className="account-avatar"
              type="button"
              aria-label="계정"
              aria-expanded={accountOpen}
              onClick={() => setAccountOpen((open) => !open)}
            >
              {initials}
            </button>
            {accountOpen && (
              <div className="rf-popover rf-popover--right account-menu" role="menu">
                <strong>{userLabel}</strong>
                <small>{userEmail}</small>
                <Link role="menuitem" to={routes.projects} onClick={() => setAccountOpen(false)}>내 프로젝트</Link>
                {auth.status === 'signed-in' ? (
                  <button role="menuitem" type="button" onClick={handleSignOut}>로그아웃</button>
                ) : (
                  <Link role="menuitem" to={routes.login} onClick={() => setAccountOpen(false)}>로그인</Link>
                )}
              </div>
            )}
          </div>
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
          <button
            className={`editor-tool mt-auto ${notesOpen ? 'is-active' : ''}`}
            title="메모"
            type="button"
            onClick={() => setNotesOpen((open) => !open)}
          >
            <MessageSquare size={19} />
          </button>
        </aside>

        <aside className="editor-library-panel">
          <header>
            <h2>가구 라이브러리</h2>
            <Search size={15} />
          </header>
          <div className="editor-tabs" role="group" aria-label="가구 카테고리">
            {furnitureCategories.map((tab) => (
              <button className={activeCategory === tab ? 'is-active' : ''} key={tab} type="button" onClick={() => setActiveCategory(tab)}>
                {tab}
              </button>
            ))}
          </div>
          <div className="furniture-grid">
            {filteredFurnitureItems.map((item) => (
              <button className="furniture-card" key={item.label} type="button" title="배치" onClick={() => addFurniture(item)}>
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
            <button className="editor-icon-button" title="실행 취소" type="button" onClick={undo} disabled={historyIndex === 0}><Undo2 size={16} /></button>
            <button className="editor-icon-button" title="다시 실행" type="button" onClick={redo} disabled={historyIndex >= history.length - 1}><Redo2 size={16} /></button>
            <div className="canvas-actions">
              <button className="editor-icon-button" title="축소" type="button" onClick={() => changeZoom(-10)}><Minus size={16} /></button>
              <span>{zoom}%</span>
              <button className="editor-icon-button" title="확대" type="button" onClick={() => changeZoom(10)}><Plus size={16} /></button>
              <span className="snap-label"><Grid2X2 size={14} />스냅</span>
              <button className="rf-btn" type="button" onClick={exportLayoutImage}>
                <Download size={14} />
                이미지로 내보내기
              </button>
            </div>
          </div>

          <div className="editor-stage" style={{ '--editor-zoom': zoom / 100 } as React.CSSProperties}>
            {viewMode === '3d' ? (
              <RoomScene furniture={placedFurniture} selectedId={selectedFurnitureId} onSelect={setSelectedFurnitureId} />
            ) : (
              <FloorPlan furniture={placedFurniture} selectedId={selectedFurnitureId} onSelect={setSelectedFurnitureId} />
            )}
            {selectedFurniture && <div className="selection-badge"><span />{selectedFurniture.label} 선택됨 · 클릭으로 선택 변경</div>}
            {notesOpen && (
              <aside className="editor-notes-panel" aria-label="메모">
                <header>
                  <strong>메모</strong>
                  <button type="button" onClick={() => setNotesOpen(false)}>닫기</button>
                </header>
                <textarea defaultValue={`${project.name}\n- 창가 쪽 여백 확인\n- 침대 주변 통로 60cm 이상 유지`} />
              </aside>
            )}
          </div>
        </div>

        <aside className="editor-inspector-panel">
          <header>
            <SelectedIcon size={16} />
            <h2>{selectedFurniture?.label ?? '선택 없음'}</h2>
            <span>{selectedFurniture?.category ?? '가구'}</span>
          </header>
          <div className="inspector-body">
            <InspectorGroup title="치수">
              <Field label="W" value={selectedFurniture ? '2.30' : '0.00'} unit="m" />
              <Field label="D" value={selectedFurniture ? '2.75' : '0.00'} unit="m" />
              <Field label="H" value={selectedFurniture ? '0.55' : '0.00'} unit="m" />
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
                    onClick={() => {
                      setMaterial(swatch)
                      if (selectedFurniture) {
                        commitFurniture(
                          placedFurniture.map((item) => item.id === selectedFurniture.id ? { ...item, material: swatch } : item),
                          selectedFurniture.id,
                          `${selectedFurniture.label} 재질 변경됨`,
                        )
                      }
                    }}
                    aria-label={`${swatch} 재질`}
                  />
                ))}
              </div>
              <p className="material-name">다크 패브릭</p>
            </div>
            <div className="inspector-actions">
              <button className="rf-btn" type="button" onClick={duplicateSelectedFurniture} disabled={!selectedFurniture}><Copy size={14} />복제</button>
              <button className="danger-button" type="button" onClick={deleteSelectedFurniture} disabled={!selectedFurniture}><Trash2 size={14} />삭제</button>
            </div>
          </div>
          <footer className="room-info">
            <p className="inspector-label">공간 정보</p>
            <dl className="metric-dl">
              <dt>방 크기</dt><dd>5.2 x 6.0 m</dd>
              <dt>천장 높이</dt><dd>2.8 m</dd>
              <dt>바닥 면적</dt><dd>31.2 m²</dd>
              <dt>배치 가구</dt><dd>{placedFurniture.length}</dd>
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

function RoomScene({
  furniture,
  selectedId,
  onSelect,
}: {
  furniture: PlacedFurniture[]
  selectedId: string | null
  onSelect: (id: string) => void
}) {
  return (
    <div className="css-room-scene" aria-label="3D room preview">
      <div className="room-shell">
        <span className="room-plane room-floor" />
        <span className="room-plane room-back" />
        <span className="room-plane room-left" />
        <span className="room-plane room-right" />
        <span className="room-object room-desk" />
        <span className="room-object room-storage" />
        <span className="room-object room-window" />
        {furniture.map((item, index) => (
          <button
            className={`room-object room-added-object ${selectedId === item.id ? 'is-selected' : ''}`}
            key={item.id}
            type="button"
            style={{
              background: item.material,
              height: item.templateId === 'rug' ? '16%' : item.templateId === 'lamp' || item.templateId === 'plant' ? '12%' : '24%',
              left: `${item.x * 72 + 8}%`,
              top: `${item.y * 58 + 16}%`,
              width: item.templateId === 'rug' ? '32%' : item.templateId === 'bed' ? '28%' : '17%',
              zIndex: 4 + index,
            }}
            onClick={() => onSelect(item.id)}
          >
            <span>{item.label}</span>
          </button>
        ))}
      </div>
    </div>
  )
}

function FloorPlan({
  furniture,
  selectedId,
  onSelect,
}: {
  furniture: PlacedFurniture[]
  selectedId: string | null
  onSelect: (id: string) => void
}) {
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
        {furniture.map((item) => {
          const x = 44 + item.x * 380
          const y = 40 + item.y * 430
          const width = item.templateId === 'bed' ? 180 : item.templateId === 'rug' ? 210 : 84
          const height = item.templateId === 'bed' ? 190 : item.templateId === 'rug' ? 130 : 76
          const selected = selectedId === item.id
          return (
            <g key={item.id} onClick={() => onSelect(item.id)}>
              <rect className={selected ? 'plan-selected' : 'plan-furniture'} x={x} y={y} width={width} height={height} rx="8" />
              {selected && <line className="plan-selected-line" x1={x} y1={y + 32} x2={x + width} y2={y + 32} />}
              <text x={x + width / 2} y={y + height / 2}>{item.label}</text>
            </g>
          )
        })}
        <line className="plan-dim" x1="0" y1="-20" x2="520" y2="-20" />
        <text className="plan-label" x="260" y="-26">5.2 m</text>
        <line className="plan-dim" x1="-22" y1="0" x2="-22" y2="600" />
        <text className="plan-label" x="-26" y="300" transform="rotate(-90 -26 300)">6.0 m</text>
      </svg>
    </div>
  )
}

function createLayoutExportSvg(projectName: string, furniture: PlacedFurniture[]) {
  const items = furniture.map((item, index) => {
    const x = 70 + item.x * 380
    const y = 90 + item.y * 300
    return `<g><rect x="${x}" y="${y}" width="120" height="70" rx="10" fill="${item.material}" stroke="#8fb4ff" opacity="0.92"/><text x="${x + 60}" y="${y + 40}" text-anchor="middle" fill="#f8f8f5" font-size="13" font-family="IBM Plex Sans">${index + 1}. ${escapeSvgText(item.label)}</text></g>`
  }).join('')

  return `<svg xmlns="http://www.w3.org/2000/svg" width="960" height="640" viewBox="0 0 960 640"><rect width="960" height="640" fill="#0a0b0d"/><text x="48" y="60" fill="#f8f8f5" font-size="28" font-family="IBM Plex Sans" font-weight="700">${escapeSvgText(projectName)}</text><rect x="70" y="92" width="760" height="460" rx="12" fill="#15171c" stroke="#8fb4ff" opacity="0.7"/>${items}</svg>`
}

function escapeSvgText(value: string) {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
}
