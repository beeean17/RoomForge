import { useCallback, useEffect, useRef, useState } from 'react'

import type { EditorBridgeMessage } from '../editor/editorBridge'
import { isEditorBridgeMessage } from '../editor/editorBridge'
import {
  persistEditorBridgeEvent,
  type EditorEventPersistenceResult,
} from '../editor/editorEventPersistence'
import type { SourceImageState } from '../editor/editorSourceImages'
import type { WorkspaceProject } from '../projects/projectData'

const OPENCV_BRIDGE_VERSION = 1

export type OpenCvConversionStage =
  | 'idle'
  | 'source_loading'
  | 'runtime_loading'
  | 'extracting_candidates'
  | 'persisting_result'
  | 'complete'
  | 'failed'

export type OpenCvConversionState = {
  status: 'idle' | 'running' | 'complete' | 'failed'
  stage: OpenCvConversionStage
  failedStage?: OpenCvConversionStage
  progress: number
  phaseLabel: string
  detail: string
  qualityStatus?: string
  confidence?: number
  reason?: string
  persistence?: EditorEventPersistenceResult
}

type OpenCvConversionOptions = {
  active: boolean
  ownerUid?: string
  project: WorkspaceProject | null | undefined
  sourceImageState: SourceImageState
}

type UseOpenCvConversionWorkerResult = OpenCvConversionState & {
  cancel: () => void
}

const idleState: OpenCvConversionState = {
  status: 'idle',
  stage: 'idle',
  progress: 0,
  phaseLabel: '변환 대기',
  detail: '소스 이미지를 선택한 뒤 변환을 시작하세요.',
}

export const openCvConversionStageOrder: Array<{
  stage: Exclude<OpenCvConversionStage, 'idle' | 'failed'>
  label: string
  progress: number
}> = [
  { stage: 'source_loading', label: '소스 이미지 로드', progress: 12 },
  { stage: 'runtime_loading', label: 'OpenCV runtime 로드', progress: 35 },
  { stage: 'extracting_candidates', label: '후보 geometry 추출', progress: 72 },
  { stage: 'persisting_result', label: '결과 저장', progress: 90 },
  { stage: 'complete', label: '에디터 handoff', progress: 100 },
]

export function useOpenCvConversionWorker({
  active,
  ownerUid,
  project,
  sourceImageState,
}: OpenCvConversionOptions): UseOpenCvConversionWorkerResult {
  const [state, setState] = useState<OpenCvConversionState>(idleState)
  const workerRef = useRef<Worker | null>(null)
  const runIdRef = useRef(0)
  const projectRef = useRef(project)
  const sourceRef = useRef(sourceImageState)

  useEffect(() => {
    projectRef.current = project
    sourceRef.current = sourceImageState
  }, [project, sourceImageState])

  const cancel = useCallback(() => {
    runIdRef.current += 1
    workerRef.current?.terminate()
    workerRef.current = null
    setState({
      status: 'failed',
      stage: 'failed',
      failedStage: 'extracting_candidates',
      progress: 100,
      phaseLabel: '변환 취소됨',
      detail: '사용자가 변환 worker 실행을 중단했습니다.',
    })
  }, [])

  useEffect(() => {
    runIdRef.current += 1
    const runId = runIdRef.current
    let disposed = false
    let watchdogTimer: number | undefined
    let currentStage: OpenCvConversionStage = 'idle'
    let workerFailureReported = false

    workerRef.current?.terminate()
    workerRef.current = null

    function update(next: OpenCvConversionState) {
      if (disposed || runId !== runIdRef.current) return
      currentStage = next.stage
      setState(next)
    }

    function fail(stage: OpenCvConversionStage, phaseLabel: string, detail: string) {
      window.clearTimeout(watchdogTimer)
      workerRef.current?.terminate()
      workerRef.current = null
      update({
        status: 'failed',
        stage: 'failed',
        failedStage: stage,
        progress: 100,
        phaseLabel,
        detail,
      })
    }

    if (!active) {
      setState(idleState)
      return () => {
        disposed = true
      }
    }

    if (!project) {
      setState({
        status: 'failed',
        stage: 'failed',
        failedStage: 'source_loading',
        progress: 100,
        phaseLabel: '프로젝트 없음',
        detail: '변환을 실행할 프로젝트를 찾을 수 없습니다.',
      })
      return () => {
        disposed = true
      }
    }

    if (sourceImageState.status === 'loading') {
      setState({
        status: 'running',
        stage: 'source_loading',
        progress: 12,
        phaseLabel: '소스 이미지 로드 중',
        detail: 'Storage에서 최신 소스 이미지와 캡처 메타데이터를 불러오고 있습니다.',
      })
      return () => {
        disposed = true
      }
    }

    if (sourceImageState.status === 'error') {
      setState({
        status: 'failed',
        stage: 'failed',
        failedStage: 'source_loading',
        progress: 100,
        phaseLabel: '소스 이미지 로드 실패',
        detail: sourceImageState.error ?? '소스 이미지를 불러오지 못했습니다.',
      })
      return () => {
        disposed = true
      }
    }

    const source = sourceImageState.bridgePayload
    const sourceImage = source?.sourceImage
    if (!sourceImage?.dataUrl) {
      setState({
        status: 'failed',
        stage: 'failed',
        failedStage: 'source_loading',
        progress: 100,
        phaseLabel: '소스 이미지 없음',
        detail: 'OpenCV worker에 전달할 소스 이미지 바이트가 없습니다.',
      })
      return () => {
        disposed = true
      }
    }

    const worker = new Worker(new URL('../../../../editor/src/opencvWorker.ts', import.meta.url), {
      type: 'module',
    })
    workerRef.current = worker

    update({
      status: 'running',
      stage: 'runtime_loading',
      progress: 35,
      phaseLabel: 'OpenCV.js runtime 로드 중',
      detail: '브라우저 worker에서 OpenCV.js 모듈을 초기화하고 있습니다.',
    })

    watchdogTimer = window.setTimeout(() => {
      fail('runtime_loading', 'OpenCV worker 시간 초과', 'worker가 제한 시간 안에 응답하지 않았습니다.')
    }, 30000)

    worker.onerror = (event) => {
      if (workerFailureReported) {
        return
      }
      fail(
        failureStageFromCurrent(currentStage),
        'OpenCV worker 오류',
        workerErrorEventDetail(event),
      )
    }

    worker.onmessageerror = () => {
      fail(
        failureStageFromCurrent(currentStage),
        'OpenCV worker 메시지 오류',
        'OpenCV worker 응답을 브라우저가 역직렬화하지 못했습니다.',
      )
    }

    worker.onmessage = (event: MessageEvent<unknown>) => {
      if (disposed || runId !== runIdRef.current || !isEditorBridgeMessage(event.data)) {
        return
      }

      const message = event.data
      if (message.type === 'roomforge.opencv.progress') {
        update(conversionStateFromWorkerProgress(message.payload))
        return
      }

      if (message.type === 'roomforge.opencv.workerFailed') {
        workerFailureReported = true
        fail(
          failureStageFromPayload(message.payload, currentStage),
          'OpenCV worker 실패',
          messageDetail(message, 'OpenCV worker 실행 중 오류가 발생했습니다.'),
        )
        return
      }

      if (message.type === 'roomforge.opencv.runtimeLoaded') {
        update({
          status: 'running',
          stage: 'extracting_candidates',
          progress: 72,
          phaseLabel: '후보 geometry 추출 중',
          detail: 'Canny edge와 Hough line 기반으로 방 경계 후보를 계산하고 있습니다.',
        })
        worker.postMessage({
          type: 'roomforge.opencv.extractCandidates',
          version: OPENCV_BRIDGE_VERSION,
          requestId: `status-opencv-extract-${project.id}-${Date.now()}`,
          payload: { sourceImage },
        } satisfies EditorBridgeMessage)
        return
      }

      if (message.type === 'roomforge.opencv.runtimeFailed') {
        workerFailureReported = true
        fail('runtime_loading', 'OpenCV.js runtime 로드 실패', messageDetail(message, 'OpenCV.js runtime 초기화에 실패했습니다.'))
        return
      }

      if (message.type === 'roomforge.opencv.candidatesExtracted') {
        window.clearTimeout(watchdogTimer)
        worker.terminate()
        workerRef.current = null
        update({
          status: 'running',
          stage: 'persisting_result',
          progress: 90,
          phaseLabel: 'OpenCV 결과 저장 중',
          detail: '추출된 후보 geometry를 프로젝트 결과 문서로 저장하고 있습니다.',
          qualityStatus: stringValue(message.payload.qualityStatus),
          confidence: numberValue(message.payload.confidence),
          reason: stringValue(message.payload.reasonMessage),
        })

        void projectForPersistence(projectRef, project)
          .then((persistenceProject) => persistEditorBridgeEvent({
            message,
            project: persistenceProject,
            ownerUid,
            source: sourceRef.current.bridgePayload,
          }))
          .then((persistence) => {
            if (disposed || runId !== runIdRef.current) return
            setState({
              status: 'complete',
              stage: 'complete',
              progress: 100,
              phaseLabel: '변환 완료',
              detail:
                persistence.status === 'stored'
                  ? 'OpenCV 결과를 저장했습니다. 에디터로 이동합니다.'
                  : `${persistence.label}. 에디터에서 결과를 다시 확인합니다.`,
              qualityStatus: stringValue(message.payload.qualityStatus),
              confidence: numberValue(message.payload.confidence),
              reason: stringValue(message.payload.reasonMessage),
              persistence,
            })
          })
          .catch((error) => {
            if (disposed || runId !== runIdRef.current) return
            setState({
              status: 'complete',
              stage: 'complete',
              progress: 100,
              phaseLabel: '변환 완료',
              detail: `OpenCV 결과는 생성됐지만 저장은 실패했습니다. ${errorMessage(error)}`,
              qualityStatus: stringValue(message.payload.qualityStatus),
              confidence: numberValue(message.payload.confidence),
              reason: stringValue(message.payload.reasonMessage),
              persistence: {
                status: 'skipped',
                label: errorMessage(error),
              },
            })
          })
      }
    }

    worker.postMessage({
      type: 'roomforge.opencv.loadRuntime',
      version: OPENCV_BRIDGE_VERSION,
      requestId: `status-opencv-runtime-${project.id}-${Date.now()}`,
      payload: {},
    } satisfies EditorBridgeMessage)

    return () => {
      disposed = true
      window.clearTimeout(watchdogTimer)
      worker.terminate()
      if (workerRef.current === worker) {
        workerRef.current = null
      }
    }
  }, [
    active,
    ownerUid,
    project?.id,
    sourceImageState.bridgePayload?.sourceImage?.dataUrl,
    sourceImageState.sourceImageId,
    sourceImageState.status,
  ])

  return { ...state, cancel }
}

function failureStageFromCurrent(currentStage: OpenCvConversionStage): OpenCvConversionStage {
  if (currentStage === 'idle' || currentStage === 'complete' || currentStage === 'failed') {
    return 'extracting_candidates'
  }
  return currentStage
}

function failureStageFromPayload(
  payload: Record<string, unknown>,
  currentStage: OpenCvConversionStage,
): OpenCvConversionStage {
  const workerStage = stringValue(payload.stage)
  if (!workerStage) {
    return failureStageFromCurrent(currentStage)
  }
  return appStageFromWorkerStage(workerStage, numberValue(payload.progress) ?? 100)
}

function workerErrorEventDetail(event: ErrorEvent): string {
  const location = event.filename
    ? ` (${event.filename}:${event.lineno}:${event.colno})`
    : ''
  return `${event.message || 'OpenCV worker 실행 중 오류가 발생했습니다.'}${location}`
}

function conversionStateFromWorkerProgress(payload: Record<string, unknown>): OpenCvConversionState {
  const workerStage = stringValue(payload.stage) ?? 'extracting_candidates'
  const progress = clampProgress(numberValue(payload.progress) ?? 50)
  const stage = appStageFromWorkerStage(workerStage, progress)
  return {
    status: 'running',
    stage,
    progress,
    phaseLabel: koreanWorkerStageLabel(workerStage),
    detail: koreanWorkerStageDetail(workerStage, stringValue(payload.detail)),
  }
}

function appStageFromWorkerStage(workerStage: string, progress: number): OpenCvConversionStage {
  if (workerStage.startsWith('runtime_') || progress < 40) {
    return 'runtime_loading'
  }
  if (workerStage === 'source_image_missing') {
    return 'source_loading'
  }
  return 'extracting_candidates'
}

function koreanWorkerStageLabel(stage: string) {
  const labels: Record<string, string> = {
    runtime_loading: 'OpenCV.js runtime 로드 중',
    runtime_ready: 'OpenCV.js runtime 준비됨',
    source_image_received: '소스 이미지 전달됨',
    image_decoding: '소스 이미지 디코딩 중',
    image_decoded: '소스 이미지 디코딩 완료',
    preprocessing: '이미지 전처리 중',
    edge_detection: '엣지 검출 중',
    line_detection: '벽 후보 라인 검출 중',
    geometry_building: '후보 geometry 구성 중',
    quality_scoring: '후보 품질 계산 중',
    candidate_extraction_complete: '후보 geometry 추출 완료',
    source_image_missing: '소스 이미지 없음',
  }
  return labels[stage] ?? 'OpenCV worker 실행 중'
}

function koreanWorkerStageDetail(stage: string, fallback?: string) {
  const details: Record<string, string> = {
    runtime_loading: '브라우저 worker에서 OpenCV.js 모듈을 불러오고 있습니다.',
    runtime_ready: 'OpenCV.js 이미지 처리 API가 준비되었습니다.',
    source_image_received: 'Storage에서 불러온 소스 이미지가 worker 입력으로 전달되었습니다.',
    image_decoding: '이미지를 ImageBitmap과 처리용 canvas로 변환하고 있습니다.',
    image_decoded: '처리 가능한 픽셀 데이터가 준비되었습니다.',
    preprocessing: '그레이스케일 변환과 노이즈 완화를 적용하고 있습니다.',
    edge_detection: 'Canny edge detection으로 벽과 윤곽 후보를 찾고 있습니다.',
    line_detection: 'Hough line detection으로 벽 후보 선분을 찾고 있습니다.',
    geometry_building: '검출된 엣지와 라인으로 방 경계 후보를 조립하고 있습니다.',
    quality_scoring: '후보의 confidence와 검토 필요 여부를 계산하고 있습니다.',
    candidate_extraction_complete: 'OpenCV 후보 geometry 결과를 저장할 준비가 끝났습니다.',
    source_image_missing: 'OpenCV worker에 전달할 소스 이미지 바이트가 없습니다.',
  }
  return details[stage] ?? fallback ?? 'OpenCV worker 단계가 진행 중입니다.'
}

async function projectForPersistence(
  projectRef: React.RefObject<WorkspaceProject | null | undefined>,
  fallback: WorkspaceProject,
): Promise<WorkspaceProject> {
  for (let attempt = 0; attempt < 12; attempt += 1) {
    const current = projectRef.current ?? fallback
    if (current.latestJobId || attempt === 11) {
      return current
    }
    await new Promise((resolve) => window.setTimeout(resolve, 150))
  }
  return projectRef.current ?? fallback
}

function messageDetail(message: EditorBridgeMessage, fallback: string): string {
  return stringValue(message.payload.reasonMessage) ??
    stringValue(message.payload.message) ??
    stringValue(message.payload.error) ??
    fallback
}

function stringValue(value: unknown): string | undefined {
  return typeof value === 'string' && value.length > 0 ? value : undefined
}

function numberValue(value: unknown): number | undefined {
  return typeof value === 'number' && Number.isFinite(value) ? value : undefined
}

function clampProgress(value: number): number {
  return Math.min(Math.max(Math.round(value), 0), 100)
}

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error)
}
