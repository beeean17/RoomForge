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
      renderer = new THREE.WebGLRenderer({ canvas, alpha: true, antialias: true })
    } catch {
      setIsWebGlUnavailable(true)
      return undefined
    }
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2))
    renderer.outputColorSpace = THREE.SRGBColorSpace

    const scene = new THREE.Scene()
    scene.background = null

    const camera = new THREE.PerspectiveCamera(40, 1, 0.1, 80)
    const target = new THREE.Vector3(-0.12, 0.94, -2.29)
    const room = new THREE.Group()
    scene.add(room)

    const roomWidth = 5.2
    const roomDepth = 6.0
    const roomHeight = 2.8
    const halfWidth = roomWidth / 2
    const back = -roomDepth / 2
    const front = roomDepth / 2

    function material(color: number, roughness = 0.72, metalness = 0.04) {
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

    plane(roomWidth, roomDepth, 0x353238, { rx: -Math.PI / 2, y: 0 })
    plane(roomWidth, roomHeight, 0x202126, { z: back, y: roomHeight / 2 })
    plane(roomDepth, roomHeight, 0x191b20, { ry: Math.PI / 2, x: -halfWidth, y: roomHeight / 2 })
    plane(roomDepth, roomHeight, 0x23262b, { ry: -Math.PI / 2, x: halfWidth, y: roomHeight / 2 })
    plane(roomWidth, roomHeight, 0x17191d, { z: front, y: roomHeight / 2, rz: Math.PI })

    box(2.3, 0.55, 2.75, 0x2b2b32, { x: 0, y: 0.28, z: back + 1.25 })
    box(2.3, 0.18, 0.38, 0x45454e, { x: 0, y: 0.76, z: back + 0.25 })
    box(0.55, 0.46, 0.48, 0x24242a, { x: -1.55, y: 0.23, z: back + 0.52 })
    box(0.55, 0.46, 0.48, 0x24242a, { x: 1.55, y: 0.23, z: back + 0.52 })
    box(0.62, 0.78, 1.6, 0x292a30, { x: -halfWidth + 0.35, y: 0.39, z: -0.4 })
    box(0.46, 1.65, 1.5, 0x1d1e24, { x: halfWidth - 0.3, y: 0.82, z: 1.0 })
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

    const hemi = new THREE.HemisphereLight(0xffffff, 0x3a3a42, 0.55)
    scene.add(hemi)
    const sun = new THREE.DirectionalLight(0xfff4e2, 0.85)
    sun.position.set(6, 4.5, -1)
    scene.add(sun)
    const ceiling = new THREE.PointLight(0xffffff, 0.35, 12)
    ceiling.position.set(0, 2.6, 0.4)
    scene.add(ceiling)
    const lampLeft = new THREE.PointLight(0xffd49a, 0.5, 4)
    lampLeft.position.set(-1.45, 0.85, back + 0.6)
    scene.add(lampLeft)
    const lampRight = new THREE.PointLight(0xffd49a, 0.5, 4)
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

      sun.intensity = lerp(0.95, 0.1, themeProgress)
      sun.position.set(6, lerp(4.5, -3, themeProgress), -1)
      hemi.intensity = lerp(0.58, 0.34, themeProgress)
      ceiling.intensity = lerp(0.4, 0.22, themeProgress)
      lampLeft.intensity = lampRight.intensity = lerp(0.4, 0.95, themeProgress)
      windowMaterial.emissiveIntensity = lerp(0.95, 0.45, themeProgress)

      const baseRadius = 7.2
      const radius = lerp(5.7, baseRadius, progress)
      const cameraYaw = yaw * progress
      const cameraPitch = -0.05 + pitch * progress
      const cp = Math.cos(cameraPitch)
      camera.position.set(
        target.x + radius * Math.sin(cameraYaw) * cp,
        target.y + radius * Math.sin(cameraPitch),
        target.z + radius * Math.cos(cameraYaw) * cp,
      )
      camera.lookAt(target)
      room.rotation.y = lerp(-0.08, 0.02, progress)
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
