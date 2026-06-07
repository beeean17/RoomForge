import * as THREE from 'three'

export type RoomObjectAssetCategory =
  | 'bed'
  | 'desk'
  | 'chair'
  | 'wardrobe'
  | 'dresser'
  | 'drawer'
  | 'cabinet'
  | 'shelf'
  | 'table'
  | 'sofa'
  | 'window'
  | 'door'
  | 'custom'

export type RoomObjectAssetObjectType = 'furniture' | 'structural_fixture' | 'proxy'

export type RoomObjectAssetDimensions = {
  x: number
  y: number
  z: number
}

export type RoomObjectAssetMetadata = {
  readonly assetId: string
  readonly category: RoomObjectAssetCategory
  readonly objectType: RoomObjectAssetObjectType
  readonly label: string
  readonly defaultDimensions: RoomObjectAssetDimensions
  readonly color: string
  readonly aliases: readonly string[]
}

export const roomObjectAssetCatalog = [
  {
    assetId: 'bed.double',
    category: 'bed',
    objectType: 'furniture',
    label: 'Double bed',
    defaultDimensions: { x: 1.5, y: 0.55, z: 2 },
    color: '#6f7f8f',
    aliases: ['bed', 'double_bed', 'queen_bed'],
  },
  {
    assetId: 'desk.standard',
    category: 'desk',
    objectType: 'furniture',
    label: 'Desk',
    defaultDimensions: { x: 1.2, y: 0.75, z: 0.65 },
    color: '#7f6f8f',
    aliases: ['desk', 'work_desk', 'office_desk'],
  },
  {
    assetId: 'chair.desk',
    category: 'chair',
    objectType: 'furniture',
    label: 'Desk chair',
    defaultDimensions: { x: 0.55, y: 0.85, z: 0.55 },
    color: '#64748b',
    aliases: ['chair', 'desk_chair', 'office_chair'],
  },
  {
    assetId: 'wardrobe.standard',
    category: 'wardrobe',
    objectType: 'furniture',
    label: 'Wardrobe',
    defaultDimensions: { x: 1, y: 2, z: 0.6 },
    color: '#64748b',
    aliases: ['wardrobe', 'closet'],
  },
  {
    assetId: 'dresser.standard',
    category: 'dresser',
    objectType: 'furniture',
    label: 'Dresser',
    defaultDimensions: { x: 1.05, y: 0.85, z: 0.48 },
    color: '#7a6f61',
    aliases: ['dresser', 'chest_of_drawers', 'drawers'],
  },
  {
    assetId: 'drawer.nightstand',
    category: 'drawer',
    objectType: 'furniture',
    label: 'Nightstand',
    defaultDimensions: { x: 0.48, y: 0.58, z: 0.4 },
    color: '#8a735f',
    aliases: ['drawer', 'nightstand', 'bedside_table', 'side_table'],
  },
  {
    assetId: 'cabinet.standard',
    category: 'cabinet',
    objectType: 'furniture',
    label: 'Cabinet',
    defaultDimensions: { x: 0.9, y: 0.9, z: 0.45 },
    color: '#7a6f61',
    aliases: ['cabinet', 'cupboard'],
  },
  {
    assetId: 'shelf.standard',
    category: 'shelf',
    objectType: 'furniture',
    label: 'Shelf',
    defaultDimensions: { x: 0.9, y: 1.6, z: 0.35 },
    color: '#5f7f7a',
    aliases: ['shelf', 'bookcase', 'bookshelf'],
  },
  {
    assetId: 'table.dining',
    category: 'table',
    objectType: 'furniture',
    label: 'Table',
    defaultDimensions: { x: 1.2, y: 0.74, z: 0.75 },
    color: '#7f8f6f',
    aliases: ['table', 'dining_table'],
  },
  {
    assetId: 'sofa.two-seat',
    category: 'sofa',
    objectType: 'furniture',
    label: 'Two-seat sofa',
    defaultDimensions: { x: 1.8, y: 0.82, z: 0.85 },
    color: '#8b6f61',
    aliases: ['sofa', 'couch', 'loveseat'],
  },
  {
    assetId: 'fixture.window.standard',
    category: 'window',
    objectType: 'structural_fixture',
    label: 'Window',
    defaultDimensions: { x: 1.1, y: 0.9, z: 0.1 },
    color: '#7aa7c7',
    aliases: ['window', 'glass_window'],
  },
  {
    assetId: 'fixture.door.standard',
    category: 'door',
    objectType: 'structural_fixture',
    label: 'Door',
    defaultDimensions: { x: 0.85, y: 2.05, z: 0.1 },
    color: '#a4774f',
    aliases: ['door', 'interior_door'],
  },
  {
    assetId: 'custom.proxy',
    category: 'custom',
    objectType: 'proxy',
    label: 'Custom proxy',
    defaultDimensions: { x: 0.8, y: 0.8, z: 0.8 },
    color: '#64748b',
    aliases: ['custom', 'proxy', 'unknown', 'object'],
  },
] as const satisfies readonly RoomObjectAssetMetadata[]

export type RoomObjectAssetId = (typeof roomObjectAssetCatalog)[number]['assetId']

export type RoomObjectAssetBuildOptions = {
  assetId?: string | null
  category?: string | null
  dimensions?: Partial<RoomObjectAssetDimensions>
}

type RoomObjectAssetBuilder = (
  group: THREE.Group,
  dimensions: RoomObjectAssetDimensions,
  metadata: RoomObjectAssetMetadata,
) => void

const minimumDimensionMeters = 0.05
const fallbackRoomObjectAsset = roomObjectAssetCatalog.find(
  (asset) => asset.assetId === 'custom.proxy',
) ?? roomObjectAssetCatalog[roomObjectAssetCatalog.length - 1]

const assetById = new Map<string, RoomObjectAssetMetadata>()
const assetByCategory = new Map<string, RoomObjectAssetMetadata>()
const assetByAlias = new Map<string, RoomObjectAssetMetadata>()

for (const asset of roomObjectAssetCatalog) {
  assetById.set(lookupKey(asset.assetId), asset)
  assetByCategory.set(lookupKey(asset.category), asset)
  for (const alias of asset.aliases) {
    assetByAlias.set(lookupKey(alias), asset)
  }
}

const roomObjectAssetBuilders: Record<RoomObjectAssetCategory, RoomObjectAssetBuilder> = {
  bed: buildBedAsset,
  desk: buildDeskAsset,
  chair: buildChairAsset,
  wardrobe: buildWardrobeAsset,
  dresser: buildDresserAsset,
  drawer: buildNightstandAsset,
  cabinet: buildCabinetAsset,
  shelf: buildShelfAsset,
  table: buildTableAsset,
  sofa: buildSofaAsset,
  window: buildWindowAsset,
  door: buildDoorAsset,
  custom: buildCustomProxyAsset,
}

export function findRoomObjectAssetById(
  assetId: string | null | undefined,
): RoomObjectAssetMetadata | undefined {
  const key = lookupKey(assetId)
  if (!key) {
    return undefined
  }
  return assetById.get(key) ?? assetByAlias.get(key)
}

export function roomObjectAssetForId(assetId: string | null | undefined): RoomObjectAssetMetadata {
  return findRoomObjectAssetById(assetId) ?? fallbackRoomObjectAsset
}

export function findRoomObjectAssetByCategory(
  category: string | null | undefined,
): RoomObjectAssetMetadata | undefined {
  const key = lookupKey(category)
  if (!key) {
    return undefined
  }
  return assetByCategory.get(key) ?? assetByAlias.get(key)
}

export function roomObjectAssetForCategory(
  category: string | null | undefined,
): RoomObjectAssetMetadata {
  return findRoomObjectAssetByCategory(category) ?? fallbackRoomObjectAsset
}

export function resolveRoomObjectAsset({
  assetId,
  category,
}: {
  assetId?: string | null
  category?: string | null
}): RoomObjectAssetMetadata {
  return (
    findRoomObjectAssetById(assetId) ??
    findRoomObjectAssetByCategory(category) ??
    fallbackRoomObjectAsset
  )
}

export function normalizeRoomObjectAssetDimensions(
  dimensions: Partial<RoomObjectAssetDimensions> | null | undefined,
  fallback: RoomObjectAssetDimensions = fallbackRoomObjectAsset.defaultDimensions,
): RoomObjectAssetDimensions {
  return {
    x: positiveDimension(dimensions?.x, fallback.x),
    y: positiveDimension(dimensions?.y, fallback.y),
    z: positiveDimension(dimensions?.z, fallback.z),
  }
}

export function buildRoomObjectAsset(
  assetId: string,
  dimensions?: Partial<RoomObjectAssetDimensions>,
): THREE.Group {
  return buildRoomObjectAssetFromMetadata(roomObjectAssetForId(assetId), dimensions)
}

export function buildRoomObjectAssetForCategory(
  category: string,
  dimensions?: Partial<RoomObjectAssetDimensions>,
): THREE.Group {
  return buildRoomObjectAssetFromMetadata(roomObjectAssetForCategory(category), dimensions)
}

export function createRoomObjectAssetGroup(options: RoomObjectAssetBuildOptions): THREE.Group {
  return buildRoomObjectAssetFromMetadata(resolveRoomObjectAsset(options), options.dimensions)
}

export function buildRoomObjectAssetFromMetadata(
  metadata: RoomObjectAssetMetadata,
  dimensions?: Partial<RoomObjectAssetDimensions>,
): THREE.Group {
  const normalizedDimensions = normalizeRoomObjectAssetDimensions(
    dimensions,
    metadata.defaultDimensions,
  )
  const group = new THREE.Group()
  group.name = metadata.assetId
  group.userData = {
    roomForgeAssetId: metadata.assetId,
    roomForgeCategory: metadata.category,
    roomForgeObjectType: metadata.objectType,
    dimensionsMeters: { ...normalizedDimensions },
  }

  roomObjectAssetBuilders[metadata.category](group, normalizedDimensions, metadata)
  return group
}

function buildBedAsset(
  group: THREE.Group,
  dimensions: RoomObjectAssetDimensions,
  metadata: RoomObjectAssetMetadata,
): void {
  const frameHeight = Math.max(0.05, dimensions.y * 0.18)
  const mattressHeight = Math.max(0.08, dimensions.y * 0.45)
  const headDepth = Math.min(dimensions.z * 0.14, 0.18)
  const mattressDepth = Math.max(minimumDimensionMeters, dimensions.z - headDepth)
  const pillowHeight = Math.min(0.12, Math.max(0.04, dimensions.y * 0.2))
  const pillowWidth = dimensions.x >= 1 ? dimensions.x * 0.36 : dimensions.x * 0.62
  const pillowY = Math.min(
    dimensions.y - pillowHeight / 2,
    frameHeight + mattressHeight + pillowHeight / 2,
  )

  addBox(
    group,
    'bed.frame',
    { x: dimensions.x, y: frameHeight, z: dimensions.z },
    { x: 0, y: frameHeight / 2, z: 0 },
    '#3f4852',
  )
  addBox(
    group,
    'bed.mattress',
    { x: dimensions.x * 0.94, y: mattressHeight, z: mattressDepth * 0.94 },
    {
      x: 0,
      y: frameHeight + mattressHeight / 2,
      z: -dimensions.z / 2 + headDepth + mattressDepth / 2,
    },
    '#f2efe8',
  )
  addBox(
    group,
    'bed.headboard',
    { x: dimensions.x, y: dimensions.y, z: headDepth },
    { x: 0, y: dimensions.y / 2, z: -dimensions.z / 2 + headDepth / 2 },
    metadata.color,
  )

  const pillowZ = -dimensions.z / 2 + headDepth + mattressDepth * 0.18
  if (dimensions.x >= 1) {
    addBox(
      group,
      'bed.left-pillow',
      { x: pillowWidth, y: pillowHeight, z: mattressDepth * 0.22 },
      { x: -dimensions.x * 0.23, y: pillowY, z: pillowZ },
      '#f8f6f1',
    )
    addBox(
      group,
      'bed.right-pillow',
      { x: pillowWidth, y: pillowHeight, z: mattressDepth * 0.22 },
      { x: dimensions.x * 0.23, y: pillowY, z: pillowZ },
      '#f8f6f1',
    )
  } else {
    addBox(
      group,
      'bed.pillow',
      { x: pillowWidth, y: pillowHeight, z: mattressDepth * 0.22 },
      { x: 0, y: pillowY, z: pillowZ },
      '#f8f6f1',
    )
  }
}

function buildDeskAsset(
  group: THREE.Group,
  dimensions: RoomObjectAssetDimensions,
  metadata: RoomObjectAssetMetadata,
): void {
  const topThickness = Math.min(Math.max(0.05, dimensions.y * 0.08), dimensions.y * 0.22)
  const legHeight = Math.max(minimumDimensionMeters, dimensions.y - topThickness)
  const legWidth = Math.max(0.035, Math.min(dimensions.x, dimensions.z) * 0.08)

  addBox(
    group,
    'desk.top',
    { x: dimensions.x, y: topThickness, z: dimensions.z },
    { x: 0, y: legHeight + topThickness / 2, z: 0 },
    metadata.color,
  )
  addFourLegs(group, 'desk', dimensions, {
    color: '#4b5563',
    height: legHeight,
    insetX: dimensions.x * 0.14,
    insetZ: dimensions.z * 0.16,
    width: legWidth,
  })
  addBox(
    group,
    'desk.modesty-panel',
    { x: dimensions.x * 0.72, y: legHeight * 0.42, z: legWidth },
    { x: 0, y: legHeight * 0.58, z: -dimensions.z / 2 + legWidth / 2 },
    '#5d5169',
  )
}

function buildChairAsset(
  group: THREE.Group,
  dimensions: RoomObjectAssetDimensions,
  metadata: RoomObjectAssetMetadata,
): void {
  const seatHeight = Math.min(0.1, Math.max(0.05, dimensions.y * 0.12))
  const legHeight = Math.max(0.18, dimensions.y * 0.42)
  const legWidth = Math.max(0.035, Math.min(dimensions.x, dimensions.z) * 0.1)
  const backThickness = Math.max(0.04, dimensions.z * 0.12)
  const backHeight = Math.max(0.16, dimensions.y - legHeight)

  addBox(
    group,
    'chair.seat',
    { x: dimensions.x * 0.86, y: seatHeight, z: dimensions.z * 0.76 },
    { x: 0, y: legHeight + seatHeight / 2, z: dimensions.z * 0.06 },
    metadata.color,
  )
  addBox(
    group,
    'chair.back',
    { x: dimensions.x * 0.88, y: backHeight, z: backThickness },
    {
      x: 0,
      y: legHeight + backHeight / 2,
      z: -dimensions.z / 2 + backThickness / 2,
    },
    '#46566d',
  )
  addFourLegs(group, 'chair', dimensions, {
    color: '#374151',
    height: legHeight,
    insetX: dimensions.x * 0.2,
    insetZ: dimensions.z * 0.22,
    width: legWidth,
  })
}

function buildWardrobeAsset(
  group: THREE.Group,
  dimensions: RoomObjectAssetDimensions,
  metadata: RoomObjectAssetMetadata,
): void {
  const panelDepth = Math.max(0.018, dimensions.z * 0.03)
  const frontZ = dimensions.z / 2 + panelDepth / 2
  const handleHeight = Math.max(0.18, dimensions.y * 0.22)

  addBox(
    group,
    'wardrobe.body',
    dimensions,
    { x: 0, y: dimensions.y / 2, z: 0 },
    metadata.color,
  )
  addBox(
    group,
    'wardrobe.left-door',
    { x: dimensions.x * 0.47, y: dimensions.y * 0.92, z: panelDepth },
    { x: -dimensions.x * 0.24, y: dimensions.y * 0.5, z: frontZ },
    '#728197',
  )
  addBox(
    group,
    'wardrobe.right-door',
    { x: dimensions.x * 0.47, y: dimensions.y * 0.92, z: panelDepth },
    { x: dimensions.x * 0.24, y: dimensions.y * 0.5, z: frontZ },
    '#728197',
  )
  addBox(
    group,
    'wardrobe.left-handle',
    { x: 0.025, y: handleHeight, z: panelDepth },
    { x: -dimensions.x * 0.05, y: dimensions.y * 0.55, z: frontZ + panelDepth },
    '#d8c596',
  )
  addBox(
    group,
    'wardrobe.right-handle',
    { x: 0.025, y: handleHeight, z: panelDepth },
    { x: dimensions.x * 0.05, y: dimensions.y * 0.55, z: frontZ + panelDepth },
    '#d8c596',
  )
}

function buildDresserAsset(
  group: THREE.Group,
  dimensions: RoomObjectAssetDimensions,
  metadata: RoomObjectAssetMetadata,
): void {
  const panelDepth = Math.max(0.018, dimensions.z * 0.04)
  const drawerHeight = dimensions.y * 0.23
  const firstDrawerY = dimensions.y * 0.24

  addBox(
    group,
    'dresser.body',
    dimensions,
    { x: 0, y: dimensions.y / 2, z: 0 },
    metadata.color,
  )
  addBox(
    group,
    'dresser.top',
    { x: dimensions.x * 1.04, y: dimensions.y * 0.06, z: dimensions.z * 1.04 },
    { x: 0, y: dimensions.y * 0.97, z: 0 },
    '#8a7a68',
  )

  for (let row = 0; row < 3; row += 1) {
    const y = firstDrawerY + row * dimensions.y * 0.26
    addBox(
      group,
      `dresser.drawer-${row + 1}`,
      { x: dimensions.x * 0.86, y: drawerHeight, z: panelDepth },
      { x: 0, y, z: dimensions.z / 2 + panelDepth / 2 },
      '#8d806f',
    )
    addBox(
      group,
      `dresser.handle-${row + 1}`,
      { x: dimensions.x * 0.2, y: Math.max(0.025, drawerHeight * 0.12), z: panelDepth },
      { x: 0, y, z: dimensions.z / 2 + panelDepth * 1.5 },
      '#d8c596',
    )
  }
}

function buildNightstandAsset(
  group: THREE.Group,
  dimensions: RoomObjectAssetDimensions,
  metadata: RoomObjectAssetMetadata,
): void {
  const panelDepth = Math.max(0.015, dimensions.z * 0.04)
  const drawerHeight = dimensions.y * 0.28

  addBox(
    group,
    'nightstand.body',
    dimensions,
    { x: 0, y: dimensions.y / 2, z: 0 },
    metadata.color,
  )
  addBox(
    group,
    'nightstand.top',
    { x: dimensions.x * 1.06, y: dimensions.y * 0.07, z: dimensions.z * 1.06 },
    { x: 0, y: dimensions.y * 0.965, z: 0 },
    '#9b816b',
  )

  for (let row = 0; row < 2; row += 1) {
    const y = dimensions.y * (0.34 + row * 0.32)
    addBox(
      group,
      `nightstand.drawer-${row + 1}`,
      { x: dimensions.x * 0.82, y: drawerHeight, z: panelDepth },
      { x: 0, y, z: dimensions.z / 2 + panelDepth / 2 },
      '#967a63',
    )
    addBox(
      group,
      `nightstand.handle-${row + 1}`,
      { x: dimensions.x * 0.24, y: Math.max(0.02, drawerHeight * 0.12), z: panelDepth },
      { x: 0, y, z: dimensions.z / 2 + panelDepth * 1.5 },
      '#d8c596',
    )
  }
}

function buildCabinetAsset(
  group: THREE.Group,
  dimensions: RoomObjectAssetDimensions,
  metadata: RoomObjectAssetMetadata,
): void {
  const panelDepth = Math.max(0.018, dimensions.z * 0.04)

  addBox(
    group,
    'cabinet.body',
    dimensions,
    { x: 0, y: dimensions.y / 2, z: 0 },
    metadata.color,
  )
  addBox(
    group,
    'cabinet.left-door',
    { x: dimensions.x * 0.42, y: dimensions.y * 0.72, z: panelDepth },
    { x: -dimensions.x * 0.22, y: dimensions.y * 0.48, z: dimensions.z / 2 + panelDepth / 2 },
    '#867761',
  )
  addBox(
    group,
    'cabinet.right-door',
    { x: dimensions.x * 0.42, y: dimensions.y * 0.72, z: panelDepth },
    { x: dimensions.x * 0.22, y: dimensions.y * 0.48, z: dimensions.z / 2 + panelDepth / 2 },
    '#867761',
  )
  addBox(
    group,
    'cabinet.left-handle',
    { x: 0.025, y: dimensions.y * 0.22, z: panelDepth },
    { x: -dimensions.x * 0.06, y: dimensions.y * 0.5, z: dimensions.z / 2 + panelDepth * 1.5 },
    '#d8c596',
  )
  addBox(
    group,
    'cabinet.right-handle',
    { x: 0.025, y: dimensions.y * 0.22, z: panelDepth },
    { x: dimensions.x * 0.06, y: dimensions.y * 0.5, z: dimensions.z / 2 + panelDepth * 1.5 },
    '#d8c596',
  )
}

function buildShelfAsset(
  group: THREE.Group,
  dimensions: RoomObjectAssetDimensions,
  metadata: RoomObjectAssetMetadata,
): void {
  const boardThickness = Math.min(0.08, Math.max(0.035, dimensions.y * 0.045))
  const sideWidth = Math.min(0.08, Math.max(0.04, dimensions.x * 0.07))
  const shelfDepth = dimensions.z

  addBox(
    group,
    'shelf.left-side',
    { x: sideWidth, y: dimensions.y, z: shelfDepth },
    { x: -dimensions.x / 2 + sideWidth / 2, y: dimensions.y / 2, z: 0 },
    metadata.color,
  )
  addBox(
    group,
    'shelf.right-side',
    { x: sideWidth, y: dimensions.y, z: shelfDepth },
    { x: dimensions.x / 2 - sideWidth / 2, y: dimensions.y / 2, z: 0 },
    metadata.color,
  )
  addBox(
    group,
    'shelf.back',
    { x: dimensions.x, y: dimensions.y, z: Math.max(0.025, dimensions.z * 0.08) },
    { x: 0, y: dimensions.y / 2, z: -dimensions.z / 2 },
    '#4f6f6a',
    0.72,
  )

  for (let index = 0; index < 4; index += 1) {
    const y = index === 0
      ? boardThickness / 2
      : Math.min(dimensions.y - boardThickness / 2, (dimensions.y / 3) * index)
    addBox(
      group,
      `shelf.board-${index + 1}`,
      { x: dimensions.x, y: boardThickness, z: shelfDepth },
      { x: 0, y, z: 0 },
      metadata.color,
    )
  }
}

function buildTableAsset(
  group: THREE.Group,
  dimensions: RoomObjectAssetDimensions,
  metadata: RoomObjectAssetMetadata,
): void {
  const topThickness = Math.min(Math.max(0.05, dimensions.y * 0.08), dimensions.y * 0.24)
  const legHeight = Math.max(minimumDimensionMeters, dimensions.y - topThickness)
  const legWidth = Math.max(0.04, Math.min(dimensions.x, dimensions.z) * 0.08)

  addBox(
    group,
    'table.top',
    { x: dimensions.x, y: topThickness, z: dimensions.z },
    { x: 0, y: legHeight + topThickness / 2, z: 0 },
    metadata.color,
  )
  addFourLegs(group, 'table', dimensions, {
    color: '#566044',
    height: legHeight,
    insetX: dimensions.x * 0.16,
    insetZ: dimensions.z * 0.16,
    width: legWidth,
  })
}

function buildSofaAsset(
  group: THREE.Group,
  dimensions: RoomObjectAssetDimensions,
  metadata: RoomObjectAssetMetadata,
): void {
  const armWidth = Math.max(0.08, dimensions.x * 0.08)
  const seatHeight = Math.max(0.12, dimensions.y * 0.28)
  const backHeight = Math.max(0.18, dimensions.y * 0.68)
  const backDepth = Math.max(0.08, dimensions.z * 0.16)
  const cushionWidth = Math.max(0.1, (dimensions.x - armWidth * 2) / 2)

  addBox(
    group,
    'sofa.seat-base',
    { x: dimensions.x, y: seatHeight, z: dimensions.z * 0.72 },
    { x: 0, y: seatHeight / 2, z: dimensions.z * 0.12 },
    metadata.color,
  )
  addBox(
    group,
    'sofa.back',
    { x: dimensions.x, y: backHeight, z: backDepth },
    { x: 0, y: backHeight / 2, z: -dimensions.z / 2 + backDepth / 2 },
    '#74594f',
  )
  addBox(
    group,
    'sofa.left-arm',
    { x: armWidth, y: dimensions.y * 0.72, z: dimensions.z },
    { x: -dimensions.x / 2 + armWidth / 2, y: dimensions.y * 0.36, z: 0 },
    '#74594f',
  )
  addBox(
    group,
    'sofa.right-arm',
    { x: armWidth, y: dimensions.y * 0.72, z: dimensions.z },
    { x: dimensions.x / 2 - armWidth / 2, y: dimensions.y * 0.36, z: 0 },
    '#74594f',
  )
  addBox(
    group,
    'sofa.left-cushion',
    { x: cushionWidth * 0.92, y: seatHeight * 0.35, z: dimensions.z * 0.5 },
    { x: -cushionWidth / 2, y: seatHeight * 1.1, z: dimensions.z * 0.12 },
    '#a28578',
  )
  addBox(
    group,
    'sofa.right-cushion',
    { x: cushionWidth * 0.92, y: seatHeight * 0.35, z: dimensions.z * 0.5 },
    { x: cushionWidth / 2, y: seatHeight * 1.1, z: dimensions.z * 0.12 },
    '#a28578',
  )
}

function buildWindowAsset(
  group: THREE.Group,
  dimensions: RoomObjectAssetDimensions,
  metadata: RoomObjectAssetMetadata,
): void {
  const frame = Math.min(0.08, Math.max(0.035, Math.min(dimensions.x, dimensions.y) * 0.08))
  const paneDepth = Math.max(0.012, dimensions.z * 0.35)

  addBox(
    group,
    'window.pane',
    {
      x: Math.max(minimumDimensionMeters, dimensions.x - frame * 2),
      y: Math.max(minimumDimensionMeters, dimensions.y - frame * 2),
      z: paneDepth,
    },
    { x: 0, y: dimensions.y / 2, z: 0 },
    '#9fc8df',
    0.38,
  )
  addBox(
    group,
    'window.top-frame',
    { x: dimensions.x, y: frame, z: dimensions.z },
    { x: 0, y: dimensions.y - frame / 2, z: 0 },
    metadata.color,
  )
  addBox(
    group,
    'window.bottom-frame',
    { x: dimensions.x, y: frame, z: dimensions.z },
    { x: 0, y: frame / 2, z: 0 },
    metadata.color,
  )
  addBox(
    group,
    'window.left-frame',
    { x: frame, y: dimensions.y, z: dimensions.z },
    { x: -dimensions.x / 2 + frame / 2, y: dimensions.y / 2, z: 0 },
    metadata.color,
  )
  addBox(
    group,
    'window.right-frame',
    { x: frame, y: dimensions.y, z: dimensions.z },
    { x: dimensions.x / 2 - frame / 2, y: dimensions.y / 2, z: 0 },
    metadata.color,
  )
  addBox(
    group,
    'window.center-mullion',
    { x: frame * 0.7, y: dimensions.y - frame * 2, z: dimensions.z },
    { x: 0, y: dimensions.y / 2, z: 0 },
    metadata.color,
  )
  addBox(
    group,
    'window.crossbar',
    { x: dimensions.x - frame * 2, y: frame * 0.7, z: dimensions.z },
    { x: 0, y: dimensions.y * 0.52, z: 0 },
    metadata.color,
  )
}

function buildDoorAsset(
  group: THREE.Group,
  dimensions: RoomObjectAssetDimensions,
  metadata: RoomObjectAssetMetadata,
): void {
  const panelDepth = Math.max(0.018, dimensions.z * 0.32)
  const knobRadius = Math.min(0.06, Math.max(0.025, dimensions.x * 0.06))

  addBox(
    group,
    'door.slab',
    { x: dimensions.x * 0.9, y: dimensions.y, z: panelDepth },
    { x: 0, y: dimensions.y / 2, z: 0 },
    metadata.color,
  )
  addBox(
    group,
    'door.inner-panel-top',
    { x: dimensions.x * 0.58, y: dimensions.y * 0.24, z: panelDepth },
    { x: 0, y: dimensions.y * 0.68, z: panelDepth },
    '#b3845c',
  )
  addBox(
    group,
    'door.inner-panel-bottom',
    { x: dimensions.x * 0.58, y: dimensions.y * 0.32, z: panelDepth },
    { x: 0, y: dimensions.y * 0.32, z: panelDepth },
    '#b3845c',
  )
  addSphere(
    group,
    'door.knob',
    knobRadius,
    { x: dimensions.x * 0.3, y: dimensions.y * 0.52, z: dimensions.z / 2 + knobRadius / 2 },
    '#d8c596',
  )
}

function buildCustomProxyAsset(
  group: THREE.Group,
  dimensions: RoomObjectAssetDimensions,
  metadata: RoomObjectAssetMetadata,
): void {
  const capHeight = Math.max(0.035, dimensions.y * 0.08)

  addBox(
    group,
    'proxy.body',
    dimensions,
    { x: 0, y: dimensions.y / 2, z: 0 },
    metadata.color,
    0.42,
  )
  addBox(
    group,
    'proxy.top-marker',
    { x: dimensions.x * 0.62, y: capHeight, z: dimensions.z * 0.62 },
    { x: 0, y: dimensions.y - capHeight / 2, z: 0 },
    '#9aa7b8',
  )
  addBox(
    group,
    'proxy.front-marker',
    { x: dimensions.x * 0.42, y: dimensions.y * 0.08, z: Math.max(0.018, dimensions.z * 0.04) },
    { x: 0, y: dimensions.y * 0.55, z: dimensions.z / 2 },
    '#d6a75b',
  )
}

function addFourLegs(
  group: THREE.Group,
  prefix: string,
  dimensions: RoomObjectAssetDimensions,
  options: {
    color: string
    height: number
    insetX: number
    insetZ: number
    width: number
  },
): void {
  const xOffset = Math.max(0, dimensions.x / 2 - options.insetX)
  const zOffset = Math.max(0, dimensions.z / 2 - options.insetZ)
  const legSize = {
    x: options.width,
    y: options.height,
    z: options.width,
  }
  const y = options.height / 2

  addBox(group, `${prefix}.front-left-leg`, legSize, { x: -xOffset, y, z: zOffset }, options.color)
  addBox(group, `${prefix}.front-right-leg`, legSize, { x: xOffset, y, z: zOffset }, options.color)
  addBox(group, `${prefix}.back-left-leg`, legSize, { x: -xOffset, y, z: -zOffset }, options.color)
  addBox(group, `${prefix}.back-right-leg`, legSize, { x: xOffset, y, z: -zOffset }, options.color)
}

function addBox(
  group: THREE.Group,
  name: string,
  size: RoomObjectAssetDimensions,
  center: RoomObjectAssetDimensions,
  color: string,
  opacity = 1,
): THREE.Mesh {
  const geometry = new THREE.BoxGeometry(
    positiveDimension(size.x, minimumDimensionMeters),
    positiveDimension(size.y, minimumDimensionMeters),
    positiveDimension(size.z, minimumDimensionMeters),
  )
  const mesh = new THREE.Mesh(geometry, materialFor(color, opacity))
  mesh.name = name
  mesh.position.set(center.x, center.y, center.z)
  group.add(mesh)
  return mesh
}

function addSphere(
  group: THREE.Group,
  name: string,
  radius: number,
  center: RoomObjectAssetDimensions,
  color: string,
): THREE.Mesh {
  const geometry = new THREE.SphereGeometry(positiveDimension(radius, 0.025), 10, 8)
  const mesh = new THREE.Mesh(geometry, materialFor(color))
  mesh.name = name
  mesh.position.set(center.x, center.y, center.z)
  group.add(mesh)
  return mesh
}

function materialFor(color: string, opacity = 1): THREE.MeshBasicMaterial {
  return new THREE.MeshBasicMaterial({
    color: new THREE.Color(color),
    transparent: opacity < 1,
    opacity,
    depthWrite: opacity >= 1,
  })
}

function positiveDimension(value: number | undefined, fallback: number): number {
  if (typeof value !== 'number' || !Number.isFinite(value) || value <= 0) {
    return Math.max(minimumDimensionMeters, fallback)
  }
  return Math.max(minimumDimensionMeters, value)
}

function lookupKey(value: string | null | undefined): string {
  return typeof value === 'string' ? value.trim().toLowerCase() : ''
}
