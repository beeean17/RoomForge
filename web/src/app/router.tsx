import { createBrowserRouter, Navigate } from 'react-router-dom'

import { App } from './App'
import { AdminPlaceholderPage } from '../features/admin/AdminPlaceholderPage'
import { EditorPage } from '../features/editor/EditorPage'
import { LandingPage } from '../features/landing/LandingPage'
import { LoginPage } from '../features/auth/LoginPage'
import { ProjectOverviewPage } from '../features/projects/ProjectOverviewPage'
import { ProjectsPage } from '../features/projects/ProjectsPage'
import { ReconstructionStatusPage } from '../features/reconstruction/ReconstructionStatusPage'
import { SourceImagesPage } from '../features/source/SourceImagesPage'

export const router = createBrowserRouter([
  {
    element: <App />,
    children: [
      { path: '/', element: <LandingPage /> },
      { path: '/login', element: <LoginPage /> },
      { path: '/projects', element: <ProjectsPage /> },
      { path: '/projects/:projectId', element: <ProjectOverviewPage /> },
      { path: '/projects/:projectId/source', element: <SourceImagesPage /> },
      { path: '/projects/:projectId/status', element: <ReconstructionStatusPage /> },
      { path: '/projects/:projectId/editor', element: <EditorPage /> },
      { path: '/admin', element: <AdminPlaceholderPage /> },
      { path: '/admin/*', element: <AdminPlaceholderPage /> },
      { path: '/legacy/*', element: <LegacyFallback /> },
      { path: '/app/*', element: <Navigate to="/projects" replace /> },
      { path: '/m/app/*', element: <Navigate to="/projects" replace /> },
      { path: '*', element: <Navigate to="/" replace /> },
    ],
  },
])

function LegacyFallback() {
  return (
    <main className="rf-page rf-page--center">
      <section className="rf-panel rf-panel--narrow">
        <p className="rf-eyebrow">Legacy fallback</p>
        <h1>Flutter web legacy route</h1>
        <p>
          This route family is reserved for the temporary Flutter Web fallback while
          the React desktop web migration is in progress.
        </p>
      </section>
    </main>
  )
}
