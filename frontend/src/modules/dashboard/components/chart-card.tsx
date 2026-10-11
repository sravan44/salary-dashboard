import { Group, Paper, SegmentedControl, Text } from '@mantine/core'
import { useState, type ReactNode } from 'react'

type Props<T extends string> = {
  title: string
  /** Chart types the reader can switch between; the first is the default. "Table" is always offered too. */
  types: readonly T[]
  renderChart: (type: T) => ReactNode
  table: ReactNode
  empty?: string
  /** Shown under the chart and the table, e.g. how converted figures were converted. */
  footer?: ReactNode
}

/** A titled chart with a type switcher and a Table view: every value in the chart is also reachable as text. */
export function ChartCard<T extends string>({ title, types, renderChart, table, empty, footer }: Props<T>) {
  const [view, setView] = useState<string>(types[0])
  return (
    <Paper withBorder p="md" component="section" aria-label={title}>
      <Group justify="space-between" mb="sm">
        <Text fw={600}>{title}</Text>
        {!empty && <SegmentedControl size="xs" data={[...types, 'Table']} value={view} onChange={setView} aria-label={`${title} view`} />}
      </Group>
      {empty ? (
        <Text c="dimmed" size="sm">
          {empty}
        </Text>
      ) : view === 'Table' ? (
        table
      ) : (
        <figure aria-label={`${title} chart`} style={{ margin: 0 }}>
          {renderChart(view as T)}
        </figure>
      )}
      {footer}
    </Paper>
  )
}
