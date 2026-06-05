import { useEffect, useState } from 'react'
import { Moon, Sun } from 'lucide-react'

type Theme = 'dark' | 'light'

function getInitialTheme(): Theme {
  const attr = document.documentElement.getAttribute('data-theme')
  return attr === 'light' ? 'light' : 'dark'
}

export function ThemeToggle() {
  const [theme, setTheme] = useState<Theme>(getInitialTheme)
  const nextTheme = theme === 'dark' ? 'light' : 'dark'
  const nextLabel = nextTheme === 'light' ? '낮' : '밤'

  useEffect(() => {
    document.documentElement.setAttribute('data-theme', theme)
    document.documentElement.style.setProperty('--p', theme === 'dark' ? '1' : '0')
    localStorage.setItem('rf-theme', theme)
  }, [theme])

  return (
    <button
      className={`theme-toggle theme-toggle--${theme}`}
      type="button"
      aria-label={`${nextLabel} 테마로 전환`}
      aria-pressed={theme === 'dark'}
      title={`${nextLabel} 테마로 전환`}
      onClick={() => setTheme(nextTheme)}
    >
      <span className="theme-toggle__icon" aria-hidden="true" key={theme}>
        {theme === 'light' ? (
          <Sun className="theme-toggle__svg theme-toggle__svg--sun" size={17} strokeWidth={1.8} />
        ) : (
          <Moon className="theme-toggle__svg theme-toggle__svg--moon" size={17} strokeWidth={1.8} />
        )}
      </span>
    </button>
  )
}
