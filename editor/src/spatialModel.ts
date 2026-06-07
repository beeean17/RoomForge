import type { BridgePayload } from './bridge'

export type ViewMode = '2d' | '3d'

export type MeterPoint = {
  x: number
  y: number
}

export type MeterPoint3d = {
  x: number
  y: number
  z: number
}

export type ImageBoundingBox = {
  x: number
  y: number
  width: number
  height: number
}

export type CandidateSourceEvidence = {
  candidateId: string
  sourceImageId?: string
  captureImageId?: string
  sourceImageRole?: string
  confidenceScore?: number
  boundingBox?: ImageBoundingBox
}

export type FurnitureCategory =
  | 'bed'
  | 'desk'
  | 'chair'
  | 'wardrobe'
  | 'sofa'
  | 'table'
  | 'shelf'
  | 'cabinet'
  | 'custom'

export type FurnitureObject = {
  objectId: string
  category: FurnitureCategory
  candidateId?: string
  source?: 'catalog' | 'cv_candidate'
  label: string
  size: {
    widthMeters: number
    depthMeters: number
    heightMeters: number
  }
  position: {
    x: number
    y: number
  }
  rotationDegrees: number
  color: string
  locked?: boolean
}

export type SpatialSelection = {
  objectId: string
  objectType: 'room' | 'furniture' | 'fixture'
} | null

export type CandidateSceneObject = {
  candidateId: string
  objectType: string
  category: string
  label?: string
  sourceImageId?: string
  captureImageId?: string
  sourceImageRole?: string
  sourceEvidence?: CandidateSourceEvidence[]
  coordinateSpace: string
  boundingBox?: ImageBoundingBox
  confidenceScore?: number
  reviewState: string
  reviewLabel?: string
  suggestedAssetId?: string
  suggestedPosition?: MeterPoint3d
  suggestedWallId?: string
  suggestedSize?: MeterPoint3d
  suggestedRotationDegrees?: number
  notes?: string
}

export type PlacedSceneObject = {
  objectId: string
  candidateId?: string
  objectType: string
  category: string
  assetId?: string
  label?: string
  position?: MeterPoint3d
  size?: MeterPoint3d
  rotationDegrees: number
  confidenceScore?: number
  locked: boolean
}

export type ConfirmedSceneObject = PlacedSceneObject & {
  confirmedByUid?: string
  confirmedAt?: string
}

export type StructuralFixtureObject = {
  fixtureId: string
  candidateId?: string
  category: string
  wallId: string
  label?: string
  position?: MeterPoint3d
  size?: MeterPoint3d
  rotationDegrees: number
  confidenceScore?: number
  locked: boolean
}

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
  furniture: FurnitureObject[]
  candidateObjects: CandidateSceneObject[]
  placedObjects: PlacedSceneObject[]
  confirmedObjects: ConfirmedSceneObject[]
  structuralFixtures: StructuralFixtureObject[]
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
    furniture: [],
    candidateObjects: [],
    placedObjects: [],
    confirmedObjects: [],
    structuralFixtures: [],
  }
}

export function spatialModelFromBridgePayload(payload: BridgePayload): SpatialModel {
  const fallback = defaultSpatialModel()
  const scene = recordValue(payload.scene)
  const layers = sceneObjectLayersFromPayload(payload, scene)
  const room = recordValue(scene.room ?? payload.room)
  const floorPlan = recordValue(room.floorPlan ?? payload.floorPlan)
  const metricGeometry = recordValue(floorPlan.metricGeometry ?? payload.metricGeometry)
  const scale = recordValue(scene.scale ?? payload.scale)
  const rawFurniture = Array.isArray(scene.furniture ?? payload.furniture)
    ? ((scene.furniture ?? payload.furniture) as unknown[])
    : []
  const rawPoints = Array.isArray(metricGeometry.points) ? metricGeometry.points : undefined
  const points = rawPoints
    ?.map((point) => recordValue(point))
    .map((point) => ({
      x: numberValue(point.x, 0),
      y: numberValue(point.y, 0),
    }))
    .filter((point) => Number.isFinite(point.x) && Number.isFinite(point.y))

  if (metricGeometry.coordinateSpace !== 'meters' || !points || points.length < 3) {
    return { ...fallback, ...layers }
  }

  return {
    ...fallback,
    sceneId: stringValue(scene.sceneId ?? payload.sceneId, fallback.sceneId),
    viewMode: viewModeValue(scene.viewMode ?? payload.viewMode, fallback.viewMode),
    hasUnsavedChanges: booleanValue(
      scene.hasUnsavedChanges ?? payload.hasUnsavedChanges,
      fallback.hasUnsavedChanges,
    ),
    scale: {
      metersPerSceneUnit: numberValue(
        scale.metersPerSceneUnit,
        fallback.scale.metersPerSceneUnit,
      ),
    },
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
    furniture: rawFurniture.map(furnitureValue).filter((item) => item !== null),
    ...layers,
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
  return `${model.viewMode.toUpperCase()} | ${bounds.widthMeters.toFixed(
    2,
  )} m x ${bounds.depthMeters.toFixed(2)} m | ${model.furniture.length} furniture | selected ${selected} | ${state}`
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
  const objectType =
    record.objectType === 'furniture'
      ? 'furniture'
      : record.objectType === 'fixture'
        ? 'fixture'
        : 'room'
  return { objectId, objectType }
}

function sceneObjectLayersFromPayload(
  payload: BridgePayload,
  scene: Record<string, unknown>,
): {
  candidateObjects: CandidateSceneObject[]
  placedObjects: PlacedSceneObject[]
  confirmedObjects: ConfirmedSceneObject[]
  structuralFixtures: StructuralFixtureObject[]
} {
  const sceneUnderstanding = recordValue(payload.sceneUnderstandingResult)
  const candidateObjects = firstListValue(
    scene.candidateObjects,
    payload.candidateObjects,
    sceneUnderstanding.candidateObjects,
  )
    .map(candidateSceneObjectValue)
    .filter((item) => item !== null)
  const placedObjects = firstListValue(
    scene.placedObjects,
    payload.placedObjects,
    sceneUnderstanding.placedObjects,
  )
    .map(placedSceneObjectValue)
    .filter((item) => item !== null)
  const confirmedObjects = firstListValue(
    scene.confirmedObjects,
    payload.confirmedObjects,
    sceneUnderstanding.confirmedObjects,
  )
    .map(confirmedSceneObjectValue)
    .filter((item) => item !== null)
  const structuralFixtures = firstListValue(
    scene.structuralFixtures,
    payload.structuralFixtures,
    sceneUnderstanding.structuralFixtures,
  )
    .map(structuralFixtureValue)
    .filter((item) => item !== null)

  return {
    candidateObjects,
    placedObjects,
    confirmedObjects,
    structuralFixtures,
  }
}

function candidateSceneObjectValue(value: unknown): CandidateSceneObject | null {
  const record = recordValue(value)
  const candidateId = stringValue(record.candidateId, '')
  if (!candidateId) {
    return null
  }
  return {
    candidateId,
    objectType: stringValue(record.objectType, 'unknown'),
    category: stringValue(record.category, 'unknown'),
    label: optionalStringValue(record.label),
    sourceImageId: optionalStringValue(record.sourceImageId),
    captureImageId: optionalStringValue(record.captureImageId),
    sourceImageRole: optionalStringValue(record.sourceImageRole),
    sourceEvidence: sourceEvidenceListValue(record.sourceEvidence),
    coordinateSpace: stringValue(record.coordinateSpace, 'image_pixels'),
    boundingBox: boundingBoxValue(record.boundingBox),
    confidenceScore: optionalNumberValue(record.confidenceScore),
    reviewState: stringValue(record.reviewState, 'review_required'),
    reviewLabel: optionalStringValue(record.reviewLabel),
    suggestedAssetId: optionalStringValue(record.suggestedAssetId),
    suggestedPosition: point3dValue(record.suggestedPosition),
    suggestedWallId: optionalStringValue(record.suggestedWallId),
    suggestedSize: point3dValue(record.suggestedSize),
    suggestedRotationDegrees: optionalNumberValue(record.suggestedRotationDegrees),
    notes: optionalStringValue(record.notes),
  }
}

function sourceEvidenceListValue(value: unknown): CandidateSourceEvidence[] | undefined {
  if (!Array.isArray(value)) {
    return undefined
  }
  const evidence = value
    .map(sourceEvidenceValue)
    .filter((item) => item !== null)
  return evidence.length > 0 ? evidence : undefined
}

function sourceEvidenceValue(value: unknown): CandidateSourceEvidence | null {
  const record = recordValue(value)
  const candidateId = stringValue(record.candidateId, '')
  if (!candidateId) {
    return null
  }
  return {
    candidateId,
    sourceImageId: optionalStringValue(record.sourceImageId),
    captureImageId: optionalStringValue(record.captureImageId),
    sourceImageRole: optionalStringValue(record.sourceImageRole),
    confidenceScore: optionalNumberValue(record.confidenceScore),
    boundingBox: boundingBoxValue(record.boundingBox),
  }
}

function placedSceneObjectValue(value: unknown): PlacedSceneObject | null {
  const record = recordValue(value)
  const objectId = stringValue(record.objectId, '')
  if (!objectId) {
    return null
  }
  return {
    objectId,
    candidateId: optionalStringValue(record.candidateId),
    objectType: stringValue(record.objectType, 'furniture'),
    category: stringValue(record.category, 'custom'),
    assetId: optionalStringValue(record.assetId),
    label: optionalStringValue(record.label),
    position: point3dValue(record.position),
    size: point3dValue(record.size),
    rotationDegrees: numberValue(record.rotationDegrees, 0),
    confidenceScore: optionalNumberValue(record.confidenceScore),
    locked: booleanValue(record.locked, false),
  }
}

function confirmedSceneObjectValue(value: unknown): ConfirmedSceneObject | null {
  const placed = placedSceneObjectValue(value)
  if (!placed) {
    return null
  }
  const record = recordValue(value)
  return {
    ...placed,
    confirmedByUid: optionalStringValue(record.confirmedByUid),
    confirmedAt: optionalStringValue(record.confirmedAt),
  }
}

function structuralFixtureValue(value: unknown): StructuralFixtureObject | null {
  const record = recordValue(value)
  const fixtureId = stringValue(record.fixtureId, '')
  if (!fixtureId) {
    return null
  }
  return {
    fixtureId,
    candidateId: optionalStringValue(record.candidateId),
    category: stringValue(record.category, 'fixture'),
    wallId: stringValue(record.wallId, 'room-shell'),
    label: optionalStringValue(record.label),
    position: point3dValue(record.position),
    size: point3dValue(record.size),
    rotationDegrees: numberValue(record.rotationDegrees, 0),
    confidenceScore: optionalNumberValue(record.confidenceScore),
    locked: booleanValue(record.locked, true),
  }
}

function furnitureValue(value: unknown): FurnitureObject | null {
  const record = recordValue(value)
  const objectId = record.objectId
  const category = record.category
  if (typeof objectId !== 'string' || !isFurnitureCategory(category)) {
    return null
  }
  const size = recordValue(record.size)
  const position = recordValue(record.position)
  return {
    objectId,
    category,
    label: stringValue(record.label, categoryLabel(category)),
    size: {
      widthMeters: numberValue(size.widthMeters, 0.6),
      depthMeters: numberValue(size.depthMeters, 0.6),
      heightMeters: numberValue(size.heightMeters, 0.8),
    },
    position: {
      x: numberValue(position.x, 1),
      y: numberValue(position.y, 1),
    },
    rotationDegrees: numberValue(record.rotationDegrees, 0),
    color: stringValue(record.color, '#64748b'),
    locked: booleanValue(record.locked, false),
    candidateId: optionalStringValue(record.candidateId),
    source: furnitureSourceValue(record.source),
  }
}

function firstListValue(...values: unknown[]): unknown[] {
  for (const value of values) {
    if (Array.isArray(value)) {
      return value
    }
  }
  return []
}

function optionalStringValue(value: unknown): string | undefined {
  return typeof value === 'string' && value.length > 0 ? value : undefined
}

function optionalNumberValue(value: unknown): number | undefined {
  return typeof value === 'number' && Number.isFinite(value) ? value : undefined
}

function point3dValue(value: unknown): MeterPoint3d | undefined {
  const point = recordValue(value)
  const x = optionalNumberValue(point.x)
  const y = optionalNumberValue(point.y)
  const z = optionalNumberValue(point.z)
  if (x === undefined || y === undefined || z === undefined) {
    return undefined
  }
  return { x, y, z }
}

function boundingBoxValue(value: unknown): ImageBoundingBox | undefined {
  const box = recordValue(value)
  const x = optionalNumberValue(box.x)
  const y = optionalNumberValue(box.y)
  const width = optionalNumberValue(box.width)
  const height = optionalNumberValue(box.height)
  if (x === undefined || y === undefined || width === undefined || height === undefined) {
    return undefined
  }
  return { x, y, width, height }
}

function isFurnitureCategory(value: unknown): value is FurnitureCategory {
  return (
    value === 'bed' ||
    value === 'desk' ||
    value === 'chair' ||
    value === 'wardrobe' ||
    value === 'sofa' ||
    value === 'table' ||
    value === 'shelf' ||
    value === 'cabinet' ||
    value === 'custom'
  )
}

function furnitureSourceValue(value: unknown): FurnitureObject['source'] | undefined {
  return value === 'catalog' || value === 'cv_candidate' ? value : undefined
}

function categoryLabel(category: FurnitureCategory): string {
  const labels: Record<FurnitureCategory, string> = {
    bed: 'Bed',
    desk: 'Desk',
    chair: 'Chair',
    wardrobe: 'Wardrobe',
    sofa: 'Sofa',
    table: 'Table',
    shelf: 'Shelf',
    cabinet: 'Cabinet',
    custom: 'Custom',
  }
  return labels[category]
}
