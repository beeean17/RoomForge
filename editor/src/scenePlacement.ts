import {
  roomBounds,
  type CandidateSceneObject,
  type ImageBoundingBox,
  type MeterPoint3d,
  type SpatialModel,
} from './spatialModel.ts'
import {
  furnitureSizePriorForCategory,
  structuralFixtureSizePriorForCategory,
} from './sizePriors.ts'

export type PlacementImageReference = {
  captureImageId?: string
  sourceImageId?: string
  role?: string
  widthPx?: number
  heightPx?: number
  depthArtifactRefs?: { artifactId: string }[]
  cameraPose?: {
    depthEstimateMeters?: number
    depthConfidence?: number
    sizeScale?: number
  }
}

export type MetricPlacementEstimate = {
  suggestedPosition: MeterPoint3d
  suggestedSize: MeterPoint3d
  suggestedRotationDegrees: number
  suggestedWallId: string
  evidenceSource: 'wall_role' | 'depth_assisted'
  depthConfidence?: number
  reviewRequired: boolean
  reviewReasons: string[]
}

type WallRole = 'front_wall' | 'right_wall' | 'back_wall' | 'left_wall'

type RoomBounds = ReturnType<typeof roomBounds>

const roleToWall: Record<WallRole, { wallId: string; rotationDegrees: number }> = {
  front_wall: { wallId: 'front-wall', rotationDegrees: 0 },
  right_wall: { wallId: 'right-wall', rotationDegrees: 90 },
  back_wall: { wallId: 'back-wall', rotationDegrees: 180 },
  left_wall: { wallId: 'left-wall', rotationDegrees: 270 },
}

const minUsableDepthConfidence = 0.5
const depthReviewConfidence = 0.75

export function estimateMetricPlacementForCandidate({
  candidate,
  model,
  images = [],
}: {
  candidate: CandidateSceneObject
  model: SpatialModel
  images?: PlacementImageReference[]
}): MetricPlacementEstimate {
  const bounds = roomBounds(model)
  const role = wallRoleForCandidate(candidate)
  const image = imageForCandidate(candidate, images)
  const imageWidth = positiveNumber(image?.widthPx)
  const imageHeight = positiveNumber(image?.heightPx)
  const box = validBoundingBox(candidate.boundingBox)
  const prior = placementPriorForCandidate(candidate)
  const size = candidate.suggestedSize ?? prior.suggestedSize
  const reviewReasons: string[] = []

  if (!role) {
    reviewReasons.push('weak_or_missing_wall_role')
  }
  if (!box) {
    reviewReasons.push('missing_or_invalid_bbox')
  }
  if (!imageWidth || !imageHeight) {
    reviewReasons.push('missing_image_dimensions')
  }
  if (typeof candidate.confidenceScore === 'number' && candidate.confidenceScore < 0.7) {
    reviewReasons.push('low_confidence')
  }

  const placementRole = role ?? 'front_wall'
  const normalized = normalizedBottomCenter({
    box,
    imageWidth,
    imageHeight,
  })
  const fallbackPosition = positionForWallRole({
    role: placementRole,
    normalizedX: normalized.x,
    normalizedBottomY: normalized.bottomY,
    bounds,
    size,
  })
  let position = fallbackPosition
  let suggestedSize = size
  let evidenceSource: MetricPlacementEstimate['evidenceSource'] = 'wall_role'
  let depthConfidence: number | undefined
  const depthEvidence = depthEvidenceForPlacement({
    image,
    bounds,
    role: placementRole,
    size,
  })
  if (depthEvidence.kind === 'usable') {
    suggestedSize = depthEvidence.sizeScale
      ? scaledSize(size, depthEvidence.sizeScale)
      : size
    position = positionForWallRole({
      role: placementRole,
      normalizedX: normalized.x,
      normalizedBottomY: normalized.bottomY,
      bounds,
      size: suggestedSize,
      depthInsetMeters: depthEvidence.depthInsetMeters,
    })
    evidenceSource = 'depth_assisted'
    depthConfidence = depthEvidence.confidence
    if ((depthEvidence.confidence ?? 1) < depthReviewConfidence) {
      reviewReasons.push('depth_assisted_low_confidence')
    }
  } else if (depthEvidence.kind === 'noisy') {
    reviewReasons.push('noisy_depth_metadata')
  }
  const wall = roleToWall[placementRole]

  return {
    suggestedPosition: position,
    suggestedSize,
    suggestedRotationDegrees: wall.rotationDegrees,
    suggestedWallId: wall.wallId,
    evidenceSource,
    depthConfidence,
    reviewRequired: reviewReasons.length > 0,
    reviewReasons,
  }
}

export function applyMetricPlacementToCandidates({
  model,
  images = [],
}: {
  model: SpatialModel
  images?: PlacementImageReference[]
}): SpatialModel {
  return {
    ...model,
    candidateObjects: model.candidateObjects.map((candidate) =>
      applyMetricPlacementToCandidate({ candidate, model, images }),
    ),
  }
}

function applyMetricPlacementToCandidate({
  candidate,
  model,
  images,
}: {
  candidate: CandidateSceneObject
  model: SpatialModel
  images: PlacementImageReference[]
}): CandidateSceneObject {
  if (candidate.objectType !== 'furniture' && candidate.objectType !== 'structural_fixture') {
    return candidate
  }
  if (candidate.reviewState === 'rejected' || candidate.reviewState === 'placed') {
    return candidate
  }
  const estimate = estimateMetricPlacementForCandidate({ candidate, model, images })
  const shouldReview = estimate.reviewRequired || candidate.reviewState === 'review_required'
  return {
    ...candidate,
    suggestedPosition: estimate.suggestedPosition,
    suggestedAssetId: candidate.suggestedAssetId ?? placementPriorForCandidate(candidate).assetId,
    suggestedSize: estimate.suggestedSize,
    suggestedRotationDegrees: estimate.suggestedRotationDegrees,
    suggestedWallId: estimate.suggestedWallId,
    reviewState:
      shouldReview
        ? 'review_required'
        : candidate.reviewState,
    reviewLabel:
      shouldReview
        ? 'Needs review'
        : candidate.reviewLabel,
    notes: placementNotes({
      existingNotes: candidate.notes,
      reviewReasons: estimate.reviewReasons,
      wallId: estimate.suggestedWallId,
      evidenceSource: estimate.evidenceSource,
      depthConfidence: estimate.depthConfidence,
    }),
  }
}

function placementPriorForCandidate(candidate: CandidateSceneObject): {
  suggestedSize: MeterPoint3d
  assetId: string
} {
  if (candidate.objectType === 'structural_fixture') {
    const prior = structuralFixtureSizePriorForCategory(candidate.category)
    return { suggestedSize: prior.size, assetId: prior.assetId }
  }

  const prior = furnitureSizePriorForCategory(candidate.category)
  return { suggestedSize: prior.suggestedSize, assetId: prior.assetId }
}

function positionForWallRole({
  role,
  normalizedX,
  normalizedBottomY,
  bounds,
  size,
  depthInsetMeters,
}: {
  role: WallRole
  normalizedX: number
  normalizedBottomY: number
  bounds: RoomBounds
  size: MeterPoint3d
  depthInsetMeters?: number
}): MeterPoint3d {
  const xMargin = Math.max(0.1, size.x / 2)
  const zMargin = Math.max(0.1, size.z / 2)
  const frontBackInset =
    depthInsetMeters ??
    perpendicularInset({
      normalizedBottomY,
      roomSpanMeters: bounds.depthMeters,
      objectDepthMeters: size.z,
    })
  const sideInset =
    depthInsetMeters ??
    perpendicularInset({
      normalizedBottomY,
      roomSpanMeters: bounds.widthMeters,
      objectDepthMeters: size.z,
    })
  const widthOffset = normalizedX * bounds.widthMeters
  const depthOffset = normalizedX * bounds.depthMeters

  if (role === 'right_wall') {
    return {
      x: round2(clamp(bounds.widthMeters - sideInset, xMargin, bounds.widthMeters - xMargin)),
      y: 0,
      z: round2(clamp(depthOffset, zMargin, bounds.depthMeters - zMargin)),
    }
  }
  if (role === 'back_wall') {
    return {
      x: round2(clamp(bounds.widthMeters - widthOffset, xMargin, bounds.widthMeters - xMargin)),
      y: 0,
      z: round2(clamp(bounds.depthMeters - frontBackInset, zMargin, bounds.depthMeters - zMargin)),
    }
  }
  if (role === 'left_wall') {
    return {
      x: round2(clamp(sideInset, xMargin, bounds.widthMeters - xMargin)),
      y: 0,
      z: round2(clamp(bounds.depthMeters - depthOffset, zMargin, bounds.depthMeters - zMargin)),
    }
  }
  return {
    x: round2(clamp(widthOffset, xMargin, bounds.widthMeters - xMargin)),
    y: 0,
    z: round2(clamp(frontBackInset, zMargin, bounds.depthMeters - zMargin)),
  }
}

type DepthEvidence =
  | {
      kind: 'usable'
      depthInsetMeters: number
      confidence?: number
      sizeScale?: number
    }
  | { kind: 'noisy' }
  | { kind: 'missing' }

function depthEvidenceForPlacement({
  image,
  bounds,
  role,
  size,
}: {
  image: PlacementImageReference | null
  bounds: RoomBounds
  role: WallRole
  size: MeterPoint3d
}): DepthEvidence {
  if (!image?.cameraPose || !image.depthArtifactRefs || image.depthArtifactRefs.length === 0) {
    return { kind: 'missing' }
  }
  const depthEstimateMeters = positiveNumber(image.cameraPose.depthEstimateMeters)
  const confidence = normalizedNumber(image.cameraPose.depthConfidence)
  const roomSpanMeters = role === 'front_wall' || role === 'back_wall'
    ? bounds.depthMeters
    : bounds.widthMeters
  const minInset = Math.max(0.1, size.z / 2)
  const maxInset = Math.max(minInset, roomSpanMeters - minInset)
  if (
    !depthEstimateMeters ||
    depthEstimateMeters < minInset ||
    depthEstimateMeters > maxInset ||
    (confidence !== undefined && confidence < minUsableDepthConfidence)
  ) {
    return { kind: 'noisy' }
  }
  return {
    kind: 'usable',
    depthInsetMeters: round2(clamp(depthEstimateMeters, minInset, maxInset)),
    confidence,
    sizeScale: sizeScaleValue(image.cameraPose.sizeScale),
  }
}

function scaledSize(size: MeterPoint3d, scale: number): MeterPoint3d {
  return {
    x: round2(size.x * scale),
    y: size.y,
    z: round2(size.z * scale),
  }
}

function perpendicularInset({
  normalizedBottomY,
  roomSpanMeters,
  objectDepthMeters,
}: {
  normalizedBottomY: number
  roomSpanMeters: number
  objectDepthMeters: number
}): number {
  const wallAdjacentInset = Math.max(0.1, objectDepthMeters / 2)
  const perspectiveAllowance = Math.min(roomSpanMeters * 0.35, 1.2)
  return wallAdjacentInset + (1 - normalizedBottomY) * perspectiveAllowance
}

function normalizedBottomCenter({
  box,
  imageWidth,
  imageHeight,
}: {
  box: ImageBoundingBox | null
  imageWidth: number | null
  imageHeight: number | null
}): { x: number; bottomY: number } {
  if (!box || !imageWidth || !imageHeight) {
    return { x: 0.5, bottomY: 1 }
  }
  return {
    x: clamp((box.x + box.width / 2) / imageWidth, 0, 1),
    bottomY: clamp((box.y + box.height) / imageHeight, 0, 1),
  }
}

function wallRoleForCandidate(candidate: CandidateSceneObject): WallRole | null {
  const role = candidate.sourceImageRole
  return role === 'front_wall' ||
    role === 'right_wall' ||
    role === 'back_wall' ||
    role === 'left_wall'
    ? role
    : null
}

function imageForCandidate(
  candidate: CandidateSceneObject,
  images: PlacementImageReference[],
): PlacementImageReference | null {
  return (
    images.find(
      (image) =>
        image.captureImageId === candidate.captureImageId ||
        image.sourceImageId === candidate.sourceImageId ||
        image.role === candidate.sourceImageRole,
    ) ?? null
  )
}

function validBoundingBox(box: ImageBoundingBox | undefined): ImageBoundingBox | null {
  if (
    !box ||
    box.width <= 0 ||
    box.height <= 0 ||
    !Number.isFinite(box.x) ||
    !Number.isFinite(box.y) ||
    !Number.isFinite(box.width) ||
    !Number.isFinite(box.height)
  ) {
    return null
  }
  return box
}

function placementNotes({
  existingNotes,
  reviewReasons,
  wallId,
  evidenceSource,
  depthConfidence,
}: {
  existingNotes: string | undefined
  reviewReasons: string[]
  wallId: string
  evidenceSource: MetricPlacementEstimate['evidenceSource']
  depthConfidence?: number
}): string | undefined {
  const evidenceLabel =
    evidenceSource === 'depth_assisted'
      ? ` with depth metadata${depthConfidence === undefined ? '' : ` (${depthConfidence.toFixed(2)})`}`
      : ''
  const placementNote =
    reviewReasons.length > 0
      ? `Metric placement estimated for ${wallId}${evidenceLabel}; review: ${reviewReasons.join(', ')}.`
      : `Metric placement estimated for ${wallId}${evidenceLabel}.`
  if (!existingNotes || existingNotes.startsWith('Metric placement estimated for ')) {
    return placementNote
  }
  return existingNotes
}

function positiveNumber(value: number | undefined): number | null {
  return typeof value === 'number' && Number.isFinite(value) && value > 0 ? value : null
}

function normalizedNumber(value: number | undefined): number | undefined {
  return typeof value === 'number' && Number.isFinite(value) && value >= 0 && value <= 1
    ? value
    : undefined
}

function sizeScaleValue(value: number | undefined): number | undefined {
  if (typeof value !== 'number' || !Number.isFinite(value)) {
    return undefined
  }
  return clamp(value, 0.75, 1.3)
}

function clamp(value: number, min: number, max: number): number {
  if (max < min) {
    return (min + max) / 2
  }
  return Math.min(Math.max(value, min), max)
}

function round2(value: number): number {
  return Number(value.toFixed(2))
}
