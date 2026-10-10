import { Button, CloseButton, Group, Pill } from '@mantine/core'
import type { FilterKey } from '../use-directory-filters'

const LABELS: Record<FilterKey, string> = {
  q: 'Search',
  country: 'Country',
  department: 'Department',
  job_title: 'Job title',
  status: 'Status',
  currency: 'Currency',
  min_salary: 'Min salary',
  max_salary: 'Max salary',
}

type Props = {
  active: { key: FilterKey; value: string }[]
  describe: (key: FilterKey, value: string) => string
  onRemove: (key: FilterKey) => void
  onClearAll: () => void
}

export function FilterChips({ active, describe, onRemove, onClearAll }: Props) {
  if (active.length === 0) return null

  return (
    <Group gap="xs" mt="sm" aria-label="Active filters">
      {active.map(({ key, value }) => {
        const text = `${LABELS[key]}: ${describe(key, value)}`
        return (
          <Pill key={key} size="md">
            <Group gap={4} wrap="nowrap">
              {text}
              <CloseButton size="xs" aria-label={`Remove filter ${text}`} onClick={() => onRemove(key)} />
            </Group>
          </Pill>
        )
      })}
      <Button variant="subtle" size="compact-sm" onClick={onClearAll}>
        Clear all filters
      </Button>
    </Group>
  )
}
