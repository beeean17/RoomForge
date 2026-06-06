import { Activity, Archive, ChevronDown, Folder, Images, Layers, RefreshCw, Ruler, Search, Smartphone, Users } from 'lucide-react'
import { Link, NavLink, useNavigate, useSearchParams } from 'react-router-dom'
import { type FormEvent, useEffect, useRef, useState } from 'react'

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
  const navigate = useNavigate()
  const [searchParams] = useSearchParams()
  const [accountOpen, setAccountOpen] = useState(false)
  const [workspaceOpen, setWorkspaceOpen] = useState(false)
  const [searchDraft, setSearchDraft] = useState(searchParams.get('q') ?? '')
  const accountRef = useRef<HTMLDivElement | null>(null)
  const workspaceRef = useRef<HTMLDivElement | null>(null)
  const searchInputRef = useRef<HTMLInputElement | null>(null)
  const searchValueFromUrl = searchParams.get('q') ?? ''
  const projectScope = searchParams.get('scope') ?? 'mine'
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
  const workspaceScopes = [
    { key: 'mine', label: '내 프로젝트', to: routes.projects, icon: Folder, badge: '6' },
    { key: 'shared', label: '공유됨', to: `${routes.projects}?scope=shared`, icon: Users, badge: undefined },
    { key: 'templates', label: '템플릿', to: `${routes.projects}?scope=templates`, icon: Layers, badge: undefined },
    { key: 'archive', label: '보관함', to: `${routes.projects}?scope=archive`, icon: Archive, badge: undefined },
  ] as const

  useEffect(() => {
    if (!accountOpen && !workspaceOpen) {
      return undefined
    }

    const closeOnOutsidePointer = (event: PointerEvent) => {
      const target = event.target as Node
      if (!accountRef.current?.contains(target)) {
        setAccountOpen(false)
      }
      if (!workspaceRef.current?.contains(target)) {
        setWorkspaceOpen(false)
      }
    }

    window.addEventListener('pointerdown', closeOnOutsidePointer)
    return () => window.removeEventListener('pointerdown', closeOnOutsidePointer)
  }, [accountOpen, workspaceOpen])

  useEffect(() => {
    setSearchDraft(searchValueFromUrl)
  }, [searchValueFromUrl])

  useEffect(() => {
    const focusSearch = (event: KeyboardEvent) => {
      if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 'k') {
        event.preventDefault()
        searchInputRef.current?.focus()
      }
    }

    window.addEventListener('keydown', focusSearch)
    return () => window.removeEventListener('keydown', focusSearch)
  }, [])

  async function handleSignOut() {
    await auth.signOut()
    setAccountOpen(false)
    navigate(routes.landing)
  }

  function handleSearch(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const query = searchDraft.trim()
    const params = new URLSearchParams(searchParams)
    params.delete('scope')
    if (query) {
      params.set('q', query)
    } else {
      params.delete('q')
    }
    navigate(`${routes.projects}${params.toString() ? `?${params.toString()}` : ''}`)
  }

  return (
    <div className="rf-page">
      <header className="product-topbar">
        <Brand />
        <nav aria-label="상단 경로" className="top-crumb">
          <NavLink to={routes.projects}>프로젝트</NavLink>
          {active !== 'projects' && <span>/</span>}
          {active !== 'projects' && <span>{project?.name ?? '거실 리노베이션'}</span>}
        </nav>
        <form className="top-search" role="search" onSubmit={handleSearch}>
          <Search size={15} />
          <input
            ref={searchInputRef}
            name="q"
            type="search"
            placeholder="프로젝트 검색"
            value={searchDraft}
            onChange={(event) => setSearchDraft(event.currentTarget.value)}
          />
          <kbd>⌘K</kbd>
        </form>
        <div className="top-actions">
          <ThemeToggle />
          <div className="rf-menu-wrap" ref={accountRef}>
            <button
              className="account-avatar"
              type="button"
              aria-label="계정"
              aria-expanded={accountOpen}
              onClick={() => setAccountOpen((open) => !open)}
            >
              {initials}
            </button>
            {accountOpen && (
              <div className="rf-popover rf-popover--right account-menu" role="menu">
                <strong>{userLabel}</strong>
                <small>{userEmail}</small>
                <Link role="menuitem" to={routes.projects} onClick={() => setAccountOpen(false)}>내 프로젝트</Link>
                {auth.status === 'signed-in' ? (
                  <button role="menuitem" type="button" onClick={handleSignOut}>로그아웃</button>
                ) : (
                  <Link role="menuitem" to={routes.login} onClick={() => setAccountOpen(false)}>로그인</Link>
                )}
              </div>
            )}
          </div>
        </div>
      </header>

      <aside className="product-sidebar" aria-label="워크스페이스 탐색">
        <div className="rf-menu-wrap" ref={workspaceRef}>
          <button
            className="workspace-switcher"
            type="button"
            aria-expanded={workspaceOpen}
            onClick={() => setWorkspaceOpen((open) => !open)}
          >
            <span className="workspace-avatar">{initials}</span>
            <span className="workspace-copy">
              <span>{userLabel}</span>
              <small>{userEmail}</small>
            </span>
            <ChevronDown size={15} />
          </button>
          {workspaceOpen && (
            <div className="rf-popover workspace-menu" role="menu">
              {workspaceScopes.map((scope) => (
                <Link key={scope.key} role="menuitem" to={scope.to} onClick={() => setWorkspaceOpen(false)}>
                  <scope.icon size={15} />
                  {scope.label}
                </Link>
              ))}
            </div>
          )}
        </div>

        <div className="sidebar-rule" />
        <nav className="sidebar-nav" aria-label="프로젝트 범위">
          {workspaceScopes.map((scope) => (
            <Link
              className={`nav-link ${active === 'projects' && projectScope === scope.key ? 'is-active' : ''}`}
              key={scope.key}
              to={scope.to}
            >
              <scope.icon size={16} />
              {scope.label}
              {scope.badge && <span className="nav-badge">{scope.badge}</span>}
            </Link>
          ))}
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
