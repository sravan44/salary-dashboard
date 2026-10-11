import { Alert, Badge, Button, Center, Group, Loader, Paper, Stack, Table, Text, Title } from '@mantine/core'
import { useExchangeRates, useSyncExchangeRates } from './api'

/** "2026-10-09T16:00:00Z" → "2026-10-09 16:00 UTC" (the same for every viewer, whatever their time zone). */
const utcMinute = (iso: string) => `${iso.slice(0, 10)} ${iso.slice(11, 16)} UTC`

/** Admins: the cached reference rates used for the reporting currency, and a button to fetch fresh ones now. */
export function ExchangeRatesPage() {
  const rates = useExchangeRates()
  const sync = useSyncExchangeRates()

  return (
    <Stack>
      <Group justify="space-between">
        <Title order={2}>Exchange rates</Title>
        <Button loading={sync.isPending} onClick={() => sync.mutate()}>
          Sync rates
        </Button>
      </Group>
      {sync.isSuccess && (
        <Alert color="green">
          Synced {sync.data.stored} rates for {sync.data.rate_date}.
        </Alert>
      )}
      {sync.isError && <Alert color="red">{sync.error.message}</Alert>}

      {rates.isPending && (
        <Center p="xl">
          <Loader aria-label="Loading exchange rates" />
        </Center>
      )}
      {rates.isError && <Alert color="red">{rates.error.message}</Alert>}
      {rates.data && (
        <Paper withBorder p="md">
          {rates.data.rate_date === null ? (
            <Text>No rates yet. Choose "Sync rates" to fetch them.</Text>
          ) : (
            <Stack gap="sm">
              <Group gap="xs">
                <Text size="sm" c="dimmed">
                  Rates for {rates.data.rate_date} · {rates.data.source} · fetched {utcMinute(rates.data.fetched_at ?? '')}
                </Text>
                {rates.data.stale && (
                  <Badge color="orange" variant="light">
                    Stale
                  </Badge>
                )}
              </Group>
              <Text size="sm">
                1 {rates.data.base} in each currency. They refresh automatically every weekday after the ECB publishes.
              </Text>
              <Table aria-label="Exchange rates" striped maw={360}>
                <Table.Thead>
                  <Table.Tr>
                    <Table.Th>Currency</Table.Th>
                    <Table.Th ta="right">1 {rates.data.base} =</Table.Th>
                  </Table.Tr>
                </Table.Thead>
                <Table.Tbody>
                  {rates.data.rates.map(({ currency, rate }) => (
                    <Table.Tr key={currency}>
                      <Table.Td>{currency}</Table.Td>
                      <Table.Td ta="right" ff="monospace">
                        {rate}
                      </Table.Td>
                    </Table.Tr>
                  ))}
                </Table.Tbody>
              </Table>
            </Stack>
          )}
        </Paper>
      )}
    </Stack>
  )
}
