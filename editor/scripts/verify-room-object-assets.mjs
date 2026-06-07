import assert from 'node:assert/strict'

import * as THREE from 'three'

import {
  buildRoomObjectAsset,
  createRoomObjectAssetGroup,
  resolveRoomObjectAsset,
  roomObjectAssetCatalog,
  roomObjectAssetForCategory,
  roomObjectAssetForId,
} from '../src/roomObjectAssets.ts'

const requiredAssetIds = [
  'bed.double',
  'desk.standard',
  'chair.desk',
  'wardrobe.standard',
  'dresser.standard',
  'drawer.nightstand',
  'cabinet.standard',
  'shelf.standard',
  'table.dining',
  'sofa.two-seat',
  'fixture.window.standard',
  'fixture.door.standard',
  'custom.proxy',
]

assert.equal(roomObjectAssetCatalog.length, requiredAssetIds.length)
assert.deepEqual(
  roomObjectAssetCatalog.map((asset) => asset.assetId),
  requiredAssetIds,
)

assert.equal(roomObjectAssetForId('bed.double').category, 'bed')
assert.equal(roomObjectAssetForId('fixture.window.standard').category, 'window')
assert.equal(roomObjectAssetForCategory('nightstand').assetId, 'drawer.nightstand')
assert.equal(roomObjectAssetForCategory('chest_of_drawers').assetId, 'dresser.standard')
assert.equal(resolveRoomObjectAsset({ assetId: 'missing.asset', category: 'door' }).assetId, 'fixture.door.standard')
assert.equal(resolveRoomObjectAsset({ category: 'unknown_detector_label' }).assetId, 'custom.proxy')

for (const asset of roomObjectAssetCatalog) {
  assert.ok(asset.defaultDimensions.x > 0)
  assert.ok(asset.defaultDimensions.y > 0)
  assert.ok(asset.defaultDimensions.z > 0)

  const group = buildRoomObjectAsset(asset.assetId, asset.defaultDimensions)
  assert.ok(group instanceof THREE.Group)
  assert.equal(group.name, asset.assetId)
  assert.equal(group.userData.roomForgeAssetId, asset.assetId)
  assert.deepEqual(group.userData.dimensionsMeters, asset.defaultDimensions)

  let meshCount = 0
  group.traverse((object) => {
    if (object instanceof THREE.Mesh) {
      meshCount += 1
      assert.ok(object.geometry)
      assert.ok(object.material)
      object.geometry.computeBoundingBox()
      assert.ok(object.geometry.boundingBox)
    }
  })
  assert.ok(meshCount >= 2, `${asset.assetId} should include recognizable mesh parts`)
  disposeObject(group)
}

const categoryGroup = createRoomObjectAssetGroup({
  category: 'desk',
  dimensions: { x: 1.4, y: 0.8, z: 0.7 },
})
assert.equal(categoryGroup.userData.roomForgeAssetId, 'desk.standard')
assert.deepEqual(categoryGroup.userData.dimensionsMeters, { x: 1.4, y: 0.8, z: 0.7 })
disposeObject(categoryGroup)

const clampedGroup = buildRoomObjectAsset('custom.proxy', { x: -1, y: 0, z: Number.NaN })
assert.deepEqual(clampedGroup.userData.dimensionsMeters, { x: 0.8, y: 0.8, z: 0.8 })
disposeObject(clampedGroup)

console.log('Room object asset catalog contract verified')

function disposeObject(object) {
  object.traverse((child) => {
    if (child instanceof THREE.Mesh) {
      child.geometry.dispose()
      if (Array.isArray(child.material)) {
        child.material.forEach((material) => material.dispose())
      } else {
        child.material.dispose()
      }
    }
  })
}
