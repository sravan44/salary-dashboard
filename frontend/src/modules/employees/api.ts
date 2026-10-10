import { keepPreviousData, useMutation, useQuery, useQueryClient, type QueryClient } from '@tanstack/react-query'
import { getJson, sendJson } from '../../shared/api-client'
import type { DirectoryResponse, EmployeeCreate, EmployeeDetail, EmployeeUpdate, ReferenceData, StatusChange } from './types'
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

export function useEmployee(id: string) {
  return useQuery({
    queryKey: ['employee', id],
    queryFn: async () => (await getJson<{ data: EmployeeDetail }>(`/api/v1/employees/${id}`)).data,
  })
}

export function useCreateEmployee() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: async (employee: EmployeeCreate) =>
      (await sendJson<{ data: EmployeeDetail }>('POST', '/api/v1/employees', { employee })).data,
    onSuccess: (saved) => refreshAfterSave(queryClient, saved),
  })
}

export function useUpdateEmployee(id: string) {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: async (employee: EmployeeUpdate | StatusChange) =>
      (await sendJson<{ data: EmployeeDetail }>('PATCH', `/api/v1/employees/${id}`, { employee })).data,
    onSuccess: (saved) => refreshAfterSave(queryClient, saved),
  })
}

/** A saved employee changes the directory and the dashboard (e.g. a deactivated person leaves its figures). */
function refreshAfterSave(queryClient: QueryClient, saved: EmployeeDetail) {
  queryClient.setQueryData(['employee', String(saved.id)], saved)
  void queryClient.invalidateQueries({ queryKey: ['employees'] })
  void queryClient.invalidateQueries({ queryKey: ['dashboard-overview'] })
  void queryClient.invalidateQueries({ queryKey: ['dashboard-currency-detail'] })
}
