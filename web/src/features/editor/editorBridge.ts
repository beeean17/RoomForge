import type { WorkspaceProject } from '../projects/projectData'

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
}: InitializeMessageOptions): EditorBridgeMessage {
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
      scene: {
        sceneId: `${project.id}-editor-scene`,
        coordinateSpace: 'meters',
        unit: 'meters',
        viewMode: '2d',
        room: {
          objectId: 'room-shell',
          label: project.name,
          heightMeters: 2.7,
          floorPlan: {
            floorPlanId: `${project.id}-floor-plan`,
            metricGeometry: {
              coordinateSpace: 'meters',
              points: [
                { x: 0, y: 0 },
                { x: 4.2, y: 0 },
                { x: 4.2, y: 3.6 },
                { x: 0, y: 3.6 },
              ],
            },
          },
        },
        furniture: [],
        candidateObjects: [],
        placedObjects: [],
        confirmedObjects: [],
        structuralFixtures: [],
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
