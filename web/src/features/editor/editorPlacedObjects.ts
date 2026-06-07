export type PlacedObjectTransformField =
  | 'position-x'
  | 'position-y'
  | 'rotation'
  | 'width'
  | 'depth'
  | 'height'

export type PlacedObjectItem = {
  objectId: string
  category: string
  label: string
  sourceLabel: string
  assetId?: string
  candidateId?: string
  source?: string
  selected: boolean
  locked: boolean
  outsideRoom: boolean
  coordinateSpace: 'meters'
  positionX: number
  positionY: number
  rotationDegrees: number
  widthMeters: number
  depthMeters: number
  heightMeters: number
  canEdit: boolean
  canDelete: boolean
  canToggleLock: boolean
}

export type PlacedObjectState = {
  items: PlacedObjectItem[]
  selectedItem: PlacedObjectItem | null
  counts: {
    total: number
    cvCandidates: number
    catalog: number
    locked: number
    outsideRoom: number
  }
  roomBounds: {
    widthMeters: number
    depthMeters: number
  }
}

type RoomBounds = PlacedObjectState['roomBounds']

export const placedObjectTransformFields: Array<{
  field: PlacedObjectTransformField
  label: string
  unit: string
  min: number
  maxFallback: number
  step: number
}> = [
  { field: 'position-x', label: 'X', unit: 'm', min: 0, maxFallback: 10, step: 0.05 },
  { field: 'position-y', label: 'Y', unit: 'm', min: 0, maxFallback: 10, step: 0.05 },
  { field: 'rotation', label: 'Rotation', unit: 'deg', min: 0, maxFallback: 345, step: 15 },
  { field: 'width', label: 'Width', unit: 'm', min: 0.2, maxFallback: 10, step: 0.05 },
  { field: 'depth', label: 'Depth', unit: 'm', min: 0.2, maxFallback: 10, step: 0.05 },
  { field: 'height', label: 'Height', unit: 'm', min: 0.2, maxFallback: 5, step: 0.05 },
]

export function placedObjectStateFromPayload(payload: Record<string, unknown>): PlacedObjectState | null {
  const source = placedPayloadSource(payload)
  if (!('furniture' in source)) {
    return null
  }

  const selected = recordValue(source.selected)
  const selectedObjectId = stringValue(selected.objectId)
  const selectedType = stringValue(selected.objectType)
  const roomBounds = roomBoundsFromPayload(recordValue(source.room))
  const items = listValue(source.furniture)
    .map((item) =>
      placedObjectItemFromRecord({
        item: recordValue(item),
        selectedObjectId,
        selectedType,
        roomBounds,
      }),
    )
    .filter((item): item is PlacedObjectItem => item !== null)
  const selectedItem = items.find((item) => item.selected) ?? null

  return {
    items,
    selectedItem,
    counts: {
      total: items.length,
      cvCandidates: items.filter(isCvCandidatePlacedObject).length,
      catalog: items.filter((item) => !isCvCandidatePlacedObject(item)).length,
      locked: items.filter((item) => item.locked).length,
      outsideRoom: items.filter((item) => item.outsideRoom).length,
    },
    roomBounds,
  }
}

export function transformValueForItem(
  item: PlacedObjectItem,
  field: PlacedObjectTransformField,
): number {
  if (field === 'position-x') return item.positionX
  if (field === 'position-y') return item.positionY
  if (field === 'rotation') return item.rotationDegrees
  if (field === 'width') return item.widthMeters
  if (field === 'depth') return item.depthMeters
  return item.heightMeters
}

export function maxValueForField(
  field: PlacedObjectTransformField,
  roomBounds: RoomBounds,
): number {
  if (field === 'position-x' || field === 'width') {
    return Math.max(roomBounds.widthMeters, 0.2)
  }
  if (field === 'position-y' || field === 'depth') {
    return Math.max(roomBounds.depthMeters, 0.2)
  }
  if (field === 'height') {
    return 3
  }
  return 345
}

function placedPayloadSource(payload: Record<string, unknown>): Record<string, unknown> {
  const scene = recordValue(payload.scene)
  if ('furniture' in scene) {
    return scene
  }
  const spatialModel = recordValue(payload.spatialModel)
  if ('furniture' in spatialModel) {
    return spatialModel
  }
  return payload
}

function placedObjectItemFromRecord({
  item,
  selectedObjectId,
  selectedType,
  roomBounds,
}: {
  item: Record<string, unknown>
  selectedObjectId?: string
  selectedType?: string
  roomBounds: RoomBounds
}): PlacedObjectItem | null {
  const objectId = stringValue(item.objectId)
  if (!objectId) {
    return null
  }

  const size = recordValue(item.size)
  const position = recordValue(item.position)
  const assetId = stringValue(item.assetId)
  const candidateId = stringValue(item.candidateId)
  const source = stringValue(item.source)
  const widthMeters = numberValue(size.widthMeters, 0.6)
  const depthMeters = numberValue(size.depthMeters, 0.6)
  const positionX = numberValue(position.x, 0)
  const positionY = numberValue(position.y, 0)
  const locked = booleanValue(item.locked, false)

  return {
    objectId,
    category: stringValue(item.category) ?? 'custom',
    label: stringValue(item.label) ?? stringValue(item.category) ?? 'Furniture',
    sourceLabel: sourceLabelForPlacedObject({ source, candidateId, assetId }),
    assetId,
    candidateId,
    source,
    selected: selectedType === 'furniture' && selectedObjectId === objectId,
    locked,
    outsideRoom: objectOutsideRoom({
      positionX,
      positionY,
      widthMeters,
      depthMeters,
      roomBounds,
    }),
    coordinateSpace: 'meters',
    positionX,
    positionY,
    rotationDegrees: numberValue(item.rotationDegrees, 0),
    widthMeters,
    depthMeters,
    heightMeters: numberValue(size.heightMeters, 0.8),
    canEdit: !locked,
    canDelete: true,
    canToggleLock: true,
  }
}

function isCvCandidatePlacedObject(item: PlacedObjectItem): boolean {
  return item.source === 'cv_candidate' || Boolean(item.candidateId)
}

function sourceLabelForPlacedObject({
  source,
  candidateId,
  assetId,
}: {
  source?: string
  candidateId?: string
  assetId?: string
}): string {
  const baseLabel = source === 'cv_candidate' || candidateId ? 'CV candidate' : 'Catalog'
  return assetId ? `${baseLabel} / ${assetId}` : baseLabel
}

function objectOutsideRoom({
  positionX,
  positionY,
  widthMeters,
  depthMeters,
  roomBounds,
}: {
  positionX: number
  positionY: number
  widthMeters: number
  depthMeters: number
  roomBounds: RoomBounds
}): boolean {
  const halfWidth = widthMeters / 2
  const halfDepth = depthMeters / 2
  return (
    positionX - halfWidth < 0 ||
    positionY - halfDepth < 0 ||
    positionX + halfWidth > roomBounds.widthMeters ||
    positionY + halfDepth > roomBounds.depthMeters
  )
}

function roomBoundsFromPayload(room: Record<string, unknown>): RoomBounds {
  const floorPlan = recordValue(room.floorPlan)
  const metricGeometry = recordValue(floorPlan.metricGeometry)
  const points = listValue(metricGeometry.points)
    .map((point) => recordValue(point))
    .map((point) => ({
      x: numberValue(point.x, 0),
      y: numberValue(point.y, 0),
    }))
  if (points.length < 3) {
    return { widthMeters: 4.2, depthMeters: 3.6 }
  }
  const xs = points.map((point) => point.x)
  const ys = points.map((point) => point.y)
  return {
    widthMeters: Math.max(...xs) - Math.min(...xs),
    depthMeters: Math.max(...ys) - Math.min(...ys),
  }
}

function recordValue(value: unknown): Record<string, unknown> {
  return typeof value === 'object' && value !== null ? (value as Record<string, unknown>) : {}
}

function listValue(value: unknown): unknown[] {
  return Array.isArray(value) ? value : []
}

function stringValue(value: unknown): string | undefined {
  return typeof value === 'string' && value.length > 0 ? value : undefined
}

function numberValue(value: unknown, fallback: number): number {
  return typeof value === 'number' && Number.isFinite(value) ? value : fallback
}

function booleanValue(value: unknown, fallback: boolean): boolean {
  return typeof value === 'boolean' ? value : fallback
}
