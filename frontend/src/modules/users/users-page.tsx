import { Alert, Badge, Button, Center, Group, Loader, MultiSelect, Paper, PasswordInput, Stack, Table, Text, TextInput, Title } from '@mantine/core'
import { useState, type FormEvent } from 'react'
import { ApiError } from '../../shared/api-client'
import { ROLE_LABELS } from '../auth/types'
import { useCreateUser, useUpdateRoles, useUsers, type UserRow } from './api'

const ROLE_OPTIONS = Object.entries(ROLE_LABELS).map(([value, label]) => ({ value, label }))
const ROLE_ORDER = Object.keys(ROLE_LABELS)
/** Roles in a fixed order, so the same set always looks (and is sent) the same. */
const ordered = (roles: string[]) => ROLE_ORDER.filter((role) => roles.includes(role))

const fieldErrors = (error: unknown) => (error instanceof ApiError ? error.details : {})
const LABELS: Record<string, string> = { email: 'Email', roles: 'Roles', password: 'Password' }
const capitalised = (text?: string) => text && text[0].toUpperCase() + text.slice(1)
const describe = (error: unknown, key: string) => fieldErrors(error)[key] && `${LABELS[key]} ${fieldErrors(error)[key].join(', ')}`

/** Admin only: add accounts and change roles. A user may hold several roles; access is their union. */
export function UsersPage() {
  const users = useUsers()

  return (
    <Stack gap="md">
      <Title order={2}>Users</Title>
      <AddUserForm />
      {users.isPending ? (
        <Center p="xl">
          <Loader aria-label="Loading users" />
        </Center>
      ) : users.isError ? (
        <Alert color="red" role="alert">
          {users.error.message}
        </Alert>
      ) : (
        <Paper withBorder p="md">
          <Table aria-label="Users" verticalSpacing="sm">
            <Table.Thead>
              <Table.Tr>
                <Table.Th>Email</Table.Th>
                <Table.Th>Current roles</Table.Th>
                <Table.Th>Change roles</Table.Th>
                <Table.Th />
              </Table.Tr>
            </Table.Thead>
            <Table.Tbody>
              {users.data.map((user) => (
                <UserRowEditor key={user.id} user={user} />
              ))}
            </Table.Tbody>
          </Table>
        </Paper>
      )}
    </Stack>
  )
}

function UserRowEditor({ user }: { user: UserRow }) {
  const [roles, setRoles] = useState(user.roles)
  const update = useUpdateRoles(user.id)
  const changed = ordered(roles).join() !== ordered(user.roles).join()

  return (
    <Table.Tr>
      <Table.Td>{user.email}</Table.Td>
      <Table.Td>
        <Group gap={4}>
          {user.roles.map((role) => (
            <Badge key={role} variant="light">
              {ROLE_LABELS[role] ?? role}
            </Badge>
          ))}
        </Group>
      </Table.Td>
      <Table.Td>
        <MultiSelect
          aria-label={`Roles for ${user.email}`}
          data={ROLE_OPTIONS}
          value={roles}
          onChange={(next) => {
            update.reset()
            setRoles(next)
          }}
          error={capitalised(fieldErrors(update.error).roles?.join(', '))}
          miw={260}
        />
      </Table.Td>
      <Table.Td>
        <Group gap="xs" wrap="nowrap">
          <Button size="xs" disabled={!changed} loading={update.isPending} onClick={() => update.mutate(ordered(roles))}>
            Save
          </Button>
          {update.isSuccess && !changed && (
            <Text size="sm" c="teal">
              Saved
            </Text>
          )}
          {update.isError && !(update.error instanceof ApiError && Object.keys(update.error.details).length) && (
            <Text size="sm" c="red">
              {update.error.message}
            </Text>
          )}
        </Group>
      </Table.Td>
    </Table.Tr>
  )
}

function AddUserForm() {
  const create = useCreateUser()
  const [email, setEmail] = useState('')
  const [roles, setRoles] = useState<string[]>([])
  const [password, setPassword] = useState('')

  const submit = (event: FormEvent) => {
    event.preventDefault()
    create.mutate(
      { email, roles: ordered(roles), password },
      {
        onSuccess: () => {
          setEmail('')
          setRoles([])
          setPassword('')
        },
      },
    )
  }
  const general = create.isError && Object.keys(fieldErrors(create.error)).length === 0 ? create.error.message : null

  return (
    <Paper withBorder p="md">
      <form onSubmit={submit} noValidate>
        <Stack gap="sm">
          <Title order={4}>Add a user</Title>
          {general && (
            <Alert color="red" role="alert">
              {general}
            </Alert>
          )}
          <Group align="flex-start" grow>
            <TextInput label="Email" type="email" value={email} error={describe(create.error, 'email')} onChange={(e) => setEmail(e.currentTarget.value)} />
            <MultiSelect label="Roles" placeholder="Choose one or more" data={ROLE_OPTIONS} value={roles} error={describe(create.error, 'roles')} onChange={setRoles} />
            <PasswordInput
              label="First password"
              description="12–72 characters; share it with them securely"
              value={password}
              error={describe(create.error, 'password')}
              onChange={(e) => setPassword(e.currentTarget.value)}
            />
          </Group>
          <Group>
            <Button type="submit" loading={create.isPending}>
              Add user
            </Button>
          </Group>
        </Stack>
      </form>
    </Paper>
  )
}
