import { useCallback, useRef } from 'react'
import { useSearchParams } from 'react-router-dom'

/** Filters that narrow the directory. They live in the URL so a view can be bookmarked or shared. */
export const FILTER_KEYS = ['q', 'country', 'department', 'job_title', 'status', 'currency', 'min_salary', 'max_salary'] as const
export type FilterKey = (typeof FILTER_KEYS)[number]

/** Filters that take several values (OR), stored as repeated keys: ?country=IN&country=US. */
export const LIST_KEYS = ['country', 'department', 'job_title', 'status'] as const
export type ListKey = (typeof LIST_KEYS)[number]
export type SingleKey = Exclude<FilterKey, ListKey>

export const isListKey = (key: string): key is ListKey => (LIST_KEYS as readonly string[]).includes(key)

const SALARY_KEYS = ['min_salary', 'max_salary'] as const

export function useDirectoryFilters() {
  const [searchParams, setSearchParams] = useSearchParams()

  // React Router hands `setSearchParams(prev => …)` the params from the last render, and navigations
  // run as transitions, so two quick changes (e.g. a debounced search firing right after a filter
  // change) could each start from the same stale params and overwrite one another. Every change is
  // therefore built from `latest`, which is updated synchronously with each change.
  const latest = useRef(searchParams)
  latest.current = searchParams

  const update = useCallback(
    (changes: Record<string, string | string[] | null>) => {
      const next = new URLSearchParams(latest.current)
      Object.entries(changes).forEach(([key, value]) => {
        next.delete(key)
        ;[value ?? []].flat().forEach((v) => v && next.append(key, v))
      })
      // A salary range only makes sense within one currency.
      if (!next.get('currency')) SALARY_KEYS.forEach((key) => next.delete(key))
      // Any change other than paging starts again from the first page.
      if (!('page' in changes)) next.delete('page')
      latest.current = next
      setSearchParams(next)
    },
    [setSearchParams],
  )

  const clearAll = useCallback(() => {
    latest.current = new URLSearchParams()
    setSearchParams(latest.current)
  }, [setSearchParams])

  const toggleSort = (field: string) => {
    const current = latest.current.get('sort') ?? 'full_name'
    update({ sort: current === field ? `-${field}` : field })
  }

  const getAll = (key: ListKey) => [...new Set(searchParams.getAll(key).filter(Boolean))]

  return {
    params: searchParams,
    get: (key: SingleKey | 'sort') => searchParams.get(key) ?? '',
    getAll,
    activeFilters: FILTER_KEYS.flatMap((key) =>
      (isListKey(key) ? getAll(key) : [searchParams.get(key) ?? ''].filter(Boolean)).map((value) => ({ key, value })),
    ),
    setFilter: (key: SingleKey, value: string) => update({ [key]: value.trim() || null }),
    setValues: (key: ListKey, values: string[]) => update({ [key]: values }),
    /** Removes one chip: a single value of a multi-value filter, or the whole single-value filter. */
    removeFilter: (key: FilterKey, value: string) =>
      update({ [key]: isListKey(key) ? latest.current.getAll(key).filter((v) => v !== value) : null }),
    setPage: (page: number) => update({ page: page > 1 ? String(page) : null }),
    setPerPage: (perPage: string) => update({ per_page: perPage }),
    sort: searchParams.get('sort') ?? 'full_name',
    toggleSort,
    clearAll,
  }
}
