import { AppShell, Badge, Button, Group, NavLink, Text, Title } from '@mantine/core'
import { NavLink as RouterNavLink, Outlet } from 'react-router-dom'
import { useSession, useSignOut } from '../modules/auth/api'
import { ROLE_LABELS, type Permission } from '../modules/auth/types'

const NAV_ITEMS: { to: string; label: string; end: boolean; permission: Permission }[] = [
  { to: '/', label: 'Dashboard', end: true, permission: 'view_dashboard' },
  { to: '/employees', label: 'Employees', end: false, permission: 'manage_employees' },
  { to: '/admin/users', label: 'Users', end: false, permission: 'manage_users' },
]

/** Rendered inside RequireAuth. On sign-out the user is briefly gone before the guard redirects. */
export function AppLayout() {
  const user = useSession().data
  const signOut = useSignOut()
  if (!user) return null

  return (
    <AppShell header={{ height: 56 }} navbar={{ width: 200, breakpoint: 'sm' }} padding="md">
      <AppShell.Header>
        <Group h="100%" px="md" justify="space-between">
          <Title order={3}>ACME Salary Insights</Title>
          <Group gap="xs" role="group" aria-label="Signed in user">
            <Text size="sm">{user.email}</Text>
            {user.roles.map((role) => (
              <Badge key={role} variant="light" size="sm">
                {ROLE_LABELS[role] ?? role}
              </Badge>
            ))}
            <Button variant="subtle" size="compact-sm" loading={signOut.isPending} onClick={() => signOut.mutate()}>
              Sign out
            </Button>
          </Group>
        </Group>
      </AppShell.Header>
      <AppShell.Navbar p="xs" component="nav" aria-label="Main">
        {NAV_ITEMS.filter((item) => user.permissions[item.permission]).map((item) => (
          <NavLink key={item.to} component={RouterNavLink} to={item.to} end={item.end} label={item.label} />
        ))}
      </AppShell.Navbar>
      <AppShell.Main>
        <Outlet />
      </AppShell.Main>
    </AppShell>
  )
}
