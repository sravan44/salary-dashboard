import { Alert, Button, Center, Group, Loader, Modal, NativeSelect, Paper, SimpleGrid, Stack, Table, Text, Textarea, TextInput, Title } from '@mantine/core'
import { useState, type FormEvent } from 'react'
import { ApiError } from '../../../shared/api-client'
import { formatMoney } from '../../../shared/format-money'
import { shortRate } from '../../../shared/format-rate'
import { useRecordSalaryChange, useReferenceData, useSalaryHistory } from '../api'
import type { EmployeeDetail, HistoryConversion, SalaryChange, SalaryRecord } from '../types'

const REASON_LABELS: Record<string, string> = {
  hire: 'Hire', annual_review: 'Annual review', promotion: 'Promotion', market_adjustment: 'Market adjustment', correction: 'Correction',
}
const CHANGE_REASONS = ['annual_review', 'promotion', 'market_adjustment', 'correction']

/** "+11.11%", "−3.20%"; "—" for the first record; "n/a" when the currency changed (no meaningful %). */
function changeLabel(record: SalaryRecord, isOldest: boolean) {
  if (record.change_percent === null) return isOldest ? '—' : 'n/a (currency changed)'
  const value = Number(record.change_percent)
  return `${value > 0 ? '+' : value < 0 ? '−' : ''}${Math.abs(value).toFixed(2)}%`
}

type Props = {
  employee: EmployeeDetail
  /** Fetched once by the page (it also shows the converted current salary). */
  history: ReturnType<typeof useSalaryHistory>
  /** Reporting currency for converted amounts; '' = original currencies only. */
  report: string
  onReportChange: (currency: string) => void
}

/** The full salary history (never edited, only added to) and the action that adds to it. */
export function SalaryHistory({ employee, history, report, onReportChange }: Props) {
  const reference = useReferenceData()
  const [open, setOpen] = useState(false)
  const active = employee.status === 'active'
  const records = history.data?.records ?? []
  const conversion = report ? history.data?.conversion : null

  return (
    <Paper withBorder p="md">
      <Stack gap="sm">
        <Group justify="space-between" align="flex-end">
          <Title order={3}>Salary history</Title>
          <Group align="flex-end">
            <NativeSelect
              label="Show amounts in"
              value={report}
              data={[{ value: '', label: 'Original currency' }, ...(reference.data?.currencies ?? []).map((c) => ({ value: c, label: c }))]}
              onChange={(e) => onReportChange(e.currentTarget.value)}
            />
            <Button onClick={() => setOpen(true)} disabled={!active}>
              Record salary change
            </Button>
          </Group>
        </Group>
        {!active && (
          <Text size="sm" c="dimmed">
            Reactivate this employee to record a pay change.
          </Text>
        )}
        {history.isPending ? (
          <Center p="md">
            <Loader size="sm" aria-label="Loading salary history" />
          </Center>
        ) : history.isError ? (
          <Alert color="red" role="alert">
            {history.error.message}
          </Alert>
        ) : (
          <Table aria-label="Salary history" striped>
            <Table.Thead>
              <Table.Tr>
                <Table.Th>Period</Table.Th>
                <Table.Th ta="right">Annual salary</Table.Th>
                {conversion && <Table.Th ta="right">{`In ${conversion.to}`}</Table.Th>}
                <Table.Th ta="right">Change</Table.Th>
                <Table.Th>Reason</Table.Th>
                <Table.Th>Notes</Table.Th>
                <Table.Th>Recorded by</Table.Th>
              </Table.Tr>
            </Table.Thead>
            <Table.Tbody>
              {records.map((record, index, all) => (
                <Table.Tr key={record.id} fw={record.current ? 600 : undefined}>
                  <Table.Td>{`${record.effective_from} → ${record.effective_to ?? 'current'}`}</Table.Td>
                  <Table.Td ta="right">{formatMoney(record.amount, record.currency)}</Table.Td>
                  {conversion && (
                    <Table.Td ta="right">{record.converted ? formatMoney(record.converted.amount, record.converted.currency) : 'n/a (no rate)'}</Table.Td>
                  )}
                  <Table.Td ta="right">{changeLabel(record, index === all.length - 1)}</Table.Td>
                  <Table.Td>{REASON_LABELS[record.reason] ?? record.reason}</Table.Td>
                  <Table.Td>{record.notes ?? ''}</Table.Td>
                  <Table.Td>{record.revised_by ?? ''}</Table.Td>
                </Table.Tr>
              ))}
            </Table.Tbody>
          </Table>
        )}
        {conversion && <ConversionNote conversion={conversion} />}
      </Stack>
      {open && <RecordChangeForm employee={employee} currentCurrency={records[0]?.currency} onClose={() => setOpen(false)} />}
    </Paper>
  )
}

const LABELS: Record<string, string> = {
  amount: 'New annual salary', currency: 'Currency', effective_from: 'Effective from', reason: 'Reason', notes: 'Notes', employee: 'Employee',
}

function RecordChangeForm({ employee, currentCurrency, onClose }: { employee: EmployeeDetail; currentCurrency?: string; onClose: () => void }) {
  const reference = useReferenceData()
  const record = useRecordSalaryChange(String(employee.id))
  const [values, setValues] = useState<SalaryChange>({
    amount: '',
    currency: currentCurrency ?? employee.current_salary?.currency ?? '',
    effective_from: new Date().toISOString().slice(0, 10),
    reason: 'annual_review',
    notes: '',
  })
  const set = (key: keyof SalaryChange) => (value: string) => setValues((current) => ({ ...current, [key]: value }))

  const details = record.error instanceof ApiError ? record.error.details : {}
  const fieldError = (key: string) => details[key] && `${LABELS[key]} ${details[key].join(', ')}`
  const fieldKeys = ['amount', 'currency', 'effective_from', 'reason', 'notes']
  const general = record.isError
    ? Object.keys(details).filter((key) => !fieldKeys.includes(key)).map((key) => fieldError(key)).join('; ') ||
      (Object.keys(details).length === 0 ? record.error.message : '')
    : ''

  const submit = (event: FormEvent) => {
    event.preventDefault()
    record.mutate(values, { onSuccess: onClose })
  }

  return (
    <Modal opened onClose={onClose} title={`Record salary change for ${employee.full_name}`} size="lg">
      <form onSubmit={submit} noValidate>
        <Stack>
          <Text size="sm" c="dimmed">
            The current salary is closed the day before the new one starts. Nothing is overwritten: the full history stays.
          </Text>
          {general && (
            <Alert color="red" role="alert">
              {general}
            </Alert>
          )}
          <SimpleGrid cols={{ base: 1, sm: 2 }}>
            <TextInput label="New annual salary" inputMode="decimal" value={values.amount} error={fieldError('amount')} onChange={(e) => set('amount')(e.currentTarget.value)} />
            <NativeSelect
              label="Currency"
              value={values.currency}
              data={(reference.data?.currencies ?? [values.currency]).map((c) => ({ value: c, label: c }))}
              error={fieldError('currency')}
              onChange={(e) => set('currency')(e.currentTarget.value)}
            />
            <TextInput label="Effective from" type="date" description="After the current salary's start; not in the future" value={values.effective_from} error={fieldError('effective_from')} onChange={(e) => set('effective_from')(e.currentTarget.value)} />
            <NativeSelect
              label="Reason"
              value={values.reason}
              data={CHANGE_REASONS.map((value) => ({ value, label: REASON_LABELS[value] }))}
              error={fieldError('reason')}
              onChange={(e) => set('reason')(e.currentTarget.value)}
            />
          </SimpleGrid>
          <Textarea label="Notes" autosize minRows={2} value={values.notes} error={fieldError('notes')} onChange={(e) => set('notes')(e.currentTarget.value)} />
          <Group justify="flex-end">
            <Button variant="default" onClick={onClose}>
              Cancel
            </Button>
            <Button type="submit" loading={record.isPending}>
              Record change
            </Button>
          </Group>
        </Stack>
      </form>
    </Modal>
  )
}

/** Where converted amounts come from: rates, date and source, plus any gaps. Indicative only. */
function ConversionNote({ conversion: c }: { conversion: HistoryConversion }) {
  if (!c.available) {
    return (
      <Alert color="yellow" role="alert">
        No exchange rates have been fetched yet, so amounts are shown in their original currency only.
      </Alert>
    )
  }
  return (
    <Stack gap={4}>
      {c.stale && (
        <Alert color="yellow" role="alert">
          {`These rates are more than 7 days old (${c.rate_date}).`}
        </Alert>
      )}
      {c.missing.length > 0 && (
        <Text size="sm" c="orange">{`No exchange rate for ${c.missing.join(', ')}: those amounts are not converted.`}</Text>
      )}
      <Text role="note" aria-label="Conversion details" size="xs" c="dimmed">
        {`Converted to ${c.to} at ${c.source}, rates of ${c.rate_date}: `}
        {c.rates.map((r, i) => (
          <span key={r.currency} title={`1 ${r.currency} = ${r.rate} ${c.to} (exact)`}>
            {`${i > 0 ? ' · ' : ''}1 ${r.currency} = ${shortRate(r.rate)} ${c.to}`}
          </span>
        ))}
        {". Indicative: today's rates are applied to every record, including past ones."}
      </Text>
    </Stack>
  )
}
