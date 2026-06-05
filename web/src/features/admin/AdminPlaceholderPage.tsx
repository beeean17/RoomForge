import { ProductShell } from '../../components/shell/ProductShell'
import { StatusPill } from '../../components/ui/StatusPill'

export function AdminPlaceholderPage() {
  return (
    <ProductShell active="admin">
      <header className="page-head">
        <div>
          <p className="rf-eyebrow">Admin</p>
          <h1>운영 콘솔</h1>
          <p>Admin route는 데스크탑 React 앱 안에 독립 권한 경계로 남습니다.</p>
        </div>
        <StatusPill label="admin required" tone="warning" />
      </header>
      <section className="card-grid">
        <article className="route-card">
          <StatusPill label="jobs" />
          <h2 className="mt-4">작업 조회</h2>
          <p>Phase 2 이후 Callable Function과 Firestore collection group query로 연결합니다.</p>
        </article>
        <article className="route-card">
          <StatusPill label="audit" tone="warning" />
          <h2 className="mt-4">감사 이력</h2>
          <p>재시도, 권한, artifact 접근 결과를 운영자 관점에서 확인합니다.</p>
        </article>
      </section>
    </ProductShell>
  )
}
