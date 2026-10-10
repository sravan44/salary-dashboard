import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ApiError, getJson, sendJson } from '../../shared/api-client'
import type { SessionUser } from './types'

export const SESSION_KEY = ['session'] as const
/** Set by a deliberate sign-out, so the next person starts on a fresh login page (no "return to" page). */
export const SIGNED_OUT_KEY = ['signed-out'] as const

/** Who is signed in: the user, or null when nobody is (a 401 is an answer here, not an error). */
export function useSession() {
  return useQuery({
    queryKey: SESSION_KEY,
    queryFn: async () => {
      try {
        return (await getJson<{ data: SessionUser }>('/api/v1/session')).data
      } catch (error) {
        if (error instanceof ApiError && error.status === 401) return null
        throw error
      }
    },
    staleTime: Infinity,
  })
}

export function useSignIn() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: async (credentials: { email: string; password: string }) =>
      (await sendJson<{ data: SessionUser }>('POST', '/api/v1/session', credentials)).data,
    onSuccess: (user) => {
      // Nothing cached from a previous user may be shown to this one.
      queryClient.removeQueries({ predicate: (query) => query.queryKey[0] !== SESSION_KEY[0] })
      queryClient.setQueryData(SESSION_KEY, user)
    },
  })
}

export function useSignOut() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: () => sendJson<void>('DELETE', '/api/v1/session'),
    onSettled: () => {
      queryClient.removeQueries({ predicate: (query) => query.queryKey[0] !== SESSION_KEY[0] })
      queryClient.setQueryData(SIGNED_OUT_KEY, true)
      queryClient.setQueryData(SESSION_KEY, null)
    },
  })
}
