import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { getJson, sendJson } from '../../shared/api-client'

/** password_set is false for an invited user who hasn't used their set-password link yet. */
export type UserRow = { id: number; email: string; roles: string[]; password_set: boolean; created_at: string }
/** Empty password: the account has none yet; send them a password link when ready. */
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

/** Admin sets someone's password directly; that user is signed out everywhere. */
export function useSetUserPassword(id: number) {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: async (body: { password: string; password_confirmation: string }) =>
      (await sendJson<{ data: UserRow }>('PATCH', `/api/v1/users/${id}/password`, body)).data,
    onSuccess: () => queryClient.invalidateQueries({ queryKey: USERS_KEY }),
  })
}

/**
 * Admin emails the chosen users a password link: a set-password link (24 h) to anyone without a password yet,
 * a reset link (2 h) to anyone with one. Up to 50 users at a time.
 */
export function useSendPasswordLinks() {
  return useMutation({
    mutationFn: async (userIds: number[]) =>
      (await sendJson<{ data: { sent: number } }>('POST', '/api/v1/users/password_links', { user_ids: userIds })).data.sent,
  })
}
