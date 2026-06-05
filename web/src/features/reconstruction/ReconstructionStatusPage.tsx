import { Link, useParams } from 'react-router-dom'

import { ProductShell } from '../../components/shell/ProductShell'
import { StatusPill } from '../../components/ui/StatusPill'
import { demoProjectId, routes } from '../../lib/routes'

const steps = ['이미지 검증', '특징점 매칭', '공간 후보 생성', '품질 판정']

export function ReconstructionStatusPage() {
  const projectId = useParams().projectId ?? demoProjectId

  return (
    <ProductShell active="status">
      <header className="page-head">
        <div>
          <p className="rf-eyebrow">Reconstruction</p>
          <h1>재구성 상태</h1>
          <p>Firestore의 job status vocabulary를 그대로 표시하는 route입니다.</p>
        </div>
        <Link className="rf-btn rf-btn--primary ml-auto" to={routes.editor(projectId)}>
          에디터로 이동
        </Link>
      </header>
      <section className="rf-panel p-6">
        <div className="flex flex-wrap items-center gap-3">
          <StatusPill label="succeeded" tone="success" />
          <h2 className="m-0 text-2xl font-extrabold">재구성이 완료되었습니다</h2>
        </div>
        <div className="mt-6 grid grid-cols-1 gap-3 md:grid-cols-4">
          {steps.map((step) => (
            <article className="route-card !min-h-[130px]" key={step}>
              <StatusPill label="done" tone="success" />
              <h2 className="mt-4">{step}</h2>
            </article>
          ))}
        </div>
      </section>
    </ProductShell>
  )
}
