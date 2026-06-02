import { roomBounds, type CandidateSceneObject, type FurnitureCategory, type SpatialModel } from './spatialModel.ts'
import {
  furnitureCategoryForValue,
  furnitureSizePriorForCategory,
} from './sizePriors.ts'

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
          ? `${Math.round(candidate.confidenceScore * 100)}%`
          : 'n/a',
      sourceLabel: sourceLabelForCandidate(candidate),
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
  const prior = furnitureSizePriorForCategory(category)
  const size = candidate.suggestedSize
    ? {
        widthMeters: Math.max(candidate.suggestedSize.x, 0.2),
        depthMeters: Math.max(candidate.suggestedSize.z, 0.2),
        heightMeters: Math.max(candidate.suggestedSize.y, 0.2),
      }
    : prior.size
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
    color: prior.color,
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
        assetId: candidate.suggestedAssetId ?? prior.assetId,
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
  const prior = furnitureSizePriorForCategory(category)
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
            suggestedAssetId: prior.assetId,
            suggestedSize: prior.suggestedSize,
            notes: 'Category changed; suggested size and representative asset were recalculated from category priors.',
          }
        : candidate,
    ),
  }
}

function candidateLabel(candidate: CandidateSceneObject): string {
  const prefix = candidate.objectType === 'structural_fixture' ? 'Fixture' : 'Furniture'
  return `${prefix}: ${candidate.category}`
}

function sourceLabelForCandidate(candidate: CandidateSceneObject): string {
  const evidence = candidate.sourceEvidence ?? []
  const roles = uniqueStrings(
    evidence
      .map((item) => item.sourceImageRole)
      .filter((role): role is string => typeof role === 'string' && role.length > 0),
  )
  if (roles.length > 0) {
    return roles.length === 1 ? roles[0] : `${roles.join(', ')} (${evidence.length} sources)`
  }
  return candidate.sourceImageRole ?? candidate.sourceImageId ?? 'unknown source'
}

function uniqueStrings(values: string[]): string[] {
  return [...new Set(values)]
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

function furnitureCategoryForCandidate(category: string): FurnitureCategory {
  return furnitureCategoryForValue(category)
}

function clamp(value: number, min: number, max: number): number {
  if (max < min) {
    return Number(((min + max) / 2).toFixed(2))
  }
  return Number(Math.min(Math.max(value, min), max).toFixed(2))
}
