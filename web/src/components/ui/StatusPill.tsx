type StatusTone = 'success' | 'accent' | 'warning'

export function StatusPill({ label, tone = 'accent' }: { label: string; tone?: StatusTone }) {
  return <span className={`status-pill status-pill--${tone}`}>{label}</span>
}
