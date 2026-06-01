import type { FurnitureCategory, FurnitureObject, SpatialModel } from './spatialModel'

export type FurnitureEditAction =
  | 'move-up'
  | 'move-down'
  | 'move-left'
  | 'move-right'
  | 'rotate-left'
  | 'rotate-right'
  | 'narrower'
  | 'wider'
  | 'shallower'
  | 'deeper'
  | 'toggle-lock'
  | 'delete'

export type FurnitureEditResult = {
  model: SpatialModel
  selected: FurnitureObject | null
  changed: boolean
  deleted: boolean
  blockedByLock: boolean
}

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
  const baseByCategory: Record<
    FurnitureCategory,
    {
      label: string
      size: { widthMeters: number; depthMeters: number; heightMeters: number }
      color: string
    }
  > = {
    bed: {
      label: 'Bed',
      size: { widthMeters: 1.5, depthMeters: 2, heightMeters: 0.55 },
      color: '#6f7f8f',
    },
    desk: {
      label: 'Desk',
      size: { widthMeters: 1.2, depthMeters: 0.65, heightMeters: 0.75 },
      color: '#7f6f8f',
    },
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
    wardrobe: {
      label: 'Wardrobe',
      size: { widthMeters: 1, depthMeters: 0.6, heightMeters: 2 },
      color: '#64748b',
    },
    shelf: {
      label: 'Shelf',
      size: { widthMeters: 0.9, depthMeters: 0.35, heightMeters: 1.6 },
      color: '#5f7f7a',
    },
    cabinet: {
      label: 'Cabinet',
      size: { widthMeters: 0.9, depthMeters: 0.45, heightMeters: 0.9 },
      color: '#7a6f61',
    },
    custom: {
      label: 'Custom',
      size: { widthMeters: 0.8, depthMeters: 0.8, heightMeters: 0.8 },
      color: '#64748b',
    },
  }
  const base = baseByCategory[category]

  return {
    objectId: id,
    category,
    source: 'catalog',
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

export function editFurnitureObject(
  item: FurnitureObject,
  action: FurnitureEditAction,
): FurnitureObject {
  const moveStep = 0.1
  const sizeStep = 0.1
  if (action === 'move-up') {
    return { ...item, position: { ...item.position, y: Number((item.position.y - moveStep).toFixed(2)) } }
  }
  if (action === 'move-down') {
    return { ...item, position: { ...item.position, y: Number((item.position.y + moveStep).toFixed(2)) } }
  }
  if (action === 'move-left') {
    return { ...item, position: { ...item.position, x: Number((item.position.x - moveStep).toFixed(2)) } }
  }
  if (action === 'move-right') {
    return { ...item, position: { ...item.position, x: Number((item.position.x + moveStep).toFixed(2)) } }
  }
  if (action === 'rotate-left' || action === 'rotate-right') {
    const delta = action === 'rotate-left' ? -15 : 15
    return { ...item, rotationDegrees: (item.rotationDegrees + delta + 360) % 360 }
  }
  if (action === 'narrower' || action === 'wider') {
    const delta = action === 'narrower' ? -sizeStep : sizeStep
    return {
      ...item,
      size: {
        ...item.size,
        widthMeters: Number(Math.max(0.2, item.size.widthMeters + delta).toFixed(2)),
      },
    }
  }
  if (action === 'shallower' || action === 'deeper') {
    const delta = action === 'shallower' ? -sizeStep : sizeStep
    return {
      ...item,
      size: {
        ...item.size,
        depthMeters: Number(Math.max(0.2, item.size.depthMeters + delta).toFixed(2)),
      },
    }
  }
  if (action === 'toggle-lock') {
    return { ...item, locked: !item.locked }
  }
  return item
}

export function editSelectedFurnitureInModel(
  model: SpatialModel,
  action: FurnitureEditAction,
): FurnitureEditResult {
  const selected = selectedFurniture(model)
  if (!selected) {
    return { model, selected: null, changed: false, deleted: false, blockedByLock: false }
  }

  if (action === 'delete') {
    return {
      model: {
        ...model,
        hasUnsavedChanges: true,
        selected: { objectId: model.room.objectId, objectType: 'room' },
        furniture: model.furniture.filter((item) => item.objectId !== selected.objectId),
      },
      selected,
      changed: true,
      deleted: true,
      blockedByLock: false,
    }
  }

  if (selected.locked && action !== 'toggle-lock') {
    return { model, selected, changed: false, deleted: false, blockedByLock: true }
  }

  return {
    model: {
      ...model,
      hasUnsavedChanges: true,
      furniture: model.furniture.map((item) =>
        item.objectId === selected.objectId ? editFurnitureObject(item, action) : item,
      ),
    },
    selected,
    changed: true,
    deleted: false,
    blockedByLock: false,
  }
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
