import { Alert, Button, Center, Paper, PasswordInput, Stack, TextInput, Title } from '@mantine/core'
import { useState, type FormEvent } from 'react'
import { Navigate, useNavigate, useSearchParams } from 'react-router-dom'
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
          </Stack>
        </form>
      </Paper>
    </Center>
  )
}
