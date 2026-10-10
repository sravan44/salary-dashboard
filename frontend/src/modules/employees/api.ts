import { keepPreviousData, useQuery } from '@tanstack/react-query'
import { getJson } from '../../shared/api-client'
import type { DirectoryResponse, ReferenceData } from './types'
import { isListKey } from './use-directory-filters'

/** The page URL repeats keys (?country=IN&country=US); Rails reads lists as country[]=IN&country[]=US. */
export function toApiParams(params: URLSearchParams) {
  const api = new URLSearchParams()
  params.forEach((value, key) => api.append(isListKey(key) ? `${key}[]` : key, value))
  return api
}

export function useEmployeeDirectory(params: URLSearchParams) {
  const key = params.toString()
  return useQuery({
    queryKey: ['employees', key],
    queryFn: () => getJson<DirectoryResponse>('/api/v1/employees', toApiParams(new URLSearchParams(key))),
    placeholderData: keepPreviousData, // keep the table on screen while the next page loads
  })
}

export function useReferenceData() {
  return useQuery({
    queryKey: ['reference'],
    queryFn: async () => (await getJson<{ data: ReferenceData }>('/api/v1/reference')).data,
    staleTime: Infinity,
  })
}
