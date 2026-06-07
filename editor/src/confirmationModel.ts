import type {
  ConfirmedSceneObject,
  FurnitureObject,
  SpatialModel,
  StructuralFixtureObject,
} from './spatialModel'

export type ConfirmationResult = {
  model: SpatialModel
  changed: boolean
  confirmedCount: number
}

export function confirmSelectedObjectInModel({
  model,
  confirmedByUid,
}: {
  model: SpatialModel
  confirmedByUid?: string
}): ConfirmationResult {
  if (model.selected?.objectType === 'furniture') {
    const item = model.furniture.find((candidate) => candidate.objectId === model.selected?.objectId)
    return item
      ? confirmObjectsInModel({ model, objects: [confirmedFurnitureObject(model, item, confirmedByUid)] })
      : unchanged(model)
  }

  if (model.selected?.objectType === 'fixture') {
    const fixture = model.structuralFixtures.find((candidate) => candidate.fixtureId === model.selected?.objectId)
    return fixture
      ? confirmObjectsInModel({ model, objects: [confirmedFixtureObject(fixture, confirmedByUid)] })
      : unchanged(model)
  }

  return unchanged(model)
}

export function confirmAllPlacedObjectsInModel({
  model,
  confirmedByUid,
}: {
  model: SpatialModel
  confirmedByUid?: string
}): ConfirmationResult {
  const objects = [
    ...model.furniture.map((item) => confirmedFurnitureObject(model, item, confirmedByUid)),
    ...model.structuralFixtures.map((fixture) => confirmedFixtureObject(fixture, confirmedByUid)),
  ]
  return confirmObjectsInModel({ model, objects })
}

function confirmObjectsInModel({
  model,
  objects,
}: {
  model: SpatialModel
  objects: ConfirmedSceneObject[]
}): ConfirmationResult {
  if (objects.length === 0) {
    return unchanged(model)
  }

  const nextObjects = [...model.confirmedObjects]
  let changed = false
  for (const object of objects) {
    const index = nextObjects.findIndex((candidate) => candidate.objectId === object.objectId)
    if (index >= 0) {
      nextObjects[index] = object
    } else {
      nextObjects.push(object)
    }
    changed = true
  }

  return {
    model: {
      ...model,
      hasUnsavedChanges: changed ? true : model.hasUnsavedChanges,
      confirmedObjects: nextObjects,
    },
    changed,
    confirmedCount: objects.length,
  }
}

function confirmedFurnitureObject(
  model: SpatialModel,
  item: FurnitureObject,
  confirmedByUid?: string,
): ConfirmedSceneObject {
  const placed = model.placedObjects.find((object) =>
    object.objectId === item.objectId ||
    (item.candidateId !== undefined && object.candidateId === item.candidateId),
  )
  return withConfirmationMetadata({
    objectId: item.objectId,
    candidateId: item.candidateId,
    objectType: 'furniture',
    category: item.category,
    assetId: placed?.assetId,
    label: item.label,
    position: { x: item.position.x, y: 0, z: item.position.y },
    size: {
      x: item.size.widthMeters,
      y: item.size.heightMeters,
      z: item.size.depthMeters,
    },
    rotationDegrees: item.rotationDegrees,
    confidenceScore: placed?.confidenceScore,
    locked: item.locked ?? false,
  }, confirmedByUid)
}

function confirmedFixtureObject(
  fixture: StructuralFixtureObject,
  confirmedByUid?: string,
): ConfirmedSceneObject {
  return withConfirmationMetadata({
    objectId: fixture.fixtureId,
    candidateId: fixture.candidateId,
    objectType: 'structural_fixture',
    category: fixture.category,
    label: fixture.label,
    position: fixture.position,
    size: fixture.size,
    rotationDegrees: fixture.rotationDegrees,
    confidenceScore: fixture.confidenceScore,
    locked: fixture.locked,
  }, confirmedByUid)
}

function withConfirmationMetadata(
  object: Omit<ConfirmedSceneObject, 'confirmedAt' | 'confirmedByUid'>,
  confirmedByUid?: string,
): ConfirmedSceneObject {
  return {
    ...object,
    confirmedByUid,
    confirmedAt: new Date().toISOString(),
  }
}

function unchanged(model: SpatialModel): ConfirmationResult {
  return { model, changed: false, confirmedCount: 0 }
}

