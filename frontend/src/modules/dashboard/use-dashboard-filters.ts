import { useCallback, useRef } from 'react'
import { useSearchParams } from 'react-router-dom'
import type { DashboardFiltersInput } from './types'

export type DashboardParam = 'country' | 'department' | 'job_title' | 'currency'

/** The schema's enum name for a department, e.g. "Customer Support" → CUSTOMER_SUPPORT. */
export const departmentEnum = (name: string) => name.toUpperCase().replace(/ /g, '_')

/** Dashboard filters and chart currency, kept in the URL so a view can be bookmarked. */
export function useDashboardFilters() {
  const [searchParams, setSearchParams] = useSearchParams()
  // Built from a synchronously updated ref so quick successive changes never overwrite each other
  // (same reason as in the employee directory).
  const latest = useRef(searchParams)
  latest.current = searchParams

  const set = useCallback(
    (key: DashboardParam, value: string) => {
      const next = new URLSearchParams(latest.current)
      if (value) next.set(key, value)
      else next.delete(key)
      latest.current = next
      setSearchParams(next)
    },
    [setSearchParams],
  )

  const clear = useCallback(() => {
    latest.current = new URLSearchParams()
    setSearchParams(latest.current)
  }, [setSearchParams])

  const get = (key: DashboardParam) => searchParams.get(key) ?? ''
  const filters: DashboardFiltersInput = {}
  if (get('country')) filters.country = get('country')
  if (get('department')) filters.department = departmentEnum(get('department'))
  if (get('job_title')) filters.jobTitle = get('job_title')

  return { get, set, clear, filters, hasFilters: Object.keys(filters).length > 0 }
}
