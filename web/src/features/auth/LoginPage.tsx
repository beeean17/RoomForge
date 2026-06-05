import { Link } from 'react-router-dom'

import { Brand } from '../../components/shell/Brand'
import { ThemeToggle } from '../../components/shell/ThemeToggle'
import { routes } from '../../lib/routes'

export function LoginPage() {
  return (
    <main className="rf-page hero-grid">
      <section className="hero-copy">
        <div className="absolute left-8 top-7 flex items-center gap-3">
          <Brand />
          <ThemeToggle />
        </div>
        <div>
          <p className="rf-eyebrow">Sign in</p>
          <h1 className="!max-w-[11ch]">작업공간으로 들어가기</h1>
          <p>프로젝트, 소스 이미지, 재구성 상태, 에디터를 같은 데스크탑 세션에서 이어갑니다.</p>
          <div className="mt-8 grid w-full max-w-[380px] gap-3">
            <Link className="rf-btn rf-btn--primary !min-h-[52px]" to={routes.projects}>
              Google로 계속하기
            </Link>
            <p className="m-0 text-[12px] text-[var(--text-dim)]">
              Firebase Auth 연결은 Phase 1에서 실제 provider로 교체됩니다.
            </p>
          </div>
        </div>
      </section>
      <aside className="hero-visual">
        <img src="/assets/room.png" alt="" />
        <div className="hero-badge">
          <span className="status-pill status-pill--success">desktop ready</span>
          <strong>Project workspace</strong>
        </div>
      </aside>
    </main>
  )
}
