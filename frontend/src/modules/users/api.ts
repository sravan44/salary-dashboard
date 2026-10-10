import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { getJson, sendJson } from '../../shared/api-client'

export type UserRow = { id: number; email: string; roles: string[]; created_at: string }
export type NewUser = { email: string; roles: string[]; password: string }

const USERS_KEY = ['users'] as const

export function useUsers() {
  return useQuery({ queryKey: USERS_KEY, queryFn: async () => (await getJson<{ data: UserRow[] }>('/api/v1/users')).data })
}

export function useCreateUser() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: async (user: NewUser) => (await sendJson<{ data: UserRow }>('POST', '/api/v1/users', { user })).data,
    onSuccess: () => queryClient.invalidateQueries({ queryKey: USERS_KEY }),
  })
}

export function useUpdateRoles(id: number) {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: async (roles: string[]) => (await sendJson<{ data: UserRow }>('PATCH', `/api/v1/users/${id}`, { user: { roles } })).data,
    onSuccess: () => queryClient.invalidateQueries({ queryKey: USERS_KEY }),
  })
}
