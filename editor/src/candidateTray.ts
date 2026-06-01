import { roomBounds, type CandidateSceneObject, type FurnitureCategory, type SpatialModel } from './spatialModel.ts'

export type CandidateTrayItem = {
  candidateId: string
  label: string
  category: string
  confidenceLabel: string
  sourceLabel: string
  reviewLabel: string
  rejected: boolean
  placed: boolean
  lowConfidence: boolean
}

export const candidateCategoryOptions = [
  'bed',
  'desk',
  'chair',
  'table',
  'sofa',
  'wardrobe',
  'shelf',
  'cabinet',
  'window',
  'door',
  'custom',
] as const

export function candidateTrayItems(model: SpatialModel): CandidateTrayItem[] {
  return model.candidateObjects.map((candidate) => {
    const lowConfidence =
      typeof candidate.confidenceScore === 'number' && candidate.confidenceScore < 0.7
    const rejected = candidate.reviewState === 'rejected'
    const placed = model.furniture.some((item) => item.candidateId === candidate.candidateId)
    return {
      candidateId: candidate.candidateId,
      label: candidate.label ?? candidateLabel(candidate),
      category: candidate.category,
      confidenceLabel:
        typeof candidate.confidenceScore === 'number'
          ? candidate.confidenceScore.toFixed(2)
          : 'n/a',
      sourceLabel: candidate.sourceImageRole ?? candidate.sourceImageId ?? 'unknown source',
      reviewLabel: candidate.reviewLabel ?? reviewLabelFor({ rejected, placed, lowConfidence }),
      rejected,
      placed,
      lowConfidence,
    }
  })
}

export function placeCandidateInModel(
  model: SpatialModel,
  candidateId: string,
): SpatialModel {
  const candidate = model.candidateObjects.find((item) => item.candidateId === candidateId)
  if (!candidate || candidate.objectType !== 'furniture' || candidate.reviewState === 'rejected') {
    return model
  }
  const existing = model.furniture.find((item) => item.candidateId === candidateId)
  if (existing) {
    return {
      ...model,
      selected: { objectId: existing.objectId, objectType: 'furniture' },
    }
  }

  const bounds = roomBounds(model)
  const category = furnitureCategoryForCandidate(candidate.category)
  const size = candidate.suggestedSize
    ? {
        widthMeters: Math.max(candidate.suggestedSize.x, 0.2),
        depthMeters: Math.max(candidate.suggestedSize.z, 0.2),
        heightMeters: Math.max(candidate.suggestedSize.y, 0.2),
      }
    : defaultSizeForCategory(category)
  const position = candidate.suggestedPosition
    ? {
        x: clamp(candidate.suggestedPosition.x, size.widthMeters / 2, bounds.widthMeters - size.widthMeters / 2),
        y: clamp(candidate.suggestedPosition.z, size.depthMeters / 2, bounds.depthMeters - size.depthMeters / 2),
      }
    : {
        x: bounds.centerX,
        y: bounds.centerY,
      }
  const objectId = `cv-${candidateId.replace(/[^a-zA-Z0-9_-]/g, '-')}`
  const furniture = {
    objectId,
    category,
    candidateId,
    source: 'cv_candidate' as const,
    label: candidate.label ?? candidateLabel(candidate),
    size,
    position,
    rotationDegrees: candidate.suggestedRotationDegrees ?? 0,
    color: colorForCategory(category),
    locked: false,
  }

  return {
    ...model,
    hasUnsavedChanges: true,
    selected: { objectId, objectType: 'furniture' },
    furniture: [...model.furniture, furniture],
    placedObjects: [
      ...model.placedObjects.filter((object) => object.candidateId !== candidateId),
      {
        objectId,
        candidateId,
        objectType: 'furniture',
        category,
        assetId: candidate.suggestedAssetId,
        label: furniture.label,
        position: { x: position.x, y: 0, z: position.y },
        size: { x: size.widthMeters, y: size.heightMeters, z: size.depthMeters },
        rotationDegrees: furniture.rotationDegrees,
        confidenceScore: candidate.confidenceScore,
        locked: false,
      },
    ],
    candidateObjects: model.candidateObjects.map((item) =>
      item.candidateId === candidateId
        ? { ...item, reviewState: 'placed', reviewLabel: 'Placed' }
        : item,
    ),
  }
}

export function rejectCandidateInModel(
  model: SpatialModel,
  candidateId: string,
): SpatialModel {
  if (!model.candidateObjects.some((candidate) => candidate.candidateId === candidateId)) {
    return model
  }
  return {
    ...model,
    hasUnsavedChanges: true,
    candidateObjects: model.candidateObjects.map((candidate) =>
      candidate.candidateId === candidateId
        ? {
            ...candidate,
            reviewState: 'rejected',
            reviewLabel: 'Rejected',
            notes: candidate.notes ?? 'Rejected in candidate tray.',
          }
        : candidate,
    ),
    placedObjects: model.placedObjects.filter((object) => object.candidateId !== candidateId),
    furniture: model.furniture.filter((object) => object.candidateId !== candidateId),
  }
}

export function releaseCandidatePlacementInModel(
  model: SpatialModel,
  candidateId: string,
): SpatialModel {
  if (!model.candidateObjects.some((candidate) => candidate.candidateId === candidateId)) {
    return model
  }
  return {
    ...model,
    candidateObjects: model.candidateObjects.map((candidate) =>
      candidate.candidateId === candidateId
        ? { ...candidate, reviewState: 'review_required', reviewLabel: 'Needs review' }
        : candidate,
    ),
    placedObjects: model.placedObjects.filter((object) => object.candidateId !== candidateId),
  }
}

export function updateCandidateCategoryInModel({
  model,
  candidateId,
  category,
}: {
  model: SpatialModel
  candidateId: string
  category: string
}): SpatialModel {
  if (!candidateCategoryOptions.includes(category as (typeof candidateCategoryOptions)[number])) {
    return model
  }
  if (!model.candidateObjects.some((candidate) => candidate.candidateId === candidateId)) {
    return model
  }
  return {
    ...model,
    hasUnsavedChanges: true,
    candidateObjects: model.candidateObjects.map((candidate) =>
      candidate.candidateId === candidateId
        ? {
            ...candidate,
            category,
            reviewState: 'review_required',
            reviewLabel: 'Needs review',
            suggestedAssetId: suggestedAssetIdForCategory(category),
            notes: 'Category changed; suggested asset and size prior pending recalculation.',
          }
        : candidate,
    ),
  }
}

function candidateLabel(candidate: CandidateSceneObject): string {
  const prefix = candidate.objectType === 'structural_fixture' ? 'Fixture' : 'Furniture'
  return `${prefix}: ${candidate.category}`
}

function reviewLabelFor({
  rejected,
  placed,
  lowConfidence,
}: {
  rejected: boolean
  placed: boolean
  lowConfidence: boolean
}): string {
  if (rejected) {
    return 'Rejected'
  }
  if (placed) {
    return 'Placed'
  }
  return lowConfidence ? 'Needs review' : 'Candidate'
}

function suggestedAssetIdForCategory(category: string): string {
  return `${category}.pending`
}

function furnitureCategoryForCandidate(category: string): FurnitureCategory {
  return isCandidateFurnitureCategory(category) ? category : 'custom'
}

function isCandidateFurnitureCategory(category: string): category is FurnitureCategory {
  return [
    'bed',
    'desk',
    'chair',
    'wardrobe',
    'sofa',
    'table',
    'shelf',
    'cabinet',
    'custom',
  ].includes(category)
}

function defaultSizeForCategory(category: FurnitureCategory): {
  widthMeters: number
  depthMeters: number
  heightMeters: number
} {
  const sizes: Record<FurnitureCategory, { widthMeters: number; depthMeters: number; heightMeters: number }> = {
    bed: { widthMeters: 1.5, depthMeters: 2, heightMeters: 0.55 },
    desk: { widthMeters: 1.2, depthMeters: 0.65, heightMeters: 0.75 },
    chair: { widthMeters: 0.55, depthMeters: 0.55, heightMeters: 0.85 },
    wardrobe: { widthMeters: 1, depthMeters: 0.6, heightMeters: 2 },
    sofa: { widthMeters: 1.8, depthMeters: 0.85, heightMeters: 0.82 },
    table: { widthMeters: 1.2, depthMeters: 0.75, heightMeters: 0.74 },
    shelf: { widthMeters: 0.9, depthMeters: 0.35, heightMeters: 1.6 },
    cabinet: { widthMeters: 0.9, depthMeters: 0.45, heightMeters: 0.9 },
    custom: { widthMeters: 0.8, depthMeters: 0.8, heightMeters: 0.8 },
  }
  return sizes[category]
}

function colorForCategory(category: FurnitureCategory): string {
  const colors: Record<FurnitureCategory, string> = {
    bed: '#6f7f8f',
    desk: '#7f6f8f',
    chair: '#64748b',
    wardrobe: '#64748b',
    sofa: '#8b6f61',
    table: '#7f8f6f',
    shelf: '#5f7f7a',
    cabinet: '#7a6f61',
    custom: '#64748b',
  }
  return colors[category]
}

function clamp(value: number, min: number, max: number): number {
  if (max < min) {
    return Number(((min + max) / 2).toFixed(2))
  }
  return Number(Math.min(Math.max(value, min), max).toFixed(2))
}
