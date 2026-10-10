import { useCallback, useRef } from 'react'
import { useSearchParams } from 'react-router-dom'

/** Filters that narrow the directory. They live in the URL so a view can be bookmarked or shared. */
export const FILTER_KEYS = ['q', 'country', 'department', 'job_title', 'status', 'currency', 'min_salary', 'max_salary'] as const
export type FilterKey = (typeof FILTER_KEYS)[number]

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
    (changes: Record<string, string | null>) => {
      const next = new URLSearchParams(latest.current)
      Object.entries(changes).forEach(([key, value]) => (value ? next.set(key, value) : next.delete(key)))
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

  return {
    params: searchParams,
    get: (key: string) => searchParams.get(key) ?? '',
    activeFilters: FILTER_KEYS.filter((key) => searchParams.get(key)).map((key) => ({ key, value: searchParams.get(key)! })),
    setFilter: (key: FilterKey, value: string) => update({ [key]: value.trim() || null }),
    setPage: (page: number) => update({ page: page > 1 ? String(page) : null }),
    setPerPage: (perPage: string) => update({ per_page: perPage }),
    sort: searchParams.get('sort') ?? 'full_name',
    toggleSort,
    clearAll,
  }
}
