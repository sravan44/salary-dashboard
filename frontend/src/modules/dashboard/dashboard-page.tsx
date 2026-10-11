import { Alert, Button, Center, Group, Loader, MultiSelect, NativeSelect, SimpleGrid, Stack, Text, Title } from '@mantine/core'
import { useConverted, useCurrencyDetail, useDashboardOverview } from './api'
import { DepartmentRangeChart } from './components/department-range-chart'
import { FxProvenance } from './components/fx-provenance'
import { HeadcountByCountryChart } from './components/headcount-by-country-chart'
import { HeadcountByDepartmentChart } from './components/headcount-by-department-chart'
import { HiresByYearChart } from './components/hires-by-year-chart'
import { JobTitlePayChart } from './components/job-title-pay-chart'
import { SalaryDistributionChart } from './components/salary-distribution-chart'
import { StatTiles } from './components/stat-tiles'
import { useDashboardFilters, type DashboardListParam } from './use-dashboard-filters'
import type { Converted, DashboardReference } from './types'

export function DashboardPage() {
  const filters = useDashboardFilters()
  const overview = useDashboardOverview(filters.filters)
  const counts = overview.data?.dashboard
  // Salary charts show one currency: the chosen one, or the most common in this selection. While the
  // previous selection's numbers are still on screen (placeholder), don't guess from them.
  const defaultCurrency = overview.isPlaceholderData ? undefined : counts?.currencies[0]?.currency
  const currency = filters.currency || defaultCurrency
  const report = filters.reportCurrency
  // Per-currency charts are not needed while a reporting currency is chosen.
  const detail = useCurrencyDetail(filters.filters, report ? undefined : currency)
  const converted = useConverted(filters.filters, report)

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
          <Group align="flex-start">
            <NativeSelect
              label="Reporting currency"
              description="Convert every salary into one currency at reference rates (indicative)."
              w={360}
              value={report}
              data={[
                { value: '', label: 'Original currencies (no conversion)' },
                ...(overview.data?.reference.currencies ?? []).map((c) => ({ value: c, label: c })),
              ]}
              onChange={(event) => filters.setReportCurrency(event.currentTarget.value)}
            />
            {!report && (
              <NativeSelect
                label="Salary currency"
                description="Without conversion, salary charts show one currency at a time; amounts are never combined."
                w={360}
                value={currency}
                data={counts.currencies.map((c) => ({ value: c.currency, label: `${c.currency} (${c.headcount.toLocaleString('en-US')} employees)` }))}
                onChange={(event) => filters.setCurrency(event.currentTarget.value)}
              />
            )}
          </Group>
          {report ? (
            <ConvertedCharts query={converted} />
          ) : detail.isError ? (
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

/** Salary charts in the reporting currency, each with the provenance of its rates. */
function ConvertedCharts({ query }: { query: ReturnType<typeof useConverted> }) {
  if (query.isError) {
    return (
      <Alert color="red" title="Could not load converted figures" role="alert">
        {query.error.message}
      </Alert>
    )
  }
  if (!query.data) {
    return (
      <Center p="md">
        <Loader size="sm" aria-label="Loading converted figures" />
      </Center>
    )
  }
  const c: Converted = query.data.dashboard.converted
  if (!c.available) {
    return (
      <Alert color="yellow" title="No exchange rates yet" role="alert">
        No exchange rates have been fetched yet, so nothing can be converted. Run <code>bin/rails fx:refresh</code> (it also runs when
        the app container starts) and try again.
      </Alert>
    )
  }
  const label = `${c.reportingCurrency}, converted`
  const footer = <FxProvenance converted={c} />
  return (
    <Stack gap="sm">
      {c.stale && (
        <Alert color="yellow" role="alert">
          {`These rates are more than 7 days old (${c.rateDate}). Run the rate refresh to update them.`}
        </Alert>
      )}
      {c.excludedCurrencies.map((e) => (
        <Alert key={e.currency} color="yellow" role="alert">
          {`${e.headcount.toLocaleString('en-US')} employees paid in ${e.currency} are not included: no exchange rate is available.`}
        </Alert>
      ))}
      <SimpleGrid cols={{ base: 1, lg: 2 }}>
        <SalaryDistributionChart buckets={c.distribution} currency={c.reportingCurrency} label={label} footer={footer} />
        <DepartmentRangeChart rows={c.byDepartment} currency={c.reportingCurrency} label={label} footer={footer} />
        <JobTitlePayChart rows={c.byJobTitle} currency={c.reportingCurrency} label={label} footer={footer} />
      </SimpleGrid>
    </Stack>
  )
}
