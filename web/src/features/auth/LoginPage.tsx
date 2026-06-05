import { useEffect, useState } from 'react'
import { Link, useNavigate, useSearchParams } from 'react-router-dom'

import { Brand } from '../../components/shell/Brand'
import { ThemeToggle } from '../../components/shell/ThemeToggle'
import { routes } from '../../lib/routes'
import { useAuth } from './AuthProvider'

export function LoginPage() {
  const auth = useAuth()
  const navigate = useNavigate()
  const [searchParams] = useSearchParams()
  const [isSigningIn, setIsSigningIn] = useState(false)
  const [localError, setLocalError] = useState<string | null>(null)
  const next = searchParams.get('next')

  useEffect(() => {
    if (auth.status === 'signed-in') {
      navigate(next && next.startsWith('/') ? next : routes.projects, { replace: true })
    }
  }, [auth.status, navigate, next])

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

  const error = localError ?? (auth.status === 'error' ? auth.error : null)

  return (
    <main className="auth-page">
      <section className="auth-column">
        <header className="auth-top">
          <Brand />
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
          <Link to={routes.landing}>홈으로</Link>
          <span className="dot" />
          <a href="mailto:support@roomforge.local">도움이 필요하신가요?</a>
          <span className="ml-auto">© RoomForge</span>
        </footer>
      </section>

      <aside className="auth-visual" aria-hidden="true">
        <img className="shot" src="/assets/room.png" alt="" />
        <div className="auth-badge"><span className="led" />Live reconstruction</div>
        <span className="auth-scan" />
        <div className="auth-visual-copy">
          <span className="tag">Photo to metric room model</span>
          <h2>사진이 방이 되는 순간.</h2>
          <div className="auth-chips">
            <span className="auth-chip"><b>3D</b><span>실시간 공간 뷰</span></span>
            <span className="auth-chip"><b>m</b><span>미터 좌표 보정</span></span>
            <span className="auth-chip"><b>CV</b><span>후보 geometry</span></span>
          </div>
        </div>
      </aside>
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
