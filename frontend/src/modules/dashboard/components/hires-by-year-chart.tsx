import { Table } from '@mantine/core'
import HighchartsReact from 'highcharts-react-official'
import type { Options } from 'highcharts'
import { Highcharts, SERIES_COLOR } from '../../../shared/highcharts'
import type { YearHeadcount } from '../types'
import { ChartCard } from './chart-card'

const TYPES = ['Line', 'Column', 'Area'] as const
type HiresType = (typeof TYPES)[number]

function options(rows: YearHeadcount[], type: HiresType): Options {
  const seriesType = type === 'Line' ? 'line' : type === 'Column' ? 'column' : 'area'
  return {
    chart: { type: seriesType, height: 300 },
    xAxis: { categories: rows.map((r, i) => (i === rows.length - 1 ? `${r.year} (to date)` : String(r.year))), title: { text: 'Hire year' } },
    // Counts start at zero, otherwise a partial final year reads as a collapse.
    yAxis: { title: { text: 'Employees' }, min: 0, allowDecimals: false, gridLineColor: '#e9e8e3' },
    legend: { enabled: false },
    tooltip: { pointFormat: '<b>{point.y:,.0f}</b> current employees hired' },
    plotOptions: {
      line: { lineWidth: 2, marker: { radius: 4 } },
      area: { lineWidth: 2, fillOpacity: 0.2, marker: { radius: 4 } },
      column: { borderRadius: 4, maxPointWidth: 24, borderWidth: 0 },
    },
    series: [{ type: seriesType, name: 'Hires', color: SERIES_COLOR, data: rows.map((r) => r.headcount) }],
  }
}

/** Counts current (active) employees by hire year; people who already left are not in it. */
export function HiresByYearChart({ rows }: { rows: YearHeadcount[] }) {
  return (
    <ChartCard
      title="Hires by year (current employees)"
      types={TYPES}
      renderChart={(type) => <HighchartsReact key={type} highcharts={Highcharts} options={options(rows, type)} />}
      table={
        <Table>
          <Table.Thead>
            <Table.Tr>
              <Table.Th>Year</Table.Th>
              <Table.Th ta="right">Employees</Table.Th>
            </Table.Tr>
          </Table.Thead>
          <Table.Tbody>
            {rows.map((r) => (
              <Table.Tr key={r.year}>
                <Table.Td>{r.year}</Table.Td>
                <Table.Td ta="right">{r.headcount.toLocaleString('en-US')}</Table.Td>
              </Table.Tr>
            ))}
          </Table.Tbody>
        </Table>
      }
    />
  )
}
