export const routes = {
  landing: '/',
  login: '/login',
  projects: '/projects',
  project: (projectId: string) => `/projects/${encodeURIComponent(projectId)}`,
  source: (projectId: string) => `/projects/${encodeURIComponent(projectId)}/source`,
  status: (projectId: string) => `/projects/${encodeURIComponent(projectId)}/status`,
  editor: (projectId: string) => `/projects/${encodeURIComponent(projectId)}/editor`,
  admin: '/admin',
} as const

export const demoProjectId = 'demo-project'
