import type { BridgePayload } from './bridge'

export type CaptureImageReference = {
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
}

export type CaptureSessionForSceneUnderstanding = {
  captureSessionId: string
  projectId?: string
  roomDimensionsId?: string
  captureMethod?: string
  depthEnabled: boolean
  availableRoles: string[]
  images: CaptureImageReference[]
}

export function captureSessionFromBridgePayload(
  payload: BridgePayload,
): CaptureSessionForSceneUnderstanding | null {
  const direct = recordValue(payload.captureSession)
  const scene = recordValue(payload.scene)
  const fromScene = recordValue(scene.captureSession)
  const session = Object.keys(direct).length > 0 ? direct : fromScene
  const captureSessionId = stringValue(session.captureSessionId)
  const images = listValue(session.images).map(captureImageValue).filter((image) => image !== null)
  const roles = listValue(session.availableRoles)
    .map((role) => stringValue(role))
    .filter((role) => role.length > 0)
  const availableRoles = uniqueStrings(roles.length > 0 ? roles : images.map((image) => image.role))

  if (!captureSessionId && images.length === 0 && availableRoles.length === 0) {
    return null
  }

  return {
    captureSessionId,
    projectId: optionalStringValue(session.projectId),
    roomDimensionsId: optionalStringValue(session.roomDimensionsId),
    captureMethod: optionalStringValue(session.captureMethod),
    depthEnabled: booleanValue(session.depthEnabled, false),
    availableRoles,
    images,
  }
}

export function captureRoleSummary(session: CaptureSessionForSceneUnderstanding | null): string {
  if (!session || session.availableRoles.length === 0) {
    return 'No capture session images'
  }
  return `${session.availableRoles.length} capture roles: ${session.availableRoles.join(', ')}`
}

function captureImageValue(value: unknown): CaptureImageReference | null {
  const record = recordValue(value)
  const captureImageId = stringValue(record.captureImageId)
  const captureSessionId = stringValue(record.captureSessionId)
  const sourceImageId = stringValue(record.sourceImageId)
  const role = stringValue(record.role)

  if (!captureImageId || !captureSessionId || !sourceImageId || !role) {
    return null
  }

  return {
    captureImageId,
    captureSessionId,
    sourceImageId,
    role,
    storagePath: optionalStringValue(record.storagePath),
    contentType: optionalStringValue(record.contentType),
    widthPx: positiveNumberValue(record.widthPx),
    heightPx: positiveNumberValue(record.heightPx),
    captureOrder: nonNegativeNumberValue(record.captureOrder),
    guidanceState: optionalStringValue(record.guidanceState),
  }
}

function recordValue(value: unknown): Record<string, unknown> {
  return typeof value === 'object' && value !== null ? (value as Record<string, unknown>) : {}
}

function listValue(value: unknown): unknown[] {
  return Array.isArray(value) ? value : []
}

function stringValue(value: unknown): string {
  return typeof value === 'string' ? value : ''
}

function optionalStringValue(value: unknown): string | undefined {
  const parsed = stringValue(value)
  return parsed.length > 0 ? parsed : undefined
}

function booleanValue(value: unknown, fallback: boolean): boolean {
  return typeof value === 'boolean' ? value : fallback
}

function positiveNumberValue(value: unknown): number | undefined {
  return typeof value === 'number' && Number.isFinite(value) && value > 0 ? value : undefined
}

function nonNegativeNumberValue(value: unknown): number | undefined {
  return typeof value === 'number' && Number.isFinite(value) && value >= 0 ? value : undefined
}

function uniqueStrings(values: string[]): string[] {
  return [...new Set(values.filter((value) => value.length > 0))]
}
