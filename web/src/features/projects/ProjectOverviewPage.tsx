import { Link, useParams } from 'react-router-dom'

import { ProductShell } from '../../components/shell/ProductShell'
import { StatusPill } from '../../components/ui/StatusPill'
import { demoProjectId, routes } from '../../lib/routes'

export function ProjectOverviewPage() {
  const projectId = useParams().projectId ?? demoProjectId

  return (
    <ProductShell active="overview">
      <header className="page-head">
        <div>
          <p className="rf-eyebrow">Project hub</p>
          <h1>거실 리노베이션</h1>
          <p>소스 → 재구성 → 편집으로 이어지는 단일 프로젝트 허브입니다.</p>
        </div>
        <Link className="rf-btn rf-btn--primary ml-auto" to={routes.editor(projectId)}>
          에디터 열기
        </Link>
      </header>
      <section className="grid grid-cols-1 gap-5 xl:grid-cols-[1.7fr_1fr]">
        <div className="rf-panel overflow-hidden">
          <div className="relative aspect-video bg-[#080808]">
            <img className="absolute inset-0 h-full w-full object-cover brightness-[0.78] saturate-[0.86]" src="/assets/room.png" alt="" />
            <div className="absolute bottom-4 left-4 flex gap-2">
              <Link className="rf-btn rf-btn--primary" to={routes.editor(projectId)}>
                3D 에디터
              </Link>
              <Link className="rf-btn" to={routes.source(projectId)}>
                소스 이미지
              </Link>
            </div>
          </div>
        </div>
        <div className="grid gap-4">
          <article className="route-card">
            <StatusPill label="재구성 완료" tone="success" />
            <h2 className="mt-4">다음 단계</h2>
            <p>에디터에서 벽, 바닥, 개구부와 가구 배치를 다듬습니다.</p>
          </article>
          <article className="route-card">
            <StatusPill label="이미지 18장" />
            <h2 className="mt-4">소스 커버리지</h2>
            <p>8개 기준 각도와 추가 디테일 사진이 프로젝트에 연결됩니다.</p>
          </article>
        </div>
      </section>
    </ProductShell>
  )
}
