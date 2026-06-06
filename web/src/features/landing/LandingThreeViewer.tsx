import { useEffect, useRef, useState } from 'react'
import * as THREE from 'three'

import { createLandingRoomScene } from './landingRoomScene'

type LandingThreeViewerProps = {
  orbitProgress: number
  yaw: number
  pitch: number
  isFreeLook: boolean
}

const photoCameraFlow = {
  aspect: 1536 / 1024,
  initial: {
    fov: 58,
    position: new THREE.Vector3(-0.08, 1.46, 3.35),
    target: new THREE.Vector3(0.22, 1.12, -1.1),
  },
  center: {
    fov: 56,
    position: new THREE.Vector3(0, 1.42, 1.15),
    target: new THREE.Vector3(0.18, 1.05, -1.2),
  },
}

export function LandingThreeViewer({ orbitProgress, yaw, pitch, isFreeLook }: LandingThreeViewerProps) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null)
  const stateRef = useRef({ orbitProgress, yaw, pitch, isFreeLook })
  const renderSceneRef = useRef<() => void>(() => undefined)
  const [isWebGlUnavailable, setIsWebGlUnavailable] = useState(false)

  stateRef.current = { orbitProgress, yaw, pitch, isFreeLook }

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

    const camera = new THREE.PerspectiveCamera(photoCameraFlow.initial.fov, photoCameraFlow.aspect, 0.1, 80)
    const cameraTarget = new THREE.Vector3()
    const orbitAnchor = new THREE.Vector3(0.18, 1.05, -1.2)
    const orbitTarget = new THREE.Vector3()
    const transitionTarget = new THREE.Vector3()
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
    const { room, frontWall, lighting } = createLandingRoomScene(scene)
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
      const { orbitProgress: progress, yaw, pitch, isFreeLook } = stateRef.current
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
      const freeLookProgress = isFreeLook ? smooth(clamp((progress - 0.18) / 0.62)) : 0
      const cameraYaw = yaw
      const cameraPitch = lerp(-0.025, 0.02, entryProgress) + pitch
      camera.position.lerpVectors(photoCameraFlow.initial.position, photoCameraFlow.center.position, entryProgress)

      lookDirection.set(
        Math.sin(cameraYaw) * Math.cos(cameraPitch),
        Math.sin(cameraPitch) * 0.74,
        -Math.cos(cameraYaw) * Math.cos(cameraPitch),
      )
      orbitTarget.copy(orbitAnchor).add(lookDirection.multiplyScalar(3.1))
      transitionTarget.lerpVectors(photoCameraFlow.initial.target, photoCameraFlow.center.target, entryProgress)
      cameraTarget.lerpVectors(transitionTarget, orbitTarget, freeLookProgress)
      camera.lookAt(cameraTarget)
      camera.fov = lerp(photoCameraFlow.initial.fov, photoCameraFlow.center.fov, entryProgress)
      camera.updateProjectionMatrix()
      const frontWallOpacity = smooth(clamp((entryProgress - 0.18) / 0.58))
      for (const mesh of frontWall) {
        const meshMaterial = mesh.material
        if (Array.isArray(meshMaterial)) {
          meshMaterial.forEach((item) => {
            item.opacity = frontWallOpacity
            item.transparent = frontWallOpacity < 1
          })
        } else {
          meshMaterial.opacity = frontWallOpacity
          meshMaterial.transparent = frontWallOpacity < 1
        }
        mesh.visible = frontWallOpacity > 0.015
      }
      room.rotation.y = 0
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
  }, [orbitProgress, yaw, pitch, isFreeLook])

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
