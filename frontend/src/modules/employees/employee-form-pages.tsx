import { Alert, Center, Loader, Stack, Title } from '@mantine/core'
import { useNavigate, useParams } from 'react-router-dom'
import { useCreateEmployee, useEmployee, useReferenceData, useUpdateEmployee } from './api'
import { EmployeeForm } from './components/employee-form'
import { EMPTY_EMPLOYEE, type EmployeeFormValues } from './components/employee-form-values'

export function NewEmployeePage() {
  const navigate = useNavigate()
  const reference = useReferenceData()
  const create = useCreateEmployee()

  const submit = ({ amount, currency, ...profile }: EmployeeFormValues) =>
    create.mutate({ ...profile, salary: { amount, currency } }, { onSuccess: (saved) => navigate(`/employees/${saved.id}`) })

  return (
    <Stack gap="md">
      <Title order={2}>Add employee</Title>
      <EmployeeForm
        mode="create"
        initial={EMPTY_EMPLOYEE}
        reference={reference.data}
        submitting={create.isPending}
        error={create.error}
        cancelTo="/employees"
        onSubmit={submit}
      />
    </Stack>
  )
}

export function EditEmployeePage() {
  const { id = '' } = useParams()
  const navigate = useNavigate()
  const employee = useEmployee(id)
  const reference = useReferenceData()
  const update = useUpdateEmployee(id)

  if (employee.isPending) {
    return (
      <Center p="xl">
        <Loader aria-label="Loading employee" />
      </Center>
    )
  }
  if (employee.isError) {
    return (
      <Alert color="red" role="alert">
        {employee.error.message}
      </Alert>
    )
  }

  const e = employee.data
  // Only the editable profile fields are sent; hire date, employee number and salary never are.
  const submit = ({ full_name, email, country_code, department, job_title }: EmployeeFormValues) =>
    update.mutate({ full_name, email, country_code, department, job_title }, { onSuccess: () => navigate(`/employees/${id}`) })

  return (
    <Stack gap="md">
      <Title order={2}>Edit {e.full_name}</Title>
      <EmployeeForm
        mode="edit"
        initial={{ ...EMPTY_EMPLOYEE, ...e, amount: '', currency: '' }}
        reference={reference.data}
        submitting={update.isPending}
        error={update.error}
        cancelTo={`/employees/${id}`}
        onSubmit={submit}
      />
    </Stack>
  )
}
