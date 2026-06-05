import { useEffect, useRef, useState } from 'react'
import * as THREE from 'three'

import { createLandingRoomScene } from './landingRoomScene'

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
    const colorScratch = new THREE.Color()
    const daySkyColor = new THREE.Color(0xdfeff8)
    const nightSkyColor = new THREE.Color(0x05070d)
    const daySunColor = new THREE.Color(0xfff2d0)
    const nightMoonColor = new THREE.Color(0x7891c8)
    const dayWindowColor = new THREE.Color(0xeaf7ff)
    const nightWindowColor = new THREE.Color(0x111827)
    const dayWindowGlow = new THREE.Color(0xd9f1ff)
    const nightWindowGlow = new THREE.Color(0x26385f)
    const dayCeilingColor = new THREE.Color(0xf6f7ff)
    const nightCeilingColor = new THREE.Color(0xffd7a2)
    const dayLampColor = new THREE.Color(0xffe4ba)
    const nightLampColor = new THREE.Color(0xffb866)
    const { room, lighting } = createLandingRoomScene(scene)
    const { ambient, hemi, sun, ceiling, lampLeft, lampRight, windowMaterial, windowGlow } = lighting

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

      renderer.setClearColor(colorScratch.lerpColors(daySkyColor, nightSkyColor, themeProgress), 1)
      renderer.toneMappingExposure = lerp(1.42, 1.08, themeProgress)
      windowMaterial.color.lerpColors(dayWindowColor, nightWindowColor, themeProgress)
      windowMaterial.emissive.lerpColors(dayWindowGlow, nightWindowGlow, themeProgress)
      windowMaterial.emissiveIntensity = lerp(1.65, 0.18, themeProgress)
      windowGlow.color.lerpColors(dayWindowGlow, nightWindowGlow, themeProgress)
      windowGlow.intensity = lerp(1.35, 0.14, themeProgress)

      ambient.intensity = lerp(0.6, 0.2, themeProgress)
      sun.color.lerpColors(daySunColor, nightMoonColor, themeProgress)
      sun.intensity = lerp(1.55, 0.12, themeProgress)
      sun.position.set(6, lerp(4.5, -1.8, themeProgress), -1)
      hemi.color.lerpColors(daySunColor, nightMoonColor, themeProgress)
      hemi.intensity = lerp(1.12, 0.34, themeProgress)
      ceiling.color.lerpColors(dayCeilingColor, nightCeilingColor, themeProgress)
      ceiling.intensity = lerp(0.42, 1.16, themeProgress)
      lampLeft.color.lerpColors(dayLampColor, nightLampColor, themeProgress)
      lampRight.color.lerpColors(dayLampColor, nightLampColor, themeProgress)
      lampLeft.intensity = lampRight.intensity = lerp(0.22, 1.48, themeProgress)

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
