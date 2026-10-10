import { Table } from '@mantine/core'
import HighchartsReact from 'highcharts-react-official'
import type { Options } from 'highcharts'
import { CATEGORICAL, Highcharts, SERIES_COLOR, SURFACE } from '../../../shared/highcharts'
import type { DepartmentHeadcount } from '../types'
import { ChartCard } from './chart-card'

const TYPES = ['Donut', 'Pie', 'Bar'] as const
type DepartmentType = (typeof TYPES)[number]

function options(rows: DepartmentHeadcount[], type: DepartmentType): Options {
  if (type === 'Bar') {
    return {
      chart: { type: 'bar', height: rows.length * 36 + 60 },
      xAxis: { categories: rows.map((r) => r.department), lineWidth: 0 },
      yAxis: { title: { text: 'Employees' }, gridLineColor: '#e9e8e3' },
      legend: { enabled: false },
      tooltip: { pointFormat: '<b>{point.y:,.0f}</b> employees' },
      plotOptions: { bar: { borderRadius: 4, maxPointWidth: 24, borderWidth: 0 } },
      series: [{ type: 'bar', name: 'Employees', color: SERIES_COLOR, data: rows.map((r) => r.headcount) }],
    }
  }
  return {
    chart: { type: 'pie', height: 320 },
    tooltip: { pointFormat: '<b>{point.y:,.0f}</b> employees ({point.percentage:.1f}%)' },
    plotOptions: {
      pie: {
        innerSize: type === 'Donut' ? '55%' : '0%',
        borderWidth: 2,
        borderColor: SURFACE,
        dataLabels: { format: '{point.name}: {point.percentage:.0f}%' },
      },
    },
    // At most 8 departments, so the fixed categorical order is never cycled.
    series: [{ type: 'pie', name: 'Employees', data: rows.map((r, i) => ({ name: r.department, y: r.headcount, color: CATEGORICAL[i] })) }],
  }
}

export function HeadcountByDepartmentChart({ rows }: { rows: DepartmentHeadcount[] }) {
  return (
    <ChartCard
      title="Headcount by department"
      types={TYPES}
      renderChart={(type) => <HighchartsReact key={type} highcharts={Highcharts} options={options(rows, type)} />}
      table={
        <Table>
          <Table.Thead>
            <Table.Tr>
              <Table.Th>Department</Table.Th>
              <Table.Th ta="right">Employees</Table.Th>
            </Table.Tr>
          </Table.Thead>
          <Table.Tbody>
            {rows.map((r) => (
              <Table.Tr key={r.department}>
                <Table.Td>{r.department}</Table.Td>
                <Table.Td ta="right">{r.headcount.toLocaleString('en-US')}</Table.Td>
              </Table.Tr>
            ))}
          </Table.Tbody>
        </Table>
      }
    />
  )
}
