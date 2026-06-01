import type {
  CandidateSceneObject,
  StructuralFixtureObject,
} from './spatialModel.ts'
import type { PlacementImageReference } from './scenePlacement.ts'

export type RequiredWallRole = 'front_wall' | 'right_wall' | 'back_wall' | 'left_wall'

export type WallCoverageState = 'complete' | 'partial' | 'low_confidence' | 'missing'

export type WallCoverage = {
  role: RequiredWallRole
  state: WallCoverageState
  candidateCount: number
  maxConfidence: number | null
  guidance: string
}

export type SceneCoverageSummary = {
  requiredRoles: RequiredWallRole[]
  walls: Record<RequiredWallRole, WallCoverage>
  canContinue: boolean
  guidance: string[]
}

export type SceneCoverageInput = {
  availableRoles?: string[]
  images?: PlacementImageReference[]
  candidateObjects?: CandidateSceneObject[]
  structuralFixtures?: StructuralFixtureObject[]
}

export const requiredWallRoles: RequiredWallRole[] = [
  'front_wall',
  'right_wall',
  'back_wall',
  'left_wall',
]

export function computeSceneCoverage({
  availableRoles = [],
  images = [],
  candidateObjects = [],
  structuralFixtures = [],
}: SceneCoverageInput): SceneCoverageSummary {
  const rolesWithImages = new Set([
    ...availableRoles,
    ...images.map((image) => image.role).filter((role): role is string => Boolean(role)),
  ])
  const walls = Object.fromEntries(
    requiredWallRoles.map((role) => [
      role,
      coverageForRole({
        role,
        rolesWithImages,
        candidateObjects,
        structuralFixtures,
      }),
    ]),
  ) as Record<RequiredWallRole, WallCoverage>
  const incomplete = requiredWallRoles
    .map((role) => walls[role])
    .filter((wall) => wall.state !== 'complete')
  const canContinue = incomplete.length === 0
  return {
    requiredRoles: requiredWallRoles,
    walls,
    canContinue,
    guidance: canContinue
      ? ['Coverage looks sufficient. Continue editing the generated layout.']
      : incomplete.map((wall) => wall.guidance),
  }
}

export function sceneCoveragePayload(summary: SceneCoverageSummary): Record<string, unknown> {
  return {
    requiredRoles: summary.requiredRoles,
    canContinue: summary.canContinue,
    guidance: summary.guidance,
    walls: Object.fromEntries(
      summary.requiredRoles.map((role) => [
        role,
        {
          state: summary.walls[role].state,
          candidateCount: summary.walls[role].candidateCount,
          maxConfidence: summary.walls[role].maxConfidence,
          guidance: summary.walls[role].guidance,
        },
      ]),
    ),
  }
}

export function coverageGuidanceText(summary: SceneCoverageSummary): string {
  return summary.guidance[0] ?? 'Coverage needs review before editing.'
}

function coverageForRole({
  role,
  rolesWithImages,
  candidateObjects,
  structuralFixtures,
}: {
  role: RequiredWallRole
  rolesWithImages: Set<string>
  candidateObjects: CandidateSceneObject[]
  structuralFixtures: StructuralFixtureObject[]
}): WallCoverage {
  const hasImage = rolesWithImages.has(role)
  const confidences = [
    ...candidateConfidencesForRole(role, candidateObjects),
    ...fixtureConfidencesForRole(role, structuralFixtures),
  ]
  const candidateCount = confidences.length
  const maxConfidence = confidences.length > 0 ? Math.max(...confidences) : null

  if (!hasImage) {
    return {
      role,
      state: 'missing',
      candidateCount,
      maxConfidence,
      guidance: `Capture a ${role} photo to complete room coverage.`,
    }
  }
  if (candidateCount === 0) {
    return {
      role,
      state: 'partial',
      candidateCount,
      maxConfidence,
      guidance: `Add an angled ${role} photo or review this wall manually.`,
    }
  }
  if ((maxConfidence ?? 0) < 0.7) {
    return {
      role,
      state: 'low_confidence',
      candidateCount,
      maxConfidence,
      guidance: `Retake the ${role} photo with the full wall and furniture visible.`,
    }
  }
  return {
    role,
    state: 'complete',
    candidateCount,
    maxConfidence,
    guidance: `${role} coverage is sufficient.`,
  }
}

function candidateConfidencesForRole(
  role: RequiredWallRole,
  candidates: CandidateSceneObject[],
): number[] {
  return candidates.flatMap((candidate) => {
    const evidence = candidate.sourceEvidence ?? [
      {
        sourceImageRole: candidate.sourceImageRole,
        confidenceScore: candidate.confidenceScore,
      },
    ]
    return evidence
      .filter((item) => item.sourceImageRole === role)
      .map((item) => item.confidenceScore ?? candidate.confidenceScore)
      .filter((score): score is number => typeof score === 'number' && Number.isFinite(score))
  })
}

function fixtureConfidencesForRole(
  role: RequiredWallRole,
  fixtures: StructuralFixtureObject[],
): number[] {
  const wallId = wallIdForRole(role)
  return fixtures
    .filter((fixture) => fixture.wallId === wallId)
    .map((fixture) => fixture.confidenceScore)
    .filter((score): score is number => typeof score === 'number' && Number.isFinite(score))
}

function wallIdForRole(role: RequiredWallRole): string {
  if (role === 'right_wall') {
    return 'right-wall'
  }
  if (role === 'back_wall') {
    return 'back-wall'
  }
  if (role === 'left_wall') {
    return 'left-wall'
  }
  return 'front-wall'
}
