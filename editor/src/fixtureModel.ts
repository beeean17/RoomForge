import { roomBounds, type CandidateSceneObject, type SpatialModel, type StructuralFixtureObject } from './spatialModel.ts'

export type FixtureEditAction =
  | 'wall-previous'
  | 'wall-next'
  | 'offset-decrease'
  | 'offset-increase'
  | 'narrower'
  | 'wider'
  | 'shorter'
  | 'taller'
  | 'category-next'
  | 'delete'

export const fixtureWallIds = ['front-wall', 'right-wall', 'back-wall', 'left-wall'] as const
export const fixtureCategories = ['window', 'door', 'built_in'] as const

export type FixtureEditResult = {
  model: SpatialModel
  selected: StructuralFixtureObject | null
  changed: boolean
  deleted: boolean
}

export function selectFixtureInModel(
  model: SpatialModel,
  fixtureId: string,
): SpatialModel {
  const fixture = model.structuralFixtures.find((item) => item.fixtureId === fixtureId)
  if (!fixture) {
    return model
  }
  return {
    ...model,
    selected: { objectId: fixture.fixtureId, objectType: 'fixture' },
  }
}

export function selectedFixture(model: SpatialModel): StructuralFixtureObject | null {
  if (model.selected?.objectType !== 'fixture') {
    return null
  }
  return model.structuralFixtures.find((item) => item.fixtureId === model.selected?.objectId) ?? null
}

export function selectedFixtureSummary(model: SpatialModel): string {
  const fixture = selectedFixture(model)
  if (!fixture) {
    return 'No fixture selected'
  }
  const size = fixture.size ?? { x: 0.8, y: 1, z: 0.1 }
  return `${fixture.label ?? fixture.category}; ${fixture.wallId}; ${size.x.toFixed(
    2,
  )} m wide x ${size.y.toFixed(2)} m high`
}

export function placeFixtureCandidateInModel(
  model: SpatialModel,
  candidateId: string,
): SpatialModel {
  const candidate = model.candidateObjects.find((item) => item.candidateId === candidateId)
  if (!candidate || candidate.objectType !== 'structural_fixture' || candidate.reviewState === 'rejected') {
    return model
  }

  const existing = model.structuralFixtures.find((fixture) => fixture.candidateId === candidateId)
  if (existing) {
    return {
      ...model,
      selected: { objectId: existing.fixtureId, objectType: 'fixture' },
    }
  }

  const fixture = fixtureFromCandidate({ candidate, model })
  return {
    ...model,
    hasUnsavedChanges: true,
    selected: { objectId: fixture.fixtureId, objectType: 'fixture' },
    structuralFixtures: [...model.structuralFixtures, fixture],
    candidateObjects: model.candidateObjects.map((item) =>
      item.candidateId === candidateId
        ? { ...item, reviewState: 'placed', reviewLabel: 'Placed' }
        : item,
    ),
  }
}

export function editSelectedFixtureInModel(
  model: SpatialModel,
  action: FixtureEditAction,
): FixtureEditResult {
  const selected = selectedFixture(model)
  if (!selected) {
    return { model, selected: null, changed: false, deleted: false }
  }
  if (action === 'delete') {
    return {
      model: {
        ...model,
        hasUnsavedChanges: true,
        selected: { objectId: model.room.objectId, objectType: 'room' },
        structuralFixtures: model.structuralFixtures.filter(
          (item) => item.fixtureId !== selected.fixtureId,
        ),
      },
      selected,
      changed: true,
      deleted: true,
    }
  }
  return {
    model: {
      ...model,
      hasUnsavedChanges: true,
      structuralFixtures: model.structuralFixtures.map((fixture) =>
        fixture.fixtureId === selected.fixtureId ? editFixtureObject(fixture, action) : fixture,
      ),
    },
    selected,
    changed: true,
    deleted: false,
  }
}

function fixtureFromCandidate({
  candidate,
  model,
}: {
  candidate: CandidateSceneObject
  model: SpatialModel
}): StructuralFixtureObject {
  const bounds = roomBounds(model)
  const wallId = fixtureWallIdForCandidate(candidate)
  const size = candidate.suggestedSize
    ? {
        x: Math.max(candidate.suggestedSize.x, 0.2),
        y: Math.max(candidate.suggestedSize.y, 0.2),
        z: Math.max(candidate.suggestedSize.z, 0.05),
      }
    : defaultFixtureSize(candidate.category)
  const fallbackOffset = wallId === 'right-wall' || wallId === 'left-wall'
    ? bounds.depthMeters / 2
    : bounds.widthMeters / 2
  const suggestedOffset = candidate.suggestedPosition
    ? wallId === 'right-wall' || wallId === 'left-wall'
      ? candidate.suggestedPosition.z
      : candidate.suggestedPosition.x
    : fallbackOffset

  return {
    fixtureId: `fixture-${candidate.candidateId.replace(/[^a-zA-Z0-9_-]/g, '-')}`,
    candidateId: candidate.candidateId,
    category: fixtureCategoryForCandidate(candidate.category),
    wallId,
    label: candidate.label ?? fixtureLabel(candidate.category),
    position: {
      x: Number(Math.max(0, suggestedOffset).toFixed(2)),
      y: Number(Math.max(size.y / 2, 0.5).toFixed(2)),
      z: 0,
    },
    size,
    rotationDegrees: candidate.suggestedRotationDegrees ?? fixtureRotationForWall(wallId),
    confidenceScore: candidate.confidenceScore,
    locked: false,
  }
}

function fixtureWallIdForCandidate(candidate: CandidateSceneObject): string {
  if (candidate.suggestedWallId) {
    return candidate.suggestedWallId
  }
  if (candidate.sourceImageRole === 'right_wall') {
    return 'right-wall'
  }
  if (candidate.sourceImageRole === 'back_wall') {
    return 'back-wall'
  }
  if (candidate.sourceImageRole === 'left_wall') {
    return 'left-wall'
  }
  return 'front-wall'
}

function fixtureRotationForWall(wallId: string): number {
  if (wallId === 'right-wall') return 90
  if (wallId === 'back-wall') return 180
  if (wallId === 'left-wall') return 270
  return 0
}

function fixtureCategoryForCandidate(category: string): string {
  if (category === 'window' || category === 'door' || category === 'built_in') {
    return category
  }
  return 'built_in'
}

function defaultFixtureSize(category: string): { x: number; y: number; z: number } {
  if (category === 'door') {
    return { x: 0.9, y: 2, z: 0.1 }
  }
  if (category === 'built_in') {
    return { x: 1.2, y: 1.2, z: 0.2 }
  }
  return { x: 1.1, y: 1, z: 0.1 }
}

function fixtureLabel(category: string): string {
  if (category === 'built_in') return 'Built-in'
  return category ? category[0].toUpperCase() + category.slice(1) : 'Fixture'
}

function editFixtureObject(
  fixture: StructuralFixtureObject,
  action: FixtureEditAction,
): StructuralFixtureObject {
  const size = fixture.size ?? { x: 0.8, y: 1, z: 0.1 }
  const position = fixture.position ?? { x: 0.5, y: 1, z: 0 }
  if (action === 'wall-previous' || action === 'wall-next') {
    const currentIndex = Math.max(fixtureWallIds.indexOf(fixture.wallId as (typeof fixtureWallIds)[number]), 0)
    const delta = action === 'wall-next' ? 1 : -1
    const wallId = fixtureWallIds[(currentIndex + delta + fixtureWallIds.length) % fixtureWallIds.length]
    return { ...fixture, wallId }
  }
  if (action === 'offset-decrease' || action === 'offset-increase') {
    const delta = action === 'offset-increase' ? 0.1 : -0.1
    return {
      ...fixture,
      position: { ...position, x: Number(Math.max(0, position.x + delta).toFixed(2)) },
    }
  }
  if (action === 'narrower' || action === 'wider') {
    const delta = action === 'wider' ? 0.1 : -0.1
    return {
      ...fixture,
      size: { ...size, x: Number(Math.max(0.2, size.x + delta).toFixed(2)) },
    }
  }
  if (action === 'shorter' || action === 'taller') {
    const delta = action === 'taller' ? 0.1 : -0.1
    return {
      ...fixture,
      size: { ...size, y: Number(Math.max(0.2, size.y + delta).toFixed(2)) },
    }
  }
  if (action === 'category-next') {
    const currentIndex = Math.max(
      fixtureCategories.indexOf(fixture.category as (typeof fixtureCategories)[number]),
      0,
    )
    const category = fixtureCategories[(currentIndex + 1) % fixtureCategories.length]
    return {
      ...fixture,
      category,
      label: category === 'built_in' ? 'Built-in' : category[0].toUpperCase() + category.slice(1),
    }
  }
  return fixture
}
