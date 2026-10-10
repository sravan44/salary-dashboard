import { Group, MultiSelect, NativeSelect, SimpleGrid, TextInput } from '@mantine/core'
import { useDebouncedCallback } from '@mantine/hooks'
import { useEffect, useState } from 'react'
import type { ReferenceData } from '../types'
import type { ListKey, useDirectoryFilters } from '../use-directory-filters'

type Props = { filters: ReturnType<typeof useDirectoryFilters>; reference: ReferenceData | undefined }

const options = (values: string[] = [], label: (v: string) => string = (v) => v) => values.map((value) => ({ value, label: label(value) }))

export function DirectoryFilters({ filters, reference }: Props) {
  const countryName = (code: string) => reference?.countries.find((c) => c.code === code)?.name ?? code
  // Several values per filter (OR). Searchable, because there are dozens of job titles.
  const multi = (key: ListKey, label: string, values: string[] | undefined, display?: (v: string) => string) => {
    const selected = filters.getAll(key)
    return (
      <MultiSelect
        label={label}
        placeholder={selected.length ? undefined : 'Any'}
        data={options(values, display)}
        value={selected}
        onChange={(next) => filters.setValues(key, next)}
        searchable
        clearable
        nothingFoundMessage="No matches"
      />
    )
  }
  const hasCurrency = filters.get('currency') !== ''

  return (
    <>
      <SearchBox value={filters.get('q')} onSearch={(value) => filters.setFilter('q', value)} />
      <SimpleGrid cols={{ base: 1, sm: 2, lg: 4 }} mt="sm">
        {multi('country', 'Country', reference?.countries.map((c) => c.code), countryName)}
        {multi('department', 'Department', reference?.departments)}
        {multi('job_title', 'Job title', reference?.job_titles)}
        {multi('status', 'Status', reference?.statuses)}
      </SimpleGrid>
      <SimpleGrid cols={{ base: 1, sm: 3 }} mt="sm">
        {/* One currency only: a salary range is meaningless across currencies. */}
        <NativeSelect
          label="Currency"
          value={filters.get('currency')}
          data={[{ value: '', label: 'Any' }, ...options(reference?.currencies)]}
          onChange={(event) => filters.setFilter('currency', event.currentTarget.value)}
        />
        <AmountInput label="Min salary" value={filters.get('min_salary')} disabled={!hasCurrency} onCommit={(v) => filters.setFilter('min_salary', v)} />
        <AmountInput label="Max salary" value={filters.get('max_salary')} disabled={!hasCurrency} onCommit={(v) => filters.setFilter('max_salary', v)} />
      </SimpleGrid>
    </>
  )
}

/** Searches as you type (debounced) and follows the URL when the search is cleared elsewhere. */
function SearchBox({ value, onSearch }: { value: string; onSearch: (value: string) => void }) {
  const [text, setText] = useState(value)
  const debouncedSearch = useDebouncedCallback(onSearch, 300)
  useEffect(() => setText(value), [value])

  return (
    <Group grow>
      <TextInput
        type="search"
        aria-label="Search employees"
        placeholder="Search by name, employee number or email"
        value={text}
        onChange={(event) => {
          setText(event.currentTarget.value)
          debouncedSearch(event.currentTarget.value)
        }}
      />
    </Group>
  )
}

/** Applies on Enter or when focus leaves, so typing "100000" does not fire six requests. */
function AmountInput(props: { label: string; value: string; disabled: boolean; onCommit: (value: string) => void }) {
  const [text, setText] = useState(props.value)
  useEffect(() => setText(props.value), [props.value])
  const commit = () => text !== props.value && props.onCommit(text)

  return (
    <TextInput
      label={props.label}
      inputMode="decimal"
      value={text}
      disabled={props.disabled}
      title={props.disabled ? 'Choose a currency first' : undefined}
      onChange={(event) => setText(event.currentTarget.value)}
      onBlur={commit}
      onKeyDown={(event) => event.key === 'Enter' && commit()}
    />
  )
}
