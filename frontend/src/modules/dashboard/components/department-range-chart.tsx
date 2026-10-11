import { Table } from '@mantine/core'
import type { ReactNode } from 'react'
import HighchartsReact from 'highcharts-react-official'
import type { Options } from 'highcharts'
import { formatMoney, formatMoneyCompact } from '../../../shared/format-money'
import { Highcharts, MUTED_MARK, SERIES_COLOR, SURFACE } from '../../../shared/highcharts'
import type { PayStat } from '../types'
import { ChartCard } from './chart-card'

const DEPARTMENT_TYPES = ['Range', 'Median'] as const
type DepartmentType = (typeof DEPARTMENT_TYPES)[number]

/** Range: a thin min–max bar with the median as a dot. Median: one column per department. */
function departmentOptions(rows: Omit<PayStat, 'currency'>[], currency: string, type: DepartmentType): Options {
  const detail = rows.map((r) => `${formatMoney(r.min, currency)} – ${formatMoney(r.max, currency)} · ${r.headcount.toLocaleString('en-US')} employees`)
  const medians = rows.map((r, i) => ({ y: Number(r.median), custom: { median: formatMoney(r.median, currency), detail: detail[i] } }))
  const base: Options = {
    xAxis: { categories: rows.map((r) => r.group), lineWidth: 0 },
    yAxis: {
      title: { text: `Annual base salary (${currency})` },
      gridLineColor: '#e9e8e3',
      labels: { formatter: (ctx) => formatMoneyCompact(Number(ctx.value), currency) },
    },
    legend: { enabled: type === 'Range' },
    tooltip: { headerFormat: '<span>{point.key}</span><br/>', pointFormat: '<b>{point.custom.median}</b> median<br/>{point.custom.detail}' },
  }
  if (type === 'Median') {
    return {
      ...base,
      chart: { type: 'column', height: 320 },
      plotOptions: { column: { borderRadius: 4, maxPointWidth: 24, borderWidth: 0 } },
      series: [{ type: 'column', name: 'Median', color: SERIES_COLOR, data: medians }],
    }
  }
  return {
    ...base,
    chart: { type: 'columnrange', inverted: true, height: rows.length * 40 + 90 },
    series: [
      {
        type: 'columnrange',
        name: 'Min – max',
        color: MUTED_MARK,
        pointWidth: 4,
        borderRadius: 2,
        borderWidth: 0,
        enableMouseTracking: false,
        data: rows.map((r) => [Number(r.min), Number(r.max)]),
      },
      {
        type: 'scatter',
        name: 'Median',
        color: SERIES_COLOR,
        marker: { symbol: 'circle', radius: 6, lineWidth: 2, lineColor: SURFACE },
        data: medians.map((m, i) => ({ ...m, x: i })),
      },
    ],
  }
}

export function DepartmentRangeChart({ rows, currency, label = currency, footer }: { rows: Omit<PayStat, 'currency'>[]; currency: string; label?: string; footer?: ReactNode }) {
  return (
    <ChartCard
      title={`Median and range by department (${label})`}
      footer={footer}
      types={DEPARTMENT_TYPES}
      empty={rows.length === 0 ? `No salaries in ${currency} for this selection.` : undefined}
      renderChart={(type) => <HighchartsReact key={type} highcharts={Highcharts} options={departmentOptions(rows, currency, type)} />}
      table={
        <Table>
          <Table.Thead>
            <Table.Tr>
              <Table.Th>Department</Table.Th>
              <Table.Th ta="right">Employees</Table.Th>
              <Table.Th ta="right">Min</Table.Th>
              <Table.Th ta="right">Median</Table.Th>
              <Table.Th ta="right">Max</Table.Th>
            </Table.Tr>
          </Table.Thead>
          <Table.Tbody>
            {rows.map((r) => (
              <Table.Tr key={r.group}>
                <Table.Td>{r.group}</Table.Td>
                <Table.Td ta="right">{r.headcount.toLocaleString('en-US')}</Table.Td>
                <Table.Td ta="right">{formatMoney(r.min, currency)}</Table.Td>
                <Table.Td ta="right">{formatMoney(r.median, currency)}</Table.Td>
                <Table.Td ta="right">{formatMoney(r.max, currency)}</Table.Td>
              </Table.Tr>
            ))}
          </Table.Tbody>
        </Table>
      }
    />
  )
}
