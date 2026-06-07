export type ConfirmationHandoffItem = {
  objectId: string
  objectType: 'furniture' | 'structural_fixture'
  category: string
  label: string
  sourceLabel: string
  selected: boolean
  confirmed: boolean
}

export type ConfirmedObjectItem = {
  objectId: string
  objectType: string
  category: string
  label: string
  confirmedAtLabel: string
}

export type ConfirmationHandoffState = {
  placedItems: ConfirmationHandoffItem[]
  confirmedItems: ConfirmedObjectItem[]
  selectedItem: ConfirmationHandoffItem | null
  counts: {
    placed: number
    confirmed: number
    unconfirmed: number
    selectedConfirmed: number
  }
  canConfirmSelected: boolean
  canConfirmAll: boolean
}

export function confirmationHandoffStateFromPayload(payload: Record<string, unknown>): ConfirmationHandoffState | null {
  const source = confirmationPayloadSource(payload)
  if (!('furniture' in source) && !('structuralFixtures' in source) && !('confirmedObjects' in source)) {
    return null
  }

  const selected = recordValue(source.selected)
  const confirmedItems = listValue(source.confirmedObjects)
    .map((item) => confirmedObjectItemFromRecord(recordValue(item)))
    .filter((item): item is ConfirmedObjectItem => item !== null)
  const confirmedIds = new Set(confirmedItems.map((item) => item.objectId))
  const placedItems = [
    ...listValue(source.furniture)
      .map((item) => handoffFurnitureItemFromRecord({
        item: recordValue(item),
        selected,
        confirmedIds,
      }))
      .filter((item): item is ConfirmationHandoffItem => item !== null),
    ...listValue(source.structuralFixtures)
      .map((item) => handoffFixtureItemFromRecord({
        item: recordValue(item),
        selected,
        confirmedIds,
      }))
      .filter((item): item is ConfirmationHandoffItem => item !== null),
  ]
  const selectedItem = placedItems.find((item) => item.selected) ?? null
  const unconfirmed = placedItems.filter((item) => !item.confirmed).length

  return {
    placedItems,
    confirmedItems,
    selectedItem,
    counts: {
      placed: placedItems.length,
      confirmed: confirmedItems.length,
      unconfirmed,
      selectedConfirmed: selectedItem?.confirmed ? 1 : 0,
    },
    canConfirmSelected: selectedItem !== null && !selectedItem.confirmed,
    canConfirmAll: unconfirmed > 0,
  }
}

function confirmationPayloadSource(payload: Record<string, unknown>): Record<string, unknown> {
  const scene = recordValue(payload.scene)
  if ('furniture' in scene || 'structuralFixtures' in scene || 'confirmedObjects' in scene) {
    return scene
  }
  const spatialModel = recordValue(payload.spatialModel)
  if ('furniture' in spatialModel || 'structuralFixtures' in spatialModel || 'confirmedObjects' in spatialModel) {
    return spatialModel
  }
  return payload
}

function handoffFurnitureItemFromRecord({
  item,
  selected,
  confirmedIds,
}: {
  item: Record<string, unknown>
  selected: Record<string, unknown>
  confirmedIds: Set<string>
}): ConfirmationHandoffItem | null {
  const objectId = stringValue(item.objectId)
  if (!objectId) {
    return null
  }
  return {
    objectId,
    objectType: 'furniture',
    category: stringValue(item.category) ?? 'custom',
    label: stringValue(item.label) ?? stringValue(item.category) ?? 'Furniture',
    sourceLabel: stringValue(item.candidateId) ? 'CV candidate' : 'Catalog',
    selected: selected.objectType === 'furniture' && selected.objectId === objectId,
    confirmed: confirmedIds.has(objectId),
  }
}

function handoffFixtureItemFromRecord({
  item,
  selected,
  confirmedIds,
}: {
  item: Record<string, unknown>
  selected: Record<string, unknown>
  confirmedIds: Set<string>
}): ConfirmationHandoffItem | null {
  const fixtureId = stringValue(item.fixtureId)
  if (!fixtureId) {
    return null
  }
  return {
    objectId: fixtureId,
    objectType: 'structural_fixture',
    category: stringValue(item.category) ?? 'fixture',
    label: stringValue(item.label) ?? stringValue(item.category) ?? 'Fixture',
    sourceLabel: stringValue(item.candidateId) ? 'CV candidate' : 'Manual fixture',
    selected: selected.objectType === 'fixture' && selected.objectId === fixtureId,
    confirmed: confirmedIds.has(fixtureId),
  }
}

function confirmedObjectItemFromRecord(item: Record<string, unknown>): ConfirmedObjectItem | null {
  const objectId = stringValue(item.objectId)
  if (!objectId) {
    return null
  }
  const objectType = stringValue(item.objectType) ?? 'object'
  const category = stringValue(item.category) ?? 'custom'
  return {
    objectId,
    objectType,
    category,
    label: stringValue(item.label) ?? `${objectType}: ${category}`,
    confirmedAtLabel: stringValue(item.confirmedAt) ?? 'confirmed',
  }
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

