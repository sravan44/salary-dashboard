import { MantineProvider } from '@mantine/core'
import { Navigate, Route, Routes } from 'react-router-dom'
import { AppLayout } from './app-layout'
import { DashboardPage } from '../modules/dashboard/dashboard-page'
import { EmployeesPage } from '../modules/employees/employees-page'

export function App() {
  return (
    <MantineProvider>
      <Routes>
        <Route element={<AppLayout />}>
          <Route index element={<DashboardPage />} />
          <Route path="employees" element={<EmployeesPage />} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Route>
      </Routes>
    </MantineProvider>
  )
}
