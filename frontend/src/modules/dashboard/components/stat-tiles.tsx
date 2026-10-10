import { Paper, SimpleGrid, Text } from '@mantine/core'

type Tile = { label: string; value: number }

/** Headline numbers: a figure, not a chart. */
export function StatTiles({ tiles }: { tiles: Tile[] }) {
  return (
    <SimpleGrid cols={{ base: 1, sm: 3 }} component="section" aria-label="Headline numbers">
      {tiles.map((tile) => (
        <Paper withBorder p="md" key={tile.label}>
          <Text size="sm" c="dimmed">
            {tile.label}
          </Text>
          <Text fz={28} fw={700} style={{ fontVariantNumeric: 'tabular-nums' }}>
            {tile.value.toLocaleString('en-US')}
          </Text>
        </Paper>
      ))}
    </SimpleGrid>
  )
}
