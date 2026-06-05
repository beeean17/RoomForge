import { useEffect, useRef, useState } from 'react'
import * as THREE from 'three'

type LandingThreeViewerProps = {
  orbitProgress: number
  yaw: number
  pitch: number
}

export function LandingThreeViewer({ orbitProgress, yaw, pitch }: LandingThreeViewerProps) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null)
  const stateRef = useRef({ orbitProgress, yaw, pitch })
  const renderSceneRef = useRef<() => void>(() => undefined)
  const [isWebGlUnavailable, setIsWebGlUnavailable] = useState(false)

  stateRef.current = { orbitProgress, yaw, pitch }

  useEffect(() => {
    const canvas = canvasRef.current
    const host = canvas?.parentElement
    if (!canvas || !host) {
      return undefined
    }
    const hostElement = host

    let renderer: THREE.WebGLRenderer
    try {
      renderer = new THREE.WebGLRenderer({ canvas, alpha: false, antialias: true })
    } catch {
      setIsWebGlUnavailable(true)
      return undefined
    }
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2))
    renderer.setClearColor(0x101114, 1)
    renderer.outputColorSpace = THREE.SRGBColorSpace
    renderer.toneMapping = THREE.ACESFilmicToneMapping
    renderer.toneMappingExposure = 1.35

    const scene = new THREE.Scene()

    const camera = new THREE.PerspectiveCamera(42, 1, 0.1, 80)
    const cameraTarget = new THREE.Vector3()
    const entryPosition = new THREE.Vector3(0, 1.42, 2.78)
    const centerPosition = new THREE.Vector3(0, 1.38, 0.7)
    const entryTarget = new THREE.Vector3(0, 1.08, -1.15)
    const orbitAnchor = new THREE.Vector3(0, 1.32, 0.7)
    const orbitTarget = new THREE.Vector3()
    const lookDirection = new THREE.Vector3()
    const room = new THREE.Group()
    scene.add(room)

    const roomWidth = 5.2
    const roomDepth = 6.0
    const roomHeight = 2.8
    const halfWidth = roomWidth / 2
    const back = -roomDepth / 2
    const front = roomDepth / 2

    function material(color: number, roughness = 0.68, metalness = 0.02) {
      return new THREE.MeshStandardMaterial({ color, roughness, metalness })
    }

    function box(
      width: number,
      height: number,
      depth: number,
      color: number,
      position: { x: number; y: number; z: number; rx?: number; ry?: number; rz?: number; roughness?: number; metalness?: number },
    ) {
      const mesh = new THREE.Mesh(new THREE.BoxGeometry(width, height, depth), material(color, position.roughness, position.metalness))
      mesh.position.set(position.x, position.y, position.z)
      mesh.rotation.set(position.rx ?? 0, position.ry ?? 0, position.rz ?? 0)
      room.add(mesh)
      return mesh
    }

    function cylinder(
      radiusTop: number,
      radiusBottom: number,
      height: number,
      color: number,
      position: { x: number; y: number; z: number; rx?: number; ry?: number; rz?: number; roughness?: number; metalness?: number },
      radialSegments = 28,
    ) {
      const mesh = new THREE.Mesh(new THREE.CylinderGeometry(radiusTop, radiusBottom, height, radialSegments), material(color, position.roughness, position.metalness))
      mesh.position.set(position.x, position.y, position.z)
      mesh.rotation.set(position.rx ?? 0, position.ry ?? 0, position.rz ?? 0)
      room.add(mesh)
      return mesh
    }

    function plane(width: number, height: number, color: number, options: { x?: number; y?: number; z?: number; rx?: number; ry?: number; rz?: number }) {
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
    }

    plane(roomWidth, roomDepth, 0xe4d8c8, { rx: -Math.PI / 2, y: 0 })
    for (let index = 0; index < 10; index += 1) {
      box(roomWidth - 0.42, 0.012, 0.012, 0xcbbfae, { x: 0, y: 0.024, z: -2.72 + index * 0.58, roughness: 0.9 })
    }
    for (let index = 0; index < 7; index += 1) {
      box(0.012, 0.012, 0.52, 0xd8ccbc, { x: -2.1 + index * 0.7, y: 0.026, z: -1.9, roughness: 0.92 })
      box(0.012, 0.012, 0.52, 0xd8ccbc, { x: -1.88 + index * 0.7, y: 0.026, z: 0.45, roughness: 0.92 })
      box(0.012, 0.012, 0.52, 0xd8ccbc, { x: -2.24 + index * 0.7, y: 0.026, z: 2.12, roughness: 0.92 })
    }

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

    const floorGrid = new THREE.GridHelper(roomDepth, 12, 0xf1e9dd, 0xc5b9aa)
    floorGrid.position.y = 0.018
    floorGrid.scale.x = roomWidth / roomDepth
    const gridMaterial = floorGrid.material as THREE.Material
    gridMaterial.transparent = true
    gridMaterial.opacity = 0.16
    gridMaterial.depthWrite = false
    room.add(floorGrid)

    box(3.45, 0.04, 3.45, 0xbeb3a6, { x: 0.26, y: 0.036, z: -0.82, roughness: 1 })
    box(3.32, 0.018, 3.32, 0xd1c8bb, { x: 0.26, y: 0.066, z: -0.82, roughness: 1 })

    box(2.36, 1.04, 0.18, 0x303238, { x: 0, y: 0.78, z: back + 0.28, roughness: 0.86 })
    for (let index = 0; index < 4; index += 1) {
      box(0.018, 0.82, 0.03, 0x4b4d54, { x: -0.9 + index * 0.6, y: 0.9, z: back + 0.18 })
    }
    box(2.34, 0.34, 2.7, 0x25262b, { x: 0, y: 0.2, z: back + 1.45, roughness: 0.78 })
    box(2.18, 0.28, 2.38, 0xe5ded7, { x: 0, y: 0.48, z: back + 1.48, roughness: 0.96 })
    box(2.12, 0.26, 1.52, 0x34353a, { x: 0, y: 0.68, z: back + 1.82, roughness: 0.92 })
    box(2.1, 0.22, 0.84, 0x8f8b84, { x: 0, y: 0.8, z: back + 2.45, roughness: 0.9 })
    box(0.88, 0.2, 0.48, 0xded8d0, { x: -0.52, y: 0.78, z: back + 0.78, rz: -0.03, roughness: 0.98 })
    box(0.88, 0.2, 0.48, 0xded8d0, { x: 0.52, y: 0.78, z: back + 0.78, rz: 0.03, roughness: 0.98 })
    box(0.74, 0.2, 0.5, 0x4a4b50, { x: -0.46, y: 0.96, z: back + 1.04, rz: 0.04, roughness: 0.95 })
    box(0.74, 0.2, 0.5, 0x4a4b50, { x: 0.46, y: 0.96, z: back + 1.04, rz: -0.04, roughness: 0.95 })
    box(0.58, 0.18, 0.36, 0xe8e1d8, { x: 0, y: 1.08, z: back + 1.35, roughness: 0.98 })

    ;[-1.62, 1.62].forEach((x) => {
      box(0.62, 0.5, 0.58, 0x252528, { x, y: 0.25, z: back + 0.72, roughness: 0.8 })
      box(0.57, 0.04, 0.52, 0x171719, { x, y: 0.52, z: back + 0.72, roughness: 0.72 })
      box(0.44, 0.018, 0.04, 0x686a70, { x, y: 0.38, z: back + 0.44, roughness: 0.5, metalness: 0.35 })
      cylinder(0.13, 0.13, 0.04, 0xf1f0e6, { x: x - 0.12, y: 0.63, z: back + 0.62, roughness: 0.58 }, 32)
      cylinder(0.06, 0.08, 0.32, 0x1a1a1d, { x: x - 0.12, y: 0.8, z: back + 0.62, roughness: 0.55 }, 24)
      cylinder(0.03, 0.03, 0.26, 0x3d3f28, { x: x + 0.18, y: 0.68, z: back + 0.82, roughness: 0.8 }, 10)
      for (let leaf = 0; leaf < 5; leaf += 1) {
        box(0.04, 0.09, 0.02, 0x5f7040, { x: x + 0.18 + Math.sin(leaf) * 0.08, y: 0.84 + leaf * 0.015, z: back + 0.82 + Math.cos(leaf) * 0.07, rz: leaf * 0.42, roughness: 0.9 })
      }
    })

    box(0.46, 1.85, 1.74, 0x1d1e20, { x: -2.33, y: 0.92, z: -1.85, roughness: 0.78 })
    for (let shelf = 0; shelf < 5; shelf += 1) {
      box(0.42, 0.035, 1.62, 0x303135, { x: -2.31, y: 0.28 + shelf * 0.35, z: -1.85, roughness: 0.8 })
    }
    ;[-2.35, -2.29].forEach((x, column) => {
      for (let item = 0; item < 6; item += 1) {
        box(0.055, 0.18 + (item % 2) * 0.08, 0.08, column ? 0xded8ce : 0x5f626a, { x, y: 0.42 + item * 0.23, z: -2.2 + (item % 3) * 0.27, roughness: 0.86 })
      }
    })
    cylinder(0.06, 0.08, 0.2, 0x6c7449, { x: -2.29, y: 1.78, z: -2.4, roughness: 0.9 }, 10)

    box(0.72, 1.7, 1.38, 0x232426, { x: -1.82, y: 0.86, z: -1.82, roughness: 0.78 })
    box(0.018, 1.52, 1.3, 0x111113, { x: -1.45, y: 0.92, z: -1.82, roughness: 0.72 })
    box(0.02, 0.42, 0.05, 0xb7b2aa, { x: -1.43, y: 0.92, z: -2.08, roughness: 0.4, metalness: 0.45 })
    box(0.02, 0.42, 0.05, 0xb7b2aa, { x: -1.43, y: 0.92, z: -1.55, roughness: 0.4, metalness: 0.45 })

    box(0.86, 0.12, 2.22, 0x242527, { x: -2.12, y: 0.72, z: 0.28, roughness: 0.75 })
    box(0.78, 0.62, 0.2, 0x202124, { x: -2.16, y: 0.34, z: -0.64, roughness: 0.78 })
    box(0.78, 0.62, 0.2, 0x202124, { x: -2.16, y: 0.34, z: 1.34, roughness: 0.78 })
    plane(0.56, 0.36, 0x1c2631, { x: -1.7, y: 1.08, z: -0.05, ry: Math.PI / 2 })
    box(0.04, 0.42, 0.62, 0x0f1011, { x: -1.72, y: 1.08, z: -0.05, roughness: 0.55 })
    box(0.22, 0.04, 0.22, 0x202124, { x: -1.9, y: 0.77, z: -0.05, roughness: 0.7 })
    box(0.38, 0.025, 0.16, 0xe2dfd7, { x: -1.9, y: 0.8, z: 0.38, roughness: 0.92 })
    cylinder(0.04, 0.04, 0.5, 0x18191b, { x: -1.8, y: 1.0, z: 0.92, rx: Math.PI / 2, roughness: 0.6 }, 16)
    cylinder(0.11, 0.08, 0.16, 0xf0eee6, { x: -1.78, y: 1.17, z: 0.92, rz: Math.PI / 2, roughness: 0.65 }, 24)

    box(0.5, 0.16, 0.5, 0x25262a, { x: -1.28, y: 0.44, z: 0.52, roughness: 0.72 })
    box(0.48, 0.56, 0.1, 0x1d1f23, { x: -1.12, y: 0.72, z: 0.52, ry: Math.PI / 2, roughness: 0.72 })
    cylinder(0.045, 0.045, 0.55, 0x111113, { x: -1.28, y: 0.24, z: 0.52, roughness: 0.55 }, 14)
    for (let spoke = 0; spoke < 5; spoke += 1) {
      box(0.38, 0.035, 0.035, 0x17181a, { x: -1.28 + Math.sin(spoke * 1.26) * 0.15, y: 0.14, z: 0.52 + Math.cos(spoke * 1.26) * 0.15, ry: spoke * 1.26, roughness: 0.62 })
      cylinder(0.04, 0.04, 0.035, 0x111113, { x: -1.28 + Math.sin(spoke * 1.26) * 0.32, y: 0.08, z: 0.52 + Math.cos(spoke * 1.26) * 0.32, rx: Math.PI / 2, roughness: 0.5 }, 12)
    }

    const windowMesh = plane(2.5, 1.78, 0xe6f0f5, {
      ry: -Math.PI / 2,
      x: halfWidth - 0.055,
      y: 1.48,
      z: 0.32,
    })
    const windowMaterial = windowMesh.material as THREE.MeshStandardMaterial
    windowMaterial.emissive = new THREE.Color(0xeaf2fb)
    windowMaterial.emissiveIntensity = 0.95
    box(0.06, 1.96, 0.08, 0x151617, { x: halfWidth - 0.08, y: 1.48, z: -1.02, roughness: 0.55 })
    box(0.06, 1.96, 0.08, 0x151617, { x: halfWidth - 0.08, y: 1.48, z: 1.54, roughness: 0.55 })
    box(0.06, 0.08, 2.62, 0x151617, { x: halfWidth - 0.08, y: 2.44, z: 0.28, roughness: 0.55 })
    box(0.06, 0.08, 2.62, 0x151617, { x: halfWidth - 0.08, y: 0.52, z: 0.28, roughness: 0.55 })
    for (let blind = 0; blind < 7; blind += 1) {
      box(0.05, 0.08, 2.42, 0xf0eee8, { x: halfWidth - 0.18, y: 0.72 + blind * 0.25, z: 0.28, roughness: 0.86 })
    }

    box(0.78, 0.82, 0.84, 0x242527, { x: 2.05, y: 0.41, z: 2.26, roughness: 0.78 })
    box(0.72, 0.04, 0.78, 0x171819, { x: 2.05, y: 0.84, z: 2.26, roughness: 0.66 })
    cylinder(0.08, 0.1, 0.18, 0x657148, { x: 1.9, y: 0.95, z: 2.12, roughness: 0.88 }, 10)
    for (let leaf = 0; leaf < 7; leaf += 1) {
      box(0.035, 0.1, 0.02, 0x5b6c3f, { x: 1.9 + Math.sin(leaf * 0.9) * 0.12, y: 1.05 + leaf * 0.012, z: 2.12 + Math.cos(leaf * 0.9) * 0.1, rz: leaf * 0.34, roughness: 0.92 })
    }
    box(0.32, 0.05, 0.22, 0xd8d2ca, { x: 2.23, y: 0.92, z: 2.35, ry: -0.2, roughness: 0.8 })
    box(0.16, 0.22, 0.04, 0x9c948a, { x: 2.26, y: 1.06, z: 2.45, ry: -0.2, roughness: 0.84 })

    box(0.05, 1.9, 0.9, 0xe5e0d6, { x: -2.16, y: 0.96, z: front - 0.36, ry: -0.72, roughness: 0.82 })
    box(0.05, 0.16, 0.9, 0x242527, { x: -2.26, y: 1.92, z: front - 0.16, ry: -0.72, roughness: 0.62 })
    cylinder(0.035, 0.035, 0.06, 0xc7b88e, { x: -1.9, y: 1.0, z: front - 0.52, rz: Math.PI / 2, roughness: 0.35, metalness: 0.45 }, 16)

    const ambient = new THREE.AmbientLight(0xffffff, 0.34)
    scene.add(ambient)
    const hemi = new THREE.HemisphereLight(0xffffff, 0x6a5f54, 0.9)
    scene.add(hemi)
    const sun = new THREE.DirectionalLight(0xfff4e2, 1.25)
    sun.position.set(6, 4.5, -1)
    scene.add(sun)
    const ceiling = new THREE.PointLight(0xffffff, 0.82, 12)
    ceiling.position.set(0, 2.6, 0.4)
    scene.add(ceiling)
    const lampLeft = new THREE.PointLight(0xffd49a, 0.72, 4)
    lampLeft.position.set(-1.45, 0.85, back + 0.6)
    scene.add(lampLeft)
    const lampRight = new THREE.PointLight(0xffd49a, 0.72, 4)
    lampRight.position.set(1.45, 0.85, back + 0.6)
    scene.add(lampRight)

    let frame = 0

    function scheduleRender() {
      if (frame) {
        return
      }
      frame = window.requestAnimationFrame(() => {
        frame = 0
        render()
      })
    }

    function resize() {
      const rect = hostElement.getBoundingClientRect()
      const width = Math.max(1, Math.floor(rect.width))
      const height = Math.max(1, Math.floor(rect.height))
      renderer.setSize(width, height, false)
      camera.aspect = width / height
      camera.updateProjectionMatrix()
      scheduleRender()
    }

    function render() {
      const { orbitProgress: progress, yaw, pitch } = stateRef.current
      const dark = document.documentElement.getAttribute('data-theme') !== 'light'
      const themeProgress = dark ? 1 : 0
      const lerp = (a: number, b: number, t: number) => a + (b - a) * t
      const smooth = (value: number) => value * value * (3 - 2 * value)
      const clamp = (value: number) => Math.max(0, Math.min(1, value))

      ambient.intensity = lerp(0.48, 0.34, themeProgress)
      sun.intensity = lerp(1.35, 0.56, themeProgress)
      sun.position.set(6, lerp(4.5, -1.8, themeProgress), -1)
      hemi.intensity = lerp(1.0, 0.72, themeProgress)
      ceiling.intensity = lerp(0.92, 0.68, themeProgress)
      lampLeft.intensity = lampRight.intensity = lerp(0.64, 1.08, themeProgress)
      windowMaterial.emissiveIntensity = lerp(1.1, 0.62, themeProgress)

      const entryProgress = smooth(clamp(progress / 0.82))
      const orbit = smooth(clamp((progress - 0.28) / 0.72))
      const cameraYaw = yaw
      const cameraPitch = lerp(-0.025, 0.02, entryProgress) + pitch
      camera.position.lerpVectors(entryPosition, centerPosition, entryProgress)

      lookDirection.set(
        Math.sin(cameraYaw) * Math.cos(cameraPitch),
        Math.sin(cameraPitch) * 0.74,
        -Math.cos(cameraYaw) * Math.cos(cameraPitch),
      )
      orbitTarget.copy(orbitAnchor).add(lookDirection.multiplyScalar(3.1))
      cameraTarget.lerpVectors(entryTarget, orbitTarget, orbit)
      camera.lookAt(cameraTarget)
      camera.fov = lerp(42, 68, entryProgress)
      camera.updateProjectionMatrix()
      room.rotation.y = lerp(-0.04, 0.02, entryProgress)
      renderer.render(scene, camera)
    }

    renderSceneRef.current = scheduleRender
    resize()
    scheduleRender()

    const resizeObserver = new ResizeObserver(resize)
    resizeObserver.observe(hostElement)
    const themeObserver = new MutationObserver(scheduleRender)
    themeObserver.observe(document.documentElement, { attributes: true, attributeFilter: ['data-theme'] })

    return () => {
      window.cancelAnimationFrame(frame)
      resizeObserver.disconnect()
      themeObserver.disconnect()
      renderSceneRef.current = () => undefined
      renderer.dispose()
      scene.traverse((object: THREE.Object3D) => {
        if (object instanceof THREE.Mesh) {
          object.geometry.dispose()
          const meshMaterial = object.material
          if (Array.isArray(meshMaterial)) {
            meshMaterial.forEach((item) => item.dispose())
          } else {
            meshMaterial.dispose()
          }
        }
      })
    }
  }, [])

  useEffect(() => {
    renderSceneRef.current()
  }, [orbitProgress, yaw, pitch])

  if (isWebGlUnavailable) {
    return (
      <div className="landing-three-fallback" aria-hidden="true">
        <div className="fallback-room">
          <span className="fallback-wall fallback-wall-back" />
          <span className="fallback-wall fallback-wall-left" />
          <span className="fallback-wall fallback-wall-right" />
          <span className="fallback-floor" />
          <span className="fallback-bed" />
          <span className="fallback-desk" />
          <span className="fallback-window" />
        </div>
      </div>
    )
  }

  return <canvas ref={canvasRef} className="landing-three-canvas" aria-hidden="true" />
}
