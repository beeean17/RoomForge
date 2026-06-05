import {
  getAuth,
  GoogleAuthProvider,
  onAuthStateChanged,
  signInWithPopup,
  signOut as firebaseSignOut,
  type User,
} from 'firebase/auth'
import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react'

import { hasFirebaseConfig, roomForgeFirebaseApp } from '../../firebase/config'

export type AuthState =
  | { status: 'loading'; user: null; error: null; isConfigured: boolean }
  | { status: 'signed-out'; user: null; error: null; isConfigured: boolean }
  | { status: 'signed-in'; user: User; error: null; isConfigured: true }
  | { status: 'error'; user: null; error: string; isConfigured: boolean }

type AuthContextValue = AuthState & {
  signInWithGoogle: () => Promise<void>
  signOut: () => Promise<void>
}

const AuthContext = createContext<AuthContextValue | null>(null)

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const isConfigured = hasFirebaseConfig()
  const [state, setState] = useState<AuthState>(() =>
    isConfigured
      ? { status: 'loading', user: null, error: null, isConfigured }
      : { status: 'signed-out', user: null, error: null, isConfigured },
  )

  useEffect(() => {
    if (!isConfigured) {
      setState({ status: 'signed-out', user: null, error: null, isConfigured: false })
      return undefined
    }

    const auth = getAuth(roomForgeFirebaseApp())
    return onAuthStateChanged(
      auth,
      (user) => {
        setState(
          user
            ? { status: 'signed-in', user, error: null, isConfigured: true }
            : { status: 'signed-out', user: null, error: null, isConfigured: true },
        )
      },
      (error) => {
        setState({
          status: 'error',
          user: null,
          error: error.message,
          isConfigured: true,
        })
      },
    )
  }, [isConfigured])

  const signInWithGoogle = useCallback(async () => {
    if (!isConfigured) {
      setState({
        status: 'error',
        user: null,
        error: 'Firebase web config가 아직 없습니다. VITE_ROOMFORGE_FIREBASE_* 환경 변수를 연결하면 실제 Google 로그인이 활성화됩니다.',
        isConfigured: false,
      })
      return
    }

    const auth = getAuth(roomForgeFirebaseApp())
    const provider = new GoogleAuthProvider()
    provider.addScope('email')
    provider.addScope('profile')
    await signInWithPopup(auth, provider)
  }, [isConfigured])

  const signOut = useCallback(async () => {
    if (!isConfigured) {
      setState({ status: 'signed-out', user: null, error: null, isConfigured: false })
      return
    }
    await firebaseSignOut(getAuth(roomForgeFirebaseApp()))
  }, [isConfigured])

  const value = useMemo<AuthContextValue>(
    () => ({ ...state, signInWithGoogle, signOut }),
    [state, signInWithGoogle, signOut],
  )

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function useAuth() {
  const value = useContext(AuthContext)
  if (!value) {
    throw new Error('useAuth must be used inside AuthProvider.')
  }
  return value
}
