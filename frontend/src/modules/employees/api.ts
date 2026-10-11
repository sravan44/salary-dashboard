import { keepPreviousData, useMutation, useQuery, useQueryClient, type QueryClient } from '@tanstack/react-query'
import { getJson, sendJson } from '../../shared/api-client'
import type { AuditEntry, DirectoryResponse, EmployeeCreate, EmployeeDetail, EmployeeUpdate, HistoryConversion, ReferenceData, SalaryChange, SalaryHistoryData, SalaryRecord, StatusChange } from './types'
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

/** The salary history; with a reporting currency, each record also carries its converted amount. */
export function useSalaryHistory(id: string, report = '') {
  return useQuery({
    queryKey: ['salary-history', id, report],
    queryFn: async (): Promise<SalaryHistoryData> => {
      const params = report ? new URLSearchParams({ report }) : undefined
      const body = await getJson<{ data: SalaryRecord[]; meta?: { conversion: HistoryConversion } }>(`/api/v1/employees/${id}/compensations`, params)
      return { records: body.data, conversion: body.meta?.conversion ?? null }
    },
    placeholderData: keepPreviousData,
  })
}

export function useAuditTrail(id: string) {
  return useQuery({
    queryKey: ['audit-trail', id],
    queryFn: async () => (await getJson<{ data: AuditEntry[] }>(`/api/v1/employees/${id}/versions`)).data,
  })
}

/** A recorded pay change touches the history, the profile's current salary, the audit log, the directory and the dashboard. */
export function useRecordSalaryChange(id: string) {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: async (compensation: SalaryChange) =>
      (await sendJson<{ data: SalaryRecord }>('POST', `/api/v1/employees/${id}/compensations`, { compensation })).data,
    onSuccess: () => {
      for (const key of [['salary-history', id], ['employee', id], ['audit-trail', id], ['employees'], ['dashboard-overview'], ['dashboard-currency-detail']]) {
        void queryClient.invalidateQueries({ queryKey: key })
      }
    },
  })
}
