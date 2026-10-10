import { useQueryClient } from '@tanstack/react-query'
import { useEffect } from 'react'
import { ApiError } from '../../shared/api-client'
import { SESSION_KEY } from './api'

const isUnauthenticated = (error: unknown) => error instanceof ApiError && error.status === 401

/**
 * When any request answers 401 (the server-side session expired or was signed out elsewhere),
 * forget the user; the route guard then shows the login page and returns here afterwards.
 */
export function SessionExpiryWatcher() {
  const queryClient = useQueryClient()

  useEffect(() => {
    const signOutLocally = () => queryClient.setQueryData(SESSION_KEY, null)
    const unsubscribeQueries = queryClient.getQueryCache().subscribe((event) => {
      if (event.type === 'updated' && event.action.type === 'error' && isUnauthenticated(event.action.error)) signOutLocally()
    })
    const unsubscribeMutations = queryClient.getMutationCache().subscribe((event) => {
      if (event.type === 'updated' && event.action.type === 'error' && isUnauthenticated(event.action.error)) signOutLocally()
    })
    return () => {
      unsubscribeQueries()
      unsubscribeMutations()
    }
  }, [queryClient])

  return null
}
