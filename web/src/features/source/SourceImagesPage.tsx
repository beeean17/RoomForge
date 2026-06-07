import { Camera, Ruler, Save, Plus, RotateCcw, Smartphone, Trash2, Upload } from 'lucide-react'
import {
  collection,
  getFirestore,
  onSnapshot,
  orderBy,
  query,
  type DocumentData,
  type QueryDocumentSnapshot,
} from 'firebase/firestore'
import { getDownloadURL, getStorage, ref as storageRef } from 'firebase/storage'
import { useEffect, useRef, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'

import { ProductShell } from '../../components/shell/ProductShell'
import { StatePanel } from '../../components/ui/StatePanel'
import { StatusPill } from '../../components/ui/StatusPill'
import { roomForgeFirebaseApp } from '../../firebase/config'
import { demoProjectId } from '../../lib/routes'
import { routes } from '../../lib/routes'
import { useAuth } from '../auth/AuthProvider'
import { sourceDirections, type SourceDirection } from '../projects/projectData'
import {
  createProjectReconstructionJob,
  saveProjectRoomDimensions,
  useProject,
  useProjectRoomDimensions,
  type RoomDimensionsInput,
} from '../projects/projectRepository'

type SourceSlot = SourceDirection & {
  previewUrl?: string
  fileName?: string
}

type ExtraImage = {
  id: string
  src: string
  name: string
}

type RemoteSourceImagesState = {
  status: 'idle' | 'loading' | 'ready' | 'error'
  images: RemoteSourceImage[]
  error: string | null
}

type RemoteSourceImage = {
  id: string
  sourceImageId: string
  storagePath: string
  previewUrl?: string
  name: string
  role?: string
}

type RoomDimensionDraft = {
  width: string
  depth: string
  height: string
}

const sourceRoleToSlotKey: Partial<Record<string, SourceDirection['key']>> = {
  front_left_corner: 'NW',
  front_wall: 'N',
  front_right_corner: 'NE',
  left_wall: 'W',
  right_wall: 'E',
  back_left_corner: 'SW',
  back_wall: 'S',
  back_right_corner: 'SE',
}

export function SourceImagesPage() {
  const projectId = useParams().projectId ?? demoProjectId
  const navigate = useNavigate()
  const auth = useAuth()
  const { project, status, error, source } = useProject(projectId)
  const roomDimensionsState = useProjectRoomDimensions(project?.id)
  const remoteImages = useProjectSourceImages(projectId)
  const [sourceSlots, setSourceSlots] = useState<SourceSlot[]>([])
  const [extraImages, setExtraImages] = useState<ExtraImage[]>([])
  const [roomDimensionDraft, setRoomDimensionDraft] = useState<RoomDimensionDraft>({
    width: '5.20',
    depth: '6.00',
    height: '2.80',
  })
  const [roomDimensionSaveState, setRoomDimensionSaveState] = useState<'idle' | 'saving' | 'saved' | 'error'>('idle')
  const [roomDimensionError, setRoomDimensionError] = useState<string | null>(null)
  const [pendingSlotKey, setPendingSlotKey] = useState<SourceDirection['key'] | null>(null)
  const [mobileHandoffOpen, setMobileHandoffOpen] = useState(false)
  const [reconstructionQueued, setReconstructionQueued] = useState(false)
  const [reconstructionError, setReconstructionError] = useState<string | null>(null)
  const sourceInputRef = useRef<HTMLInputElement | null>(null)
  const extraInputRef = useRef<HTMLInputElement | null>(null)

  useEffect(() => {
    if (!project) {
      setSourceSlots([])
      setExtraImages([])
      return
    }

    if (source === 'firebase') {
      const syncedImages = buildSourceDisplayState(remoteImages.images)
      setSourceSlots(syncedImages.sourceSlots)
      setExtraImages(syncedImages.extraImages)
      return
    }

    setSourceSlots(initialSourceSlots(false))
    setExtraImages([])
  }, [project, remoteImages.images, source])

  useEffect(() => {
    if (roomDimensionsState.status !== 'ready' && roomDimensionsState.status !== 'empty') {
      return
    }

    setRoomDimensionDraft({
      width: formatDimensionInput(roomDimensionsState.dimensions.widthM),
      depth: formatDimensionInput(roomDimensionsState.dimensions.depthM),
      height: formatDimensionInput(roomDimensionsState.dimensions.heightM),
    })
    setRoomDimensionSaveState('idle')
    setRoomDimensionError(null)
  }, [
    roomDimensionsState.dimensions.depthM,
    roomDimensionsState.dimensions.heightM,
    roomDimensionsState.dimensions.widthM,
    roomDimensionsState.status,
  ])

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
  const hasPersistedSourceImages =
    Boolean(project.latestSourceImageId) || project.imageCount > 0 || remoteImages.images.length > 0
  const mobileCaptureHref = `roomforge://projects/${project.id}/capture`
  const parsedRoomDimensions = parseRoomDimensionDraft(roomDimensionDraft)
  const roomDimensionsValid = parsedRoomDimensions !== null

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

  async function startConversion() {
    const currentProject = project
    if (!currentProject) {
      return
    }

    setReconstructionQueued(true)
    setReconstructionError(null)

    if (!parsedRoomDimensions) {
      setReconstructionQueued(false)
      setRoomDimensionError('방 가로, 세로, 천장 높이를 0보다 큰 미터 값으로 입력하세요.')
      return
    }

    if (source !== 'firebase') {
      window.setTimeout(() => navigate(`${routes.status(currentProject.id)}?convert=1`), 650)
      return
    }

    if (auth.status !== 'signed-in') {
      navigate(routes.login)
      return
    }

    try {
      await createProjectReconstructionJob(currentProject, auth.user, parsedRoomDimensions)
      navigate(`${routes.status(currentProject.id)}?convert=1`)
    } catch (error) {
      setReconstructionQueued(false)
      setReconstructionError(error instanceof Error ? error.message : String(error))
    }
  }

  function updateRoomDimensionDraft(key: keyof RoomDimensionDraft, value: string) {
    setRoomDimensionDraft((current) => ({ ...current, [key]: value }))
    setRoomDimensionSaveState('idle')
    setRoomDimensionError(null)
  }

  async function saveRoomDimensionsDraft() {
    if (!project) {
      return
    }
    if (!parsedRoomDimensions) {
      setRoomDimensionSaveState('error')
      setRoomDimensionError('방 가로, 세로, 천장 높이를 0보다 큰 미터 값으로 입력하세요.')
      return
    }
    if (auth.status !== 'signed-in') {
      navigate(routes.login)
      return
    }

    setRoomDimensionSaveState('saving')
    setRoomDimensionError(null)
    try {
      await saveProjectRoomDimensions(project.id, auth.user, parsedRoomDimensions)
      setRoomDimensionSaveState('saved')
    } catch (error) {
      setRoomDimensionSaveState('error')
      setRoomDimensionError(error instanceof Error ? error.message : String(error))
    }
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
          <button
            className="rf-btn rf-btn--primary"
            type="button"
            onClick={startConversion}
            disabled={reconstructionQueued || !roomDimensionsValid || (source === 'firebase' && !hasPersistedSourceImages)}
          >
            <RotateCcw size={15} />
            {reconstructionQueued ? '변환 화면 준비 중' : '2D/3D로 변환'}
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

      {remoteImages.status === 'error' && (
        <section className="data-notice data-notice--danger">
          <strong>소스 이미지 동기화 실패</strong>
          <span>{remoteImages.error}</span>
        </section>
      )}

      {reconstructionError && (
        <section className="data-notice data-notice--danger">
          <strong>변환을 시작하지 못했습니다</strong>
          <span>{reconstructionError}</span>
        </section>
      )}

      <section className="coverage-banner">
        <span className="coverage-icon"><Camera size={20} /></span>
        <div>
          <strong>8개 각도 중 {filledCount}개 촬영됨 · <span>{emptyCount}개</span>가 비어 있어요</strong>
          <p>{hasSourceImages ? '현재 상태로 2D/3D 변환은 가능하지만, 비어 있는 각도를 채우면 모서리 정확도가 올라갑니다.' : '첫 사진을 업로드하거나 모바일 앱 가이드 촬영으로 빈 슬롯을 채우세요.'}</p>
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
          <article className="summary-card source-room-dimensions-card">
            <header>
              <span><Ruler size={18} /></span>
              <div>
                <h2>실제 방 치수</h2>
                <p>가구와 문·창문 배치 스케일에 사용할 기준값입니다.</p>
              </div>
            </header>
            <div className="dimension-field-grid">
              <label>
                <span>가로</span>
                <input
                  inputMode="decimal"
                  min="0.1"
                  step="0.01"
                  type="number"
                  value={roomDimensionDraft.width}
                  onChange={(event) => updateRoomDimensionDraft('width', event.currentTarget.value)}
                />
                <small>m</small>
              </label>
              <label>
                <span>세로</span>
                <input
                  inputMode="decimal"
                  min="0.1"
                  step="0.01"
                  type="number"
                  value={roomDimensionDraft.depth}
                  onChange={(event) => updateRoomDimensionDraft('depth', event.currentTarget.value)}
                />
                <small>m</small>
              </label>
              <label>
                <span>천장</span>
                <input
                  inputMode="decimal"
                  min="0.1"
                  step="0.01"
                  type="number"
                  value={roomDimensionDraft.height}
                  onChange={(event) => updateRoomDimensionDraft('height', event.currentTarget.value)}
                />
                <small>m</small>
              </label>
            </div>
            <div className="source-room-dimensions-actions">
              <span>
                {roomDimensionsState.status === 'loading'
                  ? '저장된 치수를 불러오는 중'
                  : roomDimensionSaveState === 'saved'
                    ? '저장됨'
                    : `${roomDimensionDraft.width || '-'} x ${roomDimensionDraft.depth || '-'} m`}
              </span>
              <button
                className="rf-btn"
                type="button"
                onClick={saveRoomDimensionsDraft}
                disabled={!roomDimensionsValid || roomDimensionSaveState === 'saving'}
              >
                <Save size={14} />
                {roomDimensionSaveState === 'saving' ? '저장 중' : '치수 저장'}
              </button>
            </div>
            {(roomDimensionError || roomDimensionsState.error) && (
              <p className="source-room-dimensions-error">
                {roomDimensionError ?? roomDimensionsState.error}
              </p>
            )}
          </article>
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

function parseRoomDimensionDraft(draft: RoomDimensionDraft): RoomDimensionsInput | null {
  const widthM = positiveInputNumber(draft.width)
  const depthM = positiveInputNumber(draft.depth)
  const heightM = positiveInputNumber(draft.height)
  if (!widthM || !depthM || !heightM) {
    return null
  }
  return { widthM, depthM, heightM }
}

function positiveInputNumber(value: string) {
  const parsed = Number(value)
  return Number.isFinite(parsed) && parsed > 0 ? parsed : null
}

function formatDimensionInput(value: number) {
  return value.toFixed(2)
}

function initialSourceSlots(hasSourceImages: boolean): SourceSlot[] {
  if (hasSourceImages) {
    return sourceDirections
  }
  return sourceDirections.map((direction) =>
    direction.key === 'ROOM' ? direction : { ...direction, filled: false, quality: undefined, brightness: undefined },
  )
}

function useProjectSourceImages(projectId: string | undefined): RemoteSourceImagesState {
  const auth = useAuth()
  const authUserId = auth.status === 'signed-in' ? auth.user.uid : null
  const [state, setState] = useState<RemoteSourceImagesState>({
    status: 'idle',
    images: [],
    error: null,
  })

  useEffect(() => {
    if (!auth.isConfigured || auth.status !== 'signed-in' || !projectId) {
      setState({ status: 'idle', images: [], error: null })
      return undefined
    }

    const app = roomForgeFirebaseApp()
    const firestore = getFirestore(app)
    const storage = getStorage(app)
    const sourceImages = query(
      collection(firestore, 'projects', projectId, 'source_images'),
      orderBy('uploaded_at', 'desc'),
    )
    let active = true
    let snapshotVersion = 0

    setState((current) => ({ status: 'loading', images: current.images, error: null }))

    const unsubscribe = onSnapshot(
      sourceImages,
      (snapshot) => {
        const version = ++snapshotVersion
        const metadata = snapshot.docs
          .map(remoteSourceImageFromSnapshot)
          .filter(isRemoteSourceImage)

        Promise.all(
          metadata.map(async (image) => {
            try {
              return {
                ...image,
                previewUrl: await getDownloadURL(storageRef(storage, image.storagePath)),
              }
            } catch {
              return image
            }
          }),
        ).then((images) => {
          if (!active || version !== snapshotVersion) return
          setState({ status: 'ready', images, error: null })
        })
      },
      (error) => {
        if (!active) return
        setState({ status: 'error', images: [], error: error.message })
      },
    )

    return () => {
      active = false
      unsubscribe()
    }
  }, [auth.isConfigured, auth.status, authUserId, projectId])

  return state
}

function buildSourceDisplayState(images: RemoteSourceImage[]) {
  const sourceSlots = initialSourceSlots(false)
  const extraImages: ExtraImage[] = []

  images.forEach((image, index) => {
    const slotKey = image.role ? sourceRoleToSlotKey[image.role] : undefined
    const previewUrl = image.previewUrl
    if (!previewUrl) {
      return
    }

    if (slotKey) {
      const slotIndex = sourceSlots.findIndex((slot) => slot.key === slotKey)
      if (slotIndex >= 0 && !sourceSlots[slotIndex].filled) {
        sourceSlots[slotIndex] = {
          ...sourceSlots[slotIndex],
          filled: true,
          quality: 'ok',
          brightness: 0.72 + (index % 5) * 0.05,
          previewUrl,
          fileName: image.name,
        }
        return
      }
    }

    extraImages.push({
      id: image.id,
      src: previewUrl,
      name: image.name,
    })
  })

  return { sourceSlots, extraImages }
}

function remoteSourceImageFromSnapshot(
  snapshot: QueryDocumentSnapshot<DocumentData>,
): RemoteSourceImage | null {
  const data = snapshot.data()
  const storagePath = stringValue(data.storage_path)
  if (!storagePath) {
    return null
  }

  const sourceImageId = stringValue(data.source_image_id) ?? snapshot.id
  return {
    id: snapshot.id,
    sourceImageId,
    storagePath,
    name: stringValue(data.original_filename)
      ?? stringValue(data.stored_filename)
      ?? `${sourceImageId}.jpg`,
    role: stringValue(data.capture_image_role) ?? undefined,
  }
}

function isRemoteSourceImage(image: RemoteSourceImage | null): image is RemoteSourceImage {
  return image !== null
}

function stringValue(value: unknown) {
  return typeof value === 'string' && value.length > 0 ? value : null
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
      {direction.previewUrl ? (
        <img src={direction.previewUrl} alt="" style={{ filter: `brightness(${direction.brightness ?? 0.8}) saturate(.9)` }} />
      ) : (
        <span className="capture-cell-placeholder">이미지 없음</span>
      )}
      {direction.quality === 'warn' && <StatusPill label="흐릿함" tone="warning" />}
      <div className="capture-actions">
        <button type="button" onClick={onReplace}>교체</button>
        <button type="button" aria-label={`${direction.label} 삭제`} onClick={onDelete}><Trash2 size={13} /></button>
      </div>
    </div>
  )
}
