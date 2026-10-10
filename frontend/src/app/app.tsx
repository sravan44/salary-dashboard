import { Center, Loader, MantineProvider } from '@mantine/core'
import { lazy, Suspense } from 'react'
import { Navigate, Route, Routes } from 'react-router-dom'
import { AppLayout } from './app-layout'
import { EditEmployeePage, NewEmployeePage } from '../modules/employees/employee-form-pages'
import { EmployeePage } from '../modules/employees/employee-page'
import { EmployeesPage } from '../modules/employees/employees-page'

// The dashboard (with Highcharts, ~540 kB) loads only when it is opened, so other pages stay light.
const DashboardPage = lazy(() => import('../modules/dashboard/dashboard-page').then((m) => ({ default: m.DashboardPage })))

const pageLoader = (
  <Center p="xl">
    <Loader aria-label="Loading page" />
  </Center>
)

export function App() {
  return (
    <MantineProvider>
      <Routes>
        <Route element={<AppLayout />}>
          <Route
            index
            element={
              <Suspense fallback={pageLoader}>
                <DashboardPage />
              </Suspense>
            }
          />
          <Route path="employees" element={<EmployeesPage />} />
          <Route path="employees/new" element={<NewEmployeePage />} />
          <Route path="employees/:id" element={<EmployeePage />} />
          <Route path="employees/:id/edit" element={<EditEmployeePage />} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Route>
      </Routes>
    </MantineProvider>
  )
}
