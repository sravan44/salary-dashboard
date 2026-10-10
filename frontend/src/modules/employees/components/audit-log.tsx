import { Alert, Center, List, Loader, Paper, Stack, Text, Title } from '@mantine/core'
import { useAuditTrail } from '../api'
import type { AuditEntry } from '../types'

const ITEM_LABELS: Record<string, string> = { Employee: 'Employee', Compensation: 'Salary record' }
const EVENT_LABELS: Record<string, string> = { create: 'created', update: 'updated' }

/** "job_title" → "Job title". */
const fieldLabel = (field: string) => field.charAt(0).toUpperCase() + field.slice(1).replace(/_/g, ' ')
const show = (value: unknown) => (value === null || value === undefined || value === '' ? '—' : String(value))
/** Deterministic and unambiguous: the server's UTC timestamp, minute precision. */
const when = (iso: string) => `${iso.slice(0, 10)} ${iso.slice(11, 16)} UTC`

/** Who changed what, when, for this employee and their salary records (append-only). */
export function AuditLog({ employeeId }: { employeeId: number }) {
  const trail = useAuditTrail(String(employeeId))

  return (
    <Paper withBorder p="md">
      <Stack gap="sm">
        <Title order={3}>Audit log</Title>
        {trail.isPending ? (
          <Center p="md">
            <Loader size="sm" aria-label="Loading audit log" />
          </Center>
        ) : trail.isError ? (
          <Alert color="red" role="alert">
            {trail.error.message}
          </Alert>
        ) : (
          <List aria-label="Audit log" listStyleType="none" spacing="sm">
            {trail.data.map((entry) => (
              <List.Item key={entry.id}>
                <Entry entry={entry} />
              </List.Item>
            ))}
          </List>
        )}
      </Stack>
    </Paper>
  )
}

function Entry({ entry }: { entry: AuditEntry }) {
  return (
    <div>
      <Text size="sm" fw={600}>
        {`${when(entry.created_at)} · ${entry.whodunnit ?? 'unknown'} · ${ITEM_LABELS[entry.item_type] ?? entry.item_type} ${EVENT_LABELS[entry.event] ?? entry.event}`}
      </Text>
      {Object.entries(entry.changes).map(([field, [before, after]]) => (
        <Text key={field} size="sm" c="dimmed">
          {`${fieldLabel(field)}: ${show(before)} → ${show(after)}`}
        </Text>
      ))}
    </div>
  )
}
