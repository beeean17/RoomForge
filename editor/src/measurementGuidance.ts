import type { FurnitureObject, SpatialModel } from './spatialModel'

function meters(value: number): string {
  return `${value.toFixed(2)} m`
}

function measurementRoomBounds(model: SpatialModel): {
  widthMeters: number
  depthMeters: number
} {
  const points = model.room.floorPlan.metricGeometry.points
  const xs = points.map((point) => point.x)
  const ys = points.map((point) => point.y)
  return {
    widthMeters: Math.max(...xs) - Math.min(...xs),
    depthMeters: Math.max(...ys) - Math.min(...ys),
  }
}

export function measurementSummaryForModel({
  model,
  selected,
  selectedLabel,
  roomLabel = 'Room',
}: {
  model: SpatialModel
  selected?: FurnitureObject | null
  selectedLabel?: string
  roomLabel?: string
}): string {
  const bounds = measurementRoomBounds(model)
  if (selected) {
    return `${selectedLabel ?? selected.label}: ${meters(selected.size.widthMeters)} x ${meters(
      selected.size.depthMeters,
    )}; room ${meters(bounds.widthMeters)} x ${meters(bounds.depthMeters)}`
  }
  return `${roomLabel} ${meters(bounds.widthMeters)} x ${meters(bounds.depthMeters)} x ${meters(
    model.room.heightMeters,
  )}`
}

export function placementWarningForModel({
  model,
  labelFor = (item: FurnitureObject) => item.label,
}: {
  model: SpatialModel
  labelFor?: (item: FurnitureObject) => string
}): string | null {
  const bounds = measurementRoomBounds(model)
  const outside = model.furniture.find((item) => furnitureOutsideRoom(item, bounds))
  if (!outside) {
    return null
  }
  return `Warning: ${labelFor(outside)} is outside the ${meters(bounds.widthMeters)} x ${meters(
    bounds.depthMeters,
  )} room bounds. Move or resize it inside the room before saving.`
}

export function furnitureOutsideRoom(
  item: FurnitureObject,
  bounds: { widthMeters: number; depthMeters: number },
): boolean {
  const halfWidth = item.size.widthMeters / 2
  const halfDepth = item.size.depthMeters / 2
  return (
    item.position.x - halfWidth < 0 ||
    item.position.y - halfDepth < 0 ||
    item.position.x + halfWidth > bounds.widthMeters ||
    item.position.y + halfDepth > bounds.depthMeters
  )
}
