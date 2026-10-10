import { Center, Loader, MantineProvider } from '@mantine/core'
import { lazy, Suspense, type ReactNode } from 'react'
import { Navigate, Route, Routes } from 'react-router-dom'
import { AppLayout } from './app-layout'
import { LoginPage } from '../modules/auth/login-page'
import { RequireAuth } from '../modules/auth/require-auth'
import { SessionExpiryWatcher } from '../modules/auth/session-expiry'
import type { Permission } from '../modules/auth/types'
import { EditEmployeePage, NewEmployeePage } from '../modules/employees/employee-form-pages'
import { EmployeePage } from '../modules/employees/employee-page'
import { EmployeesPage } from '../modules/employees/employees-page'
import { UsersPage } from '../modules/users/users-page'

// The dashboard (with Highcharts, ~540 kB) loads only when it is opened, so other pages stay light.
const DashboardPage = lazy(() => import('../modules/dashboard/dashboard-page').then((m) => ({ default: m.DashboardPage })))

const pageLoader = (
  <Center p="xl">
    <Loader aria-label="Loading page" />
  </Center>
)

const allow = (permission: Permission, page: ReactNode) => <RequireAuth permission={permission}>{page}</RequireAuth>

export function App() {
  return (
    <MantineProvider>
      <SessionExpiryWatcher />
      <Routes>
        <Route path="login" element={<LoginPage />} />
        <Route
          element={
            <RequireAuth>
              <AppLayout />
            </RequireAuth>
          }
        >
          <Route index element={allow('view_dashboard', <Suspense fallback={pageLoader}>{<DashboardPage />}</Suspense>)} />
          <Route path="employees" element={allow('manage_employees', <EmployeesPage />)} />
          <Route path="employees/new" element={allow('manage_employees', <NewEmployeePage />)} />
          <Route path="employees/:id" element={allow('manage_employees', <EmployeePage />)} />
          <Route path="employees/:id/edit" element={allow('manage_employees', <EditEmployeePage />)} />
          <Route path="admin/users" element={allow('manage_users', <UsersPage />)} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Route>
      </Routes>
    </MantineProvider>
  )
}
