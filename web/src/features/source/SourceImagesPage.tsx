import { useParams } from 'react-router-dom'

import { ProductShell } from '../../components/shell/ProductShell'
import { StatusPill } from '../../components/ui/StatusPill'
import { demoProjectId } from '../../lib/routes'

const slots = ['NW', 'N', 'NE', 'W', 'ROOM', 'E', 'SW', 'S', 'SE']

export function SourceImagesPage() {
  const projectId = useParams().projectId ?? demoProjectId

  return (
    <ProductShell active="source">
      <header className="page-head">
        <div>
          <p className="rf-eyebrow">Project {projectId}</p>
          <h1>소스 이미지</h1>
          <p>데스크탑에서는 파일 업로드와 커버리지 확인을 담당하고, 가이드 촬영은 native 앱으로 넘깁니다.</p>
        </div>
        <button className="rf-btn rf-btn--primary ml-auto" type="button">
          업로드
        </button>
      </header>
      <section className="grid grid-cols-1 gap-6 xl:grid-cols-[minmax(0,620px)_1fr]">
        <div>
          <div className="mb-3 flex items-center gap-2">
            <h2 className="m-0 text-[15px] font-bold">각도별 촬영</h2>
            <StatusPill label="6 / 8" tone="warning" />
          </div>
          <div className="grid grid-cols-3 gap-3">
            {slots.map((slot, index) => (
              <div className="route-card !min-h-[150px]" key={slot}>
                <StatusPill label={slot} tone={index % 4 === 2 ? 'warning' : 'accent'} />
                <p className="mt-10 text-[var(--text-muted)]">{slot === 'ROOM' ? '중앙 기준 이미지' : '주변 각도 이미지'}</p>
              </div>
            ))}
          </div>
        </div>
        <aside className="rf-panel p-5">
          <p className="rf-eyebrow">Native handoff</p>
          <h2 className="m-0 text-xl font-extrabold">앱 가이드 촬영</h2>
          <p className="text-[var(--text-muted)]">실제 카메라 가이드와 업로드 retry는 Flutter native 앱 phase에서 분리 구현합니다.</p>
          <button className="rf-btn mt-4" type="button">
            모바일 앱 연결
          </button>
        </aside>
      </section>
    </ProductShell>
  )
}
