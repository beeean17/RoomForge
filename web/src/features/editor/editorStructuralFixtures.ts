export type StructuralFixtureCandidateItem = {
  candidateId: string
  category: string
  label: string
  reviewLabel: string
  sourceLabel: string
  confidenceLabel: string
  needsReview: boolean
  isPlaced: boolean
  isRejected: boolean
  canPlace: boolean
  canReject: boolean
}

export type StructuralFixtureItem = {
  fixtureId: string
  candidateId?: string
  category: string
  label: string
  wallId: string
  sourceLabel: string
  confidenceLabel: string
  selected: boolean
  locked: boolean
  widthMeters: number
  heightMeters: number
  depthMeters: number
  offsetMeters: number
  verticalCenterMeters: number
  rotationDegrees: number
  canEdit: boolean
}

export type StructuralFixtureState = {
  candidates: StructuralFixtureCandidateItem[]
  fixtures: StructuralFixtureItem[]
  selectedFixture: StructuralFixtureItem | null
  counts: {
    candidates: number
    needsReview: number
    placed: number
    rejected: number
    selected: number
  }
}

export function structuralFixtureStateFromPayload(payload: Record<string, unknown>): StructuralFixtureState | null {
  const source = structuralFixturePayloadSource(payload)
  if (!('candidateObjects' in source) && !('structuralFixtures' in source)) {
    return null
  }

  const fixtures = listValue(source.structuralFixtures)
    .map((fixture) =>
      structuralFixtureItemFromRecord({
        fixture: recordValue(fixture),
        selected: recordValue(source.selected),
      }),
    )
    .filter((fixture): fixture is StructuralFixtureItem => fixture !== null)
  const placedCandidateIds = new Set(
    fixtures
      .map((fixture) => fixture.candidateId)
      .filter((candidateId): candidateId is string => Boolean(candidateId)),
  )
  const candidates = listValue(source.candidateObjects)
    .map((candidate) => structuralCandidateItemFromRecord(recordValue(candidate), placedCandidateIds))
    .filter((candidate): candidate is StructuralFixtureCandidateItem => candidate !== null)
  const selectedFixture = fixtures.find((fixture) => fixture.selected) ?? null

  return {
    candidates,
    fixtures,
    selectedFixture,
    counts: {
      candidates: candidates.length,
      needsReview: candidates.filter((candidate) => candidate.needsReview).length,
      placed: candidates.filter((candidate) => candidate.isPlaced).length,
      rejected: candidates.filter((candidate) => candidate.isRejected).length,
      selected: selectedFixture ? 1 : 0,
    },
  }
}

function structuralFixturePayloadSource(payload: Record<string, unknown>): Record<string, unknown> {
  const scene = recordValue(payload.scene)
  if ('candidateObjects' in scene || 'structuralFixtures' in scene) {
    return scene
  }
  const spatialModel = recordValue(payload.spatialModel)
  if ('candidateObjects' in spatialModel || 'structuralFixtures' in spatialModel) {
    return spatialModel
  }
  return payload
}

function structuralCandidateItemFromRecord(
  candidate: Record<string, unknown>,
  placedCandidateIds: Set<string>,
): StructuralFixtureCandidateItem | null {
  if (candidate.objectType !== 'structural_fixture') {
    return null
  }
  const candidateId = stringValue(candidate.candidateId)
  if (!candidateId) {
    return null
  }

  const category = stringValue(candidate.category) ?? 'fixture'
  const confidenceScore = numberValue(candidate.confidenceScore)
  const reviewState = stringValue(candidate.reviewState) ?? 'new'
  const isRejected = reviewState === 'rejected'
  const isPlaced = reviewState === 'placed' || placedCandidateIds.has(candidateId)
  const lowConfidence = typeof confidenceScore === 'number' && confidenceScore < 0.7
  const needsReview = !isRejected && !isPlaced && (reviewState === 'review_required' || lowConfidence)

  return {
    candidateId,
    category,
    label: stringValue(candidate.label) ?? `Fixture: ${category}`,
    reviewLabel: stringValue(candidate.reviewLabel) ?? reviewLabelFor({ isRejected, isPlaced, needsReview }),
    sourceLabel: sourceLabelForCandidate(candidate),
    confidenceLabel: typeof confidenceScore === 'number' ? `${Math.round(confidenceScore * 100)}%` : 'n/a',
    needsReview,
    isPlaced,
    isRejected,
    canPlace: !isRejected && !isPlaced,
    canReject: !isRejected,
  }
}

function structuralFixtureItemFromRecord({
  fixture,
  selected,
}: {
  fixture: Record<string, unknown>
  selected: Record<string, unknown>
}): StructuralFixtureItem | null {
  const fixtureId = stringValue(fixture.fixtureId)
  if (!fixtureId) {
    return null
  }
  const size = recordValue(fixture.size)
  const position = recordValue(fixture.position)
  const category = stringValue(fixture.category) ?? 'fixture'
  const confidenceScore = numberValue(fixture.confidenceScore)
  const locked = booleanValue(fixture.locked, false)

  return {
    fixtureId,
    candidateId: stringValue(fixture.candidateId),
    category,
    label: stringValue(fixture.label) ?? `Fixture: ${category}`,
    wallId: stringValue(fixture.wallId) ?? 'front-wall',
    sourceLabel: stringValue(fixture.candidateId) ? 'CV candidate' : 'Manual fixture',
    confidenceLabel: typeof confidenceScore === 'number' ? `${Math.round(confidenceScore * 100)}%` : 'n/a',
    selected: selected.objectType === 'fixture' && selected.objectId === fixtureId,
    locked,
    widthMeters: numberValue(size.x, 0.8),
    heightMeters: numberValue(size.y, 1),
    depthMeters: numberValue(size.z, 0.1),
    offsetMeters: numberValue(position.x, 0),
    verticalCenterMeters: numberValue(position.y, 1),
    rotationDegrees: numberValue(fixture.rotationDegrees, 0),
    canEdit: !locked,
  }
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

function sourceLabelForCandidate(candidate: Record<string, unknown>): string {
  const sourceEvidence = listValue(candidate.sourceEvidence)
  const roles = uniqueStrings(
    sourceEvidence
      .map((item) => stringValue(recordValue(item).sourceImageRole))
      .filter((role): role is string => Boolean(role)),
  )
  if (roles.length > 0) {
    return roles.length === 1 ? roles[0] : `${roles.join(', ')} (${sourceEvidence.length} sources)`
  }
  return stringValue(candidate.sourceImageRole) ?? stringValue(candidate.sourceImageId) ?? 'unknown source'
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

function numberValue(value: unknown): number | undefined
function numberValue(value: unknown, fallback: number): number
function numberValue(value: unknown, fallback?: number): number | undefined {
  return typeof value === 'number' && Number.isFinite(value) ? value : fallback
}

function booleanValue(value: unknown, fallback: boolean): boolean {
  return typeof value === 'boolean' ? value : fallback
}
