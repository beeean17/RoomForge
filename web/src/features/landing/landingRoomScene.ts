import * as THREE from 'three'

type MeshOptions = {
  x: number
  y: number
  z: number
  rx?: number
  ry?: number
  rz?: number
  roughness?: number
  metalness?: number
}

type PlaneOptions = {
  x?: number
  y?: number
  z?: number
  rx?: number
  ry?: number
  rz?: number
}

type PlanItem = {
  width: number
  depth: number
  height: number
  x: number
  z: number
}

type WindowRefs = {
  windowMaterial: THREE.MeshStandardMaterial
  windowGlow: THREE.PointLight
}

export type LandingRoomLighting = WindowRefs & {
  ambient: THREE.AmbientLight
  hemi: THREE.HemisphereLight
  sun: THREE.DirectionalLight
  ceiling: THREE.PointLight
  lampLeft: THREE.PointLight
  lampRight: THREE.PointLight
}

export type LandingRoomScene = {
  room: THREE.Group
  lighting: LandingRoomLighting
}

type LandingRoomBuilder = {
  scene: THREE.Scene
  room: THREE.Group
  roomWidth: number
  roomDepth: number
  roomHeight: number
  halfWidth: number
  back: number
  front: number
  box: (width: number, height: number, depth: number, color: number, position: MeshOptions) => THREE.Mesh
  cylinder: (
    radiusTop: number,
    radiusBottom: number,
    height: number,
    color: number,
    position: MeshOptions,
    radialSegments?: number,
  ) => THREE.Mesh
  plane: (width: number, height: number, color: number, options: PlaneOptions) => THREE.Mesh
}

const roomPlan = {
  width: 5.2,
  depth: 4.27,
  height: 2.8,
  wallThickness: 0.18,
}

const furniturePlan = {
  shelf: { width: 0.32, depth: 1.51, height: 2.1, x: -2.43, z: -1.38 },
  wardrobe: { width: 0.6, depth: 1.38, height: 2.25, x: -1.97, z: -1.44 },
  desk: { width: 0.77, depth: 1.77, height: 0.75, x: -2.18, z: 0.13 },
  chair: { width: 0.44, depth: 0.61, height: 0.85, x: -1.59, z: 0.12 },
  nightstandLeft: { width: 0.49, depth: 0.5, height: 0.55, x: -0.89, z: -1.73 },
  bed: { width: 1.85, depth: 2.57, height: 0.95, x: 0.33, z: -0.75 },
  nightstandRight: { width: 0.5, depth: 0.5, height: 0.55, x: 1.54, z: -1.73 },
  rug: { width: 3.05, depth: 2.64, height: 0.02, x: 0.33, z: -0.05 },
  dresser: { width: 0.55, depth: 0.92, height: 0.95, x: 2.25, z: 1.68 },
} satisfies Record<string, PlanItem>

const windowPlan = {
  x: roomPlan.width / 2,
  z: -0.3,
  length: 2.82,
  height: 1.8,
  bottom: 0.52,
  startZ: -1.71,
  endZ: 1.11,
}

const doorPlan = {
  x: -roomPlan.width / 2,
  z: 1.46,
  width: 0.76,
  height: 2.1,
  openingWidth: 0.7,
  startZ: 1.11,
  endZ: 1.81,
}

export function createLandingRoomScene(scene: THREE.Scene): LandingRoomScene {
  const room = new THREE.Group()
  scene.add(room)

  const builder: LandingRoomBuilder = {
    scene,
    room,
    roomWidth: roomPlan.width,
    roomDepth: roomPlan.depth,
    roomHeight: roomPlan.height,
    halfWidth: roomPlan.width / 2,
    back: -roomPlan.depth / 2,
    front: roomPlan.depth / 2,
    box: (width, height, depth, color, position) => {
      const mesh = new THREE.Mesh(new THREE.BoxGeometry(width, height, depth), material(color, position.roughness, position.metalness))
      mesh.position.set(position.x, position.y, position.z)
      mesh.rotation.set(position.rx ?? 0, position.ry ?? 0, position.rz ?? 0)
      room.add(mesh)
      return mesh
    },
    cylinder: (radiusTop, radiusBottom, height, color, position, radialSegments = 28) => {
      const mesh = new THREE.Mesh(new THREE.CylinderGeometry(radiusTop, radiusBottom, height, radialSegments), material(color, position.roughness, position.metalness))
      mesh.position.set(position.x, position.y, position.z)
      mesh.rotation.set(position.rx ?? 0, position.ry ?? 0, position.rz ?? 0)
      room.add(mesh)
      return mesh
    },
    plane: (width, height, color, options) => {
      const mesh = new THREE.Mesh(
        new THREE.PlaneGeometry(width, height),
        new THREE.MeshStandardMaterial({
          color,
          roughness: 0.64,
          metalness: 0.02,
          side: THREE.DoubleSide,
        }),
      )
      mesh.position.set(options.x ?? 0, options.y ?? 0, options.z ?? 0)
      mesh.rotation.set(options.rx ?? 0, options.ry ?? 0, options.rz ?? 0)
      room.add(mesh)
      return mesh
    },
  }

  createFloor(builder)
  createRoomShell(builder)
  createAreaRug(builder, furniturePlan.rug)
  createBed(builder, furniturePlan.bed)
  createNightstand(builder, furniturePlan.nightstandLeft)
  createNightstand(builder, furniturePlan.nightstandRight)
  createShelf(builder, furniturePlan.shelf)
  createWardrobe(builder, furniturePlan.wardrobe)
  createDesk(builder, furniturePlan.desk)
  createChair(builder, furniturePlan.chair)
  const windowRefs = createWindowWall(builder)
  createDresser(builder, furniturePlan.dresser)
  createDoor(builder)

  return {
    room,
    lighting: createLighting(builder, windowRefs),
  }
}

function material(color: number, roughness = 0.68, metalness = 0.02) {
  return new THREE.MeshStandardMaterial({ color, roughness, metalness })
}

function createFloor({ room, roomWidth, roomDepth, back, front, box, plane }: LandingRoomBuilder) {
  plane(roomWidth, roomDepth, 0xe4d8c8, { rx: -Math.PI / 2, y: 0 })

  const plankCount = 8
  for (let index = 0; index <= plankCount; index += 1) {
    const z = back + (roomDepth / plankCount) * index
    box(roomWidth - roomPlan.wallThickness * 2.4, 0.012, 0.012, 0xcbbfae, { x: 0, y: 0.024, z, roughness: 0.9 })
  }
  for (let index = 0; index < 7; index += 1) {
    box(0.012, 0.012, 0.48, 0xd8ccbc, { x: -2.1 + index * 0.7, y: 0.026, z: back + 0.62, roughness: 0.92 })
    box(0.012, 0.012, 0.48, 0xd8ccbc, { x: -1.88 + index * 0.7, y: 0.026, z: -0.04, roughness: 0.92 })
    box(0.012, 0.012, 0.48, 0xd8ccbc, { x: -2.24 + index * 0.7, y: 0.026, z: front - 0.58, roughness: 0.92 })
  }

  const floorGrid = new THREE.GridHelper(roomDepth, 10, 0xf1e9dd, 0xc5b9aa)
  floorGrid.position.y = 0.018
  floorGrid.scale.x = roomWidth / roomDepth
  const gridMaterial = floorGrid.material as THREE.Material
  gridMaterial.transparent = true
  gridMaterial.opacity = 0.14
  gridMaterial.depthWrite = false
  room.add(floorGrid)
}

function createRoomShell({ roomWidth, roomDepth, roomHeight, halfWidth, back, front, box, plane }: LandingRoomBuilder) {
  plane(roomWidth, roomHeight, 0xd7d0c8, { z: back, y: roomHeight / 2 })
  plane(roomDepth, roomHeight, 0xc7c1bb, { ry: Math.PI / 2, x: -halfWidth, y: roomHeight / 2 })
  plane(roomDepth, roomHeight, 0xd4d0ca, { ry: -Math.PI / 2, x: halfWidth, y: roomHeight / 2 })
  plane(roomWidth, roomHeight, 0xd0cac3, { z: front, y: roomHeight / 2 })
  box(roomWidth, 0.16, 0.12, 0x202124, { x: 0, y: 0.08, z: back + 0.03 })
  box(roomWidth, 0.16, 0.12, 0x202124, { x: 0, y: 0.08, z: front - 0.03 })
  box(roomWidth, 0.12, 0.14, 0x202124, { x: 0, y: roomHeight - 0.06, z: back + 0.03 })
  box(roomWidth, 0.12, 0.14, 0x202124, { x: 0, y: roomHeight - 0.06, z: front - 0.03 })
  box(0.12, 0.16, roomDepth, 0x202124, { x: -halfWidth + 0.04, y: 0.08, z: 0 })
  box(0.12, 0.16, roomDepth, 0x202124, { x: halfWidth - 0.04, y: 0.08, z: 0 })
}

function createAreaRug({ box }: LandingRoomBuilder, rug: PlanItem) {
  box(rug.width, rug.height, rug.depth, 0xbeb3a6, { x: rug.x, y: rug.height / 2 + 0.012, z: rug.z, roughness: 1 })
  box(rug.width - 0.08, 0.01, rug.depth - 0.08, 0xd1c8bb, { x: rug.x, y: rug.height + 0.018, z: rug.z, roughness: 1 })
}

function createBed({ box }: LandingRoomBuilder, bed: PlanItem) {
  const backEdge = bed.z - bed.depth / 2
  box(bed.width, 0.64, 0.09, 0x303238, { x: bed.x, y: 0.58, z: backEdge + 0.08, roughness: 0.86 })
  for (let index = 0; index < 4; index += 1) {
    box(0.014, 0.48, 0.024, 0x4b4d54, { x: bed.x - 0.66 + index * 0.44, y: 0.64, z: backEdge + 0.03 })
  }
  box(bed.width, 0.3, bed.depth, 0x25262b, { x: bed.x, y: 0.18, z: bed.z, roughness: 0.78 })
  box(bed.width - 0.14, 0.22, bed.depth - 0.24, 0xe5ded7, { x: bed.x, y: 0.43, z: bed.z + 0.02, roughness: 0.96 })
  box(bed.width - 0.18, 0.2, bed.depth * 0.52, 0x34353a, { x: bed.x, y: 0.62, z: bed.z + 0.44, roughness: 0.92 })
  box(bed.width - 0.24, 0.16, bed.depth * 0.26, 0x8f8b84, { x: bed.x, y: 0.74, z: bed.z + 0.95, roughness: 0.9 })
  box(0.68, 0.14, 0.38, 0xded8d0, { x: bed.x - 0.42, y: 0.72, z: backEdge + 0.45, rz: -0.03, roughness: 0.98 })
  box(0.68, 0.14, 0.38, 0xded8d0, { x: bed.x + 0.42, y: 0.72, z: backEdge + 0.45, rz: 0.03, roughness: 0.98 })
  box(0.54, 0.11, 0.36, 0x4a4b50, { x: bed.x - 0.34, y: 0.84, z: backEdge + 0.68, rz: 0.04, roughness: 0.95 })
  box(0.54, 0.11, 0.36, 0x4a4b50, { x: bed.x + 0.34, y: 0.84, z: backEdge + 0.68, rz: -0.04, roughness: 0.95 })
  box(0.42, 0.09, 0.24, 0xe8e1d8, { x: bed.x, y: 0.94, z: backEdge + 0.94, roughness: 0.98 })
}

function createNightstand({ box, cylinder }: LandingRoomBuilder, stand: PlanItem) {
  box(stand.width, stand.height - 0.08, stand.depth, 0x252528, { x: stand.x, y: (stand.height - 0.08) / 2, z: stand.z, roughness: 0.8 })
  box(stand.width - 0.04, 0.04, stand.depth - 0.06, 0x171719, { x: stand.x, y: stand.height, z: stand.z, roughness: 0.72 })
  box(0.34, 0.016, 0.04, 0x686a70, { x: stand.x, y: 0.34, z: stand.z - stand.depth / 2 + 0.06, roughness: 0.5, metalness: 0.35 })
  cylinder(0.12, 0.12, 0.04, 0xf1f0e6, { x: stand.x - 0.1, y: 0.65, z: stand.z - 0.08, roughness: 0.58 }, 32)
  cylinder(0.055, 0.075, 0.3, 0x1a1a1d, { x: stand.x - 0.1, y: 0.81, z: stand.z - 0.08, roughness: 0.55 }, 24)
  createNightstandPlant({ x: stand.x + 0.16, y: 0.66, z: stand.z + 0.12 }, { box, cylinder })
}

function createShelf({ box, cylinder }: LandingRoomBuilder, shelf: PlanItem) {
  box(shelf.width, shelf.height, shelf.depth, 0x1d1e20, { x: shelf.x, y: shelf.height / 2, z: shelf.z, roughness: 0.78 })
  for (let level = 0; level < 6; level += 1) {
    box(shelf.width - 0.04, 0.035, shelf.depth - 0.08, 0x303135, { x: shelf.x + 0.01, y: 0.22 + level * 0.34, z: shelf.z, roughness: 0.8 })
  }
  for (const [column, x] of [shelf.x - 0.04, shelf.x + 0.04].entries()) {
    for (let item = 0; item < 6; item += 1) {
      box(0.055, 0.16 + (item % 2) * 0.07, 0.07, column ? 0xded8ce : 0x5f626a, { x, y: 0.38 + item * 0.24, z: shelf.z - 0.55 + (item % 3) * 0.28, roughness: 0.86 })
    }
  }
  cylinder(0.05, 0.07, 0.18, 0x6c7449, { x: shelf.x + 0.04, y: shelf.height - 0.14, z: shelf.z - 0.58, roughness: 0.9 }, 10)
}

function createWardrobe({ box }: LandingRoomBuilder, wardrobe: PlanItem) {
  box(wardrobe.width, wardrobe.height, wardrobe.depth, 0x232426, { x: wardrobe.x, y: wardrobe.height / 2, z: wardrobe.z, roughness: 0.78 })
  box(0.018, wardrobe.height - 0.18, wardrobe.depth - 0.1, 0x111113, { x: wardrobe.x + wardrobe.width / 2 - 0.04, y: wardrobe.height / 2, z: wardrobe.z, roughness: 0.72 })
  box(0.02, 0.42, 0.05, 0xb7b2aa, { x: wardrobe.x + wardrobe.width / 2 - 0.02, y: wardrobe.height / 2, z: wardrobe.z - 0.25, roughness: 0.4, metalness: 0.45 })
  box(0.02, 0.42, 0.05, 0xb7b2aa, { x: wardrobe.x + wardrobe.width / 2 - 0.02, y: wardrobe.height / 2, z: wardrobe.z + 0.25, roughness: 0.4, metalness: 0.45 })
}

function createDesk({ box, cylinder, plane }: LandingRoomBuilder, desk: PlanItem) {
  box(desk.width, 0.12, desk.depth, 0x242527, { x: desk.x, y: desk.height, z: desk.z, roughness: 0.75 })
  box(desk.width - 0.08, desk.height - 0.16, 0.18, 0x202124, { x: desk.x, y: (desk.height - 0.16) / 2, z: desk.z - desk.depth / 2 + 0.14, roughness: 0.78 })
  box(desk.width - 0.08, desk.height - 0.16, 0.18, 0x202124, { x: desk.x, y: (desk.height - 0.16) / 2, z: desk.z + desk.depth / 2 - 0.14, roughness: 0.78 })
  plane(0.54, 0.34, 0x1c2631, { x: desk.x + desk.width / 2 + 0.08, y: 1.08, z: desk.z, ry: Math.PI / 2 })
  box(0.04, 0.4, 0.58, 0x0f1011, { x: desk.x + desk.width / 2 + 0.06, y: 1.08, z: desk.z, roughness: 0.55 })
  box(0.22, 0.04, 0.22, 0x202124, { x: desk.x + 0.1, y: 0.78, z: desk.z, roughness: 0.7 })
  box(0.38, 0.025, 0.16, 0xe2dfd7, { x: desk.x + 0.1, y: 0.8, z: desk.z + 0.42, roughness: 0.92 })
  cylinder(0.04, 0.04, 0.46, 0x18191b, { x: desk.x + 0.2, y: 1.0, z: desk.z + 0.72, rx: Math.PI / 2, roughness: 0.6 }, 16)
  cylinder(0.1, 0.08, 0.15, 0xf0eee6, { x: desk.x + 0.23, y: 1.16, z: desk.z + 0.72, rz: Math.PI / 2, roughness: 0.65 }, 24)
}

function createChair({ box, cylinder }: LandingRoomBuilder, chair: PlanItem) {
  box(chair.width, 0.14, chair.depth * 0.72, 0x25262a, { x: chair.x, y: 0.42, z: chair.z, roughness: 0.72 })
  box(0.08, chair.height * 0.55, chair.depth * 0.68, 0x1d1f23, { x: chair.x + chair.width / 2 - 0.03, y: 0.68, z: chair.z, roughness: 0.72 })
  cylinder(0.04, 0.04, 0.5, 0x111113, { x: chair.x, y: 0.24, z: chair.z, roughness: 0.55 }, 14)
  for (let spoke = 0; spoke < 5; spoke += 1) {
    box(0.32, 0.032, 0.032, 0x17181a, { x: chair.x + Math.sin(spoke * 1.26) * 0.13, y: 0.14, z: chair.z + Math.cos(spoke * 1.26) * 0.13, ry: spoke * 1.26, roughness: 0.62 })
    cylinder(0.035, 0.035, 0.032, 0x111113, { x: chair.x + Math.sin(spoke * 1.26) * 0.28, y: 0.08, z: chair.z + Math.cos(spoke * 1.26) * 0.28, rx: Math.PI / 2, roughness: 0.5 }, 12)
  }
}

function createWindowWall({ scene, box, plane }: LandingRoomBuilder): WindowRefs {
  const windowY = windowPlan.bottom + windowPlan.height / 2
  const wallX = windowPlan.x
  const windowMesh = plane(windowPlan.length, windowPlan.height, 0xe6f0f5, {
    ry: -Math.PI / 2,
    x: wallX - 0.055,
    y: windowY,
    z: windowPlan.z,
  })
  const windowMaterial = windowMesh.material as THREE.MeshStandardMaterial
  windowMaterial.emissive = new THREE.Color(0xeaf2fb)
  windowMaterial.emissiveIntensity = 0.95
  const windowGlow = new THREE.PointLight(0xd9f1ff, 1.15, 6)
  windowGlow.position.set(wallX - 0.52, windowY, windowPlan.z)
  scene.add(windowGlow)

  box(0.06, windowPlan.height + 0.16, 0.08, 0x151617, { x: wallX - 0.08, y: windowY, z: windowPlan.startZ, roughness: 0.55 })
  box(0.06, windowPlan.height + 0.16, 0.08, 0x151617, { x: wallX - 0.08, y: windowY, z: windowPlan.endZ, roughness: 0.55 })
  box(0.06, 0.08, windowPlan.length + 0.08, 0x151617, { x: wallX - 0.08, y: windowPlan.bottom + windowPlan.height + 0.02, z: windowPlan.z, roughness: 0.55 })
  box(0.06, 0.08, windowPlan.length + 0.08, 0x151617, { x: wallX - 0.08, y: windowPlan.bottom - 0.02, z: windowPlan.z, roughness: 0.55 })
  for (let blind = 0; blind < 7; blind += 1) {
    box(0.05, 0.08, windowPlan.length - 0.18, 0xf0eee8, { x: wallX - 0.18, y: windowPlan.bottom + 0.2 + blind * 0.24, z: windowPlan.z, roughness: 0.86 })
  }

  return { windowMaterial, windowGlow }
}

function createDresser({ box, cylinder }: LandingRoomBuilder, dresser: PlanItem) {
  box(dresser.width, dresser.height - 0.04, dresser.depth, 0x242527, { x: dresser.x, y: (dresser.height - 0.04) / 2, z: dresser.z, roughness: 0.78 })
  box(dresser.width - 0.05, 0.04, dresser.depth - 0.06, 0x171819, { x: dresser.x, y: dresser.height, z: dresser.z, roughness: 0.66 })
  createDresserPlant({ x: dresser.x - 0.12, y: dresser.height + 0.08, z: dresser.z - 0.16 }, { box, cylinder })
  box(0.26, 0.05, 0.2, 0xd8d2ca, { x: dresser.x + 0.13, y: dresser.height + 0.08, z: dresser.z + 0.16, ry: -0.2, roughness: 0.8 })
  box(0.13, 0.2, 0.04, 0x9c948a, { x: dresser.x + 0.15, y: dresser.height + 0.2, z: dresser.z + 0.25, ry: -0.2, roughness: 0.84 })
}

function createDoor({ box, cylinder }: LandingRoomBuilder) {
  const wallX = doorPlan.x
  box(0.08, doorPlan.height + 0.06, 0.035, 0x151617, { x: wallX + 0.055, y: doorPlan.height / 2, z: doorPlan.startZ, roughness: 0.58 })
  box(0.08, doorPlan.height + 0.06, 0.035, 0x151617, { x: wallX + 0.055, y: doorPlan.height / 2, z: doorPlan.endZ, roughness: 0.58 })
  box(0.08, 0.06, doorPlan.openingWidth + 0.06, 0x151617, { x: wallX + 0.055, y: doorPlan.height + 0.03, z: doorPlan.z, roughness: 0.58 })
  box(0.08, 0.035, doorPlan.openingWidth, 0x1c1d1f, { x: wallX + 0.06, y: 0.025, z: doorPlan.z, roughness: 0.66 })
  box(0.05, doorPlan.height, doorPlan.width, 0xe5e0d6, { x: wallX + 0.44, y: doorPlan.height / 2, z: doorPlan.z, ry: -0.72, roughness: 0.82 })
  box(0.05, 0.16, doorPlan.width, 0x242527, { x: wallX + 0.34, y: doorPlan.height + 0.02, z: doorPlan.z + 0.1, ry: -0.72, roughness: 0.62 })
  cylinder(0.035, 0.035, 0.06, 0xc7b88e, { x: wallX + 0.68, y: 1.02, z: doorPlan.z - 0.22, rz: Math.PI / 2, roughness: 0.35, metalness: 0.45 }, 16)
}

function createNightstandPlant(
  position: { x: number; y: number; z: number },
  primitives: Pick<LandingRoomBuilder, 'box' | 'cylinder'>,
) {
  primitives.cylinder(0.03, 0.03, 0.24, 0x3d3f28, { ...position, roughness: 0.8 }, 10)
  for (let leaf = 0; leaf < 5; leaf += 1) {
    primitives.box(0.04, 0.08, 0.02, 0x5f7040, {
      x: position.x + Math.sin(leaf) * 0.07,
      y: position.y + 0.14 + leaf * 0.014,
      z: position.z + Math.cos(leaf) * 0.06,
      rz: leaf * 0.42,
      roughness: 0.9,
    })
  }
}

function createDresserPlant(
  position: { x: number; y: number; z: number },
  primitives: Pick<LandingRoomBuilder, 'box' | 'cylinder'>,
) {
  primitives.cylinder(0.07, 0.09, 0.16, 0x657148, { ...position, roughness: 0.88 }, 10)
  for (let leaf = 0; leaf < 7; leaf += 1) {
    primitives.box(0.032, 0.09, 0.02, 0x5b6c3f, {
      x: position.x + Math.sin(leaf * 0.9) * 0.1,
      y: position.y + 0.09 + leaf * 0.011,
      z: position.z + Math.cos(leaf * 0.9) * 0.09,
      rz: leaf * 0.34,
      roughness: 0.92,
    })
  }
}

function createLighting({ scene }: LandingRoomBuilder, windowRefs: WindowRefs): LandingRoomLighting {
  const ambient = new THREE.AmbientLight(0xffffff, 0.34)
  scene.add(ambient)
  const hemi = new THREE.HemisphereLight(0xffffff, 0x6a5f54, 0.9)
  scene.add(hemi)
  const sun = new THREE.DirectionalLight(0xfff4e2, 1.25)
  sun.position.set(6, 4.5, -1)
  scene.add(sun)
  const ceiling = new THREE.PointLight(0xffffff, 0.82, 12)
  ceiling.position.set(0, 2.6, 0.1)
  scene.add(ceiling)
  const lampLeft = new THREE.PointLight(0xffd49a, 0.72, 4)
  lampLeft.position.set(furniturePlan.nightstandLeft.x - 0.1, 0.86, furniturePlan.nightstandLeft.z - 0.08)
  scene.add(lampLeft)
  const lampRight = new THREE.PointLight(0xffd49a, 0.72, 4)
  lampRight.position.set(furniturePlan.nightstandRight.x - 0.1, 0.86, furniturePlan.nightstandRight.z - 0.08)
  scene.add(lampRight)

  return {
    ...windowRefs,
    ambient,
    hemi,
    sun,
    ceiling,
    lampLeft,
    lampRight,
  }
}
