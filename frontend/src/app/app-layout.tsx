import { AppShell, Group, NavLink, Title } from '@mantine/core'
import { NavLink as RouterNavLink, Outlet } from 'react-router-dom'

const NAV_ITEMS = [
  { to: '/', label: 'Dashboard', end: true },
  { to: '/employees', label: 'Employees', end: false },
]

export function AppLayout() {
  return (
    <AppShell header={{ height: 56 }} navbar={{ width: 200, breakpoint: 'sm' }} padding="md">
      <AppShell.Header>
        <Group h="100%" px="md">
          <Title order={3}>ACME Salary Insights</Title>
        </Group>
      </AppShell.Header>
      <AppShell.Navbar p="xs" component="nav" aria-label="Main">
        {NAV_ITEMS.map((item) => (
          <NavLink key={item.to} component={RouterNavLink} to={item.to} end={item.end} label={item.label} />
        ))}
      </AppShell.Navbar>
      <AppShell.Main>
        <Outlet />
      </AppShell.Main>
    </AppShell>
  )
}
