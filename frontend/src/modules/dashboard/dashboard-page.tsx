import { Alert, Button, Center, Group, Loader, MultiSelect, NativeSelect, SimpleGrid, Stack, Text, Title } from '@mantine/core'
import { useCurrencyDetail, useDashboardOverview } from './api'
import { DepartmentRangeChart } from './components/department-range-chart'
import { HeadcountByCountryChart } from './components/headcount-by-country-chart'
import { HeadcountByDepartmentChart } from './components/headcount-by-department-chart'
import { HiresByYearChart } from './components/hires-by-year-chart'
import { JobTitlePayChart } from './components/job-title-pay-chart'
import { SalaryDistributionChart } from './components/salary-distribution-chart'
import { StatTiles } from './components/stat-tiles'
import { useDashboardFilters, type DashboardListParam } from './use-dashboard-filters'
import type { DashboardReference } from './types'

export function DashboardPage() {
  const filters = useDashboardFilters()
  const overview = useDashboardOverview(filters.filters)
  const counts = overview.data?.dashboard
  // Salary charts show one currency: the chosen one, or the most common in this selection. While the
  // previous selection's numbers are still on screen (placeholder), don't guess from them.
  const defaultCurrency = overview.isPlaceholderData ? undefined : counts?.currencies[0]?.currency
  const currency = filters.currency || defaultCurrency
  const detail = useCurrencyDetail(filters.filters, currency)

  return (
    <Stack gap="md">
      <Title order={2}>Dashboard</Title>
      <FilterBar filters={filters} reference={overview.data?.reference} />
      {overview.isError ? (
        <Alert color="red" title="Could not load the dashboard" role="alert">
          {overview.error.message}
        </Alert>
      ) : !counts ? (
        <Center p="xl">
          <Loader aria-label="Loading dashboard" />
        </Center>
      ) : counts.headcount === 0 ? (
        <Text>No active employees match these filters.</Text>
      ) : (
        <>
          <StatTiles
            tiles={[
              { label: 'Active employees', value: counts.headcount },
              { label: 'Countries', value: counts.countriesCount },
              { label: 'Currencies', value: counts.currencies.length },
            ]}
          />
          <SimpleGrid cols={{ base: 1, lg: 2 }}>
            <HeadcountByCountryChart rows={counts.headcountByCountry} />
            <HeadcountByDepartmentChart rows={counts.headcountByDepartment} />
          </SimpleGrid>
          <HiresByYearChart rows={counts.hiresByYear} />
          <NativeSelect
            label="Salary currency"
            description="Salary charts show one currency at a time; amounts in different currencies are never combined."
            w={360}
            value={currency}
            data={counts.currencies.map((c) => ({ value: c.currency, label: `${c.currency} (${c.headcount.toLocaleString('en-US')} employees)` }))}
            onChange={(event) => filters.setCurrency(event.currentTarget.value)}
          />
          {detail.isError ? (
            <Alert color="red" title="Could not load salary charts" role="alert">
              {detail.error.message}
            </Alert>
          ) : detail.data && currency ? (
            <SimpleGrid cols={{ base: 1, lg: 2 }}>
              <SalaryDistributionChart buckets={detail.data.dashboard.distribution} currency={currency} />
              <DepartmentRangeChart rows={detail.data.dashboard.byDepartment} currency={currency} />
              <JobTitlePayChart rows={detail.data.dashboard.byJobTitle} currency={currency} />
            </SimpleGrid>
          ) : (
            <Center p="md">
              <Loader size="sm" aria-label="Loading salary charts" />
            </Center>
          )}
        </>
      )}
    </Stack>
  )
}

function FilterBar({ filters, reference }: { filters: ReturnType<typeof useDashboardFilters>; reference?: DashboardReference }) {
  // Several values per filter (OR within a filter, AND across filters).
  const select = (key: DashboardListParam, label: string, options: { value: string; label: string }[]) => {
    const selected = filters.getAll(key)
    return (
      <MultiSelect
        label={label}
        w={260}
        placeholder={selected.length ? undefined : 'Any'}
        data={options}
        value={selected}
        onChange={(values) => filters.setValues(key, values)}
        searchable
        clearable
        nothingFoundMessage="No matches"
      />
    )
  }
  const plain = (values: string[] = []) => values.map((value) => ({ value, label: value }))

  return (
    <Group align="flex-start" wrap="wrap">
      {select('country', 'Country', (reference?.countries ?? []).map((c) => ({ value: c.code, label: c.name })))}
      {select('department', 'Department', plain(reference?.departments))}
      {select('job_title', 'Job title', plain(reference?.jobTitles))}
      {filters.hasFilters && (
        <Button variant="subtle" mt={25} onClick={filters.clear}>
          Clear filters
        </Button>
      )}
    </Group>
  )
}
