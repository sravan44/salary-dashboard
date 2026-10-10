import { keepPreviousData, useQuery } from '@tanstack/react-query'
import { getJson } from '../../shared/api-client'
import type { DirectoryResponse, ReferenceData } from './types'

export function useEmployeeDirectory(params: URLSearchParams) {
  const key = params.toString()
  return useQuery({
    queryKey: ['employees', key],
    queryFn: () => getJson<DirectoryResponse>('/api/v1/employees', new URLSearchParams(key)),
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
