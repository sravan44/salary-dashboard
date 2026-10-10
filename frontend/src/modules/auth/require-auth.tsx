import { Alert, Anchor, Center, Loader } from '@mantine/core'
import { useQueryClient } from '@tanstack/react-query'
import type { ReactNode } from 'react'
import { Link, Navigate, useLocation } from 'react-router-dom'
import { SIGNED_OUT_KEY, useSession } from './api'
import type { Permission } from './types'

/**
 * Shows its children only to a signed-in user who has `permission`.
 * Signed out → the login page (remembering where they were going). Wrong role → a clear message.
 * The server enforces the same rules; this only keeps the UI honest.
 */
export function RequireAuth({ permission, children }: { permission?: Permission; children: ReactNode }) {
  const session = useSession()
  const location = useLocation()
  const signedOutDeliberately = useQueryClient().getQueryData(SIGNED_OUT_KEY) === true

  if (session.isPending) {
    return (
      <Center p="xl">
        <Loader aria-label="Checking sign-in" />
      </Center>
    )
  }
  if (session.isError) {
    // Not "signed out": the check itself failed (e.g. the server is down). Don't pretend otherwise.
    return (
      <Alert color="red" title="Could not check your sign-in" role="alert" m="md">
        {session.error.message}
      </Alert>
    )
  }
  if (!session.data) {
    if (signedOutDeliberately) return <Navigate to="/login" replace />
    const next = encodeURIComponent(location.pathname + location.search)
    return <Navigate to={`/login?next=${next}`} replace />
  }
  if (permission && !session.data.permissions[permission]) {
    return (
      <Alert color="gray" role="alert">
        You don’t have access to this page.{' '}
        <Anchor component={Link} to="/">
          Go to the dashboard
        </Anchor>
      </Alert>
    )
  }
  return <>{children}</>
}
