import { act, renderHook } from '@testing-library/react'
import type { ReactNode } from 'react'
import { MemoryRouter, useLocation } from 'react-router-dom'
import { useDirectoryFilters } from './use-directory-filters'

function setup(initial = '/employees') {
  const wrapper = ({ children }: { children: ReactNode }) => <MemoryRouter initialEntries={[initial]}>{children}</MemoryRouter>
  return renderHook(() => ({ filters: useDirectoryFilters(), location: useLocation() }), { wrapper })
}

const params = (result: ReturnType<typeof setup>['result']) => new URLSearchParams(result.current.location.search)

describe('useDirectoryFilters', () => {
  // In a real browser, events can arrive before React Router has re-rendered (navigations run as
  // transitions), so two updates may run against the same render. Neither may overwrite the other.
  it('keeps both changes when two filters are set in the same tick', () => {
    const { result } = setup()

    act(() => {
      result.current.filters.setValues('country', ['IN', 'US'])
      result.current.filters.setValues('department', ['Engineering'])
    })

    expect(params(result).getAll('country')).toEqual(['IN', 'US'])
    expect(params(result).getAll('department')).toEqual(['Engineering'])
  })

  it('removes one value of a multi-value filter and keeps the rest', () => {
    const { result } = setup('/employees?country=IN&country=US&q=rao')

    act(() => result.current.filters.removeFilter('country', 'IN'))
    expect(params(result).getAll('country')).toEqual(['US'])

    act(() => result.current.filters.removeFilter('q', 'rao'))
    expect(params(result).toString()).toBe('country=US')
  })

  it('lists one active filter per value', () => {
    const { result } = setup('/employees?country=IN&country=US&currency=USD')

    expect(result.current.filters.activeFilters).toEqual([
      { key: 'country', value: 'IN' },
      { key: 'country', value: 'US' },
      { key: 'currency', value: 'USD' },
    ])
  })

  it('flips the sort direction when toggled twice in the same tick', () => {
    const { result } = setup()

    act(() => {
      result.current.filters.toggleSort('salary')
      result.current.filters.toggleSort('salary')
    })

    expect(params(result).get('sort')).toBe('-salary')
  })

  it('resets to page 1 on any filter change but not when paging', () => {
    const { result } = setup('/employees?page=4')

    act(() => result.current.filters.setPage(5))
    expect(params(result).get('page')).toBe('5')

    act(() => result.current.filters.setValues('status', ['active']))
    expect(params(result).has('page')).toBe(false)
  })

  it('drops the salary range when no currency is selected', () => {
    const { result } = setup('/employees?currency=USD&min_salary=1&max_salary=2')

    act(() => result.current.filters.setFilter('currency', ''))

    expect(params(result).toString()).toBe('')
  })
})
