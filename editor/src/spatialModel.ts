import type { BridgePayload } from './bridge'

export type ViewMode = '2d' | '3d'

export type MeterPoint = {
  x: number
  y: number
}

export type SpatialSelection = {
  objectId: string
  objectType: 'room'
} | null

export type SpatialModel = {
  version: 1
  sceneId: string
  coordinateSpace: 'meters'
  unit: 'meters'
  viewMode: ViewMode
  selected: SpatialSelection
  hasUnsavedChanges: boolean
  scale: {
    metersPerSceneUnit: number
  }
  room: {
    objectId: string
    label: string
    heightMeters: number
    floorPlan: {
      floorPlanId: string
      metricGeometry: {
        coordinateSpace: 'meters'
        points: MeterPoint[]
      }
    }
  }
}

export function defaultSpatialModel(): SpatialModel {
  return {
    version: 1,
    sceneId: 'demo-floor-plan-scene',
    coordinateSpace: 'meters',
    unit: 'meters',
    viewMode: '2d',
    selected: { objectId: 'room-shell', objectType: 'room' },
    hasUnsavedChanges: false,
    scale: { metersPerSceneUnit: 1 },
    room: {
      objectId: 'room-shell',
      label: 'Room shell',
      heightMeters: 2.7,
      floorPlan: {
        floorPlanId: 'demo-floor-plan',
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
  }
}

export function spatialModelFromBridgePayload(payload: BridgePayload): SpatialModel {
  const fallback = defaultSpatialModel()
  const scene = recordValue(payload.scene)
  const room = recordValue(scene.room ?? payload.room)
  const floorPlan = recordValue(room.floorPlan ?? payload.floorPlan)
  const metricGeometry = recordValue(floorPlan.metricGeometry ?? payload.metricGeometry)
  const rawPoints = Array.isArray(metricGeometry.points) ? metricGeometry.points : undefined
  const points = rawPoints
    ?.map((point) => recordValue(point))
    .map((point) => ({
      x: numberValue(point.x, 0),
      y: numberValue(point.y, 0),
    }))
    .filter((point) => Number.isFinite(point.x) && Number.isFinite(point.y))

  if (metricGeometry.coordinateSpace !== 'meters' || !points || points.length < 3) {
    return fallback
  }

  return {
    ...fallback,
    sceneId: stringValue(scene.sceneId ?? payload.sceneId, fallback.sceneId),
    viewMode: viewModeValue(scene.viewMode ?? payload.viewMode, fallback.viewMode),
    hasUnsavedChanges: booleanValue(
      scene.hasUnsavedChanges ?? payload.hasUnsavedChanges,
      fallback.hasUnsavedChanges,
    ),
    selected: selectionValue(scene.selected ?? payload.selected),
    room: {
      ...fallback.room,
      objectId: stringValue(room.objectId, fallback.room.objectId),
      label: stringValue(room.label, fallback.room.label),
      heightMeters: numberValue(room.heightMeters, fallback.room.heightMeters),
      floorPlan: {
        floorPlanId: stringValue(floorPlan.floorPlanId, fallback.room.floorPlan.floorPlanId),
        metricGeometry: {
          coordinateSpace: 'meters',
          points,
        },
      },
    },
  }
}

export function roomBounds(model: SpatialModel): {
  widthMeters: number
  depthMeters: number
  centerX: number
  centerY: number
} {
  const points = model.room.floorPlan.metricGeometry.points
  const xs = points.map((point) => point.x)
  const ys = points.map((point) => point.y)
  const minX = Math.min(...xs)
  const maxX = Math.max(...xs)
  const minY = Math.min(...ys)
  const maxY = Math.max(...ys)

  return {
    widthMeters: maxX - minX,
    depthMeters: maxY - minY,
    centerX: minX + (maxX - minX) / 2,
    centerY: minY + (maxY - minY) / 2,
  }
}

export function spatialSummary(model: SpatialModel): string {
  const bounds = roomBounds(model)
  const selected = model.selected?.objectId ?? 'none'
  const state = model.hasUnsavedChanges ? 'Unsaved changes' : 'Saved'
  return `${model.viewMode.toUpperCase()} | ${bounds.widthMeters.toFixed(2)} m x ${bounds.depthMeters.toFixed(2)} m | selected ${selected} | ${state}`
}

function recordValue(value: unknown): Record<string, unknown> {
  return typeof value === 'object' && value !== null ? (value as Record<string, unknown>) : {}
}

function stringValue(value: unknown, fallback: string): string {
  return typeof value === 'string' && value.length > 0 ? value : fallback
}

function numberValue(value: unknown, fallback: number): number {
  return typeof value === 'number' && Number.isFinite(value) ? value : fallback
}

function booleanValue(value: unknown, fallback: boolean): boolean {
  return typeof value === 'boolean' ? value : fallback
}

function viewModeValue(value: unknown, fallback: ViewMode): ViewMode {
  return value === '2d' || value === '3d' ? value : fallback
}

function selectionValue(value: unknown): SpatialSelection {
  const record = recordValue(value)
  const objectId = record.objectId
  if (typeof objectId !== 'string' || objectId.length === 0) {
    return null
  }
  return { objectId, objectType: 'room' }
}
