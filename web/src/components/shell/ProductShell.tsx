import { Activity, Archive, ChevronDown, Folder, Images, Layers, RefreshCw, Ruler, Search, Smartphone, Users } from 'lucide-react'
import { NavLink } from 'react-router-dom'

import { Brand } from './Brand'
import { ThemeToggle } from './ThemeToggle'
import { demoProjectId, routes } from '../../lib/routes'
import { useAuth } from '../../features/auth/AuthProvider'
import type { WorkspaceProject } from '../../features/projects/projectData'

type ProductShellProps = {
  active?: 'projects' | 'overview' | 'room' | 'source' | 'status' | 'editor' | 'recovery' | 'admin'
  project?: WorkspaceProject
  children: React.ReactNode
}

export function ProductShell({ active = 'projects', project, children }: ProductShellProps) {
  const auth = useAuth()
  const userLabel = auth.status === 'signed-in' ? auth.user.displayName ?? '개인 워크스페이스' : '개인 워크스페이스'
  const userEmail = auth.status === 'signed-in' ? auth.user.email ?? 'RoomForge 계정' : '로그인 후 프로젝트가 동기화됩니다'
  const initials = auth.status === 'signed-in'
    ? (auth.user.displayName ?? auth.user.email ?? 'SY').slice(0, 2).toUpperCase()
    : 'SY'
  const projectId = project?.id ?? demoProjectId
  const projectLinks = [
    { key: 'overview', label: '개요', to: routes.project(projectId), icon: Folder, badge: undefined, pulse: false },
    { key: 'room', label: '방 치수', to: routes.room(projectId), icon: Ruler, badge: undefined, pulse: false },
    { key: 'source', label: '소스 이미지', to: routes.source(projectId), icon: Images, badge: project?.imageCount ? String(project.imageCount) : undefined, pulse: false },
    { key: 'status', label: '재구성 상태', to: routes.status(projectId), icon: Activity, badge: undefined, pulse: project?.status === 'processing' },
    { key: 'editor', label: '에디터', to: routes.editor(projectId), icon: Layers, badge: undefined, pulse: true },
    { key: 'recovery', label: '복구', to: routes.recovery(projectId), icon: RefreshCw, badge: undefined, pulse: false },
  ] as const

  return (
    <div className="rf-page">
      <header className="product-topbar">
        <Brand />
        <nav aria-label="상단 경로" className="top-crumb">
          <NavLink to={routes.projects}>프로젝트</NavLink>
          {active !== 'projects' && <span>/</span>}
          {active !== 'projects' && <span>{project?.name ?? '거실 리노베이션'}</span>}
        </nav>
        <label className="top-search">
          <Search size={15} />
          <input type="search" placeholder="프로젝트 검색" />
          <kbd>⌘K</kbd>
        </label>
        <div className="top-actions">
          <ThemeToggle />
          <button className="account-avatar" type="button" aria-label="계정">
            {initials}
          </button>
        </div>
      </header>

      <aside className="product-sidebar" aria-label="워크스페이스 탐색">
        <button className="workspace-switcher" type="button">
          <span className="workspace-avatar">{initials}</span>
          <span className="workspace-copy">
            <span>{userLabel}</span>
            <small>{userEmail}</small>
          </span>
          <ChevronDown size={15} />
        </button>

        <div className="sidebar-rule" />
        <nav className="sidebar-nav" aria-label="프로젝트 범위">
          <NavLink className={({ isActive }) => `nav-link ${isActive || active === 'projects' ? 'is-active' : ''}`} to={routes.projects}>
            <Folder size={16} />
            내 프로젝트 <span className="nav-badge">6</span>
          </NavLink>
          <a className="nav-link" href="#shared">
            <Users size={16} />
            공유됨
          </a>
          <a className="nav-link" href="#templates">
            <Layers size={16} />
            템플릿
          </a>
          <a className="nav-link" href="#archive">
            <Archive size={16} />
            보관함
          </a>
        </nav>

        {project && (
          <>
            <div className="sidebar-rule" />
            <div className="current-project-card">
              <span className="current-project-thumb" />
              <span className="workspace-copy">
                <span>{project.name}</span>
                <small>{project.statusLabel} · 편집 단계</small>
              </span>
            </div>
          </>
        )}

        {project && (
          <nav className="sidebar-nav" aria-label="현재 프로젝트">
            <p className="nav-grouptitle">촬영 · 재구성</p>
            {projectLinks.map((link) => (
              link.key !== 'editor' && link.key !== 'recovery' ? (
                <NavLink
                  className={() => `nav-link ${active === link.key ? 'is-active' : ''}`}
                  key={link.key}
                  to={link.to}
                >
                  <link.icon size={16} />
                  {link.label}
                  {link.badge && <span className="nav-badge">{link.badge}</span>}
                  {link.pulse && <span className="nav-dot is-pulsing" />}
                </NavLink>
              ) : null
            ))}
            <p className="nav-grouptitle">편집</p>
            {projectLinks.map((link) => (
              link.key === 'editor' || link.key === 'recovery' ? (
                <NavLink
                  className={() => `nav-link ${active === link.key ? 'is-active' : ''}`}
                  key={link.key}
                  to={link.to}
                >
                  <link.icon size={16} />
                  {link.label}
                  {link.key === 'editor' && <span className="nav-dot is-pulsing" />}
                </NavLink>
              ) : null
            ))}
          </nav>
        )}

        <div className="mobile-handoff">
          <div className="mobile-handoff-title">
            <Smartphone size={15} />
            모바일 앱
          </div>
          <p>카메라 가이드 촬영은 RoomForge 앱에서. 데스크탑은 검토와 편집에 집중합니다.</p>
        </div>
      </aside>

      <main className="product-main">
        <div className="product-content">{children}</div>
      </main>
    </div>
  )
}
