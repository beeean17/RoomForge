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

    const camera = new THREE.PerspectiveCamera(46, 1, 0.1, 80)
    const cameraTarget = new THREE.Vector3()
    const entryPosition = new THREE.Vector3(0, 1.35, 5.9)
    const centerPosition = new THREE.Vector3(0, 1.34, 0.35)
    const entryTarget = new THREE.Vector3(0, 1.05, -1.8)
    const orbitAnchor = new THREE.Vector3(0, 1.28, 0.35)
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
      position: { x: number; y: number; z: number },
    ) {
      const mesh = new THREE.Mesh(new THREE.BoxGeometry(width, height, depth), material(color))
      mesh.position.set(position.x, position.y, position.z)
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

    plane(roomWidth, roomDepth, 0x817971, { rx: -Math.PI / 2, y: 0 })
    plane(roomWidth, roomHeight, 0x6e727a, { z: back, y: roomHeight / 2 })
    plane(roomDepth, roomHeight, 0x777a80, { ry: Math.PI / 2, x: -halfWidth, y: roomHeight / 2 })
    plane(roomDepth, roomHeight, 0x878a8f, { ry: -Math.PI / 2, x: halfWidth, y: roomHeight / 2 })
    plane(0.82, roomHeight, 0x777a80, { x: -2.18, z: front, y: roomHeight / 2 })
    plane(0.82, roomHeight, 0x85888f, { x: 2.18, z: front, y: roomHeight / 2 })
    plane(3.55, 0.56, 0x7e8288, { z: front, y: roomHeight - 0.28 })

    const floorGrid = new THREE.GridHelper(roomDepth, 12, 0xd9dde3, 0xb8bdc5)
    floorGrid.position.y = 0.014
    floorGrid.scale.x = roomWidth / roomDepth
    const gridMaterial = floorGrid.material as THREE.Material
    gridMaterial.transparent = true
    gridMaterial.opacity = 0.24
    gridMaterial.depthWrite = false
    room.add(floorGrid)

    box(2.3, 0.55, 2.75, 0x383a42, { x: 0, y: 0.28, z: back + 1.25 })
    box(2.3, 0.18, 0.38, 0x9a9ca4, { x: 0, y: 0.76, z: back + 0.25 })
    box(0.55, 0.46, 0.48, 0x393b42, { x: -1.55, y: 0.23, z: back + 0.52 })
    box(0.55, 0.46, 0.48, 0x393b42, { x: 1.55, y: 0.23, z: back + 0.52 })
    box(0.62, 0.78, 1.6, 0x4d5058, { x: -halfWidth + 0.35, y: 0.39, z: -0.4 })
    box(0.46, 1.65, 1.5, 0x3c3f46, { x: halfWidth - 0.3, y: 0.82, z: 1.0 })
    box(0.05, 1.6, 2.3, 0x111114, { x: halfWidth - 0.02, y: 1.5, z: -0.8 })

    const windowMesh = plane(2.1, 1.4, 0xe9f1f8, {
      ry: -Math.PI / 2,
      x: halfWidth - 0.06,
      y: 1.5,
      z: -0.8,
    })
    const windowMaterial = windowMesh.material as THREE.MeshStandardMaterial
    windowMaterial.emissive = new THREE.Color(0xeaf2fb)
    windowMaterial.emissiveIntensity = 0.95

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

      const entryProgress = smooth(clamp(progress / 0.36))
      const orbit = smooth(clamp((progress - 0.28) / 0.72))
      const cameraYaw = yaw
      const cameraPitch = lerp(-0.04, 0.04, entryProgress) + pitch * 0.55
      camera.position.lerpVectors(entryPosition, centerPosition, entryProgress)

      lookDirection.set(
        Math.sin(cameraYaw) * Math.cos(cameraPitch),
        Math.sin(cameraPitch) * 0.74,
        -Math.cos(cameraYaw) * Math.cos(cameraPitch),
      )
      orbitTarget.copy(orbitAnchor).add(lookDirection.multiplyScalar(3.1))
      cameraTarget.lerpVectors(entryTarget, orbitTarget, orbit)
      camera.lookAt(cameraTarget)
      camera.fov = lerp(46, 64, entryProgress)
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
