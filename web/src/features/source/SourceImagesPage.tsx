import { Camera, Plus, RotateCcw, Smartphone, Trash2, Upload } from 'lucide-react'
import { useEffect, useRef, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'

import { ProductShell } from '../../components/shell/ProductShell'
import { StatePanel } from '../../components/ui/StatePanel'
import { StatusPill } from '../../components/ui/StatusPill'
import { demoProjectId } from '../../lib/routes'
import { routes } from '../../lib/routes'
import { sourceDirections, type SourceDirection } from '../projects/projectData'
import { useProject } from '../projects/projectRepository'

type SourceSlot = SourceDirection & {
  previewUrl?: string
  fileName?: string
}

type ExtraImage = {
  id: string
  src: string
  name: string
}

export function SourceImagesPage() {
  const projectId = useParams().projectId ?? demoProjectId
  const navigate = useNavigate()
  const { project, status, error } = useProject(projectId)
  const [sourceSlots, setSourceSlots] = useState<SourceSlot[]>([])
  const [extraImages, setExtraImages] = useState<ExtraImage[]>([])
  const [pendingSlotKey, setPendingSlotKey] = useState<SourceDirection['key'] | null>(null)
  const [mobileHandoffOpen, setMobileHandoffOpen] = useState(false)
  const [reconstructionQueued, setReconstructionQueued] = useState(false)
  const sourceInputRef = useRef<HTMLInputElement | null>(null)
  const extraInputRef = useRef<HTMLInputElement | null>(null)

  useEffect(() => {
    if (!project) {
      setSourceSlots([])
      setExtraImages([])
      return
    }

    const nextSlots = initialSourceSlots(project.imageCount > 0)
    const filledCount = nextSlots.filter((direction) => direction.filled && direction.key !== 'ROOM').length
    setSourceSlots(nextSlots)
    setExtraImages(
      Array.from({ length: Math.max(0, project.imageCount - filledCount) }, (_, index) => ({
        id: `demo-extra-${project.id}-${index}`,
        src: '/assets/room.png',
        name: `추가 사진 ${index + 1}`,
      })),
    )
  }, [project])

  if (!project && status === 'loading') {
    return <StatePanel eyebrow="Source" title="소스 이미지를 불러오는 중입니다" body="프로젝트 접근 권한과 업로드 상태를 확인하고 있습니다." />
  }

  if (!project) {
    return (
      <StatePanel
        eyebrow="Source"
        title="프로젝트를 찾을 수 없습니다"
        body={error ?? '요청한 프로젝트가 없거나 현재 계정에 접근 권한이 없습니다.'}
        action={<a className="rf-btn rf-btn--primary" href={routes.projects}>프로젝트 목록</a>}
      />
    )
  }

  const filledCount = sourceSlots.filter((direction) => direction.filled && direction.key !== 'ROOM').length
  const emptyCount = 8 - filledCount
  const extraImageCount = extraImages.length
  const hasSourceImages = filledCount > 0 || extraImageCount > 0
  const mobileCaptureHref = `roomforge://projects/${project.id}/capture`

  function openSourcePicker(slotKey: SourceDirection['key'] | null = null) {
    setPendingSlotKey(slotKey)
    sourceInputRef.current?.click()
  }

  function handleSourceFiles(files: FileList | null) {
    const imageFiles = Array.from(files ?? []).filter((file) => file.type.startsWith('image/'))
    if (imageFiles.length === 0) {
      setPendingSlotKey(null)
      return
    }

    setSourceSlots((currentSlots) => {
      const nextSlots = currentSlots.map((slot) => ({ ...slot }))
      const targetKeys = pendingSlotKey
        ? [pendingSlotKey]
        : nextSlots.filter((slot) => slot.key !== 'ROOM' && !slot.filled).map((slot) => slot.key)

      imageFiles.forEach((file, index) => {
        const targetKey = targetKeys[index] ?? targetKeys[targetKeys.length - 1]
        const targetIndex = nextSlots.findIndex((slot) => slot.key === targetKey)
        if (targetIndex >= 0) {
          nextSlots[targetIndex] = {
            ...nextSlots[targetIndex],
            filled: true,
            quality: 'ok',
            brightness: 0.78 + (index % 4) * 0.05,
            previewUrl: URL.createObjectURL(file),
            fileName: file.name,
          }
        }
      })

      return nextSlots
    })
    setPendingSlotKey(null)
    if (sourceInputRef.current) {
      sourceInputRef.current.value = ''
    }
  }

  function handleExtraFiles(files: FileList | null) {
    const imageFiles = Array.from(files ?? []).filter((file) => file.type.startsWith('image/'))
    if (imageFiles.length > 0) {
      setExtraImages((current) => [
        ...current,
        ...imageFiles.map((file) => ({
          id: `${file.name}-${file.lastModified}-${crypto.randomUUID()}`,
          src: URL.createObjectURL(file),
          name: file.name,
        })),
      ])
    }
    if (extraInputRef.current) {
      extraInputRef.current.value = ''
    }
  }

  function deleteSourceSlot(slotKey: SourceDirection['key']) {
    setSourceSlots((currentSlots) =>
      currentSlots.map((slot) =>
        slot.key === slotKey
          ? { ...slot, filled: false, quality: undefined, brightness: undefined, previewUrl: undefined, fileName: undefined }
          : slot,
      ),
    )
  }

  function queueReconstruction() {
    setReconstructionQueued(true)
    window.setTimeout(() => navigate(routes.status(project!.id)), 650)
  }

  return (
    <ProductShell active="source" project={project}>
      <header className="page-head">
        <div>
          <h1>소스 이미지</h1>
          <p>방을 위에서 보고 둘러싼 8개 각도로 촬영을 채우고, 그 밖의 디테일 사진을 추가합니다.</p>
        </div>
        <div className="workspace-toolbar">
          <button className="rf-btn" type="button" onClick={() => openSourcePicker()}>
            <Upload size={16} />
            업로드
          </button>
          <button className="rf-btn rf-btn--primary" type="button" onClick={queueReconstruction} disabled={reconstructionQueued}>
            <RotateCcw size={15} />
            {reconstructionQueued ? '재구성 큐 등록 중' : '재구성 다시 실행'}
          </button>
        </div>
      </header>
      <input
        ref={sourceInputRef}
        hidden
        type="file"
        accept="image/*"
        multiple={!pendingSlotKey}
        onChange={(event) => handleSourceFiles(event.currentTarget.files)}
      />
      <input
        ref={extraInputRef}
        hidden
        type="file"
        accept="image/*"
        multiple
        onChange={(event) => handleExtraFiles(event.currentTarget.files)}
      />

      {mobileHandoffOpen && (
        <section className="data-notice">
          <strong>모바일 촬영 링크</strong>
          <span>앱이 설치되어 있으면 가이드 촬영으로 이동합니다.</span>
          <a className="rf-inline-link" href={mobileCaptureHref}>앱 열기</a>
        </section>
      )}

      <section className="coverage-banner">
        <span className="coverage-icon"><Camera size={20} /></span>
        <div>
          <strong>8개 각도 중 {filledCount}개 촬영됨 · <span>{emptyCount}개</span>가 비어 있어요</strong>
          <p>{hasSourceImages ? '현재 상태로 재구성은 가능하지만, 비어 있는 각도를 채우면 모서리 정확도가 올라갑니다.' : '첫 사진을 업로드하거나 모바일 앱 가이드 촬영으로 빈 슬롯을 채우세요.'}</p>
        </div>
        <button className="rf-btn" type="button" onClick={() => setMobileHandoffOpen(true)}>
          <Smartphone size={15} />
          앱으로 빈 각도 촬영
        </button>
      </section>

      <section className="source-layout">
        <div className="source-main">
          <div className="section-title-row">
            <h2>각도별 촬영</h2>
            <StatusPill label={`${filledCount} / 8`} tone="warning" />
          </div>

          <div className="capture-grid" aria-label="각도별 촬영 슬롯">
            {sourceSlots.map((direction) => (
              <CaptureCell
                direction={direction}
                key={direction.key}
                onCapture={() => openSourcePicker(direction.key)}
                onDelete={() => deleteSourceSlot(direction.key)}
                onReplace={() => openSourcePicker(direction.key)}
              />
            ))}
          </div>
        </div>

        <aside className="source-guide">
          <article className="summary-card">
            <h2>왜 8개 각도인가요?</h2>
            <p>방을 위에서 보고 둘러싼 여덟 각도에서 고르게 찍으면, 벽·모서리·개구부가 빠짐없이 겹쳐 재구성 정확도가 올라갑니다.</p>
            <ul>
              <li>각 각도에서 방 전체가 프레임에 들어오게</li>
              <li>인접한 각도끼리 시야가 30~50% 겹치게</li>
              <li>모서리 각도가 모서리 정확도를 좌우</li>
            </ul>
          </article>
          <article className="app-guide-card">
            <span><Smartphone size={20} /></span>
            <div>
              <strong>앱 가이드 촬영</strong>
              <p>앱이 각도를 안내하며 빈 칸을 채워줍니다.</p>
            </div>
            <button type="button" onClick={() => setMobileHandoffOpen(true)}>연결</button>
          </article>
        </aside>
      </section>

      <section className="extra-source-section">
        <div className="section-title-row">
          <h2>추가 사진</h2>
          <StatusPill label={`+${extraImageCount}`} tone={extraImageCount > 0 ? 'accent' : 'muted'} />
          <span>{extraImageCount > 0 ? `특정 각도에 매이지 않는 디테일·접사 ${extraImageCount}장` : '추가된 디테일 사진이 없습니다'}</span>
        </div>
        <div className="extra-grid">
          <button className="extra-cell extra-cell--add" type="button" onClick={() => extraInputRef.current?.click()}>
            <Plus size={20} />
            <span>추가</span>
          </button>
          {extraImages.slice(0, 11).map((image, index) => (
            <div className="extra-cell" key={image.id}>
              <img src={image.src} alt="" style={{ filter: `brightness(${0.58 + (index % 6) * 0.07}) saturate(.86)` }} />
              <button type="button" aria-label={`${image.name} 삭제`} onClick={() => setExtraImages((current) => current.filter((item) => item.id !== image.id))}>
                <Trash2 size={13} />
              </button>
            </div>
          ))}
        </div>
      </section>
    </ProductShell>
  )
}

function initialSourceSlots(hasSourceImages: boolean): SourceSlot[] {
  if (hasSourceImages) {
    return sourceDirections
  }
  return sourceDirections.map((direction) =>
    direction.key === 'ROOM' ? direction : { ...direction, filled: false, quality: undefined, brightness: undefined },
  )
}

function CaptureCell({
  direction,
  onCapture,
  onDelete,
  onReplace,
}: {
  direction: SourceSlot
  onCapture: () => void
  onDelete: () => void
  onReplace: () => void
}) {
  if (direction.key === 'ROOM') {
    return (
      <div className="capture-cell capture-cell--room">
        <span>위에서 본 방</span>
        <svg viewBox="0 0 120 120" aria-hidden="true">
          <rect x="16" y="24" width="88" height="74" rx="4" />
          <line x1="46" y1="24" x2="74" y2="24" />
          <path d="M16 70a14 14 0 0 0 14 14" />
          <rect x="60" y="42" width="34" height="42" rx="2" />
        </svg>
        <strong>{direction.label}</strong>
      </div>
    )
  }

  if (!direction.filled) {
    return (
      <button className="capture-cell capture-cell--empty" type="button" onClick={onCapture}>
        <Camera size={22} />
        <span>촬영 필요</span>
      </button>
    )
  }

  return (
    <div className="capture-cell capture-cell--filled">
      <img src={direction.previewUrl ?? '/assets/room.png'} alt="" style={{ filter: `brightness(${direction.brightness ?? 0.8}) saturate(.9)` }} />
      {direction.quality === 'warn' && <StatusPill label="흐릿함" tone="warning" />}
      <div className="capture-actions">
        <button type="button" onClick={onReplace}>교체</button>
        <button type="button" aria-label={`${direction.label} 삭제`} onClick={onDelete}><Trash2 size={13} /></button>
      </div>
    </div>
  )
}
