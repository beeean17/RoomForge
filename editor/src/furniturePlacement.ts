import type { FurnitureObject } from './spatialModel'

export type FurniturePlacementBounds = {
  widthMeters: number
  depthMeters: number
}

export type FurniturePlacementItem = Pick<FurnitureObject, 'size' | 'rotationDegrees'>

const defaultGridStepMeters = 0.05
const defaultWallSnapThresholdMeters = 0.12

export function snappedPlanNumber(
  value: number,
  options: {
    snapEnabled: boolean
    stepMeters?: number
  },
): number {
  if (!options.snapEnabled) {
    return Number(value.toFixed(2))
  }
  const step = options.stepMeters ?? defaultGridStepMeters
  return Number((Math.round(value / step) * step).toFixed(2))
}

export function furnitureMagneticSnapPosition({
  item,
  position,
  bounds,
  snapEnabled,
  gridStepMeters = defaultGridStepMeters,
  wallSnapThresholdMeters = defaultWallSnapThresholdMeters,
}: {
  item: FurniturePlacementItem
  position: { x: number; y: number }
  bounds: FurniturePlacementBounds
  snapEnabled: boolean
  gridStepMeters?: number
  wallSnapThresholdMeters?: number
}): { x: number; y: number } {
  const snappedPosition = {
    x: snappedPlanNumber(position.x, { snapEnabled, stepMeters: gridStepMeters }),
    y: snappedPlanNumber(position.y, { snapEnabled, stepMeters: gridStepMeters }),
  }

  if (!snapEnabled) {
    return snappedPosition
  }

  const extents = furnitureFootprintExtents(item, snappedPosition)
  let nextX = snappedPosition.x
  let nextY = snappedPosition.y
  const leftDistance = extents.minX
  const rightDistance = bounds.widthMeters - extents.maxX
  const frontDistance = extents.minY
  const backDistance = bounds.depthMeters - extents.maxY

  if (Math.abs(leftDistance) <= wallSnapThresholdMeters) {
    nextX -= leftDistance
  } else if (Math.abs(rightDistance) <= wallSnapThresholdMeters) {
    nextX += rightDistance
  }

  if (Math.abs(frontDistance) <= wallSnapThresholdMeters) {
    nextY -= frontDistance
  } else if (Math.abs(backDistance) <= wallSnapThresholdMeters) {
    nextY += backDistance
  }

  return {
    x: Number(nextX.toFixed(2)),
    y: Number(nextY.toFixed(2)),
  }
}

export function furnitureFootprintExtents(
  item: FurniturePlacementItem,
  position: { x: number; y: number },
): {
  minX: number
  maxX: number
  minY: number
  maxY: number
} {
  const corners = furnitureFootprintCornersAt(item, position)
  return {
    minX: Math.min(...corners.map((corner) => corner.x)),
    maxX: Math.max(...corners.map((corner) => corner.x)),
    minY: Math.min(...corners.map((corner) => corner.y)),
    maxY: Math.max(...corners.map((corner) => corner.y)),
  }
}

export function furnitureFootprintCornersAt(
  item: FurniturePlacementItem,
  position: { x: number; y: number },
): Array<{ x: number; y: number }> {
  const halfWidth = Math.max(item.size.widthMeters, 0) / 2
  const halfDepth = Math.max(item.size.depthMeters, 0) / 2
  const radians = (item.rotationDegrees * Math.PI) / 180
  const cos = Math.cos(radians)
  const sin = Math.sin(radians)

  return [
    { x: -halfWidth, y: -halfDepth },
    { x: halfWidth, y: -halfDepth },
    { x: halfWidth, y: halfDepth },
    { x: -halfWidth, y: halfDepth },
  ].map((corner) => ({
    x: position.x + corner.x * cos - corner.y * sin,
    y: position.y + corner.x * sin + corner.y * cos,
  }))
}

export function signedPlanAngleDeltaDegrees(startAngleDegrees: number, currentAngleDegrees: number): number {
  return ((((currentAngleDegrees - startAngleDegrees) % 360) + 540) % 360) - 180
}

export function snappedRotationDegrees(value: number, snapEnabled: boolean): number {
  const normalized = ((value % 360) + 360) % 360
  const step = snapEnabled ? 5 : 1
  return (Math.round(normalized / step) * step) % 360
}
