import { Table } from '@mantine/core'
import type { ReactNode } from 'react'
import HighchartsReact from 'highcharts-react-official'
import type { Options } from 'highcharts'
import { formatMoney, formatMoneyCompact } from '../../../shared/format-money'
import { Highcharts, SERIES_COLOR, SURFACE } from '../../../shared/highcharts'
import type { SalaryBucket } from '../types'
import { ChartCard } from './chart-card'

const DISTRIBUTION_TYPES = ['Column', 'Line', 'Area'] as const
type DistributionType = (typeof DISTRIBUTION_TYPES)[number]

const rangeLabel = (b: SalaryBucket, currency: string) => `${formatMoney(b.from, currency)} – ${formatMoney(b.to, currency)}`

function distributionOptions(buckets: SalaryBucket[], currency: string, type: DistributionType): Options {
  const seriesType = type === 'Column' ? 'column' : type === 'Line' ? 'line' : 'area'
  const ranges = buckets.map((b) => rangeLabel(b, currency))
  return {
    chart: { type: seriesType, height: 300 },
    xAxis: { categories: buckets.map((b) => formatMoneyCompact(Number(b.from), currency)), title: { text: `Salary from (${currency})` } },
    yAxis: { title: { text: 'Employees' }, allowDecimals: false, gridLineColor: '#e9e8e3' },
    legend: { enabled: false },
    tooltip: { headerFormat: '', pointFormat: '<b>{point.y:,.0f}</b> employees<br/>{point.custom.range}' },
    plotOptions: {
      column: { borderRadius: 4, borderWidth: 2, borderColor: SURFACE, groupPadding: 0, pointPadding: 0, maxPointWidth: 48 },
      line: { lineWidth: 2, marker: { radius: 4 } },
      area: { lineWidth: 2, fillOpacity: 0.2, marker: { radius: 4 } },
    },
    series: [{ type: seriesType, name: 'Employees', color: SERIES_COLOR, data: buckets.map((b, i) => ({ y: b.count, custom: { range: ranges[i] } })) }],
  }
}

export function SalaryDistributionChart({ buckets, currency, label = currency, footer }: { buckets: SalaryBucket[]; currency: string; label?: string; footer?: ReactNode }) {
  return (
    <ChartCard
      title={`Salary distribution (${label})`}
      footer={footer}
      types={DISTRIBUTION_TYPES}
      empty={buckets.length === 0 ? `No salaries in ${currency} for this selection.` : undefined}
      renderChart={(type) => <HighchartsReact key={type} highcharts={Highcharts} options={distributionOptions(buckets, currency, type)} />}
      table={
        <Table>
          <Table.Thead>
            <Table.Tr>
              <Table.Th>Salary range</Table.Th>
              <Table.Th ta="right">Employees</Table.Th>
            </Table.Tr>
          </Table.Thead>
          <Table.Tbody>
            {buckets.map((b) => (
              <Table.Tr key={b.from}>
                <Table.Td>{rangeLabel(b, currency)}</Table.Td>
                <Table.Td ta="right">{b.count.toLocaleString('en-US')}</Table.Td>
              </Table.Tr>
            ))}
          </Table.Tbody>
        </Table>
      }
    />
  )
}
