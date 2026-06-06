import { type CSSProperties, type MouseEvent, type PointerEvent, useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react'
import { Link, useNavigate, useSearchParams } from 'react-router-dom'

import { Brand } from '../../components/shell/Brand'
import { ThemeToggle } from '../../components/shell/ThemeToggle'
import { useAuth } from '../auth/AuthProvider'
import { routes } from '../../lib/routes'
import { LandingThreeViewer } from './LandingThreeViewer'

type LandingViewerStyle = CSSProperties & Record<`--${string}`, string | number>

type Timeline = {
  t: number
  intro: number
  reveal: number
  recon: number
  orbit: number
  heroFade: number
  dockbar: number
  viewer: LandingViewerStyle
}

type PhotoTransitionRect = {
  left: number
  top: number
  width: number
  height: number
  createdAt?: number
}

const photoReference = {
  width: 1536,
  height: 1024,
  aspect: 1536 / 1024,
}

const clamp = (value: number, min = 0, max = 1) => Math.max(min, Math.min(max, value))
const smooth = (value: number, start: number, end: number) => {
  const x = clamp((value - start) / (end - start))
  return x * x * (3 - 2 * x)
}

function getCoverFrame(width: number, height: number) {
  if (width <= 0 || height <= 0) {
    return { left: 0, top: 0, width, height }
  }
  const containerAspect = width / height
  const frameWidth = containerAspect > photoReference.aspect ? width : height * photoReference.aspect
  const frameHeight = frameWidth / photoReference.aspect

  return {
    left: (width - frameWidth) / 2,
    top: (height - frameHeight) / 2,
    width: frameWidth,
    height: frameHeight,
  }
}

const initialTimeline: Timeline = {
  t: 0,
  intro: 0,
  reveal: 0,
  recon: 0,
  orbit: 0,
  heroFade: 0,
  dockbar: 0,
  viewer: {
    left: 0,
    top: 0,
    width: '100%',
    height: '100%',
    borderRadius: 0,
  },
}

const features = [
  {
    number: '01',
    title: '후보 geometry 추출',
    body: '벽, 바닥, 문, 창문, 가구 후보를 원본 이미지 좌표로 분리해 사용자가 검토할 수 있게 만듭니다.',
  },
  {
    number: '02',
    title: '미터 스케일 보정',
    body: '확인된 기준 길이를 바탕으로 픽셀 좌표를 실제 미터 좌표로 전환하고 배치 가능한 평면을 만듭니다.',
  },
  {
    number: '03',
    title: '2D와 3D 배치',
    body: '확정된 공간 위에서 프록시 가구를 이동, 회전, 크기 조정하고 저장 가능한 layout 상태로 이어갑니다.',
  },
]

const photoTransitionStorageKey = 'roomforge:landing-photo-transition'
const photoTransitionPortalSelector = '[data-roomforge-auth-photo-portal="true"]'
const photoFlightDurationMs = 1150
const photoFlightCleanupDelayMs = photoFlightDurationMs + 250
const photoFlightOverlayReleaseDelayMs = 90
const photoDockScrollDurationMs = 900
const landingPhotoDockFilter = 'saturate(0.580) contrast(1.08) brightness(0.740) blur(0px)'
const authPhotoFilter = 'var(--auth-photo-filter)'

function getPhotoPortal() {
  return document.querySelector<HTMLElement>(photoTransitionPortalSelector)
}

function removePhotoPortal() {
  getPhotoPortal()?.remove()
}

function readPxVar(element: HTMLElement, name: string) {
  const value = Number.parseFloat(element.style.getPropertyValue(name))
  return Number.isFinite(value) ? value : null
}

function getPortalPhotoRect(portal: HTMLElement): PhotoTransitionRect | null {
  const left = readPxVar(portal, '--from-left')
  const top = readPxVar(portal, '--from-top')
  const width = readPxVar(portal, '--from-width')
  const height = readPxVar(portal, '--from-height')
  const createdAt = Number.parseInt(portal.dataset.createdAt ?? '', 10)

  if (left === null || top === null || width === null || height === null || width <= 0 || height <= 0) {
    return null
  }

  return {
    left,
    top,
    width,
    height,
    createdAt: Number.isFinite(createdAt) ? createdAt : undefined,
  }
}

function getStoredPhotoRect(raw: string | null): PhotoTransitionRect | null {
  if (!raw) {
    return null
  }

  try {
    const rect = JSON.parse(raw) as PhotoTransitionRect
    return rect.width > 0 && rect.height > 0 ? rect : null
  } catch {
    return null
  }
}

function getPhotoFlightVars(from: PhotoTransitionRect, to: PhotoTransitionRect, fromFilter = landingPhotoDockFilter, toFilter = authPhotoFilter) {
  return {
    '--from-left': `${from.left}px`,
    '--from-top': `${from.top}px`,
    '--from-width': `${from.width}px`,
    '--from-height': `${from.height}px`,
    '--to-left': `${to.left}px`,
    '--to-top': `${to.top}px`,
    '--to-width': `${to.width}px`,
    '--to-height': `${to.height}px`,
    '--flight-from-filter': fromFilter,
    '--flight-to-filter': toFilter,
  }
}

function createAuthPhotoPortal(rect: DOMRect) {
  removePhotoPortal()

  const portal = document.createElement('div')
  portal.className = 'auth-photo-flight-portal'
  portal.dataset.roomforgeAuthPhotoPortal = 'true'
  portal.dataset.createdAt = String(Date.now())
  portal.style.setProperty('--from-left', `${rect.left}px`)
  portal.style.setProperty('--from-top', `${rect.top}px`)
  portal.style.setProperty('--from-width', `${rect.width}px`)
  portal.style.setProperty('--from-height', `${rect.height}px`)
  portal.style.setProperty('--flight-from-filter', landingPhotoDockFilter)
  portal.style.setProperty('--flight-to-filter', authPhotoFilter)

  const image = document.createElement('img')
  image.src = '/assets/room.png'
  image.alt = ''
  image.draggable = false
  portal.appendChild(image)
  document.body.appendChild(portal)

  window.setTimeout(() => {
    if (portal.isConnected && !portal.classList.contains('is-flying')) {
      portal.remove()
    }
  }, 5000)
}

function easeOutCubic(value: number) {
  return 1 - Math.pow(1 - value, 3)
}

export function LandingPage() {
  const auth = useAuth()
  const navigate = useNavigate()
  const [searchParams] = useSearchParams()
  const introRef = useRef<HTMLElement | null>(null)
  const pinRef = useRef<HTMLDivElement | null>(null)
  const viewerRef = useRef<HTMLDivElement | null>(null)
  const [timeline, setTimeline] = useState<Timeline>(initialTimeline)
  const [navScrolled, setNavScrolled] = useState(false)
  const [drag, setDrag] = useState({ active: false, yaw: 0, pitch: 0, lastX: 0, lastY: 0, touched: false })
  const [loginTransitioning, setLoginTransitioning] = useState(false)
  const [returnTransitioning, setReturnTransitioning] = useState(false)
  const fromLoginPhoto = searchParams.get('from') === 'login-photo'
  const startRoute = auth.status === 'signed-in' ? routes.projects : routes.login
  const isSignedIn = auth.status === 'signed-in'
  const accountLabel = isSignedIn ? auth.user.displayName ?? auth.user.email ?? '내 계정' : ''
  const accountInitials = isSignedIn ? (auth.user.displayName ?? auth.user.email ?? 'RF').slice(0, 2).toUpperCase() : ''

  useLayoutEffect(() => {
    if (!fromLoginPhoto) {
      return
    }

    const targetTop = getPhotoDockTop()
    if (targetTop !== null) {
      window.scrollTo({ top: targetTop, behavior: 'auto' })
    }
  }, [fromLoginPhoto])

  useLayoutEffect(() => {
    let frame = 0
    let loopFrame = 0
    let loopActive = false
    let lastViewportKey = ''
    let lastTimelineKey = ''

    const update = () => {
      const intro = introRef.current
      const pin = pinRef.current
      if (!intro || !pin) {
        return
      }

      const total = Math.max(1, intro.offsetHeight - window.innerHeight)
      const rect = intro.getBoundingClientRect()
      const t = clamp(-rect.top / total)
      const introProgress = smooth(t, 0, 0.26)
      const reveal = smooth(t, 0.28, 0.54)
      const recon = smooth(t, 0.52, 0.72)
      const orbit = smooth(t, 0.7, 1)
      const heroFade = smooth(t, 0.03, 0.18)
      const dockbar = smooth(t, 0.2, 0.3)

      const width = pin.clientWidth
      const height = pin.clientHeight
      const padding = width < 760 ? 16 : 28
      let dockWidth = Math.min(1120, width - padding * 2)
      let dockHeight = dockWidth / photoReference.aspect
      const maxHeight = height - (width < 760 ? 140 : 168)
      if (dockHeight > maxHeight) {
        dockHeight = maxHeight
        dockWidth = dockHeight * photoReference.aspect
      }
      const dockLeft = (width - dockWidth) / 2
      const dockTop = (height - dockHeight) / 2
      const lerp = (a: number, b: number) => a + (b - a) * introProgress
      const viewerWidth = lerp(width, dockWidth)
      const viewerHeight = lerp(height, dockHeight)
      const mediaFrame = getCoverFrame(viewerWidth, viewerHeight)
      const timelineKey = `${t.toFixed(4)}:${width}:${height}`

      if (timelineKey !== lastTimelineKey) {
        lastTimelineKey = timelineKey
        setTimeline({
          t,
          intro: introProgress,
          reveal,
          recon,
          orbit,
          heroFade,
          dockbar,
          viewer: {
            left: `${lerp(0, dockLeft).toFixed(1)}px`,
            top: `${lerp(0, dockTop).toFixed(1)}px`,
            width: `${viewerWidth.toFixed(1)}px`,
            height: `${viewerHeight.toFixed(1)}px`,
            borderRadius: `${(8 * introProgress).toFixed(2)}px`,
            '--media-left': `${mediaFrame.left.toFixed(1)}px`,
            '--media-top': `${mediaFrame.top.toFixed(1)}px`,
            '--media-width': `${mediaFrame.width.toFixed(1)}px`,
            '--media-height': `${mediaFrame.height.toFixed(1)}px`,
          },
        })
      }
      setNavScrolled(window.scrollY > 40)
    }

    const requestUpdate = () => {
      window.cancelAnimationFrame(frame)
      frame = window.requestAnimationFrame(update)
    }

    const tick = () => {
      const viewportKey = `${window.scrollY}:${window.innerWidth}:${window.innerHeight}`
      if (viewportKey !== lastViewportKey) {
        lastViewportKey = viewportKey
        update()
      }
      if (loopActive) {
        loopFrame = window.requestAnimationFrame(tick)
      }
    }

    const startLoop = () => {
      if (loopActive) {
        return
      }
      loopActive = true
      loopFrame = window.requestAnimationFrame(tick)
    }

    const stopLoop = () => {
      loopActive = false
      window.cancelAnimationFrame(loopFrame)
    }

    update()
    startLoop()
    window.addEventListener('scroll', requestUpdate, { passive: true })
    window.addEventListener('resize', requestUpdate)
    return () => {
      window.cancelAnimationFrame(frame)
      stopLoop()
      window.removeEventListener('scroll', requestUpdate)
      window.removeEventListener('resize', requestUpdate)
    }
  }, [])

  useEffect(() => {
    if (!drag.active) {
      return undefined
    }
    const stop = () => setDrag((current) => ({ ...current, active: false }))
    window.addEventListener('pointerup', stop)
    return () => window.removeEventListener('pointerup', stop)
  }, [drag.active])

  const stageStyle = useMemo(
    () =>
      ({
        ...timeline.viewer,
        '--dock': timeline.intro.toFixed(3),
        '--grid': (timeline.recon * (1 - timeline.orbit) * 0.52).toFixed(3),
      }) as CSSProperties,
    [timeline],
  )

  const photoFilter = `saturate(${(0.5 + 0.08 * timeline.intro).toFixed(3)}) contrast(1.08) brightness(${(0.45 + 0.29 * timeline.intro).toFixed(3)}) blur(${(14 * (1 - timeline.intro)).toFixed(2)}px)`
  const scanLeft = `${(timeline.reveal * 100).toFixed(2)}%`
  const processedClip = `inset(0 ${(100 - timeline.reveal * 100).toFixed(2)}% 0 0)`
  const modeLabel = timeline.reveal < 0.4 ? '원본 사진' : timeline.orbit < 0.25 ? '재구성 중...' : 'Live 3D 공간'

  function startDrag(event: PointerEvent<HTMLDivElement>) {
    if (timeline.orbit < 0.12 || loginTransitioning) {
      return
    }
    event.preventDefault()
    setDrag((current) => ({
      ...current,
      active: true,
      touched: true,
      lastX: event.clientX,
      lastY: event.clientY,
    }))
    event.currentTarget.setPointerCapture(event.pointerId)
  }

  function moveDrag(event: PointerEvent<HTMLDivElement>) {
    setDrag((current) => {
      if (!current.active) {
        return current
      }
      const dx = event.clientX - current.lastX
      const dy = event.clientY - current.lastY
      return {
        ...current,
        lastX: event.clientX,
        lastY: event.clientY,
        yaw: current.yaw + dx * 0.008,
        pitch: clamp(current.pitch + dy * 0.006, -1.05, 0.95),
      }
    })
  }

  function magnetic(event: PointerEvent<HTMLElement>) {
    if (!window.matchMedia('(pointer: fine)').matches) {
      return
    }
    const el = event.currentTarget
    const rect = el.getBoundingClientRect()
    const x = event.clientX - rect.left - rect.width / 2
    const y = event.clientY - rect.top - rect.height / 2
    el.style.transform = `translate(${(x * 0.1).toFixed(2)}px, ${(y * 0.12).toFixed(2)}px)`
  }

  function resetMagnetic(event: PointerEvent<HTMLElement>) {
    event.currentTarget.style.transform = ''
  }

  function getPhotoDockTop() {
    const intro = introRef.current
    if (!intro) {
      return null
    }
    const total = Math.max(1, intro.offsetHeight - window.innerHeight)
    return intro.offsetTop + total * 0.265
  }

  function animateScrollTo(targetTop: number, durationMs = photoDockScrollDurationMs) {
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
      window.scrollTo({ top: targetTop, behavior: 'auto' })
      return Promise.resolve()
    }

    return new Promise<void>((resolve) => {
      const startTop = window.scrollY
      const delta = targetTop - startTop
      if (Math.abs(delta) < 2) {
        window.scrollTo({ top: targetTop, behavior: 'auto' })
        resolve()
        return
      }

      const startedAt = performance.now()
      const step = (now: number) => {
        const progress = clamp((now - startedAt) / durationMs)
        window.scrollTo({ top: startTop + delta * easeOutCubic(progress), behavior: 'auto' })
        if (progress < 1) {
          window.requestAnimationFrame(step)
          return
        }
        window.scrollTo({ top: targetTop, behavior: 'auto' })
        resolve()
      }
      window.requestAnimationFrame(step)
    })
  }

  async function moveToPhotoDock(behavior?: ScrollBehavior) {
    const targetTop = getPhotoDockTop()
    if (targetTop === null) {
      return
    }
    const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches
    const scrollBehavior = behavior ?? (reduceMotion ? 'auto' : 'smooth')

    if (reduceMotion || scrollBehavior === 'auto') {
      window.scrollTo({ top: targetTop, behavior: 'auto' })
      return
    }

    await animateScrollTo(targetTop)
  }

  function scrollToMainLanding(behavior: ScrollBehavior = 'smooth') {
    window.requestAnimationFrame(() => {
      if (behavior === 'auto' || window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
        window.scrollTo({ top: 0, behavior: 'auto' })
        return
      }

      void animateScrollTo(0)
    })
  }

  async function navigateToLoginFromPhoto(event: MouseEvent<HTMLAnchorElement>) {
    if (auth.status === 'signed-in') {
      return
    }

    event.preventDefault()
    if (loginTransitioning) {
      return
    }

    setLoginTransitioning(true)
    setDrag((current) => ({ ...current, active: false }))
    await moveToPhotoDock()
    const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches
    const viewerRect = viewerRef.current?.getBoundingClientRect()

    if (viewerRect && viewerRect.width > 0 && viewerRect.height > 0 && !reduceMotion) {
      createAuthPhotoPortal(viewerRect)
      try {
        window.sessionStorage.setItem(
          photoTransitionStorageKey,
          JSON.stringify({
            left: viewerRect.left,
            top: viewerRect.top,
            width: viewerRect.width,
            height: viewerRect.height,
            createdAt: Date.now(),
          }),
        )
      } catch {
        // Session storage can be unavailable in restricted browser contexts.
      }
      await new Promise((resolve) => window.setTimeout(resolve, 80))
    }

    const nextUrl = `${routes.login}?from=landing-photo`
    navigate(nextUrl)
  }

  useEffect(() => {
    if (!fromLoginPhoto) {
      return undefined
    }

    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
      removePhotoPortal()
      window.sessionStorage.removeItem(photoTransitionStorageKey)
      navigate(routes.landing, { replace: true })
      scrollToMainLanding('auto')
      return undefined
    }

    let cancelled = false
    let frame = 0
    let cleanupTimer = 0
    let releaseTimer = 0

    const run = async () => {
      setDrag((current) => ({ ...current, active: false }))
      await moveToPhotoDock('auto')
      await new Promise<void>((resolve) => {
        window.requestAnimationFrame(() => {
          window.requestAnimationFrame(() => resolve())
        })
      })
      if (cancelled) {
        return
      }

      frame = window.requestAnimationFrame(() => {
        const activePortal = getPhotoPortal()
        const from = getStoredPhotoRect(window.sessionStorage.getItem(photoTransitionStorageKey)) ?? (activePortal ? getPortalPhotoRect(activePortal) : null)
        const isFresh = from ? !from.createdAt || Date.now() - from.createdAt < 6000 : false
        const toRect = viewerRef.current?.getBoundingClientRect()

        if (!activePortal || !from || !isFresh || !toRect || toRect.width <= 0 || toRect.height <= 0) {
          removePhotoPortal()
          window.sessionStorage.removeItem(photoTransitionStorageKey)
          setReturnTransitioning(false)
          navigate(routes.landing, { replace: true })
          scrollToMainLanding()
          return
        }

        setReturnTransitioning(true)
        viewerRef.current?.classList.add('is-return-transitioning')

        const to = {
          left: toRect.left,
          top: toRect.top,
          width: toRect.width,
          height: toRect.height,
        }

        let finished = false
        const finish = () => {
          if (finished) {
            return
          }
          finished = true
          window.clearTimeout(cleanupTimer)
          window.clearTimeout(releaseTimer)
          releaseTimer = window.setTimeout(() => {
            activePortal.remove()
            window.sessionStorage.removeItem(photoTransitionStorageKey)
            setReturnTransitioning(false)
            viewerRef.current?.classList.remove('is-return-transitioning')
            navigate(routes.landing, { replace: true })
            scrollToMainLanding()
          }, photoFlightOverlayReleaseDelayMs)
        }

        activePortal.classList.remove('is-flying')
        Object.entries(getPhotoFlightVars(from, to, authPhotoFilter, landingPhotoDockFilter)).forEach(([name, value]) => {
          activePortal.style.setProperty(name, value)
        })
        activePortal.getBoundingClientRect()
        activePortal.addEventListener('animationend', finish, { once: true })
        activePortal.addEventListener('animationcancel', finish, { once: true })
        cleanupTimer = window.setTimeout(finish, photoFlightCleanupDelayMs)
        activePortal.classList.add('is-flying')
      })
    }

    void run()

    return () => {
      cancelled = true
      viewerRef.current?.classList.remove('is-return-transitioning')
      window.cancelAnimationFrame(frame)
      window.clearTimeout(cleanupTimer)
      window.clearTimeout(releaseTimer)
    }
  }, [fromLoginPhoto, navigate])

  return (
    <main className="rf-page landing-page">
      <nav className={`landing-nav ${navScrolled ? 'is-scrolled' : ''}`}>
        <Brand />
        <div className="landing-links">
          <a onPointerMove={magnetic} onPointerLeave={resetMagnetic} href="#how">
            작동 방식
          </a>
          <a onPointerMove={magnetic} onPointerLeave={resetMagnetic} href="#features">
            기능
          </a>
          <Link onPointerMove={magnetic} onPointerLeave={resetMagnetic} to={routes.projects}>
            프로젝트
          </Link>
        </div>
        <div className="landing-cta">
          <ThemeToggle />
          {auth.status === 'loading' ? (
            <span className="landing-auth-status">로그인 확인 중</span>
          ) : isSignedIn ? (
            <>
              <Link
                className="landing-account-chip"
                onPointerMove={magnetic}
                onPointerLeave={resetMagnetic}
                title={auth.user.email ?? undefined}
                to={routes.projects}
              >
                <span className="landing-account-avatar" aria-hidden="true">
                  {accountInitials}
                </span>
                <span className="landing-account-name">{accountLabel}</span>
              </Link>
              <Link className="rf-btn rf-btn--primary" onPointerMove={magnetic} onPointerLeave={resetMagnetic} to={routes.projects}>
                내 프로젝트
              </Link>
            </>
          ) : (
            <>
              <Link className="rf-btn" onClick={navigateToLoginFromPhoto} onPointerMove={magnetic} onPointerLeave={resetMagnetic} to={routes.login}>
                로그인
              </Link>
              <Link className="rf-btn rf-btn--primary" onClick={navigateToLoginFromPhoto} onPointerMove={magnetic} onPointerLeave={resetMagnetic} to={startRoute}>
                시작하기
              </Link>
            </>
          )}
        </div>
      </nav>

      <section className="landing-intro" ref={introRef}>
        <div className="landing-pin" ref={pinRef}>
          <div
            ref={viewerRef}
            className={`landing-viewer ${timeline.orbit > 0.12 ? 'is-orbit-ready' : ''} ${drag.active ? 'is-grabbing' : ''} ${loginTransitioning ? 'is-login-transitioning' : ''} ${returnTransitioning ? 'is-return-transitioning' : ''}`}
            onPointerDown={startDrag}
            onPointerMove={moveDrag}
            style={stageStyle}
            role="img"
            aria-label="흐릿한 실제 방 사진이 선명해지며 3D 재구성 뷰어로 들어가는 데모"
          >
            <div className="landing-layer landing-photo-layer">
              <img
                className="landing-room-photo"
                src="/assets/room.png"
                alt="실제 침실 사진"
                draggable={false}
                onDragStart={(event) => event.preventDefault()}
                style={{ filter: photoFilter }}
              />
            </div>
            <div className="landing-layer landing-proc-layer" style={{ clipPath: processedClip }}>
              <LandingThreeViewer orbitProgress={timeline.orbit} yaw={drag.yaw} pitch={drag.pitch} isFreeLook={drag.touched} />
            </div>
            <div className="landing-sky">
              <span className="orb sun" />
              <span className="orb moon" />
            </div>
            <span className="landing-photo-badge" style={{ opacity: timeline.intro * (1 - timeline.reveal) }}>
              Original photo
            </span>
            <span className="landing-mode-badge" style={{ opacity: timeline.intro }}>
              {modeLabel}
            </span>
            <span className="landing-dimtag d1" style={{ opacity: clamp((timeline.orbit - 0.15) / 0.6) }}>
              침대 · 1.85 x 2.57 m
            </span>
            <span className="landing-dimtag d2" style={{ opacity: clamp((timeline.orbit - 0.38) / 0.6) }}>
              방 · 5.20 x 4.27 m
            </span>
            <span className="landing-scan" style={{ left: scanLeft, opacity: timeline.reveal > 0.005 && timeline.reveal < 0.995 ? timeline.intro : 0 }}>
              <span className="handle" aria-hidden="true">↔</span>
            </span>
            <span className="landing-glow" style={{ left: scanLeft, opacity: timeline.reveal > 0.005 && timeline.reveal < 0.995 ? 1 : 0 }} />
            <span className={`landing-hint ${timeline.orbit > 0.25 && !drag.touched ? '' : 'gone'}`}>드래그하여 회전</span>
          </div>

          <div className="landing-scrim" style={{ opacity: 1 - smooth(timeline.t, 0.06, 0.22) }} aria-hidden="true" />
          <section
            className={`landing-hero-text ${timeline.heroFade > 0.6 ? 'faded' : ''}`}
            style={{
              opacity: 1 - timeline.heroFade,
              transform: `translateY(${(-timeline.heroFade * 36).toFixed(1)}px)`,
            }}
          >
            <div className="landing-hero-inner">
              <div className="landing-hero-copy">
                <div>
                  <p className="eyebrow">Photo to metric room model</p>
                  <h1>사진이 방이 되는 순간.</h1>
                </div>
                <div>
                  <p className="sub">실제 방 사진을 치수 기반 3D 공간으로 전환합니다. 원본 이미지, 후보 geometry, 확인된 공간 모델을 한 흐름에서 검토하고 바로 배치까지 이어갑니다.</p>
                  <div className="hero-actions">
                    <Link className="rf-btn rf-btn--primary btn-big" onClick={navigateToLoginFromPhoto} to={startRoute}>
                      공간 만들기
                    </Link>
                    <a className="rf-btn btn-big" href="#how">
                      데모 보기
                    </a>
                  </div>
                  <div className="landing-hero-metrics" aria-label="RoomForge 핵심 지표">
                    <div><strong>3D</strong><span>실시간 공간 뷰</span></div>
                    <div><strong>m</strong><span>미터 좌표 보정</span></div>
                    <div><strong>CV</strong><span>후보 geometry 검토</span></div>
                  </div>
                  <span className="scrollcue"><span className="dot" />스크롤하여 뷰어로 들어가기</span>
                </div>
              </div>
            </div>
          </section>

          <div className="landing-dockbar" style={{ opacity: timeline.dockbar }} aria-hidden="true">
            <div className="stagebar">
              {['원본 사진', '재구성', '3D 공간'].map((label, index) => (
                <span className={`step ${activeStep(timeline) === index ? 'on' : ''}`} key={label}>
                  <span className="led" />
                  {label}
                </span>
              ))}
            </div>
            <p>흐릿한 배경은 업로드한 원본 사진, 뷰어 안은 Three.js 재구성 결과입니다.</p>
          </div>
        </div>
      </section>

      <section className="landing-section" id="how">
        <p className="rf-eyebrow">How it works</p>
        <h2>원본 사진에서 편집 가능한 공간으로.</h2>
        <p className="lead">흐릿하게 깔린 원본 사진이 스크롤과 함께 선명해지며 뷰어 안으로 들어오고, 후보 geometry로 분해된 뒤 배치 가능한 3D 공간으로 이어집니다.</p>
      </section>

      <section className="landing-section" id="features">
        <p className="rf-eyebrow">Core flow</p>
        <h2>CV 후보를 사람이 바로 고칠 수 있는 작업공간.</h2>
        <div className="landing-features">
          {features.map((feature) => (
            <FeatureCard key={feature.number} {...feature} />
          ))}
        </div>
      </section>

      <section className="landing-final">
        <p className="rf-eyebrow">Start building</p>
        <h2>사진 한 장에서 시작해, 실제 배치 가능한 방으로.</h2>
        <div className="row">
          <Link className="rf-btn rf-btn--primary btn-big" onClick={navigateToLoginFromPhoto} to={startRoute}>
            무료로 시작하기
          </Link>
          <Link className="rf-btn" to={routes.projects}>
            프로젝트 보기
          </Link>
        </div>
      </section>
      <footer className="landing-foot">© RoomForge · 사진이 방이 되는 순간</footer>
    </main>
  )
}

function activeStep(timeline: Timeline) {
  if (timeline.reveal < 0.4) {
    return 0
  }
  return timeline.orbit < 0.25 ? 1 : 2
}

function FeatureCard({ number, title, body }: { number: string; title: string; body: string }) {
  function tilt(event: PointerEvent<HTMLElement>) {
    if (!window.matchMedia('(pointer: fine)').matches) {
      return
    }
    const rect = event.currentTarget.getBoundingClientRect()
    const x = (event.clientX - rect.left) / rect.width
    const y = (event.clientY - rect.top) / rect.height
    event.currentTarget.style.setProperty('--tilt-x', `${((x - 0.5) * 5).toFixed(2)}deg`)
    event.currentTarget.style.setProperty('--tilt-y', `${((0.5 - y) * 4).toFixed(2)}deg`)
  }

  function reset(event: PointerEvent<HTMLElement>) {
    event.currentTarget.style.setProperty('--tilt-x', '0deg')
    event.currentTarget.style.setProperty('--tilt-y', '0deg')
  }

  return (
    <article className="landing-feature-card" onPointerMove={tilt} onPointerLeave={reset}>
      <span className="num">{number}</span>
      <div className="ic" aria-hidden="true" />
      <h3>{title}</h3>
      <p>{body}</p>
    </article>
  )
}
