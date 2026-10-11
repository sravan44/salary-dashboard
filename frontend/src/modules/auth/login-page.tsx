import { Alert, Anchor, Button, Center, Paper, PasswordInput, Stack, TextInput, Title } from '@mantine/core'
import { useState, type FormEvent } from 'react'
import { Link, Navigate, useLocation, useNavigate, useSearchParams } from 'react-router-dom'
import { useSession, useSignIn } from './api'

/** Only same-app paths are followed after sign-in, so a crafted link cannot send users elsewhere. */
function safeNext(next: string | null) {
  return next && next.startsWith('/') && !next.startsWith('//') ? next : '/'
}

export function LoginPage() {
  const session = useSession()
  const signIn = useSignIn()
  const navigate = useNavigate()
  const [params] = useSearchParams()
  const notice = (useLocation().state as { notice?: string } | null)?.notice
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const next = safeNext(params.get('next'))

  if (session.data) return <Navigate to={next} replace />

  const submit = (event: FormEvent) => {
    event.preventDefault()
    signIn.mutate({ email, password }, { onSuccess: () => navigate(next, { replace: true }) })
  }

  return (
    <Center mih="100vh" p="md">
      <Paper withBorder p="xl" w={380}>
        <form onSubmit={submit} noValidate>
          <Stack>
            <Title order={2}>Sign in</Title>
            {notice && !signIn.isError && (
              <Alert color="teal">
                {notice}
              </Alert>
            )}
            {signIn.isError && (
              <Alert color="red" role="alert">
                {signIn.error.message}
              </Alert>
            )}
            <TextInput label="Email" type="email" autoComplete="username" value={email} onChange={(e) => setEmail(e.currentTarget.value)} />
            <PasswordInput label="Password" autoComplete="current-password" value={password} onChange={(e) => setPassword(e.currentTarget.value)} />
            <Button type="submit" loading={signIn.isPending}>
              Sign in
            </Button>
            <Anchor component={Link} to="/forgot-password" size="sm" ta="center">
              Forgot password?
            </Anchor>
          </Stack>
        </form>
      </Paper>
    </Center>
  )
}
