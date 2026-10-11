import { Alert, Anchor, Button, Center, Paper, Stack, Text, TextInput, Title } from '@mantine/core'
import { useState, type FormEvent } from 'react'
import { Link } from 'react-router-dom'
import { useRequestPasswordReset } from './password-api'
import { generalError } from './password-errors'

/** Signed out: email a reset link. The answer never says whether the email has an account. */
export function ForgotPasswordPage() {
  const request = useRequestPasswordReset()
  const [email, setEmail] = useState('')

  const submit = (event: FormEvent) => {
    event.preventDefault()
    request.mutate(email)
  }

  return (
    <Center mih="100vh" p="md">
      <Paper withBorder p="xl" w={380}>
        <Stack>
          <Title order={2}>Forgot password</Title>
          {request.isSuccess ? (
            <Alert color="teal">
              {request.data} The link works once and expires in 2 hours.
            </Alert>
          ) : (
            <form onSubmit={submit} noValidate>
              <Stack>
                <Text size="sm" c="dimmed">
                  Enter your sign-in email and we’ll send you a link to choose a new password.
                </Text>
                {request.isError && (
                  <Alert color="red" role="alert">
                    {generalError(request.error)}
                  </Alert>
                )}
                <TextInput label="Email" type="email" autoComplete="username" value={email} onChange={(e) => setEmail(e.currentTarget.value)} />
                <Button type="submit" loading={request.isPending} disabled={!email.trim()}>
                  Send reset link
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
