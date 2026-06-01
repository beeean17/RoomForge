import type { CandidateSceneObject, SpatialModel } from './spatialModel'

export type CandidateTrayItem = {
  candidateId: string
  label: string
  category: string
  confidenceLabel: string
  sourceLabel: string
  reviewLabel: string
  rejected: boolean
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
    return {
      candidateId: candidate.candidateId,
      label: candidate.label ?? candidateLabel(candidate),
      category: candidate.category,
      confidenceLabel:
        typeof candidate.confidenceScore === 'number'
          ? candidate.confidenceScore.toFixed(2)
          : 'n/a',
      sourceLabel: candidate.sourceImageRole ?? candidate.sourceImageId ?? 'unknown source',
      reviewLabel: candidate.reviewLabel ?? reviewLabelFor({ rejected, lowConfidence }),
      rejected,
      lowConfidence,
    }
  })
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
  lowConfidence,
}: {
  rejected: boolean
  lowConfidence: boolean
}): string {
  if (rejected) {
    return 'Rejected'
  }
  return lowConfidence ? 'Needs review' : 'Candidate'
}

function suggestedAssetIdForCategory(category: string): string {
  return `${category}.pending`
}
