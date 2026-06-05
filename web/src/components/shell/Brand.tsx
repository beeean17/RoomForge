import { Link } from 'react-router-dom'

export function Brand({ to = '/' }: { to?: string }) {
  return (
    <Link className="rf-brand" to={to} aria-label="RoomForge 홈">
      <span className="rf-brand-mark" aria-hidden="true" />
      RoomForge
    </Link>
  )
}
