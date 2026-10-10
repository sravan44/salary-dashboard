import { Table } from '@mantine/core'
import HighchartsReact from 'highcharts-react-official'
import type { Options } from 'highcharts'
import { CATEGORICAL, Highcharts, SERIES_COLOR, SURFACE } from '../../../shared/highcharts'
import type { CountryHeadcount } from '../types'
import { ChartCard } from './chart-card'

const HEADCOUNT_TYPES = ['Bar', 'Column', 'Pie'] as const
type HeadcountType = (typeof HEADCOUNT_TYPES)[number]

const count = (value: number) => value.toLocaleString('en-US')

function headcountOptions(rows: CountryHeadcount[], type: HeadcountType): Options {
  if (type === 'Pie') {
    return {
      chart: { type: 'pie', height: 340 },
      tooltip: { pointFormat: '<b>{point.y:,.0f}</b> employees ({point.percentage:.1f}%)' },
      plotOptions: { pie: { borderWidth: 2, borderColor: SURFACE, dataLabels: { format: '{point.name}: {point.percentage:.0f}%' } } },
      series: [{ type: 'pie', name: 'Employees', data: rows.map((r, i) => ({ name: r.countryName, y: r.headcount, color: CATEGORICAL[i] })) }],
    }
  }
  const seriesType = type === 'Bar' ? 'bar' : 'column'
  return {
    chart: { type: seriesType, height: type === 'Bar' ? rows.length * 36 + 60 : 320 },
    xAxis: { categories: rows.map((r) => r.countryName), lineWidth: 0 },
    yAxis: { title: { text: 'Employees' }, gridLineColor: '#e9e8e3' },
    legend: { enabled: false },
    tooltip: { pointFormat: '<b>{point.y:,.0f}</b> employees' },
    plotOptions: { bar: { borderRadius: 4, maxPointWidth: 24, borderWidth: 0 }, column: { borderRadius: 4, maxPointWidth: 24, borderWidth: 0 } },
    series: [{ type: seriesType, name: 'Employees', color: SERIES_COLOR, data: rows.map((r) => r.headcount) }],
  }
}

export function HeadcountByCountryChart({ rows }: { rows: CountryHeadcount[] }) {
  return (
    <ChartCard
      title="Headcount by country"
      types={HEADCOUNT_TYPES}
      renderChart={(type) => <HighchartsReact key={type} highcharts={Highcharts} options={headcountOptions(rows, type)} />}
      table={
        <Table>
          <Table.Thead>
            <Table.Tr>
              <Table.Th>Country</Table.Th>
              <Table.Th ta="right">Employees</Table.Th>
            </Table.Tr>
          </Table.Thead>
          <Table.Tbody>
            {rows.map((row) => (
              <Table.Tr key={row.countryCode}>
                <Table.Td>{row.countryName}</Table.Td>
                <Table.Td ta="right">{count(row.headcount)}</Table.Td>
              </Table.Tr>
            ))}
          </Table.Tbody>
        </Table>
      }
    />
  )
}
