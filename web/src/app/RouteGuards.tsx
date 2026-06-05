import { getIdTokenResult } from 'firebase/auth'
import { useEffect, useState } from 'react'
import { Link, Navigate, useLocation } from 'react-router-dom'

import { Brand } from '../components/shell/Brand'
import { ThemeToggle } from '../components/shell/ThemeToggle'
import { StatePanel } from '../components/ui/StatePanel'
import { useAuth } from '../features/auth/AuthProvider'
import { routes } from '../lib/routes'
import { useRuntimeSurface } from '../lib/surface'

type GuardProps = {
  children: React.ReactNode
}

export function RequireAuth({ children }: GuardProps) {
  const auth = useAuth()
  const location = useLocation()

  if (!auth.isConfigured) {
    return <>{children}</>
  }

  if (auth.status === 'loading') {
    return <RouteLoading title="계정 상태를 확인하는 중입니다" />
  }

  if (auth.status === 'signed-in') {
    return <>{children}</>
  }

  const next = encodeURIComponent(`${location.pathname}${location.search}`)
  return <Navigate to={`${routes.login}?next=${next}`} replace />
}

export function RequireAdmin({ children }: GuardProps) {
  const auth = useAuth()
  const location = useLocation()
  const surface = useRuntimeSurface()
  const [check, setCheck] = useState<'idle' | 'checking' | 'allowed' | 'denied'>('idle')

  useEffect(() => {
    let active = true

    if (!auth.isConfigured) {
      setCheck('allowed')
      return () => {
        active = false
      }
    }

    if (auth.status !== 'signed-in') {
      setCheck('idle')
      return () => {
        active = false
      }
    }

    setCheck('checking')
    getIdTokenResult(auth.user, true)
      .then((result) => {
        if (!active) return
        const roles = result.claims.roles
        const isAdmin =
          result.claims.admin === true ||
          result.claims.role === 'admin' ||
          (Array.isArray(roles) && roles.includes('admin'))
        setCheck(isAdmin ? 'allowed' : 'denied')
      })
      .catch(() => {
        if (active) setCheck('denied')
      })

    return () => {
      active = false
    }
  }, [auth])

  if (surface === 'mobile-web') {
    return <AdminMobileLockedPage />
  }

  if (!auth.isConfigured) {
    return <>{children}</>
  }

  if (auth.status === 'loading' || check === 'checking') {
    return <RouteLoading title="관리자 권한을 확인하는 중입니다" />
  }

  if (auth.status !== 'signed-in') {
    const next = encodeURIComponent(`${location.pathname}${location.search}`)
    return <Navigate to={`${routes.login}?next=${next}`} replace />
  }

  if (check === 'denied') {
    return <Navigate to={routes.adminAccessDenied} replace />
  }

  return <>{children}</>
}

export function RequireDesktopCapability({ children, feature }: GuardProps & { feature: 'editor' | 'room' }) {
  const surface = useRuntimeSurface()

  if (surface === 'desktop-web') {
    return <>{children}</>
  }

  const copy = {
    editor: {
      title: '에디터는 데스크탑에서 사용할 수 있습니다',
      body: '모바일 웹은 상태와 프리뷰 확인에 집중합니다. Geometry 보정, 2D 평면도 편집, 가구 배치는 데스크탑 웹에서 이어가세요.',
    },
    room: {
      title: '방 치수 편집은 데스크탑에서 사용할 수 있습니다',
      body: '모바일 웹에서는 치수를 확인할 수 있지만 정밀 입력과 보정은 데스크탑 웹에서 진행합니다. 촬영은 모바일 앱으로 연결됩니다.',
    },
  }[feature]

  return (
    <StatePanel
      eyebrow="Mobile web gate"
      title={copy.title}
      body={copy.body}
      action={
        <>
          <Link className="rf-btn rf-btn--primary" to={routes.projects}>프로젝트로 돌아가기</Link>
          <a className="rf-btn" href="roomforge://projects">모바일 앱 열기</a>
        </>
      }
    />
  )
}

export function RouteLoading({ title }: { title: string }) {
  return (
    <main className="route-loading-page">
      <header>
        <Brand />
        <div className="top-actions">
          <ThemeToggle />
        </div>
      </header>
      <section>
        <span className="route-loader" />
        <h1>{title}</h1>
      </section>
    </main>
  )
}

function AdminMobileLockedPage() {
  return (
    <StatePanel
      eyebrow="Admin unavailable"
      title="관리자 화면은 데스크탑에서만 열립니다"
      body="운영 로그, 재시도, 감사 작업은 넓은 화면과 관리자 권한 검증을 전제로 합니다. 모바일 브라우저에서는 프로젝트 상태 확인만 지원합니다."
      action={<Link className="rf-btn rf-btn--primary" to={routes.projects}>프로젝트로 이동</Link>}
    />
  )
}
