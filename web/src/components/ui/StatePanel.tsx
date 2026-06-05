type StatePanelProps = {
  eyebrow?: string
  title: string
  body: string
  action?: React.ReactNode
}

export function StatePanel({ eyebrow, title, body, action }: StatePanelProps) {
  return (
    <main className="rf-page rf-page--center">
      <section className="state-panel">
        {eyebrow && <p className="rf-eyebrow">{eyebrow}</p>}
        <h1>{title}</h1>
        <p>{body}</p>
        {action && <div className="state-panel-actions">{action}</div>}
      </section>
    </main>
  )
}
