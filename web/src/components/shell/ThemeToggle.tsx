import { useEffect, useState } from 'react'

type Theme = 'dark' | 'light'

function getInitialTheme(): Theme {
  const attr = document.documentElement.getAttribute('data-theme')
  return attr === 'light' ? 'light' : 'dark'
}

export function ThemeToggle() {
  const [theme, setTheme] = useState<Theme>(getInitialTheme)

  useEffect(() => {
    document.documentElement.setAttribute('data-theme', theme)
    localStorage.setItem('rf-theme', theme)
  }, [theme])

  return (
    <button
      className="theme-toggle"
      type="button"
      aria-label="낮/밤 테마 전환"
      aria-pressed={theme === 'dark'}
      title="낮 / 밤 전환"
      onClick={() => setTheme((current) => (current === 'dark' ? 'light' : 'dark'))}
    >
      <span className="dial" aria-hidden="true">
        <span className="body sun" />
        <span className="body moon" />
      </span>
    </button>
  )
}
