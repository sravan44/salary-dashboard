export type Permission = 'view_dashboard' | 'manage_employees' | 'manage_users'

/** The signed-in user, as returned by GET /api/v1/session. */
export type SessionUser = {
  id: number
  email: string
  roles: string[]
  permissions: Record<Permission, boolean>
}

export const ROLE_LABELS: Record<string, string> = { viewer: 'Viewer', hr_manager: 'HR manager', admin: 'Admin' }
