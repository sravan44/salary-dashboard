import { Table } from '@mantine/core'
import type { ReactNode } from 'react'
import HighchartsReact from 'highcharts-react-official'
import type { Options } from 'highcharts'
import { formatMoney, formatMoneyCompact } from '../../../shared/format-money'
import { Highcharts, SERIES_COLOR } from '../../../shared/highcharts'
import type { PayStat } from '../types'
import { ChartCard } from './chart-card'

const TYPES = ['Bar', 'Column'] as const
type JobTitleType = (typeof TYPES)[number]

function options(rows: Omit<PayStat, 'currency'>[], currency: string, type: JobTitleType): Options {
  const seriesType = type === 'Bar' ? 'bar' : 'column'
  return {
    chart: { type: seriesType, height: type === 'Bar' ? rows.length * 32 + 70 : 340 },
    xAxis: { categories: rows.map((r) => r.group), lineWidth: 0 },
    yAxis: {
      title: { text: `Median annual base salary (${currency})` },
      gridLineColor: '#e9e8e3',
      labels: { formatter: (ctx) => formatMoneyCompact(Number(ctx.value), currency) },
    },
    legend: { enabled: false },
    tooltip: { pointFormat: '<b>{point.custom.median}</b> median · {point.custom.headcount} employees' },
    plotOptions: {
      bar: { borderRadius: 4, maxPointWidth: 24, borderWidth: 0 },
      column: { borderRadius: 4, maxPointWidth: 24, borderWidth: 0 },
    },
    series: [
      {
        type: seriesType,
        name: 'Median',
        color: SERIES_COLOR,
        data: rows.map((r) => ({ y: Number(r.median), custom: { median: formatMoney(r.median, currency), headcount: r.headcount.toLocaleString('en-US') } })),
      },
    ],
  }
}

/** The ten largest job titles in the chosen currency, by median salary. */
export function JobTitlePayChart({ rows, currency, label = currency, footer }: { rows: Omit<PayStat, 'currency'>[]; currency: string; label?: string; footer?: ReactNode }) {
  return (
    <ChartCard
      title={`Median salary by job title (${label})`}
      footer={footer}
      types={TYPES}
      empty={rows.length === 0 ? `No salaries in ${currency} for this selection.` : undefined}
      renderChart={(type) => <HighchartsReact key={type} highcharts={Highcharts} options={options(rows, currency, type)} />}
      table={
        <Table>
          <Table.Thead>
            <Table.Tr>
              <Table.Th>Job title</Table.Th>
              <Table.Th ta="right">Employees</Table.Th>
              <Table.Th ta="right">Median</Table.Th>
            </Table.Tr>
          </Table.Thead>
          <Table.Tbody>
            {rows.map((r) => (
              <Table.Tr key={r.group}>
                <Table.Td>{r.group}</Table.Td>
                <Table.Td ta="right">{r.headcount.toLocaleString('en-US')}</Table.Td>
                <Table.Td ta="right">{formatMoney(r.median, currency)}</Table.Td>
              </Table.Tr>
            ))}
          </Table.Tbody>
        </Table>
      }
    />
  )
}
