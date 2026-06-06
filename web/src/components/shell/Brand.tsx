import { type MouseEventHandler } from 'react'
import { Link } from 'react-router-dom'

export function Brand({ onClick, to = '/' }: { onClick?: MouseEventHandler<HTMLAnchorElement>; to?: string }) {
  return (
    <Link className="rf-brand" onClick={onClick} to={to} aria-label="RoomForge 홈">
      <span className="rf-brand-mark" aria-hidden="true" />
      RoomForge
    </Link>
  )
}
