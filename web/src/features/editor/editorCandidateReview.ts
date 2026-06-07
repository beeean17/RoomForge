export type CandidateReviewItem = {
  candidateId: string
  objectType: string
  category: string
  label: string
  confidenceLabel: string
  sourceLabel: string
  evidenceLabel: string
  reviewState: string
  reviewLabel: string
  coordinateSpace: string
  isFurniture: boolean
  isPlaced: boolean
  isRejected: boolean
  needsReview: boolean
  canPlace: boolean
  canReject: boolean
  canChangeCategory: boolean
}

export type CandidateReviewState = {
  items: CandidateReviewItem[]
  counts: {
    candidates: number
    needsReview: number
    placed: number
    rejected: number
    confirmed: number
  }
}

export const candidateReviewCategoryOptions = [
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

type CandidateRecord = Record<string, unknown>

export function candidateReviewStateFromPayload(payload: Record<string, unknown>): CandidateReviewState | null {
  const source = candidatePayloadSource(payload)
  const candidateObjects = listValue(source.candidateObjects)
  if (!candidateObjects.length && !('candidateObjects' in source)) {
    return null
  }

  const placedCandidateIds = new Set(
    [
      ...listValue(source.placedObjects),
      ...listValue(source.furniture),
    ]
      .map((item) => stringValue(recordValue(item).candidateId))
      .filter((candidateId): candidateId is string => Boolean(candidateId)),
  )
  const confirmedCount = listValue(source.confirmedObjects).length
  const items = candidateObjects
    .map((item) => candidateReviewItemFromRecord(recordValue(item), placedCandidateIds))
    .filter((item): item is CandidateReviewItem => item !== null)

  return {
    items,
    counts: {
      candidates: items.length,
      needsReview: items.filter((item) => item.needsReview).length,
      placed: items.filter((item) => item.isPlaced).length,
      rejected: items.filter((item) => item.isRejected).length,
      confirmed: confirmedCount,
    },
  }
}

function candidatePayloadSource(payload: Record<string, unknown>): Record<string, unknown> {
  const scene = recordValue(payload.scene)
  if ('candidateObjects' in scene) {
    return scene
  }
  const sceneUnderstandingResult = recordValue(payload.sceneUnderstandingResult)
  if ('candidateObjects' in sceneUnderstandingResult) {
    return sceneUnderstandingResult
  }
  return payload
}

function candidateReviewItemFromRecord(
  candidate: CandidateRecord,
  placedCandidateIds: Set<string>,
): CandidateReviewItem | null {
  const candidateId = stringValue(candidate.candidateId)
  if (!candidateId) {
    return null
  }

  const category = stringValue(candidate.category) ?? 'custom'
  const objectType = stringValue(candidate.objectType) ?? 'furniture'
  const confidenceScore = numberValue(candidate.confidenceScore)
  const reviewState = stringValue(candidate.reviewState) ?? 'new'
  const explicitLabel = stringValue(candidate.reviewLabel)
  const isRejected = reviewState === 'rejected'
  const isPlaced = reviewState === 'placed' || placedCandidateIds.has(candidateId)
  const lowConfidence = typeof confidenceScore === 'number' && confidenceScore < 0.7
  const needsReview = !isRejected && !isPlaced && (reviewState === 'review_required' || lowConfidence)
  const isFurniture = objectType === 'furniture'

  return {
    candidateId,
    objectType,
    category,
    label: stringValue(candidate.label) ?? candidateLabel(objectType, category),
    confidenceLabel: typeof confidenceScore === 'number' ? `${Math.round(confidenceScore * 100)}%` : 'n/a',
    sourceLabel: sourceLabelForCandidate(candidate),
    evidenceLabel: evidenceLabelForCandidate(candidate),
    reviewState,
    reviewLabel: explicitLabel ?? reviewLabelFor({ isRejected, isPlaced, needsReview }),
    coordinateSpace: stringValue(candidate.coordinateSpace) ?? 'unknown',
    isFurniture,
    isPlaced,
    isRejected,
    needsReview,
    canPlace: isFurniture && !isRejected && !isPlaced,
    canReject: !isRejected,
    canChangeCategory: !isRejected,
  }
}

function candidateLabel(objectType: string, category: string): string {
  return `${objectType === 'structural_fixture' ? 'Fixture' : 'Furniture'}: ${category}`
}

function reviewLabelFor({
  isRejected,
  isPlaced,
  needsReview,
}: {
  isRejected: boolean
  isPlaced: boolean
  needsReview: boolean
}): string {
  if (isRejected) return 'Rejected'
  if (isPlaced) return 'Placed'
  return needsReview ? 'Needs review' : 'Candidate'
}

function sourceLabelForCandidate(candidate: CandidateRecord): string {
  const sourceEvidence = listValue(candidate.sourceEvidence)
  const roles = uniqueStrings(
    sourceEvidence
      .map((item) => stringValue(recordValue(item).sourceImageRole))
      .filter((role): role is string => Boolean(role)),
  )
  if (roles.length === 1) {
    return roles[0]
  }
  if (roles.length > 1) {
    return `${roles.join(', ')} (${sourceEvidence.length} sources)`
  }
  return stringValue(candidate.sourceImageRole) ?? stringValue(candidate.sourceImageId) ?? 'unknown source'
}

function evidenceLabelForCandidate(candidate: CandidateRecord): string {
  const sourceEvidence = listValue(candidate.sourceEvidence)
  if (sourceEvidence.length > 0) {
    return `${sourceEvidence.length} source${sourceEvidence.length === 1 ? '' : 's'}`
  }
  const captureImageId = stringValue(candidate.captureImageId)
  if (captureImageId) {
    return captureImageId
  }
  return 'single source'
}

function uniqueStrings(values: string[]): string[] {
  return [...new Set(values)]
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

function numberValue(value: unknown): number | undefined {
  return typeof value === 'number' && Number.isFinite(value) ? value : undefined
}
