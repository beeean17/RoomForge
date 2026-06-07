import { type CSSProperties, type MouseEvent, useEffect, useLayoutEffect, useRef, useState } from 'react'
import { Link, useNavigate, useSearchParams } from 'react-router-dom'

import { Brand } from '../../components/shell/Brand'
import { ThemeToggle } from '../../components/shell/ThemeToggle'
import { routes } from '../../lib/routes'
import { useAuth } from './AuthProvider'

type PhotoTransitionRect = {
  left: number
  top: number
  width: number
  height: number
  createdAt?: number
}

type PhotoFlight = {
  from: PhotoTransitionRect
  to: PhotoTransitionRect
  source: 'portal' | 'fallback'
}

const photoTransitionStorageKey = 'roomforge:landing-photo-transition'
const photoTransitionPortalSelector = '[data-roomforge-auth-photo-portal="true"]'
const photoFlightDurationMs = 1150
const photoFlightCleanupDelayMs = photoFlightDurationMs + 250
const photoFlightOverlayReleaseDelayMs = 90
const landingPhotoDockFilter = 'saturate(0.580) contrast(1.08) brightness(0.740) blur(0px)'
const authPhotoFilter = 'var(--auth-photo-filter)'

function getPhotoPortal() {
  return document.querySelector<HTMLElement>(photoTransitionPortalSelector)
}

function removePhotoPortal() {
  getPhotoPortal()?.remove()
}

function createPhotoPortal(rect: DOMRect) {
  removePhotoPortal()

  const portal = document.createElement('div')
  portal.className = 'auth-photo-flight-portal'
  portal.dataset.roomforgeAuthPhotoPortal = 'true'
  portal.dataset.createdAt = String(Date.now())
  portal.style.setProperty('--from-left', `${rect.left}px`)
  portal.style.setProperty('--from-top', `${rect.top}px`)
  portal.style.setProperty('--from-width', `${rect.width}px`)
  portal.style.setProperty('--from-height', `${rect.height}px`)
  portal.style.setProperty('--flight-from-filter', authPhotoFilter)
  portal.style.setProperty('--flight-to-filter', landingPhotoDockFilter)

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

export function LoginPage() {
  const auth = useAuth()
  const navigate = useNavigate()
  const [searchParams] = useSearchParams()
  const visualRef = useRef<HTMLElement | null>(null)
  const photoFlightReleaseTimer = useRef(0)
  const [isSigningIn, setIsSigningIn] = useState(false)
  const [localError, setLocalError] = useState<string | null>(null)
  const [photoFlight, setPhotoFlight] = useState<PhotoFlight | null>(null)
  const [photoExitPending, setPhotoExitPending] = useState(false)
  const next = searchParams.get('next')
  const fromLandingPhoto = searchParams.get('from') === 'landing-photo'
  const [photoFlightSettled, setPhotoFlightSettled] = useState(!fromLandingPhoto)

  useLayoutEffect(() => {
    if (fromLandingPhoto) {
      window.scrollTo({ top: 0, behavior: 'auto' })
    }
  }, [fromLandingPhoto])

  useEffect(() => {
    return () => {
      window.clearTimeout(photoFlightReleaseTimer.current)
    }
  }, [])

  useEffect(() => {
    if (auth.status === 'signed-in') {
      navigate(next && next.startsWith('/') ? next : routes.projects, { replace: true })
    }
  }, [auth.status, navigate, next])

  useEffect(() => {
    if (!fromLandingPhoto) {
      removePhotoPortal()
      window.sessionStorage.removeItem(photoTransitionStorageKey)
      setPhotoFlightSettled(true)
      return undefined
    }

    setPhotoFlightSettled(false)

    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
      removePhotoPortal()
      window.sessionStorage.removeItem(photoTransitionStorageKey)
      setPhotoFlightSettled(true)
      return undefined
    }

    let frame = 0
    let cleanupTimer = 0

    const existingPortal = getPhotoPortal()
    const from = getStoredPhotoRect(window.sessionStorage.getItem(photoTransitionStorageKey)) ?? (existingPortal ? getPortalPhotoRect(existingPortal) : null)
    const isFresh = from ? !from.createdAt || Date.now() - from.createdAt < 6000 : false
    if (!from || !isFresh) {
      removePhotoPortal()
      window.sessionStorage.removeItem(photoTransitionStorageKey)
      setPhotoFlightSettled(true)
      return undefined
    }

    frame = window.requestAnimationFrame(() => {
      const toRect = visualRef.current?.getBoundingClientRect()
      if (!toRect || toRect.width <= 0 || toRect.height <= 0) {
        removePhotoPortal()
        window.sessionStorage.removeItem(photoTransitionStorageKey)
        setPhotoFlightSettled(true)
        return
      }
      const to = {
        left: toRect.left,
        top: toRect.top,
        width: toRect.width,
        height: toRect.height,
      }
      const activePortal = getPhotoPortal()

      const flight = {
        from,
        to,
        source: activePortal ? 'portal' : 'fallback',
      } satisfies PhotoFlight

      window.sessionStorage.removeItem(photoTransitionStorageKey)
      setPhotoFlight(flight)

      if (activePortal) {
        const finish = () => {
          window.clearTimeout(cleanupTimer)
          setPhotoFlightSettled(true)
          window.clearTimeout(photoFlightReleaseTimer.current)
          photoFlightReleaseTimer.current = window.setTimeout(() => {
            activePortal.remove()
            setPhotoFlight(null)
          }, photoFlightOverlayReleaseDelayMs)
        }

        activePortal.classList.remove('is-flying')
        Object.entries(getPhotoFlightVars(from, to)).forEach(([name, value]) => {
          activePortal.style.setProperty(name, value)
        })
        activePortal.getBoundingClientRect()
        activePortal.addEventListener('animationend', finish, { once: true })
        activePortal.addEventListener('animationcancel', finish, { once: true })
        cleanupTimer = window.setTimeout(finish, photoFlightCleanupDelayMs)
        activePortal.classList.add('is-flying')
      }
    })

    return () => {
      window.cancelAnimationFrame(frame)
      window.clearTimeout(cleanupTimer)
    }
  }, [fromLandingPhoto])

  async function handleGoogleSignIn() {
    setIsSigningIn(true)
    setLocalError(null)
    try {
      await auth.signInWithGoogle()
    } catch (error) {
      setLocalError(error instanceof Error ? error.message : String(error))
    } finally {
      setIsSigningIn(false)
    }
  }

  async function navigateToLandingFromPhoto(event: MouseEvent<HTMLAnchorElement>) {
    event.preventDefault()
    if (photoExitPending) {
      return
    }

    const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches
    const visualRect = visualRef.current?.getBoundingClientRect()

    if (visualRect && visualRect.width > 0 && visualRect.height > 0 && !reduceMotion) {
      setPhotoExitPending(true)
      createPhotoPortal(visualRect)
      try {
        window.sessionStorage.setItem(
          photoTransitionStorageKey,
          JSON.stringify({
            left: visualRect.left,
            top: visualRect.top,
            width: visualRect.width,
            height: visualRect.height,
            createdAt: Date.now(),
          }),
        )
      } catch {
        // Session storage can be unavailable in restricted browser contexts.
      }
      await new Promise((resolve) => window.setTimeout(resolve, 100))
      navigate(`${routes.landing}?from=login-photo`)
      return
    }

    navigate(routes.landing)
  }

  const error = localError ?? (auth.status === 'error' ? auth.error : null)
  const pageClass = [
    'auth-page',
    fromLandingPhoto ? 'auth-page--photo-entry' : '',
    fromLandingPhoto && !photoFlightSettled ? 'auth-page--photo-flight-pending' : '',
    fromLandingPhoto && photoFlightSettled ? 'auth-page--photo-flight-settled' : '',
    photoFlight ? 'auth-page--photo-flight-active' : '',
    photoExitPending ? 'auth-page--photo-exit' : '',
  ]
    .filter(Boolean)
    .join(' ')
  const photoFlightStyle = photoFlight
    ? ({
        ...getPhotoFlightVars(photoFlight.from, photoFlight.to),
      } as CSSProperties)
    : undefined

  return (
    <main className={pageClass}>
      <section className="auth-column">
        <header className="auth-top">
          <Brand onClick={navigateToLandingFromPhoto} />
          <span className="ml-auto" />
          <ThemeToggle />
        </header>

        <div className="auth-body">
          <div className="auth-card">
            <p className="rf-eyebrow">Welcome back</p>
            <h1>
              RoomForge에
              <br />
              로그인
            </h1>
            <p className="sub">사진을 치수 기반 3D 공간으로. 계정으로 계속하면 프로젝트와 재구성 결과가 그대로 이어집니다.</p>

            <button className="btn-google" type="button" onClick={handleGoogleSignIn} disabled={isSigningIn || auth.status === 'loading'}>
              <GoogleIcon />
              {isSigningIn || auth.status === 'loading' ? '로그인 준비 중...' : 'Google로 계속하기'}
            </button>

            {error && (
              <div className="auth-notice" role="alert">
                {error}
              </div>
            )}

            {!auth.isConfigured && !error && (
              <div className="auth-notice" role="status">
                Firebase web config가 아직 없습니다. `VITE_ROOMFORGE_FIREBASE_*` 환경 변수를 연결하면 실제 Google 로그인이 활성화됩니다.
              </div>
            )}

            <p className="auth-legal">
              계속하면 RoomForge 이용약관 및 개인정보처리방침에 동의하는 것으로 간주됩니다.
            </p>

            <div className="auth-handoff">
              <span>▣</span>
              <span>
                카메라 가이드 촬영은 <b style={{ color: 'var(--text-main)' }}>RoomForge 모바일 앱</b>에서 진행됩니다. 데스크탑 웹은 재구성 검토와 편집에 최적화되어 있어요.
              </span>
            </div>
          </div>
        </div>

        <footer className="auth-foot">
          <Link onClick={navigateToLandingFromPhoto} to={routes.landing}>홈으로</Link>
          <span className="dot" />
          <a href="mailto:support@roomforge.local">도움이 필요하신가요?</a>
          <span className="ml-auto">© RoomForge</span>
        </footer>
      </section>

      <div className="auth-visual-stage" aria-hidden="true">
        <aside className="auth-visual" ref={visualRef}>
          <img className="shot" src="/assets/room.png" alt="" draggable={false} onDragStart={(event) => event.preventDefault()} />
        </aside>
        <div className="auth-visual-copy">
          <span className="tag">Photo to metric room model</span>
          <h2>사진이 방이 되는 순간.</h2>
          <div className="auth-chips">
            <span className="auth-chip"><b>3D</b><span>실시간 공간 뷰</span></span>
            <span className="auth-chip"><b>m</b><span>미터 좌표 보정</span></span>
            <span className="auth-chip"><b>CV</b><span>후보 geometry</span></span>
          </div>
        </div>
      </div>

      {photoFlight && photoFlight.source === 'fallback' && (
        <div
          className="auth-photo-flight"
          aria-hidden="true"
          style={photoFlightStyle}
          onAnimationEnd={() => {
            setPhotoFlightSettled(true)
            window.clearTimeout(photoFlightReleaseTimer.current)
            photoFlightReleaseTimer.current = window.setTimeout(() => {
              setPhotoFlight(null)
            }, photoFlightOverlayReleaseDelayMs)
          }}
        >
          <img src="/assets/room.png" alt="" draggable={false} />
        </div>
      )}
    </main>
  )
}

function GoogleIcon() {
  return (
    <svg viewBox="0 0 48 48" aria-hidden="true">
      <path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z" />
      <path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z" />
      <path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z" />
      <path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z" />
    </svg>
  )
}
