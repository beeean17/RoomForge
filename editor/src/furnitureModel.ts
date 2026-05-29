import type { FurnitureCategory, FurnitureObject, SpatialModel } from './spatialModel'

export type FurnitureDefaultsOptions = {
  category: FurnitureCategory
  id: string
  model: SpatialModel
}

function furnitureRoomBounds(model: SpatialModel): {
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

export function furnitureDefaults({
  category,
  id,
  model,
}: FurnitureDefaultsOptions): FurnitureObject {
  const bounds = furnitureRoomBounds(model)
  const base = {
    chair: {
      label: 'Chair',
      size: { widthMeters: 0.55, depthMeters: 0.55, heightMeters: 0.85 },
      color: '#64748b',
    },
    table: {
      label: 'Table',
      size: { widthMeters: 1.2, depthMeters: 0.75, heightMeters: 0.74 },
      color: '#7f8f6f',
    },
    sofa: {
      label: 'Sofa',
      size: { widthMeters: 1.8, depthMeters: 0.85, heightMeters: 0.82 },
      color: '#8b6f61',
    },
  }[category]

  return {
    objectId: id,
    category,
    label: base.label,
    size: base.size,
    position: {
      x: Number((bounds.centerX + bounds.widthMeters * 0.18).toFixed(2)),
      y: Number((bounds.centerY + bounds.depthMeters * 0.18).toFixed(2)),
    },
    rotationDegrees: 0,
    color: base.color,
    locked: false,
  }
}

export function addFurnitureToModel(
  model: SpatialModel,
  item: FurnitureObject,
): SpatialModel {
  return {
    ...model,
    hasUnsavedChanges: true,
    selected: { objectId: item.objectId, objectType: 'furniture' },
    furniture: [...model.furniture, item],
  }
}

export function selectFurnitureInModel(
  model: SpatialModel,
  objectId: string,
): SpatialModel {
  const item = model.furniture.find((candidate) => candidate.objectId === objectId)
  if (!item) {
    return model
  }
  return {
    ...model,
    selected: { objectId: item.objectId, objectType: 'furniture' },
  }
}

export function selectedFurniture(model: SpatialModel): FurnitureObject | null {
  if (model.selected?.objectType !== 'furniture') {
    return null
  }
  return model.furniture.find((item) => item.objectId === model.selected?.objectId) ?? null
}

export function selectedFurnitureSummary(model: SpatialModel): string {
  const item = selectedFurniture(model)
  if (!item) {
    return 'No furniture selected'
  }
  const locked = item.locked ? '; locked' : ''
  return `${item.label}; ${item.size.widthMeters.toFixed(2)} m x ${item.size.depthMeters.toFixed(
    2,
  )} m x ${item.size.heightMeters.toFixed(2)} m; position ${item.position.x.toFixed(
    2,
  )} m, ${item.position.y.toFixed(2)} m; rotation ${item.rotationDegrees.toFixed(0)} deg${locked}`
}

export function selectionVisualTokens({
  selected,
}: {
  selected: boolean
}): {
  outline: boolean
  scale: number
  marker: string
} {
  return selected
    ? { outline: true, scale: 1.05, marker: 'edge-outline' }
    : { outline: false, scale: 1, marker: 'none' }
}
