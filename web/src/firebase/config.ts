import { initializeApp, type FirebaseApp } from 'firebase/app'

const firebaseConfig = {
  apiKey: import.meta.env.VITE_ROOMFORGE_FIREBASE_API_KEY,
  authDomain: import.meta.env.VITE_ROOMFORGE_FIREBASE_AUTH_DOMAIN,
  projectId: import.meta.env.VITE_ROOMFORGE_FIREBASE_PROJECT_ID,
  storageBucket: import.meta.env.VITE_ROOMFORGE_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: import.meta.env.VITE_ROOMFORGE_FIREBASE_MESSAGING_SENDER_ID,
  appId: import.meta.env.VITE_ROOMFORGE_FIREBASE_APP_ID,
}

export function hasFirebaseConfig() {
  return Object.values(firebaseConfig).every((value) => typeof value === 'string' && value.length > 0)
}

let app: FirebaseApp | undefined

export function roomForgeFirebaseApp() {
  if (!hasFirebaseConfig()) {
    throw new Error('RoomForge Firebase web config is missing.')
  }
  app ??= initializeApp(firebaseConfig)
  return app
}
