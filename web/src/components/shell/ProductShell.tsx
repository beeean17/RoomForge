import { NavLink } from 'react-router-dom'

import { Brand } from './Brand'
import { ThemeToggle } from './ThemeToggle'
import { demoProjectId, routes } from '../../lib/routes'

type ProductShellProps = {
  active?: 'projects' | 'overview' | 'source' | 'status' | 'editor' | 'admin'
  children: React.ReactNode
}

const projectLinks = [
  { key: 'overview', label: '개요', to: routes.project(demoProjectId) },
  { key: 'source', label: '소스 이미지', to: routes.source(demoProjectId) },
  { key: 'status', label: '재구성 상태', to: routes.status(demoProjectId) },
  { key: 'editor', label: '에디터', to: routes.editor(demoProjectId) },
]

export function ProductShell({ active = 'projects', children }: ProductShellProps) {
  return (
    <div className="rf-page">
      <header className="product-topbar">
        <Brand />
        <nav aria-label="상단 경로" className="hidden md:flex items-center gap-2 text-[13px] text-[var(--text-dim)]">
          <NavLink to={routes.projects}>프로젝트</NavLink>
          {active !== 'projects' && <span>/</span>}
          {active !== 'projects' && <span className="text-[var(--text-main)]">거실 리노베이션</span>}
        </nav>
        <div className="ml-auto flex items-center gap-2">
          <ThemeToggle />
          <button className="grid h-9 w-9 place-items-center rounded-full text-[12px] font-extrabold text-white" style={{ background: 'linear-gradient(135deg,#8fb4ff,#80c7c2)' }}>
            SY
          </button>
        </div>
      </header>
      <aside className="product-sidebar" aria-label="워크스페이스 탐색">
        <NavLink className={({ isActive }) => `nav-link ${isActive || active === 'projects' ? 'is-active' : ''}`} to={routes.projects}>
          내 프로젝트
        </NavLink>
        <div className="my-2 h-px bg-[var(--line-soft)]" />
        <p className="rf-eyebrow px-3 pb-1">현재 프로젝트</p>
        {projectLinks.map((link) => (
          <NavLink
            className={() => `nav-link ${active === link.key ? 'is-active' : ''}`}
            key={link.key}
            to={link.to}
          >
            {link.label}
          </NavLink>
        ))}
        <div className="mt-auto rounded-[12px] border border-[var(--line-soft)] p-3" style={{ background: 'var(--panel)' }}>
          <p className="m-0 text-[12px] font-bold text-[var(--text-main)]">모바일 앱</p>
          <p className="mt-1 text-[11.5px] text-[var(--text-muted)]">가이드 촬영과 업로드는 native 앱에서 진행합니다.</p>
        </div>
      </aside>
      <main className="product-main">{children}</main>
    </div>
  )
}
