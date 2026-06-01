import type {
  CandidateSceneObject,
  CandidateSourceEvidence,
  MeterPoint3d,
} from './spatialModel.ts'
import { furnitureSizePriorForCategory } from './sizePriors.ts'

type MergeDecision =
  | { kind: 'duplicate'; overlapRatio: number }
  | { kind: 'conflict'; overlapRatio: number }
  | { kind: 'none'; overlapRatio: number }

type Footprint = {
  minX: number
  maxX: number
  minZ: number
  maxZ: number
  area: number
  centerX: number
  centerZ: number
}

const duplicateOverlapThreshold = 0.35
const adjacentDuplicateOverlapThreshold = 0.25
const conflictOverlapThreshold = 0.45

export function mergeSceneCandidates(candidates: CandidateSceneObject[]): CandidateSceneObject[] {
  const merged: CandidateSceneObject[] = []

  for (const candidate of candidates) {
    const normalized = withSourceEvidence(candidate)
    const match = bestMergeTarget(merged, normalized)
    if (!match) {
      merged.push(normalized)
      continue
    }
    merged[match.index] = mergeCandidatePair(merged[match.index], normalized, match.decision)
  }

  return merged
}

function bestMergeTarget(
  merged: CandidateSceneObject[],
  candidate: CandidateSceneObject,
): { index: number; decision: Exclude<MergeDecision, { kind: 'none' }> } | null {
  let best: { index: number; decision: Exclude<MergeDecision, { kind: 'none' }> } | null = null
  for (let index = 0; index < merged.length; index += 1) {
    const decision = mergeDecision(merged[index], candidate)
    if (decision.kind === 'none') {
      continue
    }
    if (!best || mergeDecisionRank(decision) > mergeDecisionRank(best.decision)) {
      best = { index, decision }
    }
  }
  return best
}

function mergeDecision(existing: CandidateSceneObject, incoming: CandidateSceneObject): MergeDecision {
  const overlapRatio = footprintOverlapRatio(existing, incoming)
  if (existing.category === incoming.category) {
    const threshold = wallRolesAreAdjacent(existing.sourceImageRole, incoming.sourceImageRole)
      ? adjacentDuplicateOverlapThreshold
      : duplicateOverlapThreshold
    return overlapRatio >= threshold
      ? { kind: 'duplicate', overlapRatio }
      : { kind: 'none', overlapRatio }
  }
  return overlapRatio >= conflictOverlapThreshold
    ? { kind: 'conflict', overlapRatio }
    : { kind: 'none', overlapRatio }
}

function mergeDecisionRank(decision: Exclude<MergeDecision, { kind: 'none' }>): number {
  const typeRank = decision.kind === 'conflict' ? 10 : 0
  return typeRank + decision.overlapRatio
}

function mergeCandidatePair(
  existing: CandidateSceneObject,
  incoming: CandidateSceneObject,
  decision: Exclude<MergeDecision, { kind: 'none' }>,
): CandidateSceneObject {
  const primary = higherConfidenceCandidate(existing, incoming)
  const evidence = mergeEvidence(existing, incoming)
  const sourceRoles = uniqueStrings(
    evidence
      .map((item) => item.sourceImageRole)
      .filter((role): role is string => typeof role === 'string' && role.length > 0),
  )
  const mergedPosition =
    decision.kind === 'duplicate'
      ? weightedPosition(existing, incoming) ?? primary.suggestedPosition
      : primary.suggestedPosition
  const reviewRequired =
    decision.kind === 'conflict' ||
    existing.reviewState === 'review_required' ||
    incoming.reviewState === 'review_required'

  return {
    ...primary,
    sourceEvidence: evidence,
    sourceImageRole: primary.sourceImageRole,
    sourceImageId: primary.sourceImageId,
    captureImageId: primary.captureImageId,
    suggestedPosition: mergedPosition,
    confidenceScore: Math.max(existing.confidenceScore ?? 0, incoming.confidenceScore ?? 0),
    reviewState:
      primary.reviewState === 'rejected' || primary.reviewState === 'placed'
        ? primary.reviewState
        : reviewRequired
          ? 'review_required'
          : primary.reviewState,
    reviewLabel:
      primary.reviewState === 'rejected' || primary.reviewState === 'placed'
        ? primary.reviewLabel
        : reviewRequired
          ? 'Needs review'
          : primary.reviewLabel,
    notes: mergeNotes({
      decision,
      selectedCategory: primary.category,
      sourceRoles,
      evidenceCount: evidence.length,
    }),
  }
}

function withSourceEvidence(candidate: CandidateSceneObject): CandidateSceneObject {
  return {
    ...candidate,
    sourceEvidence: sourceEvidenceForCandidate(candidate),
  }
}

function sourceEvidenceForCandidate(candidate: CandidateSceneObject): CandidateSourceEvidence[] {
  if (candidate.sourceEvidence && candidate.sourceEvidence.length > 0) {
    return candidate.sourceEvidence
  }
  return [
    {
      candidateId: candidate.candidateId,
      sourceImageId: candidate.sourceImageId,
      captureImageId: candidate.captureImageId,
      sourceImageRole: candidate.sourceImageRole,
      confidenceScore: candidate.confidenceScore,
      boundingBox: candidate.boundingBox,
    },
  ]
}

function mergeEvidence(
  existing: CandidateSceneObject,
  incoming: CandidateSceneObject,
): CandidateSourceEvidence[] {
  const evidence = [...sourceEvidenceForCandidate(existing), ...sourceEvidenceForCandidate(incoming)]
  const seen = new Set<string>()
  return evidence.filter((item) => {
    const key = `${item.candidateId}:${item.captureImageId ?? ''}:${item.sourceImageId ?? ''}`
    if (seen.has(key)) {
      return false
    }
    seen.add(key)
    return true
  })
}

function higherConfidenceCandidate(
  first: CandidateSceneObject,
  second: CandidateSceneObject,
): CandidateSceneObject {
  return (second.confidenceScore ?? 0) > (first.confidenceScore ?? 0) ? second : first
}

function weightedPosition(
  first: CandidateSceneObject,
  second: CandidateSceneObject,
): MeterPoint3d | undefined {
  if (!first.suggestedPosition || !second.suggestedPosition) {
    return undefined
  }
  const firstWeight = Math.max(first.confidenceScore ?? 0.5, 0.1)
  const secondWeight = Math.max(second.confidenceScore ?? 0.5, 0.1)
  const total = firstWeight + secondWeight
  return {
    x: round2((first.suggestedPosition.x * firstWeight + second.suggestedPosition.x * secondWeight) / total),
    y: 0,
    z: round2((first.suggestedPosition.z * firstWeight + second.suggestedPosition.z * secondWeight) / total),
  }
}

function footprintOverlapRatio(first: CandidateSceneObject, second: CandidateSceneObject): number {
  const firstFootprint = footprintForCandidate(first)
  const secondFootprint = footprintForCandidate(second)
  if (!firstFootprint || !secondFootprint) {
    return 0
  }
  const intersectionWidth = Math.max(
    0,
    Math.min(firstFootprint.maxX, secondFootprint.maxX) -
      Math.max(firstFootprint.minX, secondFootprint.minX),
  )
  const intersectionDepth = Math.max(
    0,
    Math.min(firstFootprint.maxZ, secondFootprint.maxZ) -
      Math.max(firstFootprint.minZ, secondFootprint.minZ),
  )
  const intersectionArea = intersectionWidth * intersectionDepth
  return intersectionArea / Math.min(firstFootprint.area, secondFootprint.area)
}

function footprintForCandidate(candidate: CandidateSceneObject): Footprint | null {
  const position = candidate.suggestedPosition
  if (!position) {
    return null
  }
  const size = candidate.suggestedSize ?? furnitureSizePriorForCategory(candidate.category).suggestedSize
  const width = Math.max(size.x, 0.1)
  const depth = Math.max(size.z, 0.1)
  return {
    minX: position.x - width / 2,
    maxX: position.x + width / 2,
    minZ: position.z - depth / 2,
    maxZ: position.z + depth / 2,
    area: width * depth,
    centerX: position.x,
    centerZ: position.z,
  }
}

function wallRolesAreAdjacent(first: string | undefined, second: string | undefined): boolean {
  const order = ['front_wall', 'right_wall', 'back_wall', 'left_wall']
  const firstIndex = order.indexOf(first ?? '')
  const secondIndex = order.indexOf(second ?? '')
  if (firstIndex < 0 || secondIndex < 0) {
    return false
  }
  const distance = Math.abs(firstIndex - secondIndex)
  return distance === 0 || distance === 1 || distance === order.length - 1
}

function mergeNotes({
  decision,
  selectedCategory,
  sourceRoles,
  evidenceCount,
}: {
  decision: Exclude<MergeDecision, { kind: 'none' }>
  selectedCategory: string
  sourceRoles: string[]
  evidenceCount: number
}): string {
  const roleSummary = sourceRoles.length > 0 ? sourceRoles.join(', ') : 'unknown roles'
  if (decision.kind === 'conflict') {
    return `Merged overlapping category conflict; selected ${selectedCategory} by confidence. Sources: ${roleSummary}.`
  }
  return `Merged ${evidenceCount} same-category detections. Sources: ${roleSummary}.`
}

function uniqueStrings(values: string[]): string[] {
  return [...new Set(values)]
}

function round2(value: number): number {
  return Number(value.toFixed(2))
}
