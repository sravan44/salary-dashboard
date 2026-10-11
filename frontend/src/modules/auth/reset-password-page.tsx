import { Alert, Anchor, Button, Center, Paper, Stack, Text, Title } from '@mantine/core'
import { useState, type FormEvent } from 'react'
import { Link, useLocation, useNavigate } from 'react-router-dom'
import { ApiError } from '../../shared/api-client'
import { useResetPassword } from './password-api'
import { generalError } from './password-errors'
import { NewPasswordFields } from './password-fields'

/** The token arrives after "#", so it stays in the browser and never reaches the server's request logs. */
const tokenFrom = (hash: string) => new URLSearchParams(hash.replace(/^#/, '')).get('token') ?? ''

/** Signed out: a reset link, or a new user's set-password link, lands here to choose a password. */
export function ResetPasswordPage() {
  const location = useLocation()
  const navigate = useNavigate()
  const reset = useResetPassword()
  const [password, setPassword] = useState('')
  const [confirmation, setConfirmation] = useState('')
  const token = tokenFrom(location.hash)
  const expired = reset.error instanceof ApiError && reset.error.code === 'invalid_token' ? reset.error.message : null

  const submit = (event: FormEvent) => {
    event.preventDefault()
    reset.mutate(
      { token, password, password_confirmation: confirmation },
      { onSuccess: () => navigate('/login', { replace: true, state: { notice: 'Your password is set. Sign in with it now.' } }) },
    )
  }

  return (
    <Center mih="100vh" p="md">
      <Paper withBorder p="xl" w={380}>
        <Stack>
          <Title order={2}>Choose a password</Title>
          {!token || expired ? (
            <Alert color="red" role="alert" title="This link can’t be used">
              {expired ?? 'The link is incomplete. Open it again from your email.'}{' '}
              <Anchor component={Link} to="/forgot-password">
                Ask for a new link
              </Anchor>
            </Alert>
          ) : (
            <form onSubmit={submit} noValidate>
              <Stack>
                <Text size="sm" c="dimmed">
                  Choose the password you’ll sign in with.
                </Text>
                {generalError(reset.error) && (
                  <Alert color="red" role="alert">
                    {generalError(reset.error)}
                  </Alert>
                )}
                <NewPasswordFields password={password} confirmation={confirmation} onPassword={setPassword} onConfirmation={setConfirmation} error={reset.error} />
                <Button type="submit" loading={reset.isPending}>
                  Set password
                </Button>
              </Stack>
            </form>
          )}
          <Anchor component={Link} to="/login" size="sm">
            Back to sign in
          </Anchor>
        </Stack>
      </Paper>
    </Center>
  )
}
