import { useCallback, useRef } from 'react'
import { useSearchParams } from 'react-router-dom'
import type { DashboardFiltersInput } from './types'

/** Filters that take several values (OR), stored as repeated keys: ?country=IN&country=US. */
export type DashboardListParam = 'country' | 'department' | 'job_title'

/** The schema's enum name for a department, e.g. "Customer Support" → CUSTOMER_SUPPORT. */
export const departmentEnum = (name: string) => name.toUpperCase().replace(/ /g, '_')

/** Dashboard filters and chart currency, kept in the URL so a view can be bookmarked. */
export function useDashboardFilters() {
  const [searchParams, setSearchParams] = useSearchParams()
  // Built from a synchronously updated ref so quick successive changes never overwrite each other
  // (same reason as in the employee directory).
  const latest = useRef(searchParams)
  latest.current = searchParams

  const change = useCallback(
    (key: string, values: string[]) => {
      const next = new URLSearchParams(latest.current)
      next.delete(key)
      values.filter(Boolean).forEach((value) => next.append(key, value))
      latest.current = next
      setSearchParams(next)
    },
    [setSearchParams],
  )

  const clear = useCallback(() => {
    latest.current = new URLSearchParams()
    setSearchParams(latest.current)
  }, [setSearchParams])

  const getAll = (key: DashboardListParam) => [...new Set(searchParams.getAll(key).filter(Boolean))]
  const filters: DashboardFiltersInput = {}
  if (getAll('country').length) filters.country = getAll('country')
  if (getAll('department').length) filters.department = getAll('department').map(departmentEnum)
  if (getAll('job_title').length) filters.jobTitle = getAll('job_title')

  return {
    getAll,
    setValues: (key: DashboardListParam, values: string[]) => change(key, values),
    /** The salary charts' currency: always exactly one, never several. */
    currency: searchParams.get('currency') ?? '',
    setCurrency: (currency: string) => change('currency', [currency]),
    /** The reporting currency for converted analytics; empty = original currencies (no conversion). */
    reportCurrency: searchParams.get('report') ?? '',
    setReportCurrency: (currency: string) => change('report', [currency]),
    clear,
    filters,
    hasFilters: Object.keys(filters).length > 0,
  }
}
