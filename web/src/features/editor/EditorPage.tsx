import { useParams } from 'react-router-dom'

import { Brand } from '../../components/shell/Brand'
import { ThemeToggle } from '../../components/shell/ThemeToggle'
import { StatusPill } from '../../components/ui/StatusPill'
import { demoProjectId } from '../../lib/routes'

export function EditorPage() {
  const projectId = useParams().projectId ?? demoProjectId

  return (
    <main className="rf-page">
      <header className="product-topbar">
        <Brand />
        <span className="text-[13px] font-semibold text-[var(--text-dim)]">/ 거실 리노베이션 / 에디터</span>
        <div className="ml-auto flex items-center gap-2">
          <StatusPill label="모든 변경 저장됨" tone="success" />
          <ThemeToggle />
        </div>
      </header>
      <section className="editor-frame" data-project-id={projectId}>
        <aside className="editor-rail" aria-label="에디터 도구">
          {['선택', '이동', '벽', '개구부', '가구', '측정'].map((tool, index) => (
            <button className={`rf-btn !h-10 !w-10 !p-0 ${index === 0 ? 'rf-btn--primary' : ''}`} key={tool} title={tool} type="button">
              {tool.slice(0, 1)}
            </button>
          ))}
        </aside>
        <aside className="editor-library">
          <p className="rf-eyebrow">Library</p>
          <h2 className="m-0 text-lg font-extrabold">가구 라이브러리</h2>
          <div className="mt-4 grid grid-cols-2 gap-2">
            {['침대', '소파', '책상', '수납'].map((item) => (
              <button className="route-card !min-h-[92px] !p-3 text-left" key={item} type="button">
                <strong>{item}</strong>
                <p className="!mb-0 text-[12px]">preset</p>
              </button>
            ))}
          </div>
        </aside>
        <div className="editor-canvas-shell">
          <div className="editor-toolbar">
            <button className="rf-btn rf-btn--primary !min-h-8" type="button">
              3D
            </button>
            <button className="rf-btn !min-h-8" type="button">
              2D 평면도
            </button>
            <button className="rf-btn !min-h-8 ml-auto" type="button">
              이미지로 내보내기
            </button>
          </div>
          <div className="editor-canvas">
            <div className="editor-room">
              <div className="absolute left-[30%] top-[12%] h-[34%] w-[42%] rounded-lg border-2 border-[var(--accent)] bg-[rgba(143,180,255,0.14)]" />
            </div>
          </div>
        </div>
        <aside className="editor-inspector">
          <p className="rf-eyebrow">Inspector</p>
          <h2 className="m-0 text-lg font-extrabold">침대</h2>
          <dl className="mt-4 grid grid-cols-2 gap-y-3 text-[12.5px]">
            <dt className="text-[var(--text-dim)]">방 크기</dt>
            <dd className="text-right font-bold">5.2 x 6.0 m</dd>
            <dt className="text-[var(--text-dim)]">선택 객체</dt>
            <dd className="text-right font-bold">가구</dd>
            <dt className="text-[var(--text-dim)]">좌표계</dt>
            <dd className="text-right font-bold">meters</dd>
          </dl>
        </aside>
      </section>
    </main>
  )
}
