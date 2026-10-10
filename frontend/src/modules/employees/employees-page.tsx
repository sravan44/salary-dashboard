import { Alert, Center, Group, Loader, NativeSelect, Pagination, Paper, Stack, Text, Title } from '@mantine/core'
import { ApiError } from '../../shared/api-client'
import { useEmployeeDirectory, useReferenceData } from './api'
import { DirectoryFilters } from './components/directory-filters'
import { EmployeesTable } from './components/employees-table'
import { FilterChips } from './components/filter-chips'
import { useDirectoryFilters, type FilterKey } from './use-directory-filters'

const PAGE_SIZES = ['10', '25', '50', '100']

export function EmployeesPage() {
  const filters = useDirectoryFilters()
  const reference = useReferenceData()
  const directory = useEmployeeDirectory(filters.params)

  const describe = (key: FilterKey, value: string) =>
    key === 'country' ? (reference.data?.countries.find((c) => c.code === value)?.name ?? value) : value

  return (
    <Stack gap="xs">
      <Title order={2}>Employees</Title>
      <Paper withBorder p="md">
        <DirectoryFilters filters={filters} reference={reference.data} />
        <FilterChips
          active={filters.activeFilters}
          describe={describe}
          onRemove={(key) => filters.setFilter(key, '')}
          onClearAll={filters.clearAll}
        />
      </Paper>
      <DirectoryResults filters={filters} directory={directory} />
    </Stack>
  )
}

type ResultsProps = {
  filters: ReturnType<typeof useDirectoryFilters>
  directory: ReturnType<typeof useEmployeeDirectory>
}

function DirectoryResults({ filters, directory }: ResultsProps) {
  if (directory.isError) return <DirectoryError error={directory.error} />
  if (!directory.data) {
    return (
      <Center p="xl">
        <Loader aria-label="Loading employees" />
      </Center>
    )
  }

  const { data: employees, meta } = directory.data
  if (meta.total === 0) {
    return (
      <Paper withBorder p="xl" ta="center">
        <Text>No employees match these filters.</Text>
        {filters.activeFilters.length > 0 && (
          <Text size="sm" c="dimmed">
            Remove a filter above, or clear them all.
          </Text>
        )}
      </Paper>
    )
  }

  const first = (meta.page - 1) * meta.per_page + 1
  const last = first + employees.length - 1

  return (
    <Paper withBorder p="md">
      <Text size="sm" c="dimmed">
        Showing {first.toLocaleString()}–{last.toLocaleString()} of {meta.total.toLocaleString()}
      </Text>
      <EmployeesTable
        employees={employees}
        sort={filters.sort}
        onSort={filters.toggleSort}
        salarySortable={filters.get('currency') !== ''}
      />
      <Group justify="space-between" mt="md">
        <NativeSelect
          label="Rows per page"
          w={130}
          value={String(meta.per_page)}
          data={PAGE_SIZES}
          onChange={(event) => filters.setPerPage(event.currentTarget.value)}
        />
        <Pagination total={meta.total_pages} value={meta.page} onChange={filters.setPage} />
      </Group>
    </Paper>
  )
}

function DirectoryError({ error }: { error: Error }) {
  const details = error instanceof ApiError ? Object.entries(error.details) : []
  return (
    <Alert color="red" title="Could not load employees" role="alert">
      <Text size="sm">{error.message}</Text>
      {details.map(([field, messages]) => (
        <Text size="sm" key={field}>
          {field} {messages.join(', ')}
        </Text>
      ))}
    </Alert>
  )
}
