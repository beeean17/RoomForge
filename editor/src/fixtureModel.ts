import type { SpatialModel, StructuralFixtureObject } from './spatialModel'

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
