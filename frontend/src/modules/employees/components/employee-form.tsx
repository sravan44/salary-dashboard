import { Alert, Autocomplete, Button, Group, NativeSelect, SimpleGrid, Stack, TextInput } from '@mantine/core'
import { useState, type FormEvent } from 'react'
import { Link } from 'react-router-dom'
import { ApiError } from '../../../shared/api-client'
import type { ReferenceData } from '../types'
import type { EmployeeFormValues } from './employee-form-values'

type Props = {
  mode: 'create' | 'edit'
  initial: EmployeeFormValues
  reference: ReferenceData | undefined
  submitting: boolean
  error: unknown
  cancelTo: string
  onSubmit: (values: EmployeeFormValues) => void
}

const LABELS: Record<string, string> = {
  full_name: 'Full name', email: 'Email', country_code: 'Country', department: 'Department', job_title: 'Job title',
  hire_date: 'Hire date', 'salary.amount': 'Annual salary', 'salary.currency': 'Currency',
}

/**
 * Create and edit share one form. Validation lives on the server (one source of truth); its field
 * errors are shown under the matching input. Salary and hire date are set only when creating:
 * the hire date starts the salary history, and pay changes are recorded separately.
 */
export function EmployeeForm({ mode, initial, reference, submitting, error, cancelTo, onSubmit }: Props) {
  const [values, setValues] = useState(initial)
  // The currency follows the country until the user picks one themselves.
  const [currencyChosen, setCurrencyChosen] = useState(mode === 'edit')
  const set = (key: keyof EmployeeFormValues) => (value: string) => setValues((current) => ({ ...current, [key]: value }))

  const details = error instanceof ApiError ? error.details : {}
  const fieldError = (key: string) => details[key] && `${LABELS[key]} ${details[key].join(', ')}`
  const generalError = error && Object.keys(details).length === 0 ? (error as Error).message : null

  const chooseCountry = (code: string) => {
    const countryCurrency = reference?.countries.find((c) => c.code === code)?.currency
    setValues((current) => ({ ...current, country_code: code, currency: currencyChosen || !countryCurrency ? current.currency : countryCurrency }))
  }

  const submit = (event: FormEvent) => {
    event.preventDefault()
    onSubmit(values)
  }

  const choices = (items: { value: string; label: string }[]) => [{ value: '', label: 'Choose…' }, ...items]
  const plain = (items: string[] = []) => items.map((value) => ({ value, label: value }))

  return (
    <form onSubmit={submit} noValidate>
      <Stack gap="md" maw={720}>
        {generalError && (
          <Alert color="red" title="Could not save" role="alert">
            {generalError}
          </Alert>
        )}
        <SimpleGrid cols={{ base: 1, sm: 2 }}>
          <TextInput label="Full name" withAsterisk value={values.full_name} error={fieldError('full_name')} onChange={(e) => set('full_name')(e.currentTarget.value)} />
          <TextInput label="Email" type="email" withAsterisk value={values.email} error={fieldError('email')} onChange={(e) => set('email')(e.currentTarget.value)} />
          <NativeSelect
            label="Country"
            withAsterisk
            value={values.country_code}
            data={choices((reference?.countries ?? []).map((c) => ({ value: c.code, label: c.name })))}
            error={fieldError('country_code')}
            onChange={(e) => chooseCountry(e.currentTarget.value)}
          />
          <NativeSelect
            label="Department"
            withAsterisk
            value={values.department}
            data={choices(plain(reference?.departments))}
            error={fieldError('department')}
            onChange={(e) => set('department')(e.currentTarget.value)}
          />
          <Autocomplete
            label="Job title"
            withAsterisk
            description="Pick an existing title or type a new one"
            value={values.job_title}
            data={reference?.job_titles ?? []}
            error={fieldError('job_title')}
            onChange={set('job_title')}
          />
          <TextInput
            label="Hire date"
            type="date"
            withAsterisk
            disabled={mode === 'edit'}
            description={mode === 'edit' ? 'Starts the salary history, so it cannot be changed' : 'Today or earlier'}
            value={values.hire_date}
            error={fieldError('hire_date')}
            onChange={(e) => set('hire_date')(e.currentTarget.value)}
          />
          {mode === 'create' && (
            <>
              <TextInput
                label="Annual salary"
                withAsterisk
                inputMode="decimal"
                description="Annual base salary, in the currency on the right"
                value={values.amount}
                error={fieldError('salary.amount')}
                onChange={(e) => set('amount')(e.currentTarget.value)}
              />
              <NativeSelect
                label="Currency"
                withAsterisk
                value={values.currency}
                data={choices(plain(reference?.currencies))}
                error={fieldError('salary.currency')}
                onChange={(e) => {
                  setCurrencyChosen(true)
                  set('currency')(e.currentTarget.value)
                }}
              />
            </>
          )}
        </SimpleGrid>
        <Group>
          <Button type="submit" loading={submitting}>
            {mode === 'create' ? 'Create employee' : 'Save changes'}
          </Button>
          <Button component={Link} to={cancelTo} variant="default">
            Cancel
          </Button>
        </Group>
      </Stack>
    </form>
  )
}
