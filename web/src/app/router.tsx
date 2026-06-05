import { createBrowserRouter, Navigate } from 'react-router-dom'

import { App } from './App'
import { RequireAdmin, RequireAuth, RequireDesktopCapability } from './RouteGuards'
import {
  AdminAccessDeniedPage,
  AdminAuditPage,
  AdminDashboardPage,
  AdminJobAuditPage,
  AdminJobDetailPage,
  AdminJobRetryPage,
  AdminJobsPage,
} from '../features/admin/AdminPages'
import { EditorPage } from '../features/editor/EditorPage'
import { LandingPage } from '../features/landing/LandingPage'
import { LoginPage } from '../features/auth/LoginPage'
import { DraftRecoveryPage } from '../features/projects/DraftRecoveryPage'
import { ProjectOverviewPage } from '../features/projects/ProjectOverviewPage'
import { ProjectsPage } from '../features/projects/ProjectsPage'
import { RoomDimensionsPage } from '../features/projects/RoomDimensionsPage'
import { ReconstructionStatusPage } from '../features/reconstruction/ReconstructionStatusPage'
import { SourceImagesPage } from '../features/source/SourceImagesPage'

export const router = createBrowserRouter([
  {
    element: <App />,
    children: [
      { path: '/', element: <LandingPage /> },
      { path: '/login', element: <LoginPage /> },
      { path: '/projects', element: <RequireAuth><ProjectsPage /></RequireAuth> },
      { path: '/projects/:projectId', element: <RequireAuth><ProjectOverviewPage /></RequireAuth> },
      {
        path: '/projects/:projectId/room',
        element: <RequireAuth><RequireDesktopCapability feature="room"><RoomDimensionsPage /></RequireDesktopCapability></RequireAuth>,
      },
      { path: '/projects/:projectId/source', element: <RequireAuth><SourceImagesPage /></RequireAuth> },
      { path: '/projects/:projectId/status', element: <RequireAuth><ReconstructionStatusPage /></RequireAuth> },
      {
        path: '/projects/:projectId/editor',
        element: <RequireAuth><RequireDesktopCapability feature="editor"><EditorPage /></RequireDesktopCapability></RequireAuth>,
      },
      { path: '/projects/:projectId/recovery', element: <RequireAuth><DraftRecoveryPage /></RequireAuth> },
      { path: '/admin', element: <RequireAdmin><AdminDashboardPage /></RequireAdmin> },
      { path: '/admin/jobs', element: <RequireAdmin><AdminJobsPage /></RequireAdmin> },
      { path: '/admin/jobs/:jobId', element: <RequireAdmin><AdminJobDetailPage /></RequireAdmin> },
      { path: '/admin/jobs/:jobId/retry', element: <RequireAdmin><AdminJobRetryPage /></RequireAdmin> },
      { path: '/admin/jobs/:jobId/audit', element: <RequireAdmin><AdminJobAuditPage /></RequireAdmin> },
      { path: '/admin/audit', element: <RequireAdmin><AdminAuditPage /></RequireAdmin> },
      { path: '/admin/access-denied', element: <RequireAuth><AdminAccessDeniedPage /></RequireAuth> },
      { path: '/admin/*', element: <Navigate to="/admin" replace /> },
      { path: '/legacy', element: <LegacyFallback /> },
      { path: '/legacy/*', element: <LegacyFallback /> },
      { path: '/app', element: <Navigate to="/projects" replace /> },
      { path: '/app/*', element: <Navigate to="/projects" replace /> },
      { path: '/m/projects', element: <Navigate to="/projects" replace /> },
      { path: '/m/projects/*', element: <Navigate to="/projects" replace /> },
      { path: '/m/app', element: <Navigate to="/projects" replace /> },
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
