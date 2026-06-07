import type { FurnitureCategory, MeterPoint3d } from './spatialModel.ts'

export type FurnitureSize = {
  widthMeters: number
  depthMeters: number
  heightMeters: number
}

export type FurnitureSizePrior = {
  category: FurnitureCategory
  label: string
  size: FurnitureSize
  suggestedSize: MeterPoint3d
  assetId: string
  color: string
}

export type StructuralFixtureSizePrior = {
  category: 'window' | 'door' | 'built_in'
  label: string
  size: MeterPoint3d
  assetId: string
}

const furnitureSizePriors: Record<FurnitureCategory, FurnitureSizePrior> = {
  bed: {
    category: 'bed',
    label: 'Bed',
    size: { widthMeters: 1.5, depthMeters: 2, heightMeters: 0.55 },
    suggestedSize: { x: 1.5, y: 0.55, z: 2 },
    assetId: 'bed.double',
    color: '#6f7f8f',
  },
  desk: {
    category: 'desk',
    label: 'Desk',
    size: { widthMeters: 1.2, depthMeters: 0.65, heightMeters: 0.75 },
    suggestedSize: { x: 1.2, y: 0.75, z: 0.65 },
    assetId: 'desk.standard',
    color: '#7f6f8f',
  },
  chair: {
    category: 'chair',
    label: 'Chair',
    size: { widthMeters: 0.55, depthMeters: 0.55, heightMeters: 0.85 },
    suggestedSize: { x: 0.55, y: 0.85, z: 0.55 },
    assetId: 'chair.desk',
    color: '#64748b',
  },
  wardrobe: {
    category: 'wardrobe',
    label: 'Wardrobe',
    size: { widthMeters: 1, depthMeters: 0.6, heightMeters: 2 },
    suggestedSize: { x: 1, y: 2, z: 0.6 },
    assetId: 'wardrobe.standard',
    color: '#64748b',
  },
  sofa: {
    category: 'sofa',
    label: 'Sofa',
    size: { widthMeters: 1.8, depthMeters: 0.85, heightMeters: 0.82 },
    suggestedSize: { x: 1.8, y: 0.82, z: 0.85 },
    assetId: 'sofa.two-seat',
    color: '#8b6f61',
  },
  table: {
    category: 'table',
    label: 'Table',
    size: { widthMeters: 1.2, depthMeters: 0.75, heightMeters: 0.74 },
    suggestedSize: { x: 1.2, y: 0.74, z: 0.75 },
    assetId: 'table.dining',
    color: '#7f8f6f',
  },
  shelf: {
    category: 'shelf',
    label: 'Shelf',
    size: { widthMeters: 0.9, depthMeters: 0.35, heightMeters: 1.6 },
    suggestedSize: { x: 0.9, y: 1.6, z: 0.35 },
    assetId: 'shelf.standard',
    color: '#5f7f7a',
  },
  cabinet: {
    category: 'cabinet',
    label: 'Cabinet',
    size: { widthMeters: 0.9, depthMeters: 0.45, heightMeters: 0.9 },
    suggestedSize: { x: 0.9, y: 0.9, z: 0.45 },
    assetId: 'cabinet.standard',
    color: '#7a6f61',
  },
  custom: {
    category: 'custom',
    label: 'Custom',
    size: { widthMeters: 0.8, depthMeters: 0.8, heightMeters: 0.8 },
    suggestedSize: { x: 0.8, y: 0.8, z: 0.8 },
    assetId: 'custom.proxy',
    color: '#64748b',
  },
}

const structuralFixtureSizePriors: Record<
  StructuralFixtureSizePrior['category'],
  StructuralFixtureSizePrior
> = {
  window: {
    category: 'window',
    label: 'Window',
    size: { x: 1.1, y: 0.9, z: 0.1 },
    assetId: 'fixture.window.standard',
  },
  door: {
    category: 'door',
    label: 'Door',
    size: { x: 0.85, y: 2.05, z: 0.1 },
    assetId: 'fixture.door.standard',
  },
  built_in: {
    category: 'built_in',
    label: 'Built-in',
    size: { x: 0.8, y: 1, z: 0.1 },
    assetId: 'fixture.built_in.proxy',
  },
}

export function furnitureSizePriorForCategory(category: string): FurnitureSizePrior {
  return cloneFurniturePrior(furnitureSizePriors[furnitureCategoryForValue(category)])
}

export function furnitureCategoryForValue(category: string): FurnitureCategory {
  return isFurnitureCategoryValue(category) ? category : 'custom'
}

export function isFurnitureCategoryValue(category: string): category is FurnitureCategory {
  return Object.hasOwn(furnitureSizePriors, category)
}

export function structuralFixtureSizePriorForCategory(
  category: string,
): StructuralFixtureSizePrior {
  return cloneFixturePrior(
    isStructuralFixturePriorCategory(category)
      ? structuralFixtureSizePriors[category]
      : structuralFixtureSizePriors.built_in,
  )
}

function isStructuralFixturePriorCategory(
  category: string,
): category is StructuralFixtureSizePrior['category'] {
  return Object.hasOwn(structuralFixtureSizePriors, category)
}

function cloneFurniturePrior(prior: FurnitureSizePrior): FurnitureSizePrior {
  return {
    ...prior,
    size: { ...prior.size },
    suggestedSize: { ...prior.suggestedSize },
  }
}

function cloneFixturePrior(prior: StructuralFixtureSizePrior): StructuralFixtureSizePrior {
  return {
    ...prior,
    size: { ...prior.size },
  }
}
