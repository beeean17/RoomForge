import { Link } from 'react-router-dom'

import { Brand } from '../../components/shell/Brand'
import { ThemeToggle } from '../../components/shell/ThemeToggle'
import { demoProjectId, routes } from '../../lib/routes'

export function LandingPage() {
  return (
    <main className="rf-page">
      <header className="product-topbar">
        <Brand />
        <nav className="hidden md:flex items-center gap-1 text-[12px] font-bold text-[var(--text-dim)]">
          <a className="rounded-lg px-3 py-2 hover:bg-[var(--surface)] hover:text-[var(--text-main)]" href="#workflow">
            Workflow
          </a>
          <Link className="rounded-lg px-3 py-2 hover:bg-[var(--surface)] hover:text-[var(--text-main)]" to={routes.projects}>
            Projects
          </Link>
        </nav>
        <div className="ml-auto flex items-center gap-2">
          <ThemeToggle />
          <Link className="rf-btn" to={routes.login}>
            로그인
          </Link>
          <Link className="rf-btn rf-btn--primary" to={routes.project(demoProjectId)}>
            시작하기
          </Link>
        </div>
      </header>
      <section className="hero-grid">
        <div className="hero-copy">
          <p className="rf-eyebrow">Room reconstruction workspace</p>
          <h1>사진이 방이 되는 순간</h1>
          <p>
            실제 방 사진을 바탕으로 소스 이미지, 재구성 상태, 2D/3D 편집을 한 흐름에서 이어가는 데스크탑 작업공간입니다.
          </p>
          <div className="hero-actions">
            <Link className="rf-btn rf-btn--primary" to={routes.projects}>
              내 프로젝트
            </Link>
            <Link className="rf-btn" to={routes.editor(demoProjectId)}>
              에디터 보기
            </Link>
          </div>
        </div>
        <div className="hero-visual" aria-label="RoomForge room preview">
          <img src="/assets/room.png" alt="" />
          <div className="hero-badge">
            <span className="status-pill status-pill--accent">CV preview</span>
            <strong>Metric room model</strong>
          </div>
        </div>
      </section>
    </main>
  )
}
