import {
  AlertTriangle,
  ArrowLeft,
  ArrowRight,
  Check,
  Clock,
  FileText,
  List,
  RefreshCw,
  Shield,
  X,
} from 'lucide-react'
import { Link, useParams } from 'react-router-dom'

import { Brand } from '../../components/shell/Brand'
import { ThemeToggle } from '../../components/shell/ThemeToggle'
import { StatusPill } from '../../components/ui/StatusPill'

type AdminJobStatus = 'completed' | 'processing' | 'review_required' | 'failed' | 'queued'

type AdminJob = {
  id: string
  project: string
  user: string
  status: AdminJobStatus
  progress: string
  startedAt: string
}

const adminJobs: AdminJob[] = [
  { id: 'J-2061', project: '침실 A동', user: 'kim@studio.co', status: 'processing', progress: '62%', startedAt: '방금' },
  { id: 'J-2060', project: '사무실 회의실', user: 'lee@acme.io', status: 'review_required', progress: '겹침 부족', startedAt: '3분 전' },
  { id: 'J-2059', project: '거실 리노베이션', user: 'sy00nb7907', status: 'completed', progress: '4m 12s', startedAt: '12분 전' },
  { id: 'J-2058', project: '원룸 스튜디오', user: 'park@home.kr', status: 'failed', progress: '정합 단계', startedAt: '20분 전' },
  { id: 'J-2057', project: '발코니 확장', user: 'sy00nb7907', status: 'completed', progress: '3m 48s', startedAt: '34분 전' },
  { id: 'J-2056', project: '주방 리모델링', user: 'choi@reno.kr', status: 'queued', progress: '대기열 #3', startedAt: '1시간 전' },
]

const auditRows = [
  ['10:42:18', 'sy00nb7907', 'job.retry', '#J-2058', '성공', 'rcpt_9f2a31'],
  ['10:42:05', 'sy00nb7907', 'job.retry.request', '#J-2058', '성공', 'rcpt_9f2a30'],
  ['10:31:50', 'kim@studio.co', 'job.create', '#J-2061', '성공', '—'],
  ['10:24:11', 'guest@x.io', 'admin.access', '/admin', '거부', 'rcpt_9f29c7'],
  ['10:18:02', 'system', 'job.failed', '#J-2058', '—', '—'],
]

const job = adminJobs.find((item) => item.id === 'J-2058') ?? adminJobs[3]

export function AdminDashboardPage() {
  return (
    <AdminLayout active="dashboard">
      <header className="page-head">
        <div>
          <p className="rf-eyebrow admin-eyebrow">Operations</p>
          <h1>대시보드</h1>
          <p>재구성 큐, 실패율, 최근 작업을 운영자 관점에서 확인합니다.</p>
        </div>
        <div className="workspace-toolbar">
          <button className="rf-btn" type="button">최근 24시간</button>
          <button className="rf-btn" type="button"><RefreshCw size={15} />새로고침</button>
        </div>
      </header>

      <section className="admin-kpi-grid">
        {[
          ['대기 중', '8', '큐', 'muted'],
          ['진행 중', '4', '워커 가동', 'accent'],
          ['오늘 완료', '126', '+18%', 'success'],
          ['실패 · 24h', '4', '3.1% 에러율', 'danger'],
        ].map(([label, value, detail, tone]) => (
          <article className="admin-card admin-kpi" key={label}>
            <span>{label}</span>
            <strong>{value}</strong>
            <small className={`admin-tone-${tone}`}>{detail}</small>
          </article>
        ))}
      </section>

      <section className="admin-dashboard-grid">
        <AdminTableCard title="최근 작업" link={<Link to="/admin/jobs">전체 보기 →</Link>} jobs={adminJobs.slice(0, 5)} compact />
        <aside className="admin-side-stack">
          <article className="admin-card">
            <header className="admin-card-head"><h2>최근 7일 처리량</h2><span>완료 작업</span></header>
            <div className="admin-bar-chart">
              {[88, 102, 76, 119, 95, 134, 126].map((value, index, all) => (
                <span key={index}>
                  <i style={{ height: `${Math.round(value / Math.max(...all) * 100)}%` }} />
                  <small>{['월', '화', '수', '목', '금', '토', '일'][index]}</small>
                </span>
              ))}
            </div>
          </article>
          <SystemHealthCard />
          <article className="admin-attention">
            <div><AlertTriangle size={16} /><strong>주의가 필요한 작업</strong><span>3</span></div>
            <p>실패 2건 · 재시도 한도 초과 1건. 작업 목록에서 확인하세요.</p>
            <Link to="/admin/jobs">실패 작업 보기 <ArrowRight size={13} /></Link>
          </article>
        </aside>
      </section>
    </AdminLayout>
  )
}

export function AdminJobsPage() {
  return (
    <AdminLayout active="jobs">
      <header className="page-head">
        <div>
          <p className="rf-eyebrow admin-eyebrow">Job Operations</p>
          <h1>작업</h1>
          <p>재구성 작업을 조회하고, 실패 작업은 권한 검증 후 재시도합니다.</p>
        </div>
      </header>
      <div className="admin-tabs">
        {['전체 142', '대기 8', '진행 중 4', '검토 필요 6', '완료 118', '실패 6'].map((tab, index) => (
          <button className={index === 0 ? 'is-active' : ''} key={tab} type="button">{tab}</button>
        ))}
      </div>
      <AdminTableCard title="작업 목록" jobs={adminJobs} />
      <p className="admin-footnote"><Shield size={14} />재시도·감사 작업은 Callable Function을 통해 권한 검증 후 실행됩니다.</p>
    </AdminLayout>
  )
}

export function AdminJobDetailPage() {
  const jobId = useParams().jobId ?? job.id
  return (
    <AdminLayout active="jobs" crumb={jobId}>
      <header className="page-head">
        <div>
          <p className="rf-eyebrow admin-eyebrow">Job Detail</p>
          <h1>#{jobId}</h1>
          <p>{job.project} · {job.user} · 정합 실패를 조사합니다.</p>
        </div>
        <div className="workspace-toolbar">
          <Link className="rf-btn" to={`/admin/jobs/${jobId}/audit`}><FileText size={15} />감사</Link>
          <Link className="rf-btn rf-btn--admin" to={`/admin/jobs/${jobId}/retry`}><RefreshCw size={15} />재시도</Link>
        </div>
      </header>
      <section className="admin-detail-grid">
        <article className="admin-card">
          <header className="admin-card-head"><h2>재구성 단계</h2><StatusPill label="failed" tone="danger" /></header>
          <ul className="admin-step-list">
            {['업로드 검증', '특징점 추출'].map((step) => <li className="is-done" key={step}><Check size={14} />{step}</li>)}
            <li className="is-failed"><X size={14} />카메라 정합 <span>겹침 부족</span></li>
            {['포인트 클라우드', '메시·평면 추출', '후보 geometry'].map((step) => <li key={step}><Clock size={14} />{step}</li>)}
          </ul>
        </article>
        <article className="admin-card admin-log-card">
          <header className="admin-card-head"><h2>로그</h2><span>RECON_OVERLAP</span></header>
          <pre>{`12:04:21 INFO  업로드 18장 검증 완료
12:04:48 INFO  특징점 추출 완료
12:06:02 WARN  인접 뷰 겹침 38%
12:06:13 ERROR 정합 수렴 실패
12:06:13 ERROR status=failed`}</pre>
        </article>
        <article className="admin-card">
          <h2>작업 메타데이터</h2>
          <dl className="metric-dl">
            <dt>사용자</dt><dd>{job.user}</dd>
            <dt>프로젝트</dt><dd>{job.project}</dd>
            <dt>재시도</dt><dd>1 / 3</dd>
            <dt>워커</dt><dd>worker-03</dd>
          </dl>
        </article>
        <article className="admin-card">
          <header className="admin-card-head"><h2>최근 활동</h2><Link to={`/admin/jobs/${jobId}/audit`}>전체 감사 →</Link></header>
          <AuditTimeline compact />
        </article>
      </section>
    </AdminLayout>
  )
}

export function AdminJobRetryPage() {
  const jobId = useParams().jobId ?? job.id
  return (
    <AdminLayout active="jobs" crumb={`${jobId} retry`}>
      <div className="admin-modal-backdrop">
        <section className="admin-modal" role="dialog" aria-modal="true" aria-label="작업 재시도">
          <header>
            <span><RefreshCw size={20} /></span>
            <div><h1>작업 재시도</h1><p>#{jobId} · {job.project}</p></div>
            <Link to={`/admin/jobs/${jobId}`} aria-label="닫기"><X size={18} /></Link>
          </header>
          <div className="admin-modal-body">
            <p>원본 작업은 보존되고, 연결된 재시도 작업이 새로 큐에 등록됩니다. 실행 결과와 사유는 감사 로그에 기록됩니다.</p>
            <label>
              <span>사유</span>
              <textarea defaultValue="정합 실패 — 겹침 부족 보완 후 재처리" />
            </label>
            <div className="retry-option is-active"><Check size={15} /><strong>동일 설정으로 재시도</strong></div>
            <div className="retry-option"><Clock size={15} /><strong>설정 조정 후 재시도</strong></div>
          </div>
          <footer>
            <Link className="rf-btn" to={`/admin/jobs/${jobId}`}>취소</Link>
            <button className="rf-btn rf-btn--admin" type="button"><RefreshCw size={15} />재시도 작업 생성</button>
          </footer>
        </section>
      </div>
    </AdminLayout>
  )
}

export function AdminJobAuditPage() {
  const jobId = useParams().jobId ?? job.id
  return (
    <AdminLayout active="jobs" crumb={`${jobId} audit`}>
      <header className="page-head">
        <div>
          <p className="rf-eyebrow admin-eyebrow">Job Audit</p>
          <h1>작업 감사 #{jobId}</h1>
          <p>권한이 필요한 행위는 영수증 ID와 함께 변경 불가능하게 기록됩니다.</p>
        </div>
        <Link className="rf-btn" to={`/admin/jobs/${jobId}`}><ArrowLeft size={15} />작업으로</Link>
      </header>
      <article className="admin-card">
        <AuditTimeline />
      </article>
    </AdminLayout>
  )
}

export function AdminAuditPage() {
  return (
    <AdminLayout active="audit">
      <header className="page-head">
        <div>
          <p className="rf-eyebrow admin-eyebrow">Global Audit</p>
          <h1>감사 로그</h1>
          <p>관리자 권한, 재시도, job 변경 이벤트를 시간순으로 확인합니다.</p>
        </div>
      </header>
      <div className="admin-tabs">
        {['전체', '권한', '작업', '재시도', '거부'].map((tab, index) => (
          <button className={index === 0 ? 'is-active' : ''} key={tab} type="button">{tab}</button>
        ))}
      </div>
      <article className="admin-card admin-table-card">
        <table className="admin-table">
          <thead><tr><th>시각</th><th>주체</th><th>이벤트</th><th>대상</th><th>결과</th><th>영수증</th></tr></thead>
          <tbody>
            {auditRows.map((row) => (
              <tr key={row.join('-')}>{row.map((cell) => <td key={cell}>{cell}</td>)}</tr>
            ))}
          </tbody>
        </table>
      </article>
    </AdminLayout>
  )
}

export function AdminAccessDeniedPage() {
  return (
    <main className="access-denied-page">
      <header><Brand /><div className="top-actions"><ThemeToggle /></div></header>
      <section>
        <span><Shield size={28} /></span>
        <p className="rf-eyebrow admin-eyebrow">Access denied</p>
        <h1>관리자 권한이 필요합니다</h1>
        <p>이 페이지는 RoomForge 운영 관리자만 접근할 수 있어요. 현재 계정에는 관리자 역할이 부여되어 있지 않습니다.</p>
        <Link className="rf-btn rf-btn--primary" to="/projects">프로젝트로 돌아가기</Link>
      </section>
    </main>
  )
}

function AdminLayout({ active, crumb, children }: { active: 'dashboard' | 'jobs' | 'audit'; crumb?: string; children: React.ReactNode }) {
  return (
    <main className="admin-page">
      <header className="admin-topbar">
        <Brand />
        <nav className="top-crumb">
          <Link to="/admin">Admin</Link>
          {crumb && <span>/</span>}
          {crumb && <span>{crumb}</span>}
        </nav>
        <div className="top-actions">
          <StatusPill label="admin required" tone="warning" />
          <ThemeToggle />
          <button className="account-avatar" type="button" aria-label="계정">SY</button>
        </div>
      </header>
      <aside className="admin-sidebar" aria-label="관리자 탐색">
        <p className="nav-grouptitle">Operations</p>
        <Link className={`nav-link ${active === 'dashboard' ? 'is-active' : ''}`} to="/admin"><Shield size={17} />대시보드</Link>
        <Link className={`nav-link ${active === 'jobs' ? 'is-active' : ''}`} to="/admin/jobs"><List size={17} />작업 <span className="nav-badge">142</span></Link>
        <Link className={`nav-link ${active === 'audit' ? 'is-active' : ''}`} to="/admin/audit"><FileText size={17} />감사 로그</Link>
        <div className="mobile-handoff">
          <div className="mobile-handoff-title"><Shield size={15} />권한 경계</div>
          <p>Admin API는 일반 사용자 권한과 분리된 Callable Function/Rules 검증을 전제로 합니다.</p>
        </div>
      </aside>
      <section className="admin-main">
        <div className="admin-content">{children}</div>
      </section>
    </main>
  )
}

function AdminTableCard({ title, link, jobs, compact = false }: { title: string; link?: React.ReactNode; jobs: AdminJob[]; compact?: boolean }) {
  return (
    <article className="admin-card admin-table-card">
      <header className="admin-card-head"><h2>{title}</h2>{link}</header>
      <table className="admin-table">
        <thead><tr><th>작업 ID</th><th>프로젝트</th>{!compact && <th>사용자</th>}<th>상태</th><th>{compact ? '시각' : '진행 / 소요'}</th>{!compact && <th>액션</th>}</tr></thead>
        <tbody>{jobs.map((item) => <AdminJobRow compact={compact} job={item} key={item.id} />)}</tbody>
      </table>
    </article>
  )
}

function AdminJobRow({ job: item, compact }: { job: AdminJob; compact: boolean }) {
  return (
    <tr>
      <td><Link to={`/admin/jobs/${item.id}`}>#{item.id}</Link></td>
      <td>{item.project}</td>
      {!compact && <td>{item.user}</td>}
      <td><JobBadge status={item.status} /></td>
      <td>{compact ? item.startedAt : item.progress}</td>
      {!compact && (
        <td>
          {item.status === 'failed' && <Link className="admin-action admin-action--primary" to={`/admin/jobs/${item.id}/retry`}>재시도</Link>}
          <Link className="admin-action" to={`/admin/jobs/${item.id}`}>상세</Link>
        </td>
      )}
    </tr>
  )
}

function JobBadge({ status }: { status: AdminJobStatus }) {
  const map: Record<AdminJobStatus, { label: string; tone: 'success' | 'accent' | 'warning' | 'danger' | 'muted' }> = {
    completed: { label: '완료', tone: 'success' },
    processing: { label: '진행 중', tone: 'accent' },
    review_required: { label: '검토 필요', tone: 'warning' },
    failed: { label: '실패', tone: 'danger' },
    queued: { label: '대기', tone: 'muted' },
  }
  return <StatusPill label={map[status].label} tone={map[status].tone} />
}

function SystemHealthCard() {
  return (
    <article className="admin-card">
      <h2>시스템 상태</h2>
      <ul className="admin-health">
        {[
          ['재구성 워커', '정상 · 4/4', 'success'],
          ['큐 길이', '8 대기', 'success'],
          ['평균 처리', '4m 21s ↑', 'warning'],
          ['24h 에러율', '3.1%', 'success'],
        ].map(([label, value, tone]) => (
          <li key={label}><span className={`history-dot history-dot--${tone === 'warning' ? 'warning' : 'success'}`} />{label}<strong>{value}</strong></li>
        ))}
      </ul>
    </article>
  )
}

function AuditTimeline({ compact = false }: { compact?: boolean }) {
  const rows = [
    ['재시도 작업 생성', 'admin · sy00nb7907', '방금', '연결 재시도 #J-2062 생성 · 동일 설정', 'rcpt_9f2a31'],
    ['재시도 요청', 'admin · sy00nb7907', '1분 전', '사유: 정합 실패 — 겹침 부족 보완 후 재처리', 'rcpt_9f2a30'],
    ['작업 실패', 'system', '20분 전', 'RECON_OVERLAP · 카메라 정합 실패', '—'],
    ['처리 시작', 'worker-03', '22분 전', '업로드 18장 검증 후 재구성 시작', '—'],
  ]
  return (
    <ol className={`audit-timeline ${compact ? 'is-compact' : ''}`}>
      {rows.map(([title, who, at, detail, receipt]) => (
        <li key={`${title}-${at}`}>
          <span />
          <div>
            <strong>{title}</strong>
            <small>{who} · {at}</small>
            {!compact && <p>{detail}</p>}
            {!compact && <em>{receipt}</em>}
          </div>
        </li>
      ))}
    </ol>
  )
}
