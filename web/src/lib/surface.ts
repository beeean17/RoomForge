import { useEffect, useState } from 'react'

export type RuntimeSurface = 'desktop-web' | 'mobile-web'

export function detectRuntimeSurface(): RuntimeSurface {
  if (typeof window === 'undefined') return 'desktop-web'

  const host = window.location.hostname.toLowerCase()
  const isMobileHost = host.startsWith('m.')
  const isMobileViewport = window.matchMedia('(max-width: 920px), (pointer: coarse)').matches
  const isMobileUserAgent = /android|iphone|ipad|ipod|mobile/i.test(window.navigator.userAgent)

  return isMobileHost || isMobileViewport || isMobileUserAgent ? 'mobile-web' : 'desktop-web'
}

export function useRuntimeSurface() {
  const [surface, setSurface] = useState<RuntimeSurface>(() => detectRuntimeSurface())

  useEffect(() => {
    const media = window.matchMedia('(max-width: 920px), (pointer: coarse)')
    const sync = () => setSurface(detectRuntimeSurface())

    sync()
    media.addEventListener('change', sync)
    window.addEventListener('resize', sync)

    return () => {
      media.removeEventListener('change', sync)
      window.removeEventListener('resize', sync)
    }
  }, [])

  return surface
}
