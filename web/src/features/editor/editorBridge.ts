import type { WorkspaceProject } from '../projects/projectData'
import type { ProjectRoomDimensions } from '../projects/projectRepository'

export const EDITOR_BRIDGE_VERSION = 1

export type EditorBridgePayload = Record<string, unknown>

export type EditorBridgeMessage = {
  type: string
  version: number
  payload: EditorBridgePayload
  requestId?: string
}

type InitializeMessageOptions = {
  project: WorkspaceProject
  requestId: string
  route: string
  source?: EditorSourceImageBridgePayload
  opencvResult?: EditorOpenCvResultBridgePayload
  sceneUnderstandingResult?: EditorSceneUnderstandingResultBridgePayload
  roomDimensions?: ProjectRoomDimensions
}

export type EditorSourceImageBridgePayload = {
  sourceImage?: {
    sourceImageId: string
    dataUrl: string
    widthPx?: number
    heightPx?: number
    contentType?: string
  }
  captureSession?: {
    captureSessionId: string
    projectId?: string
    roomDimensionsId?: string
    captureMethod?: string
    depthEnabled: boolean
    availableRoles: string[]
    images: Array<{
      captureImageId: string
      captureSessionId: string
      sourceImageId: string
      role: string
      storagePath?: string
      contentType?: string
      widthPx?: number
      heightPx?: number
      captureOrder?: number
      guidanceState?: string
    }>
  }
}

export type EditorOpenCvResultBridgePayload = {
  resultId: string
  jobId: string
  sourceImageId: string
  coordinateSpace: 'image_pixels'
  algorithm: string
  openCvVersion?: string
  confidence?: number
  qualityStatus: 'success' | 'review_required' | 'failed'
  reasonCode?: string
  reasonMessage?: string
  candidateGeometry: Record<string, unknown>
}

export type EditorSceneUnderstandingResultBridgePayload = {
  resultId: string
  captureSessionId: string
  providerType: string
  algorithmId: string
  modelId?: string
  runtime?: string
  detectorScoreThreshold?: number
  confidenceScore?: number
  qualityStatus: 'success' | 'review_required' | 'failed'
  failureReasonCode?: string
  failureReason?: string
  coverage?: Record<string, unknown>
  candidateObjects: unknown[]
  placedObjects: unknown[]
  confirmedObjects: unknown[]
  structuralFixtures: unknown[]
}

export function editorFrameSrc(projectId: string): string {
  const configuredUrl = import.meta.env.VITE_ROOMFORGE_EDITOR_URL as string | undefined
  const baseUrl = configuredUrl?.trim() || (import.meta.env.DEV ? 'http://127.0.0.1:9239/' : '/editor/')
  const url = new URL(baseUrl, window.location.origin)
  url.searchParams.set('projectId', projectId)
  url.searchParams.set('locale', 'ko')
  return url.toString()
}

export function editorFrameOrigin(frameSrc: string): string {
  return new URL(frameSrc, window.location.origin).origin
}

export function createEditorInitializeMessage({
  project,
  requestId,
  route,
  source,
  opencvResult,
  sceneUnderstandingResult,
  roomDimensions,
}: InitializeMessageOptions): EditorBridgeMessage {
  const metricRoom = roomDimensions ?? {
    roomDimensionsId: 'current',
    widthM: 4.2,
    depthM: 3.6,
    heightM: 2.7,
    unit: 'meters',
  }
  const sceneCandidateObjects = sceneUnderstandingResult?.candidateObjects ?? []
  const scenePlacedObjects = sceneUnderstandingResult?.placedObjects ?? []
  const sceneConfirmedObjects = sceneUnderstandingResult?.confirmedObjects ?? []
  const sceneStructuralFixtures = sceneUnderstandingResult?.structuralFixtures ?? []

  return {
    type: 'roomforge.scene.initialize',
    version: EDITOR_BRIDGE_VERSION,
    requestId,
    payload: {
      host: {
        app: 'roomforge-react-web',
        route,
        projectId: project.id,
        persistenceOwner: 'react_web_firebase_host',
      },
      project: {
        projectId: project.id,
        name: project.name,
        status: project.status,
        statusLabel: project.statusLabel,
        imageCount: project.imageCount,
      },
      detectorRuntime: {
        modelAssetsPresent: false,
        scoreThreshold: 0.45,
      },
      ...(source?.sourceImage ? { sourceImage: source.sourceImage } : {}),
      ...(source?.captureSession ? { captureSession: source.captureSession } : {}),
      ...(opencvResult ? { opencvResult } : {}),
      ...(sceneUnderstandingResult ? { sceneUnderstandingResult } : {}),
      roomDimensions: {
        roomDimensionsId: metricRoom.roomDimensionsId,
        unit: metricRoom.unit,
        widthMeters: metricRoom.widthM,
        depthMeters: metricRoom.depthM,
        heightMeters: metricRoom.heightM,
      },
      scene: {
        sceneId: `${project.id}-editor-scene`,
        coordinateSpace: 'meters',
        unit: 'meters',
        viewMode: '2d',
        room: {
          objectId: 'room-shell',
          label: project.name,
          heightMeters: metricRoom.heightM,
          floorPlan: {
            floorPlanId: `${project.id}-floor-plan`,
            metricGeometry: {
              coordinateSpace: 'meters',
              points: [
                { x: 0, y: 0 },
                { x: metricRoom.widthM, y: 0 },
                { x: metricRoom.widthM, y: metricRoom.depthM },
                { x: 0, y: metricRoom.depthM },
              ],
            },
          },
        },
        furniture: [],
        candidateObjects: sceneCandidateObjects,
        placedObjects: scenePlacedObjects,
        confirmedObjects: sceneConfirmedObjects,
        structuralFixtures: sceneStructuralFixtures,
        ...(source?.sourceImage ? { sourceImage: source.sourceImage } : {}),
        ...(source?.captureSession ? { captureSession: source.captureSession } : {}),
        ...(opencvResult ? { opencvResult } : {}),
        ...(sceneUnderstandingResult ? { sceneUnderstandingResult } : {}),
      },
    },
  }
}

export function isEditorBridgeMessage(value: unknown): value is EditorBridgeMessage {
  if (typeof value !== 'object' || value === null) {
    return false
  }

  const candidate = value as Record<string, unknown>
  return (
    typeof candidate.type === 'string' &&
    typeof candidate.version === 'number' &&
    typeof candidate.payload === 'object' &&
    candidate.payload !== null &&
    (candidate.requestId === undefined || typeof candidate.requestId === 'string')
  )
}
