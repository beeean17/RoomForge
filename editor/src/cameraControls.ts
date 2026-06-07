import * as THREE from 'three'

export type CameraAction = 'reset' | 'fit' | 'top' | 'front' | 'corner' | 'eye'

export type CameraSnapshot = {
  position: THREE.Vector3
  target: THREE.Vector3
  up: THREE.Vector3
  label: string
}

export type CameraSnapshotLabels = Record<CameraAction, string>

export type CameraRoomBounds = {
  widthMeters: number
  depthMeters: number
}

export function cameraSnapshotForRoom({
  action,
  bounds,
  roomHeightMeters,
  fovDegrees,
  labels,
}: {
  action: CameraAction
  bounds: CameraRoomBounds
  roomHeightMeters: number
  fovDegrees: number
  labels: CameraSnapshotLabels
}): CameraSnapshot {
  const maxDimension = Math.max(bounds.widthMeters, bounds.depthMeters, 1)
  const height = Math.max(roomHeightMeters, 2.4)
  const fitDistance = maxDimension / (2 * Math.tan(THREE.MathUtils.degToRad(fovDegrees / 2)))
  const target = new THREE.Vector3(0, height * 0.38, 0)

  if (action === 'top') {
    return {
      position: new THREE.Vector3(0, fitDistance * 1.35, 0.001),
      target: new THREE.Vector3(0, 0, 0),
      up: new THREE.Vector3(0, 0, -1),
      label: labels.top,
    }
  }

  if (action === 'front') {
    return {
      position: new THREE.Vector3(0, height * 0.55, maxDimension * 1.45),
      target,
      up: new THREE.Vector3(0, 1, 0),
      label: labels.front,
    }
  }

  if (action === 'eye') {
    return {
      position: new THREE.Vector3(0, 1.6, maxDimension * 0.95),
      target: new THREE.Vector3(0, 1.35, 0),
      up: new THREE.Vector3(0, 1, 0),
      label: labels.eye,
    }
  }

  const multiplier = action === 'fit' ? 0.78 : 0.95
  return {
    position: new THREE.Vector3(
      maxDimension * multiplier,
      Math.max(height * 0.72, maxDimension * 0.55),
      maxDimension * multiplier,
    ),
    target,
    up: new THREE.Vector3(0, 1, 0),
    label: labels[action],
  }
}

export function shouldAnimateCamera({
  reducedMotion,
  animate,
}: {
  reducedMotion: boolean
  animate: boolean
}): boolean {
  return animate && !reducedMotion
}

export function isCameraAction(value: string | undefined): value is CameraAction {
  return (
    value === 'reset' ||
    value === 'fit' ||
    value === 'top' ||
    value === 'front' ||
    value === 'corner' ||
    value === 'eye'
  )
}
