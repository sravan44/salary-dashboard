import { Alert, Badge, Button, Center, Group, Loader, Modal, Paper, SimpleGrid, Stack, Text, Title } from '@mantine/core'
import { useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { formatMoney } from '../../shared/format-money'
import { useEmployee, useReferenceData, useUpdateEmployee } from './api'
import { AuditLog } from './components/audit-log'
import { SalaryHistory } from './components/salary-history'
import type { EmployeeDetail } from './types'

export function EmployeePage() {
  const { id = '' } = useParams()
  const employee = useEmployee(id)
  const reference = useReferenceData()

  if (employee.isPending) {
    return (
      <Center p="xl">
        <Loader aria-label="Loading employee" />
      </Center>
    )
  }
  if (employee.isError) {
    const notFound = 'status' in employee.error && employee.error.status === 404
    return (
      <Alert color={notFound ? 'gray' : 'red'} title={notFound ? undefined : 'Could not load the employee'} role="alert">
        {notFound ? 'Employee not found.' : employee.error.message}
      </Alert>
    )
  }

  const e = employee.data
  const countryName = reference.data?.countries.find((c) => c.code === e.country_code)?.name ?? e.country_code
  const facts: [string, string][] = [
    ['Employee no.', e.employee_number],
    ['Email', e.email],
    ['Country', countryName],
    ['Department', e.department],
    ['Job title', e.job_title],
    ['Hire date', e.hire_date],
    ['Current salary', e.current_salary ? formatMoney(e.current_salary.amount, e.current_salary.currency) : '—'],
  ]

  return (
    <Stack gap="md">
      <Group justify="space-between">
        <Group gap="sm">
          <Title order={2}>{e.full_name}</Title>
          <Badge variant="light" color={e.status === 'active' ? 'teal' : 'gray'}>
            {e.status}
          </Badge>
        </Group>
        <Group>
          <Button component={Link} to={`/employees/${e.id}/edit`} variant="default">
            Edit
          </Button>
          <StatusButton employee={e} />
        </Group>
      </Group>
      <Paper withBorder p="md" component="section" aria-label="Profile">
        <SimpleGrid cols={{ base: 1, sm: 2 }} spacing="sm">
          {facts.map(([label, value]) => (
            <div key={label}>
              <Text size="sm" c="dimmed">
                {label}
              </Text>
              <Text>{value}</Text>
            </div>
          ))}
        </SimpleGrid>
      </Paper>
      <SalaryHistory employee={e} />
      <AuditLog employeeId={e.id} />
    </Stack>
  )
}

/** Deactivate or reactivate, always after confirmation. The record and its salary history are kept either way. */
function StatusButton({ employee }: { employee: EmployeeDetail }) {
  const [open, setOpen] = useState(false)
  // The dialog keeps the action it was opened for, so it doesn't flip to the opposite wording
  // while it fades out after the status has changed.
  const [target, setTarget] = useState<EmployeeDetail['status']>('terminated')
  const update = useUpdateEmployee(String(employee.id))
  const deactivating = target === 'terminated'
  const action = deactivating ? 'Deactivate' : 'Reactivate'
  const next = employee.status === 'active' ? 'terminated' : 'active'

  const start = () => {
    update.reset()
    setTarget(next)
    setOpen(true)
  }
  const confirm = () => update.mutate({ status: target }, { onSuccess: () => setOpen(false) })

  return (
    <>
      <Button color={next === 'terminated' ? 'red' : 'teal'} variant="light" onClick={start}>
        {next === 'terminated' ? 'Deactivate' : 'Reactivate'}
      </Button>
      <Modal opened={open} onClose={() => setOpen(false)} title={`${action} ${employee.full_name}?`}>
        <Stack>
          <Text size="sm">
            {deactivating
              ? 'They stay in the directory with their salary history, but leave the dashboard figures. You can reactivate them later.'
              : 'They count as an active employee again and return to the dashboard figures.'}
          </Text>
          {update.isError && (
            <Alert color="red" role="alert">
              {update.error.message}
            </Alert>
          )}
          <Group justify="flex-end">
            <Button variant="default" onClick={() => setOpen(false)}>
              Cancel
            </Button>
            <Button color={deactivating ? 'red' : 'teal'} loading={update.isPending} onClick={confirm}>
              {action}
            </Button>
          </Group>
        </Stack>
      </Modal>
    </>
  )
}
