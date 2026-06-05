export const routes = {
  landing: '/',
  login: '/login',
  projects: '/projects',
  project: (projectId: string) => `/projects/${encodeURIComponent(projectId)}`,
  room: (projectId: string) => `/projects/${encodeURIComponent(projectId)}/room`,
  source: (projectId: string) => `/projects/${encodeURIComponent(projectId)}/source`,
  status: (projectId: string) => `/projects/${encodeURIComponent(projectId)}/status`,
  editor: (projectId: string) => `/projects/${encodeURIComponent(projectId)}/editor`,
  recovery: (projectId: string) => `/projects/${encodeURIComponent(projectId)}/recovery`,
  admin: '/admin',
  adminJobs: '/admin/jobs',
  adminAudit: '/admin/audit',
  adminAccessDenied: '/admin/access-denied',
} as const

export const demoProjectId = 'demo-project'
