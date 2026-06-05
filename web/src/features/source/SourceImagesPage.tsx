import { Camera, Plus, RotateCcw, Smartphone, Trash2, Upload } from 'lucide-react'
import { useParams } from 'react-router-dom'

import { ProductShell } from '../../components/shell/ProductShell'
import { StatePanel } from '../../components/ui/StatePanel'
import { StatusPill } from '../../components/ui/StatusPill'
import { demoProjectId } from '../../lib/routes'
import { routes } from '../../lib/routes'
import { sourceDirections, type SourceDirection } from '../projects/projectData'
import { useProject } from '../projects/projectRepository'

export function SourceImagesPage() {
  const projectId = useParams().projectId ?? demoProjectId
  const { project, status, error } = useProject(projectId)
  const filledCount = sourceDirections.filter((direction) => direction.filled && direction.key !== 'ROOM').length

  if (!project && status === 'loading') {
    return <StatePanel eyebrow="Source" title="소스 이미지를 불러오는 중입니다" body="프로젝트 접근 권한과 업로드 상태를 확인하고 있습니다." />
  }

  if (!project) {
    return (
      <StatePanel
        eyebrow="Source"
        title="프로젝트를 찾을 수 없습니다"
        body={error ?? '요청한 프로젝트가 없거나 현재 계정에 접근 권한이 없습니다.'}
        action={<a className="rf-btn rf-btn--primary" href={routes.projects}>프로젝트 목록</a>}
      />
    )
  }

  return (
    <ProductShell active="source" project={project}>
      <header className="page-head">
        <div>
          <h1>소스 이미지</h1>
          <p>방을 위에서 보고 둘러싼 8개 각도로 촬영을 채우고, 그 밖의 디테일 사진을 추가합니다.</p>
        </div>
        <div className="workspace-toolbar">
          <button className="rf-btn" type="button">
            <Upload size={16} />
            업로드
          </button>
          <button className="rf-btn rf-btn--primary" type="button">
            <RotateCcw size={15} />
            재구성 다시 실행
          </button>
        </div>
      </header>

      <section className="coverage-banner">
        <span className="coverage-icon"><Camera size={20} /></span>
        <div>
          <strong>8개 각도 중 {filledCount}개 촬영됨 · <span>2개</span>가 비어 있어요</strong>
          <p>현재 상태로 재구성은 가능하지만, 비어 있는 각도를 채우면 모서리 정확도가 올라갑니다.</p>
        </div>
        <button className="rf-btn" type="button">
          <Smartphone size={15} />
          앱으로 빈 각도 촬영
        </button>
      </section>

      <section className="source-layout">
        <div className="source-main">
          <div className="section-title-row">
            <h2>각도별 촬영</h2>
            <StatusPill label={`${filledCount} / 8`} tone="warning" />
          </div>

          <div className="capture-grid" aria-label="각도별 촬영 슬롯">
            {sourceDirections.map((direction) => (
              <CaptureCell direction={direction} key={direction.key} />
            ))}
          </div>
        </div>

        <aside className="source-guide">
          <article className="summary-card">
            <h2>왜 8개 각도인가요?</h2>
            <p>방을 위에서 보고 둘러싼 여덟 각도에서 고르게 찍으면, 벽·모서리·개구부가 빠짐없이 겹쳐 재구성 정확도가 올라갑니다.</p>
            <ul>
              <li>각 각도에서 방 전체가 프레임에 들어오게</li>
              <li>인접한 각도끼리 시야가 30~50% 겹치게</li>
              <li>모서리 각도가 모서리 정확도를 좌우</li>
            </ul>
          </article>
          <article className="app-guide-card">
            <span><Smartphone size={20} /></span>
            <div>
              <strong>앱 가이드 촬영</strong>
              <p>앱이 각도를 안내하며 빈 칸을 채워줍니다.</p>
            </div>
            <button type="button">연결</button>
          </article>
        </aside>
      </section>

      <section className="extra-source-section">
        <div className="section-title-row">
          <h2>추가 사진</h2>
          <StatusPill label="+@" tone="accent" />
          <span>특정 각도에 매이지 않는 디테일·접사 12장</span>
        </div>
        <div className="extra-grid">
          <button className="extra-cell extra-cell--add" type="button">
            <Plus size={20} />
            <span>추가</span>
          </button>
          {Array.from({ length: 11 }, (_, index) => (
            <div className="extra-cell" key={index}>
              <img src="/assets/room.png" alt="" style={{ filter: `brightness(${0.58 + (index % 6) * 0.07}) saturate(.86)` }} />
              <button type="button" aria-label="삭제"><Trash2 size={13} /></button>
            </div>
          ))}
        </div>
      </section>
    </ProductShell>
  )
}

function CaptureCell({ direction }: { direction: SourceDirection }) {
  if (direction.key === 'ROOM') {
    return (
      <div className="capture-cell capture-cell--room">
        <span>위에서 본 방</span>
        <svg viewBox="0 0 120 120" aria-hidden="true">
          <rect x="16" y="24" width="88" height="74" rx="4" />
          <line x1="46" y1="24" x2="74" y2="24" />
          <path d="M16 70a14 14 0 0 0 14 14" />
          <rect x="60" y="42" width="34" height="42" rx="2" />
        </svg>
        <strong>{direction.label}</strong>
      </div>
    )
  }

  if (!direction.filled) {
    return (
      <button className="capture-cell capture-cell--empty" type="button">
        <Camera size={22} />
        <span>촬영 필요</span>
      </button>
    )
  }

  return (
    <div className="capture-cell capture-cell--filled">
      <img src="/assets/room.png" alt="" style={{ filter: `brightness(${direction.brightness ?? 0.8}) saturate(.9)` }} />
      {direction.quality === 'warn' && <StatusPill label="흐릿함" tone="warning" />}
      <div className="capture-actions">
        <span>교체</span>
        <button type="button" aria-label={`${direction.label} 삭제`}><Trash2 size={13} /></button>
      </div>
    </div>
  )
}
